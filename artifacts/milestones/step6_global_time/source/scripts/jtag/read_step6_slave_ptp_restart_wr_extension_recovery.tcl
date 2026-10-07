# Step6A-1: one Slave PTP restart, then observe WR-extension recovery.
#
# This experiment intentionally does not compile, program, reset, or power
# cycle either board.  Its only functional stimulus is exactly one normal
# Slave VUART "ptp stop\n" followed by one "ptp start\n".  All other reads
# reuse the validated runtime diagnostic shadows.
#
# Usage:
#   quartus_stp -t read_step6_slave_ptp_restart_wr_extension_recovery.tcl \
#     EXP-ID ?preflight_samples? ?pre_gap_ms? ?restart_gap_ms? \
#     ?rearm_timeout_ms? ?total_timeout_ms? ?capture_gap_ms?

package require ::quartus::insystem_source_probe

set ::wf_library_only 1
source [file join [file dirname [info script]] \
  read_step6_wr_extension_fallback_terminal_liveness.tcl]

set ::s6_trial_id "EXP-S6-SLAVE-PTP-RESTART-WR-EXTENSION-RECOVERY-20260922"
set ::s6_preflight_samples 5
set ::s6_pre_gap_ms 250
set ::s6_restart_gap_ms 100
set ::s6_rearm_timeout_ms 10000
set ::s6_total_timeout_ms 30000
set ::s6_capture_gap_ms 350
if {[llength $argv] >= 1} { set ::s6_trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::s6_preflight_samples [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set ::s6_pre_gap_ms [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::s6_restart_gap_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set ::s6_rearm_timeout_ms [expr {int([lindex $argv 4])}] }
if {[llength $argv] >= 6} { set ::s6_total_timeout_ms [expr {int([lindex $argv 5])}] }
if {[llength $argv] >= 7} { set ::s6_capture_gap_ms [expr {int([lindex $argv 6])}] }
if {$::s6_preflight_samples <= 0 || $::s6_pre_gap_ms < 0 ||
    $::s6_restart_gap_ms < 0 || $::s6_rearm_timeout_ms <= 0 ||
    $::s6_total_timeout_ms < $::s6_rearm_timeout_ms ||
    $::s6_capture_gap_ms < 0} {
  error "invalid recovery experiment arguments"
}

proc s6_gate_precondition {snapshot role} {
  if {$snapshot eq ""} { return 0 }
  array set s $snapshot
  if {$s(READ_VALID) != 1 || $s(RESET_CHANGED) != 0 ||
      $s(CAPTURE_HEALTHY) != 1 || $s(LINK_HEALTHY) != 1} {
    return 0
  }
  if {$role eq "MASTER"} {
    return [expr {$s(PTP_STATE) == 6 && $s(STATUS_TIME_VALID) == 1}]
  }
  return [expr {$s(RX_LOCKED_TO_DATA) == 1 &&
    $s(RX_PATTERN_READY) == 1 && $s(RX_ACTIVITY_CHANGED) == 1 &&
    $s(PTP_STATE) == 9 && $s(PD_STATE) == 4 && $s(EXT_STATE) == 2 &&
    $s(WRC_MODE) == 3 && $s(STATUS_TIME_VALID) == 0 &&
    $s(SPLL_MODE) == 3 && $s(SPLL_SEQ_STATE) == 8 &&
    $s(HELPER_LOCKED) == 1 && $s(PSTAT_LOCKED) == 1 &&
    $s(MAIN_ENABLED) == 1 && $s(MAIN_FREQ_LOCKED) == 1 &&
    $s(MAIN_PHASE_LOCKED) == 1 && $s(MAIN_LOCKED) == 1}]
}

proc s6_fresh_signal {snapshot id_key count_key baseline_count} {
  array set row $snapshot
  if {![info exists row($id_key)] || ![info exists row($count_key)]} {
    return 0
  }
  if {$row($id_key) != 4096 || $row($count_key) < 0} { return 0 }
  return [expr {$row($count_key) > $baseline_count}]
}

proc s6_slave_rearm {snapshot baseline} {
  array set row $snapshot
  set baseline_tx [lindex $baseline 1]
  return [expr {$row(EXT_STATE) == 1 &&
    ($row(WR_STATE_VALUE) != 0 ||
     [s6_fresh_signal $snapshot WR_TX_ID WR_TX_COUNT $baseline_tx])}]
}

proc s6_master_reengagement {snapshot baseline} {
  array set row $snapshot
  set baseline_rx [lindex $baseline 0]
  return [expr {$row(EXT_STATE) == 1 || $row(WR_STATE_VALUE) == 3 ||
    [s6_fresh_signal $snapshot WR_RX_ID WR_RX_COUNT $baseline_rx]}]
}

proc s6_time_candidate {snapshot} {
  array set row $snapshot
  return [expr {$row(READ_VALID) == 1 && $row(CAPTURE_HEALTHY) == 1 &&
    $row(STATUS_TIME_VALID) == 1 &&
    $row(GLOBAL_TIME_SNAPSHOT_STABLE) == 1 &&
    $row(GLOBAL_TIME_SNAPSHOT_VALID) == 1 &&
    $row(GLOBAL_TIME_SNAPSHOT_TIME_VALID) == 1 &&
    $row(GLOBAL_TIME_SNAPSHOT_PPS_VALID) == 1}]
}

proc s6_pll_ready {snapshot} {
  array set row $snapshot
  return [expr {$row(SPLL_SEQ_STATE) == 8 &&
    $row(PSTAT_LOCKED) == 1 && $row(MAIN_LOCKED) == 1}]
}

proc s6_count_advances {counts} {
  set advances 0
  set previous ""
  foreach count $counts {
    if {$previous ne "" && $count > $previous} { incr advances }
    set previous $count
  }
  return $advances
}

proc s6_run {} {
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

  puts [format "S6_PTP_RESTART_CONFIG trial=%s preflight_samples=%d pre_gap_ms=%d restart_gap_ms=%d rearm_timeout_ms=%d total_timeout_ms=%d capture_gap_ms=%d MASTER_COMPILE=0 SLAVE_COMPILE=0 MASTER_PROGRAM=0 SLAVE_PROGRAM=0 POWER_CYCLE=0 CPU_RESET=0 WR_CORE_RESET=0 PHY_RESET=0 MASTER_PTP_RESTART=0 SLAVE_PTP_RESTART=1 MODE_COMMAND=0 FIBER_QSFP_CHANGE=0 AUTONEG_CHANGE=0 SI5340_CHANGE=0 MDIO_WRITE=0" \
    $::s6_trial_id $::s6_preflight_samples $::s6_pre_gap_ms \
    $::s6_restart_gap_ms $::s6_rearm_timeout_ms $::s6_total_timeout_ms \
    $::s6_capture_gap_ms]
  flush stdout

  set gate_all 1
  set gate_transport 0
  set gate_reset_changed 0
  set last_master {}
  set last_slave {}
  set gate_begin_ms [clock milliseconds]
  for {set sample 0} {$sample < $::s6_preflight_samples} {incr sample} {
    set elapsed [expr {[clock milliseconds] - $gate_begin_ms}]
    set master [wf_collect $master_hardware MASTER $sample $elapsed]
    set slave [wf_collect $slave_hardware SLAVE $sample $elapsed]
    if {$master eq "" || $slave eq ""} {
      set gate_all 0
      set gate_transport 1
      wf_emit S6_PTP_RESTART_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 0 MASTER_PRECONDITION 0 SLAVE_PRECONDITION 0]
    } else {
      set last_master $master
      set last_slave $slave
      array set m $master
      array set s $slave
      set master_good [s6_gate_precondition $master MASTER]
      set slave_good [s6_gate_precondition $slave SLAVE]
      if {$m(RESET_CHANGED) || $s(RESET_CHANGED)} { set gate_reset_changed 1 }
      if {$m(READ_VALID) != 1 || $s(READ_VALID) != 1} { set gate_transport 1 }
      set gate_all [expr {$gate_all && $master_good && $slave_good &&
        !$m(RESET_CHANGED) && !$s(RESET_CHANGED)}]
      wf_emit S6_PTP_RESTART_GATE_SAMPLE $master
      wf_emit S6_PTP_RESTART_GATE_SAMPLE $slave
      wf_emit S6_PTP_RESTART_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 1 MASTER_PRECONDITION $master_good SLAVE_PRECONDITION $slave_good \
        MASTER_RESET_CHANGED $m(RESET_CHANGED) SLAVE_RESET_CHANGED $s(RESET_CHANGED) \
        MASTER_PTP_STATE $m(PTP_STATE) MASTER_TIME_VALID $m(STATUS_TIME_VALID) \
        SLAVE_PTP_STATE $s(PTP_STATE) SLAVE_PD_STATE $s(PD_STATE) \
        SLAVE_EXT_STATE $s(EXT_STATE) SLAVE_WRC_MODE $s(WRC_MODE) \
        SLAVE_TIME_VALID $s(STATUS_TIME_VALID) SLAVE_SPLL_SEQ $s(SPLL_SEQ_STATE) \
        SLAVE_PSTAT_LOCKED $s(PSTAT_LOCKED) SLAVE_MAIN_LOCKED $s(MAIN_LOCKED)]
    }
    if {$sample + 1 < $::s6_preflight_samples} { after $::s6_pre_gap_ms }
  }

  if {$gate_transport || $gate_reset_changed || !$gate_all} {
    puts "S6_PTP_RESTART_GATE_RESULT=INCONCLUSIVE_PRE_RESTART_STATE_CHANGED"
    puts "S6_PTP_RESTART_INJECTION_RESULT=NOT_PERFORMED"
    puts "S6_PTP_RESTART_DONE result=INCONCLUSIVE_PRE_RESTART_STATE_CHANGED phase=gate"
    flush stdout
    return
  }
  puts [format "S6_PTP_RESTART_GATE_RESULT=PASS SAMPLES=%d" $::s6_preflight_samples]
  flush stdout

  array set last_m $last_master
  array set last_s $last_slave
  set baseline_rx [list $last_m(WR_RX_COUNT) $last_s(WR_TX_COUNT)]
  set stop_ok 0
  if {[catch {
    wf_open_board $slave_hardware
    set stop_ok [wf_send_vuart $slave_hardware "ptp stop\n" STOP]
  } error_message]} {
    set stop_ok 0
  }
  catch {end_insystem_source_probe}

  set start_ok 0
  if {$stop_ok} {
    after $::s6_restart_gap_ms
    if {[catch {
      wf_open_board $slave_hardware
      set start_ok [wf_send_vuart $slave_hardware "ptp start\n" START]
    } error_message]} {
      set start_ok 0
    }
    catch {end_insystem_source_probe}
  }
  if {!$stop_ok || !$start_ok} {
    puts "S6_PTP_RESTART_INJECTION_RESULT=INCONCLUSIVE_COMMAND_TRANSPORT"
    puts [format "S6_PTP_RESTART_INJECTION_COUNTS SLAVE_PTP_STOP_COUNT=%d SLAVE_PTP_START_COUNT=%d MASTER_COMMAND_COUNT=0" \
      [expr {$stop_ok ? 1 : 0}] [expr {$start_ok ? 1 : 0}]]
    puts "S6_PTP_RESTART_DONE result=INCONCLUSIVE_COMMAND_TRANSPORT phase=injection"
    flush stdout
    return
  }
  puts "S6_PTP_RESTART_INJECTION_RESULT=PASS"
  puts "S6_PTP_RESTART_INJECTION_COUNTS SLAVE_PTP_STOP_COUNT=1 SLAVE_PTP_START_COUNT=1 MASTER_COMMAND_COUNT=0"
  flush stdout

  # PTP restart is expected to clear PTP/lock diagnostic counters.  Clear only
  # the observer's delta baselines; keep reset baselines so an actual reset is
  # still detected across the command.
  array unset ::wf_previous_counters *
  array unset ::wf_first_counters *
  array unset ::wf_previous_activity *
  puts "S6_PTP_RESTART_POST_RESTART_COUNTER_BASELINED=1"
  flush stdout

  set start_begin_ms [clock milliseconds]
  set deadline_ms [expr {$start_begin_ms + $::s6_total_timeout_ms}]
  set sample 0
  set first_sample_ms -1
  set runtime_invalid 0
  set softpll_bad_streak 0
  set softpll_failure 0
  set slave_rearmed_seen 0
  set master_reengaged_seen 0
  set handshake_rearmed 0
  set ever_time_candidate 0
  set best_time_streak 0
  set time_streak 0
  set candidate_counts {}
  set pass_recovery 0
  set stop_now 0

  while {!$stop_now && [clock milliseconds] <= $deadline_ms} {
    set elapsed [expr {[clock milliseconds] - $start_begin_ms}]
    set slave [wf_collect $slave_hardware SLAVE $sample $elapsed]
    set master [wf_collect $master_hardware MASTER $sample $elapsed]
    if {$slave eq "" || $master eq ""} {
      set runtime_invalid 1
      wf_emit S6_PTP_RESTART_SAMPLE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 0 FIRST_SAMPLE_AFTER_START_MS $first_sample_ms]
      break
    }
    if {$first_sample_ms < 0} { set first_sample_ms $elapsed }
    array set s $slave
    array set m $master
    set slave_rearmed [s6_slave_rearm $slave $baseline_rx]
    set master_reengaged [s6_master_reengagement $master $baseline_rx]
    if {$slave_rearmed} { set slave_rearmed_seen 1 }
    if {$master_reengaged} { set master_reengaged_seen 1 }
    if {$slave_rearmed || $s(WR_STATE_VALUE) == 2 ||
        $s(WR_LOCK_POLL_COUNT) > $last_s(WR_LOCK_POLL_COUNT)} {
      set handshake_rearmed 1
    }

    set slave_pll_ready [s6_pll_ready $slave]
    if {$slave_pll_ready} {
      set softpll_bad_streak 0
    } else {
      incr softpll_bad_streak
      if {$softpll_bad_streak >= 3} { set softpll_failure 1 }
    }

    set time_candidate [s6_time_candidate $slave]
    set count_advances_5 0
    if {$time_candidate} {
      set ever_time_candidate 1
      incr time_streak
      lappend candidate_counts $s(GLOBAL_TIME_SNAPSHOT_COUNT)
      if {[llength $candidate_counts] > 5} {
        set candidate_counts [lrange $candidate_counts end-4 end]
      }
      set best_time_streak [expr {max($best_time_streak, $time_streak)}]
      if {[llength $candidate_counts] >= 5} {
        set count_advances_5 [s6_count_advances $candidate_counts]
        if {$time_streak >= 5 && $count_advances_5 >= 2} {
          set pass_recovery 1
        }
      }
    } else {
      set time_streak 0
      set candidate_counts {}
    }

    wf_emit S6_PTP_RESTART_SAMPLE [concat $slave \
      [list SLAVE_REARM_EVIDENCE $slave_rearmed \
       MASTER_REENGAGEMENT_EVIDENCE $master_reengaged \
       SOFTPLL_READY $slave_pll_ready TIME_RECOVERY_CANDIDATE $time_candidate \
       TIME_CANDIDATE_STREAK $time_streak \
       SNAPSHOT_COUNT_ADVANCES_5 $count_advances_5 \
       HANDSHAKE_REARMED $handshake_rearmed]]
    wf_emit S6_PTP_RESTART_SAMPLE [concat $master \
      [list SLAVE_REARM_EVIDENCE 0 MASTER_REENGAGEMENT_EVIDENCE $master_reengaged \
       SOFTPLL_READY 0 TIME_RECOVERY_CANDIDATE 0 \
       TIME_CANDIDATE_STREAK 0 SNAPSHOT_COUNT_ADVANCES_5 0 \
       HANDSHAKE_REARMED $handshake_rearmed]]
    wf_emit S6_PTP_RESTART_SAMPLE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
      READ_VALID 1 FIRST_SAMPLE_AFTER_START_MS $first_sample_ms \
      SLAVE_REARM_EVIDENCE $slave_rearmed \
      MASTER_REENGAGEMENT_EVIDENCE $master_reengaged \
      SOFTPLL_BAD_STREAK $softpll_bad_streak \
      TIME_RECOVERY_CANDIDATE $time_candidate \
      TIME_CANDIDATE_STREAK $time_streak \
      SNAPSHOT_COUNT_ADVANCES_5 $count_advances_5]
    incr sample

    if {$s(READ_VALID) != 1 || $m(READ_VALID) != 1 ||
        $s(RESET_CHANGED) || $m(RESET_CHANGED) ||
        !$s(CAPTURE_HEALTHY) || !$m(CAPTURE_HEALTHY)} {
      set runtime_invalid 1
      set stop_now 1
    } elseif {$softpll_failure} {
      set stop_now 1
    } elseif {$pass_recovery} {
      set stop_now 1
    } elseif {$elapsed >= $::s6_rearm_timeout_ms && !$slave_rearmed_seen} {
      set stop_now 1
    } elseif {$elapsed >= $::s6_rearm_timeout_ms &&
        $slave_rearmed_seen && !$master_reengaged_seen} {
      set stop_now 1
    }
    if {!$stop_now && [clock milliseconds] <= $deadline_ms} {
      after $::s6_capture_gap_ms
    }
  }

  set result PASS_CAPTURE
  if {$runtime_invalid} {
    set result INCONCLUSIVE_RUNTIME_STATE_CHANGED
  } elseif {$softpll_failure} {
    set result FAIL_SLAVE_PTP_RESTART_DISTURBED_SOFTPLL_READY_STATE
  } elseif {$pass_recovery} {
    set result PASS_SLAVE_PTP_RESTART_WR_EXTENSION_RECOVERY
  } elseif {!$slave_rearmed_seen} {
    set result FAIL_SLAVE_PTP_RESTART_DID_NOT_REARM_WR_EXTENSION
  } elseif {!$master_reengaged_seen} {
    set result FAIL_SLAVE_REARMED_MASTER_NOT_REENGAGED
  } elseif {$handshake_rearmed && !$ever_time_candidate} {
    set result FAIL_WR_HANDSHAKE_REARMED_BUT_GLOBAL_TIME_NOT_RECOVERED
  } elseif {$ever_time_candidate} {
    set result FAIL_TRANSIENT_GLOBAL_TIME_RECOVERY
  } else {
    set result FAIL_WR_HANDSHAKE_REARMED_BUT_GLOBAL_TIME_NOT_RECOVERED
  }
  puts [format "S6_PTP_RESTART_CAPTURE_RESULT=%s SAMPLES=%d ELAPSED_MS=%d FIRST_SAMPLE_AFTER_START_MS=%d SLAVE_REARMED=%d MASTER_REENGAGED=%d BEST_TIME_STREAK=%d" \
    $result $sample [expr {[clock milliseconds] - $start_begin_ms}] \
    $first_sample_ms $slave_rearmed_seen $master_reengaged_seen $best_time_streak]
  puts [format "S6_PTP_RESTART_DONE result=%s phase=recovery" $result]
  flush stdout
}

s6_run
