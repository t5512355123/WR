# White Rabbit Step5 F4C Main phase-service cause-audit observer.
#
# The `acquisition` run role below is the F4E read-only acquisition-window
# diagnostic.  It shares the established mailbox reader with F4C and never
# changes firmware/RTL control behaviour.
#
# This script is read-only.  It correlates the existing Main trace, the
# coherent Helper measurement, the stable DCO/accounting probes, and the
# producer-side L2 telemetry.  It does not request a Helper PI snapshot, write
# WR configuration, drain the SoftPLL debug FIFO, or alter the HPLL/DCO
# controller.
#
# Usage:
#   quartus_stp -t read_step5_main_frequency_prelock_observability.tcl \
#     ?samples? ?gap_ms? ?board_filter? ?target_duration_ms? \
#     ?hard_duration_ms? ?run_role?
#
# A legacy run is capped by actual wall-clock time below.  The acquisition run
# role uses its own bounded two-board scheduler and does not apply the legacy
# five-sample readiness gate.

package require ::quartus::insystem_source_probe

set samples 2400
set gap_ms 100
set board_filter ""
set poll_attempts 100
set smoke_samples 5
set target_duration_ms 0
set hard_duration_ms 240000
set run_role "legacy"
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {[llength $argv] >= 4} { set target_duration_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set hard_duration_ms [expr {int([lindex $argv 4])}] }
if {[llength $argv] >= 6} { set run_role [string tolower [lindex $argv 5]] }
if {$samples <= 0 || $gap_ms < 0 || $target_duration_ms < 0 ||
    $hard_duration_ms <= 0 ||
    ($target_duration_ms > 0 && $target_duration_ms > $hard_duration_ms) ||
    [lsearch -exact {legacy smoke long acquisition} $run_role] < 0} {
  error "samples must be > 0, gap_ms must be >= 0, durations must be valid, and run_role must be legacy, smoke, long, or acquisition"
}

array set ::wb_toggle {}
array set ::sample_count {}
array set ::trace_valid_count {}
array set ::trace_unique_count {}
array set ::trace_dedup_skipped {}
array set ::last_counted_trace_key {}
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
array set ::main_enabled_count {}
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
array set ::main_trace_payload_debug {}
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
array set ::main_detector_valid_count {}
array set ::main_detector_stable_count {}
array set ::main_phase_lock_count_max_seen {}
array set ::main_phase_lock_count_final {}
array set ::main_phase_threshold_final {}
array set ::main_phase_lock_samples_final {}
array set ::main_detector_enabled_final {}
array set ::main_detector_freq_locked_final {}
array set ::main_detector_phase_locked_final {}
array set ::main_detector_locked_final {}
array set ::main_sample_n_delta_sum {}
array set ::main_sample_n_delta_count {}
array set ::main_sample_n_delta_ambiguous {}
array set ::main_core_valid_count {}
array set ::main_core_invalid_streak {}
array set ::main_core_invalid_max_streak {}
array set ::main_phase_inband_count {}
array set ::main_phase_outband_count {}
array set ::main_phase_domain_count {}
array set ::main_last_progress_elapsed_ms {}
array set ::main_max_stall_ms {}
array set ::main_stall_samples {}
array set ::helper_unlock_streak {}
array set ::helper_rail_streak {}
array set ::transport_gate_valid {}
array set ::health_next_ms {}
array set ::run_end_reason {}
array set ::elapsed_final {}

# F4E acquisition-mode state.  These arrays deliberately keep entry,
# producer-progress, protection, and stop state separate from the legacy F4C
# summary counters.  A single Tcl process interleaves both targets; it never
# starts a second reader.
array set ::f4e_role {}
array set ::f4e_sample_count {}
array set ::f4e_entry_seen {}
array set ::f4e_entry_sample {}
array set ::f4e_entry_elapsed_ms {}
array set ::f4e_entry_update_count {}
array set ::f4e_last_update_count {}
array set ::f4e_last_update_elapsed_ms {}
array set ::f4e_last_main_core_elapsed_ms {}
array set ::f4e_main_progress_samples {}
array set ::f4e_main_core_valid_samples {}
array set ::f4e_acquisition_allowed_samples {}
array set ::f4e_phase_domain_samples {}
array set ::f4e_phase_inband_samples {}
array set ::f4e_helper_unlock_streak {}
array set ::f4e_helper_rail_streak {}
array set ::f4e_freq_unlock_streak {}
array set ::f4e_terminal_streak {}
array set ::f4e_transport_error_streak {}
array set ::f4e_generation_baseline {}
array set ::f4e_cpu_reset_baseline {}
array set ::f4e_wr_reset_baseline {}
array set ::f4e_si_drop_baseline {}
array set ::f4e_stop_reason {}
array set ::f4e_run_end_reason {}
array set ::f4e_first_ms {}
array set ::f4e_last_ms {}
set ::f4e_global_stop_reason NONE
set ::f4e_session_start_ms 0
set ::f4e_session_end_ms 0

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

proc counter_delta {first last width} {
  if {$first eq "INVALID" || $last eq "INVALID" ||
      ![string is integer -strict $first] || ![string is integer -strict $last]} {
    return INVALID
  }
  set modulus [expr {1 << $width}]
  if {$last >= $first} { return [expr {$last - $first}] }
  return [expr {$last + $modulus - $first}]
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

# The mailbox is a bundled CDC boundary.  Keep the completed toggle while
# preloading the address, then commit the request by changing only the toggle.
# A completion is accepted only after the done/active bits match and three
# consecutive reads expose the same 64-bit response.  This is the established
# runtime-reader protocol used by the F4D JTAG observer.
proc normalize_probe64 {value} {
  if {![is_hex $value]} { return $value }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  return [string repeat 0 [expr {16 - [string length $text]}]]$text
}

proc bit64_high {value bit} {
  set word [probe_high32 $value]
  if {$word eq "INVALID"} { return INVALID }
  return [expr {($word >> $bit) & 1}]
}

proc stale_jtag_word {value} {
  set word [word32 $value]
  if {$word < 0} { return 0 }
  return [expr {(($word >> 16) & 0xffff) == 0xA5A5}]
}

proc probe_equal64 {left right} {
  if {![is_hex $left] || ![is_hex $right]} { return 0 }
  return [expr {[normalize_probe64 $left] eq [normalize_probe64 $right]}]
}

proc completion_probe_valid {value expected_toggle} {
  if {![is_hex $value] || [stale_jtag_word $value]} { return 0 }
  set done_toggle [bit64_high $value 3]
  set active [bit64_high $value 4]
  return [expr {$done_toggle eq $expected_toggle && $active == 0}]
}

proc safe_probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc mailbox_read {hardware_name addr} {
  set preload_toggle $::wb_toggle($hardware_name)
  set preload_cmd [expr {$preload_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $preload_cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 2

  # Commit by changing only the toggle.  The preload response is not a
  # completion because it may still expose the previous transaction.
  set ::wb_toggle($hardware_name) [expr {($preload_toggle ^ 1) & 1}]
  set expected_toggle $::wb_toggle($hardware_name)
  set cmd [expr {$expected_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }

  after 5
  set first_completion ""
  for {set n 0} {$n < 100} {incr n} {
    set value [safe_probe_read 1]
    if {[completion_probe_valid $value $expected_toggle]} {
      set first_completion $value
      break
    }
    after 1
  }
  if {$first_completion eq ""} { return TIMEOUT }

  # Reject the done-toggle/new-data visibility race at the JTAG boundary.
  for {set attempt 1} {$attempt <= 10} {incr attempt} {
    set p1 [safe_probe_read 1]
    after 1
    set p2 [safe_probe_read 1]
    after 1
    set p3 [safe_probe_read 1]
    if {[completion_probe_valid $p1 $expected_toggle] &&
        [completion_probe_valid $p2 $expected_toggle] &&
        [completion_probe_valid $p3 $expected_toggle] &&
        [probe_equal64 $p1 $p2] && [probe_equal64 $p2 $p3]} {
      return [format %08X [word32 $p3]]
    }
    after 1
  }
  return TIMEOUT
}

proc wb_read {hardware_name addr} {
  return [mailbox_read $hardware_name $addr]
}

proc wb_sync_toggle {hardware_name} {
  set value [safe_probe_read 1]
  if {[is_hex $value]} {
    set toggle [bit64_high $value 3]
    if {$toggle ne "INVALID"} {
      set ::wb_toggle($hardware_name) $toggle
    } else {
      set ::wb_toggle($hardware_name) 0
    }
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

proc selected_board {hardware_name} {
  if {$::board_filter eq ""} { return 1 }
  return [expr {[string first $::board_filter $hardware_name] >= 0}]
}

proc read_main_trace {hardware_name} {
  # CPU addresses are BASE_WDIAGS_PRIV + offsets 0x158..0x1ac and 0x1dc.
  # The compact core group is the causal unit used for correlation.  The
  # previous all-fields read could never become coherent on a live image
  # because the publisher advanced the epoch while the 23-word read was in
  # flight. Optional fields remain visible but are not claimed to be from the
  # same publication.
  for {set attempt 0} {$attempt < 8} {incr attempt} {
    set epoch_before_raw [wb_read $hardware_name 0x00100B58]
    set ::main_trace_epoch_before_raw($hardware_name) $epoch_before_raw
    set epoch_before [word32 $epoch_before_raw]
    if {$epoch_before < 0 || ($epoch_before & 1)} { after 1; continue }
    set freq_error [signed32 [wb_read $hardware_name 0x00100B64]]
    set pi_output [signed32 [wb_read $hardware_name 0x00100B70]]
    set clamp_side [signed32 [wb_read $hardware_name 0x00100B74]]
    set update_count [word32 [wb_read $hardware_name 0x00100B90]]
    set state [word32 [wb_read $hardware_name 0x00100B9C]]
    set pi_x [signed32 [wb_read $hardware_name 0x00100BAC]]
    set epoch_after_raw [wb_read $hardware_name 0x00100B58]
    set ::main_trace_epoch_after_raw($hardware_name) $epoch_after_raw
    set epoch_after [word32 $epoch_after_raw]
    set dref [signed32 [wb_read $hardware_name 0x00100B5C]]
    set dout [signed32 [wb_read $hardware_name 0x00100B60]]
    set prelock_error [signed32 [wb_read $hardware_name 0x00100B68]]
    set pi_unclamped [signed32 [wb_read $hardware_name 0x00100B6C]]
    set lock_count [word32 [wb_read $hardware_name 0x00100B78]]
    set lock_count_max [word32 [wb_read $hardware_name 0x00100B7C]]
    set kp [signed32 [wb_read $hardware_name 0x00100B80]]
    set ki [signed32 [wb_read $hardware_name 0x00100B84]]
    set shift [signed32 [wb_read $hardware_name 0x00100B88]]
    set bias [signed32 [wb_read $hardware_name 0x00100B8C]]
    set threshold [word32 [wb_read $hardware_name 0x00100B94]]
    set lock_samples [word32 [wb_read $hardware_name 0x00100B98]]
    set y_min [signed32 [wb_read $hardware_name 0x00100BA0]]
    set y_max [signed32 [wb_read $hardware_name 0x00100BA4]]
    set anti_windup [signed32 [wb_read $hardware_name 0x00100BA8]]
    set magic_raw [wb_read $hardware_name 0x00100BDC]
    set ::main_trace_magic_raw($hardware_name) $magic_raw
    set magic [word32 $magic_raw]
    set ::main_trace_payload_debug($hardware_name) [list \
      $dref $dout $freq_error $prelock_error $pi_unclamped $pi_output \
      $clamp_side $lock_count $lock_count_max $kp $ki $shift $bias \
      $update_count $threshold $lock_samples $state $y_min $y_max \
      $anti_windup $pi_x]
    if {$epoch_before == $epoch_after && $epoch_after >= 0 &&
        !($epoch_after & 1) && $freq_error ne "INVALID" &&
        $pi_output ne "INVALID" && $clamp_side ne "INVALID" &&
        $update_count ne "INVALID" && $state ne "INVALID" &&
        $pi_x ne "INVALID"} {
      return [list 1 $epoch_after $dref $dout $freq_error $prelock_error \
        $pi_unclamped $pi_output $clamp_side $lock_count $lock_count_max \
        $kp $ki $shift $bias $update_count $threshold $lock_samples $state \
        $y_min $y_max $anti_windup $pi_x $magic]
    }
    after 1
  }
  return [concat [list 0] [lrepeat 23 INVALID]]
}

proc read_main_detector_block {hardware_name} {
  # These are the existing producer-side WDIAGS shadows written by the
  # diagnostics task.  State and both limit words are read twice so an
  # update during the small group read is reported as unstable rather than
  # silently combined with the limits from another publication.  This is not advertised as a
  # single-cycle snapshot; the Main trace's own epoch remains the causal
  # producer identity.
  set state_before [wb_read $hardware_name 0x00100AC4]
  set limits_before [wb_read $hardware_name 0x00100AC8]
  set phase_limits_before [wb_read $hardware_name 0x00100ACC]
  set state_after [wb_read $hardware_name 0x00100AC4]
  set limits_after [wb_read $hardware_name 0x00100AC8]
  set phase_limits_after [wb_read $hardware_name 0x00100ACC]
  set valid 1
  foreach value [list $state_before $limits_before $phase_limits_before \
      $state_after $limits_after $phase_limits_after] {
    if {![is_hex $value]} { set valid 0 }
  }
  set stable [expr {$valid &&
    [string equal -nocase $state_before $state_after] &&
    [string equal -nocase $limits_before $limits_after] &&
    [string equal -nocase $phase_limits_before $phase_limits_after] ? 1 : 0}]
  if {!$valid} {
    return [list 0 0 $state_before $limits_before $phase_limits_before \
      INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
  }
  set state $state_after
  set limits $limits_after
  set phase_limits $phase_limits_after
  set main_enabled [field32 $state 0 1]
  set main_locked [field32 $state 1 1]
  set main_freq_locked [field32 $state 2 1]
  set main_phase_locked [field32 $state 3 1]
  set main_freq_lock_count [field32 $state 8 12]
  set main_phase_lock_count [field32 $state 20 12]
  set main_freq_threshold [field32 $limits 0 16]
  set main_freq_lock_samples [field32 $limits 16 16]
  set main_phase_threshold [field32 $phase_limits 0 16]
  set main_phase_lock_samples [field32 $phase_limits 16 16]
  return [list 1 $stable $state $limits $phase_limits \
    $main_enabled $main_locked $main_freq_locked $main_phase_locked \
    $main_freq_lock_count $main_phase_lock_count $main_freq_threshold \
    $main_freq_lock_samples $main_phase_threshold $main_phase_lock_samples]
}

proc read_helper_pair {hardware_name} {
  set state [wb_read $hardware_name 0x00100ABC]
  set limits [wb_read $hardware_name 0x00100AC0]
  return [list $state $limits]
}

proc low32_64 {value} {
  set word [word64 $value]
  if {$word < 0} { return INVALID }
  return [expr {$word & 0xffffffff}]
}

proc high32_64 {value} {
  set word [word64 $value]
  if {$word < 0} { return INVALID }
  return [expr {($word >> 32) & 0xffffffff}]
}

proc field64 {value low width} {
  set word [word64 $value]
  if {$word < 0} { return INVALID }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($word >> $low) & $mask}]
}

proc read_helper_measurement {hardware_name} {
  # Existing coherent WDIAGS measurement, reused without triggering any
  # snapshot.  Epoch is odd while task-diags publishes and even afterwards.
  for {set attempt 0} {$attempt < 8} {incr attempt} {
    set epoch_before_raw [wb_read $hardware_name 0x00100B00]
    set epoch_before [word32 $epoch_before_raw]
    if {$epoch_before < 0 || ($epoch_before & 1)} { after 1; continue }
    set tag [signed32 [wb_read $hardware_name 0x00100B04]]
    set expected [signed32 [wb_read $hardware_name 0x00100B08]]
    set freq_error [signed32 [wb_read $hardware_name 0x00100B0C]]
    set preclamp [signed32 [wb_read $hardware_name 0x00100B10]]
    set helper_error [signed32 [wb_read $hardware_name 0x00100B14]]
    set update_count [word32 [wb_read $hardware_name 0x00100B18]]
    set helper_output [signed32 [wb_read $hardware_name 0x00100B1C]]
    set ref_accept [word32 [wb_read $hardware_name 0x00100B20]]
    set fb_accept [word32 [wb_read $hardware_name 0x00100B24]]
    set epoch_after_raw [wb_read $hardware_name 0x00100B00]
    set epoch_after [word32 $epoch_after_raw]
    if {$epoch_before == $epoch_after && $epoch_after >= 0 &&
        !($epoch_after & 1) && $tag ne "INVALID" &&
        $expected ne "INVALID" && $freq_error ne "INVALID" &&
        $freq_error == ($tag - $expected) && $helper_error ne "INVALID" &&
        $helper_output ne "INVALID" && $helper_output >= 5 &&
        $helper_output <= 65531 && $update_count ne "INVALID" &&
        $ref_accept ne "INVALID" && $fb_accept ne "INVALID"} {
      return [list 1 $epoch_before_raw $epoch_after_raw $epoch_after $tag \
        $expected $freq_error $preclamp $helper_error $update_count \
        $helper_output $ref_accept $fb_accept]
    }
    after 1
  }
  return [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID INVALID]
}

proc read_position_observability {} {
  # Exact existing packing: probe 43 = target/applied/normal FINC/FDEC;
  # probe 44 = completed counters plus epoch; probe 42 = upper applied bits
  # and bootstrap state; probe 49 = forced FINC/FDEC counters.  The unchanged
  # probe-44 epoch brackets the complete read group.
  for {set attempt 0} {$attempt < 10} {incr attempt} {
    set accounting_before_raw [probe_read 44]
    set position_raw [probe_read 43]
    set bootstrap_raw [probe_read 42]
    set actuator_raw [probe_read 49]
    set accounting_after_raw [probe_read 44]
    set accounting_before [word64 $accounting_before_raw]
    set accounting_after [word64 $accounting_after_raw]
    set position_word [word64 $position_raw]
    set bootstrap_word [word64 $bootstrap_raw]
    set actuator_word [word64 $actuator_raw]
    if {$accounting_before >= 0 && $accounting_after >= 0 &&
        $position_word >= 0 && $bootstrap_word >= 0 && $actuator_word >= 0 &&
        [string equal -nocase $accounting_before_raw $accounting_after_raw]} {
      set target [expr {$position_word & 0xffff}]
      set applied_low [expr {($position_word >> 16) & 0xffff}]
      set applied_high [expr {($bootstrap_word >> 37) & 0xffff}]
      set applied_bits [expr {(($applied_high << 16) | $applied_low) & 0xffffffff}]
      set applied [signed32 [format %08X $applied_bits]]
      set finc [expr {($position_word >> 32) & 0xffff}]
      set fdec [expr {($position_word >> 48) & 0xffff}]
      set normal_done [expr {$accounting_after & 0xffff}]
      set dco_step [expr {($accounting_after >> 16) & 0xffff}]
      set bootstrap_completed [expr {($accounting_after >> 32) & 0xffff}]
      set epoch [expr {($accounting_after >> 48) & 0xffff}]
      set bootstrap_done [expr {($bootstrap_word >> 33) & 1}]
      set forced_finc [expr {$actuator_word & 0xffff}]
      set forced_fdec [expr {($actuator_word >> 16) & 0xffff}]
      return [list 1 $accounting_before_raw $accounting_after_raw $position_raw \
        $bootstrap_raw $actuator_raw $epoch $target $applied $finc $fdec \
        $normal_done $dco_step $bootstrap_completed $bootstrap_done \
        $forced_finc $forced_fdec]
    }
    after 1
  }
  return [concat [list 0] [lrepeat 16 INVALID]]
}

proc read_l2_observability {} {
  # Probes 52..61 are the existing producer-side packed telemetry.  Their raw
  # 64-bit values are retained in the sample line; decoded fields below use
  # the established packing from read_step5_first_loss_telemetry.tcl.
  set status_raw [probe_read 52]
  set pending_raw [probe_read 53]
  set service_start_raw [probe_read 54]
  set completed_raw [probe_read 55]
  set failed_raw [probe_read 56]
  set max_wait_raw [probe_read 57]
  set current_wait_raw [probe_read 58]
  set latency_raw [probe_read 59]
  set failure_raw [probe_read 60]
  set first_loss_raw [probe_read 61]
  set raw_values [list $status_raw $pending_raw $service_start_raw $completed_raw \
    $failed_raw $max_wait_raw $current_wait_raw $latency_raw $failure_raw $first_loss_raw]
  set valid 1
  foreach value $raw_values { if {![is_hex $value]} { set valid 0 } }
  if {!$valid} { return [concat [list 0] $raw_values [lrepeat 30 INVALID]] }

  set status_first_loss [field64 $status_raw 6 1]
  set status_main_pending [field64 $status_raw 0 1]
  set status_helper_pending [field64 $status_raw 1 1]
  set status_tx_active [field64 $status_raw 2 1]
  set status_owner_main [field64 $status_raw 3 1]
  set status_ack [field64 $status_raw 4 1]
  set status_timeout [field64 $status_raw 5 1]
  set status_dco_error [field64 $status_raw 7 1]
  set status_reason [field64 $status_raw 8 8]
  set status_rt_state [field64 $status_raw 16 3]
  set status_time [high32_64 $status_raw]
  set main_pending_count [low32_64 $pending_raw]
  set helper_pending_count [high32_64 $pending_raw]
  set main_start_count [low32_64 $service_start_raw]
  set helper_start_count [high32_64 $service_start_raw]
  set main_completed_count [low32_64 $completed_raw]
  set helper_completed_count [high32_64 $completed_raw]
  set main_failed_count [low32_64 $failed_raw]
  set helper_failed_count [high32_64 $failed_raw]
  set main_max_wait [low32_64 $max_wait_raw]
  set helper_max_wait [high32_64 $max_wait_raw]
  set main_current_wait [low32_64 $current_wait_raw]
  set helper_current_wait [high32_64 $current_wait_raw]
  set main_max_latency [low32_64 $latency_raw]
  set helper_max_latency [high32_64 $latency_raw]
  set ack_events [low32_64 $failure_raw]
  set timeout_events [high32_64 $failure_raw]
  set first_loss_time [low32_64 $first_loss_raw]
  set first_loss_owner [field64 $first_loss_raw 32 2]
  set first_loss_reason [field64 $first_loss_raw 34 8]
  set decoded [list $status_first_loss $status_main_pending $status_helper_pending \
    $status_tx_active $status_owner_main $status_ack $status_timeout \
    $status_dco_error $status_reason $status_rt_state $status_time \
    $main_pending_count $helper_pending_count $main_start_count \
    $helper_start_count $main_completed_count $helper_completed_count \
    $main_failed_count $helper_failed_count $main_max_wait $helper_max_wait \
    $main_current_wait $helper_current_wait $main_max_latency \
    $helper_max_latency $ack_events $timeout_events $first_loss_time \
    $first_loss_owner $first_loss_reason]
  return [concat [list 1] $raw_values $decoded]
}

proc initialize_demand_observation {hardware_name} {
  set ::obs_main_trace_prev_update($hardware_name) INVALID
  set ::obs_main_trace_update_progress($hardware_name) 0
  set ::obs_measurement_valid($hardware_name) 0
  set ::obs_position_valid($hardware_name) 0
  set ::obs_l2_valid($hardware_name) 0
  set ::obs_invalid_streak($hardware_name) 0
  set ::obs_stop_reason($hardware_name) NONE
  set ::obs_smoke_valid($hardware_name) 0
  set ::obs_generation_baseline($hardware_name) INVALID
  set ::obs_cpu_reset_baseline($hardware_name) INVALID
  set ::obs_wr_reset_baseline($hardware_name) INVALID
  set ::obs_si_drop_baseline($hardware_name) INVALID
  set ::obs_correlation_samples($hardware_name) 0
  set ::obs_helper_residual_samples($hardware_name) 0
  set ::obs_helper_pending_samples($hardware_name) 0
  set ::obs_residual_without_pending($hardware_name) 0
  set ::obs_residual_without_pending_and_main_progress($hardware_name) 0
  set ::obs_helper_unlock_samples($hardware_name) 0
  set ::obs_helper_unlock_main_stalled($hardware_name) 0
  set ::obs_helper_unlock_main_stalled_freq_stale($hardware_name) 0
  set ::obs_main_progress_samples($hardware_name) 0
  set ::obs_main_update_first($hardware_name) INVALID
  set ::obs_main_update_final($hardware_name) INVALID
  set ::obs_helper_completed_first($hardware_name) INVALID
  set ::obs_helper_completed_final($hardware_name) INVALID
  set ::obs_helper_pending_count_first($hardware_name) INVALID
  set ::obs_helper_pending_count_final($hardware_name) INVALID
  set ::obs_main_completed_first($hardware_name) INVALID
  set ::obs_main_completed_final($hardware_name) INVALID
  set ::main_sample_n_delta_sum($hardware_name) 0
  set ::main_sample_n_delta_count($hardware_name) 0
  set ::main_sample_n_delta_ambiguous($hardware_name) 0
  set ::main_core_valid_count($hardware_name) 0
  set ::main_core_invalid_streak($hardware_name) 0
  set ::main_core_invalid_max_streak($hardware_name) 0
  set ::main_phase_inband_count($hardware_name) 0
  set ::main_phase_outband_count($hardware_name) 0
  set ::main_phase_domain_count($hardware_name) 0
  set ::main_last_progress_elapsed_ms($hardware_name) INVALID
  set ::main_max_stall_ms($hardware_name) 0
  set ::main_stall_samples($hardware_name) 0
  set ::helper_unlock_streak($hardware_name) 0
  set ::helper_rail_streak($hardware_name) 0
  set ::transport_gate_valid($hardware_name) 0
  set ::health_next_ms($hardware_name) 30000
  set ::obs_sample_first_ms($hardware_name) INVALID
  set ::obs_sample_final_ms($hardware_name) 0
}

proc initialize_board {hardware_name} {
  set ::sample_count($hardware_name) 0
  set ::trace_valid_count($hardware_name) 0
  set ::trace_unique_count($hardware_name) 0
  set ::trace_dedup_skipped($hardware_name) 0
  set ::last_counted_trace_key($hardware_name) ""
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
  set ::main_enabled_count($hardware_name) 0
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
  set ::main_trace_payload_debug($hardware_name) INVALID
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
  set ::main_detector_valid_count($hardware_name) 0
  set ::main_detector_stable_count($hardware_name) 0
  set ::main_phase_lock_count_max_seen($hardware_name) 0
  set ::main_phase_lock_count_final($hardware_name) INVALID
  set ::main_phase_threshold_final($hardware_name) INVALID
  set ::main_phase_lock_samples_final($hardware_name) INVALID
  set ::main_detector_enabled_final($hardware_name) INVALID
  set ::main_detector_freq_locked_final($hardware_name) INVALID
  set ::main_detector_phase_locked_final($hardware_name) INVALID
  set ::main_detector_locked_final($hardware_name) INVALID
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
  global run_role
  if {$sample == 1} {
    initialize_board $hardware_name
    initialize_demand_observation $hardware_name
    set ::obs_sample_first_ms($hardware_name) $elapsed_ms
  }
  incr ::sample_count($hardware_name)
  set ::obs_sample_final_ms($hardware_name) $elapsed_ms
  set ctrl_begin [wb_read $hardware_name 0x00100A04]
  set trace [read_main_trace $hardware_name]
  foreach {trace_ok epoch dref dout freq_error prelock_error pi_unclamped pi_output \
      clamp_side lock_count lock_count_max kp ki shift bias update_count threshold \
      lock_samples state y_min y_max anti_windup pi_x magic} $trace break
  if {$trace_ok} {
    set main_enabled [expr {($state >> 0) & 1}]
    set main_freq_locked [expr {($state >> 1) & 1}]
    set main_phase_locked [expr {($state >> 2) & 1}]
    set main_locked [expr {($state >> 3) & 1}]
  } else {
    set main_enabled INVALID
    set main_freq_locked INVALID
    set main_phase_locked INVALID
    set main_locked INVALID
  }
  set main_detector [read_main_detector_block $hardware_name]
  foreach {main_detector_ok main_detector_stable main_state_raw main_limits_raw \
      main_phase_limits_raw main_detector_enabled main_detector_locked \
      main_detector_freq_locked main_detector_phase_locked main_freq_lock_count \
      main_phase_lock_count main_freq_threshold main_freq_lock_samples \
      main_phase_threshold main_phase_lock_samples} $main_detector break
  # The trace state uses a historical packing.  For F4C's Main-state and
  # phase-domain claims, use the producer-side WDIAGS shadow above, whose
  # packing is enabled/locked/frequency/phase at bits 0/1/2/3.
  set main_obs_enabled $main_enabled
  set main_obs_locked $main_locked
  set main_obs_freq_locked $main_freq_locked
  set main_obs_phase_locked $main_phase_locked
  if {$main_detector_ok} {
    set main_obs_enabled $main_detector_enabled
    set main_obs_locked $main_detector_locked
    set main_obs_freq_locked $main_detector_freq_locked
    set main_obs_phase_locked $main_detector_phase_locked
  }
  set ctrl_end [wb_read $hardware_name 0x00100A04]
  set frame_ok [frame_valid $ctrl_begin $ctrl_end]
  if {$frame_ok} { incr ::frame_valid_count($hardware_name) }
  if {$trace_ok} { incr ::trace_valid_count($hardware_name) } else { incr ::invalid_count($hardware_name) }

  set trace_unique 0
  if {$trace_ok} {
    # The firmware publishes a coherent seqlock frame with the same epoch and
    # update_count until the next publication. Count each published frame once
    # so a slower diagnostic publication is not mistaken for controller samples.
    set trace_key [format "%s|%s" $epoch $update_count]
    if {$trace_key eq $::last_counted_trace_key($hardware_name)} {
      incr ::trace_dedup_skipped($hardware_name)
    } else {
      set ::last_counted_trace_key($hardware_name) $trace_key
      incr ::trace_unique_count($hardware_name)
      set trace_unique 1
    }
  }

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

  # Additional read-only correlation groups.  The three groups deliberately
  # retain their own validity so a cross-group read cannot be presented as a
  # single-cycle causal observation.
  set helper_measurement [read_helper_measurement $hardware_name]
  foreach {helper_measurement_ok helper_epoch_before_raw helper_epoch_after_raw \
      helper_epoch helper_tag helper_expected helper_freq_error helper_preclamp \
      helper_error helper_update_count helper_output helper_ref_accept \
      helper_fb_accept} $helper_measurement break
  set position_observation [read_position_observability]
  foreach {position_ok position_accounting_before_raw position_accounting_after_raw \
      position_raw bootstrap_raw actuator_raw position_epoch target applied finc \
      fdec normal_completed dco_step bootstrap_completed bootstrap_done forced_finc \
      forced_fdec} $position_observation break
  set tracker_raw [probe_read 39]
  set tracker_word [word64 $tracker_raw]
  set helper_normal_req [expr {$tracker_word < 0 ? "INVALID" : (($tracker_word >> 32) & 0xffff)}]
  set l2_observation [read_l2_observability]
  foreach {l2_ok l2_status_raw l2_pending_raw l2_service_start_raw \
      l2_completed_raw l2_failed_raw l2_max_wait_raw l2_current_wait_raw \
      l2_latency_raw l2_failure_raw l2_first_loss_raw l2_first_loss \
      l2_main_pending l2_helper_pending l2_tx_active l2_owner_main l2_ack \
      l2_timeout l2_dco_error l2_reason l2_rt_state l2_status_time \
      l2_main_pending_count l2_helper_pending_count l2_main_start_count \
      l2_helper_start_count l2_main_completed_count l2_helper_completed_count \
      l2_main_failed_count l2_helper_failed_count l2_main_max_wait \
      l2_helper_max_wait l2_main_current_wait l2_helper_current_wait \
      l2_main_max_latency l2_helper_max_latency l2_ack_events l2_timeout_events \
      l2_first_loss_time l2_first_loss_owner l2_first_loss_reason} $l2_observation break

  set helper_residual_present UNKNOWN
  if {$position_ok && $target ne "INVALID" && $applied ne "INVALID"} {
    set helper_residual_present [expr {$target != ($applied & 0xffff)}]
  }
  set helper_measurement_residual_present UNKNOWN
  if {$helper_measurement_ok && $helper_error ne "INVALID"} {
    set helper_measurement_residual_present [expr {abs($helper_error) > 200}]
  }
  set main_sample_n_delta INVALID
  set main_sample_n_delta_is_ambiguous 0
  set main_sample_n_advanced 0
  if {$trace_ok && $update_count ne "INVALID"} {
    if {$::obs_main_trace_prev_update($hardware_name) ne "INVALID"} {
      set main_sample_n_delta [counter_delta \
        $::obs_main_trace_prev_update($hardware_name) $update_count 32]
      if {$main_sample_n_delta ne "INVALID"} {
        # A 32-bit wrap is only credible when the observed delta is below
        # half the counter space.  A sudden zero/reset-like publication with
        # a huge modulo delta is ambiguous; retain the raw sample but do not
        # count it as Main progress.
        if {$main_sample_n_delta > 0x7fffffff} {
          set main_sample_n_delta_is_ambiguous 1
          set main_sample_n_delta INVALID
          incr ::main_sample_n_delta_ambiguous($hardware_name)
        } else {
          incr ::main_sample_n_delta_count($hardware_name)
          set ::main_sample_n_delta_sum($hardware_name) [expr {
            $::main_sample_n_delta_sum($hardware_name) + $main_sample_n_delta}]
          if {$main_sample_n_delta > 0} {
            set main_sample_n_advanced 1
            incr ::obs_main_trace_update_progress($hardware_name)
          }
        }
      } else {
        set main_sample_n_delta_is_ambiguous 1
        incr ::main_sample_n_delta_ambiguous($hardware_name)
      }
    }
    if {$::obs_main_update_first($hardware_name) eq "INVALID"} {
      set ::obs_main_update_first($hardware_name) $update_count
      if {$main_obs_enabled eq "1"} {
        set ::main_last_progress_elapsed_ms($hardware_name) $elapsed_ms
      }
    }
    set ::obs_main_update_final($hardware_name) $update_count
    set ::obs_main_trace_prev_update($hardware_name) $update_count
  }
  if {$trace_ok && $update_count ne "INVALID" && $main_obs_enabled eq "1"} {
    if {$main_sample_n_advanced == 1} {
      if {$::main_last_progress_elapsed_ms($hardware_name) ne "INVALID"} {
        set stall_ms [expr {$elapsed_ms -
          $::main_last_progress_elapsed_ms($hardware_name)}]
        if {$stall_ms > $::main_max_stall_ms($hardware_name)} {
          set ::main_max_stall_ms($hardware_name) $stall_ms
        }
      }
      set ::main_last_progress_elapsed_ms($hardware_name) $elapsed_ms
    } elseif {$::main_last_progress_elapsed_ms($hardware_name) ne "INVALID"} {
      set stall_ms [expr {$elapsed_ms -
        $::main_last_progress_elapsed_ms($hardware_name)}]
      if {$stall_ms > $::main_max_stall_ms($hardware_name)} {
        set ::main_max_stall_ms($hardware_name) $stall_ms
      }
      incr ::main_stall_samples($hardware_name)
      if {$stall_ms >= 10000 && $::obs_stop_reason($hardware_name) eq "NONE"} {
        set ::obs_stop_reason($hardware_name) MAIN_NOT_PROGRESSING
      }
    }
  }
  if {$helper_measurement_ok} { incr ::obs_measurement_valid($hardware_name) }
  if {$position_ok} { incr ::obs_position_valid($hardware_name) }
  if {$l2_ok} { incr ::obs_l2_valid($hardware_name) }
  set main_core_valid [expr {$trace_ok && $main_detector_ok && $magic == 1 ? 1 : 0}]
  if {$main_detector_ok} {
    incr ::main_detector_valid_count($hardware_name)
    set ::main_detector_enabled_final($hardware_name) $main_detector_enabled
    set ::main_detector_freq_locked_final($hardware_name) $main_detector_freq_locked
    set ::main_detector_phase_locked_final($hardware_name) $main_detector_phase_locked
    set ::main_detector_locked_final($hardware_name) $main_detector_locked
    set ::main_phase_lock_count_final($hardware_name) $main_phase_lock_count
    set ::main_phase_threshold_final($hardware_name) $main_phase_threshold
    set ::main_phase_lock_samples_final($hardware_name) $main_phase_lock_samples
    if {$main_phase_lock_count > $::main_phase_lock_count_max_seen($hardware_name)} {
      set ::main_phase_lock_count_max_seen($hardware_name) $main_phase_lock_count
    }
    if {$main_detector_stable} {
      incr ::main_detector_stable_count($hardware_name)
    }
  }
  if {$main_core_valid} {
    incr ::main_core_valid_count($hardware_name)
    set ::main_core_invalid_streak($hardware_name) 0
    if {$main_obs_freq_locked eq "1" && $pi_x ne "INVALID" &&
        $main_phase_threshold ne "INVALID"} {
      incr ::main_phase_domain_count($hardware_name)
      if {[expr {abs($pi_x) <= $main_phase_threshold}]} {
        incr ::main_phase_inband_count($hardware_name)
      } else {
        incr ::main_phase_outband_count($hardware_name)
      }
    }
  } else {
    incr ::main_core_invalid_streak($hardware_name)
    if {$::main_core_invalid_streak($hardware_name) >
        $::main_core_invalid_max_streak($hardware_name)} {
      set ::main_core_invalid_max_streak($hardware_name) \
        $::main_core_invalid_streak($hardware_name)
    }
    if {$::main_core_invalid_streak($hardware_name) >= 3 &&
        $::obs_stop_reason($hardware_name) eq "NONE"} {
      set ::obs_stop_reason($hardware_name) MAIN_CORE_INVALID_STREAK
    }
  }
  set group_valid [expr {$trace_ok && $helper_measurement_ok && $position_ok && $l2_ok}]
  if {$group_valid} {
    set ::obs_invalid_streak($hardware_name) 0
    incr ::obs_correlation_samples($hardware_name)
    if {$helper_residual_present == 1} {
      incr ::obs_helper_residual_samples($hardware_name)
      if {$l2_helper_pending == 1} { incr ::obs_helper_pending_samples($hardware_name) }
      if {$l2_helper_pending == 0} {
        incr ::obs_residual_without_pending($hardware_name)
        if {$main_sample_n_advanced == 1} {
          incr ::obs_residual_without_pending_and_main_progress($hardware_name)
        }
      }
    }
    if {$helper_locked eq "0"} {
      incr ::obs_helper_unlock_samples($hardware_name)
      if {$main_sample_n_advanced == 0} {
        incr ::obs_helper_unlock_main_stalled($hardware_name)
        if {$main_obs_freq_locked eq "1"} {
          incr ::obs_helper_unlock_main_stalled_freq_stale($hardware_name)
        }
      }
    }
    if {$main_sample_n_advanced == 1} { incr ::obs_main_progress_samples($hardware_name) }
  } else {
    incr ::obs_invalid_streak($hardware_name)
  }
  if {$helper_measurement_ok && $frame_ok && $helper_locked eq "0"} {
    incr ::helper_unlock_streak($hardware_name)
  } elseif {$helper_measurement_ok && $helper_locked eq "1"} {
    set ::helper_unlock_streak($hardware_name) 0
  }
  if {$helper_measurement_ok && $frame_ok && $helper_output ne "INVALID" &&
      ($helper_output <= 5 || $helper_output >= 65531)} {
    incr ::helper_rail_streak($hardware_name)
  } elseif {$helper_measurement_ok && $helper_output ne "INVALID"} {
    set ::helper_rail_streak($hardware_name) 0
  }
  if {$::helper_unlock_streak($hardware_name) >= 3 &&
      $::obs_stop_reason($hardware_name) eq "NONE"} {
    set ::obs_stop_reason($hardware_name) HELPER_UNLOCK_REGRESSION
  } elseif {$::helper_rail_streak($hardware_name) >= 3 &&
      $::obs_stop_reason($hardware_name) eq "NONE"} {
    set ::obs_stop_reason($hardware_name) HELPER_RAIL_REGRESSION
  }
  if {$l2_ok} {
    if {$::obs_helper_completed_first($hardware_name) eq "INVALID"} {
      set ::obs_helper_completed_first($hardware_name) $l2_helper_completed_count
    }
    set ::obs_helper_completed_final($hardware_name) $l2_helper_completed_count
    if {$::obs_helper_pending_count_first($hardware_name) eq "INVALID"} {
      set ::obs_helper_pending_count_first($hardware_name) $l2_helper_pending_count
    }
    set ::obs_helper_pending_count_final($hardware_name) $l2_helper_pending_count
    if {$::obs_main_completed_first($hardware_name) eq "INVALID"} {
      set ::obs_main_completed_first($hardware_name) $l2_main_completed_count
    }
    set ::obs_main_completed_final($hardware_name) $l2_main_completed_count
  }

  if {$sample == 1 && $entry_generation ne "INVALID"} {
    set ::obs_generation_baseline($hardware_name) $entry_generation
    set ::obs_cpu_reset_baseline($hardware_name) $cpu_reset
    set ::obs_wr_reset_baseline($hardware_name) $wr_reset
    set ::obs_si_drop_baseline($hardware_name) $si_drop
  } elseif {$::obs_generation_baseline($hardware_name) ne "INVALID" &&
      ($entry_generation ne $::obs_generation_baseline($hardware_name) ||
       $cpu_reset ne $::obs_cpu_reset_baseline($hardware_name) ||
       $wr_reset ne $::obs_wr_reset_baseline($hardware_name) ||
       $si_drop ne $::obs_si_drop_baseline($hardware_name))} {
    set ::obs_stop_reason($hardware_name) RESET_OR_GENERATION_CHANGE
  }
  if {$sample == $::smoke_samples} {
    set required_core_samples [expr {($::smoke_samples * 95 + 99) / 100}]
    set smoke_ok [expr {$::main_core_valid_count($hardware_name) >= $required_core_samples &&
      $::main_detector_valid_count($hardware_name) >= $required_core_samples &&
      $::obs_measurement_valid($hardware_name) >= 3 &&
      $::obs_l2_valid($hardware_name) >= 3 &&
      $::obs_generation_baseline($hardware_name) ne "INVALID" &&
      $::obs_stop_reason($hardware_name) eq "NONE" ? 1 : 0}]
    set ::obs_smoke_valid($hardware_name) $smoke_ok
    set ::transport_gate_valid($hardware_name) $smoke_ok
    if {!$smoke_ok && $::obs_stop_reason($hardware_name) eq "NONE"} {
      set ::obs_stop_reason($hardware_name) TRANSPORT_GATE_INVALID
    }
    puts [format "STEP5_F4C_TRANSPORT_GATE board=%s run_role=%s sample=%d elapsed_ms=%d VALID=%d REQUIRED_CORE_SAMPLES=%d MAIN_CORE_VALID=%d MAIN_DETECTOR_VALID=%d MAIN_DETECTOR_STABLE=%d MEASUREMENT_VALID=%d POSITION_VALID=%d L2_VALID=%d MAIN_SAMPLE_N_DELTA_SAMPLES=%d MAIN_PROGRESS_SAMPLES=%d STOP_REASON=%s" \
      $hardware_name $run_role $sample $elapsed_ms $smoke_ok $required_core_samples $::main_core_valid_count($hardware_name) $::main_detector_valid_count($hardware_name) $::main_detector_stable_count($hardware_name) $::obs_measurement_valid($hardware_name) $::obs_position_valid($hardware_name) $::obs_l2_valid($hardware_name) $::main_sample_n_delta_count($hardware_name) $::obs_main_trace_update_progress($hardware_name) $::obs_stop_reason($hardware_name)]
    flush stdout
  }

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
    set derived_error INVALID
    if {$dref ne "INVALID" && $dout ne "INVALID"} {
      set derived_error [expr {$dout - $dref}]
    }
    set main_enabled [expr {($state >> 0) & 1}]
    set main_freq_locked [expr {($state >> 1) & 1}]
    set main_phase_locked [expr {($state >> 2) & 1}]
    set main_locked [expr {($state >> 3) & 1}]
    if {$trace_unique} {
      if {$dref ne "INVALID" && $dout ne "INVALID" && $freq_error != $derived_error} {
        incr ::measurement_failures($hardware_name)
      }
      if {$prelock_error ne "INVALID" && $prelock_error != [expr {-20 * $freq_error}]} {
        incr ::prelock_mismatch_count($hardware_name)
      }
      update_freq_stats $hardware_name $freq_error
      if {$lock_count ne "INVALID" && $lock_count > $::main_freq_lock_count_max_seen($hardware_name)} {
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
      if {$main_enabled} { incr ::main_enabled_count($hardware_name) }
    }
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

  puts [format "STEP5_HPLL_DEMAND_SAMPLE board=%s sample=%d elapsed_ms=%d GROUP_VALID=%d MAIN_SAMPLE_N=%d MAIN_SAMPLE_N_ADVANCED=%d MAIN_TRACE_UPDATE_COUNT=%s MAIN_PUBLICATION_EPOCH_RAW_BEFORE=%s MAIN_PUBLICATION_EPOCH_RAW_AFTER=%s HELPER_MEASUREMENT_OK=%d HELPER_MEASUREMENT_EPOCH_BEFORE_RAW=%s HELPER_MEASUREMENT_EPOCH_AFTER_RAW=%s HELPER_MEASUREMENT_EPOCH=%s HELPER_TAG=%s HELPER_EXPECTED=%s HELPER_FREQ_ERROR=%s HELPER_PRECLAMP=%s HELPER_ERROR=%s HELPER_UPDATE_COUNT=%s HELPER_OUTPUT=%s HELPER_REF_ACCEPT_COUNT=%s HELPER_FB_ACCEPT_COUNT=%s POSITION_OK=%d PROBE39_TRACKER_RAW=%s PROBE43_POSITION_RAW=%s PROBE42_BOOTSTRAP_RAW=%s PROBE44_ACCOUNTING_BEFORE_RAW=%s PROBE44_ACCOUNTING_AFTER_RAW=%s PROBE49_ACTUATOR_RAW=%s POSITION_EPOCH=%s HELPER_TARGET_CODE=%s HELPER_APPLIED_CODE=%s HELPER_RESIDUAL_PRESENT=%s HELPER_MEASUREMENT_RESIDUAL_PRESENT=%s HELPER_FINC=%s HELPER_FDEC=%s HELPER_NORMAL_COMPLETED=%s HELPER_DCO_STEP=%s HELPER_BOOTSTRAP_COMPLETED=%s HELPER_BOOTSTRAP_DONE=%s HELPER_FORCED_FINC=%s HELPER_FORCED_FDEC=%s HELPER_NORMAL_REQUEST=%s L2_VALID=%d L2_STATUS_RAW=%s L2_PENDING_RAW=%s L2_SERVICE_START_RAW=%s L2_COMPLETED_RAW=%s L2_FAILED_RAW=%s L2_MAX_WAIT_RAW=%s L2_CURRENT_WAIT_RAW=%s L2_LATENCY_RAW=%s L2_FAILURE_RAW=%s L2_FIRST_LOSS_RAW=%s L2_FIRST_LOSS=%s L2_MAIN_PENDING=%s L2_HELPER_PENDING=%s L2_TX_ACTIVE=%s L2_OWNER_MAIN=%s L2_ACK=%s L2_TIMEOUT=%s L2_DCO_ERROR=%s L2_REASON=%s L2_RT_STATE=%s L2_STATUS_TIME=%s L2_MAIN_PENDING_COUNT=%s L2_HELPER_PENDING_COUNT=%s L2_MAIN_START_COUNT=%s L2_HELPER_START_COUNT=%s L2_MAIN_COMPLETED_COUNT=%s L2_HELPER_COMPLETED_COUNT=%s L2_MAIN_FAILED=%s L2_HELPER_FAILED=%s L2_MAIN_MAX_WAIT=%s L2_HELPER_MAX_WAIT=%s L2_MAIN_CURRENT_WAIT=%s L2_HELPER_CURRENT_WAIT=%s L2_MAIN_MAX_LATENCY=%s L2_HELPER_MAX_LATENCY=%s L2_ACK_EVENTS=%s L2_TIMEOUT_EVENTS=%s L2_FIRST_LOSS_TIME=%s L2_FIRST_LOSS_OWNER=%s L2_FIRST_LOSS_REASON=%s HELPER_PENDING=%s MAIN_PENDING=%s HELPER_ADMISSION_ELIGIBLE=UNKNOWN" \
    $hardware_name $sample $elapsed_ms $group_valid $sample $main_sample_n_advanced $update_count $::main_trace_epoch_before_raw($hardware_name) $::main_trace_epoch_after_raw($hardware_name) \
    $helper_measurement_ok $helper_epoch_before_raw $helper_epoch_after_raw $helper_epoch $helper_tag $helper_expected $helper_freq_error $helper_preclamp $helper_error $helper_update_count $helper_output $helper_ref_accept $helper_fb_accept \
    $position_ok $tracker_raw $position_raw $bootstrap_raw $position_accounting_before_raw $position_accounting_after_raw $actuator_raw $position_epoch $target $applied $helper_residual_present $helper_measurement_residual_present $finc $fdec $normal_completed $dco_step $bootstrap_completed $bootstrap_done $forced_finc $forced_fdec $helper_normal_req \
    $l2_ok $l2_status_raw $l2_pending_raw $l2_service_start_raw $l2_completed_raw $l2_failed_raw $l2_max_wait_raw $l2_current_wait_raw $l2_latency_raw $l2_failure_raw $l2_first_loss_raw $l2_first_loss $l2_main_pending $l2_helper_pending $l2_tx_active $l2_owner_main $l2_ack $l2_timeout $l2_dco_error $l2_reason $l2_rt_state $l2_status_time $l2_main_pending_count $l2_helper_pending_count $l2_main_start_count $l2_helper_start_count $l2_main_completed_count $l2_helper_completed_count $l2_main_failed_count $l2_helper_failed_count $l2_main_max_wait $l2_helper_max_wait $l2_main_current_wait $l2_helper_current_wait $l2_main_max_latency $l2_helper_max_latency $l2_ack_events $l2_timeout_events $l2_first_loss_time $l2_first_loss_owner $l2_first_loss_reason $l2_helper_pending $l2_main_pending]

  puts [format "STEP5_MAIN_FREQ_SAMPLE board=%s sample=%d elapsed_ms=%d FRAME_VALID=%d MAIN_TRACE_VALID=%d MAIN_TRACE_UNIQUE=%d TRACE_DEDUP_SKIPPED=%d MAIN_TRACE_EPOCH_BEFORE_RAW=%s MAIN_TRACE_EPOCH_AFTER_RAW=%s MAIN_TRACE_MAGIC_RAW=%s MAIN_TRACE_MAGIC=%s MAIN_DREF_DT=%s MAIN_DOUT_DT=%s MAIN_FREQ_ERROR=%s MAIN_PRELOCK_ERROR=%s MAIN_PI_UNCLAMPED=%s MAIN_PI_OUTPUT=%s MAIN_PI_CLAMP_SIDE=%s MAIN_FREQ_LOCK_COUNT=%s MAIN_FREQ_LOCK_COUNT_MAX=%s MAIN_PI_KP=%s MAIN_PI_KI=%s MAIN_PI_SHIFT=%s MAIN_PI_BIAS=%s MAIN_PI_UPDATE_COUNT=%s MAIN_FREQ_THRESHOLD=%s MAIN_FREQ_LOCK_SAMPLES=%s MAIN_STATE=%s MAIN_PI_Y_MIN=%s MAIN_PI_Y_MAX=%s MAIN_PI_ANTI_WINDUP=%s MAIN_PI_X=%s MAIN_ENABLED=%s MAIN_FREQ_LOCKED=%s MAIN_PHASE_LOCKED=%s MAIN_LOCKED=%s HELPER_LOCKED=%s HELPER_LOCK_COUNT=%s HELPER_THRESHOLD=%s HELPER_LOCK_SAMPLES=%s PSTAT_LOCKED=%s SPLL_DELOCK_COUNT=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
    $hardware_name $sample $elapsed_ms $frame_ok $trace_ok $trace_unique $::trace_dedup_skipped($hardware_name) $::main_trace_epoch_before_raw($hardware_name) $::main_trace_epoch_after_raw($hardware_name) $::main_trace_magic_raw($hardware_name) $magic $dref $dout $freq_error $prelock_error $pi_unclamped $pi_output $clamp_side $lock_count $lock_count_max $kp $ki $shift $bias $update_count $threshold $lock_samples $state $y_min $y_max $anti_windup $pi_x $main_enabled $main_freq_locked $main_phase_locked $main_locked $helper_locked $helper_lock_count $helper_threshold $helper_lock_samples $pstat_locked $spll_delock $entry_generation $cpu_reset $wr_reset $si_drop]
  if {!$trace_ok} {
    puts [format "STEP5_MAIN_FREQ_PAYLOAD_DEBUG board=%s sample=%d VALUES=%s" \
      $hardware_name $sample $::main_trace_payload_debug($hardware_name)]
  }
  set main_phase_input_domain UNKNOWN
  if {$main_detector_ok && $main_obs_freq_locked ne "INVALID"} {
    set main_phase_input_domain [expr {$main_obs_freq_locked == 1 ? "PHASE" : "FREQUENCY"}]
  }
  set main_phase_inband UNKNOWN
  if {$main_phase_input_domain eq "PHASE" && $pi_x ne "INVALID" &&
      $main_phase_threshold ne "INVALID"} {
    set main_phase_inband [expr {abs($pi_x) <= $main_phase_threshold ? 1 : 0}]
  }
  set main_reset_valid [expr {$entry_generation ne "INVALID" &&
    $cpu_reset ne "INVALID" && $wr_reset ne "INVALID" &&
    $si_drop ne "INVALID" ? 1 : 0}]
  puts [format "STEP5_F4C_MAIN_PHASE_SAMPLE board=%s run_role=%s observer_sample_n=%d elapsed_ms=%d MAIN_CORE_VALID=%d MAIN_TRACE_VALID=%d MAIN_TRACE_UNIQUE=%d MAIN_TRACE_PUBLICATION_EPOCH_BEFORE_RAW=%s MAIN_TRACE_PUBLICATION_EPOCH_AFTER_RAW=%s MAIN_SAMPLE_N=%s MAIN_SAMPLE_N_DELTA=%s MAIN_SAMPLE_N_DELTA_AMBIGUOUS=%d MAIN_SAMPLE_N_ADVANCED=%d MAIN_DETECTOR_VALID=%d MAIN_DETECTOR_STABLE=%d MAIN_STATE_RAW=%s MAIN_LIMITS_RAW=%s MAIN_PHASE_LIMITS_RAW=%s MAIN_DETECTOR_ENABLED=%s MAIN_DETECTOR_LOCKED=%s MAIN_DETECTOR_FREQ_LOCKED=%s MAIN_DETECTOR_PHASE_LOCKED=%s MAIN_FREQ_LOCK_COUNT=%s MAIN_PHASE_LOCK_COUNT=%s MAIN_FREQ_THRESHOLD=%s MAIN_FREQ_LOCK_SAMPLES=%s MAIN_PHASE_THRESHOLD=%s MAIN_PHASE_LOCK_SAMPLES=%s MAIN_PHASE_INPUT_DOMAIN=%s MAIN_PHASE_INBAND=%s MAIN_PHASE_DOMAIN_SOURCE=MAIN_DETECTOR_SHADOW MAIN_PHASE_INBAND_ALIGNMENT=ASYNC_TRACE_PI_X_VS_DETECTOR_LIMITS MAIN_PI_X=%s MAIN_PI_UNCLAMPED=%s MAIN_PI_OUTPUT=%s MAIN_PI_CLAMP_SIDE=%s MAIN_PI_KP=%s MAIN_PI_KI=%s MAIN_PI_SHIFT=%s MAIN_PI_BIAS=%s L2_VALID=%d L2_MAIN_PENDING=%s L2_HELPER_PENDING=%s L2_TX_ACTIVE=%s L2_OWNER_MAIN=%s L2_MAIN_PENDING_COUNT=%s L2_HELPER_PENDING_COUNT=%s L2_MAIN_START_COUNT=%s L2_HELPER_START_COUNT=%s L2_MAIN_COMPLETED_COUNT=%s L2_HELPER_COMPLETED_COUNT=%s L2_MAIN_FAILED=%s L2_HELPER_FAILED=%s L2_MAIN_MAX_WAIT=%s L2_HELPER_MAX_WAIT=%s L2_MAIN_CURRENT_WAIT=%s L2_HELPER_CURRENT_WAIT=%s L2_MAIN_MAX_LATENCY=%s L2_HELPER_MAX_LATENCY=%s HELPER_MEASUREMENT_OK=%d HELPER_LOCKED=%s HELPER_ERROR=%s HELPER_OUTPUT=%s HELPER_RESIDUAL_PRESENT=%s HELPER_MEASUREMENT_RESIDUAL_PRESENT=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s RESET_FIELDS_VALID=%d STOP_REASON=%s" \
    $hardware_name $run_role $sample $elapsed_ms $main_core_valid $trace_ok $trace_unique $::main_trace_epoch_before_raw($hardware_name) $::main_trace_epoch_after_raw($hardware_name) $update_count $main_sample_n_delta $main_sample_n_delta_is_ambiguous $main_sample_n_advanced $main_detector_ok $main_detector_stable $main_state_raw $main_limits_raw $main_phase_limits_raw $main_detector_enabled $main_detector_locked $main_detector_freq_locked $main_detector_phase_locked $main_freq_lock_count $main_phase_lock_count $main_freq_threshold $main_freq_lock_samples $main_phase_threshold $main_phase_lock_samples $main_phase_input_domain $main_phase_inband $pi_x $pi_unclamped $pi_output $clamp_side $kp $ki $shift $bias $l2_ok $l2_main_pending $l2_helper_pending $l2_tx_active $l2_owner_main $l2_main_pending_count $l2_helper_pending_count $l2_main_start_count $l2_helper_start_count $l2_main_completed_count $l2_helper_completed_count $l2_main_failed_count $l2_helper_failed_count $l2_main_max_wait $l2_helper_max_wait $l2_main_current_wait $l2_helper_current_wait $l2_main_max_latency $l2_helper_max_latency $helper_measurement_ok $helper_locked $helper_error $helper_output $helper_residual_present $helper_measurement_residual_present $entry_generation $cpu_reset $wr_reset $si_drop $main_reset_valid $::obs_stop_reason($hardware_name)]
  if {$elapsed_ms >= $::health_next_ms($hardware_name)} {
    puts [format "STEP5_F4C_HEALTH board=%s run_role=%s elapsed_ms=%d MAIN_CORE_VALID_COUNT=%d MAIN_TRACE_VALID_COUNT=%d MAIN_DETECTOR_VALID_COUNT=%d MAIN_SAMPLE_N=%s MAIN_PROGRESS_SAMPLES=%d MAIN_SAMPLE_N_DELTA_SUM=%d MAIN_PHASE_LOCK_COUNT=%s MAIN_PHASE_INBAND_COUNT=%d MAIN_PHASE_OUTBAND_COUNT=%d L2_MAIN_PENDING=%s L2_HELPER_PENDING=%s L2_MAIN_START_COUNT=%s L2_HELPER_START_COUNT=%s L2_MAIN_COMPLETED_COUNT=%s L2_HELPER_COMPLETED_COUNT=%s L2_MAIN_FAILED=%s L2_HELPER_FAILED=%s HELPER_LOCKED=%s HELPER_ERROR=%s HELPER_OUTPUT=%s STOP_REASON=%s" \
      $hardware_name $run_role $elapsed_ms $::main_core_valid_count($hardware_name) $::trace_valid_count($hardware_name) $::main_detector_valid_count($hardware_name) $update_count $::obs_main_trace_update_progress($hardware_name) $::main_sample_n_delta_sum($hardware_name) $main_phase_lock_count $::main_phase_inband_count($hardware_name) $::main_phase_outband_count($hardware_name) $l2_main_pending $l2_helper_pending $l2_main_start_count $l2_helper_start_count $l2_main_completed_count $l2_helper_completed_count $l2_main_failed_count $l2_helper_failed_count $helper_locked $helper_error $helper_output $::obs_stop_reason($hardware_name)]
    set ::health_next_ms($hardware_name) [expr {$::health_next_ms($hardware_name) + 30000}]
  }
  flush stdout
}

proc emit_f4c_summary {hardware_name} {
  set sample_total $::sample_count($hardware_name)
  set core_fraction INVALID
  set detector_fraction INVALID
  set detector_stable_fraction INVALID
  set phase_inband_fraction INVALID
  set advanced_fraction INVALID
  if {$sample_total > 0} {
    set core_fraction [expr {double($::main_core_valid_count($hardware_name)) / double($sample_total)}]
    set detector_fraction [expr {double($::main_detector_valid_count($hardware_name)) / double($sample_total)}]
    set detector_stable_fraction [expr {double($::main_detector_stable_count($hardware_name)) / double($sample_total)}]
  }
  if {$::main_phase_domain_count($hardware_name) > 0} {
    set phase_inband_fraction [expr {double($::main_phase_inband_count($hardware_name)) / double($::main_phase_domain_count($hardware_name))}]
  }
  if {$::main_sample_n_delta_count($hardware_name) > 0} {
    set advanced_fraction [expr {double($::obs_main_trace_update_progress($hardware_name)) / double($::main_sample_n_delta_count($hardware_name))}]
  }
  set main_sample_n_window_delta [counter_delta \
    $::obs_main_update_first($hardware_name) $::obs_main_update_final($hardware_name) 32]
  if {$::main_sample_n_delta_ambiguous($hardware_name) > 0} {
    set main_sample_n_window_delta INVALID
  }
  set helper_completed_delta [counter_delta \
    $::obs_helper_completed_first($hardware_name) $::obs_helper_completed_final($hardware_name) 32]
  set helper_pending_delta [counter_delta \
    $::obs_helper_pending_count_first($hardware_name) $::obs_helper_pending_count_final($hardware_name) 32]
  set main_completed_delta [counter_delta \
    $::obs_main_completed_first($hardware_name) $::obs_main_completed_final($hardware_name) 32]
  foreach {gen0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {gen1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  set reset_result [expr {$gen0 ne "INVALID" && $gen1 ne "INVALID" &&
    $cpu0 ne "INVALID" && $cpu1 ne "INVALID" &&
    $wr0 ne "INVALID" && $wr1 ne "INVALID" &&
    $si0 ne "INVALID" && $si1 ne "INVALID" &&
    $gen0 == $gen1 && $cpu0 == $cpu1 && $wr0 == $wr1 && $si0 == $si1 ? "PASS" : "INCONCLUSIVE"}]
  set data_quality INCONCLUSIVE
  if {$::transport_gate_valid($hardware_name) == 1 &&
      $core_fraction ne "INVALID" && $core_fraction >= 0.95 &&
      $detector_fraction ne "INVALID" && $detector_fraction >= 0.95 &&
      $::main_sample_n_delta_count($hardware_name) >= 3 &&
      $::obs_main_trace_update_progress($hardware_name) >= 2 &&
      $::main_sample_n_delta_ambiguous($hardware_name) == 0 &&
      $reset_result eq "PASS"} {
    set data_quality PASS
  }
  set diagnostic_terminal [expr {$::run_end_reason($hardware_name) eq "TARGET_REACHED" ||
    [lsearch -exact {MAIN_NOT_PROGRESSING HELPER_UNLOCK_REGRESSION HELPER_RAIL_REGRESSION} \
      $::obs_stop_reason($hardware_name)] >= 0}]
  set diagnostic_result INCONCLUSIVE
  if {$data_quality eq "PASS" && $diagnostic_terminal} {
    set diagnostic_result PASS
  }
  puts [join [list \
    STEP5_F4C_SUMMARY \
    "board=$hardware_name" \
    "run_role=$::run_role" \
    "samples=$sample_total" \
    "sample_start_ms=$::obs_sample_first_ms($hardware_name)" \
    "elapsed_ms=$::elapsed_final($hardware_name)" \
    "target_duration_ms=$::target_duration_ms" \
    "hard_duration_ms=$::hard_duration_ms" \
    "run_end_reason=$::run_end_reason($hardware_name)" \
    "stop_reason=$::obs_stop_reason($hardware_name)" \
    "transport_gate_valid=$::transport_gate_valid($hardware_name)" \
    "main_core_valid_count=$::main_core_valid_count($hardware_name)" \
    "main_core_valid_fraction=$core_fraction" \
    "main_core_invalid_max_streak=$::main_core_invalid_max_streak($hardware_name)" \
    "main_trace_valid_count=$::trace_valid_count($hardware_name)" \
    "main_trace_unique_count=$::trace_unique_count($hardware_name)" \
    "main_trace_dedup_skipped=$::trace_dedup_skipped($hardware_name)" \
    "main_detector_valid_count=$::main_detector_valid_count($hardware_name)" \
    "main_detector_stable_count=$::main_detector_stable_count($hardware_name)" \
    "main_detector_valid_fraction=$detector_fraction" \
    "main_detector_stable_fraction=$detector_stable_fraction" \
    "main_sample_n_first=$::obs_main_update_first($hardware_name)" \
    "main_sample_n_final=$::obs_main_update_final($hardware_name)" \
    "main_sample_n_window_delta=$main_sample_n_window_delta" \
    "main_sample_n_delta_samples=$::main_sample_n_delta_count($hardware_name)" \
    "main_sample_n_delta_sum=$::main_sample_n_delta_sum($hardware_name)" \
    "main_sample_n_delta_ambiguous=$::main_sample_n_delta_ambiguous($hardware_name)" \
    "main_sample_n_advanced_samples=$::obs_main_trace_update_progress($hardware_name)" \
    "main_sample_n_advanced_fraction=$advanced_fraction" \
    "main_max_stall_ms=$::main_max_stall_ms($hardware_name)" \
    "main_stall_samples=$::main_stall_samples($hardware_name)" \
    "main_phase_domain_samples=$::main_phase_domain_count($hardware_name)" \
    "main_phase_inband_count=$::main_phase_inband_count($hardware_name)" \
    "main_phase_outband_count=$::main_phase_outband_count($hardware_name)" \
    "main_phase_inband_fraction=$phase_inband_fraction" \
    "main_phase_lock_count_max_seen=$::main_phase_lock_count_max_seen($hardware_name)" \
    "main_phase_lock_count_final=$::main_phase_lock_count_final($hardware_name)" \
    "main_phase_threshold_final=$::main_phase_threshold_final($hardware_name)" \
    "main_phase_lock_samples_final=$::main_phase_lock_samples_final($hardware_name)" \
    "main_detector_enabled_final=$::main_detector_enabled_final($hardware_name)" \
    "main_detector_freq_locked_final=$::main_detector_freq_locked_final($hardware_name)" \
    "main_detector_phase_locked_final=$::main_detector_phase_locked_final($hardware_name)" \
    "main_detector_locked_final=$::main_detector_locked_final($hardware_name)" \
    "main_pi_x_final=$::main_trace_last_x($hardware_name)" \
    "main_pi_output_final=$::main_trace_last_output($hardware_name)" \
    "main_pi_clamp_side_final=$::main_trace_last_clamp_side($hardware_name)" \
    "main_trace_update_count_final=$::main_trace_update_count_final($hardware_name)" \
    "helper_measurement_valid=$::obs_measurement_valid($hardware_name)" \
    "position_valid=$::obs_position_valid($hardware_name)" \
    "l2_valid=$::obs_l2_valid($hardware_name)" \
    "helper_residual_samples=$::obs_helper_residual_samples($hardware_name)" \
    "helper_pending_samples=$::obs_helper_pending_samples($hardware_name)" \
    "residual_without_pending=$::obs_residual_without_pending($hardware_name)" \
    "residual_without_pending_main_progress=$::obs_residual_without_pending_and_main_progress($hardware_name)" \
    "helper_unlock_samples=$::obs_helper_unlock_samples($hardware_name)" \
    "helper_unlock_main_stalled=$::obs_helper_unlock_main_stalled($hardware_name)" \
    "helper_unlock_main_stalled_freq_stale=$::obs_helper_unlock_main_stalled_freq_stale($hardware_name)" \
    "main_l2_completed_delta=$main_completed_delta" \
    "helper_l2_completed_delta=$helper_completed_delta" \
    "helper_pending_count_delta=$helper_pending_delta" \
    "helper_locked_ever=$::helper_locked_ever($hardware_name)" \
    "helper_locked_final=$::helper_locked_final($hardware_name)" \
    "pstat_locked_final=$::pstat_locked_final($hardware_name)" \
    "spll_delock_first=$::spll_delock_first($hardware_name)" \
    "spll_delock_max=$::spll_delock_max($hardware_name)" \
    "spll_delock_final=$::spll_delock_final($hardware_name)" \
    "reset_stable=$reset_result" \
    "boot_generation_first=$::entry_generation_first($hardware_name)" \
    "boot_generation_final=$::entry_generation_final($hardware_name)" \
    "main_trace_publication_epoch_final=$::main_trace_epoch_after_raw($hardware_name)" \
    "main_trace_magic_final=$::main_trace_magic_final($hardware_name)" \
    "f4c_data_quality=$data_quality" \
    "f4c_diagnostic_result=$diagnostic_result" \
    "step5_complete=NO" \
    "merge_approved=NO"] " "]
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
  set main_enabled_fraction INVALID
  if {$::trace_unique_count($hardware_name) > 0} {
    set main_enabled_fraction [expr {double($::main_enabled_count($hardware_name)) / double($::trace_unique_count($hardware_name))}]
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
  puts [format "STEP5_MAIN_FREQ_PRELOCK_SUMMARY board=%s SAMPLES=%d ELAPSED_MS=%d TRACE_VALID=%d TRACE_UNIQUE=%d TRACE_DEDUP_SKIPPED=%d FRAME_VALID=%d INVALID=%d FREQ_ERROR_SAMPLES=%d FREQ_ERROR_MEAN=%s FREQ_ERROR_RMS=%s FREQ_ERROR_MIN=%s FREQ_ERROR_MAX=%s FREQ_ERROR_MAX_ABS=%s FREQ_ERROR_FIRST=%s FREQ_ERROR_FINAL=%s FRACTION_ABS_FREQ_ERROR_LE_50=%s PRELOCK_ERROR_MISMATCHES=%d MEASUREMENT_FAILS=%d PI_SAMPLES=%d PI_LOW_RAIL_FRACTION=%s PI_HIGH_RAIL_FRACTION=%s PI_NO_RAIL_FRACTION=%s MAIN_ENABLED_FRACTION=%s MAIN_FREQ_LOCK_COUNT_MAX_SEEN=%s MAIN_FREQ_LOCK_COUNT_FINAL=%s MAIN_FREQ_LOCK_COUNT_MAX_FINAL=%s MAIN_FREQ_LOCKED_EVER=%d MAIN_FREQ_LOCKED_FINAL=%s MAIN_PHASE_LOCKED_EVER=%d MAIN_PHASE_LOCKED_FINAL=%s MAIN_LOCKED_EVER=%d MAIN_LOCKED_FINAL=%s MAIN_ENABLED_FINAL=%s HELPER_LOCKED_EVER=%d HELPER_LOCKED_FINAL=%s HELPER_LOCK_COUNT_MAX=%s HELPER_LOCK_COUNT_FINAL=%s PSTAT_LOCKED_EVER=%d PSTAT_LOCKED_FINAL=%s SPLL_DELOCK_FIRST=%s SPLL_DELOCK_MAX=%s SPLL_DELOCK_FINAL=%s RESET_STABLE=%s BOOT_GENERATION_FIRST=%s BOOT_GENERATION_FINAL=%s MAIN_DREF_DT_FINAL=%s MAIN_DOUT_DT_FINAL=%s MAIN_FREQ_ERROR_FINAL=%s MAIN_PRELOCK_ERROR_FINAL=%s MAIN_PI_UNCLAMPED_FINAL=%s MAIN_PI_OUTPUT_FINAL=%s MAIN_PI_CLAMP_SIDE_FINAL=%s MAIN_PI_KP_FINAL=%s MAIN_PI_KI_FINAL=%s MAIN_PI_SHIFT_FINAL=%s MAIN_PI_BIAS_FINAL=%s MAIN_PI_UPDATE_COUNT_FINAL=%s MAIN_FREQ_THRESHOLD_FINAL=%s MAIN_FREQ_LOCK_SAMPLES_FINAL=%s MAIN_PI_Y_MIN_FINAL=%s MAIN_PI_Y_MAX_FINAL=%s MAIN_PI_ANTI_WINDUP_FINAL=%s MAIN_PI_X_FINAL=%s TELEMETRY_RESULT=%s STEP5_COMPLETE=NO MERGE_APPROVED=NO" \
    $hardware_name $::sample_count($hardware_name) $::elapsed_final($hardware_name) $::trace_valid_count($hardware_name) $::trace_unique_count($hardware_name) $::trace_dedup_skipped($hardware_name) $::frame_valid_count($hardware_name) $::invalid_count($hardware_name) $::freq_count($hardware_name) $freq_mean $freq_rms $::freq_min($hardware_name) $::freq_max($hardware_name) $freq_max_abs $::freq_first($hardware_name) $::freq_last($hardware_name) $freq_band_fraction $::prelock_mismatch_count($hardware_name) $::measurement_failures($hardware_name) $::pi_count($hardware_name) $pi_low_fraction $pi_high_fraction $pi_no_rail_fraction $main_enabled_fraction $::main_freq_lock_count_max_seen($hardware_name) $::main_freq_lock_count_final($hardware_name) $::main_freq_lock_count_max_final($hardware_name) $::main_freq_locked_ever($hardware_name) $::main_freq_locked_final($hardware_name) $::main_phase_locked_ever($hardware_name) $::main_phase_locked_final($hardware_name) $::main_locked_ever($hardware_name) $::main_locked_final($hardware_name) $::main_enabled_final($hardware_name) $::helper_locked_ever($hardware_name) $::helper_locked_final($hardware_name) $::helper_lock_count_max($hardware_name) $::helper_lock_count_final($hardware_name) $::pstat_locked_ever($hardware_name) $::pstat_locked_final($hardware_name) $::spll_delock_first($hardware_name) $::spll_delock_max($hardware_name) $::spll_delock_final($hardware_name) $reset_result $::entry_generation_first($hardware_name) $::entry_generation_final($hardware_name) $::main_trace_last_dref($hardware_name) $::main_trace_last_dout($hardware_name) $::main_trace_last_error($hardware_name) $::main_trace_last_prelock($hardware_name) $::main_trace_last_unclamped($hardware_name) $::main_trace_last_output($hardware_name) $::main_trace_last_clamp_side($hardware_name) $::main_trace_last_kp($hardware_name) $::main_trace_last_ki($hardware_name) $::main_trace_last_shift($hardware_name) $::main_trace_last_bias($hardware_name) $::main_trace_update_count_final($hardware_name) $::main_trace_last_threshold($hardware_name) $::main_trace_last_lock_samples($hardware_name) $::main_trace_last_ymin($hardware_name) $::main_trace_last_ymax($hardware_name) $::main_trace_last_anti_windup($hardware_name) $::main_trace_last_x($hardware_name) $telemetry_result]
  set main_update_delta [counter_delta $::obs_main_update_first($hardware_name) $::obs_main_update_final($hardware_name) 32]
  set helper_completed_delta [counter_delta $::obs_helper_completed_first($hardware_name) $::obs_helper_completed_final($hardware_name) 32]
  set helper_pending_delta [counter_delta $::obs_helper_pending_count_first($hardware_name) $::obs_helper_pending_count_final($hardware_name) 32]
  set main_completed_delta [counter_delta $::obs_main_completed_first($hardware_name) $::obs_main_completed_final($hardware_name) 32]
  set main_progress_fraction INVALID
  if {$::obs_correlation_samples($hardware_name) > 0} {
    set main_progress_fraction [expr {double($::obs_main_progress_samples($hardware_name)) / double($::obs_correlation_samples($hardware_name))}]
  }
  # This legacy line is retained only for older log tooling.  It is not a
  # verdict for F4C and must never claim a demand PASS from mixed windows.
  set demand_result INCONCLUSIVE
  puts [format "STEP5_F4C_LEGACY_SUMMARY board=%s SAMPLES=%d SAMPLE_START_MS=%s SAMPLE_FINAL_MS=%d CORRELATION_SAMPLES=%d HELPER_MEASUREMENT_VALID=%d POSITION_VALID=%d L2_VALID=%d INVALID_STREAK_FINAL=%d SMOKE_SAMPLES=%d SMOKE_VALID=%d STOP_REASON=%s MAIN_TRACE_UPDATE_FIRST=%s MAIN_TRACE_UPDATE_FINAL=%s MAIN_TRACE_UPDATE_DELTA=%s MAIN_SAMPLE_N_ADVANCED=%d MAIN_PROGRESS_FRACTION=%s HELPER_RESIDUAL_SAMPLES=%d HELPER_PENDING_SAMPLES=%d RESIDUAL_WITHOUT_PENDING=%d RESIDUAL_WITHOUT_PENDING_MAIN_PROGRESS=%d HELPER_UNLOCK_SAMPLES=%d HELPER_UNLOCK_MAIN_STALLED=%d HELPER_UNLOCK_MAIN_STALLED_FREQ_STALE=%d MAIN_L2_COMPLETED_DELTA=%s HELPER_L2_COMPLETED_DELTA=%s HELPER_PENDING_COUNT_DELTA=%s DEMAND_RESULT=%s ADMISSION_ELIGIBILITY=UNKNOWN STEP5_COMPLETE=NO MERGE_APPROVED=NO" \
    $hardware_name $::sample_count($hardware_name) $::obs_sample_first_ms($hardware_name) $::obs_sample_final_ms($hardware_name) $::obs_correlation_samples($hardware_name) $::obs_measurement_valid($hardware_name) $::obs_position_valid($hardware_name) $::obs_l2_valid($hardware_name) $::obs_invalid_streak($hardware_name) $::smoke_samples $::obs_smoke_valid($hardware_name) $::obs_stop_reason($hardware_name) $::obs_main_update_first($hardware_name) $::obs_main_update_final($hardware_name) $main_update_delta $::obs_main_trace_update_progress($hardware_name) $main_progress_fraction $::obs_helper_residual_samples($hardware_name) $::obs_helper_pending_samples($hardware_name) $::obs_residual_without_pending($hardware_name) $::obs_residual_without_pending_and_main_progress($hardware_name) $::obs_helper_unlock_samples($hardware_name) $::obs_helper_unlock_main_stalled($hardware_name) $::obs_helper_unlock_main_stalled_freq_stale($hardware_name) $main_completed_delta $helper_completed_delta $helper_pending_delta $demand_result]
  flush stdout
}

proc f4e_is_number {value} {
  return [string is integer -strict $value]
}

proc f4e_hex_token {value} {
  if {[is_hex $value]} { return 0x[normalize_probe64 $value] }
  return $value
}

proc f4e_identity_role_valid {role hardware_name} {
  if {$role eq "MASTER"} {
    return [expr {[string first "1-11.1" $hardware_name] >= 0 ? 1 : 0}]
  }
  if {$role eq "SLAVE"} {
    return [expr {[string first "1-11.2" $hardware_name] >= 0 ? 1 : 0}]
  }
  return 0
}

proc f4e_collect_targets {} {
  set targets {}
  foreach hardware_name [get_hardware_names] {
    if {$::board_filter ne "" &&
        [string first $::board_filter $hardware_name] < 0} {
      continue
    }
    set role ""
    if {[string first "1-11.1" $hardware_name] >= 0} {
      set role MASTER
    } elseif {[string first "1-11.2" $hardware_name] >= 0} {
      set role SLAVE
    }
    if {$role eq ""} { continue }
    set device_names [get_device_names -hardware_name $hardware_name]
    if {[llength $device_names] == 0} { continue }
    lappend targets [list $role $hardware_name [lindex $device_names 0]]
  }
  return $targets
}

proc f4e_initialize_board {role hardware_name} {
  set ::f4e_role($hardware_name) $role
  set ::wb_toggle($hardware_name) 0
  set ::f4e_sample_count($hardware_name) 0
  set ::f4e_entry_seen($hardware_name) 0
  set ::f4e_entry_sample($hardware_name) NEVER
  set ::f4e_entry_elapsed_ms($hardware_name) NEVER
  set ::f4e_entry_update_count($hardware_name) NEVER
  set ::f4e_last_update_count($hardware_name) INVALID
  set ::f4e_last_update_elapsed_ms($hardware_name) INVALID
  set ::f4e_last_main_core_elapsed_ms($hardware_name) INVALID
  set ::f4e_main_progress_samples($hardware_name) 0
  set ::f4e_main_core_valid_samples($hardware_name) 0
  set ::f4e_acquisition_allowed_samples($hardware_name) 0
  set ::f4e_phase_domain_samples($hardware_name) 0
  set ::f4e_phase_inband_samples($hardware_name) 0
  set ::f4e_helper_unlock_streak($hardware_name) 0
  set ::f4e_helper_rail_streak($hardware_name) 0
  set ::f4e_freq_unlock_streak($hardware_name) 0
  set ::f4e_terminal_streak($hardware_name) 0
  set ::f4e_transport_error_streak($hardware_name) 0
  set ::f4e_generation_baseline($hardware_name) INVALID
  set ::f4e_cpu_reset_baseline($hardware_name) INVALID
  set ::f4e_wr_reset_baseline($hardware_name) INVALID
  set ::f4e_si_drop_baseline($hardware_name) INVALID
  set ::f4e_stop_reason($hardware_name) NONE
  set ::f4e_run_end_reason($hardware_name) NOT_REACHED
  set ::f4e_first_ms($hardware_name) NEVER
  set ::f4e_last_ms($hardware_name) 0
}

proc f4e_set_stop {reason} {
  if {$::f4e_global_stop_reason ne "NONE"} { return }
  set ::f4e_global_stop_reason $reason
  foreach hardware_name [array names ::f4e_role] {
    set ::f4e_stop_reason($hardware_name) $reason
  }
}

proc f4e_sample_error {role hardware_name sample elapsed_ms read_start_ms \
    read_end_ms error_message} {
  set ::f4e_sample_count($hardware_name) $sample
  set ::f4e_last_ms($hardware_name) $elapsed_ms
  incr ::f4e_transport_error_streak($hardware_name)
  set safe_message [string map [list " " "_" "\n" "|" "\r" "|"] $error_message]
  if {$::f4e_transport_error_streak($hardware_name) >= 3} {
    f4e_set_stop DATA_UNRESOLVED
  }
  puts [join [list \
    STEP5_F4E_SAMPLE \
    "run_role=acquisition" \
    "role=$role" \
    "board=$hardware_name" \
    "sample=$sample" \
    "observer_sample_n=$sample" \
    "elapsed_ms=$elapsed_ms" \
    "read_start_ms=$read_start_ms" \
    "read_end_ms=$read_end_ms" \
    "frame_valid=0" \
    "core_frame_valid=0" \
    "transport_valid=0" \
    "main_core_valid=0" \
    "main_trace_valid=0" \
    "main_sample_n=INVALID" \
    "main_update_count=INVALID" \
    "main_sample_n_delta=INVALID" \
    "main_sample_n_delta_ambiguous=1" \
    "main_sample_n_advanced=0" \
    "acquisition_diagnostic_allowed=0" \
    "entry_class=DATA_UNRESOLVED" \
    "stop_reason=$::f4e_stop_reason($hardware_name)" \
    "read_error=$safe_message"] " "]
  flush stdout
}

proc emit_f4e_sample {role hardware_name device_name sample elapsed_ms} {
  set ::f4e_sample_count($hardware_name) $sample
  if {$sample == 1} { set ::f4e_first_ms($hardware_name) $elapsed_ms }
  set ::f4e_last_ms($hardware_name) $elapsed_ms
  set read_start_ms [clock milliseconds]
  set probe_started 0
  set read_error ""
  set read_ok [catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name

    set ctrl_begin [wb_read $hardware_name 0x00100A04]
    set status [probe_read 0]
    set entry_probe [probe_read 26]
    set reset_probe [probe_read 27]
    set ptp_meta [wb_read $hardware_name 0x00100A5C]
    set sstat [wb_read $hardware_name 0x00100A08]
    set parse_meta [wb_read $hardware_name 0x00100A80]
    set wr_failure [wb_read $hardware_name 0x00100A6C]
    set wr_state [wb_read $hardware_name 0x00100A4C]
    set pstat [wb_read $hardware_name 0x00100A0C]
    set lock_result [wb_read $hardware_name 0x00100A8C]
    set spll_state [wb_read $hardware_name 0x00100AA0]

    set ::main_trace_epoch_before_raw($hardware_name) INVALID
    set ::main_trace_epoch_after_raw($hardware_name) INVALID
    set trace [read_main_trace $hardware_name]
    foreach {trace_ok epoch dref dout freq_error prelock_error pi_unclamped \
        pi_output clamp_side lock_count lock_count_max kp ki shift bias \
        update_count threshold lock_samples state y_min y_max anti_windup \
        pi_x magic} $trace break
    set main_detector [read_main_detector_block $hardware_name]
    foreach {main_detector_ok main_detector_stable main_state_raw \
        main_limits_raw main_phase_limits_raw main_detector_enabled \
        main_detector_locked main_detector_freq_locked \
        main_detector_phase_locked main_freq_lock_count \
        main_phase_lock_count main_freq_threshold main_freq_lock_samples \
        main_phase_threshold main_phase_lock_samples} $main_detector break
    foreach {helper_state helper_limits} [read_helper_pair $hardware_name] break
    set helper_locked [field32 $helper_state 0 1]
    set helper_lock_count [field32 $helper_state 16 16]
    set helper_threshold [field32 $helper_limits 0 16]
    set helper_lock_samples [field32 $helper_limits 16 16]

    set helper_measurement [read_helper_measurement $hardware_name]
    foreach {helper_measurement_ok helper_epoch_before_raw \
        helper_epoch_after_raw helper_epoch helper_tag helper_expected \
        helper_freq_error helper_preclamp helper_error helper_update_count \
        helper_output helper_ref_accept helper_fb_accept} $helper_measurement break
    set position_observation [read_position_observability]
    foreach {position_ok position_accounting_before_raw \
        position_accounting_after_raw position_raw bootstrap_raw actuator_raw \
        position_epoch target applied finc fdec normal_completed dco_step \
        bootstrap_completed bootstrap_done forced_finc forced_fdec} \
        $position_observation break
    set tracker_raw [probe_read 39]
    set tracker_word [word64 $tracker_raw]
    set helper_normal_request [expr {$tracker_word < 0 ? "INVALID" : (($tracker_word >> 32) & 0xffff)}]
    set l2_observation [read_l2_observability]
    foreach {l2_ok l2_status_raw l2_pending_raw l2_service_start_raw \
        l2_completed_raw l2_failed_raw l2_max_wait_raw l2_current_wait_raw \
        l2_latency_raw l2_failure_raw l2_first_loss_raw l2_first_loss \
        l2_main_pending l2_helper_pending l2_tx_active l2_owner_main l2_ack \
        l2_timeout l2_dco_error l2_reason l2_rt_state l2_status_time \
        l2_main_pending_count l2_helper_pending_count l2_main_start_count \
        l2_helper_start_count l2_main_completed_count \
        l2_helper_completed_count l2_main_failed_count l2_helper_failed_count \
        l2_main_max_wait l2_helper_max_wait l2_main_current_wait \
        l2_helper_current_wait l2_main_max_latency l2_helper_max_latency \
        l2_ack_events l2_timeout_events l2_first_loss_time \
        l2_first_loss_owner l2_first_loss_reason} $l2_observation break
    set ctrl_end [wb_read $hardware_name 0x00100A04]
    set read_end_ms [clock milliseconds]
  } read_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  if {!$read_ok} {
    f4e_sample_error $role $hardware_name $sample $elapsed_ms \
      $read_start_ms [clock milliseconds] $read_error
    return
  }

  set frame_ok [frame_valid $ctrl_begin $ctrl_end]
  set direct_values [list $ctrl_begin $ctrl_end $status $entry_probe \
    $reset_probe $ptp_meta $sstat $parse_meta $wr_failure $wr_state $pstat \
    $lock_result $spll_state]
  set direct_valid 1
  foreach value $direct_values {
    if {![is_hex $value]} { set direct_valid 0 }
  }
  set transport_valid [expr {$frame_ok && $direct_valid ? 1 : 0}]
  if {$transport_valid} {
    set ::f4e_transport_error_streak($hardware_name) 0
  } else {
    incr ::f4e_transport_error_streak($hardware_name)
    if {$::f4e_transport_error_streak($hardware_name) >= 3} {
      f4e_set_stop DATA_UNRESOLVED
    }
  }

  set status_valid [is_hex $status]
  set si_config_done [field32 $status 0 1]
  set wr_ready [field32 $status 1 1]
  set core_tm_link_up [field32 $status 2 1]
  set core_link_ok [field32 $status 3 1]
  set wr_rx_ready [field32 $status 6 1]
  set wr_tx_ready [field32 $status 7 1]
  set cpu_reset_n [field32 $status 15 1]
  set boot_generation [probe_high32 $entry_probe]
  set cpu_reset_count [probe_field32 $reset_probe 16 8]
  set wr_core_reset_count [probe_field32 $reset_probe 24 8]
  set si_drop_count [probe_field32 $reset_probe 40 8]
  set reset_fields_valid [expr {[f4e_is_number $boot_generation] &&
    [f4e_is_number $cpu_reset_count] &&
    [f4e_is_number $wr_core_reset_count] &&
    [f4e_is_number $si_drop_count] ? 1 : 0}]
  set reset_changed 0
  if {$reset_fields_valid} {
    if {$::f4e_generation_baseline($hardware_name) eq "INVALID"} {
      set ::f4e_generation_baseline($hardware_name) $boot_generation
      set ::f4e_cpu_reset_baseline($hardware_name) $cpu_reset_count
      set ::f4e_wr_reset_baseline($hardware_name) $wr_core_reset_count
      set ::f4e_si_drop_baseline($hardware_name) $si_drop_count
    } elseif {$boot_generation != $::f4e_generation_baseline($hardware_name) ||
        $cpu_reset_count != $::f4e_cpu_reset_baseline($hardware_name) ||
        $wr_core_reset_count != $::f4e_wr_reset_baseline($hardware_name) ||
        $si_drop_count != $::f4e_si_drop_baseline($hardware_name)} {
      set reset_changed 1
      f4e_set_stop RESET_OR_GENERATION_CHANGE
    }
  }
  set reset_stable [expr {$reset_fields_valid && !$reset_changed ? 1 : 0}]

  set ptp_state [field32 $ptp_meta 0 8]
  set pd_state [field32 $ptp_meta 8 8]
  set ext_state [field32 $ptp_meta 16 8]
  set wrc_mode [field32 $ptp_meta 24 8]
  set parent_is_wrnode [field32 $parse_meta 24 1]
  set parent_mode_on [field32 $parse_meta 25 1]
  set parent_calibrated [field32 $parse_meta 26 1]
  set wr_state_value [field32 $wr_state 11 4]
  set wr_next_state [field32 $wr_state 15 4]
  set wr_failure_low16 [field32 $wr_failure 0 16]
  set wr_disable_cause [field32 $wr_failure 8 3]
  set wr_disable_valid [field32 $wr_failure 11 1]
  set wr_disable_ptp_state [field32 $wr_failure 12 4]
  set wr_disable_tics_low [field32 $sstat 16 16]
  set wr_disable_pd_state [field32 $sstat 1 4]
  set wr_disable_ext_state [field32 $sstat 12 4]
  set wr_failure_reason [field32 $lock_result 9 7]
  set wr_failure_tics_low [field32 $lock_result 16 16]
  set pstat_locked [field32 $pstat 1 1]
  set spll_seq_state [field32 $spll_state 0 8]
  set spll_alignment_state [field32 $spll_state 8 8]
  set spll_mode [field32 $spll_state 16 8]
  set spll_delock_count [field32 $spll_state 24 8]

  set main_core_valid 0
  if {$trace_ok && $main_detector_ok && [f4e_is_number $magic] && $magic == 1} {
    set main_core_valid 1
    incr ::f4e_main_core_valid_samples($hardware_name)
    set ::f4e_last_main_core_elapsed_ms($hardware_name) $elapsed_ms
  }
  set main_sample_n_delta INVALID
  set main_sample_n_delta_ambiguous 0
  set main_sample_n_advanced 0
  if {$trace_ok && [f4e_is_number $update_count]} {
    if {$::f4e_last_update_count($hardware_name) ne "INVALID"} {
      set main_sample_n_delta [counter_delta \
        $::f4e_last_update_count($hardware_name) $update_count 32]
      if {$main_sample_n_delta eq "INVALID" || $main_sample_n_delta > 0x7fffffff} {
        set main_sample_n_delta INVALID
        set main_sample_n_delta_ambiguous 1
      } elseif {$main_sample_n_delta > 0} {
        set main_sample_n_advanced 1
      }
      if {$main_sample_n_advanced} {
        set ::f4e_last_update_elapsed_ms($hardware_name) $elapsed_ms
      }
    } else {
      # The first coherent producer value establishes the progress clock;
      # subsequent equal values are intentionally left stale so the 10 s
      # no-progress stop is meaningful.
      set ::f4e_last_update_elapsed_ms($hardware_name) $elapsed_ms
    }
    set ::f4e_last_update_count($hardware_name) $update_count
  }
  if {$main_core_valid && $main_sample_n_advanced} {
    incr ::f4e_main_progress_samples($hardware_name)
  }

  set main_phase_input_domain UNKNOWN
  if {$main_detector_ok && $main_detector_freq_locked ne "INVALID"} {
    set main_phase_input_domain [expr {$main_detector_freq_locked == 1 ? "PHASE" : "FREQUENCY"}]
  }
  set main_phase_inband UNKNOWN
  if {$main_phase_input_domain eq "PHASE" && [f4e_is_number $pi_x] &&
      [f4e_is_number $main_phase_threshold]} {
    set main_phase_inband [expr {abs($pi_x) <= $main_phase_threshold ? 1 : 0}]
    if {$main_core_valid} {
      incr ::f4e_phase_domain_samples($hardware_name)
      if {$main_phase_inband == 1} {
        incr ::f4e_phase_inband_samples($hardware_name)
      }
    }
  }

  set helper_residual_present UNKNOWN
  if {$position_ok && [f4e_is_number $target] && [f4e_is_number $applied]} {
    set helper_residual_present [expr {$target != ($applied & 0xffff) ? 1 : 0}]
  }
  set helper_measurement_residual_present UNKNOWN
  if {$helper_measurement_ok && [f4e_is_number $helper_error]} {
    set helper_measurement_residual_present [expr {abs($helper_error) > 200 ? 1 : 0}]
  }

  set role_identity_valid [f4e_identity_role_valid $role $hardware_name]
  set phy_link_usable [expr {$status_valid && $si_config_done == 1 &&
    $wr_ready == 1 && $core_tm_link_up == 1 && $core_link_ok == 1 &&
    $wr_rx_ready == 1 && $wr_tx_ready == 1 ? 1 : 0}]
  set no_terminal 0
  if {$direct_valid} {
    if {[f4e_is_number $pd_state] && $pd_state == 4} { set no_terminal 1 }
    if {[f4e_is_number $ext_state] && $ext_state == 0} { set no_terminal 1 }
    if {$::f4e_entry_seen($hardware_name) &&
        [f4e_is_number $wr_state_value] && $wr_state_value == 0} {
      set no_terminal 1
    }
    if {[f4e_is_number $wr_disable_valid] && $wr_disable_valid == 1} { set no_terminal 1 }
    if {[f4e_is_number $wr_failure_reason] && $wr_failure_reason >= 1 &&
        $wr_failure_reason <= 7} { set no_terminal 1 }
  }
  if {$no_terminal} {
    incr ::f4e_terminal_streak($hardware_name)
  } else {
    set ::f4e_terminal_streak($hardware_name) 0
  }
  if {$::f4e_terminal_streak($hardware_name) >= 2} {
    f4e_set_stop WR_SESSION_ENDED
  }

  set acquisition_allowed 0
  set entry_class WAITING_FOR_ACQUISITION
  if {!$role_identity_valid} {
    set entry_class IDENTITY_MISMATCH
  } elseif {!$phy_link_usable} {
    set entry_class PHY_LINK_NOT_USABLE
  } elseif {!$reset_stable} {
    set entry_class RESET_UNRESOLVED
  } elseif {$role ne "SLAVE"} {
    set entry_class MASTER_BACKGROUND
  } elseif {$wr_state_value ne "2"} {
    set entry_class WR_NOT_S_LOCK
  } elseif {$no_terminal} {
    set entry_class WR_SESSION_ENDED
  } elseif {$helper_locked ne "1"} {
    set entry_class HELPER_NOT_LOCKED
  } elseif {!$main_core_valid} {
    set entry_class MAIN_CORE_NOT_READY
  } elseif {$main_detector_enabled ne "1"} {
    set entry_class MAIN_NOT_ENABLED
  } elseif {$main_detector_freq_locked ne "1"} {
    set entry_class MAIN_FREQUENCY_NOT_LOCKED
  } else {
    set acquisition_allowed 1
    set entry_class ELIGIBLE
  }
  if {$acquisition_allowed} {
    incr ::f4e_acquisition_allowed_samples($hardware_name)
    if {!$::f4e_entry_seen($hardware_name)} {
      set ::f4e_entry_seen($hardware_name) 1
      set ::f4e_entry_sample($hardware_name) $sample
      set ::f4e_entry_elapsed_ms($hardware_name) $elapsed_ms
      set ::f4e_entry_update_count($hardware_name) $update_count
      # Start the ten-second producer-progress guard at the acquisition
      # boundary, not at an older pre-entry observation.
      set ::f4e_last_update_elapsed_ms($hardware_name) $elapsed_ms
      puts [join [list STEP5_F4E_ENTRY role=$role board=$hardware_name \
        sample=$sample elapsed_ms=$elapsed_ms main_sample_n=$update_count \
        phase_locked=$main_detector_phase_locked helper_locked=$helper_locked] " "]
      flush stdout
    }
    if {$helper_measurement_ok && $helper_locked == 0} {
      incr ::f4e_helper_unlock_streak($hardware_name)
    } elseif {$helper_locked == 1} {
      set ::f4e_helper_unlock_streak($hardware_name) 0
    }
    if {$helper_measurement_ok && [f4e_is_number $helper_output] &&
        ($helper_output <= 5 || $helper_output >= 65531)} {
      incr ::f4e_helper_rail_streak($hardware_name)
    } elseif {$helper_measurement_ok && [f4e_is_number $helper_output]} {
      set ::f4e_helper_rail_streak($hardware_name) 0
    }
    if {$main_detector_ok && $main_detector_freq_locked == 0} {
      incr ::f4e_freq_unlock_streak($hardware_name)
    } elseif {$main_detector_ok && $main_detector_freq_locked == 1} {
      set ::f4e_freq_unlock_streak($hardware_name) 0
    }
  }
  if {$::f4e_entry_seen($hardware_name)} {
    if {$::f4e_last_main_core_elapsed_ms($hardware_name) eq "INVALID"} {
      set ::f4e_last_main_core_elapsed_ms($hardware_name) $elapsed_ms
    }
    if {$main_core_valid && [f4e_is_number $update_count] &&
        $::f4e_last_update_elapsed_ms($hardware_name) ne "INVALID" &&
        [expr {$elapsed_ms - $::f4e_last_update_elapsed_ms($hardware_name)}] >= 10000} {
      f4e_set_stop MAIN_UPDATE_STALL
    } elseif {!$main_core_valid &&
        [expr {$elapsed_ms - $::f4e_last_main_core_elapsed_ms($hardware_name)}] >= 10000} {
      f4e_set_stop DATA_UNRESOLVED
    }
    if {$::f4e_helper_unlock_streak($hardware_name) >= 3} {
      f4e_set_stop HELPER_REGRESSION
    } elseif {$::f4e_helper_rail_streak($hardware_name) >= 3} {
      f4e_set_stop HELPER_REGRESSION
    } elseif {$::f4e_freq_unlock_streak($hardware_name) >= 3} {
      f4e_set_stop FREQ_ACQUISITION_REGRESSION
    }
  }

  puts [join [list \
    STEP5_F4E_SAMPLE \
    "run_role=acquisition" \
    "role=$role" \
    "board=$hardware_name" \
    "sample=$sample" \
    "observer_sample_n=$sample" \
    "elapsed_ms=$elapsed_ms" \
    "read_start_ms=$read_start_ms" \
    "read_end_ms=$read_end_ms" \
    "frame_valid=$frame_ok" \
    "core_frame_valid=$direct_valid" \
    "transport_valid=$transport_valid" \
    "role_identity_valid=$role_identity_valid" \
    "phy_link_usable=$phy_link_usable" \
    "status_raw=$status" \
    "si_config_done=$si_config_done" \
    "wr_ready=$wr_ready" \
    "core_tm_link_up=$core_tm_link_up" \
    "core_link_ok=$core_link_ok" \
    "wr_rx_ready=$wr_rx_ready" \
    "wr_tx_ready=$wr_tx_ready" \
    "cpu_reset_n=$cpu_reset_n" \
    "ptp_state=$ptp_state" \
    "pd_state=$pd_state" \
    "ext_state=$ext_state" \
    "wrc_mode=$wrc_mode" \
    "parent_is_wrnode=$parent_is_wrnode" \
    "parent_mode_on=$parent_mode_on" \
    "parent_calibrated=$parent_calibrated" \
    "wr_state=$wr_state_value" \
    "wr_next_state=$wr_next_state" \
    "wr_failure_low16=$wr_failure_low16" \
    "wr_failure_reason=$wr_failure_reason" \
    "wr_failure_tics_low=$wr_failure_tics_low" \
    "wr_disable_valid=$wr_disable_valid" \
    "wr_disable_cause=$wr_disable_cause" \
    "wr_disable_ptp_state=$wr_disable_ptp_state" \
    "wr_disable_pd_state=$wr_disable_pd_state" \
    "wr_disable_ext_state=$wr_disable_ext_state" \
    "wr_disable_tics_low=$wr_disable_tics_low" \
    "pstat_locked=$pstat_locked" \
    "spll_seq_state=$spll_seq_state" \
    "spll_alignment_state=$spll_alignment_state" \
    "spll_mode=$spll_mode" \
    "spll_delock_count=$spll_delock_count" \
    "boot_generation=$boot_generation" \
    "cpu_reset_count=$cpu_reset_count" \
    "wr_core_reset_count=$wr_core_reset_count" \
    "si_config_drop_count=$si_drop_count" \
    "reset_fields_valid=$reset_fields_valid" \
    "reset_stable=$reset_stable" \
    "reset_changed=$reset_changed" \
    "main_core_valid=$main_core_valid" \
    "main_trace_valid=$trace_ok" \
    "main_detector_valid=$main_detector_ok" \
    "main_detector_stable=$main_detector_stable" \
    "main_state_raw=$main_state_raw" \
    "main_limits_raw=$main_limits_raw" \
    "main_phase_limits_raw=$main_phase_limits_raw" \
    "main_detector_enabled=$main_detector_enabled" \
    "main_detector_locked=$main_detector_locked" \
    "main_detector_freq_locked=$main_detector_freq_locked" \
    "main_detector_phase_locked=$main_detector_phase_locked" \
    "main_freq_lock_count=$main_freq_lock_count" \
    "main_phase_lock_count=$main_phase_lock_count" \
    "main_freq_threshold=$main_freq_threshold" \
    "main_freq_lock_samples=$main_freq_lock_samples" \
    "main_phase_threshold=$main_phase_threshold" \
    "main_phase_lock_samples=$main_phase_lock_samples" \
    "main_trace_publication_epoch_before_raw=[f4e_hex_token $::main_trace_epoch_before_raw($hardware_name)]" \
    "main_trace_publication_epoch_after_raw=[f4e_hex_token $::main_trace_epoch_after_raw($hardware_name)]" \
    "main_publication_epoch=$epoch" \
    "main_sample_n=$update_count" \
    "main_update_count=$update_count" \
    "main_sample_n_delta=$main_sample_n_delta" \
    "main_sample_n_delta_ambiguous=$main_sample_n_delta_ambiguous" \
    "main_sample_n_advanced=$main_sample_n_advanced" \
    "main_dref_dt=$dref" \
    "main_dout_dt=$dout" \
    "main_frequency_error=$freq_error" \
    "main_prelock_error=$prelock_error" \
    "main_pi_x=$pi_x" \
    "main_pi_unclamped=$pi_unclamped" \
    "main_pi_output=$pi_output" \
    "main_pi_clamp_side=$clamp_side" \
    "main_pi_kp=$kp" \
    "main_pi_ki=$ki" \
    "main_pi_shift=$shift" \
    "main_pi_bias=$bias" \
    "main_pi_y_min=$y_min" \
    "main_pi_y_max=$y_max" \
    "main_pi_anti_windup=$anti_windup" \
    "main_phase_input_domain=$main_phase_input_domain" \
    "main_phase_inband=$main_phase_inband" \
    "helper_measurement_ok=$helper_measurement_ok" \
    "helper_epoch_before_raw=$helper_epoch_before_raw" \
    "helper_epoch_after_raw=$helper_epoch_after_raw" \
    "helper_epoch=$helper_epoch" \
    "helper_tag=$helper_tag" \
    "helper_expected=$helper_expected" \
    "helper_frequency_error=$helper_freq_error" \
    "helper_preclamp=$helper_preclamp" \
    "helper_error=$helper_error" \
    "helper_update_count=$helper_update_count" \
    "helper_output=$helper_output" \
    "helper_ref_accept_count=$helper_ref_accept" \
    "helper_fb_accept_count=$helper_fb_accept" \
    "helper_locked=$helper_locked" \
    "helper_lock_count=$helper_lock_count" \
    "helper_threshold=$helper_threshold" \
    "helper_lock_samples=$helper_lock_samples" \
    "position_ok=$position_ok" \
    "probe39_tracker_raw=$tracker_raw" \
    "probe43_position_raw=$position_raw" \
    "probe42_bootstrap_raw=$bootstrap_raw" \
    "probe44_accounting_before_raw=$position_accounting_before_raw" \
    "probe44_accounting_after_raw=$position_accounting_after_raw" \
    "probe49_actuator_raw=$actuator_raw" \
    "position_epoch=$position_epoch" \
    "helper_target_code=$target" \
    "helper_applied_code=$applied" \
    "helper_residual_present=$helper_residual_present" \
    "helper_measurement_residual_present=$helper_measurement_residual_present" \
    "helper_finc=$finc" \
    "helper_fdec=$fdec" \
    "helper_normal_completed=$normal_completed" \
    "helper_dco_step=$dco_step" \
    "helper_bootstrap_completed=$bootstrap_completed" \
    "helper_bootstrap_done=$bootstrap_done" \
    "helper_forced_finc=$forced_finc" \
    "helper_forced_fdec=$forced_fdec" \
    "helper_normal_request=$helper_normal_request" \
    "l2_valid=$l2_ok" \
    "l2_status_raw=$l2_status_raw" \
    "l2_pending_raw=$l2_pending_raw" \
    "l2_service_start_raw=$l2_service_start_raw" \
    "l2_completed_raw=$l2_completed_raw" \
    "l2_failed_raw=$l2_failed_raw" \
    "l2_max_wait_raw=$l2_max_wait_raw" \
    "l2_current_wait_raw=$l2_current_wait_raw" \
    "l2_latency_raw=$l2_latency_raw" \
    "l2_failure_raw=$l2_failure_raw" \
    "l2_first_loss_raw=$l2_first_loss_raw" \
    "l2_main_pending=$l2_main_pending" \
    "l2_helper_pending=$l2_helper_pending" \
    "l2_tx_active=$l2_tx_active" \
    "l2_owner_main=$l2_owner_main" \
    "l2_main_pending_count=$l2_main_pending_count" \
    "l2_helper_pending_count=$l2_helper_pending_count" \
    "l2_main_start_count=$l2_main_start_count" \
    "l2_helper_start_count=$l2_helper_start_count" \
    "l2_main_completed_count=$l2_main_completed_count" \
    "l2_helper_completed_count=$l2_helper_completed_count" \
    "l2_main_failed_count=$l2_main_failed_count" \
    "l2_helper_failed_count=$l2_helper_failed_count" \
    "l2_main_max_wait=$l2_main_max_wait" \
    "l2_helper_max_wait=$l2_helper_max_wait" \
    "l2_main_current_wait=$l2_main_current_wait" \
    "l2_helper_current_wait=$l2_helper_current_wait" \
    "l2_main_max_latency=$l2_main_max_latency" \
    "l2_helper_max_latency=$l2_helper_max_latency" \
    "l2_ack_events=$l2_ack_events" \
    "l2_timeout_events=$l2_timeout_events" \
    "l2_first_loss_time=$l2_first_loss_time" \
    "l2_first_loss_owner=$l2_first_loss_owner" \
    "l2_first_loss_reason=$l2_first_loss_reason" \
    "acquisition_diagnostic_allowed=$acquisition_allowed" \
    "entry_class=$entry_class" \
    "main_progress_samples=$::f4e_main_progress_samples($hardware_name)" \
    "acquisition_allowed_samples=$::f4e_acquisition_allowed_samples($hardware_name)" \
    "helper_unlock_streak=$::f4e_helper_unlock_streak($hardware_name)" \
    "helper_rail_streak=$::f4e_helper_rail_streak($hardware_name)" \
    "freq_unlock_streak=$::f4e_freq_unlock_streak($hardware_name)" \
    "terminal_streak=$::f4e_terminal_streak($hardware_name)" \
    "stop_reason=$::f4e_stop_reason($hardware_name)" \
    "helper_admission_eligible=UNKNOWN"] " "]
  flush stdout
}

proc run_f4e_acquisition {} {
  global samples target_duration_ms hard_duration_ms gap_ms
  set targets [f4e_collect_targets]
  set master_target ""
  set slave_target ""
  foreach target $targets {
    if {[lindex $target 0] eq "MASTER"} { set master_target $target }
    if {[lindex $target 0] eq "SLAVE"} { set slave_target $target }
  }
  puts [join [list \
    STEP5_F4E_CONFIG \
    "experiment=EXP-S5-F4E-ACQUISITION-MAIN-PHASE-PROGRESS-20260915" \
    "run_role=acquisition" \
    "samples_max=$samples" \
    "target_duration_ms=$target_duration_ms" \
    "hard_duration_ms=$hard_duration_ms" \
    "slave_cadence_ms=500" \
    "master_cadence_ms=3000" \
    "read_only_observer=1" \
    "one_reader=1" \
    "reader_processes=1" \
    "no_control_write=1" \
    "no_helper_pi_snapshot=1" \
    "no_debug_fifo_drain=1" \
    "main_trace_window=0x00100B58..0x00100BAC" \
    "main_trace_magic=0x00100BDC" \
    "main_detector_state=0x00100AC4" \
    "position_probes=42,43,44,49" \
    "l2_probes=52..61" \
    "max_actual_ms=$hard_duration_ms"] " "]
  flush stdout
  if {[llength $targets] != 2 || $master_target eq "" || $slave_target eq ""} {
    puts [join [list STEP5_F4E_CONFIG_ERROR required=MASTER+SLAVE \
      discovered=[llength $targets]] " "]
    puts "STEP5_F4E_DONE run_end_reason=CONFIG_INVALID stop_reason=CONFIG_INVALID step5_complete=NO merge_approved=NO"
    return
  }
  foreach target [list $master_target $slave_target] {
    f4e_initialize_board [lindex $target 0] [lindex $target 1]
  }
  set ::f4e_global_stop_reason NONE
  set ::f4e_session_start_ms [clock milliseconds]
  set effective_duration $::target_duration_ms
  if {$effective_duration <= 0} { set effective_duration $::hard_duration_ms }
  set target_deadline [expr {$::f4e_session_start_ms + $effective_duration}]
  set hard_deadline [expr {$::f4e_session_start_ms + $::hard_duration_ms}]
  set next_slave_ms $::f4e_session_start_ms
  set next_master_ms $::f4e_session_start_ms
  set master_sample 0
  set slave_sample 0
  while {[clock milliseconds] < $hard_deadline &&
      [clock milliseconds] < $target_deadline &&
      $::f4e_global_stop_reason eq "NONE"} {
    set did_work 0
    set now [clock milliseconds]
    if {$now >= $next_slave_ms} {
      incr slave_sample
      set slave_elapsed [expr {[clock milliseconds] - $::f4e_session_start_ms}]
      emit_f4e_sample SLAVE [lindex $slave_target 1] [lindex $slave_target 2] \
        $slave_sample $slave_elapsed
      set next_slave_ms [expr {[clock milliseconds] + 500}]
      set did_work 1
    }
    if {$::f4e_global_stop_reason ne "NONE"} { break }
    set now [clock milliseconds]
    if {$now >= $next_master_ms} {
      incr master_sample
      set master_elapsed [expr {[clock milliseconds] - $::f4e_session_start_ms}]
      emit_f4e_sample MASTER [lindex $master_target 1] [lindex $master_target 2] \
        $master_sample $master_elapsed
      set next_master_ms [expr {[clock milliseconds] + 3000}]
      set did_work 1
    }
    if {!$did_work} {
      set now [clock milliseconds]
      set next_due $next_slave_ms
      if {$next_master_ms < $next_due} { set next_due $next_master_ms }
      set remaining [expr {$next_due - $now}]
      if {$remaining > 0} {
        if {$remaining > 100} { set remaining 100 }
        after $remaining
      }
    }
  }
  set ::f4e_session_end_ms [clock milliseconds]
  set session_elapsed [expr {$::f4e_session_end_ms - $::f4e_session_start_ms}]
  if {$::f4e_global_stop_reason eq "NONE" && !$::f4e_entry_seen([lindex $slave_target 1])} {
    f4e_set_stop NO_ELIGIBLE_ACQUISITION_WINDOW
  }
  if {$::f4e_global_stop_reason ne "NONE"} {
    set end_reason STOP_$::f4e_global_stop_reason
  } elseif {$session_elapsed >= $effective_duration} {
    set end_reason TARGET_REACHED
  } elseif {$session_elapsed >= $::hard_duration_ms} {
    set end_reason HARD_DEADLINE
  } else {
    set end_reason OBSERVER_EXIT
  }
  foreach target [list $master_target $slave_target] {
    set role [lindex $target 0]
    set hardware_name [lindex $target 1]
    set ::f4e_run_end_reason($hardware_name) $end_reason
    puts [join [list \
      STEP5_F4E_ROLE_SUMMARY \
      "role=$role" \
      "board=$hardware_name" \
      "samples=$::f4e_sample_count($hardware_name)" \
      "entry_seen=$::f4e_entry_seen($hardware_name)" \
      "entry_sample=$::f4e_entry_sample($hardware_name)" \
      "entry_elapsed_ms=$::f4e_entry_elapsed_ms($hardware_name)" \
      "main_core_valid_samples=$::f4e_main_core_valid_samples($hardware_name)" \
      "main_progress_samples=$::f4e_main_progress_samples($hardware_name)" \
      "acquisition_allowed_samples=$::f4e_acquisition_allowed_samples($hardware_name)" \
      "phase_domain_samples=$::f4e_phase_domain_samples($hardware_name)" \
      "phase_inband_samples=$::f4e_phase_inband_samples($hardware_name)" \
      "stop_reason=$::f4e_stop_reason($hardware_name)" \
      "run_end_reason=$end_reason"] " "]
  }
  puts [join [list \
    STEP5_F4E_DONE \
    "session_elapsed_ms=$session_elapsed" \
    "target_duration_ms=$effective_duration" \
    "hard_duration_ms=$::hard_duration_ms" \
    "master_samples=$master_sample" \
    "slave_samples=$slave_sample" \
    "run_end_reason=$end_reason" \
    "stop_reason=$::f4e_global_stop_reason" \
    "single_reader=PASS" \
    "step5_complete=NO" \
    "merge_approved=NO"] " "]
  flush stdout
}

if {$run_role eq "acquisition"} {
  run_f4e_acquisition
  exit 0
}

puts [join [list \
  STEP5_F4C_CONFIG \
  "samples_max=$samples" \
  "gap_ms=$gap_ms" \
  "board_filter=$board_filter" \
  "experiment=EXP-S5-F4C-MAIN-PHASE-SERVICE-CAUSE-AUDIT-20260915" \
  "run_role=$run_role" \
  "target_duration_ms=$target_duration_ms" \
  "hard_duration_ms=$hard_duration_ms" \
  "read_only_observer=1" \
  "smoke_samples=$smoke_samples" \
  "helper_measurement_window=0x00100B00..0x00100B24" \
  "main_trace_window=0x00100B58..0x00100BAC" \
  "main_trace_magic=0x00100BDC" \
  "main_detector_state=0x00100AC4" \
  "main_detector_limits=0x00100AC8" \
  "main_detector_phase_limits=0x00100ACC" \
  "position_probes=42,43,44,49" \
  "l2_probes=52..61" \
  "no_helper_pi_snapshot=1" \
  "no_second_reader=1" \
  "firmware_s_lock_alignment=auxiliary" \
  "wr_master_lock_timeout_ms=60000" \
  "wr_state_retry=3" \
  "helper_phase_guard_seconds=8" \
  "main_phase_threshold_expected=1200" \
  "main_phase_lock_samples_expected=1000" \
  "cadence_ms=$gap_ms"] " "]

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== STEP5_F4C_BOARD %s ===" $hardware_name]
  flush stdout
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    set hard_deadline [expr {$start_ms + $hard_duration_ms}]
    set target_deadline [expr {$start_ms + $target_duration_ms}]
    set ::run_end_reason($hardware_name) NOT_REACHED
    for {set sample 1} {$sample <= $samples && [clock milliseconds] < $hard_deadline &&
        ($target_duration_ms == 0 || [clock milliseconds] < $target_deadline)} {incr sample} {
      set deadline [expr {$start_ms + (($sample - 1) * $gap_ms)}]
      set now [clock milliseconds]
      if {$now < $deadline} { after [expr {$deadline - $now}] }
      emit_sample $hardware_name $sample [expr {[clock milliseconds] - $start_ms}]
      if {$sample == $smoke_samples && $::obs_smoke_valid($hardware_name) == 0} { break }
      if {$::obs_stop_reason($hardware_name) ne "NONE"} { break }
    }
    set ::elapsed_final($hardware_name) [expr {[clock milliseconds] - $start_ms}]
    if {$::obs_stop_reason($hardware_name) ne "NONE"} {
      set ::run_end_reason($hardware_name) STOP_$::obs_stop_reason($hardware_name)
    } elseif {$target_duration_ms > 0 && $::elapsed_final($hardware_name) >= $target_duration_ms} {
      set ::run_end_reason($hardware_name) TARGET_REACHED
    } elseif {$::elapsed_final($hardware_name) >= $hard_duration_ms} {
      set ::run_end_reason($hardware_name) HARD_DEADLINE
    } elseif {$sample > $samples} {
      set ::run_end_reason($hardware_name) SAMPLE_LIMIT
    } else {
      set ::run_end_reason($hardware_name) OBSERVER_EXIT
    }
    emit_summary $hardware_name
    emit_f4c_summary $hardware_name
  } error_message]} {
    puts [format "STEP5_F4C_ERROR board=%s message=%s error_info=%s" $hardware_name $error_message [string map [list "\n" " | "] $::errorInfo]]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_MAIN_FREQ_PRELOCK_DONE"
