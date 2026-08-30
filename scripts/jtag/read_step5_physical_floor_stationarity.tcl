# Step5 physical-floor stationarity observer.
#
# This is a read-only observer for the 6208-step Slave image with the normal
# HPLL tracker disabled.  It verifies that the post-bootstrap physical
# position is held and measures FREQ_ERROR for the requested 1800-second
# stationarity window.
#
# Usage:
#   quartus_stp -t read_step5_physical_floor_stationarity.tcl ?samples? ?gap_ms? ?board_filter?
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
array set ::bootstrap_done_sample {}
array set ::bootstrap_completed_final {}
array set ::normal_req_base {}
array set ::normal_done_base {}
array set ::forced_done_base {}
array set ::dco_step_base {}
array set ::hold_started {}
array set ::freq_values {}
array set ::baseline_count {}
array set ::baseline_mean {}
array set ::baseline_sigma {}
array set ::baseline_ready {}
array set ::rolling_mean_violations {}
array set ::rolling_mean_max_deviation {}
array set ::sustained_violation_samples {}
array set ::current_violation_run {}
array set ::freq_sample_count {}
array set ::freq_min {}
array set ::freq_max {}
array set ::freq_sum {}
array set ::freq_sumsq {}
array set ::first_freq {}
array set ::last_freq {}
array set ::last_rolling_mean {}
array set ::low_rail_samples {}
array set ::high_rail_samples {}
array set ::helper_lock_max {}
array set ::helper_lock_final {}
array set ::helper_locked_final {}
array set ::helper_locked_seen {}
array set ::reset_first {}
array set ::reset_final {}
array set ::tracker_first {}
array set ::tracker_final {}
array set ::bootstrap_first {}
array set ::bootstrap_final {}
array set ::forced_done_final {}
array set ::dco_step_final {}
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
  if {$word < 0} { set word [expr {$word + 0x10000000000000000}] }
  return $word
}

proc signed32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  if {$word >= 0x80000000} { return [expr {$word - 0x100000000}] }
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
  if {[string length $text] > 16} { set text [string range $text end-15 end] }
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
  if {[catch {write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex}]} {
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
  if {![string is integer -strict $first] || ![string is integer -strict $last]} { return INVALID }
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
  # ld_update() semantics: locked=1 is legal only with lock_count=10000.
  for {set attempt 0} {$attempt < 4} {incr attempt} {
    set state [wb_read $hardware_name 0x00100ABC]
    set limits [wb_read $hardware_name 0x00100AC0]
    set threshold [field32 $limits 0 16]
    set lock_samples [field32 $limits 16 16]
    set lock_count [field32 $state 16 16]
    set locked [field32 $state 0 1]
    if {$threshold eq "200" && $lock_samples eq "10000" &&
        $lock_count ne "INVALID" && $lock_count <= $lock_samples &&
        $locked ne "INVALID" && ($locked == 0 || $lock_count == $lock_samples)} {
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
  set ::bootstrap_done_sample($hardware_name) NONE
  set ::bootstrap_completed_final($hardware_name) INVALID
  set ::normal_req_base($hardware_name) INVALID
  set ::normal_done_base($hardware_name) INVALID
  set ::forced_done_base($hardware_name) INVALID
  set ::dco_step_base($hardware_name) INVALID
  set ::hold_started($hardware_name) 0
  set ::freq_values($hardware_name) {}
  set ::baseline_count($hardware_name) 0
  set ::baseline_mean($hardware_name) INVALID
  set ::baseline_sigma($hardware_name) INVALID
  set ::baseline_ready($hardware_name) 0
  set ::rolling_mean_violations($hardware_name) 0
  set ::rolling_mean_max_deviation($hardware_name) 0.0
  set ::sustained_violation_samples($hardware_name) 0
  set ::current_violation_run($hardware_name) 0
  set ::freq_sample_count($hardware_name) 0
  set ::freq_min($hardware_name) 0
  set ::freq_max($hardware_name) 0
  set ::freq_sum($hardware_name) 0.0
  set ::freq_sumsq($hardware_name) 0.0
  set ::first_freq($hardware_name) INVALID
  set ::last_freq($hardware_name) INVALID
  set ::last_rolling_mean($hardware_name) INVALID
  set ::low_rail_samples($hardware_name) 0
  set ::high_rail_samples($hardware_name) 0
  set ::helper_lock_max($hardware_name) 0
  set ::helper_lock_final($hardware_name) INVALID
  set ::helper_locked_final($hardware_name) INVALID
  set ::helper_locked_seen($hardware_name) 0
  set ::reset_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::tracker_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::tracker_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::bootstrap_first($hardware_name) [list INVALID INVALID]
  set ::bootstrap_final($hardware_name) [list INVALID INVALID]
  set ::forced_done_final($hardware_name) INVALID
  set ::dco_step_final($hardware_name) INVALID
  set ::elapsed_final($hardware_name) 0
}

proc update_frequency_stats {hardware_name freq} {
  if {$freq eq "INVALID"} { return }
  if {$::freq_sample_count($hardware_name) == 0} {
    set ::freq_min($hardware_name) $freq
    set ::freq_max($hardware_name) $freq
    set ::first_freq($hardware_name) $freq
  } else {
    if {$freq < $::freq_min($hardware_name)} { set ::freq_min($hardware_name) $freq }
    if {$freq > $::freq_max($hardware_name)} { set ::freq_max($hardware_name) $freq }
  }
  incr ::freq_sample_count($hardware_name)
  set ::last_freq($hardware_name) $freq
  set ::freq_sum($hardware_name) [expr {$::freq_sum($hardware_name) + $freq}]
  set ::freq_sumsq($hardware_name) [expr {$::freq_sumsq($hardware_name) + double($freq) * double($freq)}]
}

proc rolling_mean {values} {
  if {[llength $values] == 0} { return INVALID }
  set sum 0.0
  foreach value $values { set sum [expr {$sum + double($value)}] }
  return [expr {$sum / double([llength $values])}]
}

proc emit_sample {hardware_name sample elapsed_ms} {
  set ctrl_begin [wb_read $hardware_name 0x00100A04]
  set tracker_raw [probe_read 39]
  set burst_raw [probe_read 37]
  set bootstrap_raw [probe_read 42]
  set entry_probe [probe_read 26]
  set reset_probe [probe_read 27]
  foreach {helper_state helper_limits} [read_helper_pair $hardware_name] break
  set tag_delta_raw [wb_read $hardware_name 0x00100B0C]
  set expected_delta_raw [wb_read $hardware_name 0x00100B14]
  set preclamp_raw [wb_read $hardware_name 0x00100B08]
  set helper_error_raw [wb_read $hardware_name 0x00100AD8]
  set helper_output_raw [wb_read $hardware_name 0x00100ADC]
  set ctrl_end [wb_read $hardware_name 0x00100A04]

  set tracker_word [word64 $tracker_raw]
  set burst_word [word64 $burst_raw]
  set bootstrap_word [word64 $bootstrap_raw]
  set target [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 0) & 0xffff)}]
  set applied [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 16) & 0xffff)}]
  set normal_req [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 32) & 0xffff)}]
  set normal_done [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 48) & 0xffff)}]
  set forced_done [expr {($burst_word < 0) ? "INVALID" : (($burst_word >> 16) & 0xff)}]
  set dco_step [expr {($burst_word < 0) ? "INVALID" : (($burst_word >> 48) & 0xffff)}]
  set bootstrap_completed [expr {($bootstrap_word < 0) ? "INVALID" : (($bootstrap_word >> 16) & 0xffff)}]
  set bootstrap_done [expr {($bootstrap_word < 0) ? "INVALID" : (($bootstrap_word >> 33) & 1)}]
  set helper_locked [field32 $helper_state 0 1]
  set helper_lock_count [field32 $helper_state 16 16]
  set helper_error [signed32 $helper_error_raw]
  set helper_output [signed32 $helper_output_raw]
  set tag_delta [signed32 $tag_delta_raw]
  set expected_delta [signed32 $expected_delta_raw]
  set preclamp [signed32 $preclamp_raw]
  if {$tag_delta eq "INVALID" || $expected_delta eq "INVALID"} {
    set freq_error INVALID
  } else {
    set freq_error [expr {$tag_delta - $expected_delta}]
  }
  set entry_generation [probe_high32 $entry_probe]
  set cpu_reset [probe_field32 $reset_probe 16 8]
  set wr_reset [probe_field32 $reset_probe 24 8]
  set si_drop [probe_field32 $reset_probe 40 8]
  set valid [frame_valid $ctrl_begin $ctrl_end]

  if {$sample == 1} {
    initialize_board $hardware_name
    set ::reset_first($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
    set ::tracker_first($hardware_name) [list $target $applied $normal_req $normal_done]
    set ::bootstrap_first($hardware_name) [list $bootstrap_completed $bootstrap_done]
  }
  incr ::sample_count($hardware_name)
  set ::elapsed_final($hardware_name) $elapsed_ms
  set ::reset_final($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
  set ::tracker_final($hardware_name) [list $target $applied $normal_req $normal_done]
  set ::bootstrap_final($hardware_name) [list $bootstrap_completed $bootstrap_done]
  set ::forced_done_final($hardware_name) $forced_done
  set ::dco_step_final($hardware_name) $dco_step
  set ::bootstrap_completed_final($hardware_name) $bootstrap_completed

  if {$valid} {
    incr ::valid_frame_count($hardware_name)
    if {$helper_lock_count ne "INVALID" && $helper_lock_count > $::helper_lock_max($hardware_name)} {
      set ::helper_lock_max($hardware_name) $helper_lock_count
    }
    set ::helper_lock_final($hardware_name) $helper_lock_count
    set ::helper_locked_final($hardware_name) $helper_locked
    if {$helper_locked == 1} { incr ::helper_locked_seen($hardware_name) }
    if {$helper_output == 5} { incr ::low_rail_samples($hardware_name) }
    if {$helper_output == 65531} { incr ::high_rail_samples($hardware_name) }

    if {$bootstrap_done == 1 && !$::hold_started($hardware_name)} {
      set ::hold_started($hardware_name) 1
      set ::bootstrap_done_sample($hardware_name) $sample
      set ::normal_req_base($hardware_name) $normal_req
      set ::normal_done_base($hardware_name) $normal_done
      set ::forced_done_base($hardware_name) $forced_done
      set ::dco_step_base($hardware_name) $dco_step
    }
    if {$::hold_started($hardware_name) && $freq_error ne "INVALID"} {
      update_frequency_stats $hardware_name $freq_error
      if {!$::baseline_ready($hardware_name)} {
        lappend ::freq_values($hardware_name) $freq_error
        if {[llength $::freq_values($hardware_name)] >= 300} {
          set count [llength $::freq_values($hardware_name)]
          set mean [rolling_mean $::freq_values($hardware_name)]
          set sumsq 0.0
          foreach value $::freq_values($hardware_name) {
            set diff [expr {double($value) - $mean}]
            set sumsq [expr {$sumsq + $diff * $diff}]
          }
          set sigma [expr {sqrt($sumsq / double($count))}]
          set ::baseline_count($hardware_name) $count
          set ::baseline_mean($hardware_name) $mean
          set ::baseline_sigma($hardware_name) $sigma
          set ::baseline_ready($hardware_name) 1
          set ::freq_values($hardware_name) {}
        }
      } else {
        lappend ::freq_values($hardware_name) $freq_error
        if {[llength $::freq_values($hardware_name)] > 300} {
          set ::freq_values($hardware_name) [lrange $::freq_values($hardware_name) end-299 end]
        }
        if {[llength $::freq_values($hardware_name)] >= 300} {
          set current_mean [rolling_mean $::freq_values($hardware_name)]
          set ::last_rolling_mean($hardware_name) $current_mean
          set envelope [expr {max(50.0, 5.0 * $::baseline_sigma($hardware_name))}]
          set deviation [expr {abs($current_mean - $::baseline_mean($hardware_name))}]
          if {$deviation > $::rolling_mean_max_deviation($hardware_name)} {
            set ::rolling_mean_max_deviation($hardware_name) $deviation
          }
          if {$deviation > $envelope} {
            incr ::rolling_mean_violations($hardware_name)
            incr ::current_violation_run($hardware_name)
            if {$::current_violation_run($hardware_name) > $::sustained_violation_samples($hardware_name)} {
              set ::sustained_violation_samples($hardware_name) $::current_violation_run($hardware_name)
            }
          } else {
            set ::current_violation_run($hardware_name) 0
          }
        }
      }
    }
  } else {
    incr ::invalid_frame_count($hardware_name)
  }

  set normal_delta [counter_delta $::normal_req_base($hardware_name) $normal_req 16]
  set normal_done_delta [counter_delta $::normal_done_base($hardware_name) $normal_done 16]
  set forced_delta [counter_delta $::forced_done_base($hardware_name) $forced_done 8]
  set dco_delta [counter_delta $::dco_step_base($hardware_name) $dco_step 16]
  puts [format "STEP5_FLOOR_SAMPLE board=%s sample=%d elapsed_ms=%d FRAME_VALID=%d HOLD_STARTED=%d BOOTSTRAP_COMPLETED=%s BOOTSTRAP_DONE=%s TARGET_CODE=%s APPLIED_CODE=%s NORMAL_REQ=%s NORMAL_COMPLETED=%s NORMAL_REQ_DELTA=%s NORMAL_COMPLETED_DELTA=%s FORCED_COMPLETED_DELTA=%s DCO_STEP_DELTA=%s TAG_DELTA=%s EXPECTED_DELTA=%s FREQ_ERROR=%s PRECLAMP_ERROR=%s HELPER_ERROR=%s HELPER_OUTPUT=%s HELPER_LOCKED=%s HELPER_LOCK_COUNT=%s BASELINE_READY=%d BASELINE_MEAN=%s BASELINE_SIGMA=%s ROLLING_MEAN=%s ROLLING_MEAN_VIOLATIONS=%d BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
    $hardware_name $sample $elapsed_ms $valid $::hold_started($hardware_name) $bootstrap_completed $bootstrap_done \
    $target $applied $normal_req $normal_done $normal_delta $normal_done_delta $forced_delta $dco_delta \
    $tag_delta $expected_delta $freq_error $preclamp $helper_error $helper_output $helper_locked $helper_lock_count \
    $::baseline_ready($hardware_name) $::baseline_mean($hardware_name) $::baseline_sigma($hardware_name) \
    $::last_rolling_mean($hardware_name) $::rolling_mean_violations($hardware_name) \
    $entry_generation $cpu_reset $wr_reset $si_drop]
  flush stdout
}

proc emit_summary {hardware_name} {
  foreach {gen0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {gen1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  foreach {target0 applied0 req0 done0} $::tracker_first($hardware_name) break
  foreach {target1 applied1 req1 done1} $::tracker_final($hardware_name) break
  foreach {boot0 done0} $::bootstrap_first($hardware_name) break
  foreach {boot1 done1} $::bootstrap_final($hardware_name) break
  set normal_req_delta [counter_delta $::normal_req_base($hardware_name) $req1 16]
  set normal_done_delta [counter_delta $::normal_done_base($hardware_name) $done1 16]
  set forced_delta [counter_delta $::forced_done_base($hardware_name) $::forced_done_final($hardware_name) 16]
  set dco_delta [counter_delta $::dco_step_base($hardware_name) $::dco_step_final($hardware_name) 16]
  set gen_delta [expr {($gen0 ne "INVALID" && $gen1 ne "INVALID") ? ($gen1 - $gen0) : "INVALID"}]
  set cpu_delta [expr {($cpu0 ne "INVALID" && $cpu1 ne "INVALID") ? ($cpu1 - $cpu0) : "INVALID"}]
  set wr_delta [expr {($wr0 ne "INVALID" && $wr1 ne "INVALID") ? ($wr1 - $wr0) : "INVALID"}]
  set si_delta [expr {($si0 ne "INVALID" && $si1 ne "INVALID") ? ($si1 - $si0) : "INVALID"}]
  set hold_pass [expr {$::hold_started($hardware_name) && $normal_req_delta eq "0" && $normal_done_delta eq "0" && $forced_delta eq "0" && $dco_delta eq "0"}]
  set reset_pass [expr {$gen_delta eq "0" && $cpu_delta eq "0" && $wr_delta eq "0" && $si_delta eq "0"}]
  set stationarity_pass [expr {$::baseline_ready($hardware_name) && $::rolling_mean_violations($hardware_name) == 0}]
  set hold_result [expr {$hold_pass ? "PASS" : "FAIL"}]
  set reset_result [expr {$reset_pass ? "PASS" : "FAIL"}]
  set stationarity_result [expr {$stationarity_pass ? "PASS" : "FAIL_DRIFT"}]
  set freq_mean INVALID
  set freq_rms INVALID
  if {$::freq_sample_count($hardware_name) > 0} {
    set freq_mean [expr {$::freq_sum($hardware_name) / double($::freq_sample_count($hardware_name))}]
    set freq_rms [expr {sqrt($::freq_sumsq($hardware_name) / double($::freq_sample_count($hardware_name)))}]
  }
  puts [format "STEP5_FLOOR_STATIONARITY_SUMMARY board=%s SAMPLES=%d VALID_FRAMES=%d INVALID_FRAMES=%d WINDOW_SECONDS=%.3f BOOTSTRAP_COMPLETED_FINAL=%s BOOTSTRAP_DONE_FINAL=%s BOOTSTRAP_DONE_SAMPLE=%s NORMAL_REQ_DELTA=%s NORMAL_COMPLETED_DELTA=%s FORCED_COMPLETED_DELTA=%s DCO_STEP_DELTA=%s ACTUATOR_HOLD=%s BASELINE_COUNT=%d FREQ_BASELINE_MEAN=%s FREQ_BASELINE_SIGMA=%s FREQ_MEAN=%s FREQ_RMS=%s FREQ_MIN=%s FREQ_MAX=%s FREQ_FIRST=%s FREQ_LAST=%s ROLLING_MEAN_LAST=%s ROLLING_MEAN_VIOLATIONS=%d MAX_ROLLING_MEAN_DEVIATION=%s SUSTAINED_VIOLATION_SAMPLES=%d PHYSICAL_FLOOR_STATIONARITY=%s LOW_RAIL_SAMPLES=%d HIGH_RAIL_SAMPLES=%d HELPER_LOCK_COUNT_MAX=%s HELPER_LOCK_COUNT_FINAL=%s HELPER_LOCKED_SEEN=%d HELPER_LOCKED_FINAL=%s RESET_BOOT_GENERATION_DELTA=%s RESET_CPU_DELTA=%s RESET_WR_CORE_DELTA=%s RESET_SI_CONFIG_DELTA=%s RESET_STABLE=%s" \
    $hardware_name $::sample_count($hardware_name) $::valid_frame_count($hardware_name) $::invalid_frame_count($hardware_name) \
    [expr {$::elapsed_final($hardware_name) / 1000.0}] $::bootstrap_completed_final($hardware_name) $done1 $::bootstrap_done_sample($hardware_name) \
    $normal_req_delta $normal_done_delta $forced_delta $dco_delta $hold_result $::baseline_count($hardware_name) \
    $::baseline_mean($hardware_name) $::baseline_sigma($hardware_name) $freq_mean $freq_rms $::freq_min($hardware_name) $::freq_max($hardware_name) \
    $::first_freq($hardware_name) $::last_freq($hardware_name) $::last_rolling_mean($hardware_name) \
    $::rolling_mean_violations($hardware_name) $::rolling_mean_max_deviation($hardware_name) $::sustained_violation_samples($hardware_name) \
    $stationarity_result $::low_rail_samples($hardware_name) $::high_rail_samples($hardware_name) $::helper_lock_max($hardware_name) \
    $::helper_lock_final($hardware_name) $::helper_locked_seen($hardware_name) $::helper_locked_final($hardware_name) \
    $gen_delta $cpu_delta $wr_delta $si_delta $reset_result]
  flush stdout
}

puts [format "STEP5_FLOOR_STATIONARITY_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-6208-PHYSICAL-FLOOR-STATIONARITY-1800S read_only=1 bootstrap_steps=6208 normal_hpll_tracker=0 baseline_samples=300 rolling_window_samples=300 cadence_ms=100" $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== STEP5_FLOOR_STATIONARITY_BOARD %s ===" $hardware_name]
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    set started_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set elapsed_ms [expr {[clock milliseconds] - $started_ms}]
      emit_sample $hardware_name $sample $elapsed_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
    emit_summary $hardware_name
  } error_message]} {
    puts [format "STEP5_FLOOR_STATIONARITY_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_FLOOR_STATIONARITY_DONE"
