# Step5 fixed-actuator coherent DMTD measurement audit.
#
# The firmware publishes the complete payload directly from one accepted
# helper_update() invocation.  This observer brackets every read with the
# measurement epoch and accepts only an unchanged, even epoch.  It is
# intentionally read-only and does not request any HPLL/DCO transaction.
#
# Usage:
#   quartus_stp -t read_step5_fixed_actuator_coherent_dmtd_measurement_audit.tcl ?samples? ?gap_ms? ?board_filter?

package require ::quartus::insystem_source_probe

set samples 1800
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
array set ::coherent_count {}
array set ::rejected_count {}
array set ::accounting_failures {}
array set ::bootstrap_done_sample {}
array set ::hold_started {}
array set ::bootstrap_final {}
array set ::tracker_first {}
array set ::tracker_final {}
array set ::burst_first {}
array set ::burst_final {}
array set ::reset_first {}
array set ::reset_final {}
array set ::freq_count {}
array set ::freq_sum {}
array set ::freq_sumsq {}
array set ::freq_min {}
array set ::freq_max {}
array set ::freq_first {}
array set ::freq_last {}
array set ::extreme_count {}
array set ::extreme_max_abs {}
array set ::last_epoch {}
array set ::last_update_count {}
array set ::last_ref_accept_count {}
array set ::last_fb_accept_count {}
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

proc initialize_board {hardware_name} {
  set ::sample_count($hardware_name) 0
  set ::coherent_count($hardware_name) 0
  set ::rejected_count($hardware_name) 0
  set ::accounting_failures($hardware_name) 0
  set ::bootstrap_done_sample($hardware_name) NONE
  set ::hold_started($hardware_name) 0
  set ::bootstrap_final($hardware_name) [list INVALID INVALID]
  set ::tracker_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::tracker_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::burst_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::burst_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::freq_count($hardware_name) 0
  set ::freq_sum($hardware_name) 0.0
  set ::freq_sumsq($hardware_name) 0.0
  set ::freq_min($hardware_name) INVALID
  set ::freq_max($hardware_name) INVALID
  set ::freq_first($hardware_name) INVALID
  set ::freq_last($hardware_name) INVALID
  set ::extreme_count($hardware_name) 0
  set ::extreme_max_abs($hardware_name) 0
  set ::last_epoch($hardware_name) INVALID
  set ::last_update_count($hardware_name) INVALID
  set ::last_ref_accept_count($hardware_name) INVALID
  set ::last_fb_accept_count($hardware_name) INVALID
  set ::elapsed_final($hardware_name) 0
}

proc read_coherent_measurement {hardware_name} {
  # Return: accepted epoch tag_delta expected_delta freq_error preclamp
  #         helper_error update_count helper_output ref_accept fb_accept.
  for {set attempt 0} {$attempt < 8} {incr attempt} {
    set epoch_before_raw [wb_read $hardware_name 0x00100B00]
    set epoch_before [word32 $epoch_before_raw]
    if {$epoch_before < 0 || ($epoch_before & 1)} { continue }

    set tag_delta_raw [wb_read $hardware_name 0x00100B04]
    set expected_delta_raw [wb_read $hardware_name 0x00100B08]
    set freq_error_raw [wb_read $hardware_name 0x00100B0C]
    set preclamp_raw [wb_read $hardware_name 0x00100B10]
    set helper_error_raw [wb_read $hardware_name 0x00100B14]
    set update_count_raw [wb_read $hardware_name 0x00100B18]
    set helper_output_raw [wb_read $hardware_name 0x00100B1C]
    set ref_accept_raw [wb_read $hardware_name 0x00100B20]
    set fb_accept_raw [wb_read $hardware_name 0x00100B24]
    set epoch_after_raw [wb_read $hardware_name 0x00100B00]
    set epoch_after [word32 $epoch_after_raw]

    if {$epoch_before == $epoch_after && $epoch_after >= 0 && !($epoch_after & 1)} {
      return [list 1 $epoch_after [signed32 $tag_delta_raw] \
        [signed32 $expected_delta_raw] [signed32 $freq_error_raw] \
        [signed32 $preclamp_raw] [signed32 $helper_error_raw] \
        [word32 $update_count_raw] [signed32 $helper_output_raw] \
        [word32 $ref_accept_raw] [word32 $fb_accept_raw]]
    }
  }
  return [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
}

proc update_frequency_stats {hardware_name freq} {
  if {$freq eq "INVALID"} { return }
  if {$::freq_count($hardware_name) == 0} {
    set ::freq_min($hardware_name) $freq
    set ::freq_max($hardware_name) $freq
    set ::freq_first($hardware_name) $freq
  } else {
    if {$freq < $::freq_min($hardware_name)} { set ::freq_min($hardware_name) $freq }
    if {$freq > $::freq_max($hardware_name)} { set ::freq_max($hardware_name) $freq }
  }
  incr ::freq_count($hardware_name)
  set ::freq_last($hardware_name) $freq
  set ::freq_sum($hardware_name) [expr {$::freq_sum($hardware_name) + double($freq)}]
  set ::freq_sumsq($hardware_name) [expr {$::freq_sumsq($hardware_name) + double($freq) * double($freq)}]
  set abs_freq [expr {abs($freq)}]
  if {$abs_freq > 1000000} {
    incr ::extreme_count($hardware_name)
    if {$abs_freq > $::extreme_max_abs($hardware_name)} {
      set ::extreme_max_abs($hardware_name) $abs_freq
    }
  }
}

proc emit_sample {hardware_name sample elapsed_ms} {
  if {$sample == 1} { initialize_board $hardware_name }

  set tracker_raw [probe_read 39]
  set burst_raw [probe_read 37]
  set bootstrap_raw [probe_read 42]
  set reset_probe [probe_read 27]

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
  set entry_generation [probe_high32 [probe_read 26]]
  set cpu_reset [probe_field32 $reset_probe 16 8]
  set wr_reset [probe_field32 $reset_probe 24 8]
  set si_drop [probe_field32 $reset_probe 40 8]

  foreach {accepted epoch tag_delta expected_delta freq_error preclamp helper_error update_count helper_output ref_accept fb_accept} \
    [read_coherent_measurement $hardware_name] break

  if {$sample == 1} {
    set ::reset_first($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
    set ::tracker_first($hardware_name) [list $target $applied $normal_req $normal_done]
    set ::burst_first($hardware_name) [list $forced_done $dco_step]
  }
  incr ::sample_count($hardware_name)
  set ::elapsed_final($hardware_name) $elapsed_ms
  set ::reset_final($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
  set ::tracker_final($hardware_name) [list $target $applied $normal_req $normal_done]
  set ::burst_final($hardware_name) [list $forced_done $dco_step]
  set ::bootstrap_final($hardware_name) [list $bootstrap_completed $bootstrap_done]

  if {$accepted} {
    incr ::coherent_count($hardware_name)
    set ::last_epoch($hardware_name) $epoch
    set ::last_update_count($hardware_name) $update_count
    set ::last_ref_accept_count($hardware_name) $ref_accept
    set ::last_fb_accept_count($hardware_name) $fb_accept
    if {$tag_delta eq "INVALID" || $expected_delta eq "INVALID" ||
        $freq_error eq "INVALID" || $update_count eq "INVALID" ||
        $ref_accept eq "INVALID" || $fb_accept eq "INVALID" ||
        $freq_error != ($tag_delta - $expected_delta)} {
      incr ::accounting_failures($hardware_name)
    } else {
      update_frequency_stats $hardware_name $freq_error
    }

    if {$bootstrap_done == 1 && $bootstrap_completed == 6208 && !$::hold_started($hardware_name)} {
      set ::hold_started($hardware_name) 1
      set ::bootstrap_done_sample($hardware_name) $sample
      set ::tracker_first($hardware_name) [list $target $applied $normal_req $normal_done]
      set ::burst_first($hardware_name) [list $forced_done $dco_step]
    }

    puts [format "STEP5_COHERENT_SAMPLE board=%s sample=%d elapsed_ms=%d ACCEPTED=%d EPOCH=%s TAG_DELTA=%s EXPECTED_DELTA=%s FREQ_ERROR_USED=%s PRECLAMP_ERROR=%s HELPER_ERROR=%s HELPER_OUTPUT=%s HELPER_UPDATE_COUNT=%s DMTD_REF_ACCEPT_COUNT=%s DMTD_FB_ACCEPT_COUNT=%s BOOTSTRAP_COMPLETED=%s BOOTSTRAP_DONE=%s TARGET_CODE=%s APPLIED_CODE=%s NORMAL_REQ=%s NORMAL_COMPLETED=%s FORCED_COMPLETED=%s DCO_STEP=%s HOLD_STARTED=%d BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
      $hardware_name $sample $elapsed_ms $accepted $epoch $tag_delta $expected_delta $freq_error $preclamp $helper_error $helper_output $update_count $ref_accept $fb_accept $bootstrap_completed $bootstrap_done $target $applied $normal_req $normal_done $forced_done $dco_step $::hold_started($hardware_name) $entry_generation $cpu_reset $wr_reset $si_drop]
  } else {
    incr ::rejected_count($hardware_name)
    puts [format "STEP5_COHERENT_SAMPLE board=%s sample=%d elapsed_ms=%d ACCEPTED=0 EPOCH=%s BOOTSTRAP_COMPLETED=%s BOOTSTRAP_DONE=%s TARGET_CODE=%s APPLIED_CODE=%s NORMAL_REQ=%s NORMAL_COMPLETED=%s FORCED_COMPLETED=%s DCO_STEP=%s HOLD_STARTED=%d BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
      $hardware_name $sample $elapsed_ms $accepted $bootstrap_completed $bootstrap_done $target $applied $normal_req $normal_done $forced_done $dco_step $::hold_started($hardware_name) $entry_generation $cpu_reset $wr_reset $si_drop]
  }
  flush stdout
}

proc emit_summary {hardware_name} {
  foreach {gen0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {gen1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  foreach {target0 applied0 req0 done0} $::tracker_first($hardware_name) break
  foreach {target1 applied1 req1 done1} $::tracker_final($hardware_name) break
  foreach {forced0 step0} $::burst_first($hardware_name) break
  foreach {forced1 step1} $::burst_final($hardware_name) break
  foreach {bootstrap_completed bootstrap_done} $::bootstrap_final($hardware_name) break

  set gen_delta [counter_delta $gen0 $gen1 32]
  set cpu_delta [counter_delta $cpu0 $cpu1 8]
  set wr_delta [counter_delta $wr0 $wr1 8]
  set si_delta [counter_delta $si0 $si1 8]
  set req_delta [counter_delta $req0 $req1 16]
  set done_delta [counter_delta $done0 $done1 16]
  set forced_delta [counter_delta $forced0 $forced1 8]
  set dco_delta [counter_delta $step0 $step1 16]
  set hold_pass [expr {$::hold_started($hardware_name) && $bootstrap_completed == 6208 && $bootstrap_done == 1 && $req_delta eq "0" && $done_delta eq "0" && $forced_delta eq "0" && $dco_delta eq "0"}]
  set reset_pass [expr {$gen_delta eq "0" && $cpu_delta eq "0" && $wr_delta eq "0" && $si_delta eq "0"}]
  set coherence_pass [expr {$::coherent_count($hardware_name) > 0 && $::accounting_failures($hardware_name) == 0}]
  set hold_result [expr {$hold_pass ? "PASS" : "FAIL"}]
  set reset_result [expr {$reset_pass ? "PASS" : "FAIL"}]
  set coherence_result [expr {$coherence_pass ? "PASS" : "FAIL"}]
  set classification [expr {$::extreme_count($hardware_name) == 0 ? "A_CROSS_EPOCH_ARTIFACT" : "B_CONFIRMED_PHYSICAL_OR_PIPELINE_EVENT"}]
  set freq_mean INVALID
  set freq_rms INVALID
  if {$::freq_count($hardware_name) > 0} {
    set freq_mean [expr {$::freq_sum($hardware_name) / double($::freq_count($hardware_name))}]
    set freq_rms [expr {sqrt($::freq_sumsq($hardware_name) / double($::freq_count($hardware_name)))}]
  }
  puts [format "STEP5_COHERENT_DMTD_MEASUREMENT_AUDIT_SUMMARY board=%s SAMPLES=%d COHERENT_MEASUREMENT_SNAPSHOTS=%d REJECTED_EPOCH_SNAPSHOTS=%d MEASUREMENT_ACCOUNTING_FAILS=%d FREQ_ERROR_MEAN=%s FREQ_ERROR_RMS=%s FREQ_ERROR_MIN=%s FREQ_ERROR_MAX=%s FREQ_ERROR_FIRST=%s FREQ_ERROR_LAST=%s EXTREME_THRESHOLD=1000000 EXTREME_COHERENT_SAMPLES=%d EXTREME_MAX_ABS=%s EXTREME_CLASSIFICATION=%s DMTD_MEASUREMENT_COHERENCE=%s BOOTSTRAP_COMPLETED_FINAL=%s BOOTSTRAP_DONE_FINAL=%s BOOTSTRAP_DONE_SAMPLE=%s NORMAL_REQ_DELTA=%s NORMAL_COMPLETED_DELTA=%s FORCED_COMPLETED_DELTA=%s DCO_STEP_DELTA=%s ACTUATOR_HOLD=%s LAST_EPOCH=%s LAST_HELPER_UPDATE_COUNT=%s LAST_DMTD_REF_ACCEPT_COUNT=%s LAST_DMTD_FB_ACCEPT_COUNT=%s RESET_BOOT_GENERATION_DELTA=%s RESET_CPU_DELTA=%s RESET_WR_CORE_DELTA=%s RESET_SI_CONFIG_DELTA=%s RESET_STABLE=%s" \
    $hardware_name $::sample_count($hardware_name) $::coherent_count($hardware_name) $::rejected_count($hardware_name) $::accounting_failures($hardware_name) $freq_mean $freq_rms $::freq_min($hardware_name) $::freq_max($hardware_name) $::freq_first($hardware_name) $::freq_last($hardware_name) $::extreme_count($hardware_name) $::extreme_max_abs($hardware_name) $classification $coherence_result $bootstrap_completed $bootstrap_done $::bootstrap_done_sample($hardware_name) $req_delta $done_delta $forced_delta $dco_delta $hold_result $::last_epoch($hardware_name) $::last_update_count($hardware_name) $::last_ref_accept_count($hardware_name) $::last_fb_accept_count($hardware_name) $gen_delta $cpu_delta $wr_delta $si_delta $reset_result]
  flush stdout
}

puts [format "STEP5_COHERENT_DMTD_MEASUREMENT_AUDIT_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-6208-FIXED-ACTUATOR-COHERENT-DMTD-MEASUREMENT-AUDIT read_only=1 bootstrap_steps=6208 normal_hpll_tracker=0 epoch_window=0x100..0x124 extreme_threshold=1000000" $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== STEP5_COHERENT_DMTD_MEASUREMENT_AUDIT_BOARD %s ===" $hardware_name]
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
    puts [format "STEP5_COHERENT_DMTD_MEASUREMENT_AUDIT_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_COHERENT_DMTD_MEASUREMENT_AUDIT_DONE"
