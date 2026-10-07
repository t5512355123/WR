# Step6A diagnostic: attribute a Slave TM_VALID=0 state without disturbing it.
#
# This is deliberately read-only at the WR/FPGA level.  The Wishbone mailbox
# transport sends read requests, but never writes a control register, resets a
# CPU, or changes a PPS/servo setting.  It reuses the validated transport from
# read_wb_runtime.tcl and keeps the currently programmed image untouched.
#
# Usage:
#   quartus_stp -t read_step6_tmvalid_source_attribution.tcl ?duration_ms? ?sample_ms? ?board_substring?
#
# The intended session is 180 s at 1 Hz.  Stop decisions are emitted by this
# script, while scripts/experiment/step6_tmvalid_source_attribution.py is the
# offline source-of-truth for the final classification.

package require ::quartus::insystem_source_probe

set duration_ms 180000
set sample_ms 1000
set board_filter ""
if {[llength $argv] >= 1} { set duration_ms [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set sample_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {$duration_ms <= 0 || $sample_ms <= 0} {
  error "duration_ms and sample_ms must be > 0"
}

# Load the existing source-backed WB read protocol without running its normal
# dashboard entry point.  This preserves the preload/toggle commit semantics
# and its stale/timeout accounting for the focused trace.
set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

set ::tmvalid_reference_clock_hz 125000000
array set ::tmvalid_baseline {}
array set ::tmvalid_prev_ucnt {}
array set ::tmvalid_prev_snapshot_count {}
array set ::tmvalid_prev_boot {}
array set ::tmvalid_prev_cpu_reset {}
array set ::tmvalid_prev_wr_reset {}
array set ::tmvalid_prev_si_drop {}
array set ::tmvalid_ptp_servo_streak {}
array set ::tmvalid_recovery_streak {}
array set ::tmvalid_mapping_streak {}
array set ::tmvalid_timing_output_streak {}
array set ::tmvalid_reset_pending {}
array set ::tmvalid_reset_samples {}
array set ::tmvalid_started_ms {}

proc tmvalid_field {value low width} {
  return [field32 $value $low $width]
}

proc tmvalid_status_bit {value bit} {
  return [bit64_low $value $bit]
}

proc tmvalid_live_fields {live} {
  if {![is_hex $live]} {
    return [list -1 -1]
  }
  set normalized [normalize_probe64 $live]
  scan [string range $normalized 0 7] %x high
  scan [string range $normalized 8 15] %x low
  set tai_lo [expr {(($high & 0x0000000F) << 32) | $low}]
  # Probe 64 packs cycles into bits 63:36 and TAI-low into bits 35:0.
  set cycles [expr {($high >> 4) & 0x0FFFFFFF}]
  return [list $tai_lo $cycles]
}

proc tmvalid_snapshot_fields {word0 word1} {
  if {![is_hex $word0] || ![is_hex $word1]} {
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

proc tmvalid_reset_values {entry reset} {
  set boot [probe_high_counter_hex $entry]
  set cpu [probe_byte_counter_hex $reset 16]
  set wr [probe_byte_counter_hex $reset 24]
  set si [probe_byte_counter_hex $reset 40]
  return [list $boot $cpu $wr $si]
}

proc tmvalid_numeric_u32 {value} {
  set n [word32 $value]
  if {$n < 0} { return -1 }
  return $n
}

proc tmvalid_same_or_changed {old new} {
  if {$old eq "" || $new eq "" || $old eq "INVALID" || $new eq "INVALID"} {
    return -1
  }
  return [expr {$old eq $new ? 0 : 1}]
}

proc tmvalid_capture {hardware_name sample elapsed_ms} {
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set live [safe_probe_read 64]
  set snap0 [safe_probe_read 62]
  set snap1 [safe_probe_read 63]

  # These are all source-mapped read-only diagnostics.  Do not replace them
  # with guessed probe bits: TM_VALID is PPS_ESCR bit 3, while the exported
  # top-level time_valid is status bit 4.
  set pps_cr [wb_read 0x00100300]
  set pps_escr [wb_read 0x0010031C]
  set ptp [wb_read 0x00100A10]
  set ptp_meta [wb_read 0x00100A5C]
  set sstat [wb_read 0x00100A08]
  set ucnt [wb_read 0x00100A48]
  set cko [wb_read 0x00100A40]
  set foreign_meta [wb_read 0x00100A78]
  set parse_meta [wb_read 0x00100A80]
  set pstat [wb_read 0x00100A0C]
  set spll_helper_state [wb_read 0x00100ABC]
  set spll_main_state [wb_read 0x00100AC4]
  set spll_delock [wb_read 0x00100B00]
  set ptp_rx [wb_read 0x00100A54]
  set ptp_tx [wb_read 0x00100A58]

  set status_norm [normalize_probe64 $status]
  set status_si [tmvalid_status_bit $status 0]
  set status_phy_ready [tmvalid_status_bit $status 1]
  set status_link [tmvalid_status_bit $status 2]
  set status_link_ok [tmvalid_status_bit $status 3]
  set status_time_valid [tmvalid_status_bit $status 4]
  set status_pps_valid [tmvalid_status_bit $status 5]
  set status_rx_ready [tmvalid_status_bit $status 6]
  set status_tx_ready [tmvalid_status_bit $status 7]

  set pps_escr_word [word32 $pps_escr]
  set pps_cr_word [word32 $pps_cr]
  set ptp_word [word32 $ptp]
  set sstat_word [word32 $sstat]
  set pstat_word [word32 $pstat]
  set helper_word [word32 $spll_helper_state]
  set main_word [word32 $spll_main_state]
  set ucnt_word [word32 $ucnt]
  set cko_word [word32 $cko]
  set ptp_rx_word [word32 $ptp_rx]
  set ptp_tx_word [word32 $ptp_tx]

  set escr_tm_valid [expr {$pps_escr_word < 0 ? -1 : (($pps_escr_word >> 3) & 1)}]
  set escr_pps_valid [expr {$pps_escr_word < 0 ? -1 : (($pps_escr_word >> 2) & 1)}]
  set pps_cr_enable [expr {$pps_cr_word < 0 ? -1 : ($pps_cr_word & 1)}]
  set ptp_state [expr {$ptp_word < 0 ? -1 : ($ptp_word & 0xff)}]
  set servo_state [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 8) & 0xf)}]
  set pstat_locked [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]
  set helper_locked [expr {$helper_word < 0 ? -1 : ($helper_word & 1)}]
  set main_enabled [expr {$main_word < 0 ? -1 : ($main_word & 1)}]
  set main_locked [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq_locked [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase_locked [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  set ptp_rx_value [expr {$ptp_rx_word < 0 ? -1 : $ptp_rx_word}]
  set ptp_tx_value [expr {$ptp_tx_word < 0 ? -1 : $ptp_tx_word}]
  set ucnt_value [expr {$ucnt_word < 0 ? -1 : $ucnt_word}]
  set cko_value [expr {$cko_word < 0 ? -1 : $cko_word}]

  lassign [tmvalid_live_fields $live] live_tai_lo live_cycles
  lassign [tmvalid_snapshot_fields $snap0 $snap1] snapshot_tai snapshot_cycles \
    snapshot_time_valid snapshot_pps_valid snapshot_valid snapshot_count
  lassign [tmvalid_reset_values $entry $reset] boot_generation cpu_reset_count \
    wr_core_reset_count si_config_drop_count

  set boot_changed 0
  set reset_changed 0
  if {[info exists ::tmvalid_baseline($hardware_name,boot)] &&
      $boot_generation ne "INVALID" &&
      $::tmvalid_baseline($hardware_name,boot) ne "INVALID" &&
      $boot_generation ne $::tmvalid_baseline($hardware_name,boot)} {
    set boot_changed 1
  }
  foreach pair [list \
      [list cpu $cpu_reset_count] \
      [list wr $wr_core_reset_count] \
      [list si $si_config_drop_count]] {
    set key [lindex $pair 0]
    set value [lindex $pair 1]
    if {[info exists ::tmvalid_baseline($hardware_name,$key)] &&
        $value ne "INVALID" &&
        $::tmvalid_baseline($hardware_name,$key) ne "INVALID" &&
        $value ne $::tmvalid_baseline($hardware_name,$key)} {
      set reset_changed 1
    }
  }
  if {($boot_changed || $reset_changed) &&
      (![info exists ::tmvalid_reset_pending($hardware_name)] ||
       !$::tmvalid_reset_pending($hardware_name))} {
    set ::tmvalid_reset_pending($hardware_name) 1
    set ::tmvalid_reset_samples($hardware_name) 0
  }
  if {[info exists ::tmvalid_reset_pending($hardware_name)] &&
      $::tmvalid_reset_pending($hardware_name)} {
    incr ::tmvalid_reset_samples($hardware_name)
  }

  set prev_ucnt ""
  if {[info exists ::tmvalid_prev_ucnt($hardware_name)]} {
    set prev_ucnt $::tmvalid_prev_ucnt($hardware_name)
  }
  set ucnt_increased 0
  if {$prev_ucnt ne "" && $ucnt_value >= 0 && $prev_ucnt >= 0 &&
      $ucnt_value > $prev_ucnt} {
    set ucnt_increased 1
  }
  set ::tmvalid_prev_ucnt($hardware_name) $ucnt_value

  set prev_snapshot_count ""
  if {[info exists ::tmvalid_prev_snapshot_count($hardware_name)]} {
    set prev_snapshot_count $::tmvalid_prev_snapshot_count($hardware_name)
  }
  set snapshot_increased 0
  if {$prev_snapshot_count ne "" && $snapshot_count >= 0 &&
      $prev_snapshot_count >= 0 && $snapshot_count != $prev_snapshot_count} {
    set snapshot_increased 1
  }
  set ::tmvalid_prev_snapshot_count($hardware_name) $snapshot_count

  set links_healthy [expr {$status_si == 1 && $status_phy_ready == 1 &&
                            $status_link == 1 && $status_link_ok == 1 &&
                            $status_rx_ready == 1 && $status_tx_ready == 1}]
  set step5_locked [expr {$helper_locked == 1 && $main_enabled == 1 &&
                          $main_freq_locked == 1 && $main_phase_locked == 1 &&
                          $main_locked == 1 && $pstat_locked == 1}]
  set servo_complete [expr {$ptp_state == 9 && $servo_state == 4}]
  set recovery_candidate [expr {$servo_complete && $escr_tm_valid == 1 &&
                                $status_time_valid == 1 && $status_pps_valid == 1 &&
                                $step5_locked && !$boot_changed && !$reset_changed}]
  set mapping_candidate [expr {$escr_tm_valid == 1 && $status_time_valid == 0}]
  set servo_not_complete_candidate [expr {$links_healthy &&
                                           $escr_tm_valid == 0 &&
                                           $status_time_valid == 0 &&
                                           !$servo_complete}]
  set timing_output_candidate [expr {$links_healthy && $servo_complete &&
                                     $ucnt_increased && $pstat_locked == 1 &&
                                     $step5_locked && $escr_tm_valid == 0 &&
                                     $status_time_valid == 0}]

  foreach key {recovery mapping timing_output ptp_servo} {
    if {![info exists ::tmvalid_${key}_streak($hardware_name)]} {
      set ::tmvalid_${key}_streak($hardware_name) 0
    }
  }
  if {$recovery_candidate} { incr ::tmvalid_recovery_streak($hardware_name) } \
  else { set ::tmvalid_recovery_streak($hardware_name) 0 }
  if {$mapping_candidate} { incr ::tmvalid_mapping_streak($hardware_name) } \
  else { set ::tmvalid_mapping_streak($hardware_name) 0 }
  if {$timing_output_candidate} { incr ::tmvalid_timing_output_streak($hardware_name) } \
  else { set ::tmvalid_timing_output_streak($hardware_name) 0 }
  if {$servo_not_complete_candidate} { incr ::tmvalid_ptp_servo_streak($hardware_name) } \
  else { set ::tmvalid_ptp_servo_streak($hardware_name) 0 }

  set snapshot_delta_from_baseline -1
  if {[info exists ::tmvalid_baseline($hardware_name,snapshot)] &&
      $snapshot_count >= 0 &&
      $::tmvalid_baseline($hardware_name,snapshot) >= 0} {
    set snapshot_delta_from_baseline [expr {($snapshot_count -
        $::tmvalid_baseline($hardware_name,snapshot)) & 0xffff}]
  }
  if {$::tmvalid_recovery_streak($hardware_name) >= 10 &&
      $snapshot_delta_from_baseline >= 2} {
    set stop_candidate RECOVERY_PASS
  } elseif {$::tmvalid_mapping_streak($hardware_name) >= 3} {
    set stop_candidate MAPPING_EXPORT_FAIL
  } elseif {[info exists ::tmvalid_reset_pending($hardware_name)] &&
            $::tmvalid_reset_pending($hardware_name) &&
            $::tmvalid_reset_samples($hardware_name) >= 5} {
    set stop_candidate RESET_INIT_FAIL
  } elseif {$::tmvalid_timing_output_streak($hardware_name) >= 10} {
    set stop_candidate TIMING_OUTPUT_CONTROL_FAIL
  } elseif {$::tmvalid_ptp_servo_streak($hardware_name) >= 10} {
    set stop_candidate FAIL_PTP_SERVO_NOT_COMPLETE
  } else {
    set stop_candidate NONE
  }

  if {![info exists ::tmvalid_baseline($hardware_name,boot)]} {
    set ::tmvalid_baseline($hardware_name,boot) $boot_generation
    set ::tmvalid_baseline($hardware_name,cpu) $cpu_reset_count
    set ::tmvalid_baseline($hardware_name,wr) $wr_core_reset_count
    set ::tmvalid_baseline($hardware_name,si) $si_config_drop_count
    set ::tmvalid_baseline($hardware_name,snapshot) $snapshot_count
  }

  puts [format "TMVALID_SAMPLE board=%s sample=%03d elapsed_ms=%d STATUS_RAW=%s STATUS_SI_CONFIG=%d STATUS_PHY_READY=%d STATUS_TM_LINK_UP=%d STATUS_LINK_OK=%d STATUS_TIME_VALID=%d STATUS_PPS_VALID=%d STATUS_RX_READY=%d STATUS_TX_READY=%d PPS_CR=%s PPS_ESCR=%s PPS_CR_ENABLE=%d ESCR_PPS_VALID=%d ESCR_TM_VALID=%d WDIAGS_PTP=%s PTP_STATE=%d PTP_META=%s WDIAGS_SSTAT=%s SERVO_STATE=%d WDIAGS_UCNT=%s UCNT=%d CKO=%s CKO_VALUE=%d FOREIGN_META=%s PARSE_META=%s PSTAT=%s PSTAT_LOCKED=%d SPLL_HELPER_STATE=%s HELPER_LOCKED=%d SPLL_MAIN_STATE=%s MAIN_ENABLED=%d MAIN_LOCKED=%d MAIN_FREQ_LOCKED=%d MAIN_PHASE_LOCKED=%d STEP5_LOCKED=%d PTP_RX=%s PTP_TX=%s BOOT_GENERATION=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s BOOT_CHANGED=%d RESET_CHANGED=%d LIVE_RAW=%s LIVE_TAI_LO=%d LIVE_CYCLES=%d SNAPSHOT_TAI=%d SNAPSHOT_CYCLES=%d SNAPSHOT_TIME_VALID=%d SNAPSHOT_PPS_VALID=%d SNAPSHOT_VALID=%d SNAPSHOT_COUNT=%d SNAPSHOT_INCREASED=%d SNAPSHOT_DELTA_FROM_BASELINE=%d UCNT_INCREASED=%d LINK_HEALTHY=%d SERVO_COMPLETE=%d RECOVERY_STREAK=%d MAPPING_STREAK=%d TIMING_OUTPUT_STREAK=%d PTP_SERVO_STREAK=%d STOP_CANDIDATE=%s" \
    $hardware_name $sample $elapsed_ms $status_norm $status_si $status_phy_ready \
    $status_link $status_link_ok $status_time_valid $status_pps_valid \
    $status_rx_ready $status_tx_ready $pps_cr $pps_escr $pps_cr_enable \
    $escr_pps_valid $escr_tm_valid $ptp $ptp_state $ptp_meta $sstat \
    $servo_state $ucnt $ucnt_value $cko $cko_value $foreign_meta $parse_meta \
    $pstat $pstat_locked $spll_helper_state $helper_locked $spll_main_state \
    $main_enabled $main_locked $main_freq_locked $main_phase_locked $step5_locked \
    $ptp_rx $ptp_tx $boot_generation $cpu_reset_count $wr_core_reset_count \
    $si_config_drop_count $boot_changed $reset_changed $live $live_tai_lo \
    $live_cycles $snapshot_tai $snapshot_cycles $snapshot_time_valid \
    $snapshot_pps_valid $snapshot_valid $snapshot_count $snapshot_increased \
    $snapshot_delta_from_baseline $ucnt_increased $links_healthy $servo_complete \
    $::tmvalid_recovery_streak($hardware_name) \
    $::tmvalid_mapping_streak($hardware_name) \
    $::tmvalid_timing_output_streak($hardware_name) \
    $::tmvalid_ptp_servo_streak($hardware_name) $stop_candidate]
  flush stdout
  return $stop_candidate
}

puts [format "TMVALID_ATTRIBUTION_CONFIG duration_ms=%d sample_ms=%d board_filter=%s read_only=1 reprogram=0 power_cycle=0 reference_clock_hz=125000000" \
      $duration_ms $sample_ms $board_filter]
flush stdout

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} {
    continue
  }
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} {
    puts "TMVALID_SKIP board=${hardware_name} reason=no_device"
    continue
  }
  set device_name [lindex $devices 0]
  puts "=== ${hardware_name} ==="
  puts [format "TMVALID_DEVICE board=%s device=%s" $hardware_name $device_name]
  flush stdout
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle

    # Capture the baseline from the same first sample.  This is evidence, not
    # a control action, and gives reset changes an explicit reference.
    set begin_ms [clock milliseconds]
    set deadline_ms [expr {$begin_ms + $duration_ms}]
    set sample 0
    set first_stop NONE
    while {[clock milliseconds] <= $deadline_ms} {
      set elapsed_ms [expr {[clock milliseconds] - $begin_ms}]
      set stop_candidate [tmvalid_capture $hardware_name $sample $elapsed_ms]
      if {$first_stop eq "NONE" && $stop_candidate ne "NONE"} {
        set first_stop $stop_candidate
      }
      if {$stop_candidate ne "NONE"} {
        puts [format "TMVALID_STOP board=%s sample=%03d elapsed_ms=%d reason=%s" \
              $hardware_name $sample $elapsed_ms $stop_candidate]
        break
      }
      incr sample
      after $sample_ms
    }
    if {$first_stop eq "NONE"} { set first_stop TIME_LIMIT }
    puts [format "TMVALID_DONE board=%s samples=%d elapsed_ms=%d stop_reason=%s" \
          $hardware_name [expr {$sample + 1}] \
          [expr {[clock milliseconds] - $begin_ms}] $first_stop]
    flush stdout
  } error_message]} {
    puts "TMVALID_ERROR board=${hardware_name} message=${error_message}"
    flush stdout
  }
  catch { end_insystem_source_probe }
}

puts [format "TMVALID_TRANSPORT timeout_count=%d invalid_count=%d stale_count=%d unstable_count=%d" \
      $::wb_timeout_count $::wb_invalid_count $::wb_stale_count \
      $::wb_unstable_transaction_count]
puts "TMVALID_ATTRIBUTION_DONE"
flush stdout
