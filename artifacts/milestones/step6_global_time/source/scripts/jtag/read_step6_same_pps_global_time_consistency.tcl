# Step6A-2: compare Master/Slave frozen PPS snapshots by common TAI label.
#
# This is a read-only observer.  It deliberately uses only the status probes,
# coherent Global-Time snapshot probes 63/62/63, reset counters, and the
# source-backed SoftPLL lock shadows needed by the precondition gate.  It does
# not pair records by host sample index or by local snapshot count.
#
# Usage:
#   quartus_stp -t read_step6_same_pps_global_time_consistency.tcl \
#     EXP-ID ?gate_samples? ?gate_gap_ms? ?duration_ms? ?capture_gap_ms?

package require ::quartus::insystem_source_probe

set ::wf_library_only 1
source [file join [file dirname [info script]] \
  read_step6_wr_extension_fallback_terminal_liveness.tcl]

set ::s6a2_trial_id "EXP-S6-SAME-PPS-GLOBAL-TIME-CONSISTENCY-20260922"
set ::s6a2_gate_samples 3
set ::s6a2_gate_gap_ms 350
set ::s6a2_duration_ms 20000
set ::s6a2_capture_gap_ms 250
if {[llength $argv] >= 1} { set ::s6a2_trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::s6a2_gate_samples [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set ::s6a2_gate_gap_ms [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::s6a2_duration_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set ::s6a2_capture_gap_ms [expr {int([lindex $argv 4])}] }
if {$::s6a2_gate_samples <= 0 || $::s6a2_gate_gap_ms < 0 ||
    $::s6a2_duration_ms <= 0 || $::s6a2_capture_gap_ms < 0} {
  error "invalid Step6A-2 arguments"
}

array set ::s6a2_previous_activity {}

proc s6a2_capture {hardware_name role sample elapsed_ms} {
  set activity_start [safe_probe_read 7]
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set word1_before [safe_probe_read 63]
  set word0 [safe_probe_read 62]
  set word1_after [safe_probe_read 63]
  set spll_state [wb_read 0x00100AA0]
  set pstat [wb_read 0x00100A0C]
  set main_state [wb_read 0x00100AC4]
  set activity_end [safe_probe_read 7]

  set read_valid 1
  foreach value [list $activity_start $status $entry $reset \
      $word1_before $word0 $word1_after $spll_state $pstat $main_state \
      $activity_end] {
    if {![wf_raw_valid $value]} { set read_valid 0 }
  }
  lassign [wf_reset_values $entry $reset] boot_generation cpu_reset_count \
    wr_core_reset_count si_config_drop_count
  foreach value [list $boot_generation $cpu_reset_count $wr_core_reset_count \
      $si_config_drop_count] {
    if {$value eq "INVALID"} { set read_valid 0 }
  }
  set reset_changed 0
  if {$read_valid} {
    set reset_changed [wf_reset_changed $hardware_name $boot_generation \
      $cpu_reset_count $wr_core_reset_count $si_config_drop_count]
  }

  lassign [wf_snapshot_fields $word0 $word1_after] snapshot_tai snapshot_cycles \
    snapshot_time_valid snapshot_pps_valid snapshot_valid snapshot_count
  set snapshot_stable [expr {$word1_before eq $word1_after ? 1 : 0}]

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
  set activity_start_value [wf_activity_count $activity_start]
  set activity_end_value [wf_activity_count $activity_end]
  set activity_changed [expr {$activity_start_value >= 0 &&
      $activity_end_value >= 0 && $activity_start_value != $activity_end_value}]
  if {[info exists ::s6a2_previous_activity($hardware_name)] &&
      $activity_end_value >= 0 &&
      $activity_end_value != $::s6a2_previous_activity($hardware_name)} {
    set activity_changed 1
  }
  set ::s6a2_previous_activity($hardware_name) $activity_end_value

  set spll_word [word32 $spll_state]
  set pstat_word [word32 $pstat]
  set main_word [word32 $main_state]
  set spll_seq [expr {$spll_word < 0 ? -1 : ($spll_word & 0xff)}]
  set pstat_locked [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]
  set main_locked [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]

  set link_healthy [expr {$status_si == 1 && $status_ready == 1 &&
      $status_rx_ready == 1 && $status_tx_ready == 1 &&
      $status_cpu_reset_n == 1 && $status_phy_reset == 0 &&
      $status_tx_disable == 0 && $status_tm_link == 1 &&
      $status_link_ok == 1}]
  set capture_healthy [expr {$link_healthy &&
      ($role ne "SLAVE" || ($rx_locked == 1 && $rx_pattern_ready == 1))}]
  set snapshot_accepted [expr {$read_valid && $snapshot_stable &&
      $snapshot_valid == 1 && $snapshot_time_valid == 1 &&
      $snapshot_pps_valid == 1 && $snapshot_cycles >= 0 &&
      $snapshot_cycles <= 124999999}]

  return [list ROLE $role BOARD $role SAMPLE $sample ELAPSED_MS $elapsed_ms \
    READ_VALID $read_valid LINK_HEALTHY $link_healthy CAPTURE_HEALTHY $capture_healthy \
    RESET_CHANGED $reset_changed STATUS_SI_CONFIG $status_si STATUS_WR_READY $status_ready \
    STATUS_TM_LINK_UP $status_tm_link STATUS_LINK_OK $status_link_ok \
    STATUS_TIME_VALID $status_time_valid STATUS_PPS_VALID $status_pps_valid \
    STATUS_RX_READY $status_rx_ready STATUS_TX_READY $status_tx_ready \
    STATUS_CPU_RESET_N $status_cpu_reset_n STATUS_PHY_RST $status_phy_reset \
    STATUS_PHY_TX_DISABLE $status_tx_disable RX_LOCKED_TO_DATA $rx_locked \
    RX_PATTERN_READY $rx_pattern_ready RX_ACTIVITY_CHANGED $activity_changed \
    SNAPSHOT_STABLE $snapshot_stable SNAPSHOT_ACCEPTED $snapshot_accepted \
    SNAPSHOT_VALID $snapshot_valid SNAPSHOT_TIME_VALID $snapshot_time_valid \
    SNAPSHOT_PPS_VALID $snapshot_pps_valid SNAPSHOT_COUNT $snapshot_count \
    SNAPSHOT_TAI $snapshot_tai SNAPSHOT_CYCLES $snapshot_cycles \
    SNAPSHOT_RAW0 [wf_probe64 $word0] SNAPSHOT_RAW1_BEFORE [wf_probe64 $word1_before] \
    SNAPSHOT_RAW1_AFTER [wf_probe64 $word1_after] \
    SPLL_SEQ_STATE $spll_seq PSTAT_LOCKED $pstat_locked MAIN_LOCKED $main_locked \
    BOOT_GENERATION $boot_generation CPU_RESET_COUNT $cpu_reset_count \
    WR_CORE_RESET_COUNT $wr_core_reset_count SI_CONFIG_DROP_COUNT $si_config_drop_count]
}

proc s6a2_open_board {hardware_name} {
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { error "no device for $hardware_name" }
  catch {end_insystem_source_probe}
  start_insystem_source_probe -hardware_name $hardware_name \
    -device_name [lindex $devices 0]
  wb_sync_toggle
}

proc s6a2_collect {hardware_name role sample elapsed_ms} {
  set snapshot {}
  if {[catch {
    s6a2_open_board $hardware_name
    set snapshot [s6a2_capture $hardware_name $role $sample $elapsed_ms]
  } error_message]} {
    set snapshot {}
  }
  catch {end_insystem_source_probe}
  return $snapshot
}

proc s6a2_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc s6a2_gate {snapshot role} {
  if {$snapshot eq ""} { return 0 }
  array set s $snapshot
  if {$s(READ_VALID) != 1 || $s(CAPTURE_HEALTHY) != 1 ||
      $s(LINK_HEALTHY) != 1 || $s(RESET_CHANGED) != 0 ||
      $s(STATUS_TIME_VALID) != 1 || $s(STATUS_PPS_VALID) != 1 ||
      $s(SNAPSHOT_ACCEPTED) != 1} { return 0 }
  if {$role eq "SLAVE" && ($s(RX_LOCKED_TO_DATA) != 1 ||
      $s(RX_PATTERN_READY) != 1 || $s(SPLL_SEQ_STATE) != 8 ||
      $s(PSTAT_LOCKED) != 1 || $s(MAIN_LOCKED) != 1)} { return 0 }
  return 1
}

proc s6a2_update_map {snapshot role} {
  array set s $snapshot
  if {$s(SNAPSHOT_ACCEPTED) != 1} { return [list 0 0] }
  set tai $s(SNAPSHOT_TAI)
  set cycles $s(SNAPSHOT_CYCLES)
  if {$role eq "MASTER"} {
    if {[info exists ::s6a2_master_tai($tai)] &&
        $::s6a2_master_tai($tai) != $cycles} { return [list 1 1] }
    set ::s6a2_master_tai($tai) $cycles
  } else {
    if {[info exists ::s6a2_slave_tai($tai)] &&
        $::s6a2_slave_tai($tai) != $cycles} { return [list 1 1] }
    set ::s6a2_slave_tai($tai) $cycles
  }
  return [list 1 0]
}

proc s6a2_common_update {} {
  set common_new 0
  set mismatch 0
  foreach tai [array names ::s6a2_master_tai] {
    if {![info exists ::s6a2_slave_tai($tai)] ||
        [info exists ::s6a2_common_tai($tai)]} { continue }
    set ::s6a2_common_tai($tai) 1
    set common_new 1
    set delta [expr {$::s6a2_slave_tai($tai) - $::s6a2_master_tai($tai)}]
    set ::s6a2_common_delta($tai) $delta
    if {$delta != 0} { set mismatch 1 }
  }
  return [list $common_new $mismatch]
}

proc s6a2_run {} {
  set master_hardware ""
  set slave_hardware ""
  foreach hardware_name [get_hardware_names] {
    if {[string first "1-11.1" $hardware_name] >= 0} {
      set master_hardware $hardware_name
    } elseif {[string first "1-11.2" $hardware_name] >= 0} {
      set slave_hardware $hardware_name
    }
  }
  if {$master_hardware eq "" || $slave_hardware eq ""} {
    error "both DE5a targets are required"
  }

  puts [format "S6A2_CONFIG trial=%s gate_samples=%d gate_gap_ms=%d duration_ms=%d capture_gap_ms=%d MASTER_COMPILE=0 SLAVE_COMPILE=0 MASTER_PROGRAM=0 SLAVE_PROGRAM=0 POWER_CYCLE=0 CPU_RESET=0 WR_CORE_RESET=0 PHY_RESET=0 MASTER_PTP_RESTART=0 SLAVE_PTP_RESTART=0 MODE_COMMAND=0 FIBER_QSFP_CHANGE=0 AUTONEG_CHANGE=0 SI5340_CHANGE=0 MDIO_WRITE=0" \
    $::s6a2_trial_id $::s6a2_gate_samples $::s6a2_gate_gap_ms \
    $::s6a2_duration_ms $::s6a2_capture_gap_ms]
  flush stdout

  set gate_all 1
  set gate_transport 0
  set gate_reset_changed 0
  set gate_begin_ms [clock milliseconds]
  for {set sample 0} {$sample < $::s6a2_gate_samples} {incr sample} {
    set elapsed [expr {[clock milliseconds] - $gate_begin_ms}]
    set master [s6a2_collect $master_hardware MASTER $sample $elapsed]
    set slave [s6a2_collect $slave_hardware SLAVE $sample $elapsed]
    if {$master eq "" || $slave eq ""} {
      set gate_all 0
      set gate_transport 1
      s6a2_emit S6A2_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 0 MASTER_GATE 0 SLAVE_GATE 0]
    } else {
      array set m $master
      array set s $slave
      set master_good [s6a2_gate $master MASTER]
      set slave_good [s6a2_gate $slave SLAVE]
      if {$m(RESET_CHANGED) || $s(RESET_CHANGED)} { set gate_reset_changed 1 }
      if {$m(READ_VALID) != 1 || $s(READ_VALID) != 1} { set gate_transport 1 }
      set gate_all [expr {$gate_all && $master_good && $slave_good &&
          !$m(RESET_CHANGED) && !$s(RESET_CHANGED)}]
      s6a2_emit S6A2_GATE_SAMPLE $master
      s6a2_emit S6A2_GATE_SAMPLE $slave
      s6a2_emit S6A2_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 1 MASTER_GATE $master_good SLAVE_GATE $slave_good \
        MASTER_TAI $m(SNAPSHOT_TAI) SLAVE_TAI $s(SNAPSHOT_TAI) \
        MASTER_CYCLES $m(SNAPSHOT_CYCLES) SLAVE_CYCLES $s(SNAPSHOT_CYCLES)]
    }
    if {$sample + 1 < $::s6a2_gate_samples} { after $::s6a2_gate_gap_ms }
  }

  if {$gate_transport || $gate_reset_changed || !$gate_all} {
    puts "S6A2_GATE_RESULT=INCONCLUSIVE_STEP6A2_PRECONDITION_CHANGED"
    puts "S6A2_DONE result=INCONCLUSIVE_STEP6A2_PRECONDITION_CHANGED phase=gate"
    flush stdout
    return
  }
  puts [format "S6A2_GATE_RESULT=PASS SAMPLES=%d" $::s6a2_gate_samples]
  flush stdout

  array set ::s6a2_master_tai {}
  array set ::s6a2_slave_tai {}
  array set ::s6a2_common_tai {}
  array set ::s6a2_common_delta {}
  set begin_ms [clock milliseconds]
  set deadline_ms [expr {$begin_ms + $::s6a2_duration_ms}]
  set sample 0
  set runtime_invalid 0
  set coherence_violation 0
  set stability_regression 0
  set formal_pass 0
  set mismatch_seen 0
  set mismatch_labels 0
  set previous_valid_master 1
  set previous_valid_slave 1
  set post_loss_remaining -1
  set loss_detected 0
  set stop_now 0

  while {!$stop_now && [clock milliseconds] <= $deadline_ms} {
    set elapsed [expr {[clock milliseconds] - $begin_ms}]
    set master [s6a2_collect $master_hardware MASTER $sample $elapsed]
    set slave [s6a2_collect $slave_hardware SLAVE $sample $elapsed]
    if {$master eq "" || $slave eq ""} {
      set runtime_invalid 1
      s6a2_emit S6A2_SAMPLE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed READ_VALID 0]
      break
    }
    array set m $master
    array set s $slave
    set master_valid [expr {$m(STATUS_TIME_VALID) == 1 &&
        $m(SNAPSHOT_VALID) == 1}]
    set slave_valid [expr {$s(STATUS_TIME_VALID) == 1 &&
        $s(SNAPSHOT_VALID) == 1}]
    set loss_now 0
    if {($previous_valid_master && !$master_valid) ||
        ($previous_valid_slave && !$slave_valid)} {
      set stability_regression 1
      set loss_detected 1
      set loss_now 1
      set post_loss_remaining 3
    }
    set previous_valid_master $master_valid
    set previous_valid_slave $slave_valid

    lassign [s6a2_update_map $master MASTER] master_updated master_coherence
    lassign [s6a2_update_map $slave SLAVE] slave_updated slave_coherence
    if {$master_coherence || $slave_coherence} { set coherence_violation 1 }
    lassign [s6a2_common_update] common_new mismatch_now
    if {$mismatch_now} {
      if {!$mismatch_seen} {
        set mismatch_seen 1
        set mismatch_labels 1
      } else {
        incr mismatch_labels
      }
    } elseif {$mismatch_seen && $common_new} {
      incr mismatch_labels
    }
    set common_count [array size ::s6a2_common_tai]
    set exact_count 0
    set max_abs_delta 0
    foreach tai [array names ::s6a2_common_delta] {
      set delta [expr {abs($::s6a2_common_delta($tai))}]
      if {$delta == 0} { incr exact_count }
      if {$delta > $max_abs_delta} { set max_abs_delta $delta }
    }
    if {$common_count >= 5 && !$mismatch_seen} { set formal_pass 1 }

    s6a2_emit S6A2_SAMPLE [concat $master \
      [list COMMON_TAI_COUNT $common_count EXACT_MATCH_COUNT $exact_count \
       MAX_ABS_DELTA_TICKS $max_abs_delta MISMATCH_LABELS $mismatch_labels]]
    s6a2_emit S6A2_SAMPLE [concat $slave \
      [list COMMON_TAI_COUNT $common_count EXACT_MATCH_COUNT $exact_count \
       MAX_ABS_DELTA_TICKS $max_abs_delta MISMATCH_LABELS $mismatch_labels]]
    s6a2_emit S6A2_SAMPLE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
      READ_VALID 1 MASTER_VALID $master_valid SLAVE_VALID $slave_valid \
      COMMON_TAI_COUNT $common_count EXACT_MATCH_COUNT $exact_count \
      MAX_ABS_DELTA_TICKS $max_abs_delta MISMATCH_LABELS $mismatch_labels \
      POST_LOSS_REMAINING $post_loss_remaining]
    incr sample

    if {$m(READ_VALID) != 1 || $s(READ_VALID) != 1 ||
        !$m(CAPTURE_HEALTHY) || !$s(CAPTURE_HEALTHY) ||
        $m(RESET_CHANGED) || $s(RESET_CHANGED) ||
        $m(STATUS_TM_LINK_UP) != 1 || $s(STATUS_TM_LINK_UP) != 1 ||
        $m(STATUS_LINK_OK) != 1 || $s(STATUS_LINK_OK) != 1 ||
        $s(RX_PATTERN_READY) != 1} {
      set runtime_invalid 1
      set stop_now 1
    } elseif {$coherence_violation} {
      set stop_now 1
    } elseif {$formal_pass} {
      set stop_now 1
    } elseif {$mismatch_seen && $mismatch_labels >= 3} {
      set stop_now 1
    } elseif {$loss_now} {
      set post_loss_remaining 3
    } elseif {$post_loss_remaining >= 0} {
      incr post_loss_remaining -1
      if {$post_loss_remaining <= 0} { set stop_now 1 }
    }
    if {!$stop_now && [clock milliseconds] <= $deadline_ms} {
      after $::s6a2_capture_gap_ms
    }
  }

  set common_count [array size ::s6a2_common_tai]
  set exact_count 0
  set max_abs_delta 0
  set deltas {}
  foreach tai [array names ::s6a2_common_delta] {
    set delta $::s6a2_common_delta($tai)
    lappend deltas $delta
    if {$delta == 0} { incr exact_count }
    if {[expr {abs($delta)}] > $max_abs_delta} {
      set max_abs_delta [expr {abs($delta)}]
    }
  }
  set result CAPTURE_COMPLETE
  if {$runtime_invalid} {
    set result INCONCLUSIVE_RUNTIME_STATE_CHANGED
  } elseif {$coherence_violation} {
    set result INCONCLUSIVE_SNAPSHOT_COHERENCE_VIOLATION
  } elseif {$stability_regression} {
    set result FAIL_STEP6A1_STABILITY_REGRESSION_DURING_STEP6A2
  } elseif {$formal_pass} {
    set result PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY
  } elseif {$mismatch_seen && $mismatch_labels >= 3} {
    set result FAIL_SAME_PPS_GLOBAL_TIME_OFFSET
  }
  puts [format "S6A2_CAPTURE_RESULT=%s SAMPLES=%d ELAPSED_MS=%d COMMON_TAI_COUNT=%d EXACT_MATCH_COUNT=%d MAX_ABS_DELTA_TICKS=%d MISMATCH_LABELS=%d DELTAS=%s" \
    $result $sample [expr {[clock milliseconds] - $begin_ms}] $common_count \
    $exact_count $max_abs_delta $mismatch_labels [join $deltas ,]]
  puts [format "S6A2_DONE result=%s phase=capture" $result]
  flush stdout
}

s6a2_run
