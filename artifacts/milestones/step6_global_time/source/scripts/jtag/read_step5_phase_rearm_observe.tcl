# Step5 read-only follow-up observer for the single Slave PTP re-arm action.
#
# This script never sends VUART bytes and never changes hardware.  It is used
# after read_step5_slave_ptp_rearm_phase_recovery.tcl has completed its one
# permitted "ptp stop"/"ptp start" injection.
#
# Usage:
#   quartus_stp -t read_step5_phase_rearm_observe.tcl \
#     EXP-ID ?duration_ms? ?capture_gap_ms?

package require ::quartus::insystem_source_probe

set ::wf_library_only 1
source [file join [file dirname [info script]] \
  read_step6_wr_extension_fallback_terminal_liveness.tcl]

set ::s5o_trial_id "EXP-S5-SLAVE-PTP-REARM-PHASE-OBSERVE-20260922"
set ::s5o_duration_ms 90000
set ::s5o_capture_gap_ms 350
if {[llength $argv] >= 1} { set ::s5o_trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::s5o_duration_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set ::s5o_capture_gap_ms [expr {int([lindex $argv 2])}] }
if {$::s5o_duration_ms <= 0 || $::s5o_capture_gap_ms < 0} {
  error "invalid observation arguments"
}

proc s5o_get {array_name key default} {
  upvar 1 $array_name row
  if {[info exists row($key)]} { return $row($key) }
  return $default
}

proc s5o_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc s5o_collect {hardware_name role sample elapsed_ms} {
  set last {}
  for {set attempt 0} {$attempt < 5} {incr attempt} {
    set last [wf_collect $hardware_name $role $sample $elapsed_ms]
    if {$last ne ""} {
      array set row $last
      if {[s5o_get row READ_VALID 0] == 1} { return $last }
    }
    if {$attempt < 4} { after 75 }
  }
  return $last
}

proc s5o_state {board role sample elapsed snapshot} {
  if {$snapshot eq ""} {
    s5o_emit S5_PHASE_REARM_OBSERVE_SAMPLE [list BOARD $board ROLE $role \
      SAMPLE $sample ELAPSED_MS $elapsed READ_VALID 0]
    return
  }
  array set row $snapshot
  set read_valid [s5o_get row READ_VALID 0]
  set phase_locked [s5o_get row MAIN_PHASE_LOCKED -1]
  set pstat_locked [s5o_get row PSTAT_LOCKED -1]
  set all_locks [expr {$read_valid == 1 &&
    [s5o_get row HELPER_LOCKED 0] == 1 &&
    [s5o_get row MAIN_FREQ_LOCKED 0] == 1 &&
    $phase_locked == 1 && [s5o_get row MAIN_LOCKED 0] == 1 &&
    $pstat_locked == 1}]
  s5o_emit S5_PHASE_REARM_OBSERVE_SAMPLE [list BOARD $board ROLE $role \
    SAMPLE $sample ELAPSED_MS $elapsed READ_VALID $read_valid \
    CAPTURE_HEALTHY [s5o_get row CAPTURE_HEALTHY -1] \
    RESET_CHANGED [s5o_get row RESET_CHANGED -1] \
    LINK_HEALTHY [s5o_get row LINK_HEALTHY -1] \
    PTP_STATE [s5o_get row PTP_STATE -1] PD_STATE [s5o_get row PD_STATE -1] \
    EXT_STATE [s5o_get row EXT_STATE -1] WRC_MODE [s5o_get row WRC_MODE -1] \
    WR_STATE_VALUE [s5o_get row WR_STATE_VALUE -1] \
    WR_FAILURE_REASON [s5o_get row WR_FAILURE_REASON -1] \
    SPLL_SEQ_STATE [s5o_get row SPLL_SEQ_STATE -1] \
    HELPER_LOCKED [s5o_get row HELPER_LOCKED -1] \
    MAIN_ENABLED [s5o_get row MAIN_ENABLED -1] \
    MAIN_FREQ_LOCKED [s5o_get row MAIN_FREQ_LOCKED -1] \
    MAIN_PHASE_LOCKED $phase_locked MAIN_LOCKED [s5o_get row MAIN_LOCKED -1] \
    PSTAT_LOCKED $pstat_locked STATUS_TIME_VALID [s5o_get row STATUS_TIME_VALID -1] \
    STATUS_PPS_VALID [s5o_get row STATUS_PPS_VALID -1] ALL_LOCKS $all_locks]
  return $all_locks
}

proc s5o_run {} {
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

  s5o_emit S5_PHASE_REARM_OBSERVE_CONFIG [list TRIAL $::s5o_trial_id \
    DURATION_MS $::s5o_duration_ms CAPTURE_GAP_MS $::s5o_capture_gap_ms \
    READ_ONLY 1 VUART_WRITE 0 COMPILE 0 PROGRAM 0 RESET 0 POWER_CYCLE 0]

  set begin_ms [clock milliseconds]
  set deadline_ms [expr {$begin_ms + $::s5o_duration_ms}]
  set sample 0
  set lock_observed 0
  set invalid_samples 0
  set transport_failure 0
  set reset_changed 0
  set session_failure_seen 0
  while {[clock milliseconds] <= $deadline_ms} {
    set elapsed [expr {[clock milliseconds] - $begin_ms}]
    set slave [s5o_collect $slave_hardware SLAVE $sample $elapsed]
    set master [s5o_collect $master_hardware MASTER $sample $elapsed]
    if {$slave eq "" || $master eq ""} {
      set transport_failure 1
      s5o_emit S5_PHASE_REARM_OBSERVE_PAIR [list SAMPLE $sample \
        ELAPSED_MS $elapsed READ_VALID 0]
      break
    }
    array set s $slave
    array set m $master
    set master_locks [s5o_state $master_hardware MASTER $sample $elapsed $master]
    set slave_locks [s5o_state $slave_hardware SLAVE $sample $elapsed $slave]
    if {[s5o_get m READ_VALID 0] != 1 || [s5o_get s READ_VALID 0] != 1} {
      incr invalid_samples
    }
    if {[s5o_get m RESET_CHANGED 0] || [s5o_get s RESET_CHANGED 0]} {
      set reset_changed 1
    }
    if {[s5o_get s WR_FAILURE_REASON 0] > 0} { set session_failure_seen 1 }
    if {$master_locks || $slave_locks} {
      # Only the Slave's five lock signals are a Step5 candidate; the Master
      # state is emitted for correlation, never used as a pass shortcut.
      if {$slave_locks} {
        set lock_observed 1
        puts [format "S5_PHASE_REARM_LOCK_OBSERVED sample=%d elapsed_ms=%d helper=1 main_freq=1 main_phase=1 main_lock=1 pstat=1" \
          $sample $elapsed]
        flush stdout
        break
      }
    }
    incr sample
    after $::s5o_capture_gap_ms
  }

  if {$transport_failure} {
    set result INCONCLUSIVE_RUNTIME_TRANSPORT
  } elseif {$reset_changed} {
    set result INCONCLUSIVE_RESET_CHANGED
  } elseif {$lock_observed} {
    set result RECOVERY_LOCK_OBSERVED
  } elseif {$session_failure_seen && $invalid_samples == 0} {
    set result WR_SESSION_FAILURE_NO_PHASE_LOCK
  } elseif {$invalid_samples > 0} {
    set result INCONCLUSIVE_INVALID_FRAMES
  } else {
    set result TIMEOUT_NO_PHASE_LOCK
  }
  puts [format "S5_PHASE_REARM_OBSERVE_RESULT=%s" $result]
  puts [format "S5_PHASE_REARM_OBSERVE_STEP5_PASS=NO REASON=%s" $result]
  puts [format "S5_PHASE_REARM_OBSERVE_DONE result=%s" $result]
  flush stdout
}

s5o_run
