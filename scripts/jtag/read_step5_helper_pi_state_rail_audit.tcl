# Read-only Helper PI state and rail audit for Step5.
#
# The firmware mirror publishes the last completed Helper PI update through
# WDIAGS 0x100..0x128.  The epoch is written last and is accepted only when
# the beginning/end values match and are even.  This keeps the multiword
# signed 64-bit values coherent while the interrupt-driven Helper continues
# to run.  Probe 43/44 provide the signed physical-position context.
#
# Usage:
#   quartus_stp -t read_step5_helper_pi_state_rail_audit.tcl ?samples? ?gap_ms? ?board_filter?

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

set PI_KP -150
set PI_KI -2
set PI_SHIFT 12
set PI_BIAS 5
set PI_Y_MIN 5
set PI_Y_MAX 65531

array set ::wb_toggle {}
array set ::sample_count {}
array set ::valid_frame_count {}
array set ::invalid_frame_count {}
array set ::pi_present_count {}
array set ::pi_accounting_fail_count {}
array set ::pi_output_mismatch_count {}
array set ::anti_windup_violation_count {}
array set ::low_rail_count {}
array set ::high_rail_count {}
array set ::zero_crossing_count {}
array set ::physical_position_mismatch_count {}
array set ::first_high_rail_sample {}
array set ::first_low_rail_sample {}
array set ::first_zero_crossing_sample {}
array set ::first_low_leave_sample {}
array set ::high_seen {}
array set ::high_to_low_seen {}
array set ::zero_crossing_seen {}
array set ::low_after_zero_seen {}
array set ::cycle_complete {}
array set ::previous_freq_error {}
array set ::tag_valid_first {}
array set ::tag_valid_final {}
array set ::normal_completed_first {}
array set ::normal_completed_final {}
array set ::position_applied_final {}
array set ::position_target_final {}
array set ::helper_error_final {}
array set ::helper_output_final {}
array set ::helper_locked_final {}
array set ::helper_count_final {}
array set ::pi_epoch_final {}
array set ::pi_before_final {}
array set ::pi_i_new_final {}
array set ::pi_after_final {}
array set ::pi_unclamped_final {}
array set ::pi_clamped_final {}
array set ::pi_side_final {}
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
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  set text [string repeat 0 [expr {16 - [string length $text]}]]$text
  scan $text %x word
  return $word
}

proc signed32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  if {$word >= 0x80000000} {
    return [expr {$word - 0x100000000}]
  }
  return $word
}

proc signed64_words {lo_raw hi_raw} {
  set lo [word32 $lo_raw]
  set hi [word32 $hi_raw]
  if {$lo < 0 || $hi < 0} { return INVALID }
  set value [expr {$hi * 4294967296 + $lo}]
  if {$hi >= 0x80000000} {
    return [expr {$value - 18446744073709551616}]
  }
  return $value
}

proc display_value {value} {
  if {![is_hex $value]} { return $value }
  return [string toupper $value]
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

proc frame_valid {ctrl_begin ctrl_end} {
  set a [word32 $ctrl_begin]
  set b [word32 $ctrl_end]
  if {$a < 0 || $b < 0} { return 0 }
  return [expr {(($a & 1) != 0) && (($b & 1) != 0) && $a == $b}]
}

proc read_stable_position_pair {} {
  for {set attempt 0} {$attempt < 10} {incr attempt} {
    set accounting_before [probe_read 44]
    set position [probe_read 43]
    set accounting_after [probe_read 44]
    if {[is_hex $accounting_before] && [is_hex $position] &&
        [is_hex $accounting_after] &&
        [string equal -nocase $accounting_before $accounting_after]} {
      return [list $position $accounting_after]
    }
    after 1
  }
  return [list INVALID INVALID]
}

proc read_pi_snapshot {hardware_name} {
  # The firmware writes WDIAGS PI fields and the epoch commit word as the
  # final operation of one refresh.  Bracket every field with that commit
  # word so the observer rejects a refresh crossing.
  for {set attempt 0} {$attempt < 8} {incr attempt} {
    set ctrl_begin [wb_read $hardware_name 0x00100A04]
    set epoch_begin [wb_read $hardware_name 0x00100B00]
    set epoch_word [word32 $epoch_begin]
    if {$epoch_word < 0 || ($epoch_word & 1)} {
      after 2
      continue
    }
    set before_lo [wb_read $hardware_name 0x00100B04]
    set before_hi [wb_read $hardware_name 0x00100B08]
    set i_new_lo [wb_read $hardware_name 0x00100B0C]
    set i_new_hi [wb_read $hardware_name 0x00100B10]
    set after_lo [wb_read $hardware_name 0x00100B14]
    set after_hi [wb_read $hardware_name 0x00100B18]
    set unclamped [wb_read $hardware_name 0x00100B1C]
    set clamped [wb_read $hardware_name 0x00100B20]
    set tag_delta [wb_read $hardware_name 0x00100B24]
    set expected_delta [wb_read $hardware_name 0x00100B28]
    set helper_state [wb_read $hardware_name 0x00100ABC]
    set helper_error [wb_read $hardware_name 0x00100AD8]
    set helper_output [wb_read $hardware_name 0x00100ADC]
    set ctrl_end [wb_read $hardware_name 0x00100A04]
    set epoch_end [wb_read $hardware_name 0x00100B00]
    if {[string equal -nocase $epoch_begin $epoch_end] &&
        [frame_valid $ctrl_begin $ctrl_end]} {
      return [list 1 $epoch_word $before_lo $before_hi $i_new_lo $i_new_hi \
        $after_lo $after_hi $unclamped $clamped $helper_state $helper_error \
        $helper_output $tag_delta $expected_delta]
    }
    after 2
  }
  return [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
}

proc initialize_board {hardware_name} {
  set ::sample_count($hardware_name) 0
  set ::valid_frame_count($hardware_name) 0
  set ::invalid_frame_count($hardware_name) 0
  set ::pi_present_count($hardware_name) 0
  set ::pi_accounting_fail_count($hardware_name) 0
  set ::pi_output_mismatch_count($hardware_name) 0
  set ::anti_windup_violation_count($hardware_name) 0
  set ::low_rail_count($hardware_name) 0
  set ::high_rail_count($hardware_name) 0
  set ::zero_crossing_count($hardware_name) 0
  set ::physical_position_mismatch_count($hardware_name) 0
  set ::first_high_rail_sample($hardware_name) NONE
  set ::first_low_rail_sample($hardware_name) NONE
  set ::first_zero_crossing_sample($hardware_name) NONE
  set ::first_low_leave_sample($hardware_name) NONE
  set ::high_seen($hardware_name) 0
  set ::high_to_low_seen($hardware_name) 0
  set ::zero_crossing_seen($hardware_name) 0
  set ::low_after_zero_seen($hardware_name) 0
  set ::cycle_complete($hardware_name) 0
  set ::previous_freq_error($hardware_name) INVALID
  set ::tag_valid_first($hardware_name) INVALID
  set ::tag_valid_final($hardware_name) INVALID
  set ::normal_completed_first($hardware_name) INVALID
  set ::normal_completed_final($hardware_name) INVALID
  set ::position_applied_final($hardware_name) INVALID
  set ::position_target_final($hardware_name) INVALID
  set ::helper_error_final($hardware_name) INVALID
  set ::helper_output_final($hardware_name) INVALID
  set ::helper_locked_final($hardware_name) INVALID
  set ::helper_count_final($hardware_name) INVALID
  set ::pi_epoch_final($hardware_name) INVALID
  set ::pi_before_final($hardware_name) INVALID
  set ::pi_i_new_final($hardware_name) INVALID
  set ::pi_after_final($hardware_name) INVALID
  set ::pi_unclamped_final($hardware_name) INVALID
  set ::pi_clamped_final($hardware_name) INVALID
  set ::pi_side_final($hardware_name) INVALID
  set ::reset_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::elapsed_final($hardware_name) 0
}

proc emit_sample {hardware_name sample elapsed_ms} {
  global PI_KP PI_KI PI_SHIFT PI_BIAS PI_Y_MIN PI_Y_MAX
  foreach {position_raw accounting_raw} [read_stable_position_pair] break
  set position_word [word64 $position_raw]
  set accounting_word [word64 $accounting_raw]
  set position_target INVALID
  set position_applied INVALID
  set normal_completed INVALID
  set normal_finc INVALID
  set normal_fdec INVALID
  if {$position_word >= 0} {
    set position_target [expr {$position_word & 0xffff}]
    set position_applied [expr {($position_word >> 16) & 0xffff}]
    set normal_finc [expr {($position_word >> 32) & 0xffff}]
    set normal_fdec [expr {($position_word >> 48) & 0xffff}]
  }
  if {$accounting_word >= 0} {
    set normal_completed [expr {$accounting_word & 0xffff}]
  }
  set entry_probe [probe_read 26]
  set reset_probe [probe_read 27]
  set entry_generation [probe_high32 $entry_probe]
  set cpu_reset [probe_field32 $reset_probe 16 8]
  set wr_reset [probe_field32 $reset_probe 24 8]
  set si_drop [probe_field32 $reset_probe 40 8]

  foreach {pi_valid pi_epoch before_lo before_hi i_new_lo i_new_hi \
           after_lo after_hi unclamped_raw clamped_raw helper_state_raw \
           helper_error_raw helper_output_raw tag_delta_raw expected_delta_raw} \
      [read_pi_snapshot $hardware_name] break
  set ctrl_valid $pi_valid
  set pi_before [signed64_words $before_lo $before_hi]
  set pi_i_new [signed64_words $i_new_lo $i_new_hi]
  set pi_after [signed64_words $after_lo $after_hi]
  set pi_unclamped [signed32 $unclamped_raw]
  set pi_clamped [signed32 $clamped_raw]
  set pi_side INVALID
  if {$pi_unclamped ne "INVALID"} {
    if {$pi_unclamped < $PI_Y_MIN} {
      set pi_side -1
    } elseif {$pi_unclamped > $PI_Y_MAX} {
      set pi_side 1
    } else {
      set pi_side 0
    }
  }
  set helper_error [signed32 $helper_error_raw]
  set helper_output [signed32 $helper_output_raw]
  set tag_delta [signed32 $tag_delta_raw]
  set expected_delta [signed32 $expected_delta_raw]
  set freq_error INVALID
  if {$tag_delta ne "INVALID" && $expected_delta ne "INVALID"} {
    set freq_error [expr {$tag_delta - $expected_delta}]
  }
  set helper_locked [probe_field32 $helper_state_raw 0 1]
  set helper_count [probe_field32 $helper_state_raw 16 16]
  set tag_valid [signed32 [wb_read $hardware_name 0x00100AF8]]
  if {$tag_valid < 0} { set tag_valid INVALID }

  if {$sample == 1} {
    initialize_board $hardware_name
    set ::tag_valid_first($hardware_name) $tag_valid
    set ::normal_completed_first($hardware_name) $normal_completed
    set ::reset_first($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
  }
  incr ::sample_count($hardware_name)
  set ::elapsed_final($hardware_name) $elapsed_ms
  set ::tag_valid_final($hardware_name) $tag_valid
  set ::normal_completed_final($hardware_name) $normal_completed
  set ::position_target_final($hardware_name) $position_target
  set ::position_applied_final($hardware_name) $position_applied
  set ::helper_error_final($hardware_name) $helper_error
  set ::helper_output_final($hardware_name) $helper_output
  set ::helper_locked_final($hardware_name) $helper_locked
  set ::helper_count_final($hardware_name) $helper_count
  set ::pi_epoch_final($hardware_name) $pi_epoch
  set ::pi_before_final($hardware_name) $pi_before
  set ::pi_i_new_final($hardware_name) $pi_i_new
  set ::pi_after_final($hardware_name) $pi_after
  set ::pi_unclamped_final($hardware_name) $pi_unclamped
  set ::pi_clamped_final($hardware_name) $pi_clamped
  set ::pi_side_final($hardware_name) $pi_side
  set ::reset_final($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]

  set valid [expr {$ctrl_valid && $helper_error ne "INVALID"}]
  if {$valid} {
    incr ::valid_frame_count($hardware_name)
  } else {
    incr ::invalid_frame_count($hardware_name)
  }

  set pi_present [expr {$valid && $pi_epoch ne "INVALID" && $pi_epoch != 0}]
  if {$pi_present} {
    incr ::pi_present_count($hardware_name)
    set expected_i_new [expr {$pi_before + $PI_KI * $helper_error}]
    set expected_unclamped [expr {(($expected_i_new + $PI_KP * $helper_error + (1 << ($PI_SHIFT - 1))) >> $PI_SHIFT) + $PI_BIAS}]
    set expected_clamped $expected_unclamped
    set expected_side 0
    if {$expected_clamped < $PI_Y_MIN} {
      set expected_clamped $PI_Y_MIN
      set expected_side -1
    } elseif {$expected_clamped > $PI_Y_MAX} {
      set expected_clamped $PI_Y_MAX
      set expected_side 1
    }
    set expected_after $expected_i_new
    if {$expected_side == -1 && $expected_i_new <= $pi_before} {
      set expected_after $pi_before
    } elseif {$expected_side == 1 && $expected_i_new >= $pi_before} {
      set expected_after $pi_before
    }
    if {$pi_i_new != $expected_i_new || $pi_after != $expected_after ||
        $pi_unclamped != $expected_unclamped || $pi_clamped != $expected_clamped ||
        $pi_side != $expected_side} {
      incr ::pi_accounting_fail_count($hardware_name)
    }
    if {$pi_clamped != $helper_output} {
      incr ::pi_output_mismatch_count($hardware_name)
    }
    if {$pi_side == -1 && $pi_unclamped < $PI_Y_MIN && $helper_error > 0 &&
        $pi_after != $pi_before} {
      incr ::anti_windup_violation_count($hardware_name)
    }
    if {$pi_side == 1 && $pi_unclamped > $PI_Y_MAX && $helper_error < 0 &&
        $pi_after != $pi_before} {
      incr ::anti_windup_violation_count($hardware_name)
    }
    if {$pi_side == -1 && $pi_clamped == $PI_Y_MIN} {
      incr ::low_rail_count($hardware_name)
      if {$::first_low_rail_sample($hardware_name) eq "NONE"} {
        set ::first_low_rail_sample($hardware_name) $sample
      }
      if {$::high_seen($hardware_name)} {
        set ::high_to_low_seen($hardware_name) 1
      }
      if {$::zero_crossing_seen($hardware_name)} {
        set ::low_after_zero_seen($hardware_name) 1
      }
    }
    if {$pi_side == 1 && $pi_clamped == $PI_Y_MAX} {
      incr ::high_rail_count($hardware_name)
      set ::high_seen($hardware_name) 1
      if {$::first_high_rail_sample($hardware_name) eq "NONE"} {
        set ::first_high_rail_sample($hardware_name) $sample
      }
    }
    if {$freq_error ne "INVALID" && $::previous_freq_error($hardware_name) ne "INVALID" &&
        $::previous_freq_error($hardware_name) > 0 && $freq_error <= 0} {
      incr ::zero_crossing_count($hardware_name)
      set ::zero_crossing_seen($hardware_name) 1
      if {$::first_zero_crossing_sample($hardware_name) eq "NONE"} {
        set ::first_zero_crossing_sample($hardware_name) $sample
      }
    }
    if {$::low_after_zero_seen($hardware_name) &&
        !($pi_side == -1 && $pi_clamped == $PI_Y_MIN) &&
        $::first_low_leave_sample($hardware_name) eq "NONE"} {
      set ::first_low_leave_sample($hardware_name) $sample
    }
    if {$::high_to_low_seen($hardware_name) && $::zero_crossing_seen($hardware_name) &&
        $::low_after_zero_seen($hardware_name) &&
        $::first_low_leave_sample($hardware_name) ne "NONE"} {
      set ::cycle_complete($hardware_name) 1
    }
    set ::previous_freq_error($hardware_name) $freq_error
    if {$position_applied ne "INVALID" && $normal_finc ne "INVALID" &&
        $normal_fdec ne "INVALID"} {
      # Retain the signed virtual-to-physical invariant in the same stream
      # so the PI trajectory cannot be detached from the actuator position.
      set expected_applied [expr {(5 + 64 * ($normal_finc - $normal_fdec)) & 0xffff}]
      if {$position_applied != $expected_applied} {
        incr ::physical_position_mismatch_count($hardware_name)
      }
    }
  }

  puts [format "STEP5_PI_SAMPLE board=%s sample=%d elapsed_ms=%d FRAME_VALID=%d PI_TRACE_PRESENT=%d PI_EPOCH=%s PI_INTEGRATOR_BEFORE=%s PI_I_NEW=%s PI_INTEGRATOR_AFTER=%s PI_UNCLAMPED_OUTPUT=%s PI_CLAMPED_OUTPUT=%s PI_CLAMP_SIDE=%s HELPER_ERROR=%s HELPER_OUTPUT=%s FREQ_ERROR=%s TARGET_CODE=%s APPLIED_CODE=%s NORMAL_COMPLETED=%s NORMAL_FINC=%s NORMAL_FDEC=%s HELPER_LOCKED=%s HELPER_LOCK_COUNT=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
    $hardware_name $sample $elapsed_ms $valid $pi_present $pi_epoch $pi_before $pi_i_new $pi_after \
    $pi_unclamped $pi_clamped $pi_side $helper_error $helper_output $freq_error \
    $position_target $position_applied $normal_completed $normal_finc $normal_fdec $helper_locked $helper_count \
    $entry_generation $cpu_reset $wr_reset $si_drop]
  flush stdout
}

proc emit_summary {hardware_name} {
  global PI_KP PI_KI PI_SHIFT PI_BIAS PI_Y_MIN PI_Y_MAX
  set valid $::valid_frame_count($hardware_name)
  set rail_fraction [expr {$valid > 0 ? 100.0 * $::low_rail_count($hardware_name) / double($valid) : 0.0}]
  set high_fraction [expr {$valid > 0 ? 100.0 * $::high_rail_count($hardware_name) / double($valid) : 0.0}]
  set pi_fraction [expr {$::sample_count($hardware_name) > 0 ? 100.0 * $::pi_present_count($hardware_name) / double($::sample_count($hardware_name)) : 0.0}]
  foreach {gen0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {gen1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  set gen_delta [expr {($gen0 ne "INVALID" && $gen1 ne "INVALID") ? ($gen1 - $gen0) : "INVALID"}]
  set cpu_delta [expr {($cpu0 ne "INVALID" && $cpu1 ne "INVALID") ? ($cpu1 - $cpu0) : "INVALID"}]
  set wr_delta [expr {($wr0 ne "INVALID" && $wr1 ne "INVALID") ? ($wr1 - $wr0) : "INVALID"}]
  set si_delta [expr {($si0 ne "INVALID" && $si1 ne "INVALID") ? ($si1 - $si0) : "INVALID"}]
  puts [format "STEP5_PI_AUDIT_SUMMARY board=%s SAMPLES=%d VALID_FRAMES=%d INVALID_FRAMES=%d WINDOW_SECONDS=%.3f PI_TRACE_PRESENT=%d PI_TRACE_FRACTION=%.3f PI_ACCOUNTING_FAILS=%d PI_OUTPUT_MISMATCH_FAILS=%d ANTI_WINDUP_VIOLATIONS=%d LOW_RAIL_SAMPLES=%d LOW_RAIL_FRACTION=%.3f HIGH_RAIL_SAMPLES=%d HIGH_RAIL_FRACTION=%.3f FIRST_HIGH_RAIL_SAMPLE=%s FIRST_LOW_RAIL_SAMPLE=%s FREQ_ZERO_CROSSINGS=%d FIRST_ZERO_CROSSING_SAMPLE=%s FIRST_LOW_LEAVE_SAMPLE=%s HIGH_TO_LOW_SEEN=%d LOW_AFTER_ZERO_SEEN=%d RAIL_TO_RAIL_CYCLE_COMPLETE=%d POSITION_CONTEXT_FAILS=%d KP=%d KI=%d SHIFT=%d BIAS=%d Y_MIN=%d Y_MAX=%d TAG_VALID_FIRST=%s TAG_VALID_FINAL=%s NORMAL_COMPLETED_FIRST=%s NORMAL_COMPLETED_FINAL=%s TARGET_FINAL=%s APPLIED_FINAL=%s HELPER_ERROR_FINAL=%s HELPER_OUTPUT_FINAL=%s PI_EPOCH_FINAL=%s PI_INTEGRATOR_BEFORE_FINAL=%s PI_I_NEW_FINAL=%s PI_INTEGRATOR_AFTER_FINAL=%s PI_UNCLAMPED_FINAL=%s PI_CLAMPED_FINAL=%s PI_CLAMP_SIDE_FINAL=%s HELPER_LOCKED_FINAL=%s HELPER_LOCK_COUNT_FINAL=%s RESET_BOOT_GENERATION_DELTA=%s RESET_CPU_DELTA=%s RESET_WR_CORE_DELTA=%s RESET_SI_CONFIG_DELTA=%s" \
    $hardware_name $::sample_count($hardware_name) $valid $::invalid_frame_count($hardware_name) \
    [expr {$::elapsed_final($hardware_name) / 1000.0}] $::pi_present_count($hardware_name) $pi_fraction \
    $::pi_accounting_fail_count($hardware_name) $::pi_output_mismatch_count($hardware_name) \
    $::anti_windup_violation_count($hardware_name) \
    $::low_rail_count($hardware_name) $rail_fraction $::high_rail_count($hardware_name) $high_fraction \
    $::first_high_rail_sample($hardware_name) $::first_low_rail_sample($hardware_name) \
    $::zero_crossing_count($hardware_name) $::first_zero_crossing_sample($hardware_name) \
    $::first_low_leave_sample($hardware_name) $::high_to_low_seen($hardware_name) \
    $::low_after_zero_seen($hardware_name) $::cycle_complete($hardware_name) \
    $::physical_position_mismatch_count($hardware_name) $PI_KP $PI_KI $PI_SHIFT $PI_BIAS \
    $PI_Y_MIN $PI_Y_MAX $::tag_valid_first($hardware_name) $::tag_valid_final($hardware_name) \
    $::normal_completed_first($hardware_name) $::normal_completed_final($hardware_name) \
    $::position_target_final($hardware_name) $::position_applied_final($hardware_name) \
    $::helper_error_final($hardware_name) $::helper_output_final($hardware_name) \
    $::pi_epoch_final($hardware_name) $::pi_before_final($hardware_name) $::pi_i_new_final($hardware_name) \
    $::pi_after_final($hardware_name) $::pi_unclamped_final($hardware_name) $::pi_clamped_final($hardware_name) \
    $::pi_side_final($hardware_name) $::helper_locked_final($hardware_name) $::helper_count_final($hardware_name) \
    $gen_delta $cpu_delta $wr_delta $si_delta]
}

puts [format "STEP5_PI_AUDIT_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-6208-64-HELPER-PI-STATE-RAIL-AUDIT read_only=1 pi_trace_base=0x200 fresh_reset_required=1" $samples $gap_ms $board_filter]

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

puts "STEP5_PI_AUDIT_DONE"
