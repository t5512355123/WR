# Step6 fresh-Slave Arria-10 RX word-align acquisition observer.
#
# This observer is read-only.  It does not compile, program, reset, write MDIO,
# restart PTP, change polarity, change autonegotiation, or touch SoftPLL.
# The caller must perform the exact Slave-only programming step externally.
#
# Modes:
#   master-precondition : five local Master TX-side samples before Slave
#                         programming.  CORE_LINK_OK and CORE_TM_LINK_UP are
#                         recorded but deliberately are not gates.
#   word-align          : after Slave programming, wait for three consecutive
#                         local-ready samples, establish fresh sticky-counter
#                         baselines, then observe word alignment for at most
#                         ten seconds.
#
# Usage:
#   quartus_stp -t read_step6_slave_rx_word_align_fresh_acquisition.tcl \
#       ?trial_id? ?board_filter? ?samples? ?gap_ms? ?mode?

package require ::quartus::insystem_source_probe

set ::trial_id "S6-SLAVE-RX-WORD-ALIGN-FRESH-ACQUISITION"
set ::board_filter ""
set ::sample_limit 200
set ::gap_ms 100
set ::mode "word-align"
set ::max_duration_ms 10000
if {[llength $argv] >= 1} { set ::trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::board_filter [lindex $argv 1] }
if {[llength $argv] >= 3} { set ::sample_limit [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::gap_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set ::mode [lindex $argv 4] }
if {[llength $argv] >= 6} { set ::max_duration_ms [expr {int([lindex $argv 5])}] }
if {$::mode ni {master-precondition word-align}} {
  error "mode must be master-precondition or word-align"
}
if {$::sample_limit <= 0 || $::gap_ms < 0 || $::max_duration_ms <= 0} {
  error "sample_limit must be > 0, gap_ms must be >= 0, max_duration_ms must be > 0"
}

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

array set ::wa_baseline {}
array set ::wa_prev_rx_activity {}
array set ::wa_local_ready_streak {}
array set ::wa_alignment_streak {}
array set ::wa_no_lock_streak {}
array set ::wa_no_activity_streak {}
array set ::wa_alignment_seen {}
array set ::wa_sync_seen {}
array set ::wa_pattern_seen {}
array set ::wa_error_seen {}
array set ::wa_precondition_streak {}
array set ::wa_stop_reason {}
array set ::wa_sample_count {}
array set ::wa_valid_count {}
array set ::wa_error_count {}
array set ::wa_reset_baseline {}
array set ::wa_local_ready_pass_ms {}
array set ::wa_window_start_ms {}
array set ::wa_first_count {}

proc wa_raw_valid {value} {
  return [expr {$value ne "TIMEOUT" && $value ne "INVALID" &&
                $value ne "NA" && [is_hex $value]}]
}

proc wa_probe64 {value} {
  if {![wa_raw_valid $value]} { return $value }
  return [normalize_probe64 $value]
}

proc wa_hex32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  return [format %08X $word]
}

proc wa_field64 {value low width} {
  if {![wa_raw_valid $value] || $low < 0 || $width <= 0 ||
      $width > 32 || $low + $width > 64} {
    return -1
  }
  set low_word [probe_low32 $value]
  set high_word [probe_high32 $value]
  if {$low_word < 0 || $high_word < 0} { return -1 }
  set mask [expr {(1 << $width) - 1}]
  if {$low >= 32} {
    return [expr {($high_word >> ($low - 32)) & $mask}]
  }
  if {$low + $width <= 32} {
    return [expr {($low_word >> $low) & $mask}]
  }
  set low_width [expr {32 - $low}]
  set high_width [expr {$width - $low_width}]
  set low_mask [expr {(1 << $low_width) - 1}]
  set high_mask [expr {(1 << $high_width) - 1}]
  return [expr {(($low_word >> $low) & $low_mask) |
                (($high_word & $high_mask) << $low_width)}]
}

proc wa_counter_part {raw high} {
  if {$high} { return [probe_high32 $raw] }
  return [word32 $raw]
}

proc wa_delta32 {before after} {
  # wa_counter_part already returns numeric 32-bit values.  Do not pass those
  # decimal values through word32(), whose transport helper interprets a
  # string as a hexadecimal probe word.
  if {[string is integer -strict $before]} {
    set a $before
  } else {
    set a [word32 $before]
  }
  if {[string is integer -strict $after]} {
    set b $after
  } else {
    set b [word32 $after]
  }
  if {$a < 0 || $b < 0} { return INVALID }
  if {$b < $a} { return DECREASED }
  return [expr {$b - $a}]
}

proc wa_reset_values {entry reset} {
  return [list \
    [probe_high_counter_hex $entry] \
    [probe_byte_counter_hex $reset 16] \
    [probe_byte_counter_hex $reset 24] \
    [probe_byte_counter_hex $reset 40]]
}

proc wa_numeric {value} {
  if {[string is integer -strict $value]} { return $value }
  return ""
}

proc wa_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc wa_sample {hardware_name role sample elapsed_ms} {
  set status [safe_probe_read 0]
  set clock [safe_probe_read 7]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set ptp_meta [wb_read 0x00100A5C]
  set tx [wb_read 0x00100A18]
  set ptp_tx [wb_read 0x00100A58]
  set ecr [wb_read 0x00100100]

  set sticky45 "NA"
  set sticky46 "NA"
  set sticky47 "NA"
  set sticky48 "NA"
  if {$::mode eq "word-align"} {
    set sticky45 [safe_probe_read 45]
    set sticky46 [safe_probe_read 46]
    set sticky47 [safe_probe_read 47]
    set sticky48 [safe_probe_read 48]
  }

  set reset_values [wa_reset_values $entry $reset]
  lassign $reset_values boot_generation cpu_reset_count wr_core_reset_count \
    si_config_drop_count

  set read_valid 1
  foreach value [list $status $clock $entry $reset $ptp_meta $tx $ptp_tx $ecr] {
    if {![wa_raw_valid $value]} { set read_valid 0 }
  }
  if {$::mode eq "word-align"} {
    foreach value [list $sticky45 $sticky46 $sticky47 $sticky48] {
      if {![wa_raw_valid $value]} { set read_valid 0 }
    }
  }
  foreach value [list $boot_generation $cpu_reset_count $wr_core_reset_count \
      $si_config_drop_count] {
    if {$value eq "INVALID"} { set read_valid 0 }
  }

  set si_config_done [bit32 $status 0]
  set wr_ready [bit32 $status 1]
  set core_tm_link_up [bit32 $status 2]
  set core_link_ok [bit32 $status 3]
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

  # Instance 7 is a 64-bit packed activity probe.  RX activity is [47:32].
  set rx_activity_count [wa_field64 $clock 32 16]
  set ptp_word [word32 $ptp_meta]
  set ptp_state [expr {$ptp_word < 0 ? -1 : ($ptp_word & 0xff)}]
  set ecr_tx_en [bit32 $ecr 6]
  set ecr_rx_en [bit32 $ecr 7]

  set sticky45_enc -1
  set sticky45_disperr -1
  set sticky46_errdetect -1
  set sticky46_sync_loss -1
  set sticky47_lock_loss -1
  set sticky47_link_drop -1
  set sticky48_tm_link_drop -1
  if {$::mode eq "word-align" && $read_valid} {
    set sticky45_enc [wa_counter_part $sticky45 0]
    set sticky45_disperr [wa_counter_part $sticky45 1]
    set sticky46_errdetect [wa_counter_part $sticky46 0]
    set sticky46_sync_loss [wa_counter_part $sticky46 1]
    set sticky47_lock_loss [wa_counter_part $sticky47 0]
    set sticky47_link_drop [wa_counter_part $sticky47 1]
    set sticky48_tm_link_drop [wa_counter_part $sticky48 0]
    if {![info exists ::wa_first_count($hardware_name,enc)]} {
      set ::wa_first_count($hardware_name,enc) $sticky45_enc
      set ::wa_first_count($hardware_name,disperr) $sticky45_disperr
      set ::wa_first_count($hardware_name,errdetect) $sticky46_errdetect
      set ::wa_first_count($hardware_name,sync_loss) $sticky46_sync_loss
      set ::wa_first_count($hardware_name,lock_loss) $sticky47_lock_loss
      set ::wa_first_count($hardware_name,link_drop) $sticky47_link_drop
      set ::wa_first_count($hardware_name,tm_link_drop) $sticky48_tm_link_drop
    }
  }

  set first_enc_count -1
  set first_disperr_count -1
  set first_errdetect_count -1
  set first_sync_loss_count -1
  set first_lock_loss_count -1
  set first_link_drop_count -1
  if {$::mode eq "word-align" &&
      [info exists ::wa_first_count($hardware_name,enc)]} {
    set first_enc_count $::wa_first_count($hardware_name,enc)
    set first_disperr_count $::wa_first_count($hardware_name,disperr)
    set first_errdetect_count $::wa_first_count($hardware_name,errdetect)
    set first_sync_loss_count $::wa_first_count($hardware_name,sync_loss)
    set first_lock_loss_count $::wa_first_count($hardware_name,lock_loss)
    set first_link_drop_count $::wa_first_count($hardware_name,link_drop)
  }

  set boot_changed 0
  set reset_changed 0
  if {[info exists ::wa_reset_baseline($hardware_name)]} {
    set previous_reset $::wa_reset_baseline($hardware_name)
    set current_reset [list $boot_generation $cpu_reset_count \
      $wr_core_reset_count $si_config_drop_count]
    if {$current_reset ne $previous_reset} { set reset_changed 1 }
  } elseif {$read_valid} {
    set ::wa_reset_baseline($hardware_name) [list $boot_generation \
      $cpu_reset_count $wr_core_reset_count $si_config_drop_count]
  }

  set rx_activity_changed 0
  set rx_activity_delta INVALID
  if {[info exists ::wa_prev_rx_activity($hardware_name)]} {
    set previous_activity $::wa_prev_rx_activity($hardware_name)
    if {$previous_activity >= 0 && $rx_activity_count >= 0} {
      set rx_activity_changed [expr {($previous_activity & 0xffff) !=
        ($rx_activity_count & 0xffff)}]
      set rx_activity_delta [expr {(($rx_activity_count - $previous_activity) & 0xffff)}]
    }
  }
  set ::wa_prev_rx_activity($hardware_name) $rx_activity_count

  set local_ready [expr {$read_valid && $si_config_done == 1 &&
    $wr_ready == 1 && $rx_ready == 1 && $tx_ready == 1 &&
    $cpu_reset_n == 1 && $phy_rst == 0 && $phy_tx_disable == 0}]
  if {$local_ready} { incr ::wa_local_ready_streak($hardware_name) } \
  else { set ::wa_local_ready_streak($hardware_name) 0 }

  set local_ready_pass 0
  if {$::mode eq "word-align" &&
      $::wa_local_ready_streak($hardware_name) >= 3} {
    set local_ready_pass 1
  }

  if {$::mode eq "word-align" && $local_ready_pass &&
      ![info exists ::wa_local_ready_pass_ms($hardware_name)]} {
    set ::wa_local_ready_pass_ms($hardware_name) $elapsed_ms
    set ::wa_window_start_ms($hardware_name) $elapsed_ms
  }

  # Establish the fresh error-counter baseline at the first local-ready pass.
  set baseline_set 0
  set enc_delta INVALID
  set disperr_delta INVALID
  set errdetect_delta INVALID
  set sync_loss_delta INVALID
  set lock_loss_delta INVALID
  set link_drop_delta INVALID
  set tm_link_drop_delta INVALID
  if {$::mode eq "word-align" && $local_ready_pass &&
      ![info exists ::wa_baseline($hardware_name,enc)]} {
    set ::wa_baseline($hardware_name,enc) $sticky45_enc
    set ::wa_baseline($hardware_name,disperr) $sticky45_disperr
    set ::wa_baseline($hardware_name,errdetect) $sticky46_errdetect
    set ::wa_baseline($hardware_name,sync_loss) $sticky46_sync_loss
    set ::wa_baseline($hardware_name,lock_loss) $sticky47_lock_loss
    set ::wa_baseline($hardware_name,link_drop) $sticky47_link_drop
    set ::wa_baseline($hardware_name,tm_link_drop) $sticky48_tm_link_drop
    set baseline_set 1
    set enc_delta 0
    set disperr_delta 0
    set errdetect_delta 0
    set sync_loss_delta 0
    set lock_loss_delta 0
    set link_drop_delta 0
    set tm_link_drop_delta 0
  } elseif {$::mode eq "word-align" &&
      [info exists ::wa_baseline($hardware_name,enc)]} {
    set enc_delta [wa_delta32 $::wa_baseline($hardware_name,enc) $sticky45_enc]
    set disperr_delta [wa_delta32 $::wa_baseline($hardware_name,disperr) $sticky45_disperr]
    set errdetect_delta [wa_delta32 $::wa_baseline($hardware_name,errdetect) $sticky46_errdetect]
    set sync_loss_delta [wa_delta32 $::wa_baseline($hardware_name,sync_loss) $sticky46_sync_loss]
    set lock_loss_delta [wa_delta32 $::wa_baseline($hardware_name,lock_loss) $sticky47_lock_loss]
    set link_drop_delta [wa_delta32 $::wa_baseline($hardware_name,link_drop) $sticky47_link_drop]
    set tm_link_drop_delta [wa_delta32 $::wa_baseline($hardware_name,tm_link_drop) $sticky48_tm_link_drop]
  }

  set local_ready_pass_ms -1
  set word_align_window_start_ms -1
  set word_align_elapsed_ms -1
  if {$::mode eq "word-align" &&
      [info exists ::wa_local_ready_pass_ms($hardware_name)]} {
    set local_ready_pass_ms $::wa_local_ready_pass_ms($hardware_name)
    set word_align_window_start_ms $::wa_window_start_ms($hardware_name)
    set word_align_elapsed_ms [expr {$elapsed_ms - $word_align_window_start_ms}]
  }

  set counter_invalid 0
  foreach value [list $enc_delta $disperr_delta $errdetect_delta $sync_loss_delta \
      $lock_loss_delta $link_drop_delta $tm_link_drop_delta] {
    if {$value eq "INVALID" || $value eq "DECREASED"} { set counter_invalid 1 }
  }
  set new_error 0
  foreach value [list $rx_enc_err $rx_disperr $rx_errdetect $enc_delta \
      $disperr_delta $errdetect_delta $sync_loss_delta] {
    if {[wa_numeric $value] ne "" && $value > 0} { set new_error 1 }
  }

  set stop_candidate NONE
  set alignment_good 0
  set activity_present $rx_activity_changed
  set word_align_observed 0
  if {$::mode eq "master-precondition"} {
    set precondition_good [expr {$read_valid && $si_config_done == 1 &&
      $wr_ready == 1 && $tx_ready == 1 && $cpu_reset_n == 1 &&
      $phy_rst == 0 && $phy_tx_disable == 0 && $ptp_state == 6}]
    if {$precondition_good} { incr ::wa_precondition_streak($hardware_name) } \
    else { set ::wa_precondition_streak($hardware_name) 0 }
    if {!$read_valid} {
      set stop_candidate INCONCLUSIVE_MASTER_TX_PRECONDITION
    } elseif {$reset_changed} {
      set stop_candidate INCONCLUSIVE_MASTER_TX_PRECONDITION_RESET
    } elseif {$sample + 1 >= $::sample_limit} {
      if {$::wa_precondition_streak($hardware_name) >= $::sample_limit} {
        set stop_candidate PASS_MASTER_TX_PRECONDITION
      } else {
        set stop_candidate FAIL_MASTER_TX_PRECONDITION
      }
    }
  } else {
    if {!$read_valid} {
      set stop_candidate INCONCLUSIVE_TRANSPORT
    } elseif {$reset_changed} {
      set stop_candidate INCONCLUSIVE_RESET
    } elseif {$read_valid && [info exists ::wa_baseline($hardware_name,enc)] &&
        !$counter_invalid} {
      set word_align_observed 1
      set alignment_good [expr {$rx_locked_to_data == 1 &&
        $activity_present == 1 && $rx_syncstatus == 1 &&
        $rx_pattern_ready == 1 && $rx_enc_err == 0 &&
        $rx_disperr == 0 && $rx_errdetect == 0 &&
        $enc_delta == 0 && $disperr_delta == 0 &&
        $errdetect_delta == 0}]
      if {$alignment_good} { incr ::wa_alignment_streak($hardware_name) } \
      else { set ::wa_alignment_streak($hardware_name) 0 }
      if {$rx_syncstatus == 1 && $rx_pattern_ready == 1} {
        set ::wa_alignment_seen($hardware_name) 1
      }
      if {$rx_syncstatus == 1} { set ::wa_sync_seen($hardware_name) 1 }
      if {$rx_pattern_ready == 1} { set ::wa_pattern_seen($hardware_name) 1 }
      if {$new_error} { set ::wa_error_seen($hardware_name) 1 }
      if {$rx_locked_to_data == 1} { set ::wa_no_lock_streak($hardware_name) 0 } \
      else { incr ::wa_no_lock_streak($hardware_name) }
      if {$activity_present == 1} { set ::wa_no_activity_streak($hardware_name) 0 } \
      else { incr ::wa_no_activity_streak($hardware_name) }

      if {$::wa_alignment_streak($hardware_name) >= 5} {
        set stop_candidate PASS_WORD_ALIGN_ACQUISITION
      } elseif {$::wa_no_lock_streak($hardware_name) >= 5 ||
          $::wa_no_activity_streak($hardware_name) >= 5} {
        set stop_candidate FAIL_RX_CDR_OR_RECOVERED_CLOCK_REGRESSION
      } elseif {$::wa_alignment_seen($hardware_name) &&
          $rx_syncstatus == 0 && $new_error} {
        set stop_candidate FAIL_RX_WORD_ALIGNMENT_EARLY_LOSS_WITH_8B10B_ERRORS
      }
    } elseif {[info exists ::wa_baseline($hardware_name,enc)] && $counter_invalid} {
      set stop_candidate INCONCLUSIVE_COUNTER_BASELINE
    }

    if {$stop_candidate eq "NONE"} {
      if {$local_ready_pass_ms < 0 && $elapsed_ms >= $::max_duration_ms} {
        set stop_candidate FAIL_SLAVE_PHY_LOCAL_READY
      } elseif {$local_ready_pass_ms >= 0 &&
          $word_align_elapsed_ms >= $::max_duration_ms} {
        if {$first_sync_loss_count > 0 || $::wa_alignment_seen($hardware_name)} {
          set stop_candidate FAIL_RX_WORD_ALIGNMENT_EARLY_LOSS_WITH_8B10B_ERRORS
        } elseif {!$::wa_sync_seen($hardware_name) &&
            !$::wa_pattern_seen($hardware_name) &&
            $::wa_error_seen($hardware_name)} {
          set stop_candidate FAIL_RX_WORD_ALIGNMENT_NEVER_ACQUIRED_WITH_8B10B_ERRORS
        } else {
          set stop_candidate INCONCLUSIVE_MAX_CAPTURE
        }
      } elseif {$sample + 1 >= $::sample_limit} {
        # A sample safety cap is never a formal word-align failure.
        set stop_candidate INCONCLUSIVE_SAMPLE_CAP
      }
    }
  }

  if {$read_valid} { incr ::wa_valid_count($hardware_name) } \
  else { incr ::wa_error_count($hardware_name) }
  incr ::wa_sample_count($hardware_name)
  set ::wa_stop_reason($hardware_name) $stop_candidate

  wa_emit WORDALIGN_SAMPLE [list \
    ROLE $role BOARD $hardware_name SAMPLE $sample TIMESTAMP_MS $elapsed_ms \
    MODE $::mode READ_VALID $read_valid STATUS_RAW [wa_probe64 $status] \
    CLOCK_ACTIVITY_RAW [wa_probe64 $clock] ENTRY_RAW [wa_probe64 $entry] \
    RESET_STICKY_RAW [wa_probe64 $reset] SI_CONFIG_DONE $si_config_done \
    WR_READY $wr_ready RX_READY $rx_ready TX_READY $tx_ready CPU_RESET_N $cpu_reset_n \
    PHY_RST $phy_rst PHY_TX_DISABLE $phy_tx_disable CORE_TM_LINK_UP $core_tm_link_up \
    CORE_LINK_OK $core_link_ok RX_LOCKED_TO_DATA $rx_locked_to_data \
    RX_LOCKED_TO_REF $rx_locked_to_ref RX_CLOCK_ACTIVITY $rx_activity_count \
    RX_CLOCK_ACTIVITY_DELTA $rx_activity_delta RX_CLOCK_ACTIVITY_CHANGED $rx_activity_changed \
    RX_ENC_ERR $rx_enc_err RX_DISPERR $rx_disperr RX_ERRDETECT $rx_errdetect \
    RX_SYNCSTATUS $rx_syncstatus RX_PATTERNDETECT $rx_patterndetect \
    RX_PATTERN_READY $rx_pattern_ready RX_RUNNINGDISP $rx_runningdisp \
    RX_DATA $rx_data RX_DATA_K $rx_data_k RX_BITSLIDE $rx_bitslide PTP_STATE $ptp_state \
    WDIAGS_TX [wa_hex32 $tx] PTP_TX [wa_hex32 $ptp_tx] ECR_RAW [wa_hex32 $ecr] \
    ECR_TX_EN $ecr_tx_en ECR_RX_EN $ecr_rx_en BOOT_GENERATION $boot_generation \
    CPU_RESET_COUNT $cpu_reset_count WR_CORE_RESET_COUNT $wr_core_reset_count \
    SI_CONFIG_DROP_COUNT $si_config_drop_count STICKY45_RAW $sticky45 \
    STICKY46_RAW $sticky46 STICKY47_RAW $sticky47 STICKY48_RAW $sticky48 \
    ENC_ERR_COUNT $sticky45_enc DISPERR_COUNT $sticky45_disperr \
    ERRDETECT_COUNT $sticky46_errdetect SYNC_LOSS_COUNT $sticky46_sync_loss \
    LOCK_LOSS_COUNT $sticky47_lock_loss LINK_DROP_COUNT $sticky47_link_drop \
    TM_LINK_DROP_COUNT $sticky48_tm_link_drop FIRST_ENC_ERR_COUNT $first_enc_count \
    FIRST_DISPERR_COUNT $first_disperr_count FIRST_ERRDETECT_COUNT $first_errdetect_count \
    FIRST_SYNC_LOSS_COUNT $first_sync_loss_count FIRST_LOCK_LOSS_COUNT $first_lock_loss_count \
    FIRST_LINK_DROP_COUNT $first_link_drop_count \
    ENC_ERR_DELTA $enc_delta DISPERR_DELTA $disperr_delta ERRDETECT_DELTA $errdetect_delta \
    SYNC_LOSS_DELTA $sync_loss_delta LOCK_LOSS_DELTA $lock_loss_delta \
    LINK_DROP_DELTA $link_drop_delta TM_LINK_DROP_DELTA $tm_link_drop_delta \
    LOCAL_READY $local_ready LOCAL_READY_STREAK $::wa_local_ready_streak($hardware_name) \
    LOCAL_READY_PASS $local_ready_pass LOCAL_READY_PASS_TIMESTAMP_MS $local_ready_pass_ms \
    WORD_ALIGN_WINDOW_START_MS $word_align_window_start_ms WORD_ALIGN_ELAPSED_MS $word_align_elapsed_ms \
    BASELINE_SET $baseline_set \
    WORD_ALIGN_OBSERVED $word_align_observed ACTIVITY_PRESENT $activity_present \
    ALIGNMENT_GOOD $alignment_good ALIGNMENT_STREAK $::wa_alignment_streak($hardware_name) \
    RX_NO_LOCK_STREAK $::wa_no_lock_streak($hardware_name) \
    RX_NO_ACTIVITY_STREAK $::wa_no_activity_streak($hardware_name) \
    SYNC_SEEN $::wa_sync_seen($hardware_name) PATTERN_SEEN $::wa_pattern_seen($hardware_name) \
    ERROR_SEEN $::wa_error_seen($hardware_name) COUNTER_INVALID $counter_invalid \
    STOP_CANDIDATE $stop_candidate]
  return $stop_candidate
}

wa_emit WORDALIGN_CONFIG [list TRIAL $::trial_id BOARD_FILTER $::board_filter \
  MODE $::mode SAMPLES $::sample_limit GAP_MS $::gap_ms \
  MAX_CAPTURE_MS $::max_duration_ms READ_ONLY 1 \
  SLAVE_PROGRAMMED_EXTERNALLY 1 COMPILE 0 POWER_CYCLE 0 MDIO_WRITE 0]

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
  set ::wa_sample_count($hardware_name) 0
  set ::wa_valid_count($hardware_name) 0
  set ::wa_error_count($hardware_name) 0
  set ::wa_stop_reason($hardware_name) NONE
  set ::wa_local_ready_streak($hardware_name) 0
  set ::wa_alignment_streak($hardware_name) 0
  set ::wa_no_lock_streak($hardware_name) 0
  set ::wa_no_activity_streak($hardware_name) 0
  set ::wa_precondition_streak($hardware_name) 0
  set ::wa_alignment_seen($hardware_name) 0
  set ::wa_sync_seen($hardware_name) 0
  set ::wa_pattern_seen($hardware_name) 0
  set ::wa_error_seen($hardware_name) 0
  catch {end_insystem_source_probe}
  set begin_ms [clock milliseconds]
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    if {$::mode eq "word-align"} {
      # Allow up to 10 s for local-ready and then a separate 10 s word-align
      # window, with a small host/JTAG safety margin.  Formal failure is
      # decided inside wa_sample from WORD_ALIGN_ELAPSED_MS, never here.
      set deadline_ms [expr {$begin_ms + (2 * $::max_duration_ms) + 5000}]
    } else {
      set deadline_ms [expr {$begin_ms + $::max_duration_ms}]
    }
    for {set sample 0} {$sample < $::sample_limit} {incr sample} {
      set elapsed [expr {[clock milliseconds] - $begin_ms}]
      set stop_candidate [wa_sample $hardware_name $role $sample $elapsed]
      if {$stop_candidate ne "NONE"} { break }
      if {[clock milliseconds] >= $deadline_ms} {
        set ::wa_stop_reason($hardware_name) INCONCLUSIVE_SAFETY_DEADLINE
        break
      }
      if {$sample + 1 < $::sample_limit} { after $::gap_ms }
    }
    if {$::mode eq "word-align" && $::wa_stop_reason($hardware_name) eq "NONE"} {
      set ::wa_stop_reason($hardware_name) INCONCLUSIVE_MAX_CAPTURE
    }
  } error_message]} {
    incr ::wa_error_count($hardware_name)
    set ::wa_stop_reason($hardware_name) INCONCLUSIVE_EXCEPTION
    puts [format "WORDALIGN_ERROR ROLE=%s BOARD=%s MESSAGE=%s" $role $hardware_name $error_message]
  }
  catch {end_insystem_source_probe}
  wa_emit WORDALIGN_BOARD_DONE [list ROLE $role BOARD $hardware_name \
    SAMPLES $::wa_sample_count($hardware_name) VALID $::wa_valid_count($hardware_name) \
    ERRORS $::wa_error_count($hardware_name) STOP_REASON $::wa_stop_reason($hardware_name) \
    ELAPSED_MS [expr {[clock milliseconds] - $begin_ms}]]
}

if {!$::selected} { error "no matching DE5a target" }
wa_emit WORDALIGN_DONE [list TRIAL $::trial_id MODE $::mode]
