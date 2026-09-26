# Step6A-1: read-only tail validation after a late Global-Time recovery.
#
# This script sends no functional command.  It assumes the current FPGA and
# firmware runtime session is left untouched by the preceding recovery run.
# It performs a three-pair health gate and then observes both boards for at
# most 15 seconds, stopping early only for a formal pass, a defined late-loss
# result, or an invalid runtime state.
#
# Usage:
#   quartus_stp -t read_step6_global_time_late_recovery_tail_stability.tcl \
#     EXP-ID ?gate_samples? ?gate_gap_ms? ?duration_ms? ?capture_gap_ms?

package require ::quartus::insystem_source_probe

set ::wf_library_only 1
source [file join [file dirname [info script]] \
  read_step6_wr_extension_fallback_terminal_liveness.tcl]

set ::s6tail_trial_id "EXP-S6-GLOBAL-TIME-LATE-RECOVERY-TAIL-STABILITY-20260922"
set ::s6tail_gate_samples 3
set ::s6tail_gate_gap_ms 350
set ::s6tail_duration_ms 15000
set ::s6tail_capture_gap_ms 400
if {[llength $argv] >= 1} { set ::s6tail_trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::s6tail_gate_samples [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set ::s6tail_gate_gap_ms [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::s6tail_duration_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set ::s6tail_capture_gap_ms [expr {int([lindex $argv 4])}] }
if {$::s6tail_gate_samples <= 0 || $::s6tail_gate_gap_ms < 0 ||
    $::s6tail_duration_ms <= 0 || $::s6tail_capture_gap_ms < 0} {
  error "invalid tail-stability arguments"
}

proc s6tail_basic_health {snapshot role} {
  if {$snapshot eq ""} { return 0 }
  array set s $snapshot
  if {$s(READ_VALID) != 1 || $s(RESET_CHANGED) != 0 ||
      $s(CAPTURE_HEALTHY) != 1 || $s(LINK_HEALTHY) != 1} {
    return 0
  }
  if {$role eq "SLAVE" && ($s(RX_LOCKED_TO_DATA) != 1 ||
      $s(RX_PATTERN_READY) != 1 || $s(RX_ACTIVITY_CHANGED) != 1)} {
    return 0
  }
  return 1
}

proc s6tail_pll_ready {snapshot} {
  array set s $snapshot
  return [expr {$s(SPLL_SEQ_STATE) == 8 &&
      $s(PSTAT_LOCKED) == 1 && $s(MAIN_LOCKED) == 1}]
}

proc s6tail_terminal_fallback {snapshot} {
  array set s $snapshot
  return [expr {$s(STATUS_TIME_VALID) == 0 && $s(PTP_STATE) == 9 &&
      $s(PD_STATE) == 4 && $s(EXT_STATE) == 2 &&
      $s(WR_STATE_VALUE) == 0 && [s6tail_pll_ready $snapshot]}]
}

proc s6tail_tick {snapshot} {
  array set s $snapshot
  if {$s(GLOBAL_TIME_LIVE_TAI_LO) < 0 ||
      $s(GLOBAL_TIME_LIVE_CYCLES) < 0 ||
      $s(GLOBAL_TIME_LIVE_CYCLES) > 124999999} {
    return -1
  }
  return [expr {$s(GLOBAL_TIME_LIVE_TAI_LO) * 125000000 +
      $s(GLOBAL_TIME_LIVE_CYCLES)}]
}

proc s6tail_candidate {snapshot previous_tick} {
  array set s $snapshot
  if {$s(STATUS_TIME_VALID) != 1 ||
      $s(GLOBAL_TIME_SNAPSHOT_STABLE) != 1 ||
      $s(GLOBAL_TIME_SNAPSHOT_VALID) != 1 ||
      $s(GLOBAL_TIME_SNAPSHOT_TIME_VALID) != 1 ||
      $s(GLOBAL_TIME_SNAPSHOT_PPS_VALID) != 1 ||
      $s(GLOBAL_TIME_CYCLES) < 0 ||
      $s(GLOBAL_TIME_CYCLES) > 124999999 ||
      ![s6tail_basic_health $snapshot SLAVE] ||
      $s(SPLL_SEQ_STATE) != 8 || $s(PSTAT_LOCKED) != 1 ||
      $s(MAIN_LOCKED) != 1} {
    return [list 0 -1]
  }
  set tick [s6tail_tick $snapshot]
  if {$tick < 0 || ($previous_tick >= 0 && $tick <= $previous_tick)} {
    return [list 0 $tick]
  }
  return [list 1 $tick]
}

proc s6tail_count_advances {counts} {
  set advances 0
  set previous ""
  foreach count $counts {
    if {$previous ne "" && $count > $previous} { incr advances }
    set previous $count
  }
  return $advances
}

proc s6tail_run {} {
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

  puts [format "S6_TAIL_CONFIG trial=%s gate_samples=%d gate_gap_ms=%d duration_ms=%d capture_gap_ms=%d MASTER_COMPILE=0 SLAVE_COMPILE=0 MASTER_PROGRAM=0 SLAVE_PROGRAM=0 POWER_CYCLE=0 CPU_RESET=0 WR_CORE_RESET=0 PHY_RESET=0 MASTER_PTP_RESTART=0 SLAVE_PTP_RESTART=0 MODE_COMMAND=0 FIBER_QSFP_CHANGE=0 AUTONEG_CHANGE=0 SI5340_CHANGE=0 MDIO_WRITE=0" \
    $::s6tail_trial_id $::s6tail_gate_samples $::s6tail_gate_gap_ms \
    $::s6tail_duration_ms $::s6tail_capture_gap_ms]
  flush stdout

  set gate_all 1
  set gate_transport 0
  set gate_reset_changed 0
  set gate_begin_ms [clock milliseconds]
  for {set sample 0} {$sample < $::s6tail_gate_samples} {incr sample} {
    set elapsed [expr {[clock milliseconds] - $gate_begin_ms}]
    set master [wf_collect $master_hardware MASTER $sample $elapsed]
    set slave [wf_collect $slave_hardware SLAVE $sample $elapsed]
    if {$master eq "" || $slave eq ""} {
      set gate_all 0
      set gate_transport 1
      wf_emit S6_TAIL_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 0 MASTER_HEALTH 0 SLAVE_HEALTH 0]
    } else {
      array set m $master
      array set s $slave
      set master_good [s6tail_basic_health $master MASTER]
      set slave_good [s6tail_basic_health $slave SLAVE]
      if {$m(RESET_CHANGED) || $s(RESET_CHANGED)} { set gate_reset_changed 1 }
      if {$m(READ_VALID) != 1 || $s(READ_VALID) != 1} { set gate_transport 1 }
      set gate_all [expr {$gate_all && $master_good && $slave_good &&
          !$m(RESET_CHANGED) && !$s(RESET_CHANGED)}]
      wf_emit S6_TAIL_GATE_SAMPLE $master
      wf_emit S6_TAIL_GATE_SAMPLE $slave
      wf_emit S6_TAIL_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 1 MASTER_HEALTH $master_good SLAVE_HEALTH $slave_good \
        MASTER_RESET_CHANGED $m(RESET_CHANGED) SLAVE_RESET_CHANGED $s(RESET_CHANGED) \
        SLAVE_TIME_VALID $s(STATUS_TIME_VALID) SLAVE_EXT_STATE $s(EXT_STATE) \
        SLAVE_WR_STATE $s(WR_STATE_VALUE)]
    }
    if {$sample + 1 < $::s6tail_gate_samples} { after $::s6tail_gate_gap_ms }
  }

  if {$gate_transport || $gate_reset_changed || !$gate_all} {
    puts "S6_TAIL_GATE_RESULT=INCONCLUSIVE_TAIL_PRECONDITION_CHANGED"
    puts "S6_TAIL_DONE result=INCONCLUSIVE_TAIL_PRECONDITION_CHANGED phase=gate"
    flush stdout
    return
  }
  puts [format "S6_TAIL_GATE_RESULT=PASS SAMPLES=%d" $::s6tail_gate_samples]
  flush stdout

  set begin_ms [clock milliseconds]
  set deadline_ms [expr {$begin_ms + $::s6tail_duration_ms}]
  set sample 0
  set runtime_invalid 0
  set formal_pass 0
  set terminal_stop 0
  set recovery_lost 0
  set post_loss_remaining -1
  set previous_time_valid -1
  set first_valid_ms -1
  set last_valid_ms -1
  set rising_edges 0
  set falling_edges 0
  set valid_streak 0
  set max_valid_streak 0
  set terminal_streak 0
  set max_terminal_streak 0
  set candidate_streak 0
  set candidate_counts {}
  set candidate_ticks {}
  set previous_candidate_tick -1
  set first_candidate_ms -1
  set last_candidate_ms -1
  set stop_now 0

  while {!$stop_now && [clock milliseconds] <= $deadline_ms} {
    set elapsed [expr {[clock milliseconds] - $begin_ms}]
    set slave [wf_collect $slave_hardware SLAVE $sample $elapsed]
    set master [wf_collect $master_hardware MASTER $sample $elapsed]
    if {$slave eq "" || $master eq ""} {
      set runtime_invalid 1
      wf_emit S6_TAIL_SAMPLE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed READ_VALID 0]
      break
    }
    array set s $slave
    array set m $master
    set current_time_valid $s(STATUS_TIME_VALID)
    set loss_detected_now 0
    if {$previous_time_valid >= 0 && $current_time_valid != $previous_time_valid} {
      if {$current_time_valid == 1} { incr rising_edges } else { incr falling_edges }
    }
    if {$current_time_valid == 1} {
      if {$first_valid_ms < 0} { set first_valid_ms $elapsed }
      set last_valid_ms $elapsed
      incr valid_streak
      set max_valid_streak [expr {max($max_valid_streak, $valid_streak)}]
    } else {
      if {$previous_time_valid == 1} {
        set recovery_lost 1
        set loss_detected_now 1
        set post_loss_remaining 3
      }
      set valid_streak 0
    }
    set previous_time_valid $current_time_valid

    if {[s6tail_terminal_fallback $slave]} {
      incr terminal_streak
      set max_terminal_streak [expr {max($max_terminal_streak, $terminal_streak)}]
    } else {
      set terminal_streak 0
    }

    lassign [s6tail_candidate $slave $previous_candidate_tick] candidate tick
    set count_advances 0
    if {$candidate} {
      if {$first_candidate_ms < 0} { set first_candidate_ms $elapsed }
      set last_candidate_ms $elapsed
      incr candidate_streak
      lappend candidate_counts $s(GLOBAL_TIME_SNAPSHOT_COUNT)
      lappend candidate_ticks $tick
      set previous_candidate_tick $tick
      if {[llength $candidate_counts] > 5} {
        set candidate_counts [lrange $candidate_counts end-4 end]
        set candidate_ticks [lrange $candidate_ticks end-4 end]
      }
      if {[llength $candidate_counts] >= 5} {
        set count_advances [s6tail_count_advances $candidate_counts]
        if {$candidate_streak >= 5 && $count_advances >= 2} {
          set formal_pass 1
        }
      }
    } else {
      set candidate_streak 0
      set candidate_counts {}
      set candidate_ticks {}
      set previous_candidate_tick -1
    }

    wf_emit S6_TAIL_SAMPLE [concat $slave [list \
      TIME_VALID_RISING_EDGES $rising_edges TIME_VALID_FALLING_EDGES $falling_edges \
      VALID_STREAK $valid_streak MAX_VALID_STREAK $max_valid_streak \
      TERMINAL_STREAK $terminal_streak MAX_TERMINAL_STREAK $max_terminal_streak \
      GLOBAL_TIME_TICK $tick TIME_RECOVERY_CANDIDATE $candidate \
      CANDIDATE_STREAK $candidate_streak SNAPSHOT_COUNT_ADVANCES_5 $count_advances \
      FIRST_VALID_MS $first_valid_ms LAST_VALID_MS $last_valid_ms \
      FIRST_CANDIDATE_MS $first_candidate_ms LAST_CANDIDATE_MS $last_candidate_ms]]
    wf_emit S6_TAIL_SAMPLE [concat $master [list \
      TIME_VALID_RISING_EDGES $rising_edges TIME_VALID_FALLING_EDGES $falling_edges \
      VALID_STREAK 0 MAX_VALID_STREAK $max_valid_streak \
      TERMINAL_STREAK 0 MAX_TERMINAL_STREAK $max_terminal_streak \
      GLOBAL_TIME_TICK -1 TIME_RECOVERY_CANDIDATE 0 CANDIDATE_STREAK 0 \
      SNAPSHOT_COUNT_ADVANCES_5 0 FIRST_VALID_MS $first_valid_ms \
      LAST_VALID_MS $last_valid_ms FIRST_CANDIDATE_MS $first_candidate_ms \
      LAST_CANDIDATE_MS $last_candidate_ms]]
    wf_emit S6_TAIL_SAMPLE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
      READ_VALID 1 TIME_VALID $current_time_valid \
      TIME_VALID_RISING_EDGES $rising_edges TIME_VALID_FALLING_EDGES $falling_edges \
      TIME_RECOVERY_CANDIDATE $candidate CANDIDATE_STREAK $candidate_streak \
      SNAPSHOT_COUNT_ADVANCES_5 $count_advances \
      TERMINAL_STREAK $terminal_streak POST_LOSS_REMAINING $post_loss_remaining]
    incr sample

    if {$s(READ_VALID) != 1 || $m(READ_VALID) != 1 ||
        !$s(CAPTURE_HEALTHY) || !$m(CAPTURE_HEALTHY) ||
        $s(RESET_CHANGED) || $m(RESET_CHANGED)} {
      set runtime_invalid 1
      set stop_now 1
    } elseif {$formal_pass} {
      set stop_now 1
    } elseif {$terminal_streak >= 5} {
      set terminal_stop 1
      set stop_now 1
    } elseif {$loss_detected_now} {
      # Keep the loss row plus three subsequent paired samples.
      set post_loss_remaining 3
    } elseif {$post_loss_remaining >= 0} {
      incr post_loss_remaining -1
      if {$post_loss_remaining <= 0} { set stop_now 1 }
    }
    if {!$stop_now && [clock milliseconds] <= $deadline_ms} {
      after $::s6tail_capture_gap_ms
    }
  }

  set result CAPTURE_COMPLETE
  if {$runtime_invalid} {
    set result INCONCLUSIVE_RUNTIME_STATE_CHANGED
  } elseif {$formal_pass} {
    set result PASS_LATE_RECOVERY_STABLE
  } elseif {$terminal_stop} {
    set result FAIL_LATE_RECOVERY_NOT_SUSTAINED
  } elseif {$recovery_lost} {
    set result FAIL_GLOBAL_TIME_RECOVERY_LOST
  }
  puts [format "S6_TAIL_CAPTURE_RESULT=%s SAMPLES=%d ELAPSED_MS=%d TIME_VALID_RISING_EDGES=%d TIME_VALID_FALLING_EDGES=%d MAX_VALID_STREAK=%d MAX_TERMINAL_STREAK=%d FIRST_VALID_MS=%d LAST_VALID_MS=%d FIRST_CANDIDATE_MS=%d LAST_CANDIDATE_MS=%d" \
    $result $sample [expr {[clock milliseconds] - $begin_ms}] \
    $rising_edges $falling_edges $max_valid_streak $max_terminal_streak \
    $first_valid_ms $last_valid_ms $first_candidate_ms $last_candidate_ms]
  puts [format "S6_TAIL_DONE result=%s phase=tail" $result]
  flush stdout
}

s6tail_run
