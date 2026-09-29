# Read-only Step 6 Slave servo-offset capture with tightly interleaved CKO/DMS.
#
# Each sample reads DMS high/low immediately before and after CKO, while
# bracketing the critical group with the source-mapped servo update counter
# (UCNT) and state (SSTAT). Global-Time and lock fields are read separately
# and their host-time boundaries are emitted; no cross-domain atomicity is
# claimed. This script issues mailbox reads only and does not write a target,
# alter a servo/PPS setting, reset, or program the FPGA.
#
# Usage:
#   quartus_stp -t read_step6_servo_interleaved_offset.tcl \
#       ?duration_ms? ?sample_ms? ?board_substring?

package require ::quartus::insystem_source_probe

set duration_ms 300000
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
set ::s6_interleaved_rows 0
set ::s6_interleaved_accepted 0
set ::s6_interleaved_qualifying 0
set ::s6_interleaved_invalid_streak 0
set ::s6_interleaved_reset_stop 0
set ::s6_interleaved_board_count 0
array set ::s6_interleaved_reset_baseline {}

proc s6_i_us {} {
  if {![catch {clock clicks -microseconds} value]} { return $value }
  return [expr {[clock milliseconds] * 1000}]
}

proc s6_i_signed32 {raw} {
  set value [word32 $raw]
  if {$value < 0} { return -1 }
  if {$value >= 0x80000000} { return [expr {$value - 0x100000000}] }
  return $value
}

proc s6_i_u64_bracketed {high_a low high_b} {
  if {![is_hex $high_a] || ![is_hex $low] || ![is_hex $high_b]} { return -1 }
  set h0 [word32 $high_a]
  set lo [word32 $low]
  set h1 [word32 $high_b]
  if {$h0 < 0 || $lo < 0 || $h1 < 0 || $h0 != $h1} { return -1 }
  return [expr {($h0 << 32) | $lo}]
}

proc s6_i_snapshot {snapshot0 snapshot1_before snapshot1_after status escr} {
  set tai -1
  set cycles -1
  set snapshot_valid -1
  set snapshot_count -1
  set time_valid -1
  set pps_valid -1
  set stable 0
  if {[is_hex $snapshot0] && [is_hex $snapshot1_before] &&
      [is_hex $snapshot1_after]} {
    set high0 [probe_high32 $snapshot0]
    set low0 [word32 $snapshot0]
    set low1 [word32 $snapshot1_after]
    set low1_before [word32 $snapshot1_before]
    if {$high0 >= 0 && $low0 >= 0 && $low1 >= 0 && $low1_before >= 0} {
      set stable [expr {
        [normalize_probe64 $snapshot1_before] eq \
        [normalize_probe64 $snapshot1_after] ? 1 : 0}]
      set tai [expr {(($high0 & 0xff) << 32) | $low0}]
      set cycles [expr {(($high0 & 0x00ffffff) | (($low1 & 0xf) << 24))}]
      set time_valid [expr {($low1 >> 4) & 1}]
      set pps_valid [expr {($low1 >> 5) & 1}]
      set snapshot_valid [expr {($low1 >> 6) & 1}]
      set snapshot_count [expr {($low1 >> 7) & 0xffff}]
    }
  }
  set status_time_valid [bit64_low $status 4]
  set status_pps_valid [bit64_low $status 5]
  set escr_word [word32 $escr]
  set escr_time_valid -1
  set escr_pps_valid -1
  if {$escr_word >= 0} {
    set escr_time_valid [expr {($escr_word >> 3) & 1}]
    set escr_pps_valid [expr {($escr_word >> 2) & 1}]
  }
  set global_valid [expr {
    $stable && $snapshot_valid == 1 && $time_valid == 1 && $pps_valid == 1 &&
    $status_time_valid == 1 && $status_pps_valid == 1 &&
    $escr_time_valid == 1 && $escr_pps_valid == 1 ? 1 : 0}]
  return [list $tai $cycles $stable $snapshot_valid $snapshot_count \
    $time_valid $pps_valid $status_time_valid $status_pps_valid \
    $escr_time_valid $escr_pps_valid $global_valid]
}

proc s6_i_capture {hardware_name sample elapsed_ms} {
  incr ::s6_interleaved_rows
  set row_start_us [s6_i_us]

  # Global-Time frame is a separate group. Probe 63 is read on both sides of
  # probe 62, matching the dashboard's sequence-stability rule. These fields
  # are not asserted to be atomic with the servo mailbox group below.
  set health_start_us [s6_i_us]
  set status [safe_probe_read 0]
  set live [safe_probe_read 64]
  set time_seq_before [safe_probe_read 63]
  set time_snapshot [safe_probe_read 62]
  set time_seq_after [safe_probe_read 63]
  set time_escr [wb_read 0x0010031C]
  set health_end_us [s6_i_us]

  # The lock registers are source-mapped, read-only state summaries.
  set helper_word_raw [wb_read 0x00100ABC]
  set main_word_raw [wb_read 0x00100AC4]
  set pstat_raw [wb_read 0x00100A0C]
  set helper_word [word32 $helper_word_raw]
  set main_word [word32 $main_word_raw]
  set pstat_word [word32 $pstat_raw]
  set helper_lock [expr {$helper_word < 0 ? -1 : ($helper_word & 1)}]
  set main_lock [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  set pstat_lock [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]

  # Critical sequence: DMS (high/low/high) immediately before CKO, then the
  # same DMS bracket immediately after CKO. UCNT and SSTAT frame the group.
  set critical_start_us [s6_i_us]
  set ucnt_before [wb_read 0x00100A48]
  set sstat_before [wb_read 0x00100A08]
  set dms_pre_start_us [s6_i_us]
  set dms_pre_hi_a [wb_read 0x00100A34]
  set dms_pre_lo [wb_read 0x00100A38]
  set dms_pre_hi_b [wb_read 0x00100A34]
  set dms_pre_end_us [s6_i_us]
  set cko_raw [wb_read 0x00100A40]
  set cko_host_us [s6_i_us]
  set dms_post_start_us [s6_i_us]
  set dms_post_hi_a [wb_read 0x00100A34]
  set dms_post_lo [wb_read 0x00100A38]
  set dms_post_hi_b [wb_read 0x00100A34]
  set dms_post_end_us [s6_i_us]
  set setp_raw [wb_read 0x00100A44]
  set sstat_after [wb_read 0x00100A08]
  set ucnt_after [wb_read 0x00100A48]
  set critical_end_us [s6_i_us]

  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set row_end_us [s6_i_us]

  set u0 [word32 $ucnt_before]
  set u1 [word32 $ucnt_after]
  set ss0 [word32 $sstat_before]
  set ss1 [word32 $sstat_after]
  set cko [s6_i_signed32 $cko_raw]
  set setp [s6_i_signed32 $setp_raw]
  set dms_pre [s6_i_u64_bracketed $dms_pre_hi_a $dms_pre_lo $dms_pre_hi_b]
  set dms_post [s6_i_u64_bracketed $dms_post_hi_a $dms_post_lo $dms_post_hi_b]
  set servo_state [expr {$ss0 < 0 ? -1 : (($ss0 >> 8) & 0xf)}]
  set sstat_stable [expr {$ss0 >= 0 && $ss0 == $ss1 ? 1 : 0}]
  set ucnt_stable [expr {$u0 >= 0 && $u0 == $u1 ? 1 : 0}]
  set reads_valid [expr {
    [is_hex $status] && [is_hex $live] && [is_hex $time_seq_before] &&
    [is_hex $time_snapshot] && [is_hex $time_seq_after] &&
    [is_hex $time_escr] && [is_hex $cko_raw] && [is_hex $setp_raw] &&
    $helper_word >= 0 && $main_word >= 0 &&
    $pstat_word >= 0 && $u0 >= 0 && $u1 >= 0 && $ss0 >= 0 && $ss1 >= 0 &&
    $cko >= -2147483648 && $dms_pre >= 0 && $dms_post >= 0 && $setp >= -2147483648 ? 1 : 0}]
  lassign [s6_i_snapshot $time_snapshot $time_seq_before $time_seq_after \
    $status $time_escr] tai cycles snapshot_stable snapshot_valid snapshot_count \
    snapshot_time_valid snapshot_pps_valid status_time_valid status_pps_valid \
    escr_time_valid escr_pps_valid global_valid
  set critical_stable [expr {$ucnt_stable && $sstat_stable ? 1 : 0}]
  set coherent [expr {$reads_valid && $critical_stable && $global_valid ? 1 : 0}]
  set qualifies [expr {
    $coherent && $helper_lock == 1 && $main_lock == 1 &&
    $main_freq == 1 && $main_phase == 1 && $pstat_lock == 1 &&
    abs($cko) < 60 ? 1 : 0}]
  set dms_gap_us [expr {$critical_end_us - $critical_start_us}]
  set cko_dms_pre [expr {$dms_pre >= 0 && $cko >= -2147483648 ? $cko - $dms_pre : "NA"}]
  set cko_dms_post [expr {$dms_post >= 0 && $cko >= -2147483648 ? $cko - $dms_post : "NA"}]
  set row_ms [expr {($row_end_us - $row_start_us) / 1000.0}]

  set boot [probe_high_counter_hex $entry]
  set cpu [probe_byte_counter_hex $reset 16]
  set wr [probe_byte_counter_hex $reset 24]
  set si [probe_byte_counter_hex $reset 40]
  set reset_changed 0
  foreach {key value} [list boot $boot cpu $cpu wr $wr si $si] {
    if {$value ne "INVALID" && $value ne "TIMEOUT"} {
      if {[info exists ::s6_interleaved_reset_baseline($hardware_name,$key)] &&
          $::s6_interleaved_reset_baseline($hardware_name,$key) ne $value} {
        set reset_changed 1
      }
      if {![info exists ::s6_interleaved_reset_baseline($hardware_name,$key)]} {
        set ::s6_interleaved_reset_baseline($hardware_name,$key) $value
      }
    }
  }
  set reset_signature_valid [expr {
    $boot ne "INVALID" && $boot ne "TIMEOUT" &&
    $cpu ne "INVALID" && $cpu ne "TIMEOUT" &&
    $wr ne "INVALID" && $wr ne "TIMEOUT" &&
    $si ne "INVALID" && $si ne "TIMEOUT" ? 1 : 0}]
  if {!$reset_signature_valid} {
    set reads_valid 0
    set coherent 0
    set qualifies 0
  }
  if {$reset_changed} { set ::s6_interleaved_reset_stop 1 }

  if {$reads_valid && $coherent} {
    incr ::s6_interleaved_accepted
    set ::s6_interleaved_invalid_streak 0
  } else {
    incr ::s6_interleaved_invalid_streak
  }
  if {$qualifies} { incr ::s6_interleaved_qualifying }

  puts [format "S6_INTERLEAVED_TIMING board=%s sample=%04d DMS_PRE_START_US=%s DMS_PRE_END_US=%s CKO_HOST_US=%s DMS_POST_START_US=%s DMS_POST_END_US=%s" \
    $hardware_name $sample $dms_pre_start_us $dms_pre_end_us $cko_host_us \
    $dms_post_start_us $dms_post_end_us]
  puts [format "S6_INTERLEAVED_SAMPLE board=%s sample=%04d elapsed_ms=%d row_ms=%.3f HEALTH_START_US=%s HEALTH_END_US=%s CRITICAL_START_US=%s CKO_HOST_US=%s CRITICAL_END_US=%s ROW_END_US=%s READS_VALID=%d COHERENT=%d QUALIFYING_SAMPLE=%d TAI=%s CYCLES=%s GLOBAL_TIME_VALID=%d SNAPSHOT_STABLE=%d SNAPSHOT_VALID=%d SNAPSHOT_COUNT=%d STATUS_TIME_VALID=%d STATUS_PPS_VALID=%d ESCR_TIME_VALID=%d ESCR_PPS_VALID=%d HELPER_LOCK=%d MAIN_LOCK=%d MAIN_FREQ_LOCK=%d MAIN_PHASE_LOCK=%d PSTAT_LOCK=%d UCNT_BEFORE=%s UCNT_AFTER=%s UCNT_STABLE=%d SSTAT_BEFORE=%s SSTAT_AFTER=%s SERVO_STATE=%d SSTAT_STABLE=%d DMS_PRE_HI_A=%s DMS_PRE_LO=%s DMS_PRE_HI_B=%s DMS_PRE_PS=%s CKO_RAW=%s CKO_PS=%d DMS_POST_HI_A=%s DMS_POST_LO=%s DMS_POST_HI_B=%s DMS_POST_PS=%s SETP_RAW=%s SETP_PS=%d CKO_MINUS_DMS_PRE_PS=%s CKO_MINUS_DMS_POST_PS=%s DMS_CKO_DMS_US=%d BOOT_GENERATION=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s RESET_CHANGED=%d" \
    $hardware_name $sample $elapsed_ms $row_ms $health_start_us $health_end_us \
    $critical_start_us $cko_host_us $critical_end_us $row_end_us $reads_valid \
    $coherent $qualifies $tai $cycles $global_valid $snapshot_stable \
    $snapshot_valid $snapshot_count $status_time_valid $status_pps_valid \
    $escr_time_valid $escr_pps_valid $helper_lock $main_lock $main_freq \
    $main_phase $pstat_lock $ucnt_before $ucnt_after $ucnt_stable \
    $sstat_before $sstat_after $servo_state $sstat_stable \
    $dms_pre_hi_a $dms_pre_lo $dms_pre_hi_b $dms_pre $cko_raw $cko \
    $dms_post_hi_a $dms_post_lo $dms_post_hi_b $dms_post $setp_raw $setp \
    $cko_dms_pre $cko_dms_post $dms_gap_us $boot $cpu $wr $si $reset_changed]
  flush stdout
  return $reset_changed
}

puts [format "S6_INTERLEAVED_CONFIG duration_ms=%d sample_ms=%d board_filter=%s read_only=1 wb_register_writes=0 fpga_program=0 reset=0" \
  $duration_ms $sample_ms $board_filter]
flush stdout

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} { continue }
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { continue }
  set device_name [lindex $devices 0]
  incr ::s6_interleaved_board_count
  puts [format "S6_INTERLEAVED_BOARD board=%s device=%s" $hardware_name $device_name]
  flush stdout
  catch {end_insystem_source_probe}
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    set begin_ms [clock milliseconds]
    set sample 0
    while {[clock milliseconds] - $begin_ms <= $duration_ms} {
      set elapsed_ms [expr {[clock milliseconds] - $begin_ms}]
      set sample_index $sample
      set reset_changed [s6_i_capture $hardware_name $sample $elapsed_ms]
      if {$reset_changed} {
        puts [format "S6_INTERLEAVED_STOP board=%s sample=%d elapsed_ms=%d reason=reset_signature_changed" $hardware_name $sample_index $elapsed_ms]
        incr sample
        break
      }
      if {$::s6_interleaved_invalid_streak >= 5} {
        puts [format "S6_INTERLEAVED_STOP board=%s sample=%d elapsed_ms=%d reason=five_consecutive_untrusted_samples" $hardware_name $sample_index $elapsed_ms]
        incr sample
        break
      }
      incr sample
      after $sample_ms
    }
    puts [format "S6_INTERLEAVED_BOARD_DONE board=%s samples=%d elapsed_ms=%d reset_stop=%d invalid_streak=%d" \
      $hardware_name $sample [expr {[clock milliseconds] - $begin_ms}] \
      $::s6_interleaved_reset_stop $::s6_interleaved_invalid_streak]
    flush stdout
  } error_message]} {
    puts [format "S6_INTERLEAVED_ERROR board=%s message=%s" $hardware_name $error_message]
    flush stdout
  }
  catch {end_insystem_source_probe}
}

puts [format "S6_INTERLEAVED_SUMMARY boards=%d rows=%d accepted=%d qualifying=%d reset_stop=%d timeout_count=%d invalid_count=%d" \
  $::s6_interleaved_board_count $::s6_interleaved_rows \
  $::s6_interleaved_accepted $::s6_interleaved_qualifying \
  $::s6_interleaved_reset_stop $::wb_timeout_count $::wb_invalid_count]
puts "S6_INTERLEAVED_DONE"
flush stdout
