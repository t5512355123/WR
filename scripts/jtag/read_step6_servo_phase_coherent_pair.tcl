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
set ::s6_servo_f4l_valid 0
set ::s6_servo_f4l_same_servo_update 0
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

proc s6_servo_u64_from_words {high_raw low_raw} {
  if {![is_hex $high_raw] || ![is_hex $low_raw]} { return "NA" }
  set high [word32 $high_raw]
  set low [word32 $low_raw]
  if {$high < 0 || $low < 0} { return "NA" }
  return [expr {($high << 32) | $low}]
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

proc s6_f4l_phase_current_read {hardware_name sample elapsed_ms pair_ucnt} {
  set host_start_ms [clock milliseconds]
  set servo_ucnt_before [wb_read 0x00100A48]
  set frame_valid 0
  set epoch_before_raw "NA"
  set epoch_after_raw "NA"
  set magic_raw "NA"
  set version_page_raw "NA"
  set source_epoch_raw "NA"
  set update_id_raw "NA"
  set branch_flags_raw "NA"
  set branch_error_raw "NA"
  set freq_error_raw "NA"
  set pi_x_raw "NA"
  set pi_output_raw "NA"
  set phase_current_raw "NA"
  set update_id -1
  set branch_id -1
  set branch_flags -1
  set clamp_code -1
  set branch_error "NA"
  set freq_error "NA"
  set pi_x "NA"
  set pi_output "NA"
  set phase_current_units "NA"
  set phase_current_ps "NA"
  set version -1
  set page -1
  set attempts 0

  # This is a sparse subset of the existing 34-word F4L publication. Words
  # 4 and 7-12 expose the update identity, branch/flags, error/PI fields, and
  # phase_shift_current; the publication epoch/header guard this read.
  # The servo update counter is a separate correlation bracket, not an atomic
  # cross-domain timestamp.
  for {set attempt 1} {$attempt <= 3} {incr attempt} {
    set attempts $attempt
    set epoch_before_raw [wb_read 0x00100B58]
    set magic_raw [wb_read 0x00100B5C]
    set version_page_raw [wb_read 0x00100B60]
    set source_epoch_raw [wb_read 0x00100B64]
    set update_id_raw [wb_read 0x00100B68]
    set branch_flags_raw [wb_read 0x00100B74]
    set branch_error_raw [wb_read 0x00100B78]
    set freq_error_raw [wb_read 0x00100B7C]
    set pi_x_raw [wb_read 0x00100B80]
    set pi_output_raw [wb_read 0x00100B84]
    set phase_current_raw [wb_read 0x00100B88]
    set epoch_after_raw [wb_read 0x00100B58]

    set epoch_before [word32 $epoch_before_raw]
    set epoch_after [word32 $epoch_after_raw]
    set magic [word32 $magic_raw]
    set version_page [word32 $version_page_raw]
    set source_epoch [word32 $source_epoch_raw]
    set update_id [word32 $update_id_raw]
    set branch_flags [word32 $branch_flags_raw]
    set phase_current_word [word32 $phase_current_raw]
    if {$version_page >= 0} {
      set version [expr {$version_page & 0xff}]
      set page [expr {($version_page >> 8) & 0xff}]
    }
    if {[is_hex $epoch_before_raw] && [is_hex $epoch_after_raw] &&
        [is_hex $magic_raw] && [is_hex $version_page_raw] &&
        [is_hex $source_epoch_raw] && [is_hex $update_id_raw] &&
        [is_hex $branch_flags_raw] && [is_hex $branch_error_raw] &&
        [is_hex $freq_error_raw] && [is_hex $pi_x_raw] &&
        [is_hex $pi_output_raw] && [is_hex $phase_current_raw] &&
        $epoch_before >= 0 && $epoch_after == $epoch_before &&
        !($epoch_after & 1) && $magic == 0x46344c31 &&
        $version == 1 && $page >= 0 && $page < 3 &&
        $source_epoch > 0 && !($source_epoch & 1) && $update_id >= 0 &&
        $branch_flags >= 0 &&
        $phase_current_word >= 0} {
      set frame_valid 1
      set branch_id [expr {$branch_flags & 0xff}]
      set branch_flags [expr {($branch_flags >> 8) & 0xffff}]
      set clamp_code [expr {([word32 $branch_flags_raw] >> 24) & 0x3}]
      set branch_error [s6_servo_signed32 $branch_error_raw]
      set freq_error [s6_servo_signed32 $freq_error_raw]
      set pi_x [s6_servo_signed32 $pi_x_raw]
      set pi_output [s6_servo_signed32 $pi_output_raw]
      set phase_current_units [s6_servo_signed32 $phase_current_raw]
      # DE5a uses the source-defined 8 ns reference period, HPLL_N=14, and
      # DMTD divide-by-two. Preserve raw units too; this derived ps value is
      # for comparison only and is not an atomic pairing with the WR servo.
      set phase_current_ps [expr {($phase_current_units * 2 * 8000) >> 14}]
      set epoch_before_raw [format %08X $epoch_before]
      set epoch_after_raw [format %08X $epoch_after]
      set source_epoch_raw [format %08X $source_epoch]
      set update_id_raw [format %08X $update_id]
      set branch_flags_raw [format %08X [word32 $branch_flags_raw]]
      set branch_error_raw [format %08X [word32 $branch_error_raw]]
      set freq_error_raw [format %08X [word32 $freq_error_raw]]
      set pi_x_raw [format %08X [word32 $pi_x_raw]]
      set pi_output_raw [format %08X [word32 $pi_output_raw]]
      break
    }
    after 2
  }

  set servo_ucnt_after [wb_read 0x00100A48]
  set servo_before [word32 $servo_ucnt_before]
  set servo_after [word32 $servo_ucnt_after]
  set same_servo_update [expr {
    $frame_valid && [is_hex $servo_ucnt_before] &&
    [is_hex $servo_ucnt_after] && $servo_before >= 0 &&
    $servo_before == $servo_after && $servo_after == $pair_ucnt ? 1 : 0}]
  if {$frame_valid} { incr ::s6_servo_f4l_valid }
  if {$same_servo_update} { incr ::s6_servo_f4l_same_servo_update }

  puts [format "S6_F4L_PHASE_SAMPLE board=%s sample=%04d host_elapsed_ms=%d host_start_ms=%d host_end_ms=%d FRAME_VALID=%d F4L_PUBLICATION_EPOCH_BEFORE=%s F4L_PUBLICATION_EPOCH_AFTER=%s F4L_MAGIC=%s F4L_VERSION=%d F4L_PAGE=%d F4L_SOURCE_EPOCH=%s F4L_UPDATE_ID=%s F4L_BRANCH_FLAGS_RAW=%s F4L_BRANCH_ID=%d F4L_FLAGS=%04X F4L_CLAMP_CODE=%d F4L_BRANCH_ERROR_RAW=%s F4L_BRANCH_ERROR=%s F4L_FREQ_ERROR_RAW=%s F4L_FREQ_ERROR=%s F4L_PI_X_RAW=%s F4L_PI_X=%s F4L_PI_OUTPUT_RAW=%s F4L_PI_OUTPUT=%s PHASE_SHIFT_CURRENT_RAW=%s PHASE_SHIFT_CURRENT_UNITS=%s PHASE_SHIFT_CURRENT_PS=%s F4L_READ_ATTEMPTS=%d SERVO_UCNT_BEFORE=%s SERVO_UCNT_AFTER=%s SERVO_UPDATE_MATCH=%d PAIR_UCNT=%s" \
    $hardware_name $sample $elapsed_ms $host_start_ms [clock milliseconds] \
    $frame_valid $epoch_before_raw $epoch_after_raw $magic_raw $version $page \
    $source_epoch_raw $update_id_raw $branch_flags_raw $branch_id $branch_flags \
    $clamp_code $branch_error_raw $branch_error $freq_error_raw $freq_error \
    $pi_x_raw $pi_x $pi_output_raw $pi_output $phase_current_raw \
    $phase_current_units $phase_current_ps \
    $attempts $servo_ucnt_before $servo_ucnt_after $same_servo_update $pair_ucnt]
  flush stdout
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
  set mu_hi [wb_read 0x00100A2C]
  set mu_lo [wb_read 0x00100A30]
  set dms_hi [wb_read 0x00100A34]
  set dms_lo [wb_read 0x00100A38]
  set asym [wb_read 0x00100A3C]
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
  set mu_ps [s6_servo_u64_from_words $mu_hi $mu_lo]
  set dms_ps [s6_servo_u64_from_words $dms_hi $dms_lo]
  set asym_ps [s6_servo_signed32 $asym]
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
    [is_hex $mu_hi] && [is_hex $mu_lo] &&
    [is_hex $dms_hi] && [is_hex $dms_lo] && [is_hex $asym] &&
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
           $mu_ps ne $::s6_servo_previous($hardware_name,mu) ||
           $dms_ps ne $::s6_servo_previous($hardware_name,dms) ||
           $asym_ps ne $::s6_servo_previous($hardware_name,asym) ||
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
        set ::s6_servo_previous($hardware_name,mu) $mu_ps
        set ::s6_servo_previous($hardware_name,dms) $dms_ps
        set ::s6_servo_previous($hardware_name,asym) $asym_ps
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

  puts [format "S6_SERVO_PAIR_SAMPLE board=%s sample=%04d elapsed_ms=%d READS_VALID=%d UCNT_BEFORE=%s MU_HI=%s MU_LO=%s MU_PS=%s DMS_HI=%s DMS_LO=%s DMS_PS=%s ASYM_RAW=%s ASYM_PS=%s UCNT_AFTER=%s UCNT_BRACKET_STABLE=%d UCNT_REPEAT_PAYLOAD_STABLE=%d COHERENT=%d UPDATE_DELTA=%s PAIR_VALID=%d SERVO_STATE=%s SERVO_STATE_NAME=%s CKO_RAW=%s CKO_PS=%s SETP_RAW=%s SETP_PS=%s SETP_DELTA_PS=%s CKO_DELTA_PS=%s SETPOINT_CKO_MATCH=%s SETPOINT_MINUS_CKO_PS=%s POST_ACTION_RESPONSE=%d STATUS_LINK=%s STATUS_TIME_VALID=%s STATUS_PPS_VALID=%s ESCR_TIME_VALID=%s ESCR_PPS_VALID=%s PTP_STATE=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s RESET_CHANGED=%d" \
    $hardware_name $sample $elapsed_ms $reads_valid $ucnt_before $mu_hi $mu_lo \
    $mu_ps $dms_hi $dms_lo $dms_ps $asym $asym_ps $ucnt_after \
    $bracket_stable $payload_stable $coherent $update_delta $pair_valid $servo_state \
    [s6_servo_state_name $servo_state] $cko $cko_ps $setp $setp_ps \
    $setp_delta $cko_delta $action_match $action_match_error $post_action \
    $status_link $status_time_valid $status_pps_valid $escr_tm_valid \
    $escr_pps_valid $ptp_state $boot $cpu_reset $wr_reset $si_drop $reset_changed]
  flush stdout

  if {![info exists ::s6_servo_f4l_last_ms($hardware_name)] ||
      $elapsed_ms - $::s6_servo_f4l_last_ms($hardware_name) >= 5000} {
    set ::s6_servo_f4l_last_ms($hardware_name) $elapsed_ms
    s6_f4l_phase_current_read $hardware_name $sample $elapsed_ms $u1
  }
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

puts [format "S6_SERVO_PAIR_SUMMARY boards=%d coherent_rows=%d adjacent_update_pairs=%d software_setpoint_offset_matches=%d post_action_offset_samples=%d same_counter_payload_conflicts=%d f4l_phase_frames_valid=%d f4l_phase_same_servo_update=%d reset_stop=%d timeout_count=%d invalid_count=%d" \
  $::s6_servo_board_count $::s6_servo_coherent $::s6_servo_pair_valid \
  $::s6_servo_matched $::s6_servo_post_action $::s6_servo_payload_conflicts \
  $::s6_servo_f4l_valid $::s6_servo_f4l_same_servo_update \
  $::s6_servo_reset_stop \
  $::wb_timeout_count $::wb_invalid_count]
puts "S6_SERVO_PAIR_DONE"
flush stdout
