# Step6A recovery diagnostic: observe WR-extension fallback liveness.
#
# This entry point is intentionally read-only.  It does not compile, program,
# reset, restart PTP, issue a mode command, write MDIO/SI5340, or touch any
# production control register.  It reuses the validated Wishbone diagnostic
# shadows and the existing S_LOCK trace addresses.
#
# Usage:
#   quartus_stp -t read_step6_wr_extension_fallback_terminal_liveness.tcl \
#       EXP-ID ?preflight_samples? ?gap_ms? ?duration_ms? ?capture_gap_ms?

package require ::quartus::insystem_source_probe

if {![info exists ::wf_library_only]} {
  set ::wf_library_only 0
}
set ::wf_trial_id "EXP-S6-WR-EXTENSION-FALLBACK-TERMINAL-LIVENESS-20260922"
set ::wf_preflight_samples 5
set ::wf_gap_ms 250
set ::wf_duration_ms 15000
set ::wf_capture_gap_ms 350
if {!$::wf_library_only} {
  if {[llength $argv] >= 1} { set ::wf_trial_id [lindex $argv 0] }
  if {[llength $argv] >= 2} { set ::wf_preflight_samples [expr {int([lindex $argv 1])}] }
  if {[llength $argv] >= 3} { set ::wf_gap_ms [expr {int([lindex $argv 2])}] }
  if {[llength $argv] >= 4} { set ::wf_duration_ms [expr {int([lindex $argv 3])}] }
  if {[llength $argv] >= 5} { set ::wf_capture_gap_ms [expr {int([lindex $argv 4])}] }
  if {$::wf_preflight_samples <= 0 || $::wf_gap_ms < 0 ||
      $::wf_duration_ms <= 0 || $::wf_capture_gap_ms < 0} {
    error "invalid preflight, gap, duration, or capture-gap argument"
  }
}

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

array set ::wf_baseline_reset {}
array set ::wf_previous_counters {}
array set ::wf_first_counters {}
array set ::wf_previous_activity {}

proc wf_raw_valid {value} {
  return [expr {$value ne "TIMEOUT" && $value ne "INVALID" &&
                [is_hex $value]}]
}

proc wf_probe64 {value} {
  if {![wf_raw_valid $value]} { return $value }
  return [normalize_probe64 $value]
}

proc wf_hex32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  return [format %08X $word]
}

proc wf_status_bit {value bit} {
  if {![wf_raw_valid $value]} { return -1 }
  return [bit64_low $value $bit]
}

proc wf_status_high_bit {value bit} {
  if {![wf_raw_valid $value]} { return -1 }
  return [bit64_high $value $bit]
}

proc wf_activity_count {value} {
  if {![wf_raw_valid $value]} { return -1 }
  set high [probe_high32 $value]
  if {$high < 0} { return -1 }
  return [expr {$high & 0xffff}]
}

proc wf_live_fields {live} {
  if {![wf_raw_valid $live]} { return [list -1 -1] }
  set normalized [normalize_probe64 $live]
  scan [string range $normalized 0 7] %x high
  scan [string range $normalized 8 15] %x low
  set tai_lo [expr {(($high & 0x0000000F) << 32) | $low}]
  set cycles [expr {($high >> 4) & 0x0FFFFFFF}]
  return [list $tai_lo $cycles]
}

proc wf_snapshot_fields {word0 word1} {
  if {![wf_raw_valid $word0] || ![wf_raw_valid $word1]} {
    return [list -1 -1 -1 -1 -1 -1]
  }
  set low0 [word32 $word0]
  set high0 [probe_high32 $word0]
  set low1 [word32 $word1]
  if {$low0 < 0 || $high0 < 0 || $low1 < 0} {
    return [list -1 -1 -1 -1 -1 -1]
  }
  set tai [expr {(($high0 & 0xff) << 32) | $low0}]
  set cycles [expr {($high0 & 0x00ffffff) | (($low1 & 0xf) << 24)}]
  set time_valid [expr {($low1 >> 4) & 1}]
  set pps_valid [expr {($low1 >> 5) & 1}]
  set snapshot_valid [expr {($low1 >> 6) & 1}]
  set count [expr {($low1 >> 7) & 0xffff}]
  return [list $tai $cycles $time_valid $pps_valid $snapshot_valid $count]
}

proc wf_ptp_fields {value} {
  set word [word32 $value]
  if {$word < 0} { return [list -1 -1 -1 -1] }
  return [list [expr {$word & 0xff}] \
    [expr {($word >> 8) & 0xff}] \
    [expr {($word >> 16) & 0xff}] \
    [expr {($word >> 24) & 0xff}]]
}

proc wf_reset_values {entry reset} {
  if {![wf_raw_valid $entry] || ![wf_raw_valid $reset]} {
    return [list INVALID INVALID INVALID INVALID]
  }
  return [list \
    [probe_high_counter_hex $entry] \
    [probe_byte_counter_hex $reset 16] \
    [probe_byte_counter_hex $reset 24] \
    [probe_byte_counter_hex $reset 40]]
}

proc wf_counter {value} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return $word
}

proc wf_reset_changed {hardware_name boot cpu wr si} {
  if {![info exists ::wf_baseline_reset($hardware_name)]} {
    set ::wf_baseline_reset($hardware_name) [list $boot $cpu $wr $si]
    return 0
  }
  set old $::wf_baseline_reset($hardware_name)
  return [expr {$boot ne [lindex $old 0] || $cpu ne [lindex $old 1] ||
                $wr ne [lindex $old 2] || $si ne [lindex $old 3]}]
}

proc wf_counter_decrease {hardware_name values} {
  set decreased 0
  if {[info exists ::wf_previous_counters($hardware_name)]} {
    set old $::wf_previous_counters($hardware_name)
    set index 0
    foreach value $values {
      set current [lindex $values $index]
      set previous [lindex $old $index]
      if {$current >= 0 && $previous >= 0 && $current < $previous} {
        set decreased 1
      }
      incr index
    }
  }
  set ::wf_previous_counters($hardware_name) $values
  return $decreased
}

proc wf_capture {hardware_name role sample elapsed_ms} {
  set activity_start [safe_probe_read 7]
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set global_live [safe_probe_read 64]
  set global_word1_before [safe_probe_read 63]
  set global_word0 [safe_probe_read 62]
  set global_word1_after [safe_probe_read 63]

  # Existing source-backed read-only diagnostic shadows.
  set ptp [wb_read 0x00100A10]
  set ptp_meta [wb_read 0x00100A5C]
  set sstat [wb_read 0x00100A08]
  set wr_failure [wb_read 0x00100A6C]
  set lock_result [wb_read 0x00100A8C]
  set wr_state [wb_read 0x00100A4C]
  set wr_rx_signal [wb_read 0x00100A64]
  set wr_tx_signal [wb_read 0x00100A68]
  set lock_polls [wb_read 0x00100A90]
  set lock_unlocked [wb_read 0x00100A94]
  set lock_calib_fail [wb_read 0x00100A98]
  set lock_enable [wb_read 0x00100A9C]
  set spll_state [wb_read 0x00100AA0]
  set pstat [wb_read 0x00100A0C]
  set helper_state [wb_read 0x00100ABC]
  set main_state [wb_read 0x00100AC4]
  set ptp_rx [wb_read 0x00100A54]
  set ptp_tx [wb_read 0x00100A58]

  # S_LOCK trace tail bank, reused from the source-backed startup observer.
  set slock_magic [wb_read 0x00100BE0]
  set slock_stage [wb_read 0x00100BE4]
  set slock_retry [wb_read 0x00100BE8]
  set slock_entry_tics [wb_read 0x00100BEC]
  set slock_remaining_ms [wb_read 0x00100BF0]
  set slock_poll_ret [wb_read 0x00100BF4]
  set slock_wr_state [wb_read 0x00100BF8]
  set slock_seq [wb_read 0x00100BFC]
  set activity_end [safe_probe_read 7]

  set status_word [word32 $status]
  set ptp_word [word32 $ptp]
  set ptp_meta_word [word32 $ptp_meta]
  set sstat_word [word32 $sstat]
  set failure_word [word32 $wr_failure]
  set result_word [word32 $lock_result]
  set wr_state_word [word32 $wr_state]
  set rx_word [word32 $wr_rx_signal]
  set tx_word [word32 $wr_tx_signal]
  set polls_word [word32 $lock_polls]
  set unlocked_word [word32 $lock_unlocked]
  set calib_word [word32 $lock_calib_fail]
  set enable_word [word32 $lock_enable]
  set spll_word [word32 $spll_state]
  set pstat_word [word32 $pstat]
  set helper_word [word32 $helper_state]
  set main_word [word32 $main_state]
  set ptp_rx_word [word32 $ptp_rx]
  set ptp_tx_word [word32 $ptp_tx]

  lassign [wf_live_fields $global_live] global_live_tai_lo global_live_cycles
  lassign [wf_snapshot_fields $global_word0 $global_word1_after] \
    global_snapshot_tai global_snapshot_cycles \
    global_snapshot_time_valid global_snapshot_pps_valid \
    global_snapshot_valid global_snapshot_count
  set global_snapshot_stable [expr {$global_word1_before eq $global_word1_after ? 1 : 0}]

  lassign [wf_ptp_fields $ptp_meta] ptp_state pd_state ext_state wrc_mode
  set servo_state [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 8) & 0xf)}]
  set wr_disable_tics [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 16) & 0xffff)}]
  set wr_disable_pd [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 1) & 0xf)}]
  set wr_disable_ext [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 12) & 0xf)}]
  set disable_valid [expr {$failure_word < 0 ? -1 : (($failure_word >> 11) & 1)}]
  set disable_cause [expr {$failure_word < 0 ? -1 : (($failure_word >> 8) & 0x7)}]
  set disable_ptp [expr {$failure_word < 0 ? -1 : (($failure_word >> 12) & 0xf)}]
  set failure_low16 [expr {$failure_word < 0 ? -1 : ($failure_word & 0xffff)}]
  set result_code [expr {$result_word < 0 ? -1 : ($result_word & 0xff)}]
  set result_check [expr {$result_word < 0 ? -1 : (($result_word >> 8) & 1)}]
  set failure_reason [expr {$result_word < 0 ? -1 : (($result_word >> 9) & 0x7f)}]
  set failure_tics [expr {$result_word < 0 ? -1 : (($result_word >> 16) & 0xffff)}]
  set wr_state_value [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 11) & 0xf)}]
  set wr_next_state [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 15) & 0xf)}]
  set rx_id [expr {$rx_word < 0 ? -1 : (($rx_word >> 16) & 0xffff)}]
  set rx_count [expr {$rx_word < 0 ? -1 : ($rx_word & 0xffff)}]
  set tx_id [expr {$tx_word < 0 ? -1 : (($tx_word >> 16) & 0xffff)}]
  set tx_count [expr {$tx_word < 0 ? -1 : ($tx_word & 0xffff)}]
  set lock_polls_value [wf_counter $lock_polls]
  set lock_unlocked_value [wf_counter $lock_unlocked]
  set lock_calib_value [wf_counter $lock_calib_fail]
  set lock_enable_value [wf_counter $lock_enable]
  set ptp_rx_value [wf_counter $ptp_rx]
  set ptp_tx_value [wf_counter $ptp_tx]
  set slock_retry_value [wf_counter $slock_retry]
  set slock_seq_value [wf_counter $slock_seq]
  set spll_mode [expr {$spll_word < 0 ? -1 : (($spll_word >> 16) & 0xff)}]
  set spll_align [expr {$spll_word < 0 ? -1 : (($spll_word >> 8) & 0xff)}]
  set spll_seq [expr {$spll_word < 0 ? -1 : ($spll_word & 0xff)}]
  set pstat_locked [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]
  set helper_locked [expr {$helper_word < 0 ? -1 : ($helper_word & 1)}]
  set main_enabled [expr {$main_word < 0 ? -1 : ($main_word & 1)}]
  set main_locked [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq_locked [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase_locked [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  set slock_stage_value [wf_counter $slock_stage]
  set slock_wr_state_value [wf_counter $slock_wr_state]
  set slock_poll_word [word32 $slock_poll_ret]
  set slock_poll_return [expr {$slock_poll_word < 0 ? -1 : ($slock_poll_word & 0xff)}]
  set slock_check_lock [expr {$slock_poll_word < 0 ? -1 : (($slock_poll_word >> 8) & 1)}]
  set slock_calib_attempt [expr {$slock_poll_word < 0 ? -1 : (($slock_poll_word >> 9) & 1)}]
  set slock_calib_success [expr {$slock_poll_word < 0 ? -1 : (($slock_poll_word >> 10) & 1)}]
  set slock_calib_failure [expr {$slock_poll_word < 0 ? -1 : (($slock_poll_word >> 11) & 1)}]
  set slock_t24p_calibrated [expr {$slock_poll_word < 0 ? -1 : (($slock_poll_word >> 12) & 1)}]

  lassign [wf_reset_values $entry $reset] boot_generation cpu_reset_count \
    wr_core_reset_count si_config_drop_count
  set activity_start_value [wf_activity_count $activity_start]
  set activity_end_value [wf_activity_count $activity_end]
  set activity_changed [expr {$activity_start_value >= 0 &&
      $activity_end_value >= 0 && $activity_start_value != $activity_end_value}]

  set read_valid 1
  foreach value [list $activity_start $status $entry $reset $global_live \
      $global_word1_before $global_word0 $global_word1_after $ptp $ptp_meta $sstat \
      $wr_failure $lock_result $wr_state $wr_rx_signal $wr_tx_signal \
      $lock_polls $lock_unlocked $lock_calib_fail $lock_enable $spll_state \
      $pstat $helper_state $main_state $ptp_rx $ptp_tx $slock_magic $slock_stage \
      $slock_retry $slock_entry_tics $slock_remaining_ms $slock_poll_ret \
      $slock_wr_state $slock_seq $activity_end] {
    if {![wf_raw_valid $value]} { set read_valid 0 }
  }
  foreach value [list $boot_generation $cpu_reset_count $wr_core_reset_count \
      $si_config_drop_count] {
    if {$value eq "INVALID"} { set read_valid 0 }
  }

  set reset_changed 0
  if {$read_valid} {
    set reset_changed [wf_reset_changed $hardware_name $boot_generation \
      $cpu_reset_count $wr_core_reset_count $si_config_drop_count]
  }

  set counter_values [list $lock_polls_value $lock_enable_value \
    $lock_calib_value $lock_unlocked_value $ptp_rx_value $ptp_tx_value \
    $slock_seq_value]
  set counter_decrease 0
  if {$read_valid} {
    set counter_decrease [wf_counter_decrease $hardware_name $counter_values]
  }
  if {![info exists ::wf_first_counters($hardware_name)] && $read_valid} {
    set ::wf_first_counters($hardware_name) $counter_values
  }
  set first_counters [list -1 -1 -1 -1 -1 -1 -1]
  if {[info exists ::wf_first_counters($hardware_name)]} {
    set first_counters $::wf_first_counters($hardware_name)
  }
  set counter_increase_from_first 0
  set reentry_counter_increase 0
  set index 0
  foreach value $counter_values {
    set first [lindex $first_counters $index]
    if {$value >= 0 && $first >= 0 && $value > $first} {
      set counter_increase_from_first 1
      if {$index == 0 || $index == 1 || $index == 6} {
        set reentry_counter_increase 1
      }
    }
    incr index
  }

  set status_si [wf_status_bit $status 0]
  set status_ready [wf_status_bit $status 1]
  set status_tm_link [wf_status_bit $status 2]
  set status_link_ok [wf_status_bit $status 3]
  set status_time_valid [wf_status_bit $status 4]
  set status_pps_valid [wf_status_bit $status 5]
  set status_rx_ready [wf_status_bit $status 6]
  set status_tx_ready [wf_status_bit $status 7]
  set status_tx_disable [wf_status_bit $status 10]
  set status_phy_reset [wf_status_bit $status 11]
  set status_cpu_reset_n [wf_status_bit $status 15]
  set rx_locked [wf_status_high_bit $status 0]
  set rx_pattern_ready [wf_status_high_bit $status 6]
  set link_healthy [expr {$status_si == 1 && $status_ready == 1 &&
      $status_rx_ready == 1 && $status_tx_ready == 1 &&
      $status_cpu_reset_n == 1 && $status_phy_reset == 0 &&
      $status_tx_disable == 0 && $status_tm_link == 1 &&
      $status_link_ok == 1}]
  set capture_healthy [expr {$link_healthy &&
      ($role ne "SLAVE" || ($rx_locked == 1 && $rx_pattern_ready == 1))}]

  return [list ROLE $role BOARD $role SAMPLE $sample ELAPSED_MS $elapsed_ms \
    READ_VALID $read_valid LINK_HEALTHY $link_healthy CAPTURE_HEALTHY $capture_healthy \
    RESET_CHANGED $reset_changed COUNTER_DECREASE $counter_decrease \
    COUNTER_INCREASE_FROM_FIRST $counter_increase_from_first \
    REENTRY_COUNTER_INCREASE $reentry_counter_increase \
    STATUS_SI_CONFIG $status_si STATUS_WR_READY $status_ready \
    STATUS_TM_LINK_UP $status_tm_link STATUS_LINK_OK $status_link_ok \
    STATUS_TIME_VALID $status_time_valid STATUS_PPS_VALID $status_pps_valid \
    STATUS_RX_READY $status_rx_ready STATUS_TX_READY $status_tx_ready \
    STATUS_CPU_RESET_N $status_cpu_reset_n STATUS_PHY_RST $status_phy_reset \
    STATUS_PHY_TX_DISABLE $status_tx_disable RX_LOCKED_TO_DATA $rx_locked \
    RX_PATTERN_READY $rx_pattern_ready RX_ACTIVITY_START $activity_start_value \
    RX_ACTIVITY_COUNT $activity_end_value RX_ACTIVITY_CHANGED $activity_changed \
    GLOBAL_TIME_LIVE_RAW [wf_probe64 $global_live] \
    GLOBAL_TIME_LIVE_TAI_LO $global_live_tai_lo \
    GLOBAL_TIME_LIVE_CYCLES $global_live_cycles \
    GLOBAL_TIME_SNAPSHOT_RAW0 [wf_probe64 $global_word0] \
    GLOBAL_TIME_SNAPSHOT_RAW1_BEFORE [wf_probe64 $global_word1_before] \
    GLOBAL_TIME_SNAPSHOT_RAW1_AFTER [wf_probe64 $global_word1_after] \
    GLOBAL_TIME_SNAPSHOT_STABLE $global_snapshot_stable \
    GLOBAL_TIME_SNAPSHOT_VALID $global_snapshot_valid \
    GLOBAL_TIME_SNAPSHOT_TIME_VALID $global_snapshot_time_valid \
    GLOBAL_TIME_SNAPSHOT_PPS_VALID $global_snapshot_pps_valid \
    GLOBAL_TIME_SNAPSHOT_COUNT $global_snapshot_count \
    GLOBAL_TIME_TAI $global_snapshot_tai GLOBAL_TIME_CYCLES $global_snapshot_cycles \
    WDIAGS_PTP_META [wf_probe64 $ptp_meta] WRC_MODE $wrc_mode \
    PTP_STATE $ptp_state PD_STATE $pd_state EXT_STATE $ext_state \
    WDIAGS_SSTAT [wf_probe64 $sstat] SERVO_STATE $servo_state \
    WR_DISABLE_TICS_LOW $wr_disable_tics WR_DISABLE_PD_STATE $wr_disable_pd \
    WR_DISABLE_EXT_STATE $wr_disable_ext WR_FAILURE_DEBUG [wf_probe64 $wr_failure] \
    WR_DISABLE_VALID $disable_valid WR_DISABLE_CAUSE [expr {$disable_cause}] \
    WR_DISABLE_PTP_STATE $disable_ptp WR_FAILURE_LOW16 $failure_low16 \
    WR_LOCK_RESULT [wf_probe64 $lock_result] RESULT_CODE $result_code \
    CHECK_LOCK $result_check WR_FAILURE_REASON $failure_reason \
    WR_FAILURE_TICS_LOW $failure_tics WR_STATE_DEBUG [wf_probe64 $wr_state] \
    WR_STATE_VALUE $wr_state_value WR_NEXT_STATE $wr_next_state \
    WR_RX_SIGNAL [wf_probe64 $wr_rx_signal] WR_RX_ID $rx_id WR_RX_COUNT $rx_count \
    WR_TX_SIGNAL [wf_probe64 $wr_tx_signal] WR_TX_ID $tx_id WR_TX_COUNT $tx_count \
    WR_LOCK_POLL_COUNT $lock_polls_value LOCK_ENABLE_COUNT $lock_enable_value \
    LOCK_CALIB_FAIL_COUNT $lock_calib_value LOCK_UNLOCKED_COUNT $lock_unlocked_value \
    SLOCK_TRACE_MAGIC [wf_hex32 $slock_magic] \
    SLOCK_TRACE_STAGE $slock_stage_value SLOCK_TRACE_RETRY $slock_retry_value \
    SLOCK_TRACE_ENTRY_TICS [wf_hex32 $slock_entry_tics] \
    SLOCK_TRACE_REMAINING_MS [wf_hex32 $slock_remaining_ms] \
    SLOCK_TRACE_POLL_RET [wf_hex32 $slock_poll_ret] \
    SLOCK_TRACE_POLL_RETURN $slock_poll_return SLOCK_TRACE_CHECK_LOCK $slock_check_lock \
    SLOCK_TRACE_CALIB_ATTEMPT $slock_calib_attempt \
    SLOCK_TRACE_CALIB_SUCCESS $slock_calib_success \
    SLOCK_TRACE_CALIB_FAILURE $slock_calib_failure \
    SLOCK_TRACE_T24P_CALIBRATED $slock_t24p_calibrated \
    SLOCK_TRACE_WR_STATE [wf_hex32 $slock_wr_state] SLOCK_TRACE_SEQ $slock_seq_value \
    SPLL_STATE [wf_probe64 $spll_state] SPLL_MODE $spll_mode \
    SPLL_ALIGN_STATE $spll_align SPLL_SEQ_STATE $spll_seq \
    SPLL_HELPER_STATE [wf_probe64 $helper_state] HELPER_LOCKED $helper_locked \
    SPLL_MAIN_STATE [wf_probe64 $main_state] MAIN_ENABLED $main_enabled \
    MAIN_FREQ_LOCKED $main_freq_locked MAIN_PHASE_LOCKED $main_phase_locked \
    MAIN_LOCKED $main_locked PSTAT [wf_probe64 $pstat] PSTAT_LOCKED $pstat_locked \
    PTP_RAW [wf_probe64 $ptp] PTP_RX_COUNT $ptp_rx_value PTP_TX_COUNT $ptp_tx_value \
    BOOT_GENERATION $boot_generation CPU_RESET_COUNT $cpu_reset_count \
    WR_CORE_RESET_COUNT $wr_core_reset_count SI_CONFIG_DROP_COUNT $si_config_drop_count]
}

proc wf_open_board {hardware_name} {
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { error "no device for $hardware_name" }
  catch {end_insystem_source_probe}
  start_insystem_source_probe -hardware_name $hardware_name \
    -device_name [lindex $devices 0]
  wb_sync_toggle
}

proc wf_collect {hardware_name role sample elapsed_ms} {
  set snapshot {}
  if {[catch {
    wf_open_board $hardware_name
    set snapshot [wf_capture $hardware_name $role $sample $elapsed_ms]
  } error_message]} {
    set snapshot {}
  }
  catch {end_insystem_source_probe}
  return $snapshot
}

# The recovery experiment is the sole exception to this observer's normal
# read-only behavior.  It uses the same validated HOST_TDR Wishbone path as
# the earlier VUART experiments, with a preload/commit transaction so the
# write is not mistaken for a read-side toggle.
proc wf_wb_write {addr data} {
  set preload_toggle $::wb_toggle
  set base [expr {(1 << 1) | (0xf << 2) |
      (($addr & 0xffffffff) << 6) |
      (($data & 0xffffffff) << 38)}]
  set preload_cmd [expr {$preload_toggle | $base}]
  if {[catch {
    write_source_data -instance_index 1 \
      -value [format %024X $preload_cmd] -value_in_hex
  }]} { return 0 }
  after 2

  set expected_toggle [expr {(($preload_toggle ^ 1) & 1)}]
  set ::wb_toggle $expected_toggle
  set commit_cmd [expr {$expected_toggle | $base}]
  if {[catch {
    write_source_data -instance_index 1 \
      -value [format %024X $commit_cmd] -value_in_hex
  }]} { return 0 }
  after 5
  for {set attempt 0} {$attempt < 100} {incr attempt} {
    set value [wb_probe_read]
    if {[completion_probe_valid $value $expected_toggle]} { return 1 }
    after 1
  }
  return 0
}

proc wf_send_vuart {hardware_name command label} {
  set index 0
  set ok 1
  foreach character [split $command ""] {
    scan $character %c byte
    set result [wf_wb_write 0x00100510 $byte]
    puts [format "S6_PTP_RESTART_VUART board=%s action=%s index=%02d BYTE=0x%02X WB_RESULT=%d" \
      $hardware_name $label $index $byte $result]
    flush stdout
    if {!$result} { set ok 0 }
    incr index
  }
  return $ok
}

proc wf_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc wf_precondition {snapshot role} {
  if {$snapshot eq ""} { return 0 }
  array set s $snapshot
  if {$s(READ_VALID) != 1 || $s(RESET_CHANGED) != 0 ||
      $s(LINK_HEALTHY) != 1} { return 0 }
  if {$role eq "SLAVE" && ($s(RX_LOCKED_TO_DATA) != 1 ||
      $s(RX_PATTERN_READY) != 1 || $s(RX_ACTIVITY_CHANGED) != 1 ||
      $s(PTP_STATE) != 9 || $s(PD_STATE) != 4 || $s(EXT_STATE) != 2 ||
      $s(WRC_MODE) != 3 || $s(STATUS_TIME_VALID) != 0)} { return 0 }
  return 1
}

proc wf_reentry {snapshot role} {
  if {$snapshot eq "" || $role ne "SLAVE"} { return 0 }
  array set s $snapshot
  if {$s(READ_VALID) != 1} { return 0 }
  if {$s(WR_STATE_VALUE) != 0 || $s(EXT_STATE) != 2 ||
      $s(STATUS_TIME_VALID) == 1 || $s(REENTRY_COUNTER_INCREASE) == 1} {
    return 1
  }
  return 0
}

if {!$::wf_library_only} {
set ::wf_master_hardware ""
set ::wf_slave_hardware ""
foreach hardware_name [get_hardware_names] {
  if {[string first "1-11.1" $hardware_name] >= 0} {
    set ::wf_master_hardware $hardware_name
  } elseif {[string first "1-11.2" $hardware_name] >= 0} {
    set ::wf_slave_hardware $hardware_name
  }
}
if {$::wf_master_hardware eq "" || $::wf_slave_hardware eq ""} {
  error "both DE5a targets are required"
}

puts [format "WR_FALLBACK_LIVENESS_CONFIG trial=%s preflight_samples=%d gap_ms=%d duration_ms=%d capture_gap_ms=%d read_only=1 compile=0 program=0 reset=0 power_cycle=0 ptp_restart=0 mode_command=0" \
  $::wf_trial_id $::wf_preflight_samples $::wf_gap_ms $::wf_duration_ms $::wf_capture_gap_ms]
flush stdout

set gate_all 1
set gate_transport 0
set gate_reset_changed 0
set gate_begin_ms [clock milliseconds]
for {set sample 0} {$sample < $::wf_preflight_samples} {incr sample} {
  set elapsed [expr {[clock milliseconds] - $gate_begin_ms}]
  set master [wf_collect $::wf_master_hardware MASTER $sample $elapsed]
  set slave [wf_collect $::wf_slave_hardware SLAVE $sample $elapsed]
  if {$master eq "" || $slave eq ""} {
    set gate_all 0
    set gate_transport 1
    wf_emit WR_FALLBACK_LIVENESS_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
      READ_VALID 0 MASTER_PRECONDITION 0 SLAVE_PRECONDITION 0]
  } else {
    array set m $master
    array set s $slave
    set master_good [wf_precondition $master MASTER]
    set slave_good [wf_precondition $slave SLAVE]
    if {$m(RESET_CHANGED) || $s(RESET_CHANGED)} { set gate_reset_changed 1 }
    if {$m(READ_VALID) != 1 || $s(READ_VALID) != 1} { set gate_transport 1 }
    set gate_all [expr {$gate_all && $master_good && $slave_good &&
      !$m(RESET_CHANGED) && !$s(RESET_CHANGED)}]
    wf_emit WR_FALLBACK_LIVENESS_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
      READ_VALID 1 MASTER_PRECONDITION $master_good SLAVE_PRECONDITION $slave_good \
      MASTER_RESET_CHANGED $m(RESET_CHANGED) SLAVE_RESET_CHANGED $s(RESET_CHANGED) \
      SLAVE_PTP_STATE $s(PTP_STATE) SLAVE_PD_STATE $s(PD_STATE) \
      SLAVE_EXT_STATE $s(EXT_STATE) SLAVE_WRC_MODE $s(WRC_MODE) \
      SLAVE_TIME_VALID $s(STATUS_TIME_VALID)]
  }
  if {$sample + 1 < $::wf_preflight_samples} { after $::wf_gap_ms }
}

if {$gate_transport || $gate_reset_changed || !$gate_all} {
  puts "WR_FALLBACK_LIVENESS_GATE_RESULT=INCONCLUSIVE_FALLBACK_PRECONDITION_CHANGED"
  puts "WR_FALLBACK_LIVENESS_DONE result=INCONCLUSIVE_FALLBACK_PRECONDITION_CHANGED phase=gate"
  flush stdout
  return
}
puts [format "WR_FALLBACK_LIVENESS_GATE_RESULT=PASS SAMPLES=%d" $::wf_preflight_samples]
flush stdout

set phase_begin_ms [clock milliseconds]
set phase_deadline_ms [expr {$phase_begin_ms + $::wf_duration_ms}]
set phase_sample 0
set runtime_changed 0
set autonomous_reentry 0
set phase_transport 0
while {[clock milliseconds] <= $phase_deadline_ms} {
  set elapsed [expr {[clock milliseconds] - $phase_begin_ms}]
  set master [wf_collect $::wf_master_hardware MASTER $phase_sample $elapsed]
  set slave [wf_collect $::wf_slave_hardware SLAVE $phase_sample $elapsed]
  if {$master eq "" || $slave eq ""} {
    set phase_transport 1
    wf_emit WR_FALLBACK_LIVENESS_SAMPLE_PAIR [list SAMPLE $phase_sample \
      ELAPSED_MS $elapsed READ_VALID 0]
    break
  }
  array set m $master
  array set s $slave
  wf_emit WR_FALLBACK_LIVENESS_SAMPLE_PAIR [list SAMPLE $phase_sample \
    ELAPSED_MS $elapsed READ_VALID 1]
  wf_emit WR_FALLBACK_LIVENESS_SAMPLE [concat [list BOARD MASTER] $master]
  wf_emit WR_FALLBACK_LIVENESS_SAMPLE [concat [list BOARD SLAVE] $slave]
  incr phase_sample

  if {$m(READ_VALID) != 1 || $s(READ_VALID) != 1 ||
      $m(RESET_CHANGED) || $s(RESET_CHANGED) ||
      $m(COUNTER_DECREASE) || $s(COUNTER_DECREASE) ||
      !$m(CAPTURE_HEALTHY) || !$s(CAPTURE_HEALTHY) ||
      $s(PTP_STATE) != 9 || $s(PD_STATE) != 4 || $s(WRC_MODE) != 3} {
    set runtime_changed 1
  }
  if {[wf_reentry $slave SLAVE]} {
    set autonomous_reentry 1
    break
  }
  if {$runtime_changed} { break }
  if {[clock milliseconds] <= $phase_deadline_ms} { after $::wf_capture_gap_ms }
}

set result PASS_CAPTURE
if {$phase_transport || $runtime_changed} {
  set result INCONCLUSIVE_RUNTIME_STATE_CHANGED
} elseif {$autonomous_reentry} {
  set result WR_EXTENSION_AUTONOMOUS_REENTRY_OBSERVED
}
puts [format "WR_FALLBACK_LIVENESS_CAPTURE_RESULT=%s SAMPLES=%d ELAPSED_MS=%d" \
  $result $phase_sample [expr {[clock milliseconds] - $phase_begin_ms}]]
puts [format "WR_FALLBACK_LIVENESS_DONE result=%s phase=observation" $result]
flush stdout
}
