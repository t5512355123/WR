# Step5 virtual-to-physical signed-position audit.
#
# This is a read-only observer for the 6208 + 64 tracker image.  Probe 43
# exposes completed normal FINC/FDEC counts; the script reconstructs the
# signed normal net and checks it against the virtual applied code.  The
# existing WDIAGS fields provide TAG_DELTA, EXPECTED_DELTA, PRECLAMP_ERROR,
# HELPER_ERROR, and HELPER_OUTPUT for the same observation window.
#
# Usage:
#   quartus_stp -t read_step5_signed_physical_position_audit.tcl ?samples? ?gap_ms? ?board_filter?
#
# The intended run is 600 samples at 100 ms (about 60 seconds), starting
# immediately after fresh programming.

package require ::quartus::insystem_source_probe

set samples 600
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
array set ::position_match_count {}
array set ::position_invariant_fail_count {}
array set ::transaction_invariant_fail_count {}
array set ::dco_invariant_fail_count {}
array set ::rail5_count {}
array set ::plus150000_count {}
array set ::tag_valid_first {}
array set ::tag_valid_final {}
array set ::normal_req_first {}
array set ::normal_req_final {}
array set ::normal_done_first {}
array set ::normal_done_final {}
array set ::dco_step_first {}
array set ::dco_step_final {}
array set ::bootstrap_first {}
array set ::bootstrap_final {}
array set ::finc_first {}
array set ::finc_final {}
array set ::fdec_first {}
array set ::fdec_final {}
array set ::applied_first {}
array set ::applied_final {}
array set ::target_final {}
array set ::preclamp_final {}
array set ::tag_delta_final {}
array set ::expected_delta_final {}
array set ::freq_error_final {}
array set ::helper_error_final {}
array set ::helper_output_final {}
array set ::helper_lock_final {}
array set ::helper_count_final {}
array set ::first_rail_sample {}
array set ::first_plus150000_sample {}
array set ::reset_first {}
array set ::reset_final {}
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

proc signed32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  if {$word >= 0x80000000} {
    return [expr {$word - 0x100000000}]
  }
  return $word
}

proc field32 {value low width} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($word >> $low) & $mask}]
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

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return INVALID
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
    return INVALID
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
  return INVALID
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

proc helper_pair {hardware_name} {
  for {set attempt 0} {$attempt < 4} {incr attempt} {
    set state [wb_read $hardware_name 0x00100ABC]
    set limits [wb_read $hardware_name 0x00100AC0]
    set threshold [field32 $limits 0 16]
    set lock_samples [field32 $limits 16 16]
    set lock_count [field32 $state 16 16]
    set locked [field32 $state 0 1]
    if {$threshold eq "200" && $lock_samples eq "10000" &&
        $lock_count ne "INVALID" && $lock_count <= $lock_samples &&
        $locked ne "INVALID"} {
      if {$locked == 0 || ($locked == 1 && $lock_count == $lock_samples)} {
        return [list $state $limits]
      }
    }
    after 2
  }
  return [list INVALID INVALID]
}

proc initialize_board {hardware_name} {
  set ::sample_count($hardware_name) 0
  set ::valid_frame_count($hardware_name) 0
  set ::invalid_frame_count($hardware_name) 0
  set ::position_match_count($hardware_name) 0
  set ::position_invariant_fail_count($hardware_name) 0
  set ::transaction_invariant_fail_count($hardware_name) 0
  set ::dco_invariant_fail_count($hardware_name) 0
  set ::rail5_count($hardware_name) 0
  set ::plus150000_count($hardware_name) 0
  set ::tag_valid_first($hardware_name) INVALID
  set ::tag_valid_final($hardware_name) INVALID
  set ::normal_req_first($hardware_name) INVALID
  set ::normal_req_final($hardware_name) INVALID
  set ::normal_done_first($hardware_name) INVALID
  set ::normal_done_final($hardware_name) INVALID
  set ::dco_step_first($hardware_name) INVALID
  set ::dco_step_final($hardware_name) INVALID
  set ::bootstrap_first($hardware_name) INVALID
  set ::bootstrap_final($hardware_name) INVALID
  set ::finc_first($hardware_name) INVALID
  set ::finc_final($hardware_name) INVALID
  set ::fdec_first($hardware_name) INVALID
  set ::fdec_final($hardware_name) INVALID
  set ::applied_first($hardware_name) INVALID
  set ::applied_final($hardware_name) INVALID
  set ::target_final($hardware_name) INVALID
  set ::preclamp_final($hardware_name) INVALID
  set ::tag_delta_final($hardware_name) INVALID
  set ::expected_delta_final($hardware_name) INVALID
  set ::freq_error_final($hardware_name) INVALID
  set ::helper_error_final($hardware_name) INVALID
  set ::helper_output_final($hardware_name) INVALID
  set ::helper_lock_final($hardware_name) INVALID
  set ::helper_count_final($hardware_name) INVALID
  set ::first_rail_sample($hardware_name) NONE
  set ::first_plus150000_sample($hardware_name) NONE
  set ::reset_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::elapsed_final($hardware_name) 0
}

proc emit_sample {hardware_name sample elapsed_ms} {
  set ctrl_begin [wb_read $hardware_name 0x00100A04]
  set tracker_raw [probe_read 39]
  set position_raw [probe_read 43]
  set burst_raw [probe_read 37]
  set bootstrap_raw [probe_read 42]
  set entry_probe [probe_read 26]
  set reset_probe [probe_read 27]
  foreach {helper_state helper_limits} [helper_pair $hardware_name] break
  set tag_valid_raw [wb_read $hardware_name 0x00100AF8]
  set preclamp_raw [wb_read $hardware_name 0x00100B08]
  set tag_delta_raw [wb_read $hardware_name 0x00100B0C]
  set expected_delta_raw [wb_read $hardware_name 0x00100B14]
  set helper_error_raw [wb_read $hardware_name 0x00100AD8]
  set helper_output_raw [wb_read $hardware_name 0x00100ADC]
  set ctrl_end [wb_read $hardware_name 0x00100A04]

  set tracker_word [word64 $tracker_raw]
  set position_word [word64 $position_raw]
  set burst_word [word64 $burst_raw]
  set bootstrap_word [word64 $bootstrap_raw]
  set target [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 0) & 0xffff)}]
  set applied [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 16) & 0xffff)}]
  set normal_req [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 32) & 0xffff)}]
  set normal_done [expr {($tracker_word < 0) ? "INVALID" : (($tracker_word >> 48) & 0xffff)}]
  set dco_step [expr {($burst_word < 0) ? "INVALID" : (($burst_word >> 48) & 0xffff)}]
  set bootstrap_completed [expr {($bootstrap_word < 0) ? "INVALID" : (($bootstrap_word >> 16) & 0xffff)}]
  set bootstrap_done [expr {($bootstrap_word < 0) ? "INVALID" : (($bootstrap_word >> 33) & 1)}]
  set position_target [expr {($position_word < 0) ? "INVALID" : (($position_word >> 0) & 0xffff)}]
  set position_applied [expr {($position_word < 0) ? "INVALID" : (($position_word >> 16) & 0xffff)}]
  set finc [expr {($position_word < 0) ? "INVALID" : (($position_word >> 32) & 0xffff)}]
  set fdec [expr {($position_word < 0) ? "INVALID" : (($position_word >> 48) & 0xffff)}]
  set helper_locked [field32 $helper_state 0 1]
  set helper_lock_count [field32 $helper_state 16 16]
  set helper_error_signed [signed32 $helper_error_raw]
  set helper_output_signed [signed32 $helper_output_raw]
  set preclamp_signed [signed32 $preclamp_raw]
  set tag_delta_signed [signed32 $tag_delta_raw]
  set expected_delta_signed [signed32 $expected_delta_raw]
  set freq_error_signed INVALID
  if {$tag_delta_signed ne "INVALID" && $expected_delta_signed ne "INVALID"} {
    set freq_error_signed [expr {$tag_delta_signed - $expected_delta_signed}]
  }
  set entry_generation [probe_high32 $entry_probe]
  set cpu_reset [probe_field32 $reset_probe 16 8]
  set wr_reset [probe_field32 $reset_probe 24 8]
  set si_drop [probe_field32 $reset_probe 40 8]
  set tag_valid [word32 $tag_valid_raw]
  if {$tag_valid < 0} { set tag_valid INVALID }
  set valid [frame_valid $ctrl_begin $ctrl_end]

  if {$sample == 1} {
    initialize_board $hardware_name
    set ::tag_valid_first($hardware_name) $tag_valid
    set ::normal_req_first($hardware_name) $normal_req
    set ::normal_done_first($hardware_name) $normal_done
    set ::dco_step_first($hardware_name) $dco_step
    set ::bootstrap_first($hardware_name) $bootstrap_completed
    set ::finc_first($hardware_name) $finc
    set ::fdec_first($hardware_name) $fdec
    set ::applied_first($hardware_name) $position_applied
    set ::reset_first($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
  }
  incr ::sample_count($hardware_name)
  set ::elapsed_final($hardware_name) $elapsed_ms
  set ::tag_valid_final($hardware_name) $tag_valid
  set ::normal_req_final($hardware_name) $normal_req
  set ::normal_done_final($hardware_name) $normal_done
  set ::dco_step_final($hardware_name) $dco_step
  set ::bootstrap_final($hardware_name) $bootstrap_completed
  set ::finc_final($hardware_name) $finc
  set ::fdec_final($hardware_name) $fdec
  set ::applied_final($hardware_name) $position_applied
  set ::target_final($hardware_name) $position_target
  set ::preclamp_final($hardware_name) $preclamp_signed
  set ::tag_delta_final($hardware_name) $tag_delta_signed
  set ::expected_delta_final($hardware_name) $expected_delta_signed
  set ::freq_error_final($hardware_name) $freq_error_signed
  set ::helper_error_final($hardware_name) $helper_error_signed
  set ::helper_output_final($hardware_name) $helper_output_signed
  set ::helper_lock_final($hardware_name) $helper_locked
  set ::helper_count_final($hardware_name) $helper_lock_count
  set ::reset_final($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]

  if {$valid} {
    incr ::valid_frame_count($hardware_name)
    if {$helper_output_signed == 5} {
      incr ::rail5_count($hardware_name)
      if {$::first_rail_sample($hardware_name) eq "NONE"} {
        set ::first_rail_sample($hardware_name) $sample
      }
    }
    if {$helper_error_signed == 150000} {
      incr ::plus150000_count($hardware_name)
      if {$::first_plus150000_sample($hardware_name) eq "NONE"} {
        set ::first_plus150000_sample($hardware_name) $sample
      }
    }
    if {$position_applied ne "INVALID" && $finc ne "INVALID" && $fdec ne "INVALID"} {
      set signed_net [expr {$finc - $fdec}]
      set expected_applied [expr {(5 + 64 * $signed_net) & 0xffff}]
      if {$position_applied == $expected_applied} {
        incr ::position_match_count($hardware_name)
      } else {
        incr ::position_invariant_fail_count($hardware_name)
      }
    }
    if {$normal_done ne "INVALID" && $finc ne "INVALID" && $fdec ne "INVALID" &&
        [expr {$finc + $fdec}] != $normal_done} {
      incr ::transaction_invariant_fail_count($hardware_name)
    }
    if {$dco_step ne "INVALID" && $bootstrap_completed ne "INVALID" && $normal_done ne "INVALID" &&
        [expr {$dco_step != (($bootstrap_completed + $normal_done) & 0xffff)}]} {
      incr ::dco_invariant_fail_count($hardware_name)
    }
  } else {
    incr ::invalid_frame_count($hardware_name)
  }

  puts [format "STEP5_POSITION_SAMPLE board=%s sample=%d elapsed_ms=%d FRAME_VALID=%d TARGET_CODE=%s APPLIED_CODE=%s POSITION_TARGET=%s POSITION_APPLIED=%s NORMAL_REQ=%s NORMAL_COMPLETED=%s NORMAL_FINC_COMPLETED=%s NORMAL_FDEC_COMPLETED=%s SIGNED_NORMAL_NET=%s DCO_STEP=%s BOOTSTRAP_COMPLETED=%s BOOTSTRAP_DONE=%s TAG_VALID=%s PRECLAMP_ERROR=%s PRECLAMP_ERROR_SIGNED=%s TAG_DELTA=%s TAG_DELTA_SIGNED=%s EXPECTED_DELTA=%s EXPECTED_DELTA_SIGNED=%s FREQ_ERROR_SIGNED=%s HELPER_ERROR=%s HELPER_ERROR_SIGNED=%s HELPER_OUTPUT=%s HELPER_OUTPUT_SIGNED=%s HELPER_LOCKED=%s HELPER_LOCK_COUNT=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
    $hardware_name $sample $elapsed_ms $valid [display_value $target] [display_value $applied] \
    $position_target $position_applied $normal_req $normal_done $finc $fdec \
    [expr {($finc eq "INVALID" || $fdec eq "INVALID") ? "INVALID" : ($finc - $fdec)}] \
    $dco_step $bootstrap_completed $bootstrap_done $tag_valid [display_value $preclamp_raw] $preclamp_signed \
    [display_value $tag_delta_raw] $tag_delta_signed [display_value $expected_delta_raw] $expected_delta_signed \
    $freq_error_signed [display_value $helper_error_raw] $helper_error_signed \
    [display_value $helper_output_raw] $helper_output_signed $helper_locked $helper_lock_count \
    $entry_generation $cpu_reset $wr_reset $si_drop]
  flush stdout
}

proc emit_summary {hardware_name} {
  foreach {tag0 tag1} [list $::tag_valid_first($hardware_name) $::tag_valid_final($hardware_name)] break
  foreach {req0 req1} [list $::normal_req_first($hardware_name) $::normal_req_final($hardware_name)] break
  foreach {done0 done1} [list $::normal_done_first($hardware_name) $::normal_done_final($hardware_name)] break
  foreach {step0 step1} [list $::dco_step_first($hardware_name) $::dco_step_final($hardware_name)] break
  foreach {boot0 boot1} [list $::bootstrap_first($hardware_name) $::bootstrap_final($hardware_name)] break
  foreach {finc0 finc1} [list $::finc_first($hardware_name) $::finc_final($hardware_name)] break
  foreach {fdec0 fdec1} [list $::fdec_first($hardware_name) $::fdec_final($hardware_name)] break
  foreach {gen0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {gen1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  set tag_delta [counter_delta $tag0 $tag1 32]
  set req_delta [counter_delta $req0 $req1 16]
  set done_delta [counter_delta $done0 $done1 16]
  set step_delta [counter_delta $step0 $step1 16]
  set boot_delta [counter_delta $boot0 $boot1 16]
  set finc_delta [counter_delta $finc0 $finc1 16]
  set fdec_delta [counter_delta $fdec0 $fdec1 16]
  set signed_net [expr {($finc_delta eq "INVALID" || $fdec_delta eq "INVALID") ? "INVALID" : ($finc_delta - $fdec_delta)}]
  set expected_applied [expr {$signed_net eq "INVALID" ? "INVALID" : (5 + 64 * $signed_net)}]
  set gen_delta [expr {($gen0 ne "INVALID" && $gen1 ne "INVALID") ? ($gen1 - $gen0) : "INVALID"}]
  set cpu_delta [expr {($cpu0 ne "INVALID" && $cpu1 ne "INVALID") ? ($cpu1 - $cpu0) : "INVALID"}]
  set wr_delta [expr {($wr0 ne "INVALID" && $wr1 ne "INVALID") ? ($wr1 - $wr0) : "INVALID"}]
  set si_delta [expr {($si0 ne "INVALID" && $si1 ne "INVALID") ? ($si1 - $si0) : "INVALID"}]
  set valid $::valid_frame_count($hardware_name)
  set rail_fraction [expr {$valid > 0 ? 100.0 * $::rail5_count($hardware_name) / double($valid) : 0.0}]
  set saturation_fraction [expr {$valid > 0 ? 100.0 * $::plus150000_count($hardware_name) / double($valid) : 0.0}]
  puts [format "STEP5_POSITION_AUDIT_SUMMARY board=%s SAMPLES=%d VALID_FRAMES=%d INVALID_FRAMES=%d WINDOW_SECONDS=%.3f TAG_VALID_DELTA=%s NORMAL_REQ_DELTA=%s NORMAL_COMPLETED_DELTA=%s DCO_STEP_DELTA=%s BOOTSTRAP_COMPLETED_DELTA=%s FINC_DELTA=%s FDEC_DELTA=%s SIGNED_NORMAL_NET=%s APPLIED_FINAL=%s EXPECTED_APPLIED_FROM_NET=%s POSITION_MATCH_SAMPLES=%d POSITION_INVARIANT_FAILS=%d TRANSACTION_INVARIANT_FAILS=%d DCO_INVARIANT_FAILS=%d FIRST_RAIL_SAMPLE=%s RAIL5_SAMPLES=%d RAIL5_FRACTION=%.3f FIRST_PLUS150000_SAMPLE=%s PLUS150000_SAMPLES=%d PLUS150000_FRACTION=%.3f TARGET_FINAL=%s PRECLAMP_ERROR_FINAL=%s TAG_DELTA_FINAL=%s EXPECTED_DELTA_FINAL=%s FREQ_ERROR_FINAL=%s HELPER_ERROR_FINAL=%s HELPER_OUTPUT_FINAL=%s HELPER_LOCKED_FINAL=%s HELPER_LOCK_COUNT_FINAL=%s RESET_BOOT_GENERATION_DELTA=%s RESET_CPU_DELTA=%s RESET_WR_CORE_DELTA=%s RESET_SI_CONFIG_DELTA=%s" \
    $hardware_name $::sample_count($hardware_name) $valid $::invalid_frame_count($hardware_name) \
    [expr {$::elapsed_final($hardware_name) / 1000.0}] $tag_delta $req_delta $done_delta $step_delta $boot_delta \
    $finc_delta $fdec_delta $signed_net $::applied_final($hardware_name) $expected_applied \
    $::position_match_count($hardware_name) $::position_invariant_fail_count($hardware_name) \
    $::transaction_invariant_fail_count($hardware_name) $::dco_invariant_fail_count($hardware_name) \
    $::first_rail_sample($hardware_name) $::rail5_count($hardware_name) $rail_fraction \
    $::first_plus150000_sample($hardware_name) $::plus150000_count($hardware_name) $saturation_fraction \
    $::target_final($hardware_name) $::preclamp_final($hardware_name) $::tag_delta_final($hardware_name) \
    $::expected_delta_final($hardware_name) $::freq_error_final($hardware_name) $::helper_error_final($hardware_name) \
    $::helper_output_final($hardware_name) $::helper_lock_final($hardware_name) $::helper_count_final($hardware_name) \
    $gen_delta $cpu_delta $wr_delta $si_delta]
}

puts [format "STEP5_POSITION_AUDIT_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT read_only=1 position_probe=43 cadence_ms=%d" $samples $gap_ms $board_filter $gap_ms]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && $hardware_name ne $board_filter} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set elapsed_ms [expr {($sample - 1) * $gap_ms}]
      emit_sample $hardware_name $sample $elapsed_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
    emit_summary $hardware_name
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_POSITION_AUDIT_DONE"
