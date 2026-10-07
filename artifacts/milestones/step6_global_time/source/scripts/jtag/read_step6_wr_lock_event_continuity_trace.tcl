# Read-only Step 6 observer for source-backed WR lock/admission events.
# Never uses counter subtraction, S_LOCK tail data, or a control write to
# trigger the post-event capture window.

package require ::quartus::insystem_source_probe

set ::trial_id "EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001"
set ::pretrigger_timeout_ms 300000
set ::post_event_window_ms 5000
set ::invalid_row_limit 5
set ::clock_source UNKNOWN
set ::last_clock_ms -1

proc s6e_now_ms {} {
  set value ""
  if {![catch {clock clicks -milliseconds} clicks_value] &&
      [string is double -strict $clicks_value] &&
      [scan $clicks_value %f clicks_numeric] == 1} {
    set value [expr {wide(round($clicks_numeric))}]
    set ::clock_source clock_clicks_ms
  }
  if {$value eq ""} {
    set uptime_ms -1
    if {[catch {
      set uptime_fd [open /proc/uptime r]
      set uptime_line [gets $uptime_fd]
      close $uptime_fd
      if {![regexp {^([0-9]+)\.([0-9]+)} $uptime_line -> uptime_seconds uptime_fraction]} {
        error "invalid /proc/uptime record"
      }
      set uptime_fraction [string range "${uptime_fraction}000" 0 2]
      if {[scan $uptime_seconds %d uptime_seconds_numeric] != 1 ||
          [scan $uptime_fraction %d uptime_fraction_numeric] != 1} {
        error "invalid /proc/uptime fields"
      }
      set uptime_ms [expr {$uptime_seconds_numeric * 1000 + $uptime_fraction_numeric}]
    }]} {
      error "no supported monotonic elapsed-time clock"
    }
    set value $uptime_ms
    set ::clock_source proc_uptime_ms
  }
  if {$::last_clock_ms >= 0 && $value < $::last_clock_ms} {
    error "monotonic elapsed-time clock moved backwards"
  }
  set ::last_clock_ms $value
  return $value
}

set ::capture_start_ms [s6e_now_ms]
set ::sample_count 0
set ::read_valid_count 0
set ::invalid_row_streak 0
set ::step1_established 0
set ::active_wr_seen 0
set ::failure_event_pending 0
set ::terminal_streak 0
set ::event_triggered 0
set ::event_kind NONE
set ::event_read_begin_ms -1
set ::event_read_end_ms -1
set ::event_elapsed_ms -1
set ::stop_reason NONE
set ::last_row_end_ms -1
array set ::reset_baseline {}
set ::previous_failure_count -1

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

proc s6e_raw_valid {value} {
  if {![is_hex $value]} { return 0 }
  set text $value
  if {[string length $text] > 8} {
    set high_word [word32 [string range $text 0 end-8]]
    if {$high_word >= 0 && (($high_word >> 16) & 0xffff) == 0xA5A5} {
      return 0
    }
  }
  if {[stale_jtag_word $value]} { return 0 }
  return [expr {[word32 $value] >= 0}]
}

proc s6e_status_step1 {status} {
  if {![is_hex $status]} { return -1 }
  foreach bit {0 1 2 3 6 7 15} {
    if {[bit32 $status $bit] != 1} { return 0 }
  }
  foreach bit {11 12 13 14} {
    if {[bit32 $status $bit] != 0} { return 0 }
  }
  if {[bit64_high $status 0] != 1} { return 0 }
  return 1
}

proc s6e_timed_read {reader addr} {
  set begin [s6e_now_ms]
  set value [uplevel #0 [list $reader $addr]]
  set end [s6e_now_ms]
  return [list $value $begin $end]
}

proc s6e_signal_id {word} {
  set value [word32 $word]
  if {$value < 0} { return -1 }
  return [expr {($value >> 16) & 0xffff}]
}

proc s6e_signal_count {word} {
  set value [word32 $word]
  if {$value < 0} { return -1 }
  return [expr {$value & 0xffff}]
}

proc s6e_state_name {state} {
  switch -- $state {
    0 { return WRS_IDLE }
    1 { return WRS_PRESENT }
    2 { return WRS_S_LOCK }
    3 { return WRS_M_LOCK }
    4 { return WRS_LOCKED }
    5 { return WRS_CALIBRATION }
    6 { return WRS_CALIBRATED }
    7 { return WRS_RESP_CALIB_REQ }
    8 { return WRS_WR_LINK_ON }
  }
  return UNKNOWN
}

proc s6e_read_row {sample elapsed_ms} {
  set row_start [s6e_now_ms]
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]

  # These raw packed words are the source-backed success-event observations.
  lassign [s6e_timed_read wb_read_critical 0x00100A4C] wr_state state_begin state_end
  lassign [s6e_timed_read wb_read_validated 0x00100A64] wr_rx_signal rx_begin rx_end
  lassign [s6e_timed_read wb_read_validated 0x00100A68] wr_tx_signal tx_begin tx_end
  lassign [s6e_timed_read wb_read_validated 0x00100A6C] wr_failure failure_begin failure_end
  lassign [s6e_timed_read wb_read_validated 0x00100A50] wr_reject reject_begin reject_end

  # Context only: each counter is separately timed; the group is non-atomic.
  lassign [s6e_timed_read wb_read 0x00100A8C] lock_result result_begin result_end
  lassign [s6e_timed_read wb_read_counter 0x00100A90] lock_polls polls_begin polls_end
  lassign [s6e_timed_read wb_read_counter 0x00100A94] lock_unlocked unlocked_begin unlocked_end
  lassign [s6e_timed_read wb_read_counter 0x00100A98] lock_calib_fail calib_begin calib_end
  lassign [s6e_timed_read wb_read_counter 0x00100A9C] lock_enable enable_begin enable_end

  # The S_LOCK tail is context only. Equal sequence words do not establish
  # an atomic/seqlock snapshot and it never drives success or stop decisions.
  set tail_begin [s6e_now_ms]
  set tail_seq_before [wb_read 0x00100BFC]
  set tail_magic [wb_read 0x00100BE0]
  set tail_stage [wb_read 0x00100BE4]
  set tail_retry [wb_read 0x00100BE8]
  set tail_entry_tics [wb_read 0x00100BEC]
  set tail_remaining_ms [wb_read 0x00100BF0]
  set tail_poll_detail [wb_read 0x00100BF4]
  set tail_wr_state [wb_read 0x00100BF8]
  set tail_seq_after [wb_read 0x00100BFC]
  set tail_end [s6e_now_ms]

  # Minimal downstream status.
  set spll_state [wb_read_validated 0x00100AA0]
  set helper_state [wb_read_validated 0x00100ABC]
  set main_state [wb_read_validated 0x00100AC4]
  set pstat [wb_read_validated 0x00100A0C]
  set sstat [wb_read_validated 0x00100A08]
  set ucnt [wb_read_validated 0x00100A48]

  set row_end [s6e_now_ms]
  set row_spacing -1
  if {$::last_row_end_ms >= 0} {
    set row_spacing [expr {$row_start - $::last_row_end_ms}]
  }
  set ::last_row_end_ms $row_end

  # READ_VALID covers only health/reset/failure guard inputs. State/TX event
  # words, counters, and context groups have independent validity fields.
  set critical_values [list $status $entry $reset $wr_failure]
  set read_valid 1
  foreach value $critical_values {
    if {![s6e_raw_valid $value]} { set read_valid 0 }
  }

  set boot_generation [probe_high_counter_hex $entry]
  set cpu_reset_count [probe_byte_counter_hex $reset 16]
  set wr_core_reset_count [probe_byte_counter_hex $reset 24]
  set si_config_drop_count [probe_byte_counter_hex $reset 40]
  foreach value [list $boot_generation $cpu_reset_count $wr_core_reset_count $si_config_drop_count] {
    if {$value eq "INVALID"} { set read_valid 0 }
  }

  set step1_gate [s6e_status_step1 $status]
  if {$step1_gate < 0} { set read_valid 0 }
  set wr_state_word [word32 $wr_state]
  set wr_state_value [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 11) & 0xf)}]
  set wr_next_state [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 15) & 0xf)}]
  set wr_rx_id [s6e_signal_id $wr_rx_signal]
  set wr_rx_count [s6e_signal_count $wr_rx_signal]
  set wr_tx_id [s6e_signal_id $wr_tx_signal]
  set wr_tx_count [s6e_signal_count $wr_tx_signal]

  set failure_word [word32 $wr_failure]
  set failure_count_u8 [expr {$failure_word < 0 ? -1 : ($failure_word & 0xff)}]
  set disable_cause [expr {$failure_word < 0 ? -1 : (($failure_word >> 8) & 0x7)}]
  set disable_valid [expr {$failure_word < 0 ? -1 : (($failure_word >> 11) & 1)}]
  set failure_reason_valid [expr {$failure_word < 0 ? 0 : !$disable_valid}]
  set failure_reason [expr {$failure_word < 0 || $disable_valid ? -1 : (($failure_word >> 9) & 0x7f)}]
  set reject_word [word32 $wr_reject]
  set reject_reason [expr {$reject_word < 0 ? -1 : ($reject_word & 0xff)}]
  set reject_count [expr {$reject_word < 0 ? -1 : (($reject_word >> 8) & 0xffffff)}]

  set state_valid [expr {$wr_state_word >= 0 && $wr_state_value >= 0 && $wr_state_value <= 8 && $wr_next_state >= 0 && $wr_next_state <= 8}]
  set tx_signal_valid [expr {[s6e_raw_valid $wr_tx_signal] && $wr_tx_id >= 0 && $wr_tx_count >= 0}]
  set context_read_valid 1
  foreach value [list $wr_rx_signal $wr_reject $tail_seq_before $tail_magic $tail_stage \
      $tail_seq_after $tail_retry $tail_entry_tics $tail_remaining_ms $tail_poll_detail $tail_wr_state \
      $spll_state $helper_state $main_state $pstat $sstat $ucnt] {
    if {![s6e_raw_valid $value]} { set context_read_valid 0 }
  }
  set row_event_kind NONE
  set event_read_begin -1
  set event_read_end -1
  if {$state_valid && $wr_state_value == 2 && $wr_next_state == 4} {
    set row_event_kind SLOCK_HANDOFF_NEXT_LOCKED
    set event_read_begin $state_begin
    set event_read_end $state_end
    set event_evidence_valid 1
  } elseif {$state_valid && $wr_state_value == 4} {
    set row_event_kind WRS_LOCKED_STATE
    set event_read_begin $state_begin
    set event_read_end $state_end
    set event_evidence_valid 1
  } elseif {$tx_signal_valid && $wr_tx_id == 0x1002 && $wr_tx_count > 0} {
    set row_event_kind TX_LOCKED_SEND_SUCCESS
    set event_read_begin $tx_begin
    set event_read_end $tx_end
    set event_evidence_valid 1
  } else {
    # A negative observation is valid only when both source words were read.
    set event_evidence_valid [expr {$state_valid && $tx_signal_valid}]
  }

  set polls_word [word32 $lock_polls]
  set unlocked_word [word32 $lock_unlocked]
  set calib_word [word32 $lock_calib_fail]
  set enable_word [word32 $lock_enable]
  set counter_read_valid 1
  foreach value [list $lock_result $lock_polls $lock_unlocked $lock_calib_fail $lock_enable] {
    if {![s6e_raw_valid $value]} { set counter_read_valid 0 }
  }

  set spll_word [word32 $spll_state]
  set helper_word [word32 $helper_state]
  set main_word [word32 $main_state]
  set pstat_word [word32 $pstat]
  set sstat_word [word32 $sstat]
  set ucnt_word [word32 $ucnt]
  set spll_seq_state [expr {$spll_word < 0 ? -1 : ($spll_word & 0xff)}]
  set helper_locked [expr {$helper_word < 0 ? -1 : ($helper_word & 1)}]
  set main_enabled [expr {$main_word < 0 ? -1 : ($main_word & 1)}]
  set main_locked [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq_locked [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase_locked [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  set pstat_locked [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]
  set servo_state [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 8) & 0xf)}]

  set tail_stable 0
  if {[s6e_raw_valid $tail_seq_before] && [s6e_raw_valid $tail_seq_after] &&
      [word32 $tail_seq_before] == [word32 $tail_seq_after]} {
    set tail_stable 1
  }

  return [dict create sample $sample elapsed_ms $elapsed_ms row_start_ms $row_start row_end_ms $row_end \
    row_spacing_ms $row_spacing read_valid $read_valid event_evidence_valid $event_evidence_valid \
    context_read_valid $context_read_valid counter_read_valid $counter_read_valid \
    step1_gate $step1_gate boot_generation $boot_generation cpu_reset_count $cpu_reset_count \
    wr_core_reset_count $wr_core_reset_count si_config_drop_count $si_config_drop_count \
    wr_state_raw $wr_state wr_state_value $wr_state_value wr_state_name [s6e_state_name $wr_state_value] \
    wr_next_state $wr_next_state state_read_begin_ms $state_begin state_read_end_ms $state_end \
    wr_rx_raw $wr_rx_signal wr_rx_id $wr_rx_id wr_rx_count $wr_rx_count rx_read_begin_ms $rx_begin rx_read_end_ms $rx_end \
    wr_tx_raw $wr_tx_signal wr_tx_id $wr_tx_id wr_tx_count $wr_tx_count tx_read_begin_ms $tx_begin tx_read_end_ms $tx_end \
    state_read_valid $state_valid tx_read_valid $tx_signal_valid row_event_kind $row_event_kind event_read_begin_ms $event_read_begin event_read_end_ms $event_read_end \
    wr_failure_raw $wr_failure failure_count_u8 $failure_count_u8 failure_read_begin_ms $failure_begin failure_read_end_ms $failure_end \
    wr_disable_cause $disable_cause wr_disable_valid $disable_valid wr_failure_reason_valid $failure_reason_valid wr_failure_reason $failure_reason \
    wr_reject_raw $wr_reject wr_reject_reason $reject_reason wr_reject_count $reject_count reject_read_begin_ms $reject_begin reject_read_end_ms $reject_end \
    lock_result_raw $lock_result lock_polls_raw $lock_polls lock_unlocked_raw $lock_unlocked lock_calib_fail_raw $lock_calib_fail lock_enable_raw $lock_enable \
    lock_polls_word $polls_word lock_unlocked_word $unlocked_word lock_calib_fail_word $calib_word lock_enable_word $enable_word \
    poll_read_begin_ms $polls_begin poll_read_end_ms $polls_end unlocked_read_begin_ms $unlocked_begin unlocked_read_end_ms $unlocked_end \
    calib_read_begin_ms $calib_begin calib_read_end_ms $calib_end enable_read_begin_ms $enable_begin enable_read_end_ms $enable_end \
    tail_context_only 1 tail_begin_ms $tail_begin tail_end_ms $tail_end tail_seq_before_raw $tail_seq_before tail_seq_after_raw $tail_seq_after tail_stable $tail_stable \
    tail_magic_raw $tail_magic tail_stage_raw $tail_stage tail_retry_raw $tail_retry tail_entry_tics_raw $tail_entry_tics \
    tail_remaining_ms_raw $tail_remaining_ms tail_poll_detail_raw $tail_poll_detail tail_wr_state_raw $tail_wr_state \
    spll_state_raw $spll_state spll_seq_state $spll_seq_state helper_state_raw $helper_state helper_locked $helper_locked \
    main_state_raw $main_state main_enabled $main_enabled main_freq_locked $main_freq_locked main_phase_locked $main_phase_locked main_locked $main_locked \
    pstat_raw $pstat pstat_locked $pstat_locked sstat_raw $sstat servo_state $servo_state ucnt_raw $ucnt ucnt $ucnt_word]
}

proc s6e_stop {reason elapsed_ms} {
  set ::stop_reason $reason
  puts [format "S6E_STOP board=DE5_1-11.2 elapsed_ms=%d samples=%d read_valid=%d invalid_row_streak=%d event_triggered=%d event_kind=%s event_elapsed_ms=%d terminal_streak=%d reason=%s" \
    $elapsed_ms $::sample_count $::read_valid_count $::invalid_row_streak \
    $::event_triggered $::event_kind $::event_elapsed_ms $::terminal_streak $reason]
  flush stdout
}

puts [format "S6E_CONFIG trial=%s target=DE5_1-11.2 pretrigger_timeout_ms=%d post_event_ms=%d read_only=1 compile=0 reset=0 power_cycle=0 counter_nonatomic=1 tail_context_only=1" \
  $::trial_id $::pretrigger_timeout_ms $::post_event_window_ms]
puts [format "S6E_CLOCK source=%s start_ms=%d" $::clock_source $::capture_start_ms]
puts "S6E_EVENT_CONTRACT state_word=0x00100A4C state2_next4=handoff state4=locked tx_word=0x00100A68 tx_id=0x1002_count_nonzero=send_success event_read_bracket=required counters=diagnostic_only slock_tail=context_only"
flush stdout

set ::targets {}
foreach hardware_name [get_hardware_names] {
  if {[string first "1-11.2" $hardware_name] < 0} { continue }
  foreach device_name [get_device_names -hardware_name $hardware_name] {
    lappend ::targets [list $hardware_name $device_name]
  }
}
if {[llength $::targets] != 1} {
  puts [format "S6E_STOP board=DE5_1-11.2 elapsed_ms=0 samples=0 read_valid=0 invalid_row_streak=0 event_triggered=0 event_kind=NONE event_elapsed_ms=-1 terminal_streak=0 reason=NO_OR_AMBIGUOUS_SLAVE_TARGET target_count=%d" [llength $::targets]]
  puts "S6E_DONE"
  flush stdout
  exit 2
}

lassign [lindex $::targets 0] ::hardware_name ::device_name
puts [format "S6E_BOARD board=DE5_1-11.2 hardware=%s device=%s" $::hardware_name $::device_name]
flush stdout

catch {end_insystem_source_probe}
if {[catch {
  start_insystem_source_probe -hardware_name $::hardware_name -device_name $::device_name
  wb_sync_toggle

  while {$::stop_reason eq "NONE"} {
    set elapsed [expr {[s6e_now_ms] - $::capture_start_ms}]
    if {[catch {set row [s6e_read_row $::sample_count $elapsed]} row_error]} {
      puts [format "S6E_FATAL board=DE5_1-11.2 sample=%d elapsed_ms=%d error=%s" $::sample_count $elapsed $row_error]
      s6e_stop FATAL_JTAG_OR_TCL_ERROR $elapsed
      break
    }

    incr ::sample_count
    set read_valid [dict get $row read_valid]
    set event_valid [dict get $row event_evidence_valid]
    set state_read_valid [dict get $row state_read_valid]
    set required_row_valid [expr {$read_valid && $event_valid}]
    set step1 [dict get $row step1_gate]
    set state [dict get $row wr_state_value]
    set immediate_stop NONE
    set row_event_kind [dict get $row row_event_kind]
    set terminal_counter_delta -1

    if {!$required_row_valid} {
      incr ::invalid_row_streak
    } else {
      set ::invalid_row_streak 0
    }

    if {!$read_valid} {
      set ::terminal_streak 0
    } else {
      incr ::read_valid_count
      set boot [dict get $row boot_generation]
      set cpu_reset [dict get $row cpu_reset_count]
      set wr_reset [dict get $row wr_core_reset_count]
      set si_reset [dict get $row si_config_drop_count]
      if {![info exists ::reset_baseline(boot)]} {
        set ::reset_baseline(boot) $boot
        set ::reset_baseline(cpu) $cpu_reset
        set ::reset_baseline(wr) $wr_reset
        set ::reset_baseline(si) $si_reset
      } elseif {$boot ne $::reset_baseline(boot) || $cpu_reset ne $::reset_baseline(cpu) ||
          $wr_reset ne $::reset_baseline(wr) || $si_reset ne $::reset_baseline(si)} {
        set immediate_stop RESET_OR_BOOT_SIGNATURE_CHANGED
      }

      if {$step1 == 1} {
        set ::step1_established 1
      } elseif {$step1 == 0 && $::step1_established && $immediate_stop eq "NONE"} {
        set immediate_stop STEP1_LOST_AFTER_ESTABLISHED
      }

      set failure_count [dict get $row failure_count_u8]
      if {$::previous_failure_count >= 0 && $failure_count >= 0} {
        set terminal_counter_delta [expr {($failure_count - $::previous_failure_count) & 0xff}]
        if {$terminal_counter_delta > 0} { set ::failure_event_pending 1 }
      }
      if {$failure_count >= 0} { set ::previous_failure_count $failure_count }

      set event_eligible [expr {$required_row_valid && $step1 == 1 && $immediate_stop eq "NONE"}]
      if {!$::event_triggered && $event_eligible && $row_event_kind ne "NONE"} {
        set ::event_triggered 1
        set ::event_kind $row_event_kind
        set ::event_read_begin_ms [dict get $row event_read_begin_ms]
        set ::event_read_end_ms [dict get $row event_read_end_ms]
        set ::event_elapsed_ms [expr {$::event_read_end_ms - $::capture_start_ms}]
      }

      if {$state_read_valid && $state >= 2 && $state <= 8} {
        set ::active_wr_seen 1
        # Keep a newly observed failure latched while WR remains active. The
        # stop rule is specifically: new failure record, then three trusted
        # consecutive inactive rows. An intervening active row must not erase
        # that evidence.
        set ::terminal_streak 0
      } elseif {$state_read_valid && ($state == 0 || $state == 1) &&
          $step1 == 1 && !$::event_triggered && $::active_wr_seen && $::failure_event_pending} {
        incr ::terminal_streak
      } else {
        set ::terminal_streak 0
      }
    }

    set capture_elapsed_after [expr {[s6e_now_ms] - $::capture_start_ms}]
    set post_event_elapsed -1
    if {$::event_triggered} {
      set post_event_elapsed [expr {$capture_elapsed_after - $::event_elapsed_ms}]
    }
    set stop_candidate NONE
    if {$immediate_stop ne "NONE"} {
      set stop_candidate $immediate_stop
    } elseif {$::invalid_row_streak >= $::invalid_row_limit} {
      set stop_candidate FIVE_CONSECUTIVE_INVALID_REQUIRED_RAW_ROWS
    } elseif {!$::event_triggered && $::active_wr_seen && $::terminal_streak >= 3} {
      set stop_candidate NEW_FAILURE_RECORD_AND_TERMINAL_WR_EXIT
    } elseif {$::event_triggered && $post_event_elapsed >= $::post_event_window_ms} {
      set stop_candidate POST_EVENT_WINDOW_COMPLETE
    } elseif {!$::event_triggered && $capture_elapsed_after >= $::pretrigger_timeout_ms} {
      set stop_candidate NO_SUCCESS_EVIDENCE_OBSERVED_300S
    }

    set counters_valid [dict get $row counter_read_valid]
    puts [format "S6E_SAMPLE board=DE5_1-11.2 sample=%06d elapsed_ms=%d row_start_ms=%d row_end_ms=%d row_spacing_ms=%d READ_VALID=%d EVENT_EVIDENCE_VALID=%d REQUIRED_ROW_VALID=%d CONTEXT_READ_VALID=%d invalid_row_streak=%d COUNTER_READ_VALID=%d COUNTER_NONATOMIC=1 TAIL_CONTEXT_ONLY=1 STEP1_GATE=%d step1_established=%d boot_generation=%s cpu_reset_count=%s wr_core_reset_count=%s si_config_drop_count=%s WR_STATE_RAW=%s WR_STATE=%d WR_STATE_NAME=%s WR_NEXT_STATE=%d STATE_READ_VALID=%d STATE_READ_BEGIN_MS=%d STATE_READ_END_MS=%d WR_RX_RAW=%s WR_RX_ID=%d WR_RX_COUNT=%d RX_READ_BEGIN_MS=%d RX_READ_END_MS=%d WR_TX_RAW=%s WR_TX_ID=%d WR_TX_COUNT=%d TX_READ_VALID=%d TX_READ_BEGIN_MS=%d TX_READ_END_MS=%d ROW_EVENT_KIND=%s EVENT_READ_BEGIN_MS=%d EVENT_READ_END_MS=%d EVENT_TRIGGERED=%d EVENT_KIND=%s EVENT_FIRST_READ_BEGIN_MS=%d EVENT_FIRST_READ_END_MS=%d EVENT_ELAPSED_MS=%d POST_EVENT_ELAPSED_MS=%d WR_FAILURE_RAW=%s WR_FAILURE_COUNT_U8=%d WR_FAILURE_DELTA_U8=%d FAILURE_READ_BEGIN_MS=%d FAILURE_READ_END_MS=%d WR_FAILURE_REASON_VALID=%d WR_FAILURE_REASON=%d WR_DISABLE_VALID=%d WR_DISABLE_CAUSE=%d WR_REJECT_RAW=%s WR_REJECT_REASON=%d WR_REJECT_COUNT=%d REJECT_READ_BEGIN_MS=%d REJECT_READ_END_MS=%d LOCK_RESULT_RAW=%s LOCK_POLL_COUNT_RAW=%s LOCK_UNLOCKED_COUNT_RAW=%s LOCK_CALIB_FAIL_COUNT_RAW=%s LOCK_ENABLE_COUNT_RAW=%s POLL_READ_BEGIN_MS=%d POLL_READ_END_MS=%d UNLOCKED_READ_BEGIN_MS=%d UNLOCKED_READ_END_MS=%d CALIB_READ_BEGIN_MS=%d CALIB_READ_END_MS=%d ENABLE_READ_BEGIN_MS=%d ENABLE_READ_END_MS=%d SLOCK_TAIL_BEGIN_MS=%d SLOCK_TAIL_END_MS=%d SLOCK_TAIL_SEQ_BEFORE_RAW=%s SLOCK_TAIL_SEQ_AFTER_RAW=%s SLOCK_TAIL_STABLE=%d SLOCK_STAGE_RAW=%s SLOCK_RETRY_RAW=%s SLOCK_REMAINING_MS_RAW=%s SLOCK_POLL_DETAIL_RAW=%s SLOCK_WR_STATE_RAW=%s SPLL_STATE_RAW=%s SPLL_SEQ_STATE=%d HELPER_STATE_RAW=%s HELPER_LOCK=%d MAIN_STATE_RAW=%s MAIN_ENABLED=%d MAIN_FREQ_LOCK=%d MAIN_PHASE_LOCK=%d MAIN_LOCK=%d PSTAT_RAW=%s PSTAT_LOCK=%d SERVO_STATE=%d UCNT_RAW=%s UCNT=%d active_wr_seen=%d failure_event_pending=%d terminal_streak=%d stop_candidate=%s" \
      [dict get $row sample] [dict get $row elapsed_ms] [dict get $row row_start_ms] [dict get $row row_end_ms] [dict get $row row_spacing_ms] \
      $read_valid $event_valid $required_row_valid [dict get $row context_read_valid] \
      $::invalid_row_streak $counters_valid $step1 $::step1_established \
      [dict get $row boot_generation] [dict get $row cpu_reset_count] [dict get $row wr_core_reset_count] [dict get $row si_config_drop_count] \
      [dict get $row wr_state_raw] $state [dict get $row wr_state_name] [dict get $row wr_next_state] [dict get $row state_read_valid] [dict get $row state_read_begin_ms] [dict get $row state_read_end_ms] \
      [dict get $row wr_rx_raw] [dict get $row wr_rx_id] [dict get $row wr_rx_count] [dict get $row rx_read_begin_ms] [dict get $row rx_read_end_ms] \
      [dict get $row wr_tx_raw] [dict get $row wr_tx_id] [dict get $row wr_tx_count] [dict get $row tx_read_valid] [dict get $row tx_read_begin_ms] [dict get $row tx_read_end_ms] \
      $row_event_kind [dict get $row event_read_begin_ms] [dict get $row event_read_end_ms] $::event_triggered $::event_kind \
      $::event_read_begin_ms $::event_read_end_ms $::event_elapsed_ms $post_event_elapsed \
      [dict get $row wr_failure_raw] [dict get $row failure_count_u8] $terminal_counter_delta [dict get $row failure_read_begin_ms] [dict get $row failure_read_end_ms] \
      [dict get $row wr_failure_reason_valid] [dict get $row wr_failure_reason] [dict get $row wr_disable_valid] [dict get $row wr_disable_cause] \
      [dict get $row wr_reject_raw] [dict get $row wr_reject_reason] [dict get $row wr_reject_count] [dict get $row reject_read_begin_ms] [dict get $row reject_read_end_ms] \
      [dict get $row lock_result_raw] [dict get $row lock_polls_raw] [dict get $row lock_unlocked_raw] [dict get $row lock_calib_fail_raw] [dict get $row lock_enable_raw] \
      [dict get $row poll_read_begin_ms] [dict get $row poll_read_end_ms] [dict get $row unlocked_read_begin_ms] [dict get $row unlocked_read_end_ms] \
      [dict get $row calib_read_begin_ms] [dict get $row calib_read_end_ms] [dict get $row enable_read_begin_ms] [dict get $row enable_read_end_ms] \
      [dict get $row tail_begin_ms] [dict get $row tail_end_ms] [dict get $row tail_seq_before_raw] [dict get $row tail_seq_after_raw] [dict get $row tail_stable] \
      [dict get $row tail_stage_raw] [dict get $row tail_retry_raw] [dict get $row tail_remaining_ms_raw] [dict get $row tail_poll_detail_raw] [dict get $row tail_wr_state_raw] \
      [dict get $row spll_state_raw] [dict get $row spll_seq_state] [dict get $row helper_state_raw] [dict get $row helper_locked] \
      [dict get $row main_state_raw] [dict get $row main_enabled] [dict get $row main_freq_locked] [dict get $row main_phase_locked] [dict get $row main_locked] \
      [dict get $row pstat_raw] [dict get $row pstat_locked] [dict get $row servo_state] [dict get $row ucnt_raw] [dict get $row ucnt] \
      $::active_wr_seen $::failure_event_pending $::terminal_streak $stop_candidate]
    flush stdout

    if {$stop_candidate ne "NONE"} {
      s6e_stop $stop_candidate $capture_elapsed_after
    }
  }
} fatal_error]} {
  puts [format "S6E_FATAL board=DE5_1-11.2 sample=%d error=%s" $::sample_count $fatal_error]
  if {$::stop_reason eq "NONE"} {
    s6e_stop FATAL_JTAG_OR_TCL_ERROR [expr {[s6e_now_ms] - $::capture_start_ms}]
  }
}

catch {end_insystem_source_probe}
if {$::stop_reason eq "NONE"} {
  s6e_stop OBSERVER_EXIT_WITHOUT_STOP_REASON [expr {[s6e_now_ms] - $::capture_start_ms}]
}
puts [format "S6E_SUMMARY trial=%s board=DE5_1-11.2 samples=%d read_valid=%d invalid_row_streak=%d event_triggered=%d event_kind=%s event_elapsed_ms=%d stop_reason=%s wb_timeouts=%d wb_invalid=%d" \
  $::trial_id $::sample_count $::read_valid_count $::invalid_row_streak $::event_triggered $::event_kind $::event_elapsed_ms $::stop_reason \
  $::wb_timeout_count $::wb_invalid_count]
puts "S6E_DONE"
flush stdout
