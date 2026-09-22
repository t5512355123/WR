# Step5 recovery diagnostic: re-arm the Slave WR/PTP session once and observe
# whether the already-built Step5 milestone can complete phase/PSTAT lock.
#
# This is deliberately narrower than a new firmware experiment.  It does not
# compile, program, reset, power-cycle, change PI/gain/threshold/timeout, or
# write any production control register.  Its sole functional stimulus is:
#
#     Slave VUART: "ptp stop\n" followed by "ptp start\n"
#
# The observer then records the existing WR-extension and SoftPLL shadows.
# A transient lock is reported as RECOVERY_LOCK_OBSERVED, not as Step5 PASS;
# the normal 300-second Step5 observer remains the authority for the milestone.
#
# Usage:
#   quartus_stp -t read_step5_slave_ptp_rearm_phase_recovery.tcl \
#     EXP-ID ?preflight_samples? ?pre_gap_ms? ?restart_gap_ms? \
#     ?duration_ms? ?capture_gap_ms?

package require ::quartus::insystem_source_probe

set ::wf_library_only 1
source [file join [file dirname [info script]] \
  read_step6_wr_extension_fallback_terminal_liveness.tcl]

set ::s5_trial_id "EXP-S5-SLAVE-PTP-REARM-PHASE-RECOVERY-20260922"
set ::s5_preflight_samples 3
set ::s5_pre_gap_ms 250
set ::s5_restart_gap_ms 100
set ::s5_duration_ms 90000
set ::s5_capture_gap_ms 350
if {[llength $argv] >= 1} { set ::s5_trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::s5_preflight_samples [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set ::s5_pre_gap_ms [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::s5_restart_gap_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set ::s5_duration_ms [expr {int([lindex $argv 4])}] }
if {[llength $argv] >= 6} { set ::s5_capture_gap_ms [expr {int([lindex $argv 5])}] }
if {$::s5_preflight_samples <= 0 || $::s5_pre_gap_ms < 0 ||
    $::s5_restart_gap_ms < 0 || $::s5_duration_ms <= 0 ||
    $::s5_capture_gap_ms < 0} {
  error "invalid recovery experiment arguments"
}

proc s5_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc s5_gate_precondition {snapshot role} {
  if {$snapshot eq ""} { return 0 }
  array set s $snapshot
  # This gate intentionally validates only fields required before the VUART
  # action.  The full shadow frame may contain an unrelated stale group while
  # link/PTP status is coherent; that case remains visible as READ_VALID=0.
  if {$s(CAPTURE_HEALTHY) != 1 || $s(RESET_CHANGED) != 0 ||
      $s(LINK_HEALTHY) != 1} {
    return 0
  }
  if {$role eq "SLAVE"} {
    return [expr {$s(RX_LOCKED_TO_DATA) == 1 &&
      $s(RX_PATTERN_READY) == 1 && $s(RX_ACTIVITY_CHANGED) == 1 &&
      $s(PTP_STATE) == 9 && $s(WRC_MODE) == 3}]
  }
  # The Master WDIAGS_PTP meta word uses its own extension-mode byte; in the
  # validated image the legal Master value is 1, not the Slave value 3.  The
  # recovery gate only needs the stable Master PTP state and link health.
  return [expr {$s(PTP_STATE) == 6}]
}

proc s5_collect_gate {hardware_name role sample elapsed_ms} {
  set last {}
  for {set attempt 0} {$attempt < 5} {incr attempt} {
    set last [wf_collect $hardware_name $role $sample $elapsed_ms]
    if {[s5_gate_precondition $last $role]} { return $last }
    if {$attempt < 4} { after 75 }
  }
  return $last
}

proc s5_send_vuart {hardware_name command label} {
  set index 0
  set ok 1
  foreach character [split $command ""] {
    scan $character %c byte
    set result [wf_wb_write 0x00100510 $byte]
    puts [format "S5_PHASE_REARM_VUART board=%s action=%s index=%02d BYTE=0x%02X WB_RESULT=%d" \
      $hardware_name $label $index $byte $result]
    flush stdout
    if {!$result} { set ok 0 }
    incr index
  }
  return $ok
}

proc s5_collect_valid {hardware_name role sample elapsed_ms} {
  # A complete frame contains several shadow groups.  Under a busy WR
  # session one group can be stale even though the dashboard's short read is
  # usable.  Retry only the passive capture; never retry the VUART write.
  set last {}
  for {set attempt 0} {$attempt < 5} {incr attempt} {
    set last [wf_collect $hardware_name $role $sample $elapsed_ms]
    if {$last ne ""} {
      array set row $last
      if {$row(READ_VALID) == 1} { return $last }
    }
    if {$attempt < 4} { after 75 }
  }
  return $last
}

proc s5_emit_state {board role sample elapsed snapshot} {
  if {$snapshot eq ""} {
    s5_emit S5_PHASE_REARM_SAMPLE [list BOARD $board ROLE $role SAMPLE $sample \
      ELAPSED_MS $elapsed READ_VALID 0]
    return
  }
  array set s $snapshot
  s5_emit S5_PHASE_REARM_SAMPLE [list BOARD $board ROLE $role SAMPLE $sample \
    ELAPSED_MS $elapsed READ_VALID $s(READ_VALID) CAPTURE_HEALTHY $s(CAPTURE_HEALTHY) \
    RESET_CHANGED $s(RESET_CHANGED) LINK_HEALTHY $s(LINK_HEALTHY) \
    PTP_STATE $s(PTP_STATE) PD_STATE $s(PD_STATE) EXT_STATE $s(EXT_STATE) \
    WRC_MODE $s(WRC_MODE) WR_STATE_VALUE $s(WR_STATE_VALUE) \
    TERMINAL $s(TERMINAL) WR_FAILURE_REASON $s(WR_FAILURE_REASON) \
    SPLL_SEQ_STATE $s(SPLL_SEQ_STATE) HELPER_LOCKED $s(HELPER_LOCKED) \
    MAIN_ENABLED $s(MAIN_ENABLED) MAIN_FREQ_LOCKED $s(MAIN_FREQ_LOCKED) \
    MAIN_PHASE_LOCKED $s(MAIN_PHASE_LOCKED) MAIN_LOCKED $s(MAIN_LOCKED) \
    PSTAT_LOCKED $s(PSTAT_LOCKED) STATUS_TIME_VALID $s(STATUS_TIME_VALID) \
    STATUS_PPS_VALID $s(STATUS_PPS_VALID) PHASE_UPDATES $s(PHASE_UPDATES) \
    TOTAL_UPDATES $s(TOTAL_UPDATES)]
}

proc s5_run {} {
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

  s5_emit S5_PHASE_REARM_CONFIG [list TRIAL $::s5_trial_id \
    PREFLIGHT_SAMPLES $::s5_preflight_samples PRE_GAP_MS $::s5_pre_gap_ms \
    RESTART_GAP_MS $::s5_restart_gap_ms DURATION_MS $::s5_duration_ms \
    CAPTURE_GAP_MS $::s5_capture_gap_ms MASTER_PTP_RESTART 0 \
    SLAVE_PTP_STOP 1 SLAVE_PTP_START 1 COMPILE 0 PROGRAM 0 RESET 0 \
    POWER_CYCLE 0 PI_CHANGE 0 THRESHOLD_CHANGE 0 TIMEOUT_CHANGE 0]

  set gate_all 1
  set gate_transport 0
  set gate_reset_changed 0
  set last_master {}
  set last_slave {}
  set gate_begin_ms [clock milliseconds]
  for {set sample 0} {$sample < $::s5_preflight_samples} {incr sample} {
    set elapsed [expr {[clock milliseconds] - $gate_begin_ms}]
    set master [s5_collect_gate $master_hardware MASTER $sample $elapsed]
    set slave [s5_collect_gate $slave_hardware SLAVE $sample $elapsed]
    if {$master eq "" || $slave eq ""} {
      set gate_all 0
      set gate_transport 1
      s5_emit S5_PHASE_REARM_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 0 MASTER_PRECONDITION 0 SLAVE_PRECONDITION 0]
    } else {
      set last_master $master
      set last_slave $slave
      array set m $master
      array set s $slave
      set master_good [s5_gate_precondition $master MASTER]
      set slave_good [s5_gate_precondition $slave SLAVE]
      if {$m(RESET_CHANGED) || $s(RESET_CHANGED)} { set gate_reset_changed 1 }
      if {$m(READ_VALID) != 1 || $s(READ_VALID) != 1} { set gate_transport 1 }
      set gate_all [expr {$gate_all && $master_good && $slave_good &&
        !$m(RESET_CHANGED) && !$s(RESET_CHANGED)}]
      set complete_frame [expr {$m(READ_VALID) == 1 && $s(READ_VALID) == 1}]
      s5_emit S5_PHASE_REARM_GATE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID $complete_frame ESSENTIAL_GATE 1 \
        MASTER_PRECONDITION $master_good SLAVE_PRECONDITION $slave_good \
        MASTER_READ_VALID $m(READ_VALID) MASTER_CAPTURE_HEALTHY $m(CAPTURE_HEALTHY) \
        MASTER_LINK_HEALTHY $m(LINK_HEALTHY) MASTER_RESET_CHANGED $m(RESET_CHANGED) \
        MASTER_PTP_STATE $m(PTP_STATE) SLAVE_READ_VALID $s(READ_VALID) \
        SLAVE_CAPTURE_HEALTHY $s(CAPTURE_HEALTHY) SLAVE_LINK_HEALTHY $s(LINK_HEALTHY) \
        SLAVE_RESET_CHANGED $s(RESET_CHANGED) SLAVE_PTP_STATE $s(PTP_STATE) \
        SLAVE_EXT_STATE $s(EXT_STATE) SLAVE_WRC_MODE $s(WRC_MODE) \
        SLAVE_PHASE_LOCKED $s(MAIN_PHASE_LOCKED) SLAVE_PSTAT_LOCKED $s(PSTAT_LOCKED)]
    }
    if {$sample + 1 < $::s5_preflight_samples} { after $::s5_pre_gap_ms }
  }

  if {$gate_transport || $gate_reset_changed || !$gate_all} {
    puts "S5_PHASE_REARM_GATE_RESULT=INCONCLUSIVE_PRE_RESTART_GATE"
    puts "S5_PHASE_REARM_INJECTION_RESULT=NOT_PERFORMED"
    puts "S5_PHASE_REARM_DONE result=INCONCLUSIVE_PRE_RESTART_GATE phase=gate"
    flush stdout
    return
  }
  puts [format "S5_PHASE_REARM_GATE_RESULT=PASS SAMPLES=%d" $::s5_preflight_samples]
  flush stdout

  set stop_ok 0
  if {[catch {
    wf_open_board $slave_hardware
    set stop_ok [s5_send_vuart $slave_hardware "ptp stop\n" STOP]
  } error_message]} {
    set stop_ok 0
  }
  catch {end_insystem_source_probe}

  set start_ok 0
  if {$stop_ok} {
    after $::s5_restart_gap_ms
    if {[catch {
      wf_open_board $slave_hardware
      set start_ok [s5_send_vuart $slave_hardware "ptp start\n" START]
    } error_message]} {
      set start_ok 0
    }
    catch {end_insystem_source_probe}
  }
  if {!$stop_ok || !$start_ok} {
    puts "S5_PHASE_REARM_INJECTION_RESULT=INCONCLUSIVE_COMMAND_TRANSPORT"
    puts [format "S5_PHASE_REARM_INJECTION_COUNTS SLAVE_PTP_STOP_COUNT=%d SLAVE_PTP_START_COUNT=%d MASTER_COMMAND_COUNT=0" \
      [expr {$stop_ok ? 1 : 0}] [expr {$start_ok ? 1 : 0}]]
    puts "S5_PHASE_REARM_DONE result=INCONCLUSIVE_COMMAND_TRANSPORT phase=injection"
    flush stdout
    return
  }
  puts "S5_PHASE_REARM_INJECTION_RESULT=PASS"
  puts "S5_PHASE_REARM_INJECTION_COUNTS SLAVE_PTP_STOP_COUNT=1 SLAVE_PTP_START_COUNT=1 MASTER_COMMAND_COUNT=0"
  flush stdout

  array unset ::wf_previous_counters *
  array unset ::wf_first_counters *
  array unset ::wf_previous_activity *
  puts "S5_PHASE_REARM_POST_RESTART_COUNTER_BASELINED=1"
  flush stdout

  set begin_ms [clock milliseconds]
  set deadline_ms [expr {$begin_ms + $::s5_duration_ms}]
  set sample 0
  set lock_observed 0
  set transport_failure 0
  set reset_changed 0
  set terminal_seen 0
  while {[clock milliseconds] <= $deadline_ms} {
    set elapsed [expr {[clock milliseconds] - $begin_ms}]
    set slave [s5_collect_valid $slave_hardware SLAVE $sample $elapsed]
    set master [s5_collect_valid $master_hardware MASTER $sample $elapsed]
    if {$slave eq "" || $master eq ""} {
      set transport_failure 1
      s5_emit S5_PHASE_REARM_SAMPLE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed READ_VALID 0]
      break
    }
    array set s $slave
    array set m $master
    s5_emit_state $master_hardware MASTER $sample $elapsed $master
    s5_emit_state $slave_hardware SLAVE $sample $elapsed $slave
    if {$m(RESET_CHANGED) || $s(RESET_CHANGED)} { set reset_changed 1 }
    if {$m(TERMINAL) || $s(TERMINAL)} { set terminal_seen 1 }
    if {$s(HELPER_LOCKED) == 1 && $s(MAIN_FREQ_LOCKED) == 1 &&
        $s(MAIN_PHASE_LOCKED) == 1 && $s(MAIN_LOCKED) == 1 &&
        $s(PSTAT_LOCKED) == 1} {
      set lock_observed 1
      puts [format "S5_PHASE_REARM_LOCK_OBSERVED sample=%d elapsed_ms=%d helper=1 main_freq=1 main_phase=1 main_lock=1 pstat=1" \
        $sample $elapsed]
      flush stdout
      break
    }
    incr sample
    after $::s5_capture_gap_ms
  }

  if {$transport_failure} {
    set result INCONCLUSIVE_RUNTIME_TRANSPORT
  } elseif {$reset_changed} {
    set result INCONCLUSIVE_RESET_CHANGED
  } elseif {$lock_observed} {
    set result RECOVERY_LOCK_OBSERVED
  } elseif {$terminal_seen} {
    set result WR_SESSION_TERMINAL_NO_PHASE_LOCK
  } else {
    set result TIMEOUT_NO_PHASE_LOCK
  }
  puts [format "S5_PHASE_REARM_RESULT=%s" $result]
  puts [format "S5_PHASE_REARM_STEP5_PASS=NO REASON=%s" $result]
  puts [format "S5_PHASE_REARM_DONE result=%s phase=observation" $result]
  flush stdout
}

s5_run
