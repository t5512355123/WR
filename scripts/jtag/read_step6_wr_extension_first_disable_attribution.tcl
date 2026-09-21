# Step6 diagnostic: decode the first WR-extension disable record.
#
# This observer is intentionally passive.  It keeps the currently programmed
# Slave failure state and reads only the existing Wishbone diagnostic shadows.
# No RTL, firmware, PPS setting, reset, PTP command, or FPGA programming is
# performed here.
#
# Usage:
#   quartus_stp -t read_step6_wr_extension_first_disable_attribution.tcl ?samples? ?gap_ms? ?board_substring?

package require ::quartus::insystem_source_probe

set samples 10
set gap_ms 1000
set board_filter "1-11.2"
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

array set ::ext_baseline {}
array set ::ext_previous_signature {}
array set ::ext_candidate_streak {}
array set ::ext_candidate_last {}
array set ::ext_reset_pending {}

proc ext_cause_name {value} {
  switch -- $value {
    0 { return OTHER_CALLER }
    1 { return PROTOCOL_DETECTION_TIMEOUT }
    2 { return HANDSHAKE_FAILURE }
  }
  return UNKNOWN
}

proc ext_reason_name {value} {
  switch -- $value {
    0 { return UNKNOWN }
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

proc ext_pd_name {value} {
  switch -- $value {
    0 { return PDETECTION }
    1 { return PDETECTED }
    2 { return PTP }
    3 { return CALIBRATED }
    4 { return FAILURE }
  }
  return UNKNOWN
}

proc ext_state_name {value} {
  switch -- $value {
    0 { return DISABLE }
    1 { return ACTIVE }
    2 { return PTP }
  }
  return UNKNOWN
}

proc ext_wr_state_name {value} {
  switch -- $value {
    0 { return WRS_IDLE }
    1 { return WRS_PRESENT }
    2 { return WRS_S_LOCK }
    3 { return WRS_M_LOCK }
    4 { return WRS_LOCKED }
    5 { return WRS_CALIBRATED }
    6 { return WRS_RESP_CALIB_REQ }
    7 { return WRS_RESP_CALIB }
    8 { return WRS_WR_MODE }
  }
  return UNKNOWN
}

proc ext_raw_valid {value} {
  return [expr {$value ne "TIMEOUT" && $value ne "INVALID" && [is_hex $value]}]
}

proc ext_reset_values {entry reset} {
  return [list \
    [probe_high_counter_hex $entry] \
    [probe_byte_counter_hex $reset 16] \
    [probe_byte_counter_hex $reset 24] \
    [probe_byte_counter_hex $reset 40]]
}

proc ext_sample {hardware_name sample elapsed_ms} {
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]

  set ptp_meta [wb_read 0x00100A5C]
  set sstat [wb_read 0x00100A08]
  set wr_failure [wb_read 0x00100A6C]
  set lock_result [wb_read 0x00100A8C]
  set wr_state [wb_read 0x00100A4C]
  set wr_rx_signal [wb_read 0x00100A64]
  set wr_tx_signal [wb_read 0x00100A68]
  set wr_reject [wb_read 0x00100A50]
  set lock_polls [wb_read 0x00100A90]
  set lock_unlocked [wb_read 0x00100A94]
  set lock_calib_fail [wb_read 0x00100A98]
  set lock_enable [wb_read 0x00100A9C]
  set ptp_types [wb_read 0x00100A74]
  set foreign_meta [wb_read 0x00100A78]
  set parse_meta [wb_read 0x00100A80]
  set ptp [wb_read 0x00100A10]
  set ptp_rx [wb_read 0x00100A54]
  set ptp_tx [wb_read 0x00100A58]
  set pstat [wb_read 0x00100A0C]
  set helper_state [wb_read 0x00100ABC]
  set main_state [wb_read 0x00100AC4]

  set status_word [word32 $status]
  set ptp_meta_word [word32 $ptp_meta]
  set sstat_word [word32 $sstat]
  set failure_word [word32 $wr_failure]
  set result_word [word32 $lock_result]
  set wr_state_word [word32 $wr_state]
  set rx_word [word32 $wr_rx_signal]
  set tx_word [word32 $wr_tx_signal]
  set reject_word [word32 $wr_reject]
  set pstat_word [word32 $pstat]
  set helper_word [word32 $helper_state]
  set main_word [word32 $main_state]

  set ptp_state [expr {$ptp_meta_word < 0 ? -1 : ($ptp_meta_word & 0xff)}]
  set pd_state [expr {$ptp_meta_word < 0 ? -1 : (($ptp_meta_word >> 8) & 0xff)}]
  set ext_state [expr {$ptp_meta_word < 0 ? -1 : (($ptp_meta_word >> 16) & 0xff)}]
  set wrc_mode [expr {$ptp_meta_word < 0 ? -1 : (($ptp_meta_word >> 24) & 0xff)}]
  set servo_state [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 8) & 0xf)}]
  set disable_tics_low [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 16) & 0xffff)}]
  set disable_pd_state [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 1) & 0xf)}]
  set disable_ext_state [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 12) & 0xf)}]
  set disable_cause [expr {$failure_word < 0 ? -1 : (($failure_word >> 8) & 0x7)}]
  set disable_valid [expr {$failure_word < 0 ? -1 : (($failure_word >> 11) & 1)}]
  set disable_ptp_state [expr {$failure_word < 0 ? -1 : (($failure_word >> 12) & 0xf)}]
  set failure_low16 [expr {$failure_word < 0 ? -1 : ($failure_word & 0xffff)}]
  set result_code [expr {$result_word < 0 ? -1 : ($result_word & 0xff)}]
  set check_lock [expr {$result_word < 0 ? -1 : (($result_word >> 8) & 1)}]
  set failure_reason [expr {$result_word < 0 ? -1 : (($result_word >> 9) & 0x7f)}]
  set failure_tics_low [expr {$result_word < 0 ? -1 : (($result_word >> 16) & 0xffff)}]
  set wr_state_value [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 11) & 0xf)}]
  set wr_next_state [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 15) & 0xf)}]
  set rx_id [expr {$rx_word < 0 ? -1 : (($rx_word >> 16) & 0xffff)}]
  set rx_count [expr {$rx_word < 0 ? -1 : ($rx_word & 0xffff)}]
  set tx_id [expr {$tx_word < 0 ? -1 : (($tx_word >> 16) & 0xffff)}]
  set tx_count [expr {$tx_word < 0 ? -1 : ($tx_word & 0xffff)}]
  set reject_count [expr {$reject_word < 0 ? -1 : ($reject_word & 0xffff)}]
  set reject_reason [expr {$reject_word < 0 ? -1 : (($reject_word >> 16) & 0xff)}]
  set pstat_locked [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]
  set helper_locked [expr {$helper_word < 0 ? -1 : ($helper_word & 1)}]
  set main_enabled [expr {$main_word < 0 ? -1 : ($main_word & 1)}]
  set main_locked [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq_locked [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase_locked [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  lassign [ext_reset_values $entry $reset] boot_generation cpu_reset_count \
    wr_core_reset_count si_config_drop_count

  set read_valid 1
  foreach value [list $ptp_meta $sstat $wr_failure $lock_result $wr_state \
      $wr_rx_signal $wr_tx_signal $wr_reject $lock_polls $lock_unlocked \
      $lock_calib_fail $lock_enable $ptp_types $foreign_meta $parse_meta \
      $ptp $ptp_rx $ptp_tx $pstat $helper_state $main_state] {
    if {![ext_raw_valid $value]} { set read_valid 0 }
  }
  if {![ext_raw_valid $status] || $boot_generation eq "INVALID" ||
      $cpu_reset_count eq "INVALID" || $wr_core_reset_count eq "INVALID" ||
      $si_config_drop_count eq "INVALID"} {
    set read_valid 0
  }

  set boot_changed 0
  set reset_changed 0
  if {[info exists ::ext_baseline($hardware_name,boot)] &&
      $boot_generation ne $::ext_baseline($hardware_name,boot)} {
    set boot_changed 1
  }
  foreach pair [list [list cpu $cpu_reset_count] [list wr $wr_core_reset_count] \
      [list si $si_config_drop_count]] {
    set key [lindex $pair 0]
    set value [lindex $pair 1]
    if {[info exists ::ext_baseline($hardware_name,$key)] &&
        $value ne $::ext_baseline($hardware_name,$key)} {
      set reset_changed 1
    }
  }
  if {$boot_changed || $reset_changed} {
    set ::ext_reset_pending($hardware_name) 1
  }

  set signature [format "%d:%d:%d:%d:%d:%d:%d" $disable_valid $disable_cause \
    $disable_ptp_state $disable_pd_state $disable_ext_state $failure_reason \
    $wr_state_value]
  set record_changed 0
  if {[info exists ::ext_previous_signature($hardware_name)] &&
      $signature ne $::ext_previous_signature($hardware_name)} {
    set record_changed 1
  }
  set ::ext_previous_signature($hardware_name) $signature

  set candidate NONE
  if {!$read_valid} {
    set candidate INCONCLUSIVE_TRANSPORT
  } elseif {$boot_changed || $reset_changed ||
            [info exists ::ext_reset_pending($hardware_name)]} {
    set candidate INCONCLUSIVE_RESET
  } elseif {$record_changed} {
    set candidate INCONCLUSIVE_RECORD_CHANGED
  } elseif {$disable_valid == 1 && $disable_cause == 1} {
    set candidate PASS_PROTOCOL_TIMEOUT
  } elseif {$disable_valid == 1 && $disable_cause == 2 &&
            $failure_reason >= 1 && $failure_reason <= 7} {
    set candidate [format "PASS_HANDSHAKE_%s" [ext_reason_name $failure_reason]]
  } elseif {$disable_valid == 1 && $disable_cause == 0} {
    set candidate INCONCLUSIVE_OTHER_CALLER
  } elseif {$disable_valid == 0 && $pd_state == 4 && $ext_state == 2} {
    set candidate FAIL_DIAGNOSTIC_CONTRACT
  }

  if {![info exists ::ext_candidate_streak($hardware_name)] ||
      ![info exists ::ext_candidate_last($hardware_name)] ||
      $candidate ne $::ext_candidate_last($hardware_name)} {
    set ::ext_candidate_streak($hardware_name) 0
    set ::ext_candidate_last($hardware_name) $candidate
  }
  incr ::ext_candidate_streak($hardware_name)

  set stop NONE
  if {$candidate eq "INCONCLUSIVE_TRANSPORT" ||
      $candidate eq "INCONCLUSIVE_RESET" ||
      $candidate eq "INCONCLUSIVE_RECORD_CHANGED"} {
    set stop $candidate
  } elseif {$::ext_candidate_streak($hardware_name) >= 3 &&
            $candidate ne "NONE"} {
    set stop $candidate
  }

  puts [format "EXTDISABLE_SAMPLE board=%s sample=%03d elapsed_ms=%d READ_VALID=%d STATUS_RAW=%s WDIAGS_PTP_META=%s WRC_MODE=%d PTP_STATE=%d PD_STATE=%d PD_STATE_NAME=%s EXT_STATE=%d EXT_STATE_NAME=%s WDIAGS_SSTAT=%s SERVO_STATE=%d WR_DISABLE_TICS_LOW=%d WR_DISABLE_PD_STATE=%d WR_DISABLE_PD_STATE_NAME=%s WR_DISABLE_EXT_STATE=%d WR_DISABLE_EXT_STATE_NAME=%s WR_FAILURE_DEBUG=%s WR_DISABLE_VALID=%d WR_DISABLE_CAUSE=%d WR_DISABLE_CAUSE_NAME=%s WR_DISABLE_PTP_STATE=%d WR_FAILURE_LOW16=%d WR_LOCK_RESULT=%s RESULT_CODE=%d CHECK_LOCK=%d WR_FAILURE_REASON=%d WR_FAILURE_REASON_NAME=%s WR_FAILURE_TICS_LOW=%d WR_STATE_DEBUG=%s WR_STATE_VALUE=%d WR_NEXT_STATE=%d WR_RX_SIGNAL=%s WR_RX_ID=%d WR_RX_COUNT=%d WR_TX_SIGNAL=%s WR_TX_ID=%d WR_TX_COUNT=%d WR_SIGNAL_REJECT=%s WR_REJECT_COUNT=%d WR_REJECT_REASON=%d LOCK_POLLS=%s LOCK_UNLOCKED=%s LOCK_CALIB_FAIL=%s LOCK_ENABLE=%s PTP_TYPES=%s FOREIGN_META=%s PARSE_META=%s PTP_RAW=%s PTP_RX=%s PTP_TX=%s PSTAT=%s PSTAT_LOCKED=%d HELPER_STATE=%s HELPER_LOCKED=%d MAIN_STATE=%s MAIN_ENABLED=%d MAIN_LOCKED=%d MAIN_FREQ_LOCKED=%d MAIN_PHASE_LOCKED=%d BOOT_GENERATION=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s BOOT_CHANGED=%d RESET_CHANGED=%d RECORD_CHANGED=%d CANDIDATE=%s CANDIDATE_STREAK=%d STOP_CANDIDATE=%s" \
    $hardware_name $sample $elapsed_ms $read_valid $status $ptp_meta $wrc_mode \
    $ptp_state $pd_state [ext_pd_name $pd_state] $ext_state [ext_state_name $ext_state] \
    $sstat $servo_state $disable_tics_low $disable_pd_state [ext_pd_name $disable_pd_state] \
    $disable_ext_state [ext_state_name $disable_ext_state] $wr_failure $disable_valid \
    $disable_cause [ext_cause_name $disable_cause] $disable_ptp_state $failure_low16 \
    $lock_result $result_code $check_lock $failure_reason [ext_reason_name $failure_reason] \
    $failure_tics_low $wr_state $wr_state_value $wr_next_state $wr_rx_signal $rx_id \
    $rx_count $wr_tx_signal $tx_id $tx_count $wr_reject $reject_count $reject_reason \
    $lock_polls $lock_unlocked $lock_calib_fail $lock_enable $ptp_types $foreign_meta \
    $parse_meta $ptp $ptp_rx $ptp_tx $pstat $pstat_locked $helper_state $helper_locked \
    $main_state $main_enabled $main_locked $main_freq_locked $main_phase_locked \
    $boot_generation $cpu_reset_count $wr_core_reset_count $si_config_drop_count \
    $boot_changed $reset_changed $record_changed $candidate $::ext_candidate_streak($hardware_name) $stop]
  flush stdout
  return $stop
}

puts [format "EXTDISABLE_CONFIG samples=%d gap_ms=%d board_filter=%s read_only=1 reprogram=0 power_cycle=0" \
      $samples $gap_ms $board_filter]
flush stdout

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} {
    continue
  }
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} {
    puts "EXTDISABLE_SKIP board=${hardware_name} reason=no_device"
    continue
  }
  set device_name [lindex $devices 0]
  puts "=== ${hardware_name} ==="
  puts [format "EXTDISABLE_DEVICE board=%s device=%s" $hardware_name $device_name]
  flush stdout
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    set begin_ms [clock milliseconds]
    set stop_reason NONE
    for {set sample 0} {$sample < $samples} {incr sample} {
      set stop [ext_sample $hardware_name $sample \
        [expr {[clock milliseconds] - $begin_ms}]]
      if {$stop ne "NONE"} {
        set stop_reason $stop
        puts [format "EXTDISABLE_STOP board=%s sample=%03d reason=%s" \
              $hardware_name $sample $stop]
        break
      }
      after $gap_ms
    }
    if {$stop_reason eq "NONE"} { set stop_reason TIME_LIMIT_OR_CAPTURE_END }
    puts [format "EXTDISABLE_DONE board=%s elapsed_ms=%d stop_reason=%s" \
      $hardware_name [expr {[clock milliseconds] - $begin_ms}] $stop_reason]
    flush stdout
  } error_message]} {
    puts "EXTDISABLE_ERROR board=${hardware_name} message=${error_message}"
    flush stdout
  }
  catch { end_insystem_source_probe }
}

puts [format "EXTDISABLE_TRANSPORT timeout_count=%d invalid_count=%d stale_count=%d unstable_count=%d" \
      $::wb_timeout_count $::wb_invalid_count $::wb_stale_count \
      $::wb_unstable_transaction_count]
puts "EXTDISABLE_DONE_ALL"
flush stdout
