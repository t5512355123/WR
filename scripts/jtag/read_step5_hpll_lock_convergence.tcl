# White Rabbit Step5 read-only Helper lock convergence observer.
#
# The firmware WDIAGS task mirrors the actual softpll.helper.ld state into
# the existing WDIAGS shadow. This observer samples that shadow at 100 ms,
# together with the actual lock-detector inputs used by the dashboard. It
# does not write WR configuration, HPLL force controls, or DATA_SNAPSHOT.
#
# Usage:
#   quartus_stp -t read_step5_hpll_lock_convergence.tcl ?samples? ?gap_ms? ?board_filter?
#
# The intended run is 18000 samples at 100 ms (1800 seconds).

package require ::quartus::insystem_source_probe

set samples 18000
set gap_ms 100
set board_filter ""
set poll_attempts 100
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

array set ::wb_toggle {}
array set ::sample_count {}
array set ::valid_frame_count {}
array set ::invalid_frame_count {}
array set ::helper_error_count {}
array set ::helper_error_sum {}
array set ::helper_error_sumsq {}
array set ::helper_error_max_abs {}
array set ::helper_error_in_window {}
array set ::helper_lock_max {}
array set ::helper_lock_final {}
array set ::helper_locked_seen {}
array set ::helper_locked_final {}
array set ::helper_first_locked_sample {}
array set ::helper_lock_changed_events {}
array set ::main_enabled_final {}
array set ::main_locked_final {}
array set ::main_freq_locked_final {}
array set ::main_phase_locked_final {}
array set ::pstat_locked_final {}
array set ::spll_delock_first {}
array set ::spll_delock_max {}
array set ::spll_delock_final {}
array set ::current_tics_first {}
array set ::current_tics_final {}
array set ::helper_state_first {}
array set ::helper_state_final {}
array set ::tracker_first {}
array set ::tracker_final {}
array set ::burst_first {}
array set ::burst_final {}
array set ::bootstrap_first {}
array set ::bootstrap_final {}
array set ::reset_first {}
array set ::reset_final {}
array set ::elapsed_first {}
array set ::elapsed_final {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc word64 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  if {$word < 0} {
    set word [expr {$word + 0x10000000000000000}]
  }
  return $word
}

proc display_value {value} {
  if {![is_hex $value]} { return $value }
  return [string toupper $value]
}

proc field32 {value low width} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($word >> $low) & $mask}]
}

proc signed32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  if {$word >= 0x80000000} {
    return [expr {$word - 0x100000000}]
  }
  return $word
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc probe_high32 {value} {
  if {![is_hex $value]} { return INVALID }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  set text [string repeat 0 [expr {16 - [string length $text]}]]$text
  scan [string range $text 0 7] %x word
  return [expr {$word & 0xffffffff}]
}

proc probe_field32 {value low width} {
  set high [probe_high32 $value]
  if {$high eq "INVALID"} { return INVALID }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($high >> $low) & $mask}]
}

proc wb_read {hardware_name addr} {
  global poll_attempts
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 5
  for {set n 0} {$n < $poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value INVALID
    }
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} {
        return [format %08X [expr {$word & 0xffffffff}]]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc wb_sync_toggle {hardware_name} {
  set value [probe_read 1]
  if {[is_hex $value]} {
    scan $value %x word
    set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc counter_delta {first last width} {
  if {$first eq "INVALID" || $last eq "INVALID"} { return INVALID }
  if {![string is integer -strict $first] || ![string is integer -strict $last]} {
    return INVALID
  }
  set modulus [expr {1 << $width}]
  if {$last >= $first} { return [expr {$last - $first}] }
  return [expr {$last + $modulus - $first}]
}

proc frame_valid {ctrl_begin ctrl_end} {
  set a [word32 $ctrl_begin]
  set b [word32 $ctrl_end]
  if {$a < 0 || $b < 0} { return 0 }
  return [expr {(($a & 1) != 0) && (($b & 1) != 0) && $a == $b}]
}

proc read_helper_pair {hardware_name} {
  # The experiment keeps the source-defined Helper settings at threshold=200
  # and lock_samples=10000. Reject a mailbox response that cannot represent
  # that configuration or a lock counter beyond its configured maximum, then
  # retry the pair so one stale response cannot become evidence.
  for {set attempt 0} {$attempt < 4} {incr attempt} {
    set state [wb_read $hardware_name 0x00100ABC]
    set limits [wb_read $hardware_name 0x00100AC0]
    set threshold [field32 $limits 0 16]
    set lock_samples [field32 $limits 16 16]
    set lock_count [field32 $state 16 16]
    if {$threshold eq "200" && $lock_samples eq "10000" &&
        $lock_count ne "INVALID" && $lock_count <= $lock_samples} {
      return [list $state $limits]
    }
    after 2
  }
  return [list INVALID INVALID]
}

proc initialize_board {hardware_name} {
  set ::sample_count($hardware_name) 0
  set ::valid_frame_count($hardware_name) 0
  set ::invalid_frame_count($hardware_name) 0
  set ::helper_error_count($hardware_name) 0
  set ::helper_error_sum($hardware_name) 0.0
  set ::helper_error_sumsq($hardware_name) 0.0
  set ::helper_error_max_abs($hardware_name) 0
  set ::helper_error_in_window($hardware_name) 0
  set ::helper_lock_max($hardware_name) 0
  set ::helper_lock_final($hardware_name) INVALID
  set ::helper_locked_seen($hardware_name) 0
  set ::helper_locked_final($hardware_name) INVALID
  set ::helper_first_locked_sample($hardware_name) NONE
  set ::helper_lock_changed_events($hardware_name) 0
  set ::main_enabled_final($hardware_name) INVALID
  set ::main_locked_final($hardware_name) INVALID
  set ::main_freq_locked_final($hardware_name) INVALID
  set ::main_phase_locked_final($hardware_name) INVALID
  set ::pstat_locked_final($hardware_name) INVALID
  set ::spll_delock_first($hardware_name) INVALID
  set ::spll_delock_max($hardware_name) 0
  set ::spll_delock_final($hardware_name) INVALID
  set ::current_tics_first($hardware_name) INVALID
  set ::current_tics_final($hardware_name) INVALID
  set ::helper_state_first($hardware_name) INVALID
  set ::helper_state_final($hardware_name) INVALID
  set ::tracker_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::tracker_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::burst_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::burst_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::bootstrap_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::bootstrap_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::elapsed_first($hardware_name) 0
  set ::elapsed_final($hardware_name) 0
}

proc emit_sample {hardware_name sample elapsed_ms} {
  # CTRL_BEGIN/END bracket the existing WDIAGS shadow. Direct probes remain
  # read-only and are recorded even when a mailbox frame is inconsistent.
  set ctrl_begin [wb_read $hardware_name 0x00100A04]
  set tracker_raw [probe_read 39]
  set burst_raw [probe_read 37]
  set bootstrap_raw [probe_read 42]
  set entry_probe [probe_read 26]
  set reset_probe [probe_read 27]
  foreach {helper_state helper_limits} [read_helper_pair $hardware_name] break
  set main_state [wb_read $hardware_name 0x00100AC4]
  set pstat [wb_read $hardware_name 0x00100A0C]
  set spll_state [wb_read $hardware_name 0x00100AA0]
  set helper_error [wb_read $hardware_name 0x00100AD8]
  set helper_output [wb_read $hardware_name 0x00100ADC]
  set wr_lock_unlocked [wb_read $hardware_name 0x00100A94]
  set current_tics [wb_read $hardware_name 0x00100B3C]
  set ctrl_end [wb_read $hardware_name 0x00100A04]

  set tracker_word [word64 $tracker_raw]
  set burst_word [word64 $burst_raw]
  set bootstrap_word [word64 $bootstrap_raw]
  set target [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 0) & 0xffff)}]
  set applied [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 16) & 0xffff)}]
  set normal_req [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 32) & 0xffff)}]
  set normal_done [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 48) & 0xffff)}]
  set forced_trigger [expr {($burst_word < 0) ? "INVALID" : (($burst_word >> 0) & 0xff)}]
  set forced_pending [expr {($burst_word < 0) ? "INVALID" : (($burst_word >> 8) & 0xff)}]
  set forced_done [expr {($burst_word < 0) ? "INVALID" : (($burst_word >> 16) & 0xff)}]
  set dco_step [expr {($burst_word < 0) ? "INVALID" : (($burst_word >> 48) & 0xffff)}]
  set bootstrap_completed [expr {($bootstrap_word < 0) ? "INVALID" : (($bootstrap_word >> 16) & 0xffff)}]
  set bootstrap_done [expr {($bootstrap_word < 0) ? "INVALID" : (($bootstrap_word >> 33) & 1)}]
  set helper_locked [field32 $helper_state 0 1]
  set helper_changed [field32 $helper_state 1 1]
  set helper_lock_count [field32 $helper_state 16 16]
  set helper_threshold [field32 $helper_limits 0 16]
  set helper_lock_samples [field32 $helper_limits 16 16]
  set main_enabled [field32 $main_state 0 1]
  set main_locked [field32 $main_state 1 1]
  set main_freq_locked [field32 $main_state 2 1]
  set main_phase_locked [field32 $main_state 3 1]
  set pstat_locked [field32 $pstat 1 1]
  set spll_delock [field32 $spll_state 24 8]
  set helper_error_signed [signed32 $helper_error]
  set helper_output_signed [signed32 $helper_output]
  set entry_generation [probe_high32 $entry_probe]
  set cpu_reset [probe_field32 $reset_probe 16 8]
  set wr_reset [probe_field32 $reset_probe 24 8]
  set si_drop [probe_field32 $reset_probe 40 8]
  set current_tics_value [field32 $current_tics 0 32]
  set valid [frame_valid $ctrl_begin $ctrl_end]

  if {$sample == 1} {
    initialize_board $hardware_name
    set ::elapsed_first($hardware_name) $elapsed_ms
    set ::tracker_first($hardware_name) [list $target $applied $normal_req $normal_done]
    set ::burst_first($hardware_name) [list $forced_trigger $forced_pending $forced_done $dco_step]
    set ::bootstrap_first($hardware_name) [list $bootstrap_completed $bootstrap_done]
    set ::reset_first($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
    set ::spll_delock_first($hardware_name) $spll_delock
    set ::current_tics_first($hardware_name) $current_tics_value
    set ::helper_state_first($hardware_name) $helper_state
  }
  incr ::sample_count($hardware_name)
  set ::elapsed_final($hardware_name) $elapsed_ms
  set ::tracker_final($hardware_name) [list $target $applied $normal_req $normal_done]
  set ::burst_final($hardware_name) [list $forced_trigger $forced_pending $forced_done $dco_step]
  set ::bootstrap_final($hardware_name) [list $bootstrap_completed $bootstrap_done]
  set ::reset_final($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
  set ::current_tics_final($hardware_name) $current_tics_value
  set ::helper_state_final($hardware_name) $helper_state
  set ::spll_delock_final($hardware_name) $spll_delock
  if {$spll_delock ne "INVALID" && $spll_delock > $::spll_delock_max($hardware_name)} {
    set ::spll_delock_max($hardware_name) $spll_delock
  }

  if {$valid} {
    incr ::valid_frame_count($hardware_name)
    if {$helper_lock_count ne "INVALID"} {
      set ::helper_lock_final($hardware_name) $helper_lock_count
      if {$helper_lock_count > $::helper_lock_max($hardware_name)} {
        set ::helper_lock_max($hardware_name) $helper_lock_count
      }
    }
    if {$helper_locked ne "INVALID"} {
      set ::helper_locked_final($hardware_name) $helper_locked
      if {$helper_locked} {
        incr ::helper_locked_seen($hardware_name)
        if {$::helper_first_locked_sample($hardware_name) eq "NONE"} {
          set ::helper_first_locked_sample($hardware_name) $sample
        }
      }
    }
    if {$helper_changed == 1} { incr ::helper_lock_changed_events($hardware_name) }
    set ::main_enabled_final($hardware_name) $main_enabled
    set ::main_locked_final($hardware_name) $main_locked
    set ::main_freq_locked_final($hardware_name) $main_freq_locked
    set ::main_phase_locked_final($hardware_name) $main_phase_locked
    set ::pstat_locked_final($hardware_name) $pstat_locked
    if {$helper_error_signed ne "INVALID"} {
      set abs_error [expr {abs($helper_error_signed)}]
      incr ::helper_error_count($hardware_name)
      set ::helper_error_sum($hardware_name) [expr {$::helper_error_sum($hardware_name) + $helper_error_signed}]
      set ::helper_error_sumsq($hardware_name) [expr {$::helper_error_sumsq($hardware_name) + double($helper_error_signed) * double($helper_error_signed)}]
      if {$abs_error > $::helper_error_max_abs($hardware_name)} {
        set ::helper_error_max_abs($hardware_name) $abs_error
      }
      if {$helper_threshold eq "INVALID" || $abs_error <= $helper_threshold} {
        incr ::helper_error_in_window($hardware_name)
      }
    }
  } else {
    incr ::invalid_frame_count($hardware_name)
  }

  puts [format "STEP5_LOCK_SAMPLE board=%s sample=%d elapsed_ms=%d FRAME_VALID=%d CTRL_BEGIN=%s CTRL_END=%s HELPER_STATE=%s HELPER_LIMITS=%s HELPER_LOCKED=%s HELPER_LOCK_CHANGED=%s HELPER_LOCK_COUNT=%s HELPER_THRESHOLD=%s HELPER_LOCK_SAMPLES=%s HELPER_ERROR=%s HELPER_ERROR_SIGNED=%s HELPER_OUTPUT=%s HELPER_OUTPUT_SIGNED=%s MAIN_ENABLED=%s MAIN_LOCKED=%s MAIN_FREQ_LOCKED=%s MAIN_PHASE_LOCKED=%s PSTAT_LOCKED=%s SPLL_DELOCK_COUNT=%s WR_LOCK_UNLOCKED=%s NORMAL_REQ=%s NORMAL_COMPLETED=%s DCO_STEP=%s BOOTSTRAP_COMPLETED=%s BOOTSTRAP_DONE=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s CURRENT_TICS=%s" \
    $hardware_name $sample $elapsed_ms $valid [display_value $ctrl_begin] [display_value $ctrl_end] \
    [display_value $helper_state] [display_value $helper_limits] $helper_locked $helper_changed $helper_lock_count $helper_threshold $helper_lock_samples \
    [display_value $helper_error] $helper_error_signed [display_value $helper_output] $helper_output_signed \
    $main_enabled $main_locked $main_freq_locked $main_phase_locked $pstat_locked $spll_delock \
    [display_value $wr_lock_unlocked] $normal_req $normal_done $dco_step $bootstrap_completed $bootstrap_done \
    $entry_generation $cpu_reset $wr_reset $si_drop [display_value $current_tics]]
  flush stdout
}

proc emit_summary {hardware_name} {
  foreach {target0 applied0 req0 done0} $::tracker_first($hardware_name) break
  foreach {target1 applied1 req1 done1} $::tracker_final($hardware_name) break
  foreach {trigger0 pending0 forced0 step0} $::burst_first($hardware_name) break
  foreach {trigger1 pending1 forced1 step1} $::burst_final($hardware_name) break
  foreach {boot0 doneboot0} $::bootstrap_first($hardware_name) break
  foreach {boot1 doneboot1} $::bootstrap_final($hardware_name) break
  foreach {gen0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {gen1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  set normal_req_delta [counter_delta $req0 $req1 16]
  set normal_done_delta [counter_delta $done0 $done1 16]
  set forced_delta [counter_delta $forced0 $forced1 8]
  set dco_delta [counter_delta $step0 $step1 16]
  set gen_delta [expr {($gen0 ne "INVALID" && $gen1 ne "INVALID") ? ($gen1 - $gen0) : "INVALID"}]
  set cpu_delta [expr {($cpu0 ne "INVALID" && $cpu1 ne "INVALID") ? ($cpu1 - $cpu0) : "INVALID"}]
  set wr_delta [expr {($wr0 ne "INVALID" && $wr1 ne "INVALID") ? ($wr1 - $wr0) : "INVALID"}]
  set si_delta [expr {($si0 ne "INVALID" && $si1 ne "INVALID") ? ($si1 - $si0) : "INVALID"}]
  set error_count $::helper_error_count($hardware_name)
  if {$error_count > 0} {
    set error_mean [expr {$::helper_error_sum($hardware_name) / double($error_count)}]
    set error_rms [expr {sqrt($::helper_error_sumsq($hardware_name) / double($error_count))}]
    set error_fraction [expr {100.0 * $::helper_error_in_window($hardware_name) / double($error_count)}]
  } else {
    set error_mean INVALID
    set error_rms INVALID
    set error_fraction INVALID
  }
  set window_seconds [expr {$::elapsed_final($hardware_name) / 1000.0}]
  set tics_delta [counter_delta $::current_tics_first($hardware_name) $::current_tics_final($hardware_name) 32]
  set bootstrap_pass [expr {$doneboot1 eq "1"}]
  set transaction_accounting [expr {$normal_req_delta ne "INVALID" && $normal_done_delta ne "INVALID" && $normal_req_delta == $normal_done_delta ? "PASS" : "CHECK"}]
  puts [format "STEP5_LOCK_CONVERGENCE_SUMMARY board=%s SAMPLES=%d VALID_FRAMES=%d INVALID_FRAMES=%d WINDOW_SECONDS=%.3f HELPER_LOCK_COUNT_MAX=%s HELPER_LOCK_COUNT_FINAL=%s HELPER_LOCKED_SEEN=%d HELPER_LOCKED_FINAL=%s FIRST_HELPER_LOCK_SAMPLE=%s LOCK_CHANGED_EVENTS=%d HELPER_ERROR_SAMPLES=%d HELPER_ERROR_MEAN=%s HELPER_ERROR_RMS=%s HELPER_ERROR_MAX_ABS=%s HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD=%s MAIN_ENABLED_FINAL=%s MAIN_LOCKED_FINAL=%s MAIN_FREQ_LOCKED_FINAL=%s MAIN_PHASE_LOCKED_FINAL=%s PSTAT_LOCKED_FINAL=%s SPLL_DELOCK_COUNT_FIRST=%s SPLL_DELOCK_COUNT_MAX=%s SPLL_DELOCK_COUNT_FINAL=%s CURRENT_TICS_DELTA=%s NORMAL_REQ_DELTA=%s NORMAL_COMPLETED_DELTA=%s DCO_STEP_DELTA=%s FORCED_ACTIVITY_DELTA=%s BOOTSTRAP_COMPLETED_DELTA=%s BOOTSTRAP_DONE_FINAL=%s NORMAL_TRANSACTION_ACCOUNTING=%s RESET_BOOT_GENERATION_DELTA=%s RESET_CPU_DELTA=%s RESET_WR_CORE_DELTA=%s RESET_SI_CONFIG_DELTA=%s" \
    $hardware_name $::sample_count($hardware_name) $::valid_frame_count($hardware_name) $::invalid_frame_count($hardware_name) $window_seconds \
    $::helper_lock_max($hardware_name) $::helper_lock_final($hardware_name) $::helper_locked_seen($hardware_name) $::helper_locked_final($hardware_name) \
    $::helper_first_locked_sample($hardware_name) $::helper_lock_changed_events($hardware_name) $error_count $error_mean $error_rms \
    $::helper_error_max_abs($hardware_name) $error_fraction $::main_enabled_final($hardware_name) $::main_locked_final($hardware_name) \
    $::main_freq_locked_final($hardware_name) $::main_phase_locked_final($hardware_name) $::pstat_locked_final($hardware_name) \
    $::spll_delock_first($hardware_name) $::spll_delock_max($hardware_name) $::spll_delock_final($hardware_name) $tics_delta \
    $normal_req_delta $normal_done_delta $dco_delta $forced_delta [counter_delta $boot0 $boot1 16] $bootstrap_pass \
    $transaction_accounting $gen_delta $cpu_delta $wr_delta $si_delta]
  flush stdout
}

puts [format "STEP5_LOCK_CONVERGENCE_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-6272-64-LONG-LOCK-CONVERGENCE-1800S read_only=1 helper_state=0x00100ABC helper_error=0x00100AD8 helper_output=0x00100ADC cadence_ms=100" $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== STEP5_LOCK_CONVERGENCE_BOARD %s ===" $hardware_name]
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set deadline [expr {$start_ms + (($sample - 1) * $gap_ms)}]
      set now [clock milliseconds]
      if {$now < $deadline} { after [expr {$deadline - $now}] }
      emit_sample $hardware_name $sample [expr {[clock milliseconds] - $start_ms}]
    }
    emit_summary $hardware_name
  } error_message]} {
    puts [format "STEP5_LOCK_CONVERGENCE_ERROR board=%s message=%s error_info=%s" $hardware_name $error_message [string map [list "\n" " | "] $::errorInfo]]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_LOCK_CONVERGENCE_DONE"
