# Read-only Step 6 Slave WR-servo correlation capture.
#
# WDIAG_CKO, WDIAG_SETP, WDIAG_SSTAT, and WDIAG_UCNT are mapped by
# vendor/wrpc-sw/lib/task-diags.c and include/hw/wrc_diags_regs.h.  Each row
# brackets CKO/SETP/SSTAT with the firmware servo update counter.  A row is
# called coherent only when the counter is valid and unchanged across that
# bracket.  Consecutive update pairs are kept distinct from repeated samples.
#
# This uses the existing source-probe Wishbone READ mailbox only.  It sends no
# Wishbone register writes, snapshot requests, resets, PTP commands, or control
# changes, and it does not reprogram the FPGA.
#
# Usage:
#   quartus_stp -t read_step6_servo_phase_coherent_pair.tcl \
#       ?duration_ms? ?sample_ms? ?board_substring?

package require ::quartus::insystem_source_probe

set duration_ms 120000
set sample_ms 500
set board_filter "1-11.2"
if {[llength $argv] >= 1} { set duration_ms [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set sample_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {$duration_ms <= 0 || $sample_ms <= 0} {
  error "duration_ms and sample_ms must be > 0"
}

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]
array set ::s6_servo_previous {}
array set ::s6_servo_baseline {}
set ::s6_servo_matched 0
set ::s6_servo_coherent 0
set ::s6_servo_pair_valid 0
set ::s6_servo_post_action 0
set ::s6_servo_payload_conflicts 0
set ::s6_servo_reset_stop 0
set ::s6_servo_board_count 0

proc s6_servo_signed32 {raw} {
  set value [word32 $raw]
  if {$value < 0} { return -1 }
  if {$value >= 0x80000000} {
    return [expr {$value - 0x100000000}]
  }
  return $value
}

proc s6_servo_signed_delta32 {new_value old_value} {
  set delta [expr {(($new_value - $old_value) & 0xffffffff)}]
  if {$delta >= 0x80000000} {
    set delta [expr {$delta - 0x100000000}]
  }
  return $delta
}

proc s6_servo_state_name {state} {
  switch -- $state {
    0 { return UNINITIALIZED }
    1 { return SYNC_TAI }
    2 { return SYNC_NSEC }
    3 { return SYNC_PHASE }
    4 { return TRACK_PHASE }
    5 { return WAIT_OFFSET_STABLE }
    default { return UNKNOWN }
  }
}

proc s6_servo_reset_signature {entry reset} {
  set boot [probe_high_counter_hex $entry]
  set cpu [probe_byte_counter_hex $reset 16]
  set wr [probe_byte_counter_hex $reset 24]
  set si [probe_byte_counter_hex $reset 40]
  return [list $boot $cpu $wr $si]
}

proc s6_servo_capture {hardware_name sample elapsed_ms} {
  set ucnt_before [wb_read 0x00100A48]
  set sstat [wb_read 0x00100A08]
  set cko [wb_read 0x00100A40]
  set setp [wb_read 0x00100A44]
  set ucnt_after [wb_read 0x00100A48]

  # These independent health fields are deliberately outside the counter
  # bracket: they provide context but are not claimed to be an atomic group.
  set status [safe_probe_read 0]
  set pps_escr [wb_read 0x0010031C]
  set ptp [wb_read 0x00100A10]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]

  set u0 [word32 $ucnt_before]
  set u1 [word32 $ucnt_after]
  set state_word [word32 $sstat]
  set cko_ps [s6_servo_signed32 $cko]
  set setp_ps [s6_servo_signed32 $setp]
  set status_time_valid [bit64_low $status 4]
  set status_pps_valid [bit64_low $status 5]
  set status_link [bit64_low $status 2]
  set escr_word [word32 $pps_escr]
  set ptp_word [word32 $ptp]
  set servo_state -1
  if {$state_word >= 0} {
    set servo_state [expr {($state_word >> 8) & 0xf}]
  }
  set escr_tm_valid -1
  set escr_pps_valid -1
  if {$escr_word >= 0} {
    set escr_tm_valid [expr {($escr_word >> 3) & 1}]
    set escr_pps_valid [expr {($escr_word >> 2) & 1}]
  }
  set ptp_state -1
  if {$ptp_word >= 0} { set ptp_state [expr {$ptp_word & 0xff}] }

  set reads_valid [expr {
    [is_hex $ucnt_before] && [is_hex $ucnt_after] &&
    [is_hex $sstat] && [is_hex $cko] && [is_hex $setp] &&
    $u0 >= 0 && $u1 >= 0 && $state_word >= 0}]
  set bracket_stable [expr {$reads_valid && $u0 == $u1 ? 1 : 0}]
  set payload_stable 1
  set coherent 0
  set update_delta -1
  set setp_delta "NA"
  set cko_delta "NA"
  set pair_valid 0
  set action_match -1
  set action_match_error "NA"
  set post_action 0

  if {$bracket_stable} {
    if {[info exists ::s6_servo_previous($hardware_name,ucnt)]} {
      set prior_count $::s6_servo_previous($hardware_name,ucnt)
      set update_delta [expr {(($u0 - $prior_count) & 0xffffffff)}]
      if {$update_delta == 0 &&
          ($state_word != $::s6_servo_previous($hardware_name,state) ||
           $cko_ps != $::s6_servo_previous($hardware_name,cko) ||
           $setp_ps != $::s6_servo_previous($hardware_name,setp))} {
        # The diagnostics payload changed while its published servo-update
        # identity did not. Reject that row rather than joining two refreshes.
        set payload_stable 0
        incr ::s6_servo_payload_conflicts
      }
    }
    set coherent [expr {$reads_valid && $payload_stable ? 1 : 0}]
    if {$coherent} {
      incr ::s6_servo_coherent
      if {[info exists ::s6_servo_previous($hardware_name,ucnt)] &&
          $update_delta == 1} {
        set pair_valid 1
        incr ::s6_servo_pair_valid
        set setp_delta [s6_servo_signed_delta32 $setp_ps \
          $::s6_servo_previous($hardware_name,setp)]
        set cko_delta [s6_servo_signed_delta32 $cko_ps \
          $::s6_servo_previous($hardware_name,cko)]

        # In WRH_SYNC_PHASE the source adds the measured offset to cur_setpoint
        # and calls adjust_phase(); the published state after this operation is
        # WRH_WAIT_OFFSET_STABLE. This checks that exact arithmetic on a single
        # update-counter step, not physical actuator direction.
        if {$servo_state == 5} {
          set action_match_error [expr {$setp_delta - $cko_ps}]
          set action_match [expr {abs($action_match_error) <= 1 ? 1 : 0}]
          if {$action_match} { incr ::s6_servo_matched }
        }
        if {[info exists ::s6_servo_previous($hardware_name,action_match)] &&
            $::s6_servo_previous($hardware_name,action_match) == 1} {
          set post_action 1
          incr ::s6_servo_post_action
        }
      }

      # Keep the previous unique update intact for repeated reads (delta=0).
      # Advance it only when a new counter value is observed. A skipped update
      # re-baselines the trace but cannot create a causal pair.
      if {![info exists ::s6_servo_previous($hardware_name,ucnt)] ||
          $update_delta != 0} {
        set ::s6_servo_previous($hardware_name,ucnt) $u1
        set ::s6_servo_previous($hardware_name,state) $state_word
        set ::s6_servo_previous($hardware_name,cko) $cko_ps
        set ::s6_servo_previous($hardware_name,setp) $setp_ps
        set ::s6_servo_previous($hardware_name,action_match) $action_match
      }
    }
  }

  lassign [s6_servo_reset_signature $entry $reset] boot cpu_reset wr_reset si_drop
  set reset_changed 0
  foreach {key value} [list boot $boot cpu $cpu_reset wr $wr_reset si $si_drop] {
    if {$value ne "INVALID" && $value ne "TIMEOUT"} {
      if {[info exists ::s6_servo_baseline($hardware_name,$key)] &&
          $::s6_servo_baseline($hardware_name,$key) ne $value} {
        set reset_changed 1
      }
      if {![info exists ::s6_servo_baseline($hardware_name,$key)]} {
        set ::s6_servo_baseline($hardware_name,$key) $value
      }
    }
  }
  if {$reset_changed} { set ::s6_servo_reset_stop 1 }

  puts [format "S6_SERVO_PAIR_SAMPLE board=%s sample=%04d elapsed_ms=%d READS_VALID=%d UCNT_BEFORE=%s UCNT_AFTER=%s UCNT_BRACKET_STABLE=%d UCNT_REPEAT_PAYLOAD_STABLE=%d COHERENT=%d UPDATE_DELTA=%s PAIR_VALID=%d SERVO_STATE=%s SERVO_STATE_NAME=%s CKO_RAW=%s CKO_PS=%s SETP_RAW=%s SETP_PS=%s SETP_DELTA_PS=%s CKO_DELTA_PS=%s SETPOINT_CKO_MATCH=%s SETPOINT_MINUS_CKO_PS=%s POST_ACTION_RESPONSE=%d STATUS_LINK=%s STATUS_TIME_VALID=%s STATUS_PPS_VALID=%s ESCR_TIME_VALID=%s ESCR_PPS_VALID=%s PTP_STATE=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s RESET_CHANGED=%d" \
    $hardware_name $sample $elapsed_ms $reads_valid $ucnt_before $ucnt_after \
    $bracket_stable $payload_stable $coherent $update_delta $pair_valid $servo_state \
    [s6_servo_state_name $servo_state] $cko $cko_ps $setp $setp_ps \
    $setp_delta $cko_delta $action_match $action_match_error $post_action \
    $status_link $status_time_valid $status_pps_valid $escr_tm_valid \
    $escr_pps_valid $ptp_state $boot $cpu_reset $wr_reset $si_drop $reset_changed]
  flush stdout
  return $reset_changed
}

puts [format "S6_SERVO_PAIR_CONFIG duration_ms=%d sample_ms=%d board_filter=%s read_only=1 wb_register_writes=0 fpga_program=0 reset=0" \
  $duration_ms $sample_ms $board_filter]
flush stdout

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} {
    continue
  }
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { continue }
  set device_name [lindex $devices 0]
  incr ::s6_servo_board_count
  puts [format "S6_SERVO_PAIR_BOARD board=%s device=%s" $hardware_name $device_name]
  flush stdout
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    set begin_ms [clock milliseconds]
    set sample 0
    while {[clock milliseconds] - $begin_ms <= $duration_ms} {
      set elapsed_ms [expr {[clock milliseconds] - $begin_ms}]
      if {[s6_servo_capture $hardware_name $sample $elapsed_ms]} {
        puts [format "S6_SERVO_PAIR_STOP board=%s sample=%d elapsed_ms=%d reason=reset_signature_changed" \
          $hardware_name $sample $elapsed_ms]
        break
      }
      incr sample
      after $sample_ms
    }
    puts [format "S6_SERVO_PAIR_BOARD_DONE board=%s samples=%d elapsed_ms=%d reset_stop=%d" \
      $hardware_name $sample [expr {[clock milliseconds] - $begin_ms}] \
      $::s6_servo_reset_stop]
    flush stdout
  } error_message]} {
    puts [format "S6_SERVO_PAIR_ERROR board=%s message=%s" $hardware_name $error_message]
    flush stdout
  }
  catch { end_insystem_source_probe }
}

puts [format "S6_SERVO_PAIR_SUMMARY boards=%d coherent_rows=%d adjacent_update_pairs=%d software_setpoint_offset_matches=%d post_action_offset_samples=%d same_counter_payload_conflicts=%d reset_stop=%d timeout_count=%d invalid_count=%d" \
  $::s6_servo_board_count $::s6_servo_coherent $::s6_servo_pair_valid \
  $::s6_servo_matched $::s6_servo_post_action $::s6_servo_payload_conflicts \
  $::s6_servo_reset_stop \
  $::wb_timeout_count $::wb_invalid_count]
puts "S6_SERVO_PAIR_DONE"
flush stdout
