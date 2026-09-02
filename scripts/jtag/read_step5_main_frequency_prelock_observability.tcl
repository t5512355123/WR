# White Rabbit Step5 Main-frequency pre-lock observability observer.
#
# This script is read-only.  It reads the Main frequency/pre-lock diagnostic
# overlay and the existing lock/reset shadows; it does not request a Helper
# PI snapshot, write WR configuration, drain the SoftPLL debug FIFO, or alter
# the HPLL/DCO controller.
#
# Usage:
#   quartus_stp -t read_step5_main_frequency_prelock_observability.tcl \
#     ?samples? ?gap_ms? ?board_filter?
#
# The intended run is 6000 samples at 100 ms (600 seconds).

package require ::quartus::insystem_source_probe

set samples 6000
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
array set ::trace_valid_count {}
array set ::frame_valid_count {}
array set ::invalid_count {}
array set ::measurement_failures {}
array set ::freq_count {}
array set ::freq_sum {}
array set ::freq_sumsq {}
array set ::freq_min {}
array set ::freq_max {}
array set ::freq_max_abs {}
array set ::freq_first {}
array set ::freq_last {}
array set ::freq_band_count {}
array set ::prelock_mismatch_count {}
array set ::pi_count {}
array set ::pi_low_rail_count {}
array set ::pi_high_rail_count {}
array set ::pi_no_rail_count {}
array set ::main_freq_lock_count_max_seen {}
array set ::main_freq_lock_count_final {}
array set ::main_freq_lock_count_max_final {}
array set ::main_enabled_final {}
array set ::main_freq_locked_final {}
array set ::main_phase_locked_final {}
array set ::main_locked_final {}
array set ::main_freq_locked_ever {}
array set ::main_phase_locked_ever {}
array set ::main_locked_ever {}
array set ::helper_locked_final {}
array set ::helper_locked_ever {}
array set ::helper_lock_count_max {}
array set ::helper_lock_count_final {}
array set ::pstat_locked_final {}
array set ::pstat_locked_ever {}
array set ::spll_delock_first {}
array set ::spll_delock_final {}
array set ::spll_delock_max {}
array set ::reset_first {}
array set ::reset_final {}
array set ::entry_generation_first {}
array set ::entry_generation_final {}
array set ::main_trace_magic_final {}
array set ::main_trace_epoch_before_raw {}
array set ::main_trace_epoch_after_raw {}
array set ::main_trace_magic_raw {}
array set ::main_trace_update_count_final {}
array set ::main_trace_last_dref {}
array set ::main_trace_last_dout {}
array set ::main_trace_last_error {}
array set ::main_trace_last_prelock {}
array set ::main_trace_last_unclamped {}
array set ::main_trace_last_output {}
array set ::main_trace_last_clamp_side {}
array set ::main_trace_last_kp {}
array set ::main_trace_last_ki {}
array set ::main_trace_last_shift {}
array set ::main_trace_last_bias {}
array set ::main_trace_last_threshold {}
array set ::main_trace_last_lock_samples {}
array set ::main_trace_last_ymin {}
array set ::main_trace_last_ymax {}
array set ::main_trace_last_anti_windup {}
array set ::main_trace_last_x {}
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

proc frame_valid {ctrl_begin ctrl_end} {
  set a [word32 $ctrl_begin]
  set b [word32 $ctrl_end]
  if {$a < 0 || $b < 0} { return 0 }
  return [expr {(($a & 1) != 0) && (($b & 1) != 0)}]
}

proc selected_board {hardware_name} {
  if {$::board_filter eq ""} { return 1 }
  return [expr {[string first $::board_filter $hardware_name] >= 0}]
}

proc read_main_trace {hardware_name} {
  # CPU addresses are BASE_WDIAGS_PRIV + offsets 0x158..0x1ac and 0x1dc.
  # The epoch is odd while task-diags publishes and even after completion.
  for {set attempt 0} {$attempt < 8} {incr attempt} {
    set epoch_before_raw [wb_read $hardware_name 0x00100B58]
    set ::main_trace_epoch_before_raw($hardware_name) $epoch_before_raw
    set epoch_before [word32 $epoch_before_raw]
    if {$epoch_before < 0 || ($epoch_before & 1)} { after 1; continue }
    set dref [signed32 [wb_read $hardware_name 0x00100B5C]]
    set dout [signed32 [wb_read $hardware_name 0x00100B60]]
    set freq_error [signed32 [wb_read $hardware_name 0x00100B64]]
    set prelock_error [signed32 [wb_read $hardware_name 0x00100B68]]
    set pi_unclamped [signed32 [wb_read $hardware_name 0x00100B6C]]
    set pi_output [signed32 [wb_read $hardware_name 0x00100B70]]
    set clamp_side [signed32 [wb_read $hardware_name 0x00100B74]]
    set lock_count [word32 [wb_read $hardware_name 0x00100B78]]
    set lock_count_max [word32 [wb_read $hardware_name 0x00100B7C]]
    set kp [signed32 [wb_read $hardware_name 0x00100B80]]
    set ki [signed32 [wb_read $hardware_name 0x00100B84]]
    set shift [signed32 [wb_read $hardware_name 0x00100B88]]
    set bias [signed32 [wb_read $hardware_name 0x00100B8C]]
    set update_count [word32 [wb_read $hardware_name 0x00100B90]]
    set threshold [word32 [wb_read $hardware_name 0x00100B94]]
    set lock_samples [word32 [wb_read $hardware_name 0x00100B98]]
    set state [word32 [wb_read $hardware_name 0x00100B9C]]
    set y_min [signed32 [wb_read $hardware_name 0x00100BA0]]
    set y_max [signed32 [wb_read $hardware_name 0x00100BA4]]
    set anti_windup [signed32 [wb_read $hardware_name 0x00100BA8]]
    set pi_x [signed32 [wb_read $hardware_name 0x00100BAC]]
    set magic_raw [wb_read $hardware_name 0x00100BDC]
    set ::main_trace_magic_raw($hardware_name) $magic_raw
    set magic [word32 $magic_raw]
    set epoch_after_raw [wb_read $hardware_name 0x00100B58]
    set ::main_trace_epoch_after_raw($hardware_name) $epoch_after_raw
    set epoch_after [word32 $epoch_after_raw]
    if {$epoch_before == $epoch_after && $epoch_after >= 0 &&
        !($epoch_after & 1) && $magic == 1 &&
        $dref ne "INVALID" && $dout ne "INVALID" &&
        $freq_error ne "INVALID" && $prelock_error ne "INVALID" &&
        $pi_unclamped ne "INVALID" && $pi_output ne "INVALID" &&
        $clamp_side ne "INVALID" && $lock_count ne "INVALID" &&
        $lock_count_max ne "INVALID" && $kp ne "INVALID" &&
        $ki ne "INVALID" && $shift ne "INVALID" && $bias ne "INVALID" &&
        $update_count ne "INVALID" && $threshold ne "INVALID" &&
        $lock_samples ne "INVALID" && $state ne "INVALID" &&
        $y_min ne "INVALID" && $y_max ne "INVALID" &&
        $anti_windup ne "INVALID" && $pi_x ne "INVALID"} {
      return [list 1 $epoch_after $dref $dout $freq_error $prelock_error \
        $pi_unclamped $pi_output $clamp_side $lock_count $lock_count_max \
        $kp $ki $shift $bias $update_count $threshold $lock_samples $state \
        $y_min $y_max $anti_windup $pi_x $magic]
    }
    after 1
  }
  return [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
}

proc read_helper_pair {hardware_name} {
  set state [wb_read $hardware_name 0x00100ABC]
  set limits [wb_read $hardware_name 0x00100AC0]
  return [list $state $limits]
}

proc initialize_board {hardware_name} {
  set ::sample_count($hardware_name) 0
  set ::trace_valid_count($hardware_name) 0
  set ::frame_valid_count($hardware_name) 0
  set ::invalid_count($hardware_name) 0
  set ::measurement_failures($hardware_name) 0
  set ::freq_count($hardware_name) 0
  set ::freq_sum($hardware_name) 0.0
  set ::freq_sumsq($hardware_name) 0.0
  set ::freq_min($hardware_name) INVALID
  set ::freq_max($hardware_name) INVALID
  set ::freq_max_abs($hardware_name) INVALID
  set ::freq_first($hardware_name) INVALID
  set ::freq_last($hardware_name) INVALID
  set ::freq_band_count($hardware_name) 0
  set ::prelock_mismatch_count($hardware_name) 0
  set ::pi_count($hardware_name) 0
  set ::pi_low_rail_count($hardware_name) 0
  set ::pi_high_rail_count($hardware_name) 0
  set ::pi_no_rail_count($hardware_name) 0
  set ::main_freq_lock_count_max_seen($hardware_name) 0
  set ::main_freq_lock_count_final($hardware_name) INVALID
  set ::main_freq_lock_count_max_final($hardware_name) INVALID
  set ::main_enabled_final($hardware_name) INVALID
  set ::main_freq_locked_final($hardware_name) INVALID
  set ::main_phase_locked_final($hardware_name) INVALID
  set ::main_locked_final($hardware_name) INVALID
  set ::main_freq_locked_ever($hardware_name) 0
  set ::main_phase_locked_ever($hardware_name) 0
  set ::main_locked_ever($hardware_name) 0
  set ::helper_locked_final($hardware_name) INVALID
  set ::helper_locked_ever($hardware_name) 0
  set ::helper_lock_count_max($hardware_name) 0
  set ::helper_lock_count_final($hardware_name) INVALID
  set ::pstat_locked_final($hardware_name) INVALID
  set ::pstat_locked_ever($hardware_name) 0
  set ::spll_delock_first($hardware_name) INVALID
  set ::spll_delock_final($hardware_name) INVALID
  set ::spll_delock_max($hardware_name) 0
  set ::reset_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::entry_generation_first($hardware_name) INVALID
  set ::entry_generation_final($hardware_name) INVALID
  set ::main_trace_magic_final($hardware_name) INVALID
  set ::main_trace_epoch_before_raw($hardware_name) INVALID
  set ::main_trace_epoch_after_raw($hardware_name) INVALID
  set ::main_trace_magic_raw($hardware_name) INVALID
  set ::main_trace_update_count_final($hardware_name) INVALID
  set ::main_trace_last_dref($hardware_name) INVALID
  set ::main_trace_last_dout($hardware_name) INVALID
  set ::main_trace_last_error($hardware_name) INVALID
  set ::main_trace_last_prelock($hardware_name) INVALID
  set ::main_trace_last_unclamped($hardware_name) INVALID
  set ::main_trace_last_output($hardware_name) INVALID
  set ::main_trace_last_clamp_side($hardware_name) INVALID
  set ::main_trace_last_kp($hardware_name) INVALID
  set ::main_trace_last_ki($hardware_name) INVALID
  set ::main_trace_last_shift($hardware_name) INVALID
  set ::main_trace_last_bias($hardware_name) INVALID
  set ::main_trace_last_threshold($hardware_name) INVALID
  set ::main_trace_last_lock_samples($hardware_name) INVALID
  set ::main_trace_last_ymin($hardware_name) INVALID
  set ::main_trace_last_ymax($hardware_name) INVALID
  set ::main_trace_last_anti_windup($hardware_name) INVALID
  set ::main_trace_last_x($hardware_name) INVALID
  set ::elapsed_final($hardware_name) 0
}

proc update_freq_stats {hardware_name freq} {
  if {$freq eq "INVALID"} { return }
  if {$::freq_count($hardware_name) == 0} {
    set ::freq_min($hardware_name) $freq
    set ::freq_max($hardware_name) $freq
    set ::freq_max_abs($hardware_name) [expr {abs($freq)}]
    set ::freq_first($hardware_name) $freq
  } else {
    if {$freq < $::freq_min($hardware_name)} { set ::freq_min($hardware_name) $freq }
    if {$freq > $::freq_max($hardware_name)} { set ::freq_max($hardware_name) $freq }
    if {[expr {abs($freq)}] > $::freq_max_abs($hardware_name)} {
      set ::freq_max_abs($hardware_name) [expr {abs($freq)}]
    }
  }
  incr ::freq_count($hardware_name)
  set ::freq_last($hardware_name) $freq
  set ::freq_sum($hardware_name) [expr {$::freq_sum($hardware_name) + double($freq)}]
  set ::freq_sumsq($hardware_name) [expr {$::freq_sumsq($hardware_name) + double($freq) * double($freq)}]
  if {[expr {abs($freq) <= 50}]} { incr ::freq_band_count($hardware_name) }
}

proc emit_sample {hardware_name sample elapsed_ms} {
  if {$sample == 1} { initialize_board $hardware_name }
  incr ::sample_count($hardware_name)
  set ctrl_begin [wb_read $hardware_name 0x00100A04]
  set trace [read_main_trace $hardware_name]
  foreach {trace_ok epoch dref dout freq_error prelock_error pi_unclamped pi_output \
      clamp_side lock_count lock_count_max kp ki shift bias update_count threshold \
      lock_samples state y_min y_max anti_windup pi_x magic} $trace break
  set ctrl_end [wb_read $hardware_name 0x00100A04]
  set frame_ok [frame_valid $ctrl_begin $ctrl_end]
  if {$frame_ok} { incr ::frame_valid_count($hardware_name) }
  if {$trace_ok} { incr ::trace_valid_count($hardware_name) } else { incr ::invalid_count($hardware_name) }

  foreach {helper_state helper_limits} [read_helper_pair $hardware_name] break
  set helper_locked [field32 $helper_state 0 1]
  set helper_lock_count [field32 $helper_state 16 16]
  set helper_threshold [field32 $helper_limits 0 16]
  set helper_lock_samples [field32 $helper_limits 16 16]
  set pstat [wb_read $hardware_name 0x00100A0C]
  set pstat_locked [field32 $pstat 1 1]
  set spll_state [wb_read $hardware_name 0x00100AA0]
  set spll_delock [field32 $spll_state 24 8]
  set entry_probe [probe_read 26]
  set reset_probe [probe_read 27]
  set entry_generation [probe_high32 $entry_probe]
  set cpu_reset [probe_field32 $reset_probe 16 8]
  set wr_reset [probe_field32 $reset_probe 24 8]
  set si_drop [probe_field32 $reset_probe 40 8]

  if {$sample == 1} {
    set ::reset_first($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
    set ::entry_generation_first($hardware_name) $entry_generation
    set ::spll_delock_first($hardware_name) $spll_delock
  }
  set ::reset_final($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
  set ::entry_generation_final($hardware_name) $entry_generation
  set ::spll_delock_final($hardware_name) $spll_delock
  if {$spll_delock ne "INVALID" && $spll_delock > $::spll_delock_max($hardware_name)} {
    set ::spll_delock_max($hardware_name) $spll_delock
  }

  if {$trace_ok} {
    set derived_error [expr {$dout - $dref}]
    if {$freq_error != $derived_error} { incr ::measurement_failures($hardware_name) }
    if {$prelock_error != [expr {-20 * $freq_error}]} { incr ::prelock_mismatch_count($hardware_name) }
    update_freq_stats $hardware_name $freq_error
    if {$lock_count > $::main_freq_lock_count_max_seen($hardware_name)} {
      set ::main_freq_lock_count_max_seen($hardware_name) $lock_count
    }
    incr ::pi_count($hardware_name)
    if {$clamp_side == -1} {
      incr ::pi_low_rail_count($hardware_name)
    } elseif {$clamp_side == 1} {
      incr ::pi_high_rail_count($hardware_name)
    } elseif {$clamp_side == 0} {
      incr ::pi_no_rail_count($hardware_name)
    }
    set main_enabled [expr {($state >> 0) & 1}]
    set main_freq_locked [expr {($state >> 1) & 1}]
    set main_phase_locked [expr {($state >> 2) & 1}]
    set main_locked [expr {($state >> 3) & 1}]
    if {$main_freq_locked} { set ::main_freq_locked_ever($hardware_name) 1 }
    if {$main_phase_locked} { set ::main_phase_locked_ever($hardware_name) 1 }
    if {$main_locked} { set ::main_locked_ever($hardware_name) 1 }
    set ::main_enabled_final($hardware_name) $main_enabled
    set ::main_freq_locked_final($hardware_name) $main_freq_locked
    set ::main_phase_locked_final($hardware_name) $main_phase_locked
    set ::main_locked_final($hardware_name) $main_locked
    set ::main_freq_lock_count_final($hardware_name) $lock_count
    set ::main_freq_lock_count_max_final($hardware_name) $lock_count_max
    set ::main_trace_magic_final($hardware_name) $magic
    set ::main_trace_update_count_final($hardware_name) $update_count
    set ::main_trace_last_dref($hardware_name) $dref
    set ::main_trace_last_dout($hardware_name) $dout
    set ::main_trace_last_error($hardware_name) $freq_error
    set ::main_trace_last_prelock($hardware_name) $prelock_error
    set ::main_trace_last_unclamped($hardware_name) $pi_unclamped
    set ::main_trace_last_output($hardware_name) $pi_output
    set ::main_trace_last_clamp_side($hardware_name) $clamp_side
    set ::main_trace_last_kp($hardware_name) $kp
    set ::main_trace_last_ki($hardware_name) $ki
    set ::main_trace_last_shift($hardware_name) $shift
    set ::main_trace_last_bias($hardware_name) $bias
    set ::main_trace_last_threshold($hardware_name) $threshold
    set ::main_trace_last_lock_samples($hardware_name) $lock_samples
    set ::main_trace_last_ymin($hardware_name) $y_min
    set ::main_trace_last_ymax($hardware_name) $y_max
    set ::main_trace_last_anti_windup($hardware_name) $anti_windup
    set ::main_trace_last_x($hardware_name) $pi_x
  } else {
    set main_enabled INVALID
    set main_freq_locked INVALID
    set main_phase_locked INVALID
    set main_locked INVALID
  }
  if {$helper_locked ne "INVALID"} {
    if {$helper_locked} { set ::helper_locked_ever($hardware_name) 1 }
    set ::helper_locked_final($hardware_name) $helper_locked
  }
  if {$helper_lock_count ne "INVALID"} {
    if {$helper_lock_count > $::helper_lock_count_max($hardware_name)} {
      set ::helper_lock_count_max($hardware_name) $helper_lock_count
    }
    set ::helper_lock_count_final($hardware_name) $helper_lock_count
  }
  if {$pstat_locked ne "INVALID"} {
    if {$pstat_locked} { set ::pstat_locked_ever($hardware_name) 1 }
    set ::pstat_locked_final($hardware_name) $pstat_locked
  }

  puts [format "STEP5_MAIN_FREQ_SAMPLE board=%s sample=%d elapsed_ms=%d FRAME_VALID=%d MAIN_TRACE_VALID=%d MAIN_TRACE_EPOCH_BEFORE_RAW=%s MAIN_TRACE_EPOCH_AFTER_RAW=%s MAIN_TRACE_MAGIC_RAW=%s MAIN_TRACE_MAGIC=%s MAIN_DREF_DT=%s MAIN_DOUT_DT=%s MAIN_FREQ_ERROR=%s MAIN_PRELOCK_ERROR=%s MAIN_PI_UNCLAMPED=%s MAIN_PI_OUTPUT=%s MAIN_PI_CLAMP_SIDE=%s MAIN_FREQ_LOCK_COUNT=%s MAIN_FREQ_LOCK_COUNT_MAX=%s MAIN_PI_KP=%s MAIN_PI_KI=%s MAIN_PI_SHIFT=%s MAIN_PI_BIAS=%s MAIN_PI_UPDATE_COUNT=%s MAIN_FREQ_THRESHOLD=%s MAIN_FREQ_LOCK_SAMPLES=%s MAIN_STATE=%s MAIN_PI_Y_MIN=%s MAIN_PI_Y_MAX=%s MAIN_PI_ANTI_WINDUP=%s MAIN_PI_X=%s MAIN_ENABLED=%s MAIN_FREQ_LOCKED=%s MAIN_PHASE_LOCKED=%s MAIN_LOCKED=%s HELPER_LOCKED=%s HELPER_LOCK_COUNT=%s HELPER_THRESHOLD=%s HELPER_LOCK_SAMPLES=%s PSTAT_LOCKED=%s SPLL_DELOCK_COUNT=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
    $hardware_name $sample $elapsed_ms $frame_ok $trace_ok $::main_trace_epoch_before_raw($hardware_name) $::main_trace_epoch_after_raw($hardware_name) $::main_trace_magic_raw($hardware_name) $magic $dref $dout $freq_error $prelock_error $pi_unclamped $pi_output $clamp_side $lock_count $lock_count_max $kp $ki $shift $bias $update_count $threshold $lock_samples $state $y_min $y_max $anti_windup $pi_x $main_enabled $main_freq_locked $main_phase_locked $main_locked $helper_locked $helper_lock_count $helper_threshold $helper_lock_samples $pstat_locked $spll_delock $entry_generation $cpu_reset $wr_reset $si_drop]
  flush stdout
}

proc emit_summary {hardware_name} {
  set freq_mean INVALID
  set freq_rms INVALID
  set freq_max_abs INVALID
  set freq_band_fraction INVALID
  if {$::freq_count($hardware_name) > 0} {
    set freq_mean [expr {$::freq_sum($hardware_name) / double($::freq_count($hardware_name))}]
    set freq_rms [expr {sqrt($::freq_sumsq($hardware_name) / double($::freq_count($hardware_name)))}]
    set freq_max_abs $::freq_max_abs($hardware_name)
    set freq_band_fraction [expr {double($::freq_band_count($hardware_name)) / double($::freq_count($hardware_name))}]
  }
  set pi_low_fraction INVALID
  set pi_high_fraction INVALID
  set pi_no_rail_fraction INVALID
  if {$::pi_count($hardware_name) > 0} {
    set den [expr {double($::pi_count($hardware_name))}]
    set pi_low_fraction [expr {double($::pi_low_rail_count($hardware_name)) / $den}]
    set pi_high_fraction [expr {double($::pi_high_rail_count($hardware_name)) / $den}]
    set pi_no_rail_fraction [expr {double($::pi_no_rail_count($hardware_name)) / $den}]
  }
  foreach {gen0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {gen1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  set reset_result [expr {$gen0 ne "INVALID" && $gen1 ne "INVALID" &&
    $cpu0 ne "INVALID" && $cpu1 ne "INVALID" &&
    $wr0 ne "INVALID" && $wr1 ne "INVALID" &&
    $si0 ne "INVALID" && $si1 ne "INVALID" &&
    $gen0 == $gen1 && $cpu0 == $cpu1 && $wr0 == $wr1 && $si0 == $si1 ? "PASS" : "INCONCLUSIVE"}]
  set telemetry_result [expr {$::trace_valid_count($hardware_name) > 0 &&
    $::measurement_failures($hardware_name) == 0 &&
    $::prelock_mismatch_count($hardware_name) == 0 &&
    $::main_trace_magic_final($hardware_name) == 1 ? "PASS" : "FAIL"}]
  puts [format "STEP5_MAIN_FREQ_PRELOCK_SUMMARY board=%s SAMPLES=%d ELAPSED_MS=%d TRACE_VALID=%d FRAME_VALID=%d INVALID=%d FREQ_ERROR_SAMPLES=%d FREQ_ERROR_MEAN=%s FREQ_ERROR_RMS=%s FREQ_ERROR_MIN=%s FREQ_ERROR_MAX=%s FREQ_ERROR_MAX_ABS=%s FREQ_ERROR_FIRST=%s FREQ_ERROR_FINAL=%s FRACTION_ABS_FREQ_ERROR_LE_50=%s PRELOCK_ERROR_MISMATCHES=%d MEASUREMENT_FAILS=%d PI_SAMPLES=%d PI_LOW_RAIL_FRACTION=%s PI_HIGH_RAIL_FRACTION=%s PI_NO_RAIL_FRACTION=%s MAIN_FREQ_LOCK_COUNT_MAX_SEEN=%s MAIN_FREQ_LOCK_COUNT_FINAL=%s MAIN_FREQ_LOCK_COUNT_MAX_FINAL=%s MAIN_FREQ_LOCKED_EVER=%d MAIN_FREQ_LOCKED_FINAL=%s MAIN_PHASE_LOCKED_EVER=%d MAIN_PHASE_LOCKED_FINAL=%s MAIN_LOCKED_EVER=%d MAIN_LOCKED_FINAL=%s MAIN_ENABLED_FINAL=%s HELPER_LOCKED_EVER=%d HELPER_LOCKED_FINAL=%s HELPER_LOCK_COUNT_MAX=%s HELPER_LOCK_COUNT_FINAL=%s PSTAT_LOCKED_EVER=%d PSTAT_LOCKED_FINAL=%s SPLL_DELOCK_FIRST=%s SPLL_DELOCK_MAX=%s SPLL_DELOCK_FINAL=%s RESET_STABLE=%s BOOT_GENERATION_FIRST=%s BOOT_GENERATION_FINAL=%s MAIN_DREF_DT_FINAL=%s MAIN_DOUT_DT_FINAL=%s MAIN_FREQ_ERROR_FINAL=%s MAIN_PRELOCK_ERROR_FINAL=%s MAIN_PI_UNCLAMPED_FINAL=%s MAIN_PI_OUTPUT_FINAL=%s MAIN_PI_CLAMP_SIDE_FINAL=%s MAIN_PI_KP_FINAL=%s MAIN_PI_KI_FINAL=%s MAIN_PI_SHIFT_FINAL=%s MAIN_PI_BIAS_FINAL=%s MAIN_PI_UPDATE_COUNT_FINAL=%s MAIN_FREQ_THRESHOLD_FINAL=%s MAIN_FREQ_LOCK_SAMPLES_FINAL=%s MAIN_PI_Y_MIN_FINAL=%s MAIN_PI_Y_MAX_FINAL=%s MAIN_PI_ANTI_WINDUP_FINAL=%s MAIN_PI_X_FINAL=%s TELEMETRY_RESULT=%s STEP5_COMPLETE=NO MERGE_APPROVED=NO" \
    $hardware_name $::sample_count($hardware_name) $::elapsed_final($hardware_name) $::trace_valid_count($hardware_name) $::frame_valid_count($hardware_name) $::invalid_count($hardware_name) $::freq_count($hardware_name) $freq_mean $freq_rms $::freq_min($hardware_name) $::freq_max($hardware_name) $freq_max_abs $::freq_first($hardware_name) $::freq_last($hardware_name) $freq_band_fraction $::prelock_mismatch_count($hardware_name) $::measurement_failures($hardware_name) $::pi_count($hardware_name) $pi_low_fraction $pi_high_fraction $pi_no_rail_fraction $::main_freq_lock_count_max_seen($hardware_name) $::main_freq_lock_count_final($hardware_name) $::main_freq_lock_count_max_final($hardware_name) $::main_freq_locked_ever($hardware_name) $::main_freq_locked_final($hardware_name) $::main_phase_locked_ever($hardware_name) $::main_phase_locked_final($hardware_name) $::main_locked_ever($hardware_name) $::main_locked_final($hardware_name) $::main_enabled_final($hardware_name) $::helper_locked_ever($hardware_name) $::helper_locked_final($hardware_name) $::helper_lock_count_max($hardware_name) $::helper_lock_count_final($hardware_name) $::pstat_locked_ever($hardware_name) $::pstat_locked_final($hardware_name) $::spll_delock_first($hardware_name) $::spll_delock_max($hardware_name) $::spll_delock_final($hardware_name) $reset_result $::entry_generation_first($hardware_name) $::entry_generation_final($hardware_name) $::main_trace_last_dref($hardware_name) $::main_trace_last_dout($hardware_name) $::main_trace_last_error($hardware_name) $::main_trace_last_prelock($hardware_name) $::main_trace_last_unclamped($hardware_name) $::main_trace_last_output($hardware_name) $::main_trace_last_clamp_side($hardware_name) $::main_trace_last_kp($hardware_name) $::main_trace_last_ki($hardware_name) $::main_trace_last_shift($hardware_name) $::main_trace_last_bias($hardware_name) $::main_trace_update_count_final($hardware_name) $::main_trace_last_threshold($hardware_name) $::main_trace_last_lock_samples($hardware_name) $::main_trace_last_ymin($hardware_name) $::main_trace_last_ymax($hardware_name) $::main_trace_last_anti_windup($hardware_name) $::main_trace_last_x($hardware_name) $telemetry_result]
  flush stdout
}

puts [format "STEP5_MAIN_FREQ_PRELOCK_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-6208-16-KP-MINUS300-KI-MINUS1-LANE2-MAIN-FREQUENCY-PRELOCK-OBSERVABILITY-600S-20260902 read_only_observer=1 bootstrap_steps=6208 code_per_physical_step=16 kp=-300 ki=-1 shift=12 bias=5 helper_threshold=200 helper_lock_samples=10000 normal_tracker=1 main_prelock_gain_boost=20 freq_lock_threshold=50 freq_lock_samples=50 overlay_epoch=0x00100B58 overlay=0x00100B5C..0x00100BAC overlay_magic=0x00100BDC cadence_ms=%d" $samples $gap_ms $board_filter $gap_ms]

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== STEP5_MAIN_FREQ_PRELOCK_BOARD %s ===" $hardware_name]
  flush stdout
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set deadline [expr {$start_ms + (($sample - 1) * $gap_ms)}]
      set now [clock milliseconds]
      if {$now < $deadline} { after [expr {$deadline - $now}] }
      emit_sample $hardware_name $sample [expr {[clock milliseconds] - $start_ms}]
    }
    set ::elapsed_final($hardware_name) [expr {[clock milliseconds] - $start_ms}]
    emit_summary $hardware_name
  } error_message]} {
    puts [format "STEP5_MAIN_FREQ_PRELOCK_ERROR board=%s message=%s error_info=%s" $hardware_name $error_message [string map [list "\n" " | "] $::errorInfo]]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_MAIN_FREQ_PRELOCK_DONE"
