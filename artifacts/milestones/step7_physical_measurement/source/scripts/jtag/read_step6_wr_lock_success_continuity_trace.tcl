# Step 6: first successful locking_poll() and the following WR admission.
# Read-only, single-Slave observer.  It performs only Wishbone reads through
# the established runtime mailbox; it never requests a diagnostic snapshot or
# writes a firmware control register.
#
# The poll counters are read separately, not atomically.  A positive derived
# success count is therefore held as a candidate and must remain consistent
# in the next trusted row before it starts the 5 s post-success window.

package require ::quartus::insystem_source_probe

set ::trial_id "EXP-S6-WR-LOCK-SUCCESS-CONTINUITY-20261001"
set ::pretrigger_timeout_ms 300000
set ::post_success_window_ms 5000
set ::invalid_row_limit 5
set ::invalid_metric_limit 5
set ::s6w_clock_source UNKNOWN
set ::s6w_last_clock_ms -1
proc s6w_now_ms {} {
  set value ""
  if {![catch {clock clicks -milliseconds} clicks_value] &&
      [string is double -strict $clicks_value]} {
    if {[scan $clicks_value %f clicks_numeric] == 1} {
      set value [expr {wide(round($clicks_numeric))}]
      set ::s6w_clock_source clock_clicks_ms
    }
  }
  if {$value eq ""} {
    # Quartus 17's embedded Tcl may reject the -milliseconds option. Pain is
    # Linux, so /proc/uptime provides a monotonic fallback independent of
    # wall-clock/NTP adjustments.
    set uptime_ms -1
    if {![catch {
      set uptime_fd [open /proc/uptime r]
      set uptime_line [gets $uptime_fd]
      close $uptime_fd
      if {![regexp {^([0-9]+)\.([0-9]+)} $uptime_line -> uptime_seconds uptime_fraction]} {
        error "invalid /proc/uptime record"
      }
      set uptime_fraction [string range "${uptime_fraction}000" 0 2]
      if {[scan $uptime_seconds %d uptime_seconds_numeric] != 1 ||
          [scan $uptime_fraction %d uptime_fraction_numeric] != 1} {
        error "invalid /proc/uptime numeric fields"
      }
      set uptime_ms [expr {$uptime_seconds_numeric * 1000 + $uptime_fraction_numeric}]
    }]} {
      error "no supported monotonic elapsed-time clock"
    }
    set value $uptime_ms
    set ::s6w_clock_source proc_uptime_ms
  }
  if {$::s6w_last_clock_ms >= 0 && $value < $::s6w_last_clock_ms} {
    error "monotonic elapsed-time clock moved backwards"
  }
  set ::s6w_last_clock_ms $value
  return $value
}

set ::capture_start_click [s6w_now_ms]
set ::sample_count 0
set ::valid_count 0
set ::invalid_streak 0
set ::invalid_metric_streak 0
set ::step1_established 0
set ::active_wr_seen 0
set ::terminal_streak 0
set ::success_candidate_pending 0
set ::success_candidate_ms -1
set ::success_candidate_total -1
set ::success_candidate_delta -1
set ::success_triggered 0
set ::success_trigger_ms -1
set ::success_trigger_confirm_ms -1
set ::stop_reason NONE
set ::last_row_end_ms -1
array set ::reset_baseline {}
array set ::counter_previous {}

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

proc s6w_raw_valid {value} {
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

proc s6w_status_step1 {status} {
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

proc s6w_u32_delta {first last} {
  if {$first < 0 || $last < 0} { return -1 }
  if {$last >= $first} { return [expr {$last - $first}] }
  if {$first >= 0xF0000000 && $last <= 0x0FFFFFFF} {
    return [expr {(1 << 32) - $first + $last}]
  }
  return -1
}

proc s6w_state_name {state} {
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

proc s6w_signal_id {word} {
  set value [word32 $word]
  if {$value < 0} { return -1 }
  return [expr {($value >> 16) & 0xffff}]
}

proc s6w_signal_count {word} {
  set value [word32 $word]
  if {$value < 0} { return -1 }
  return [expr {$value & 0xffff}]
}

proc s6w_read_row {hardware_name device_name sample elapsed_ms} {
  set row_start [s6w_now_ms]

  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]

  # WR admission state/signals and source-mapped failure shadows.
  set wr_state [wb_read_critical 0x00100A4C]
  set wr_rx_signal [wb_read_validated 0x00100A64]
  set wr_tx_signal [wb_read_validated 0x00100A68]
  set wr_failure [wb_read_critical 0x00100A6C]
  set wr_reject [wb_read_validated 0x00100A50]

  # Keep the lock counters in one visibly bracketed group.  They are still
  # sequential Wishbone reads, so the analyzer does not call them atomic.
  set counters_begin [s6w_now_ms]
  set lock_result [wb_read_critical 0x00100A8C]
  set lock_polls [wb_read_counter 0x00100A90]
  set lock_unlocked [wb_read_counter 0x00100A94]
  set lock_calib_fail [wb_read_counter 0x00100A98]
  set lock_enable [wb_read_counter 0x00100A9C]
  set counters_end [s6w_now_ms]

  # S_LOCK tail overlay: sequence is the firmware's publish-last marker.
  set slock_begin [s6w_now_ms]
  set slock_seq_before [wb_read 0x00100BFC]
  set slock_magic [wb_read 0x00100BE0]
  set slock_stage [wb_read 0x00100BE4]
  set slock_retry [wb_read 0x00100BE8]
  set slock_entry_tics [wb_read 0x00100BEC]
  set slock_remaining_ms [wb_read 0x00100BF0]
  set slock_poll_detail [wb_read 0x00100BF4]
  set slock_wr_state [wb_read 0x00100BF8]
  set slock_seq_after [wb_read 0x00100BFC]
  set slock_end [s6w_now_ms]

  # Minimal downstream state. No DMTD/TAG/TRR/IRQ event-chain reads.
  set spll_state [wb_read_critical 0x00100AA0]
  set helper_state [wb_read_critical 0x00100ABC]
  set main_state [wb_read_critical 0x00100AC4]
  set pstat [wb_read_validated 0x00100A0C]
  set sstat [wb_read 0x00100A08]
  set ucnt [wb_read 0x00100A48]

  set row_end [s6w_now_ms]
  set row_spacing -1
  if {$::last_row_end_ms >= 0} {
    set row_spacing [expr {$row_start - $::last_row_end_ms}]
  }
  set ::last_row_end_ms $row_end

  set critical_values [list $status $entry $reset $wr_state $wr_rx_signal \
    $wr_tx_signal $wr_failure $wr_reject $lock_result $lock_polls \
    $lock_unlocked $lock_calib_fail $lock_enable $spll_state $helper_state \
    $main_state $pstat $sstat $ucnt]
  set row_valid 1
  foreach value $critical_values {
    if {![s6w_raw_valid $value]} { set row_valid 0 }
  }

  set boot_generation [probe_high_counter_hex $entry]
  set cpu_reset_count [probe_byte_counter_hex $reset 16]
  set wr_core_reset_count [probe_byte_counter_hex $reset 24]
  set si_config_drop_count [probe_byte_counter_hex $reset 40]
  foreach value [list $boot_generation $cpu_reset_count \
      $wr_core_reset_count $si_config_drop_count] {
    if {$value eq "INVALID"} { set row_valid 0 }
  }

  set step1_gate [s6w_status_step1 $status]
  set wr_state_word [word32 $wr_state]
  set wr_state_value [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 11) & 0xf)}]
  set wr_next_state [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 15) & 0xf)}]
  set failure_word [word32 $wr_failure]
  set failure_count [expr {$failure_word < 0 ? -1 : ($failure_word & 0xffff)}]
  set disable_valid [expr {$failure_word < 0 ? -1 : (($failure_word >> 11) & 1)}]
  set reject_word [word32 $wr_reject]
  set reject_reason [expr {$reject_word < 0 ? -1 : ($reject_word & 0xff)}]
  set reject_count [expr {$reject_word < 0 ? -1 : (($reject_word >> 8) & 0xffffff)}]
  set result_word [word32 $lock_result]
  set result_code [expr {$result_word < 0 ? -1 : ($result_word & 0xff)}]
  set result_check_lock [expr {$result_word < 0 ? -1 : (($result_word >> 8) & 1)}]
  set failure_reason [expr {$result_word < 0 ? -1 : (($result_word >> 9) & 0x7f)}]
  set poll_word [word32 $lock_polls]
  set unlocked_word [word32 $lock_unlocked]
  set calib_word [word32 $lock_calib_fail]
  set enable_word [word32 $lock_enable]
  set lock_success_total -1
  if {$poll_word >= 0 && $unlocked_word >= 0 && $calib_word >= 0} {
    set lock_success_total [expr {$poll_word - $unlocked_word - $calib_word}]
  }
  if {$step1_gate < 0 || $result_code < 0 || $result_code > 2 ||
      $result_check_lock < 0 || $result_check_lock > 1 ||
      $failure_reason < 0 || $failure_reason > 7} {
    set row_valid 0
  }

  set lock_delta_poll -1
  set lock_delta_unlocked -1
  set lock_delta_calib_fail -1
  set success_poll_delta -1
  set success_metric_valid 0
  if {$row_valid && $lock_success_total >= 0} {
    set success_metric_valid 1
    if {[info exists ::counter_previous(polls)]} {
      set lock_delta_poll [s6w_u32_delta $::counter_previous(polls) $poll_word]
      set lock_delta_unlocked [s6w_u32_delta $::counter_previous(unlocked) $unlocked_word]
      set lock_delta_calib_fail [s6w_u32_delta $::counter_previous(calib_fail) $calib_word]
      if {$lock_delta_poll < 0 || $lock_delta_unlocked < 0 || $lock_delta_calib_fail < 0} {
        set success_metric_valid 0
      } else {
        set success_poll_delta [expr {$lock_delta_poll - $lock_delta_unlocked - $lock_delta_calib_fail}]
        if {$success_poll_delta < 0} { set success_metric_valid 0 }
      }
    }
    if {[info exists ::counter_previous(success_total)] &&
        $lock_success_total < $::counter_previous(success_total)} {
      set success_metric_valid 0
    }
  }

  set slock_magic_word [word32 $slock_magic]
  set slock_seq_before_word [word32 $slock_seq_before]
  set slock_seq_after_word [word32 $slock_seq_after]
  set slock_trace_valid 0
  set slock_tail_fields_valid 1
  foreach value [list $slock_magic $slock_stage $slock_retry $slock_entry_tics \
      $slock_remaining_ms $slock_poll_detail $slock_wr_state \
      $slock_seq_before $slock_seq_after] {
    if {![s6w_raw_valid $value]} { set slock_tail_fields_valid 0 }
  }
  if {$slock_tail_fields_valid && $slock_magic_word == 0x5752534c &&
      $slock_seq_before_word >= 0 && $slock_seq_after_word == $slock_seq_before_word} {
    set slock_trace_valid 1
  }
  set slock_stage_word [word32 $slock_stage]
  set slock_retry_word [word32 $slock_retry]
  set slock_remaining_word [word32 $slock_remaining_ms]
  set slock_detail_word [word32 $slock_poll_detail]
  set slock_last_poll_return [expr {$slock_detail_word < 0 ? -1 : ($slock_detail_word & 0xff)}]
  set slock_check_lock [expr {$slock_detail_word < 0 ? -1 : (($slock_detail_word >> 8) & 1)}]
  set slock_calib_attempt [expr {$slock_detail_word < 0 ? -1 : (($slock_detail_word >> 9) & 1)}]
  set slock_calib_success [expr {$slock_detail_word < 0 ? -1 : (($slock_detail_word >> 10) & 1)}]
  set slock_calib_failure [expr {$slock_detail_word < 0 ? -1 : (($slock_detail_word >> 11) & 1)}]
  set slock_t24p_calibrated [expr {$slock_detail_word < 0 ? -1 : (($slock_detail_word >> 12) & 1)}]

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
  set wr_rx_id [s6w_signal_id $wr_rx_signal]
  set wr_rx_count [s6w_signal_count $wr_rx_signal]
  set wr_tx_id [s6w_signal_id $wr_tx_signal]
  set wr_tx_count [s6w_signal_count $wr_tx_signal]

  return [dict create \
    sample $sample elapsed_ms $elapsed_ms row_start_ms $row_start row_end_ms $row_end \
    row_spacing_ms $row_spacing counters_begin_ms $counters_begin counters_end_ms $counters_end \
    counters_begin_elapsed_ms [expr {$counters_begin - $::capture_start_click}] \
    counters_end_elapsed_ms [expr {$counters_end - $::capture_start_click}] \
    slock_begin_ms $slock_begin slock_end_ms $slock_end row_valid $row_valid \
    step1_gate $step1_gate boot_generation $boot_generation cpu_reset_count $cpu_reset_count \
    wr_core_reset_count $wr_core_reset_count si_config_drop_count $si_config_drop_count \
    wr_state_raw $wr_state wr_state_value $wr_state_value wr_state_name [s6w_state_name $wr_state_value] \
    wr_next_state $wr_next_state wr_rx_raw $wr_rx_signal wr_rx_id $wr_rx_id wr_rx_count $wr_rx_count \
    wr_tx_raw $wr_tx_signal wr_tx_id $wr_tx_id wr_tx_count $wr_tx_count \
    wr_failure_raw $wr_failure wr_failure_count $failure_count wr_disable_valid $disable_valid \
    wr_failure_reason $failure_reason wr_reject_raw $wr_reject wr_reject_reason $reject_reason \
    wr_reject_count $reject_count lock_result_raw $lock_result lock_result_code $result_code \
    lock_result_check_lock $result_check_lock lock_polls_raw $lock_polls lock_unlocked_raw $lock_unlocked \
    lock_calib_fail_raw $lock_calib_fail lock_enable_raw $lock_enable lock_success_total $lock_success_total \
    lock_delta_poll $lock_delta_poll lock_delta_unlocked $lock_delta_unlocked \
    lock_delta_calib_fail $lock_delta_calib_fail success_poll_delta $success_poll_delta \
    lock_polls_word $poll_word lock_unlocked_word $unlocked_word lock_calib_fail_word $calib_word \
    success_metric_valid $success_metric_valid slock_magic_raw $slock_magic \
    slock_stage_raw $slock_stage slock_retry_raw $slock_retry slock_entry_tics_raw $slock_entry_tics \
    slock_remaining_ms_raw $slock_remaining_ms slock_poll_detail_raw $slock_poll_detail \
    slock_wr_state_raw $slock_wr_state slock_seq_before_raw $slock_seq_before \
    slock_seq_after_raw $slock_seq_after slock_trace_valid $slock_trace_valid \
    slock_last_poll_return $slock_last_poll_return slock_check_lock $slock_check_lock \
    slock_calib_attempt $slock_calib_attempt slock_calib_success $slock_calib_success \
    slock_calib_failure $slock_calib_failure slock_t24p_calibrated $slock_t24p_calibrated \
    spll_state_raw $spll_state spll_seq_state $spll_seq_state helper_state_raw $helper_state \
    helper_locked $helper_locked main_state_raw $main_state main_enabled $main_enabled \
    main_freq_locked $main_freq_locked main_phase_locked $main_phase_locked main_locked $main_locked \
    pstat_raw $pstat pstat_locked $pstat_locked sstat_raw $sstat servo_state $servo_state \
    ucnt_raw $ucnt ucnt $ucnt_word]
}

proc s6w_stop {reason board elapsed_ms} {
  set ::stop_reason $reason
  puts [format "S6W_STOP board=%s elapsed_ms=%d samples=%d valid=%d invalid_streak=%d invalid_metric_streak=%d success_triggered=%d success_trigger_ms=%d reason=%s" \
    $board $elapsed_ms $::sample_count $::valid_count $::invalid_streak \
    $::invalid_metric_streak $::success_triggered $::success_trigger_ms $reason]
  flush stdout
}

puts [format "S6W_CONFIG trial=%s target=DE5_1-11.2 pretrigger_timeout_ms=%d post_success_ms=%d artificial_delay_ms=0 read_only=1 compile=0 reset=0 power_cycle=0" \
  $::trial_id $::pretrigger_timeout_ms $::post_success_window_ms]
puts [format "S6W_CLOCK source=%s start_ms=%d" $::s6w_clock_source $::capture_start_click]
puts "S6W_REGISTER_CONTRACT slock_tail=0x00100BE0..0x00100BFC poll_counters=0x00100A90/94/98 wr_signals=0x00100A64/68 downstream=0x00100AA0/ABC/AC4/00C/008/048"
flush stdout

set ::targets {}
foreach hardware_name [get_hardware_names] {
  if {[string first "1-11.2" $hardware_name] < 0} { continue }
  set devices [get_device_names -hardware_name $hardware_name]
  foreach device_name $devices {
    lappend ::targets [list $hardware_name $device_name]
  }
}
if {[llength $::targets] != 1} {
  puts [format "S6W_STOP board=DE5_1-11.2 elapsed_ms=0 samples=0 valid=0 invalid_streak=0 invalid_metric_streak=0 success_triggered=0 success_trigger_ms=-1 reason=NO_OR_AMBIGUOUS_SLAVE_TARGET target_count=%d" [llength $::targets]]
  puts "S6W_DONE"
  flush stdout
  exit 2
}

lassign [lindex $::targets 0] ::hardware_name ::device_name
puts [format "S6W_BOARD board=DE5_1-11.2 hardware=%s device=%s" $::hardware_name $::device_name]
flush stdout

catch {end_insystem_source_probe}
if {[catch {
  start_insystem_source_probe -hardware_name $::hardware_name -device_name $::device_name
  wb_sync_toggle

while {$::stop_reason eq "NONE"} {
    set elapsed [expr {[s6w_now_ms] - $::capture_start_click}]
    set row_error ""
    if {[catch {set row [s6w_read_row $::hardware_name $::device_name $::sample_count $elapsed]} row_error]} {
      puts [format "S6W_FATAL board=DE5_1-11.2 sample=%d elapsed_ms=%d error=%s" $::sample_count $elapsed $row_error]
      s6w_stop FATAL_JTAG_OR_TCL_ERROR DE5_1-11.2 $elapsed
      break
    }

    incr ::sample_count
    set row_valid [dict get $row row_valid]
    set step1 [dict get $row step1_gate]
    set boot [dict get $row boot_generation]
    set cpu_reset [dict get $row cpu_reset_count]
    set wr_reset [dict get $row wr_core_reset_count]
    set si_reset [dict get $row si_config_drop_count]
    set state [dict get $row wr_state_value]
    set reason [dict get $row wr_failure_reason]
    set disable_valid [dict get $row wr_disable_valid]
    set success_total [dict get $row lock_success_total]
    set metric_valid [dict get $row success_metric_valid]
    set success_delta [dict get $row success_poll_delta]
    set candidate_now 0
    set confirmed_now 0
    set candidate_rejected 0
    set immediate_stop NONE

    if {!$row_valid} {
      incr ::invalid_streak
      set ::terminal_streak 0
      incr ::invalid_metric_streak
    } else {
      incr ::valid_count
      set ::invalid_streak 0

      if {![info exists ::reset_baseline(boot)]} {
        set ::reset_baseline(boot) $boot
        set ::reset_baseline(cpu) $cpu_reset
        set ::reset_baseline(wr) $wr_reset
        set ::reset_baseline(si) $si_reset
      } elseif {$boot ne $::reset_baseline(boot) ||
          $cpu_reset ne $::reset_baseline(cpu) ||
          $wr_reset ne $::reset_baseline(wr) ||
          $si_reset ne $::reset_baseline(si)} {
        set immediate_stop RESET_OR_BOOT_SIGNATURE_CHANGED
      }

      if {$step1 == 1} {
        set ::step1_established 1
      } elseif {$step1 == 0 && $::step1_established && $immediate_stop eq "NONE"} {
        set immediate_stop STEP1_LOST_AFTER_ESTABLISHED
      }

      if {$state >= 2 && $state <= 8} { set ::active_wr_seen 1 }

      if {$metric_valid} {
        set ::invalid_metric_streak 0
        if {$::success_candidate_pending && $elapsed > $::success_candidate_ms} {
          if {$success_total >= $::success_candidate_total} {
            set confirmed_now 1
            set ::success_triggered 1
            set ::success_trigger_ms $::success_candidate_ms
            set ::success_trigger_confirm_ms [dict get $row counters_end_elapsed_ms]
            set ::success_candidate_pending 0
          } else {
            set candidate_rejected 1
            set ::success_candidate_pending 0
          }
        }
        if {!$::success_triggered && !$::success_candidate_pending &&
            (($success_delta > 0) ||
             (![info exists ::counter_previous(success_total)] && $success_total > 0)) &&
            $success_total > 0} {
          set candidate_now 1
          set ::success_candidate_pending 1
          set ::success_candidate_ms [dict get $row counters_end_elapsed_ms]
          set ::success_candidate_total $success_total
          set ::success_candidate_delta $success_delta
        }
        if {$success_total >= 0} {
          set ::counter_previous(success_total) $success_total
        }
      } else {
        incr ::invalid_metric_streak
      }

      set poll_word [dict get $row lock_polls_word]
      set unlocked_word [dict get $row lock_unlocked_word]
      set calib_word [dict get $row lock_calib_fail_word]
      if {$poll_word >= 0} { set ::counter_previous(polls) $poll_word }
      if {$unlocked_word >= 0} { set ::counter_previous(unlocked) $unlocked_word }
      if {$calib_word >= 0} { set ::counter_previous(calib_fail) $calib_word }

      if {!$::success_triggered && $::active_wr_seen && $state >= 0 &&
          $state < 2 && $disable_valid == 1 && $reason >= 1 && $reason <= 7} {
        incr ::terminal_streak
      } else {
        set ::terminal_streak 0
      }
    }

    set capture_elapsed_after [expr {[s6w_now_ms] - $::capture_start_click}]
    set post_success_elapsed -1
    if {$::success_triggered} {
      set post_success_elapsed [expr {$capture_elapsed_after - $::success_trigger_confirm_ms}]
    }
    set stop_candidate NONE
    if {$immediate_stop ne "NONE"} {
      set stop_candidate $immediate_stop
    } elseif {$::invalid_streak >= $::invalid_row_limit} {
      set stop_candidate FIVE_CONSECUTIVE_INVALID_CRITICAL_ROWS
    } elseif {$::invalid_metric_streak >= $::invalid_metric_limit} {
      set stop_candidate FIVE_CONSECUTIVE_INVALID_SUCCESS_METRICS
    } elseif {!$::success_triggered && $::terminal_streak >= 3} {
      set stop_candidate WR_SESSION_TERMINATED_BEFORE_SUCCESS
    } elseif {$::success_triggered && $post_success_elapsed >= $::post_success_window_ms} {
      set stop_candidate POST_SUCCESS_WINDOW_COMPLETE
    } elseif {!$::success_triggered && $capture_elapsed_after >= $::pretrigger_timeout_ms} {
      set stop_candidate NO_SUCCESSFUL_LOCK_POLL_300S
    }

    set row_slock_valid [dict get $row slock_trace_valid]
    set trace_stage [word32 [dict get $row slock_stage_raw]]
    if {!$row_slock_valid} { set trace_stage -1 }
    puts [format "S6W_SAMPLE board=DE5_1-11.2 sample=%06d elapsed_ms=%d row_start_ms=%d row_end_ms=%d row_spacing_ms=%d row_valid=%d invalid_streak=%d step1_gate=%d step1_established=%d boot_generation=%s cpu_reset_count=%s wr_core_reset_count=%s si_config_drop_count=%s WR_STATE_RAW=%s WR_STATE=%d WR_STATE_NAME=%s WR_NEXT_STATE=%d WR_RX_RAW=%s WR_RX_ID=%d WR_RX_COUNT=%d WR_TX_RAW=%s WR_TX_ID=%d WR_TX_COUNT=%d WR_FAILURE_RAW=%s WR_FAILURE_COUNT=%d WR_DISABLE_VALID=%d WR_FAILURE_REASON=%d WR_REJECT_RAW=%s WR_REJECT_COUNT=%d WR_REJECT_REASON=%d LOCK_RESULT_RAW=%s LOCK_RESULT_CODE=%d LOCK_RESULT_CHECK_LOCK=%d LOCK_POLL_COUNT_RAW=%s LOCK_UNLOCKED_COUNT_RAW=%s LOCK_CALIB_FAIL_COUNT_RAW=%s LOCK_ENABLE_COUNT_RAW=%s LOCK_SUCCESS_TOTAL=%d DELTA_POLL=%d DELTA_UNLOCKED=%d DELTA_CALIB_FAIL=%d SUCCESS_POLL_DELTA=%d SUCCESS_METRIC_VALID=%d SUCCESS_CANDIDATE=%d SUCCESS_CANDIDATE_REJECTED=%d SUCCESS_CONFIRMED=%d SUCCESS_TRIGGERED=%d SUCCESS_TRIGGER_MS=%d SUCCESS_TRIGGER_CONFIRM_MS=%d POST_SUCCESS_ELAPSED_MS=%d COUNTERS_BEGIN_MS=%d COUNTERS_END_MS=%d COUNTERS_BEGIN_ELAPSED_MS=%d COUNTERS_END_ELAPSED_MS=%d SLOCK_GROUP_BEGIN_MS=%d SLOCK_GROUP_END_MS=%d SLOCK_TRACE_VALID=%d SLOCK_MAGIC_RAW=%s SLOCK_STAGE=%d SLOCK_RETRY_RAW=%s SLOCK_ENTRY_TICS_RAW=%s SLOCK_REMAINING_MS_RAW=%s SLOCK_POLL_DETAIL_RAW=%s SLOCK_LAST_POLL_RETURN=%d SLOCK_CHECK_LOCK=%d SLOCK_CALIB_ATTEMPT=%d SLOCK_CALIB_SUCCESS=%d SLOCK_CALIB_FAILURE=%d SLOCK_T24P_CALIBRATED=%d SLOCK_WR_STATE_RAW=%s SLOCK_SEQ_BEFORE_RAW=%s SLOCK_SEQ_AFTER_RAW=%s SPLL_STATE_RAW=%s SPLL_SEQ_STATE=%d HELPER_STATE_RAW=%s HELPER_LOCK=%d MAIN_STATE_RAW=%s MAIN_ENABLED=%d MAIN_FREQ_LOCK=%d MAIN_PHASE_LOCK=%d MAIN_LOCK=%d PSTAT_RAW=%s PSTAT_LOCK=%d SERVO_STATE=%d UCNT_RAW=%s UCNT=%d terminal_streak=%d stop_candidate=%s" \
      [dict get $row sample] [dict get $row elapsed_ms] [dict get $row row_start_ms] \
      [dict get $row row_end_ms] [dict get $row row_spacing_ms] $row_valid $::invalid_streak \
      $step1 $::step1_established $boot $cpu_reset $wr_reset $si_reset \
      [dict get $row wr_state_raw] $state [dict get $row wr_state_name] [dict get $row wr_next_state] \
      [dict get $row wr_rx_raw] [dict get $row wr_rx_id] [dict get $row wr_rx_count] \
      [dict get $row wr_tx_raw] [dict get $row wr_tx_id] [dict get $row wr_tx_count] \
      [dict get $row wr_failure_raw] [dict get $row wr_failure_count] $disable_valid $reason \
      [dict get $row wr_reject_raw] [dict get $row wr_reject_count] [dict get $row wr_reject_reason] \
      [dict get $row lock_result_raw] [dict get $row lock_result_code] [dict get $row lock_result_check_lock] \
      [dict get $row lock_polls_raw] [dict get $row lock_unlocked_raw] [dict get $row lock_calib_fail_raw] \
      [dict get $row lock_enable_raw] $success_total [dict get $row lock_delta_poll] \
      [dict get $row lock_delta_unlocked] [dict get $row lock_delta_calib_fail] $success_delta $metric_valid \
      $candidate_now $candidate_rejected $confirmed_now $::success_triggered $::success_trigger_ms \
      $::success_trigger_confirm_ms $post_success_elapsed [dict get $row counters_begin_ms] \
      [dict get $row counters_end_ms] [dict get $row counters_begin_elapsed_ms] \
      [dict get $row counters_end_elapsed_ms] [dict get $row slock_begin_ms] \
      [dict get $row slock_end_ms] $row_slock_valid [dict get $row slock_magic_raw] $trace_stage \
      [dict get $row slock_retry_raw] [dict get $row slock_entry_tics_raw] \
      [dict get $row slock_remaining_ms_raw] [dict get $row slock_poll_detail_raw] \
      [dict get $row slock_last_poll_return] [dict get $row slock_check_lock] \
      [dict get $row slock_calib_attempt] [dict get $row slock_calib_success] \
      [dict get $row slock_calib_failure] [dict get $row slock_t24p_calibrated] \
      [dict get $row slock_wr_state_raw] [dict get $row slock_seq_before_raw] \
      [dict get $row slock_seq_after_raw] [dict get $row spll_state_raw] \
      [dict get $row spll_seq_state] [dict get $row helper_state_raw] [dict get $row helper_locked] \
      [dict get $row main_state_raw] [dict get $row main_enabled] [dict get $row main_freq_locked] \
      [dict get $row main_phase_locked] [dict get $row main_locked] [dict get $row pstat_raw] \
      [dict get $row pstat_locked] [dict get $row servo_state] [dict get $row ucnt_raw] \
      [dict get $row ucnt] $::terminal_streak $stop_candidate]
    flush stdout

    if {$stop_candidate ne "NONE"} {
      s6w_stop $stop_candidate DE5_1-11.2 $capture_elapsed_after
    }
  }
} fatal_error]} {
  puts [format "S6W_FATAL board=DE5_1-11.2 sample=%d error=%s" $::sample_count $fatal_error]
  if {$::stop_reason eq "NONE"} {
    s6w_stop FATAL_JTAG_OR_TCL_ERROR DE5_1-11.2 \
      [expr {[s6w_now_ms] - $::capture_start_click}]
  }
}

catch {end_insystem_source_probe}
if {$::stop_reason eq "NONE"} {
  s6w_stop OBSERVER_EXIT_WITHOUT_STOP_REASON DE5_1-11.2 \
    [expr {[s6w_now_ms] - $::capture_start_click}]
}
puts [format "S6W_SUMMARY trial=%s board=DE5_1-11.2 samples=%d valid=%d invalid_streak=%d invalid_metric_streak=%d success_triggered=%d success_trigger_ms=%d success_trigger_confirm_ms=%d stop_reason=%s wb_timeouts=%d wb_invalid=%d" \
  $::trial_id $::sample_count $::valid_count $::invalid_streak $::invalid_metric_streak \
  $::success_triggered $::success_trigger_ms $::success_trigger_confirm_ms $::stop_reason \
  $::wb_timeout_count $::wb_invalid_count]
puts "S6W_DONE"
flush stdout
