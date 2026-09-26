# Step6B digital scheduled-trigger repeatability observer.
#
# This observer reuses one already-programmed, already-fired live session.  It
# deliberately performs no compile, programming, reset, PTP restart, or
# physical operation.  The only functional writes are exactly six source
# writes: ARM=0 on both boards, one new target on both boards, and ARM=1 on
# both boards.

package require ::quartus::insystem_source_probe

# Load the common Step6B read/capture helpers without starting its observer.
set ::s6b_no_autorun 1
set ::s6b_rearm_saved_argv $argv
set argv {}
source [file join [file dirname [info script]] \
  read_step6b_digital_scheduled_dual_board_trigger.tcl]
set argv $::s6b_rearm_saved_argv

set ::s6b_rearm_trial_id \
  "EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-REARM-REPEATABILITY-20260922"
set ::s6b_rearm_gate_timeout_ms 10000
set ::s6b_rearm_gate_gap_ms 300
set ::s6b_rearm_settle_ms 150
set ::s6b_rearm_arm_settle_ms 120
set ::s6b_rearm_capture_gap_ms 300
set ::s6b_rearm_capture_timeout_ms 40000
set ::s6b_rearm_previous_target_tai 3433
set ::s6b_rearm_target_cycles 62500000

if {[llength $argv] >= 1} { set ::s6b_rearm_trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} {
  set ::s6b_rearm_gate_timeout_ms [expr {int([lindex $argv 1])}]
}
if {[llength $argv] >= 3} {
  set ::s6b_rearm_gate_gap_ms [expr {int([lindex $argv 2])}]
}
if {[llength $argv] >= 4} {
  set ::s6b_rearm_capture_gap_ms [expr {int([lindex $argv 3])}]
}
if {[llength $argv] >= 5} {
  set ::s6b_rearm_capture_timeout_ms [expr {int([lindex $argv 4])}]
}
if {$::s6b_rearm_gate_timeout_ms <= 0 ||
    $::s6b_rearm_gate_gap_ms < 0 ||
    $::s6b_rearm_settle_ms < 120 ||
    $::s6b_rearm_arm_settle_ms < 120 ||
    $::s6b_rearm_capture_gap_ms < 200 ||
    $::s6b_rearm_capture_timeout_ms <= 0} {
  error "invalid Step6B rearm observation timing arguments"
}

proc s6b_rearm_init_state {} {
  set ::s6b_rearm_pre_gate_pairs 0
  set ::s6b_rearm_pre_common_tai_count 0
  set ::s6b_rearm_post_dearm_gate_pairs 0
  set ::s6b_rearm_post_dearm_common_tai_count 0
  set ::s6b_rearm_target_write_master 0
  set ::s6b_rearm_target_write_slave 0
  set ::s6b_rearm_arm0_write_master 0
  set ::s6b_rearm_arm0_write_slave 0
  set ::s6b_rearm_arm1_write_master 0
  set ::s6b_rearm_arm1_write_slave 0
  set ::s6b_rearm_new_target_tai NA
  set ::s6b_rearm_capture_samples 0
  set ::s6b_rearm_post_fire_samples 0
  set ::s6b_rearm_master_count NA
  set ::s6b_rearm_slave_count NA
  set ::s6b_rearm_master_actual_tai NA
  set ::s6b_rearm_slave_actual_tai NA
  set ::s6b_rearm_master_actual_cycles NA
  set ::s6b_rearm_slave_actual_cycles NA
  set ::s6b_rearm_delta_ticks NA
  set ::s6b_rearm_delta_ns NA
  set ::s6b_rearm_pre_gate_result NA
  set ::s6b_rearm_initial_result NA
  set ::s6b_rearm_dearm_result NA
  set ::s6b_rearm_post_dearm_gate_result NA
  set ::s6b_rearm_target_result NA
  set ::s6b_rearm_arm_result NA
  set ::s6b_rearm_capture_result NA
  set ::s6b_rearm_t0 NA
  set ::s6b_rearm_coherence_violation 0
  array set ::s6b_master_by_tai {}
  array set ::s6b_slave_by_tai {}
}

proc s6b_rearm_emit_result {result phase} {
  set ::s6b_rearm_capture_result $result
  puts [format "S6B_REARM_RESULT=%s PHASE=%s TRIAL=%s PRE_GATE_PAIRS=%s PRE_COMMON_TAI_COUNT=%s POST_DEARM_GATE_PAIRS=%s POST_DEARM_COMMON_TAI_COUNT=%s COHERENCE_VIOLATION=%s T0=%s NEW_TARGET_TAI=%s TARGET_CYCLES=%s PRE_GATE_RESULT=%s INITIAL_RESULT=%s DEARM_RESULT=%s POST_DEARM_GATE_RESULT=%s TARGET_RESULT=%s ARM_RESULT=%s CAPTURE_SAMPLES=%s POST_FIRE_SAMPLES=%s ARM0_WRITE_MASTER=%s ARM0_WRITE_SLAVE=%s TARGET_WRITE_MASTER=%s TARGET_WRITE_SLAVE=%s ARM1_WRITE_MASTER=%s ARM1_WRITE_SLAVE=%s MASTER_FIRE_COUNT=%s SLAVE_FIRE_COUNT=%s MASTER_ACTUAL_TAI=%s SLAVE_ACTUAL_TAI=%s MASTER_ACTUAL_CYCLES=%s SLAVE_ACTUAL_CYCLES=%s SECOND_TRIGGER_DELTA_TICKS=%s SECOND_TRIGGER_DELTA_NS=%s" \
    $result $phase $::s6b_rearm_trial_id $::s6b_rearm_pre_gate_pairs \
    $::s6b_rearm_pre_common_tai_count $::s6b_rearm_post_dearm_gate_pairs \
    $::s6b_rearm_post_dearm_common_tai_count $::s6b_rearm_coherence_violation \
    $::s6b_rearm_t0 $::s6b_rearm_new_target_tai $::s6b_rearm_target_cycles \
    $::s6b_rearm_pre_gate_result $::s6b_rearm_initial_result \
    $::s6b_rearm_dearm_result $::s6b_rearm_post_dearm_gate_result \
    $::s6b_rearm_target_result $::s6b_rearm_arm_result \
    $::s6b_rearm_capture_samples $::s6b_rearm_post_fire_samples \
    $::s6b_rearm_arm0_write_master $::s6b_rearm_arm0_write_slave \
    $::s6b_rearm_target_write_master $::s6b_rearm_target_write_slave \
    $::s6b_rearm_arm1_write_master $::s6b_rearm_arm1_write_slave \
    $::s6b_rearm_master_count $::s6b_rearm_slave_count \
    $::s6b_rearm_master_actual_tai $::s6b_rearm_slave_actual_tai \
    $::s6b_rearm_master_actual_cycles $::s6b_rearm_slave_actual_cycles \
    $::s6b_rearm_delta_ticks $::s6b_rearm_delta_ns]
  puts [format "S6B_REARM_DONE result=%s phase=%s" $result $phase]
  flush stdout
}

proc s6b_rearm_get_boards {} {
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
  return [list $master_hardware $slave_hardware]
}

proc s6b_rearm_reset_maps {} {
  array unset ::s6b_master_by_tai *
  array unset ::s6b_slave_by_tai *
  set ::s6b_coherence_violation 0
}

proc s6b_rearm_health_gate {master_hardware slave_hardware label required_pairs required_common} {
  s6b_rearm_reset_maps
  set pairs 0
  set sample 0
  set gate_start [clock milliseconds]
  set good_master {}
  set good_slave {}
  while {[clock milliseconds] - $gate_start <= $::s6b_rearm_gate_timeout_ms} {
    set elapsed [expr {[clock milliseconds] - $gate_start}]
    set master [s6b_collect $master_hardware MASTER $sample $elapsed]
    set slave [s6b_collect $slave_hardware SLAVE $sample $elapsed]
    s6b_emit_board_samples $master $slave S6B_REARM_${label}_SAMPLE
    set master_gate [s6b_live_common_gate_ok $master MASTER]
    set slave_gate [s6b_live_common_gate_ok $slave SLAVE]
    if {$master_gate && $slave_gate} {
      s6b_snapshot_map_update MASTER $master
      s6b_snapshot_map_update SLAVE $slave
      incr pairs
      set good_master $master
      set good_slave $slave
    }
    set common [s6b_common_tais]
    set common_count [llength $common]
    s6b_emit S6B_REARM_${label}_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
      MASTER_GATE $master_gate SLAVE_GATE $slave_gate PAIRS $pairs \
      COMMON_TAI_COUNT $common_count COHERENCE_VIOLATION $::s6b_coherence_violation]
    if {$pairs >= $required_pairs && $common_count >= $required_common &&
        !$::s6b_coherence_violation} {
      return [list 1 $pairs $common_count $good_master $good_slave]
    }
    incr sample
    after $::s6b_rearm_gate_gap_ms
  }
  set common_count [llength [s6b_common_tais]]
  return [list 0 $pairs $common_count $good_master $good_slave]
}

proc s6b_rearm_initial_postfire_ok {snapshot} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  return [expr {[s6b_live_common_gate_ok $snapshot $row(ROLE)] &&
      $row(TARGET_TAI_SOURCE) == 3433 &&
      $row(STEP6B_ARM_SOURCE) == 1 && $row(STEP6B_ARM_SYNC) == 1 &&
      $row(STEP6B_ARMED) == 0 && $row(STEP6B_FIRED) == 1 &&
      $row(STEP6B_FIRE_COUNT) == 1 &&
      $row(STEP6B_LATCHED_TAI) == 3433 &&
      $row(STEP6B_ACTUAL_TAI) == 3433 &&
      $row(STEP6B_ACTUAL_CYCLES) == 62500000 &&
      $row(STEP6B_ACTUAL_FIRED) == 1 &&
      $row(STEP6B_ACTUAL_ARMED) == 0 &&
      $row(RESET_CHANGED) == 0}]
}

proc s6b_rearm_dearm_ok {snapshot} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  return [expr {$row(READ_VALID) == 1 && $row(RESET_CHANGED) == 0 &&
      $row(STEP6B_ARM_SOURCE) == 0 && $row(STEP6B_ARM_SYNC) == 0 &&
      $row(STEP6B_ARMED) == 0 && $row(STEP6B_FIRED) == 0 &&
      $row(STEP6B_FIRE_COUNT) == 1}]
}

proc s6b_rearm_target_ok {snapshot target_tai} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  return [expr {[s6b_live_common_gate_ok $snapshot $row(ROLE)] &&
      $row(TARGET_TAI_SOURCE) == $target_tai &&
      $row(STEP6B_ARM_SOURCE) == 0 && $row(STEP6B_ARM_SYNC) == 0 &&
      $row(STEP6B_ARMED) == 0 &&
      $row(STEP6B_FIRED) == 0 && $row(STEP6B_FIRE_COUNT) == 1 &&
      $row(RESET_CHANGED) == 0}]
}

proc s6b_rearm_arm_ok {snapshot target_tai} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  return [expr {[s6b_live_common_gate_ok $snapshot $row(ROLE)] &&
      $row(TARGET_TAI_SOURCE) == $target_tai &&
      $row(STEP6B_ARM_SOURCE) == 1 && $row(STEP6B_ARM_SYNC) == 1 &&
      $row(STEP6B_ARMED) == 1 && $row(STEP6B_FIRED) == 0 &&
      $row(STEP6B_FIRE_COUNT) == 1 &&
      $row(STEP6B_LATCHED_TAI) == $target_tai &&
      $row(STEP6B_ACTUAL_TAI) == 0 &&
      $row(STEP6B_ACTUAL_CYCLES) == 0 &&
      $row(RESET_CHANGED) == 0}]
}

proc s6b_rearm_update_final {master slave} {
  if {$master ne ""} {
    array set m $master
    set ::s6b_rearm_master_count $m(STEP6B_FIRE_COUNT)
    set ::s6b_rearm_master_actual_tai $m(STEP6B_ACTUAL_TAI)
    set ::s6b_rearm_master_actual_cycles $m(STEP6B_ACTUAL_CYCLES)
  }
  if {$slave ne ""} {
    array set s $slave
    set ::s6b_rearm_slave_count $s(STEP6B_FIRE_COUNT)
    set ::s6b_rearm_slave_actual_tai $s(STEP6B_ACTUAL_TAI)
    set ::s6b_rearm_slave_actual_cycles $s(STEP6B_ACTUAL_CYCLES)
  }
}

proc s6b_rearm_repeatability_run {} {
  lassign [s6b_rearm_get_boards] master_hardware slave_hardware
  s6b_rearm_init_state

  puts [format "S6B_REARM_CONFIG trial=%s gate_timeout_ms=%d gate_gap_ms=%d settle_ms=%d arm_settle_ms=%d capture_gap_ms=%d capture_timeout_ms=%d PREVIOUS_TARGET_TAI=3433 TARGET_CYCLES=%d MASTER_COMPILE=0 SLAVE_COMPILE=0 FIRMWARE_BUILD=0 MASTER_PROGRAM=0 SLAVE_PROGRAM=0 PTP_RESTART=0 POWER_CYCLE=0 RESET=0" \
    $::s6b_rearm_trial_id $::s6b_rearm_gate_timeout_ms \
    $::s6b_rearm_gate_gap_ms $::s6b_rearm_settle_ms \
    $::s6b_rearm_arm_settle_ms $::s6b_rearm_capture_gap_ms \
    $::s6b_rearm_capture_timeout_ms $::s6b_rearm_target_cycles]
  flush stdout

  # Phase A: current post-fire session must be intact before any write.
  lassign [s6b_rearm_health_gate $master_hardware $slave_hardware PRE_GATE 3 2] \
    pre_ok pre_pairs pre_common pre_master pre_slave
  set ::s6b_rearm_pre_gate_pairs $pre_pairs
  set ::s6b_rearm_pre_common_tai_count $pre_common
  set ::s6b_rearm_pre_gate_result [expr {$pre_ok ? "PASS" : "INCONCLUSIVE_REARM_PRECONDITION_CHANGED"}]
  set initial_ok [expr {$pre_ok &&
      [s6b_rearm_initial_postfire_ok $pre_master] &&
      [s6b_rearm_initial_postfire_ok $pre_slave]}]
  set ::s6b_rearm_initial_result [expr {$initial_ok ? "PASS" : "INCONCLUSIVE_REARM_PRECONDITION_CHANGED"}]
  s6b_emit_board_samples $pre_master $pre_slave S6B_REARM_INITIAL_SAMPLE
  puts [format "S6B_REARM_PRE_GATE_RESULT=%s PAIRS=%d COMMON_TAI_COUNT=%d" \
    $::s6b_rearm_pre_gate_result $pre_pairs $pre_common]
  puts [format "S6B_REARM_INITIAL_STATE_RESULT=%s EXPECTED_TARGET=3433" \
    $::s6b_rearm_initial_result]
  flush stdout
  if {!$initial_ok} {
    s6b_rearm_emit_result INCONCLUSIVE_REARM_PRECONDITION_CHANGED pre_gate
    return
  }

  # Phase B: exactly one ARM=0 write per board.
  if {[s6b_write_source $master_hardware MASTER 68 0 1]} {
    set ::s6b_rearm_arm0_write_master 1
  } else {
    s6b_rearm_emit_result INCONCLUSIVE_REARM_WRITE_OR_READBACK_MISMATCH arm0_write
    return
  }
  if {[s6b_write_source $slave_hardware SLAVE 68 0 1]} {
    set ::s6b_rearm_arm0_write_slave 1
  } else {
    s6b_rearm_emit_result INCONCLUSIVE_REARM_WRITE_OR_READBACK_MISMATCH arm0_write
    return
  }
  after $::s6b_rearm_settle_ms
  set dearm_master [s6b_collect $master_hardware MASTER 0 0]
  set dearm_slave [s6b_collect $slave_hardware SLAVE 0 0]
  s6b_emit_board_samples $dearm_master $dearm_slave S6B_REARM_DEARM_VERIFY_SAMPLE
  set dearm_readback_ok [expr {[s6b_rearm_dearm_ok $dearm_master] &&
      [s6b_rearm_dearm_ok $dearm_slave]}]
  set dearm_semantics_ok $dearm_readback_ok
  foreach snapshot [list $dearm_master $dearm_slave] {
    if {$snapshot eq ""} { set dearm_readback_ok 0; set dearm_semantics_ok 0; continue }
    array set row $snapshot
    if {$row(STEP6B_ARM_SOURCE) != 0 || $row(STEP6B_ARM_SYNC) != 0} {
      set dearm_readback_ok 0
    }
    if {$row(STEP6B_FIRED) != 0 || $row(STEP6B_FIRE_COUNT) != 1} {
      set dearm_semantics_ok 0
    }
  }
  if {$dearm_semantics_ok} {
    set ::s6b_rearm_dearm_result PASS
  } elseif {$dearm_readback_ok} {
    set ::s6b_rearm_dearm_result FAIL_STEP6B_REARM_CLEAR_SEMANTICS
  } else {
    set ::s6b_rearm_dearm_result INCONCLUSIVE_REARM_WRITE_OR_READBACK_MISMATCH
  }
  puts [format "S6B_REARM_DEARM_RESULT=%s" $::s6b_rearm_dearm_result]
  flush stdout
  if {$::s6b_rearm_dearm_result ne "PASS"} {
    s6b_rearm_emit_result $::s6b_rearm_dearm_result dearm_verify
    return
  }

  # Phase C: requalify the same live session and choose one new future label.
  lassign [s6b_rearm_health_gate $master_hardware $slave_hardware POST_DEARM_GATE 2 2] \
    post_ok post_pairs post_common post_master post_slave
  set ::s6b_rearm_post_dearm_gate_pairs $post_pairs
  set ::s6b_rearm_post_dearm_common_tai_count $post_common
  set ::s6b_rearm_post_dearm_gate_result [expr {$post_ok ? "PASS" : "INCONCLUSIVE_REARM_POST_DEARM_GATE_FAILED"}]
  if {$post_ok} {
    set common [s6b_common_tais]
    set ::s6b_rearm_t0 [lindex $common end]
    set ::s6b_rearm_new_target_tai [expr {$::s6b_rearm_t0 + 20}]
  }
  puts [format "S6B_REARM_POST_DEARM_GATE_RESULT=%s PAIRS=%d COMMON_TAI_COUNT=%d T0=%s NEW_TARGET_TAI=%s" \
    $::s6b_rearm_post_dearm_gate_result $post_pairs $post_common \
    $::s6b_rearm_t0 $::s6b_rearm_new_target_tai]
  flush stdout
  if {!$post_ok} {
    s6b_rearm_emit_result INCONCLUSIVE_REARM_POST_DEARM_GATE_FAILED post_dearm_gate
    return
  }

  # Phase D: exactly one new target write per board while de-armed.
  if {[s6b_write_source $master_hardware MASTER 67 $::s6b_rearm_new_target_tai 40]} {
    set ::s6b_rearm_target_write_master 1
  } else {
    s6b_rearm_emit_result INCONCLUSIVE_SECOND_TARGET_WRITE_OR_READBACK_MISMATCH target_write
    return
  }
  if {[s6b_write_source $slave_hardware SLAVE 67 $::s6b_rearm_new_target_tai 40]} {
    set ::s6b_rearm_target_write_slave 1
  } else {
    s6b_rearm_emit_result INCONCLUSIVE_SECOND_TARGET_WRITE_OR_READBACK_MISMATCH target_write
    return
  }
  after $::s6b_rearm_settle_ms
  set target_master [s6b_collect $master_hardware MASTER 0 0]
  set target_slave [s6b_collect $slave_hardware SLAVE 0 0]
  s6b_emit_board_samples $target_master $target_slave S6B_REARM_TARGET_VERIFY_SAMPLE
  set target_ok [expr {[s6b_rearm_target_ok $target_master $::s6b_rearm_new_target_tai] &&
      [s6b_rearm_target_ok $target_slave $::s6b_rearm_new_target_tai]}]
  set ::s6b_rearm_target_result [expr {$target_ok ? "PASS" : "INCONCLUSIVE_SECOND_TARGET_WRITE_OR_READBACK_MISMATCH"}]
  puts [format "S6B_REARM_TARGET_RESULT=%s TARGET_TAI=%s TARGET_CYCLES=%d" \
    $::s6b_rearm_target_result $::s6b_rearm_new_target_tai $::s6b_rearm_target_cycles]
  flush stdout
  if {!$target_ok} {
    s6b_rearm_emit_result INCONCLUSIVE_SECOND_TARGET_WRITE_OR_READBACK_MISMATCH target_verify
    return
  }

  # Phase E: do not arm if the target is less than twelve seconds away.
  set master_remaining [s6b_live_target_delta_ticks $target_master \
    $::s6b_rearm_new_target_tai $::s6b_rearm_target_cycles]
  set slave_remaining [s6b_live_target_delta_ticks $target_slave \
    $::s6b_rearm_new_target_tai $::s6b_rearm_target_cycles]
  puts [format "S6B_REARM_PREARM_TIME_GATE MASTER_REMAINING_TICKS=%s SLAVE_REMAINING_TICKS=%s REQUIRED_REMAINING_TICKS=%d" \
    $master_remaining $slave_remaining [expr {12 * 125000000}]]
  flush stdout
  if {$master_remaining < 12 * 125000000 || $slave_remaining < 12 * 125000000} {
    s6b_rearm_emit_result INCONCLUSIVE_SECOND_TARGET_WINDOW_TOO_CLOSE prearm_time_gate
    return
  }

  # Phase F: exactly one ARM=1 write per board.
  if {[s6b_write_source $master_hardware MASTER 68 1 1]} {
    set ::s6b_rearm_arm1_write_master 1
  } else {
    s6b_rearm_emit_result INCONCLUSIVE_SECOND_DUAL_ARM_NOT_ESTABLISHED arm1_write
    return
  }
  if {[s6b_write_source $slave_hardware SLAVE 68 1 1]} {
    set ::s6b_rearm_arm1_write_slave 1
  } else {
    s6b_rearm_emit_result INCONCLUSIVE_SECOND_DUAL_ARM_NOT_ESTABLISHED arm1_write
    return
  }
  after $::s6b_rearm_arm_settle_ms
  set arm_master [s6b_collect $master_hardware MASTER 0 0]
  set arm_slave [s6b_collect $slave_hardware SLAVE 0 0]
  s6b_emit_board_samples $arm_master $arm_slave S6B_REARM_ARM_VERIFY_SAMPLE
  set arm_latch_ok [expr {[s6b_rearm_arm_ok $arm_master $::s6b_rearm_new_target_tai] &&
      [s6b_rearm_arm_ok $arm_slave $::s6b_rearm_new_target_tai]}]
  set arm_remaining_ok 1
  foreach snapshot [list $arm_master $arm_slave] {
    if {$snapshot eq ""} { set arm_remaining_ok 0; continue }
    if {[s6b_live_target_delta_ticks $snapshot $::s6b_rearm_new_target_tai \
        $::s6b_rearm_target_cycles] < 10 * 125000000} {
      set arm_remaining_ok 0
    }
  }
  if {$arm_latch_ok && $arm_remaining_ok} {
    set ::s6b_rearm_arm_result PASS
  } elseif {!$arm_latch_ok && $arm_master ne "" && $arm_slave ne ""} {
    set ::s6b_rearm_arm_result INCONCLUSIVE_SECOND_TARGET_LATCH_MISMATCH
  } else {
    set ::s6b_rearm_arm_result INCONCLUSIVE_SECOND_DUAL_ARM_NOT_ESTABLISHED
  }
  puts [format "S6B_REARM_ARM_RESULT=%s TARGET_LATCH=%s REMAINING_OK=%s" \
    $::s6b_rearm_arm_result [expr {$arm_latch_ok ? "PASS" : "FAIL"}] \
    [expr {$arm_remaining_ok ? "PASS" : "FAIL"}]]
  flush stdout
  if {$::s6b_rearm_arm_result ne "PASS"} {
    s6b_rearm_emit_result $::s6b_rearm_arm_result arm_verify
    return
  }

  # Phase G: read-only capture through the second target plus two seconds.
  set target_ticks [expr {$::s6b_rearm_new_target_tai * 125000000 + \
      $::s6b_rearm_target_cycles}]
  set target_plus_one [expr {$target_ticks + 125000000}]
  set target_plus_two [expr {$target_ticks + 2 * 125000000}]
  set deadline [expr {[clock milliseconds] + $::s6b_rearm_capture_timeout_ms}]
  set sample 0
  set trigger_seen 0
  set result ""
  set final_master $arm_master
  set final_slave $arm_slave
  while {[clock milliseconds] <= $deadline} {
    set master [s6b_collect $master_hardware MASTER $sample 0]
    set slave [s6b_collect $slave_hardware SLAVE $sample 0]
    incr ::s6b_rearm_capture_samples
    set final_master $master
    set final_slave $slave
    s6b_emit_board_samples $master $slave S6B_REARM_CAPTURE_SAMPLE
    if {$master eq "" || $slave eq ""} {
      set result INCONCLUSIVE_RUNTIME_STATE_CHANGED
      break
    }
    array set m $master
    array set s $slave
    s6b_rearm_update_final $master $slave
    set master_now [s6b_live_now_ticks $master]
    set slave_now [s6b_live_now_ticks $slave]
    set now_ticks $master_now
    if {$now_ticks < 0 || ($slave_now >= 0 && $slave_now > $now_ticks)} {
      set now_ticks $slave_now
    }
    set before_target [expr {$now_ticks >= 0 && $now_ticks < $target_ticks}]
    if {$m(STEP6B_FIRE_COUNT) > 2 || $s(STEP6B_FIRE_COUNT) > 2} {
      set result FAIL_TRIGGER_ONE_SHOT_VIOLATION
      break
    }
    if {$before_target && ($m(STEP6B_FIRED) == 1 || $s(STEP6B_FIRED) == 1 ||
        $m(STEP6B_FIRE_COUNT) > 1 || $s(STEP6B_FIRE_COUNT) > 1)} {
      set result FAIL_EARLY_SECOND_SCHEDULED_TRIGGER
      break
    }
    set runtime_ok [expr {[s6b_live_common_gate_ok $master MASTER] &&
        [s6b_live_common_gate_ok $slave SLAVE] &&
        $m(RESET_CHANGED) == 0 && $s(RESET_CHANGED) == 0}]
    if {!$runtime_ok} {
      if {$trigger_seen} {
        set result INCONCLUSIVE_RUNTIME_STATE_CHANGED
      } else {
        set result INCONCLUSIVE_STEP6A_STABILITY_LOST_BEFORE_SECOND_TARGET
      }
      break
    }
    if {$m(STEP6B_FIRED) == 1 && $s(STEP6B_FIRED) == 1} {
      if {!$trigger_seen} {
        set trigger_seen 1
        if {$m(STEP6B_ACTUAL_TAI) != $s(STEP6B_ACTUAL_TAI) ||
            $m(STEP6B_ACTUAL_CYCLES) != $s(STEP6B_ACTUAL_CYCLES)} {
          set result FAIL_SECOND_TRIGGER_TIMESTAMP_MISMATCH
          set ::s6b_rearm_delta_ticks [expr {($s(STEP6B_ACTUAL_TAI) - $m(STEP6B_ACTUAL_TAI)) * 125000000 +
              $s(STEP6B_ACTUAL_CYCLES) - $m(STEP6B_ACTUAL_CYCLES)}]
          set ::s6b_rearm_delta_ns [expr {$::s6b_rearm_delta_ticks * 8}]
          break
        }
        if {$m(STEP6B_ACTUAL_TAI) != $::s6b_rearm_new_target_tai ||
            $s(STEP6B_ACTUAL_TAI) != $::s6b_rearm_new_target_tai ||
            $m(STEP6B_ACTUAL_CYCLES) != $::s6b_rearm_target_cycles ||
            $s(STEP6B_ACTUAL_CYCLES) != $::s6b_rearm_target_cycles} {
          set result FAIL_SECOND_COMMON_TRIGGER_TARGET_MISS
          break
        }
        set ::s6b_rearm_delta_ticks 0
        set ::s6b_rearm_delta_ns 0
      } else {
        if {$m(STEP6B_FIRED) != 1 || $s(STEP6B_FIRED) != 1 ||
            $m(STEP6B_FIRE_COUNT) != 2 || $s(STEP6B_FIRE_COUNT) != 2 ||
            $m(STEP6B_ARMED) != 0 || $s(STEP6B_ARMED) != 0} {
          set result FAIL_TRIGGER_ONE_SHOT_VIOLATION
          break
        }
        incr ::s6b_rearm_post_fire_samples
        if {$::s6b_rearm_post_fire_samples >= 3} {
          set result PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER_REARM_REPEATABILITY
          break
        }
      }
    } elseif {$trigger_seen && ($m(STEP6B_FIRED) != 1 || $s(STEP6B_FIRED) != 1 ||
        $m(STEP6B_FIRE_COUNT) != 2 || $s(STEP6B_FIRE_COUNT) != 2)} {
      set result FAIL_TRIGGER_ONE_SHOT_VIOLATION
      break
    }
    if {!$trigger_seen && $now_ticks >= $target_plus_one} {
      if {$m(STEP6B_FIRE_COUNT) == 2 || $s(STEP6B_FIRE_COUNT) == 2 ||
          $m(STEP6B_FIRED) == 1 || $s(STEP6B_FIRED) == 1} {
        set result FAIL_ONE_SIDED_SECOND_SCHEDULED_TRIGGER
      } else {
        set result FAIL_BOTH_BOARDS_MISSED_SECOND_SCHEDULED_TRIGGER
      }
      break
    }
    if {!$trigger_seen && $now_ticks >= $target_plus_two} {
      set result FAIL_BOTH_BOARDS_MISSED_SECOND_SCHEDULED_TRIGGER
      break
    }
    incr sample
    after $::s6b_rearm_capture_gap_ms
  }
  if {$result eq ""} { set result INCONCLUSIVE_SECOND_TRIGGER_OBSERVATION_TIMEOUT }
  s6b_rearm_update_final $final_master $final_slave
  s6b_rearm_emit_result $result capture
}

s6b_rearm_repeatability_run
