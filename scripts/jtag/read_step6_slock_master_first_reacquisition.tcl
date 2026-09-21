# Step6 S_LOCK reacquisition observer.
#
# This is a read-only entry point for the Master-first startup experiment.  It
# reuses the established startup timeline reader's Wishbone mailbox contract
# only through the small library below; it never writes a production control
# register.  The caller must program the exact ec1f25e8 images externally.
#
# Usage:
#   quartus_stp -t read_step6_slock_master_first_reacquisition.tcl \
#       ?trial_id? ?board_filter? ?samples? ?gap_ms?
#
# The same observer is used for a ten-sample Master precondition and for the
# Slave reacquisition trace.  The analyzer derives:
#
#   LOCK_SUCCESS_COUNT = LOCK_POLLS - LOCK_UNLOCKED - LOCK_CALIB_FAIL
#
# from the source-backed cumulative counters.

package require ::quartus::insystem_source_probe

set ::trial_id "S6-SLOCK-MASTER-FIRST"
set ::board_filter ""
set ::sample_limit 600
set ::gap_ms 500
if {[llength $argv] >= 1} { set ::trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::board_filter [lindex $argv 1] }
if {[llength $argv] >= 3} { set ::sample_limit [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::gap_ms [expr {int([lindex $argv 3])}] }
if {$sample_limit <= 0 || $gap_ms < 0} {
  error "sample_limit must be > 0 and gap_ms must be >= 0"
}

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

array set ::slock_baseline {}
set ::slock_first_entry_ms -1
set ::slock_first_success_ms -1
set ::slock_first_exit_ms -1
set ::slock_first_failure_ms -1
set ::slock_pass_ready 0
set ::slock_failure_seen 0
set ::slock_failure_class NONE
set ::slock_post_event_samples 0
set ::slock_stop_reason NONE
set ::slock_sample_count 0
set ::slock_valid_count 0
set ::slock_error_count 0
set ::slock_first_generation INVALID
set ::slock_last_generation INVALID
set ::slock_max_success 0
set ::slock_max_calib_fail 0
set ::slock_max_polls 0
set ::slock_max_unlocked 0

proc slock_raw_valid {value} {
  return [expr {$value ne "TIMEOUT" && $value ne "INVALID" && [is_hex $value]}]
}

proc slock_hex32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  return [format %08X $word]
}

proc slock_state_name {value} {
  switch -- $value {
    0 { return WRS_IDLE }
    1 { return WRS_PRESENT }
    2 { return WRS_S_LOCK }
    3 { return WRS_M_LOCK }
    4 { return WRS_LOCKED }
    5 { return WRS_CALIBRATION }
    6 { return WRS_CALIBRATED }
    7 { return WRS_RESP_CALIB_REQ }
    8 { return WRS_WR_LINK_ON }
  }
  return UNKNOWN
}

proc slock_reason_name {value} {
  switch -- $value {
    1 { return WR_PRESENT_TIMEOUT }
    2 { return WR_M_LOCK_TIMEOUT }
    3 { return WR_S_LOCK_TIMEOUT }
    4 { return WR_LOCKED_TIMEOUT }
    5 { return WR_CALIBRATED_TIMEOUT }
    6 { return WR_RESP_CALIB_REQ_TIMEOUT }
    7 { return NO_WR_PARENT }
  }
  return UNKNOWN
}

proc slock_reset_values {entry reset} {
  return [list \
    [probe_high_counter_hex $entry] \
    [probe_byte_counter_hex $reset 16] \
    [probe_byte_counter_hex $reset 24] \
    [probe_byte_counter_hex $reset 40]]
}

proc slock_sample {hardware_name role sample elapsed_ms} {
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]

  # Source-backed runtime shadows.  No control address is written.
  set ptp_meta [wb_read 0x00100A5C]
  set sstat [wb_read 0x00100A08]
  set wr_failure [wb_read 0x00100A6C]
  set lock_result [wb_read 0x00100A8C]
  set wr_state [wb_read 0x00100A4C]
  set wr_tx_signal [wb_read 0x00100A68]
  set lock_polls [wb_read 0x00100A90]
  set lock_unlocked [wb_read 0x00100A94]
  set lock_calib_fail [wb_read 0x00100A98]
  set lock_enable [wb_read 0x00100A9C]
  set spll_state [wb_read 0x00100AA0]
  set pstat [wb_read 0x00100A0C]
  set helper_state [wb_read 0x00100ABC]
  set main_state [wb_read 0x00100AC4]
  set slock_magic [wb_read 0x00100BE0]
  set slock_stage [wb_read 0x00100BE4]
  set slock_remaining_ms [wb_read 0x00100BF0]

  set status_word [word32 $status]
  set ptp_meta_word [word32 $ptp_meta]
  set sstat_word [word32 $sstat]
  set failure_word [word32 $wr_failure]
  set result_word [word32 $lock_result]
  set wr_state_word [word32 $wr_state]
  set tx_word [word32 $wr_tx_signal]
  set polls_word [word32 $lock_polls]
  set unlocked_word [word32 $lock_unlocked]
  set calib_word [word32 $lock_calib_fail]
  set enable_word [word32 $lock_enable]
  set spll_word [word32 $spll_state]
  set pstat_word [word32 $pstat]
  set helper_word [word32 $helper_state]
  set main_word [word32 $main_state]

  set ptp_state [expr {$ptp_meta_word < 0 ? -1 : ($ptp_meta_word & 0xff)}]
  set pd_state [expr {$ptp_meta_word < 0 ? -1 : (($ptp_meta_word >> 8) & 0xff)}]
  set ext_state [expr {$ptp_meta_word < 0 ? -1 : (($ptp_meta_word >> 16) & 0xff)}]
  set wrc_mode [expr {$ptp_meta_word < 0 ? -1 : (($ptp_meta_word >> 24) & 0xff)}]
  set servo_state [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 8) & 0xf)}]
  set disable_valid [expr {$failure_word < 0 ? -1 : (($failure_word >> 11) & 1)}]
  set disable_cause [expr {$failure_word < 0 ? -1 : (($failure_word >> 8) & 0x7)}]
  set failure_reason [expr {$result_word < 0 ? -1 : (($result_word >> 9) & 0x7f)}]
  set wr_state_value [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 11) & 0xf)}]
  set wr_next_state [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 15) & 0xf)}]
  set tx_id [expr {$tx_word < 0 ? -1 : (($tx_word >> 16) & 0xffff)}]
  set spll_seq_state [expr {$spll_word < 0 ? -1 : (($spll_word >> 8) & 0xff)}]
  set pstat_locked [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]
  set helper_locked [expr {$helper_word < 0 ? -1 : ($helper_word & 1)}]
  set main_enabled [expr {$main_word < 0 ? -1 : ($main_word & 1)}]
  set main_locked [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq_locked [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase_locked [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  lassign [slock_reset_values $entry $reset] boot_generation cpu_reset_count \
    wr_core_reset_count si_config_drop_count

  set read_valid 1
  foreach value [list $status $ptp_meta $sstat $wr_failure $lock_result $wr_state \
      $wr_tx_signal $lock_polls $lock_unlocked $lock_calib_fail $lock_enable \
      $spll_state $pstat $helper_state $main_state $slock_magic $slock_stage \
      $slock_remaining_ms] {
    if {![slock_raw_valid $value]} { set read_valid 0 }
  }
  foreach value [list $boot_generation $cpu_reset_count $wr_core_reset_count \
      $si_config_drop_count] {
    if {$value eq "INVALID"} { set read_valid 0 }
  }

  set lock_success_count -1
  if {$polls_word >= 0 && $unlocked_word >= 0 && $calib_word >= 0} {
    set lock_success_count [expr {$polls_word - $unlocked_word - $calib_word}]
    if {$lock_success_count < 0} { set read_valid 0 }
  } else {
    set read_valid 0
  }

  set boot_changed 0
  set reset_changed 0
  if {[info exists ::slock_baseline(boot)] &&
      $boot_generation ne $::slock_baseline(boot)} { set boot_changed 1 }
  foreach pair [list [list cpu $cpu_reset_count] [list wr $wr_core_reset_count] \
      [list si $si_config_drop_count]] {
    set key [lindex $pair 0]
    set value [lindex $pair 1]
    if {[info exists ::slock_baseline($key)] &&
        $value ne $::slock_baseline($key)} { set reset_changed 1 }
  }
  if {![info exists ::slock_baseline(boot)]} {
    set ::slock_baseline(boot) $boot_generation
    set ::slock_baseline(cpu) $cpu_reset_count
    set ::slock_baseline(wr) $wr_core_reset_count
    set ::slock_baseline(si) $si_config_drop_count
    set ::slock_first_generation $boot_generation
  }
  set ::slock_last_generation $boot_generation

  if {$read_valid} { incr ::slock_valid_count } else { incr ::slock_error_count }
  if {$polls_word > $::slock_max_polls} { set ::slock_max_polls $polls_word }
  if {$unlocked_word > $::slock_max_unlocked} { set ::slock_max_unlocked $unlocked_word }
  if {$calib_word > $::slock_max_calib_fail} { set ::slock_max_calib_fail $calib_word }

  if {$read_valid && $wr_state_value == 2 && $::slock_first_entry_ms < 0} {
    set ::slock_first_entry_ms $elapsed_ms
  }
  if {$read_valid && $::slock_first_entry_ms >= 0 &&
      $lock_success_count > 0 && $::slock_first_success_ms < 0} {
    set ::slock_first_success_ms $elapsed_ms
  }
  set state_exit 0
  if {$read_valid && $::slock_first_entry_ms >= 0 &&
      $::slock_first_success_ms >= 0 &&
      ($wr_state_value >= 4 || $tx_id == 4098)} {
    set state_exit 1
    if {$::slock_first_exit_ms < 0} { set ::slock_first_exit_ms $elapsed_ms }
    set ::slock_pass_ready 1
  }

  set failure_event 0
  if {$read_valid && $disable_valid == 1 &&
      $failure_reason >= 1 && $failure_reason <= 7} {
    set failure_event 1
    if {$::slock_first_failure_ms < 0} {
      set ::slock_first_failure_ms $elapsed_ms
      set ::slock_failure_seen 1
      if {$failure_reason == 3 && $lock_success_count == 0 && $calib_word == 0} {
        set ::slock_failure_class FAIL_SPLL_NOT_LOCKED_BEFORE_SLOCK_DEADLINE
      } elseif {$failure_reason == 3 && $calib_word > 0} {
        set ::slock_failure_class FAIL_T24P_CALIBRATION_BEFORE_SLOCK_DEADLINE
      } else {
        set ::slock_failure_class [format "FAIL_DOWNSTREAM_WR_%s" [slock_reason_name $failure_reason]]
      }
    }
  }

  set stop_candidate NONE
  if {!$read_valid} {
    set stop_candidate INCONCLUSIVE_TRANSPORT
    set ::slock_stop_reason $stop_candidate
  } elseif {$boot_changed || $reset_changed} {
    set stop_candidate INCONCLUSIVE_RESET
    set ::slock_stop_reason $stop_candidate
  } elseif {$::slock_pass_ready} {
    incr ::slock_post_event_samples
    set stop_candidate PASS_SLOCK_SUCCESS
    if {$::slock_post_event_samples >= 20} {
      set ::slock_stop_reason PASS_SLOCK_SUCCESS
    }
  } elseif {$::slock_failure_seen} {
    incr ::slock_post_event_samples
    set stop_candidate $::slock_failure_class
    if {$::slock_post_event_samples >= 20} {
      set ::slock_stop_reason $::slock_failure_class
    }
  }

  incr ::slock_sample_count
  puts [format "SLOCK_REACQ_SAMPLE ROLE=%s board=%s sample=%03d timestamp_ms=%d READ_VALID=%d SI_CONFIG_DONE=%d WR_READY=%d WR_RX_READY=%d WR_TX_READY=%d CORE_TM_LINK_UP=%d CORE_LINK_OK=%d WR_RX_LOCKED_TO_DATA=%d CPU_RESET_N=%d WRC_MODE=%d PTP_STATE=%d PD_STATE=%d EXT_STATE=%d SERVO_STATE=%d WR_STATE_VALUE=%d WR_NEXT_STATE=%d WR_TX_ID=%d WR_DISABLE_VALID=%d WR_DISABLE_CAUSE=%d WR_FAILURE_REASON=%d LOCK_POLLS=%s LOCK_UNLOCKED=%s LOCK_CALIB_FAIL=%s LOCK_ENABLE=%s LOCK_SUCCESS_COUNT=%d SPLL_SEQ_STATE=%d PSTAT_LOCKED=%d HELPER_LOCKED=%d MAIN_ENABLED=%d MAIN_LOCKED=%d MAIN_FREQ_LOCKED=%d MAIN_PHASE_LOCKED=%d BOOT_GENERATION=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s SLOCK_MAGIC=%s SLOCK_STAGE=%s SLOCK_REMAINING_MS=%s FIRST_SLOCK_MS=%d FIRST_SUCCESS_MS=%d FIRST_EXIT_MS=%d FIRST_FAILURE_MS=%d PASS_READY=%d FAILURE_SEEN=%d FAILURE_CLASS=%s POST_EVENT_SAMPLES=%d STOP_CANDIDATE=%s" \
    $role $hardware_name $sample $elapsed_ms $read_valid \
    [bit32 $status 0] [bit32 $status 1] [bit32 $status 6] [bit32 $status 7] \
    [bit32 $status 2] [bit32 $status 3] [bit64_high $status 0] [bit32 $status 15] \
    $wrc_mode $ptp_state $pd_state $ext_state $servo_state $wr_state_value $wr_next_state $tx_id \
    $disable_valid $disable_cause $failure_reason [slock_hex32 $lock_polls] \
    [slock_hex32 $lock_unlocked] [slock_hex32 $lock_calib_fail] [slock_hex32 $lock_enable] \
    $lock_success_count $spll_seq_state $pstat_locked $helper_locked $main_enabled $main_locked \
    $main_freq_locked $main_phase_locked $boot_generation $cpu_reset_count $wr_core_reset_count \
    $si_config_drop_count [slock_hex32 $slock_magic] [slock_hex32 $slock_stage] \
    [slock_hex32 $slock_remaining_ms] $::slock_first_entry_ms $::slock_first_success_ms \
    $::slock_first_exit_ms $::slock_first_failure_ms $::slock_pass_ready $::slock_failure_seen \
    $::slock_failure_class $::slock_post_event_samples $stop_candidate]
  flush stdout
  return $stop_candidate
}

puts [format "SLOCK_REACQ_CONFIG trial=%s board_filter=%s samples=%d gap_ms=%d read_only=1 reprogram=0 compile=0 power_cycle=0" \
    $::trial_id $::board_filter $::sample_limit $::gap_ms]
flush stdout

set ::selected 0
foreach hardware_name [get_hardware_names] {
  if {$::board_filter ne "" && [string first $::board_filter $hardware_name] < 0} { continue }
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { continue }
  set device_name [lindex $devices 0]
  if {[string first "1-11.1" $hardware_name] >= 0} {
    set role MASTER
  } elseif {[string first "1-11.2" $hardware_name] >= 0} {
    set role SLAVE
  } else {
    set role UNKNOWN
  }
  set ::selected 1
  catch {end_insystem_source_probe}
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    set begin_ms [clock milliseconds]
    for {set sample 0} {$sample < $::sample_limit} {incr sample} {
      set elapsed [expr {[clock milliseconds] - $begin_ms}]
      slock_sample $hardware_name $role $sample $elapsed
      if {$::slock_stop_reason ne "NONE"} { break }
      if {$sample + 1 < $::sample_limit} { after $::gap_ms }
    }
  } error_message]} {
    incr ::slock_error_count
    puts [format "SLOCK_REACQ_ERROR ROLE=%s board=%s message=%s" $role $hardware_name $error_message]
  }
  catch {end_insystem_source_probe}
  puts [format "SLOCK_REACQ_BOARD_DONE ROLE=%s board=%s samples=%d valid=%d errors=%d stop_reason=%s elapsed_ms=%d" \
      $role $hardware_name $::slock_sample_count $::slock_valid_count $::slock_error_count \
      $::slock_stop_reason [expr {[clock milliseconds] - $begin_ms}]]
}

if {!$::selected} { error "no matching DE5a target" }
if {$::slock_stop_reason eq "NONE"} { set ::slock_stop_reason MAX_CAPTURE }
puts [format "SLOCK_REACQ_SUMMARY trial=%s samples=%d valid=%d errors=%d first_slock_ms=%d first_success_ms=%d first_exit_ms=%d first_failure_ms=%d max_polls=%d max_unlocked=%d max_calib_fail=%d lock_success_count_final=%d failure_class=%s stop_reason=%s boot_first=%s boot_last=%s" \
    $::trial_id $::slock_sample_count $::slock_valid_count $::slock_error_count \
    $::slock_first_entry_ms $::slock_first_success_ms $::slock_first_exit_ms \
    $::slock_first_failure_ms $::slock_max_polls $::slock_max_unlocked $::slock_max_calib_fail \
    [expr {$::slock_max_polls - $::slock_max_unlocked - $::slock_max_calib_fail}] \
    $::slock_failure_class $::slock_stop_reason $::slock_first_generation $::slock_last_generation]
puts "SLOCK_REACQ_DONE"
flush stdout
