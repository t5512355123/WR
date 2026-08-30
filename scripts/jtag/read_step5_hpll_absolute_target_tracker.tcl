# Step5 read-only absolute-target tracker observation.
#
# This script does not write the HPLL force source or any WR configuration.
# It reads the dedicated normal-HPLL tracker probe and the existing runtime
# diagnostic mailbox so that the experiment can distinguish normal tracker
# transactions from the forced-burst path.
#
# Tracker probe 39 (si5340a_controller_dco.v):
#   [15:0]  latest absolute HPLL target code
#   [31:16] virtual applied HPLL code
#   [47:32] normal HPLL request count
#   [63:48] normal HPLL completed count
#
# Burst probe 37:
#   [7:0]   forced burst trigger count
#   [15:8]  forced HPLL pending count
#   [23:16] forced HPLL completed count
#   [63:48] total DCO transaction step count
#
# Bootstrap probe 42:
#   [15:0]  remaining measured physical bootstrap steps
#   [31:16] completed measured physical bootstrap steps
#   bit 32  bootstrap started
#   bit 33  bootstrap done
#   bit 34  bootstrap request pending
#   bit 35  bootstrap request in flight
#
# Usage:
#   quartus_stp -t read_step5_hpll_absolute_target_tracker.tcl ?samples? ?gap_ms?

package require ::quartus::insystem_source_probe

set samples 120
set gap_ms 1000
set poll_attempts 25
set board_filter ""
set tracker_code_per_physical_step 128
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

array set ::wb_toggle {}
array set ::tracker_first {}
array set ::tracker_last {}
array set ::burst_first {}
array set ::burst_last {}
array set ::bootstrap_first {}
array set ::bootstrap_last {}
array set ::normal_nonzero_before_bootstrap_done {}
array set ::sample_elapsed_first {}
array set ::sample_elapsed_last {}
array set ::helper_error_count {}
array set ::helper_error_sum {}
array set ::helper_error_sumsq {}
array set ::helper_error_max_abs {}
array set ::helper_error_in_lock_window {}
array set ::helper_lock_max {}
array set ::helper_lock_final {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word64 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  if {$word < 0} {
    set word [expr {$word + 0x10000000000000000}]
  }
  return $word
}

proc display64 {value} {
  if {![is_hex $value]} { return $value }
  return [string toupper $value]
}

proc field_bits {word shift mask} {
  if {$word < 0} { return INVALID }
  return [expr {($word >> $shift) & $mask}]
}

proc signed32 {value} {
  set word [word64 $value]
  if {$word < 0} { return INVALID }
  set low [expr {$word & 0xffffffff}]
  if {$low >= 0x80000000} {
    return [expr {$low - 0x100000000}]
  }
  return $low
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
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
  after 2
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

proc emit_sample {hardware_name sample elapsed_ms} {
  set tracker_raw [probe_read 39]
  set burst_raw [probe_read 37]
  set bootstrap_raw [probe_read 42]
  set dco_raw [probe_read 8]
  set pstat [wb_read $hardware_name 0x00100A0C]
  set helper_state [wb_read $hardware_name 0x00100ABC]
  set helper_error [wb_read $hardware_name 0x00100AD8]
  set helper_output [wb_read $hardware_name 0x00100ADC]
  set tag_count [wb_read $hardware_name 0x00100AD4]

  set tracker_word [word64 $tracker_raw]
  set burst_word [word64 $burst_raw]
  set dco_word [word64 $dco_raw]
  set bootstrap_word [word64 $bootstrap_raw]
  set target [field_bits $tracker_word 0 0xffff]
  set applied [field_bits $tracker_word 16 0xffff]
  set normal_req [field_bits $tracker_word 32 0xffff]
  set normal_done [field_bits $tracker_word 48 0xffff]
  set trigger [field_bits $burst_word 0 0xff]
  set forced_pending [field_bits $burst_word 8 0xff]
  set forced_done [field_bits $burst_word 16 0xff]
  set step [field_bits $burst_word 48 0xffff]
  set rt_state [field_bits $dco_word 0 0x7]
  set bootstrap_remaining [field_bits $bootstrap_word 0 0xffff]
  set bootstrap_completed [field_bits $bootstrap_word 16 0xffff]
  set bootstrap_started [field_bits $bootstrap_word 32 0x1]
  set bootstrap_done [field_bits $bootstrap_word 33 0x1]
  set bootstrap_pending [field_bits $bootstrap_word 34 0x1]
  set bootstrap_current [field_bits $bootstrap_word 35 0x1]
  set helper_error_signed [signed32 $helper_error]
  set helper_lock_count [field_bits [word64 $helper_state] 16 0xffff]
  if {$sample == 1} {
    set ::normal_nonzero_before_bootstrap_done($hardware_name) 0
    set ::sample_elapsed_first($hardware_name) $elapsed_ms
    set ::helper_error_count($hardware_name) 0
    set ::helper_error_sum($hardware_name) 0.0
    set ::helper_error_sumsq($hardware_name) 0.0
    set ::helper_error_max_abs($hardware_name) 0
    set ::helper_error_in_lock_window($hardware_name) 0
    set ::helper_lock_max($hardware_name) 0
    set ::helper_lock_final($hardware_name) 0
  }
  set ::sample_elapsed_last($hardware_name) $elapsed_ms
  if {$helper_error_signed ne "INVALID"} {
    set abs_error [expr {abs($helper_error_signed)}]
    incr ::helper_error_count($hardware_name)
    set ::helper_error_sum($hardware_name) [expr {$::helper_error_sum($hardware_name) + $helper_error_signed}]
    set ::helper_error_sumsq($hardware_name) [expr {$::helper_error_sumsq($hardware_name) + double($helper_error_signed) * double($helper_error_signed)}]
    if {$abs_error > $::helper_error_max_abs($hardware_name)} {
      set ::helper_error_max_abs($hardware_name) $abs_error
    }
    if {$abs_error <= 200} {
      incr ::helper_error_in_lock_window($hardware_name)
    }
  }
  if {$helper_lock_count ne "INVALID"} {
    set ::helper_lock_final($hardware_name) $helper_lock_count
    if {$helper_lock_count > $::helper_lock_max($hardware_name)} {
      set ::helper_lock_max($hardware_name) $helper_lock_count
    }
  }
  if {$bootstrap_done == 0 && $normal_req != 0} {
    set ::normal_nonzero_before_bootstrap_done($hardware_name) 1
  }
  set gap INVALID
  set quantized_settled UNKNOWN
  if {$target ne "INVALID" && $applied ne "INVALID"} {
    set gap [expr {$target - $applied}]
    if {[expr {abs($gap) < $::tracker_code_per_physical_step}]} {
      set quantized_settled PASS
    } else {
      set quantized_settled NOT_SETTLED
    }
  }

  if {$sample == 1} {
    set ::tracker_first($hardware_name) [list $target $applied $normal_req $normal_done]
    set ::burst_first($hardware_name) [list $trigger $forced_pending $forced_done $step]
    set ::bootstrap_first($hardware_name) [list $bootstrap_remaining $bootstrap_completed $bootstrap_started $bootstrap_done $bootstrap_pending $bootstrap_current]
  }
  set ::tracker_last($hardware_name) [list $target $applied $normal_req $normal_done]
  set ::burst_last($hardware_name) [list $trigger $forced_pending $forced_done $step]
  set ::bootstrap_last($hardware_name) [list $bootstrap_remaining $bootstrap_completed $bootstrap_started $bootstrap_done $bootstrap_pending $bootstrap_current]

  puts [format "STEP5_TRACKER_SAMPLE board=%s sample=%03d elapsed_ms=%d TRACKER_RAW=%s TARGET_CODE=%s APPLIED_CODE=%s TARGET_MINUS_APPLIED=%s QUANTIZED_SETTLED=%s NORMAL_HPLL_REQUEST_COUNT=%s NORMAL_HPLL_COMPLETED_COUNT=%s BURST_RAW=%s BURST_TRIGGER_COUNT=%s FORCED_HPLL_PENDING_COUNT=%s FORCED_HPLL_COMPLETED_COUNT=%s DCO_STEP_COUNT=%s BOOTSTRAP_RAW=%s BOOTSTRAP_REMAINING=%s BOOTSTRAP_COMPLETED=%s BOOTSTRAP_STARTED=%s BOOTSTRAP_DONE=%s BOOTSTRAP_PENDING=%s BOOTSTRAP_CURRENT=%s RT_STATE=%s PSTAT=%s HELPER_STATE=%s HELPER_ERROR=%s HELPER_OUTPUT=%s TAG_COUNT=%s" \
    $hardware_name $sample $elapsed_ms [display64 $tracker_raw] $target $applied $gap $quantized_settled $normal_req $normal_done \
    [display64 $burst_raw] $trigger $forced_pending $forced_done $step [display64 $bootstrap_raw] $bootstrap_remaining $bootstrap_completed $bootstrap_started $bootstrap_done $bootstrap_pending $bootstrap_current $rt_state $pstat $helper_state $helper_error $helper_output $tag_count]
  flush stdout
}

proc emit_delta {hardware_name} {
  global tracker_code_per_physical_step
  if {![info exists ::tracker_first($hardware_name)] ||
      ![info exists ::tracker_last($hardware_name)]} {
    puts [format "STEP5_TRACKER_DELTA board=%s status=NO_VALID_SAMPLE" $hardware_name]
    return
  }
  foreach {tr_t0 tr_a0 tr_r0 tr_c0} $::tracker_first($hardware_name) break
  foreach {tr_t1 tr_a1 tr_r1 tr_c1} $::tracker_last($hardware_name) break
  foreach {br_b0 br_p0 br_f0 br_s0} $::burst_first($hardware_name) break
  foreach {br_b1 br_p1 br_f1 br_s1} $::burst_last($hardware_name) break
  foreach {bs_rem0 bs_comp0 bs_started0 bs_done0 bs_pending0 bs_current0} $::bootstrap_first($hardware_name) break
  foreach {bs_rem1 bs_comp1 bs_started1 bs_done1 bs_pending1 bs_current1} $::bootstrap_last($hardware_name) break
  set dt [expr {$tr_t1 - $tr_t0}]
  set da [expr {$tr_a1 - $tr_a0}]
  set dr [expr {$tr_r1 - $tr_r0}]
  set dc [expr {$tr_c1 - $tr_c0}]
  set db [expr {$br_b1 - $br_b0}]
  set dp [expr {$br_p1 - $br_p0}]
  set df [expr {$br_f1 - $br_f0}]
  set ds [expr {$br_s1 - $br_s0}]
  set dbootstrap [expr {$bs_comp1 - $bs_comp0}]
  set bootstrap_started $bs_started1
  set bootstrap_done $bs_done1
  set normal_before_bootstrap PASS
  if {[info exists ::normal_nonzero_before_bootstrap_done($hardware_name)] &&
      $::normal_nonzero_before_bootstrap_done($hardware_name) != 0} {
    set normal_before_bootstrap FAIL
  }
  set initial_gap [expr {$tr_t0 - $tr_a0}]
  set final_gap [expr {$tr_t1 - $tr_a1}]
  set progress "INCONCLUSIVE"
  if {abs($final_gap) < abs($initial_gap)} { set progress "TOWARD_TARGET" }
  if {$dc == 0 && abs($final_gap) < $tracker_code_per_physical_step &&
      $db == 0 && $dp == 0 && $df == 0} {
    set transaction_accounting "PASS_SETTLED"
  } elseif {$dr == $dc && $dc > 0 && $db == 0 && $dp == 0 && $df == 0 &&
            (abs($da) == ($tracker_code_per_physical_step * $dc))} {
    set transaction_accounting "PASS_QUANTIZED_NET"
  } else {
    set transaction_accounting "CHECK_FINE_GRAIN"
  }
  set quantized_settled "NOT_SETTLED"
  if {abs($final_gap) < $tracker_code_per_physical_step} { set quantized_settled "PASS" }
  puts [format "STEP5_TRACKER_DELTA board=%s TARGET_DELTA=%d APPLIED_DELTA=%d NORMAL_REQUEST_DELTA=%d NORMAL_COMPLETED_DELTA=%d BURST_TRIGGER_DELTA=%d FORCED_PENDING_DELTA=%d FORCED_COMPLETED_DELTA=%d DCO_STEP_DELTA=%d INITIAL_TARGET_MINUS_APPLIED=%d FINAL_TARGET_MINUS_APPLIED=%d BOOTSTRAP_COMPLETED_DELTA=%d BOOTSTRAP_STARTED=%d BOOTSTRAP_DONE=%d BOOTSTRAP_NORMAL_ZERO_BEFORE_DONE=%s QUANTIZED_SETTLED=%s TRACKER_PROGRESS=%s NORMAL_TRANSACTION_ACCOUNTING=%s" \
    $hardware_name $dt $da $dr $dc $db $dp $df $ds $initial_gap $final_gap $dbootstrap $bootstrap_started $bootstrap_done $normal_before_bootstrap $quantized_settled $progress $transaction_accounting]
  if {[info exists ::helper_error_count($hardware_name)] && $::helper_error_count($hardware_name) > 0} {
    set error_count $::helper_error_count($hardware_name)
    set error_mean [expr {$::helper_error_sum($hardware_name) / double($error_count)}]
    set error_rms [expr {sqrt($::helper_error_sumsq($hardware_name) / double($error_count))}]
    set error_fraction [expr {100.0 * $::helper_error_in_lock_window($hardware_name) / double($error_count)}]
    set elapsed_s [expr {max(0.001, ($::sample_elapsed_last($hardware_name) - $::sample_elapsed_first($hardware_name)) / 1000.0)}]
    set completed_per_second [expr {$dc / $elapsed_s}]
    puts [format "STEP5_TRACKER_STATS board=%s HELPER_ERROR_SAMPLES=%d HELPER_ERROR_MEAN=%.3f HELPER_ERROR_RMS=%.3f HELPER_ERROR_MAX_ABS=%d HELPER_ERROR_FRACTION_ABS_LE_200=%.3f HELPER_LOCK_COUNT_MAX=%d HELPER_LOCK_COUNT_FINAL=%d NORMAL_COMPLETED_PER_SECOND=%.3f WINDOW_SECONDS=%.3f" \
      $hardware_name $error_count $error_mean $error_rms $::helper_error_max_abs($hardware_name) $error_fraction $::helper_lock_max($hardware_name) $::helper_lock_final($hardware_name) $completed_per_second $elapsed_s]
  } else {
    puts [format "STEP5_TRACKER_STATS board=%s status=NO_VALID_HELPER_ERROR" $hardware_name]
  }
  flush stdout
}

puts [format "STEP5_HPLL_BOOTSTRAP_TRACKER_CONFIG samples=%d gap_ms=%d board_filter=%s code_per_physical_step=%d experiment=EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-128-TRACKER-CLOSED-LOOP-20260830 read_only=1 tracker_probe=39 bootstrap_probe=42" $samples $gap_ms $board_filter $tracker_code_per_physical_step]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== STEP5_HPLL_BOOTSTRAP_TRACKER_BOARD %s ===" $hardware_name]
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      emit_sample $hardware_name $sample [expr {[clock milliseconds] - $start_ms}]
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
    emit_delta $hardware_name
  } error_message]} {
    puts [format "STEP5_HPLL_BOOTSTRAP_TRACKER_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_HPLL_BOOTSTRAP_TRACKER_DONE"
