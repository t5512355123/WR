# Step6 post-Slave Endpoint/link attribution observer.
#
# This reader is intentionally passive.  It preserves the V2 failure session:
# no programming, compilation, power cycle, PTP restart, mode command, PHY
# reset, MDIO selector write, or SI5340 operation is performed here.
#
# The source-backed boundary is:
#   instance 0  -> WR status and raw RX/PCS indicators
#   instance 7  -> REF/DMTD/recovered-RX activity counters
#   instance 45..48 (Slave) -> sticky RX/link-loss attribution counters
#   0x00100100 -> Endpoint ECR (read-only; TX_EN bit 6, RX_EN bit 7)
#   0x00100138 -> Endpoint DSR (read-only; link bit 0, activity bit 1)
#
# Usage:
#   quartus_stp -t read_step6_post_slave_endpoint_link_attribution.tcl \
#       ?trial_id? ?board_filter? ?samples? ?gap_ms?
#
# Defaults are 120 samples at 500 ms (60 s maximum).  Run one board per
# quartus_stp process so the current Master and Slave failure state is captured
# independently without reprogramming either board.

package require ::quartus::insystem_source_probe

set ::trial_id "S6-POST-SLAVE-ENDPOINT-LINK-ATTRIBUTION"
set ::board_filter ""
set ::sample_limit 120
set ::gap_ms 500
if {[llength $argv] >= 1} { set ::trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::board_filter [lindex $argv 1] }
if {[llength $argv] >= 3} { set ::sample_limit [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::gap_ms [expr {int([lindex $argv 3])}] }
if {$sample_limit <= 0 || $gap_ms < 0} {
  error "sample_limit must be > 0 and gap_ms must be >= 0"
}

# Load only the validated read-only Wishbone/probe transport library.
set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

array set ::endpoint_baseline {}
array set ::endpoint_prev_rx_activity {}
array set ::endpoint_prev_sticky {}
array set ::endpoint_control_bad_streak {}
array set ::endpoint_no_lock_streak {}
array set ::endpoint_no_activity_streak {}
array set ::endpoint_phy_bad_streak {}
array set ::endpoint_raw_link_bad_streak {}
array set ::endpoint_link_good_streak {}
array set ::endpoint_stop_reason {}
array set ::endpoint_sample_count {}
array set ::endpoint_valid_count {}
array set ::endpoint_error_count {}

proc endpoint_raw_valid {value} {
  return [expr {$value ne "TIMEOUT" && $value ne "INVALID" &&
                $value ne "DECREASED" && [is_hex $value]}]
}

proc endpoint_hex32 {value} {
  set numeric [word32 $value]
  if {$numeric < 0} { return INVALID }
  return [format %08X $numeric]
}

proc endpoint_probe64 {value} {
  if {![endpoint_raw_valid $value]} { return $value }
  return [normalize_probe64 $value]
}

proc endpoint_counter_delta {before after} {
  set a [word32 $before]
  set b [word32 $after]
  if {$a < 0 || $b < 0} { return INVALID }
  if {$b < $a} { return DECREASED }
  return [expr {$b - $a}]
}

proc endpoint_counter_value {raw high} {
  if {$high} { return [probe_high32 $raw] }
  return [word32 $raw]
}

proc endpoint_reset_values {entry reset} {
  return [list \
    [probe_high_counter_hex $entry] \
    [probe_byte_counter_hex $reset 16] \
    [probe_byte_counter_hex $reset 24] \
    [probe_byte_counter_hex $reset 40]]
}

proc endpoint_same_or_changed {old new} {
  if {$old eq "" || $new eq "" || $old eq "INVALID" || $new eq "INVALID"} {
    return -1
  }
  return [expr {$old eq $new ? 0 : 1}]
}

proc endpoint_numeric {value} {
  if {[string is integer -strict $value]} { return $value }
  return ""
}

proc endpoint_sample {hardware_name role sample elapsed_ms} {
  set status [safe_probe_read 0]
  set clock [safe_probe_read 7]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]

  # All Wishbone reads below are passive reads.  In particular, do not add
  # MDIO reads: endpoint MDIO register selection is a write transaction.
  set ecr [wb_read 0x00100100]
  set dsr [wb_read 0x00100138]
  set ptp [wb_read 0x00100A10]
  set tx [wb_read 0x00100A18]
  set rx [wb_read 0x00100A1C]
  set rxerr [wb_read 0x00100A60]
  set ptp_rx [wb_read 0x00100A54]
  set ptp_tx [wb_read 0x00100A58]

  set sticky45 "NA"
  set sticky46 "NA"
  set sticky47 "NA"
  set sticky48 "NA"
  if {$role eq "SLAVE"} {
    set sticky45 [safe_probe_read 45]
    set sticky46 [safe_probe_read 46]
    set sticky47 [safe_probe_read 47]
    set sticky48 [safe_probe_read 48]
  }

  set reset_values [endpoint_reset_values $entry $reset]
  lassign $reset_values boot_generation cpu_reset_count wr_core_reset_count \
    si_config_drop_count

  set read_valid 1
  foreach value [list $status $clock $entry $reset $ecr $dsr $ptp $tx $rx \
      $rxerr $ptp_rx $ptp_tx] {
    if {![endpoint_raw_valid $value]} { set read_valid 0 }
  }
  if {$role eq "SLAVE"} {
    foreach value [list $sticky45 $sticky46 $sticky47 $sticky48] {
      if {![endpoint_raw_valid $value]} { set read_valid 0 }
    }
  }
  foreach value [list $boot_generation $cpu_reset_count $wr_core_reset_count \
      $si_config_drop_count] {
    if {$value eq "INVALID"} { set read_valid 0 }
  }

  # Instance 0 source mapping is defined in both DE5a_jtag top levels.
  set si_config_done [bit32 $status 0]
  set wr_ready [bit32 $status 1]
  set core_tm_link_up [bit32 $status 2]
  set core_link_ok [bit32 $status 3]
  set pps_valid [bit32 $status 5]
  set rx_ready [bit32 $status 6]
  set tx_ready [bit32 $status 7]
  set phy_tx_disable [bit32 $status 10]
  set phy_rst [bit32 $status 11]
  set rx_enc_err [bit32 $status 13]
  set cpu_reset_n [bit32 $status 15]
  set rx_data [field32 $status 16 8]
  set rx_bitslide [field32 $status 24 4]
  set rx_data_k [bit32 $status 28]
  set rx_runningdisp [bit64_high $status 7]
  set rx_pattern_ready [bit64_high $status 6]
  set rx_patterndetect [bit64_high $status 5]
  set rx_syncstatus [bit64_high $status 4]
  set rx_errdetect [bit64_high $status 3]
  set rx_disperr [bit64_high $status 2]
  set rx_locked_to_ref [bit64_high $status 1]
  set rx_locked_to_data [bit64_high $status 0]

  # Instance 7 source mapping is defined in the current Master/Slave image.
  set ref_activity_count [field32 $clock 0 16]
  set dmtd_activity_count [field32 $clock 16 16]
  set rx_activity_count [field32 $clock 32 16]

  set ecr_tx_en [bit32 $ecr 6]
  set ecr_rx_en [bit32 $ecr 7]
  set dsr_link [bit32 $dsr 0]
  set dsr_activity [bit32 $dsr 1]
  set ptp_state [field32 $ptp 0 8]

  set endpoint_control_good [expr {$ecr_tx_en == 1 && $ecr_rx_en == 1 &&
                                   $phy_rst == 0 && $phy_tx_disable == 0}]
  set direct_phy_error [expr {$rx_enc_err == 1 || $rx_disperr == 1 ||
                              $rx_errdetect == 1 || $rx_syncstatus == 0}]

  set sticky45_enc -1
  set sticky45_disperr -1
  set sticky46_errdetect -1
  set sticky46_sync_loss -1
  set sticky47_lock_loss -1
  set sticky47_link_drop -1
  set sticky48_tm_link_drop -1
  if {$role eq "SLAVE" && $read_valid} {
    set sticky45_enc [endpoint_counter_value $sticky45 0]
    set sticky45_disperr [endpoint_counter_value $sticky45 1]
    set sticky46_errdetect [endpoint_counter_value $sticky46 0]
    set sticky46_sync_loss [endpoint_counter_value $sticky46 1]
    set sticky47_lock_loss [endpoint_counter_value $sticky47 0]
    set sticky47_link_drop [endpoint_counter_value $sticky47 1]
    set sticky48_tm_link_drop [endpoint_counter_value $sticky48 0]
  }

  set rx_activity_delta INVALID
  if {[info exists ::endpoint_prev_rx_activity($hardware_name)]} {
    set rx_activity_delta [endpoint_counter_delta \
      $::endpoint_prev_rx_activity($hardware_name) $rx_activity_count]
  }
  set ::endpoint_prev_rx_activity($hardware_name) $rx_activity_count

  set sticky_error_delta 0
  set sticky_error_delta_valid 1
  if {$role eq "SLAVE" && $read_valid} {
    set current_sticky [list $sticky45_enc $sticky45_disperr $sticky46_errdetect \
      $sticky46_sync_loss $sticky47_lock_loss $sticky47_link_drop \
      $sticky48_tm_link_drop]
    if {[info exists ::endpoint_prev_sticky($hardware_name)]} {
      set previous_sticky $::endpoint_prev_sticky($hardware_name)
      foreach old $previous_sticky new $current_sticky {
        set delta [endpoint_counter_delta $old $new]
        if {$delta eq "INVALID" || $delta eq "DECREASED"} {
          set sticky_error_delta_valid 0
        } elseif {$delta > 0} {
          set sticky_error_delta 1
        }
      }
    }
    set ::endpoint_prev_sticky($hardware_name) $current_sticky
  }

  set rx_activity_increasing 0
  if {[endpoint_numeric $rx_activity_delta] ne "" && $rx_activity_delta > 0} {
    set rx_activity_increasing 1
  }
  set phy_input_unhealthy [expr {$direct_phy_error || $sticky_error_delta}]
  set raw_phy_healthy [expr {$endpoint_control_good &&
                             $rx_locked_to_data == 1 &&
                             $rx_activity_increasing == 1 &&
                             !$phy_input_unhealthy &&
                             $rx_syncstatus == 1}]
  set link_good [expr {$dsr_link == 1 && $core_tm_link_up == 1 &&
                       $core_link_ok == 1}]

  set boot_changed 0
  set reset_changed 0
  if {[info exists ::endpoint_baseline($hardware_name,boot)]} {
    if {$boot_generation ne $::endpoint_baseline($hardware_name,boot)} {
      set boot_changed 1
    }
    foreach pair [list [list cpu $cpu_reset_count] [list wr $wr_core_reset_count] \
        [list si $si_config_drop_count]] {
      set key [lindex $pair 0]
      set value [lindex $pair 1]
      if {$value ne $::endpoint_baseline($hardware_name,$key)} {
        set reset_changed 1
      }
    }
  } else {
    set ::endpoint_baseline($hardware_name,boot) $boot_generation
    set ::endpoint_baseline($hardware_name,cpu) $cpu_reset_count
    set ::endpoint_baseline($hardware_name,wr) $wr_core_reset_count
    set ::endpoint_baseline($hardware_name,si) $si_config_drop_count
  }

  if {$endpoint_control_good} { set ::endpoint_control_bad_streak($hardware_name) 0 } \
  else { incr ::endpoint_control_bad_streak($hardware_name) }
  if {$rx_locked_to_data == 1} { set ::endpoint_no_lock_streak($hardware_name) 0 } \
  else { incr ::endpoint_no_lock_streak($hardware_name) }
  if {$rx_activity_increasing} { set ::endpoint_no_activity_streak($hardware_name) 0 } \
  elseif {[endpoint_numeric $rx_activity_delta] ne ""} { incr ::endpoint_no_activity_streak($hardware_name) }
  if {$phy_input_unhealthy && $rx_locked_to_data == 1 && $rx_activity_increasing} { \
    incr ::endpoint_phy_bad_streak($hardware_name)
  } else { set ::endpoint_phy_bad_streak($hardware_name) 0 }
  if {$raw_phy_healthy && !$link_good} { incr ::endpoint_raw_link_bad_streak($hardware_name) } \
  else { set ::endpoint_raw_link_bad_streak($hardware_name) 0 }
  if {$link_good} { incr ::endpoint_link_good_streak($hardware_name) } \
  else { set ::endpoint_link_good_streak($hardware_name) 0 }

  set stop_candidate NONE
  if {!$read_valid} {
    set stop_candidate INCONCLUSIVE_TRANSPORT
  } elseif {$boot_changed || $reset_changed} {
    set stop_candidate INCONCLUSIVE_RESET
  } elseif {$::endpoint_link_good_streak($hardware_name) >= 5} {
    set stop_candidate PASS_LATE_RECOVERY
  } elseif {$::endpoint_control_bad_streak($hardware_name) >= 5} {
    set stop_candidate FAIL_ENDPOINT_CONTROL_NOT_ENABLED
  } elseif {$::endpoint_no_lock_streak($hardware_name) >= 5 ||
            $::endpoint_no_activity_streak($hardware_name) >= 5} {
    set stop_candidate FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED
  } elseif {$::endpoint_phy_bad_streak($hardware_name) >= 5} {
    set stop_candidate FAIL_PHY_PCS_INPUT_INTEGRITY
  } elseif {$::endpoint_raw_link_bad_streak($hardware_name) >= 10} {
    set stop_candidate FAIL_ENDPOINT_PCS_OR_AUTONEG_NOT_ESTABLISHED
  }
  set ::endpoint_stop_reason($hardware_name) $stop_candidate

  incr ::endpoint_sample_count($hardware_name)
  if {$read_valid} { incr ::endpoint_valid_count($hardware_name) } \
  else { incr ::endpoint_error_count($hardware_name) }

  puts [format "ENDPOINTLINK_SAMPLE ROLE=%s BOARD=%s SAMPLE=%03d TIMESTAMP_MS=%d READ_VALID=%d STATUS_RAW=%s CLOCK_ACTIVITY_RAW=%s ENTRY_RAW=%s RESET_STICKY_RAW=%s SI_CONFIG_DONE=%d WR_READY=%d CPU_RESET_N=%d PHY_RST=%d PHY_TX_DISABLE=%d RX_READY=%d TX_READY=%d CORE_TM_LINK_UP=%d CORE_LINK_OK=%d RX_LOCKED_TO_DATA=%d RX_LOCKED_TO_REF=%d RX_CLOCK_ACTIVITY=%d RX_CLOCK_ACTIVITY_DELTA=%s RX_ENC_ERR=%d RX_DISPERR=%d RX_ERRDETECT=%d RX_SYNCSTATUS=%d RX_PATTERNDETECT=%d RX_PATTERN_READY=%d RX_RUNNINGDISP=%d RX_DATA=%d RX_DATA_K=%d RX_BITSLIDE=%d PTP_STATE=%d WDIAGS_TX=%s WDIAGS_RX=%s WDIAGS_RXERR=%s PTP_RX=%s PTP_TX=%s BOOT_GENERATION=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s ECR_RAW=%s ECR_TX_EN=%d ECR_RX_EN=%d DSR_RAW=%s DSR_LINK=%d DSR_ACTIVITY=%d STICKY45_RAW=%s STICKY46_RAW=%s STICKY47_RAW=%s STICKY48_RAW=%s STICKY_ERROR_DELTA=%d STICKY_ERROR_DELTA_VALID=%d CONTROL_GOOD=%d PHY_INPUT_UNHEALTHY=%d RAW_PHY_HEALTHY=%d LINK_GOOD=%d BOOT_CHANGED=%d RESET_CHANGED=%d CONTROL_BAD_STREAK=%d RX_NO_LOCK_STREAK=%d RX_NO_ACTIVITY_STREAK=%d PHY_BAD_STREAK=%d RAW_LINK_BAD_STREAK=%d LINK_GOOD_STREAK=%d STOP_CANDIDATE=%s" \
    $role $hardware_name $sample $elapsed_ms $read_valid [endpoint_probe64 $status] \
    [endpoint_probe64 $clock] [endpoint_probe64 $entry] [endpoint_probe64 $reset] \
    $si_config_done $wr_ready \
    $cpu_reset_n $phy_rst $phy_tx_disable $rx_ready $tx_ready $core_tm_link_up \
    $core_link_ok $rx_locked_to_data $rx_locked_to_ref $rx_activity_count \
    $rx_activity_delta $rx_enc_err $rx_disperr $rx_errdetect $rx_syncstatus \
    $rx_patterndetect $rx_pattern_ready $rx_runningdisp $rx_data $rx_data_k \
    $rx_bitslide $ptp_state [endpoint_hex32 $tx] [endpoint_hex32 $rx] \
    [endpoint_hex32 $rxerr] [endpoint_hex32 $ptp_rx] [endpoint_hex32 $ptp_tx] \
    $boot_generation $cpu_reset_count $wr_core_reset_count $si_config_drop_count \
    [endpoint_hex32 $ecr] $ecr_tx_en $ecr_rx_en [endpoint_hex32 $dsr] $dsr_link \
    $dsr_activity $sticky45 $sticky46 $sticky47 $sticky48 $sticky_error_delta \
    $sticky_error_delta_valid $endpoint_control_good $phy_input_unhealthy \
    $raw_phy_healthy $link_good $boot_changed $reset_changed \
    $::endpoint_control_bad_streak($hardware_name) \
    $::endpoint_no_lock_streak($hardware_name) \
    $::endpoint_no_activity_streak($hardware_name) \
    $::endpoint_phy_bad_streak($hardware_name) \
    $::endpoint_raw_link_bad_streak($hardware_name) \
    $::endpoint_link_good_streak($hardware_name) $stop_candidate]
  flush stdout
  return $stop_candidate
}

puts [format "ENDPOINTLINK_CONFIG trial=%s board_filter=%s samples=%d gap_ms=%d max_capture_ms=%d read_only=1 reprogram=0 compile=0 power_cycle=0 mdio_write=0" \
  $::trial_id $::board_filter $::sample_limit $::gap_ms \
  [expr {$::sample_limit * $::gap_ms}]]
flush stdout

set ::endpoint_selected 0
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
  set ::endpoint_selected 1
  set ::endpoint_sample_count($hardware_name) 0
  set ::endpoint_valid_count($hardware_name) 0
  set ::endpoint_error_count($hardware_name) 0
  set ::endpoint_stop_reason($hardware_name) NONE
  set ::endpoint_control_bad_streak($hardware_name) 0
  set ::endpoint_no_lock_streak($hardware_name) 0
  set ::endpoint_no_activity_streak($hardware_name) 0
  set ::endpoint_phy_bad_streak($hardware_name) 0
  set ::endpoint_raw_link_bad_streak($hardware_name) 0
  set ::endpoint_link_good_streak($hardware_name) 0
  catch {end_insystem_source_probe}
  set begin_ms [clock milliseconds]
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    for {set sample 0} {$sample < $::sample_limit} {incr sample} {
      set elapsed [expr {[clock milliseconds] - $begin_ms}]
      set stop_candidate [endpoint_sample $hardware_name $role $sample $elapsed]
      if {$stop_candidate ne "NONE"} { break }
      if {$sample + 1 < $::sample_limit} { after $::gap_ms }
    }
  } error_message]} {
    incr ::endpoint_error_count($hardware_name)
    set ::endpoint_stop_reason($hardware_name) INCONCLUSIVE_EXCEPTION
    puts [format "ENDPOINTLINK_ERROR ROLE=%s BOARD=%s MESSAGE=%s" $role $hardware_name $error_message]
  }
  catch {end_insystem_source_probe}
  puts [format "ENDPOINTLINK_BOARD_DONE ROLE=%s BOARD=%s SAMPLES=%d VALID=%d ERRORS=%d STOP_REASON=%s ELAPSED_MS=%d" \
    $role $hardware_name $::endpoint_sample_count($hardware_name) \
    $::endpoint_valid_count($hardware_name) $::endpoint_error_count($hardware_name) \
    $::endpoint_stop_reason($hardware_name) [expr {[clock milliseconds] - $begin_ms}]]
  flush stdout
}

if {!$::endpoint_selected} { error "no matching DE5a target" }
puts "ENDPOINTLINK_DONE"
flush stdout
