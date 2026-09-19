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
#     ?f4k_arm? ?f4k_expected_main_kp?
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
set f4k_arm "UNSPECIFIED"
set f4k_expected_main_kp "UNSPECIFIED"
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {[llength $argv] >= 4} { set target_duration_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set hard_duration_ms [expr {int([lindex $argv 4])}] }
if {[llength $argv] >= 6} { set run_role [string tolower [lindex $argv 5]] }
if {[llength $argv] >= 7} { set f4k_arm [lindex $argv 6] }
if {[llength $argv] >= 8} { set f4k_expected_main_kp [expr {int([lindex $argv 7])}] }
if {$samples <= 0 || $gap_ms < 0 || $target_duration_ms < 0 ||
    $hard_duration_ms <= 0 ||
    ($target_duration_ms > 0 && $target_duration_ms > $hard_duration_ms) ||
    [lsearch -exact {legacy smoke long acquisition f4f f4g f4h f4i f4j f4l f4m f4s} $run_role] < 0} {
  error "samples must be > 0, gap_ms must be >= 0, durations must be valid, and run_role must be legacy, smoke, long, acquisition, f4f, f4g, f4h, f4i, f4j, f4l, f4m, or f4s"
}
if {$run_role eq "f4j" && $f4k_arm ne "UNSPECIFIED" &&
    [lsearch -exact {A1 B A2} $f4k_arm] < 0} {
  error "F4K arm must be A1, B, or A2"
}
if {$f4k_expected_main_kp ne "UNSPECIFIED" &&
    [lsearch -exact {300 600} $f4k_expected_main_kp] < 0} {
  error "F4K expected Main Kp must be 300 or 600"
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

# F4F Helper measurement-contract audit state.  This is deliberately kept
# separate from F4E state: F4F alternates two passive read profiles and must
# preserve every rejected raw attempt instead of collapsing it into the F4E
# acquisition verdict.
array set ::f4f_role {}
array set ::f4f_cycle_count {}
array set ::f4f_full_cycles {}
array set ::f4f_core_cycles {}
array set ::f4f_full_accepted {}
array set ::f4f_core_accepted {}
array set ::f4f_core_fresh {}
array set ::f4f_core_stale {}
array set ::f4f_core_ambiguous {}
array set ::f4f_core_first_accepted_ms {}
array set ::f4f_core_last_accepted_ms {}
array set ::f4f_core_last_update {}
array set ::f4f_profile_transport_streak {}
array set ::f4f_profile_no_core_since_ms {}
array set ::f4f_background_count {}
array set ::f4f_generation_baseline {}
array set ::f4f_cpu_reset_baseline {}
array set ::f4f_wr_reset_baseline {}
array set ::f4f_si_drop_baseline {}
array set ::f4f_reset_samples {}
array set ::f4f_stop_reason {}
array set ::f4f_run_end_reason {}
array set ::f4f_last_profile_end_ms {}
set ::f4f_global_stop_reason NONE
set ::f4f_session_start_ms 0
set ::f4f_session_end_ms 0

# F4G compact Helper/Main service-window audit state.  F4G is intentionally
# independent of the older F4E/F4F verdict state.  One active source-probe
# context contains the Slave Helper, Main, detector, position, L2, and WR
# reads; the context is closed before a Master context begins.
array set ::f4g_role {}
array set ::f4g_cycle_count {}
array set ::f4g_context_count {}
array set ::f4g_helper_core_transport_streak {}
array set ::f4g_main_core_transport_streak {}
array set ::f4g_wr_core_transport_streak {}
array set ::f4g_helper_no_core_since_ms {}
array set ::f4g_main_no_core_since_ms {}
array set ::f4g_last_helper_usable_ms {}
array set ::f4g_last_helper_update {}
array set ::f4g_last_main_usable_ms {}
array set ::f4g_last_main_update {}
array set ::f4g_last_main_progress_ms {}
array set ::f4g_phase_qual_streak {}
array set ::f4g_phase_qualified_seen {}
array set ::f4g_helper_unlock_streak {}
array set ::f4g_helper_rail_streak {}
array set ::f4g_freq_unlock_streak {}
array set ::f4g_terminal_streak {}
array set ::f4g_wr_seen_active {}
array set ::f4g_generation_baseline {}
array set ::f4g_cpu_reset_baseline {}
array set ::f4g_wr_reset_baseline {}
array set ::f4g_si_drop_baseline {}
array set ::f4g_stop_reason {}
array set ::f4g_run_end_reason {}
set ::f4g_global_stop_reason NONE
set ::f4g_session_start_ms 0
set ::f4g_session_end_ms 0
set ::f4g_run_role f4g
set ::f4g_experiment_name EXP-S5-F4G-COMPACT-HELPER-MAIN-SERVICE-WINDOW-20260915
set ::f4g_phy_status_source WDIAGS_CTRL_LEGACY

# F4I keeps the validated F4H WR/PHY source and Helper CORE reader, but uses a
# smaller Main trace group.  Domain labels are observations of the published
# Main state; the WDIAGS frame has no producer-iteration identifier, so the
# producer-side domain/error pairing remains explicitly UNPROVEN.
array set ::f4i_last_trace_key {}
array set ::f4i_last_raw_trace {}
array set ::f4i_last_domain {}
array set ::f4i_last_helper_update {}
array set ::f4i_last_update {}
array set ::f4i_last_progress_ms {}
array set ::f4i_last_main_valid_ms {}
array set ::f4i_helper_lock_seen {}
array set ::f4i_trace_count {}
array set ::f4i_trace_valid_count {}
array set ::f4i_trace_unique_count {}
array set ::f4i_trace_duplicate_count {}
array set ::f4i_domain_change_count {}
array set ::f4i_main_progress_count {}
array set ::f4i_main_invalid_streak {}
array set ::f4i_helper_unlock_streak {}
array set ::f4i_helper_rail_streak {}
array set ::f4i_phy_bad_streak {}
array set ::f4i_metadata_seen {}
array set ::f4i_next_service_ms {}
array set ::f4i_stop_reason {}
array set ::f4i_run_end_reason {}
set ::f4i_global_stop_reason NONE
set ::f4i_session_start_ms 0
set ::f4i_session_end_ms 0

# F4J captures a completed Main producer frame.  These arrays contain only
# observer-side bookkeeping; no control request or Helper PI snapshot is
# issued by this role.
array set ::f4j_last_update_id {}
array set ::f4j_last_sample_n {}
array set ::f4j_last_init_generation {}
array set ::f4j_last_producer_epoch {}
array set ::f4j_no_valid_since_ms {}
array set ::f4j_valid_count {}
array set ::f4j_unique_count {}
array set ::f4j_duplicate_count {}
array set ::f4j_update_progress_count {}
array set ::f4j_sample_progress_count {}
array set ::f4j_bin_keys {}
array set ::f4j_frequency_branch_count {}
array set ::f4j_phase_branch_count {}
array set ::f4j_phase_call_count {}
array set ::f4j_phase_in_band_count {}
array set ::f4j_phase_out_band_count {}
array set ::f4j_helper_lock_seen {}
array set ::f4j_helper_unlock_streak {}
array set ::f4j_helper_rail_streak {}
array set ::f4j_phy_bad_streak {}
array set ::f4j_master_wr_transport_streak {}
array set ::f4j_stop_reason {}
array set ::f4j_run_end_reason {}
array set ::f4j_metadata_seen {}
array set ::f4j_next_service_ms {}
set ::f4j_global_stop_reason NONE
set ::f4j_session_start_ms 0
set ::f4j_session_end_ms 0

# F4L is a separate, passive, paged Main phase/integrator diagnostic. Its
# source frame reuses the F4J dynamic overlay with a different magic/version;
# keep its observer bookkeeping separate so an F4J capture can never be
# silently interpreted as F4L.
array set ::f4l_last_source_epoch {}
array set ::f4l_last_init_generation {}
array set ::f4l_last_update_id {}
array set ::f4l_last_page {}
array set ::f4l_no_valid_since_ms {}
array set ::f4l_valid_count {}
array set ::f4l_unique_count {}
array set ::f4l_duplicate_count {}
array set ::f4l_page_valid_count {}
array set ::f4l_page_seen {}
array set ::f4l_next_service_ms {}
array set ::f4l_stop_reason {}
array set ::f4l_run_end_reason {}
array set ::f4l_schedule_last_sequence {}
array set ::f4l_schedule_valid_count {}
array set ::f4l_schedule_invalid_count {}
array set ::f4l_schedule_last_main_enabled {}
array set ::f4l_schedule_last_page {}
array set ::f4l_schedule_last_enabled_rise {}
array set ::f4l_schedule_last_enabled_fall {}
array set ::f4l_schedule_last_page_advance {}
array set ::f4l_schedule_last_page_reset {}
array set ::f4l_schedule_last_page2_due {}
array set ::f4l_schedule_last_page2_publish {}
set ::f4l_smoke_ok 0
set ::f4l_no_valid_timeout_ms 10000
set ::f4l_smoke_duration_ms 10000
set ::f4l_session_start_ms 0
set ::f4l_session_end_ms 0
set ::f4l_event_tag F4L
set ::f4l_experiment_name EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260919
set ::f4l_contract_target_duration_ms 120000
set ::f4l_contract_hard_duration_ms 130000
set ::f4l_schedule_mode 0
set ::f4l_schedule_magic 0x46345331

# F4M is an observer-only closure run layered on the existing F4L wire image.
# It records the page sequence as observed by one reader and samples the
# existing WRS_S_LOCK trace at each Slave context.  It never requests a
# control snapshot or writes any WR/SoftPLL state.
set ::f4m_enabled 0
set ::f4m_startup_gate_timeout_ms 0
set ::f4m_startup_gate_since_ms INVALID
set ::f4m_startup_gate_seen 0
array set ::f4m_current_page {}
array set ::f4m_previous_page {}
array set ::f4m_page_publish_count {}
array set ::f4m_page_due_count {}
array set ::f4m_page_skip_count {}
array set ::f4m_page_rotation_count {}
array set ::f4m_page_transition_mismatch_count {}
array set ::f4m_first_loss_sample_count {}

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

# F4F uses the same passive WDIAGS mailbox as the existing observer, but
# records every bounded retry separately.  The source-backed writer publishes
# all ten FULL payload words between one odd/even epoch pair.  CORE deliberately
# reads only helper_error, update_count, and helper_output inside that same
# pair; fields omitted by CORE are never inferred from a previous FULL read.
proc f4f_epoch_bad {raw} {
  set value [word32 $raw]
  if {$value < 0} { return 0 }
  return [expr {$value == 0xffffffff || ($value & 1)}]
}

proc f4f_reason_string {transport_error parse_error odd_or_sentinel \
    epoch_changed arithmetic_mismatch range_mismatch accepted} {
  set reasons {}
  if {$transport_error} { lappend reasons TRANSPORT_ERROR }
  if {$parse_error} { lappend reasons PARSE_ERROR }
  if {$odd_or_sentinel} { lappend reasons ODD_OR_SENTINEL }
  if {$epoch_changed} { lappend reasons EPOCH_CHANGED }
  if {$arithmetic_mismatch} { lappend reasons ARITHMETIC_MISMATCH }
  if {$range_mismatch} { lappend reasons RANGE_MISMATCH }
  if {!$accepted && [llength $reasons] == 0} { lappend reasons CONTRACT_REJECTED }
  if {[llength $reasons] == 0} { return NONE }
  return [join $reasons ,]
}

proc f4f_measurement_attempt {hardware_name profile cycle retry_n} {
  set host_start_ms [clock milliseconds]
  set epoch_before_raw [wb_read $hardware_name 0x00100B00]
  set raw_tag NOT_MEASURED
  set raw_expected NOT_MEASURED
  set raw_freq NOT_MEASURED
  set raw_preclamp NOT_MEASURED
  set raw_helper_error NOT_MEASURED
  set raw_update_count NOT_MEASURED
  set raw_output NOT_MEASURED
  set raw_ref_accept NOT_MEASURED
  set raw_fb_accept NOT_MEASURED
  if {$profile eq "FULL"} {
    set raw_tag [wb_read $hardware_name 0x00100B04]
    set raw_expected [wb_read $hardware_name 0x00100B08]
    set raw_freq [wb_read $hardware_name 0x00100B0C]
    set raw_preclamp [wb_read $hardware_name 0x00100B10]
    set raw_helper_error [wb_read $hardware_name 0x00100B14]
    set raw_update_count [wb_read $hardware_name 0x00100B18]
    set raw_output [wb_read $hardware_name 0x00100B1C]
    set raw_ref_accept [wb_read $hardware_name 0x00100B20]
    set raw_fb_accept [wb_read $hardware_name 0x00100B24]
  } elseif {$profile eq "CORE"} {
    set raw_helper_error [wb_read $hardware_name 0x00100B14]
    set raw_update_count [wb_read $hardware_name 0x00100B18]
    set raw_output [wb_read $hardware_name 0x00100B1C]
  }
  set epoch_after_raw [wb_read $hardware_name 0x00100B00]
  set host_end_ms [clock milliseconds]
  set duration_ms [expr {$host_end_ms - $host_start_ms}]

  set measured_raw [list $epoch_before_raw $raw_helper_error \
    $raw_update_count $raw_output $epoch_after_raw]
  if {$profile eq "FULL"} {
    set measured_raw [list $epoch_before_raw $raw_tag $raw_expected $raw_freq \
      $raw_preclamp $raw_helper_error $raw_update_count $raw_output \
      $raw_ref_accept $raw_fb_accept $epoch_after_raw]
  }
  set transport_error 0
  set parse_error 0
  foreach raw $measured_raw {
    if {$raw eq "TIMEOUT"} { set transport_error 1 }
    if {![is_hex $raw]} { set parse_error 1 }
  }

  set epoch_before [word32 $epoch_before_raw]
  set epoch_after [word32 $epoch_after_raw]
  set odd_or_sentinel [expr {[f4f_epoch_bad $epoch_before_raw] || \
    [f4f_epoch_bad $epoch_after_raw] ? 1 : 0}]
  set epoch_changed 0
  if {$epoch_before >= 0 && $epoch_after >= 0 && \
      $epoch_before != $epoch_after} {
    set epoch_changed 1
  }

  set tag NOT_MEASURED
  set expected NOT_MEASURED
  set freq_error NOT_MEASURED
  set preclamp NOT_MEASURED
  set helper_error [signed32 $raw_helper_error]
  set update_count [word32 $raw_update_count]
  set helper_output [signed32 $raw_output]
  set ref_accept NOT_MEASURED
  set fb_accept NOT_MEASURED
  if {$profile eq "FULL"} {
    set tag [signed32 $raw_tag]
    set expected [signed32 $raw_expected]
    set freq_error [signed32 $raw_freq]
    set preclamp [signed32 $raw_preclamp]
    set ref_accept [word32 $raw_ref_accept]
    set fb_accept [word32 $raw_fb_accept]
  }

  set arithmetic_mismatch 0
  if {$profile eq "FULL" && [string is integer -strict $tag] && \
      [string is integer -strict $expected] && \
      [string is integer -strict $freq_error] && \
      $freq_error != ($tag - $expected)} {
    set arithmetic_mismatch 1
  }
  set range_mismatch 0
  if {[string is integer -strict $helper_output] && \
      ($helper_output < 5 || $helper_output > 65531)} {
    set range_mismatch 1
  }

  set accepted 0
  if {!$transport_error && !$parse_error && !$odd_or_sentinel && \
      !$epoch_changed && !$arithmetic_mismatch && !$range_mismatch && \
      $epoch_before >= 0 && $epoch_after >= 0 && \
      [string is integer -strict $helper_error] && \
      [string is integer -strict $update_count] && \
      [string is integer -strict $helper_output]} {
    if {$profile eq "FULL" && \
        [string is integer -strict $tag] && \
        [string is integer -strict $expected] && \
        [string is integer -strict $freq_error] && \
        [string is integer -strict $preclamp] && \
        [string is integer -strict $ref_accept] && \
        [string is integer -strict $fb_accept]} {
      set accepted 1
    } elseif {$profile eq "CORE"} {
      set accepted 1
    }
  }
  set owner_unverified 1
  set reason [f4f_reason_string $transport_error $parse_error \
    $odd_or_sentinel $epoch_changed $arithmetic_mismatch \
    $range_mismatch $accepted]
  puts [join [list STEP5_F4F_HELPER_ATTEMPT \
    "board=$hardware_name" \
    "profile=$profile" \
    "cycle=$cycle" \
    "retry_n=$retry_n" \
    "host_start_ms=$host_start_ms" \
    "host_end_ms=$host_end_ms" \
    "duration_ms=$duration_ms" \
    "raw_epoch_before=$epoch_before_raw" \
    "raw_tag_delta=$raw_tag" \
    "raw_expected_delta=$raw_expected" \
    "raw_freq_error=$raw_freq" \
    "raw_preclamp_error=$raw_preclamp" \
    "raw_helper_error=$raw_helper_error" \
    "raw_update_count=$raw_update_count" \
    "raw_helper_output=$raw_output" \
    "raw_dmtd_ref_accept_count=$raw_ref_accept" \
    "raw_dmtd_fb_accept_count=$raw_fb_accept" \
    "raw_epoch_after=$epoch_after_raw" \
    "epoch_before=$epoch_before" \
    "epoch_after=$epoch_after" \
    "tag_delta=$tag" \
    "expected_delta=$expected" \
    "freq_error=$freq_error" \
    "preclamp_error=$preclamp" \
    "helper_error=$helper_error" \
    "update_count=$update_count" \
    "helper_output=$helper_output" \
    "dmtd_ref_accept_count=$ref_accept" \
    "dmtd_fb_accept_count=$fb_accept" \
    "TRANSPORT_ERROR=$transport_error" \
    "PARSE_ERROR=$parse_error" \
    "ODD_OR_SENTINEL=$odd_or_sentinel" \
    "EPOCH_CHANGED=$epoch_changed" \
    "ARITHMETIC_MISMATCH=$arithmetic_mismatch" \
    "RANGE_MISMATCH=$range_mismatch" \
    "ACCEPTED=$accepted" \
    "OWNER_UNVERIFIED=$owner_unverified" \
    "reason=$reason"] " "]
  flush stdout
  return [list $profile 1 $host_start_ms $host_end_ms $duration_ms \
    $epoch_before_raw $raw_tag $raw_expected $raw_freq $raw_preclamp \
    $raw_helper_error $raw_update_count $raw_output $raw_ref_accept \
    $raw_fb_accept $epoch_after_raw $epoch_before $epoch_after $tag $expected \
    $freq_error $preclamp $helper_error $update_count $helper_output \
    $ref_accept $fb_accept $transport_error $parse_error $odd_or_sentinel \
    $epoch_changed $arithmetic_mismatch $range_mismatch $accepted \
    $owner_unverified $reason]
}

proc f4f_invalid_measurement_result {profile host_start_ms host_end_ms} {
  set raw [list TIMEOUT NOT_MEASURED NOT_MEASURED NOT_MEASURED \
    NOT_MEASURED TIMEOUT TIMEOUT TIMEOUT NOT_MEASURED NOT_MEASURED TIMEOUT]
  set parsed [list -1 -1 INVALID INVALID INVALID INVALID INVALID -1 \
    INVALID -1 -1]
  set flags [list 1 1 0 0 0 0 0 1 TRANSPORT_ERROR,PARSE_ERROR]
  return [concat [list $profile 1 $host_start_ms $host_end_ms \
    [expr {$host_end_ms - $host_start_ms}]] $raw $parsed $flags]
}

# -------------------------------------------------------------------------
# F4G: compact Helper/Main service-window correlation
# -------------------------------------------------------------------------

proc f4g_is_number {value} {
  return [string is integer -strict $value]
}

proc f4g_hex32 {value} {
  if {[f4g_is_number $value]} {
    return [format %08X [expr {$value & 0xffffffff}]]
  }
  if {[is_hex $value]} { return [format %08X [word32 $value]] }
  return $value
}

proc f4g_raw_low32 {value} {
  set word [low32_64 $value]
  if {$word eq "INVALID"} { return INVALID }
  return [format %08X $word]
}

proc f4g_raw_high32 {value} {
  set word [high32_64 $value]
  if {$word eq "INVALID"} { return INVALID }
  return [format %08X $word]
}

proc f4g_phy_failure_bits {valid si_config_done wr_ready core_tm_link_up \
    core_link_ok wr_rx_ready wr_tx_ready} {
  if {!$valid} { return UNKNOWN }
  set failures {}
  foreach {name value} [list \
      SI_CONFIG_DONE $si_config_done \
      WR_READY $wr_ready \
      CORE_TM_LINK_UP $core_tm_link_up \
      CORE_LINK_OK $core_link_ok \
      WR_RX_READY $wr_rx_ready \
      WR_TX_READY $wr_tx_ready] {
    if {![f4g_is_number $value]} { return UNKNOWN }
    if {$value != 1} { lappend failures $name }
  }
  if {[llength $failures] == 0} { return NONE }
  return [join $failures ","]
}

proc f4g_initialize_board {role hardware_name} {
  set ::f4g_role($hardware_name) $role
  set ::wb_toggle($hardware_name) 0
  set ::f4g_cycle_count($hardware_name) 0
  set ::f4g_context_count($hardware_name) 0
  set ::f4g_helper_core_transport_streak($hardware_name) 0
  set ::f4g_main_core_transport_streak($hardware_name) 0
  set ::f4g_wr_core_transport_streak($hardware_name) 0
  set ::f4g_helper_no_core_since_ms($hardware_name) INVALID
  set ::f4g_main_no_core_since_ms($hardware_name) INVALID
  set ::f4g_last_helper_usable_ms($hardware_name) INVALID
  set ::f4g_last_main_usable_ms($hardware_name) INVALID
  set ::f4g_last_main_update($hardware_name) INVALID
  set ::f4g_last_main_progress_ms($hardware_name) INVALID
  set ::f4g_phase_qual_streak($hardware_name) 0
  set ::f4g_phase_qualified_seen($hardware_name) 0
  set ::f4g_helper_unlock_streak($hardware_name) 0
  set ::f4g_helper_rail_streak($hardware_name) 0
  set ::f4g_freq_unlock_streak($hardware_name) 0
  set ::f4g_terminal_streak($hardware_name) 0
  set ::f4g_wr_seen_active($hardware_name) 0
  set ::f4g_generation_baseline($hardware_name) INVALID
  set ::f4g_cpu_reset_baseline($hardware_name) INVALID
  set ::f4g_wr_reset_baseline($hardware_name) INVALID
  set ::f4g_si_drop_baseline($hardware_name) INVALID
  set ::f4g_stop_reason($hardware_name) NONE
  set ::f4g_run_end_reason($hardware_name) NOT_REACHED
}

proc f4g_set_stop {reason} {
  if {$::f4g_global_stop_reason ne "NONE"} { return }
  set ::f4g_global_stop_reason $reason
  foreach hardware_name [array names ::f4g_role] {
    set ::f4g_stop_reason($hardware_name) $reason
  }
}

proc f4g_update_reset_state {hardware_name entry_probe reset_probe} {
  set boot_generation [probe_high32 $entry_probe]
  set cpu_reset_count [probe_field32 $reset_probe 16 8]
  set wr_core_reset_count [probe_field32 $reset_probe 24 8]
  set si_drop_count [probe_field32 $reset_probe 40 8]
  set valid [expr {[f4g_is_number $boot_generation] &&
    [f4g_is_number $cpu_reset_count] &&
    [f4g_is_number $wr_core_reset_count] &&
    [f4g_is_number $si_drop_count] ? 1 : 0}]
  set changed 0
  if {$valid} {
    if {$::f4g_generation_baseline($hardware_name) eq "INVALID"} {
      set ::f4g_generation_baseline($hardware_name) $boot_generation
      set ::f4g_cpu_reset_baseline($hardware_name) $cpu_reset_count
      set ::f4g_wr_reset_baseline($hardware_name) $wr_core_reset_count
      set ::f4g_si_drop_baseline($hardware_name) $si_drop_count
    } elseif {$boot_generation != $::f4g_generation_baseline($hardware_name) ||
        $cpu_reset_count != $::f4g_cpu_reset_baseline($hardware_name) ||
        $wr_core_reset_count != $::f4g_wr_reset_baseline($hardware_name) ||
        $si_drop_count != $::f4g_si_drop_baseline($hardware_name)} {
      set changed 1
      f4g_set_stop RESET_OR_GENERATION_CHANGE
    }
  }
  return [list $valid $changed $boot_generation $cpu_reset_count \
    $wr_core_reset_count $si_drop_count]
}

# Read only the source-backed Helper CORE.  This function is called while the
# F4G context owns the one active source-probe reader.  Every failed retry is
# emitted with its raw words; an epoch-only rejection is never classified as a
# transport failure.
proc f4g_helper_core_attempt {hardware_name cycle retry_n} {
  set host_start_ms [clock milliseconds]
  set raw_epoch_before [wb_read $hardware_name 0x00100B00]
  set raw_helper_error [wb_read $hardware_name 0x00100B14]
  set raw_update_count [wb_read $hardware_name 0x00100B18]
  set raw_helper_output [wb_read $hardware_name 0x00100B1C]
  set raw_epoch_after [wb_read $hardware_name 0x00100B00]
  set host_end_ms [clock milliseconds]

  set transport_error 0
  set parse_error 0
  foreach raw [list $raw_epoch_before $raw_helper_error $raw_update_count \
      $raw_helper_output $raw_epoch_after] {
    if {$raw eq "TIMEOUT"} { set transport_error 1 }
    if {![is_hex $raw]} { set parse_error 1 }
  }
  set epoch_before [word32 $raw_epoch_before]
  set epoch_after [word32 $raw_epoch_after]
  set odd_or_sentinel [expr {[f4f_epoch_bad $raw_epoch_before] ||
    [f4f_epoch_bad $raw_epoch_after] ? 1 : 0}]
  set epoch_changed [expr {$epoch_before >= 0 && $epoch_after >= 0 &&
    $epoch_before != $epoch_after ? 1 : 0}]
  set helper_error [signed32 $raw_helper_error]
  set update_count [word32 $raw_update_count]
  set helper_output [signed32 $raw_helper_output]
  set range_mismatch [expr {[f4g_is_number $helper_output] &&
    ($helper_output < 5 || $helper_output > 65531) ? 1 : 0}]
  set accepted [expr {!$transport_error && !$parse_error &&
    !$odd_or_sentinel && !$epoch_changed && !$range_mismatch &&
    $epoch_before >= 0 && $epoch_after >= 0 &&
    [f4g_is_number $helper_error] && [f4g_is_number $update_count] &&
    [f4g_is_number $helper_output] ? 1 : 0}]
  set reason [f4f_reason_string $transport_error $parse_error \
    $odd_or_sentinel $epoch_changed 0 $range_mismatch $accepted]
  puts [join [list STEP5_F4G_HELPER_ATTEMPT \
    "board=$hardware_name" "cycle=$cycle" "retry_n=$retry_n" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "RAW_EPOCH_BEFORE=$raw_epoch_before" \
    "RAW_HELPER_ERROR=$raw_helper_error" \
    "RAW_UPDATE_COUNT=$raw_update_count" \
    "RAW_HELPER_OUTPUT=$raw_helper_output" \
    "RAW_EPOCH_AFTER=$raw_epoch_after" \
    "EPOCH_BEFORE=$epoch_before" "EPOCH_AFTER=$epoch_after" \
    "HELPER_ERROR=$helper_error" "UPDATE_COUNT=$update_count" \
    "HELPER_OUTPUT=$helper_output" "TRANSPORT_ERROR=$transport_error" \
    "PARSE_ERROR=$parse_error" "ODD_OR_SENTINEL=$odd_or_sentinel" \
    "EPOCH_CHANGED=$epoch_changed" "RANGE_MISMATCH=$range_mismatch" \
    "ACCEPTED=$accepted" "OWNER_UNVERIFIED=1" \
    "DYNAMIC_OWNER=NOT_AVAILABLE" "reason=$reason"] " "]
  flush stdout
  return [list $accepted $host_start_ms $host_end_ms $raw_epoch_before \
    $raw_epoch_after $epoch_before $epoch_after $helper_error $update_count \
    $helper_output $transport_error $parse_error $odd_or_sentinel \
    $epoch_changed $reason $raw_helper_error $raw_update_count \
    $raw_helper_output]
}

proc f4g_capture_helper_core {hardware_name cycle} {
  set attempts 0
  set final_result [list 0 0 0 TIMEOUT TIMEOUT -1 -1 INVALID INVALID \
    INVALID 1 1 0 0 TRANSPORT_ERROR TIMEOUT TIMEOUT TIMEOUT]
  set all_transport 1
  for {set retry_n 1} {$retry_n <= 8} {incr retry_n} {
    set attempts $retry_n
    set final_result [f4g_helper_core_attempt $hardware_name $cycle $retry_n]
    if {![lindex $final_result 10] && ![lindex $final_result 11]} {
      set all_transport 0
    }
    if {[lindex $final_result 0]} { break }
    after 1
  }
  return [list $attempts $final_result $all_transport]
}

proc f4g_capture_main_core {hardware_name cycle} {
  set host_start_ms [clock milliseconds]
  set trace [read_main_trace $hardware_name]
  set host_end_ms [clock milliseconds]
  foreach {trace_ok epoch dref dout freq_error prelock_error pi_unclamped \
      pi_output clamp_side lock_count lock_count_max kp ki shift bias \
      update_count threshold lock_samples state y_min y_max anti_windup \
      pi_x magic} $trace break
  set core_valid [expr {$trace_ok && [f4g_is_number $magic] && $magic == 1 ? 1 : 0}]
  set fresh 0
  set ambiguous 0
  set delta INVALID
  if {$core_valid && [f4g_is_number $update_count]} {
    set progress_elapsed_ms [expr {$host_end_ms - $::f4g_session_start_ms}]
    if {$::f4g_last_main_update($hardware_name) eq "INVALID"} {
      set ::f4g_last_main_progress_ms($hardware_name) $progress_elapsed_ms
    } else {
      set delta [counter_delta $::f4g_last_main_update($hardware_name) \
        $update_count 32]
      if {$delta eq "INVALID" || $delta > 0x7fffffff} {
        set delta INVALID
        set ambiguous 1
      } elseif {$delta > 0} {
        set fresh 1
        set ::f4g_last_main_progress_ms($hardware_name) $progress_elapsed_ms
      }
    }
    set ::f4g_last_main_update($hardware_name) $update_count
  }
  puts [join [list STEP5_F4G_MAIN_CORE \
    "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "MAIN_CORE_VALID=$core_valid" "MAIN_TRACE_VALID=$trace_ok" \
    "MAIN_EPOCH_RAW_BEFORE=$::main_trace_epoch_before_raw($hardware_name)" \
    "MAIN_EPOCH_RAW_AFTER=$::main_trace_epoch_after_raw($hardware_name)" \
    "MAIN_EPOCH=$epoch" "MAIN_SAMPLE_N=$update_count" \
    "MAIN_SAMPLE_N_DELTA=$delta" "MAIN_SAMPLE_N_ADVANCED=$fresh" \
    "MAIN_SAMPLE_N_AMBIGUOUS=$ambiguous" \
    "MAIN_FREQ_ERROR=$freq_error" "MAIN_PI_X=$pi_x" \
    "MAIN_PI_OUTPUT=$pi_output" "MAIN_PI_CLAMP_SIDE=$clamp_side" \
    "MAIN_STATE=$state" "MAIN_MAGIC=$magic" \
    "MAIN_FREQ_ERROR_RAW=[f4g_hex32 $freq_error]" \
    "MAIN_PI_X_RAW=[f4g_hex32 $pi_x]" \
    "MAIN_PI_OUTPUT_RAW=[f4g_hex32 $pi_output]" \
    "MAIN_PI_CLAMP_SIDE_RAW=[f4g_hex32 $clamp_side]" \
    "MAIN_SAMPLE_N_RAW=[f4g_hex32 $update_count]" \
    "MAIN_STATE_RAW=[f4g_hex32 $state]" \
    "MAIN_TRANSPORT_FAILURE=0"] " "]
  flush stdout
  return [list $core_valid $fresh $ambiguous $delta $host_start_ms \
    $host_end_ms $update_count $pi_x $pi_output $clamp_side $freq_error \
    $state $epoch $magic $trace_ok]
}

proc f4g_emit_main_detector {hardware_name cycle} {
  set host_start_ms [clock milliseconds]
  set detector [read_main_detector_block $hardware_name]
  set host_end_ms [clock milliseconds]
  foreach {valid stable state_raw limits_raw phase_limits_raw enabled locked \
      freq_locked phase_locked freq_lock_count phase_lock_count freq_threshold \
      freq_lock_samples phase_threshold phase_lock_samples} $detector break
  puts [join [list STEP5_F4G_MAIN_DETECTOR \
    "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "MAIN_DETECTOR_VALID=$valid" "MAIN_DETECTOR_STABLE=$stable" \
    "MAIN_STATE_RAW=$state_raw" "MAIN_LIMITS_RAW=$limits_raw" \
    "MAIN_PHASE_LIMITS_RAW=$phase_limits_raw" "MAIN_ENABLED=$enabled" \
    "MAIN_LOCKED=$locked" "MAIN_FREQ_LOCKED=$freq_locked" \
    "MAIN_PHASE_LOCKED=$phase_locked" "MAIN_FREQ_LOCK_COUNT=$freq_lock_count" \
    "MAIN_PHASE_LOCK_COUNT=$phase_lock_count" \
    "MAIN_FREQ_THRESHOLD=$freq_threshold" \
    "MAIN_FREQ_LOCK_SAMPLES=$freq_lock_samples" \
    "MAIN_PHASE_THRESHOLD=$phase_threshold" \
    "MAIN_PHASE_LOCK_SAMPLES=$phase_lock_samples"] " "]
  flush stdout
  return [list $valid $stable $enabled $locked $freq_locked $phase_locked \
    $freq_lock_count $phase_lock_count $freq_threshold $freq_lock_samples \
    $phase_threshold $phase_lock_samples]
}

proc f4g_emit_helper_state {hardware_name cycle} {
  set host_start_ms [clock milliseconds]
  set state [wb_read $hardware_name 0x00100ABC]
  set limits [wb_read $hardware_name 0x00100AC0]
  set host_end_ms [clock milliseconds]
  set valid [expr {[is_hex $state] && [is_hex $limits] ? 1 : 0}]
  set locked [field32 $state 0 1]
  set lock_count [field32 $state 16 16]
  set threshold [field32 $limits 0 16]
  set lock_samples [field32 $limits 16 16]
  puts [join [list STEP5_F4G_HELPER_STATE \
    "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "HELPER_STATE_VALID=$valid" "HELPER_STATE_RAW=$state" \
    "HELPER_LIMITS_RAW=$limits" "HELPER_LOCKED=$locked" \
    "HELPER_LOCK_COUNT=$lock_count" "HELPER_THRESHOLD=$threshold" \
    "HELPER_LOCK_SAMPLES=$lock_samples"] " "]
  flush stdout
  return [list $valid $locked $lock_count $threshold $lock_samples $state $limits]
}

proc f4g_read_l2_word {probe} {
  set host_start_ms [clock milliseconds]
  set raw [probe_read $probe]
  set host_end_ms [clock milliseconds]
  return [list $raw $host_start_ms $host_end_ms [is_hex $raw]]
}

proc f4g_emit_l2_word {hardware_name cycle probe name result} {
  foreach {raw host_start_ms host_end_ms valid} $result break
  puts [join [list STEP5_F4G_L2_WORD \
    "board=$hardware_name" "cycle=$cycle" "probe=$probe" "name=$name" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "RAW=$raw" "VALID=$valid" "WIDTH_BITS=32" \
    "PACKING=MAIN_LOW32_HELPER_HIGH32" \
    "MULTI_PROBE_ATOMICITY=NOT_AVAILABLE"] " "]
  if {$name eq "START" || $name eq "COMPLETED" || $name eq "FAILED"} {
    set main_raw [f4g_raw_low32 $raw]
    set helper_raw [f4g_raw_high32 $raw]
    set main_value [low32_64 $raw]
    set helper_value [high32_64 $raw]
    puts [join [list STEP5_F4G_SERVICE_COUNTER \
      "board=$hardware_name" "cycle=$cycle" "probe=$probe" \
      "COUNTER_GROUP=$name" "host_start_ms=$host_start_ms" \
      "host_end_ms=$host_end_ms" "RAW_PACKED=$raw" \
      "MAIN_RAW=$main_raw" "HELPER_RAW=$helper_raw" \
      "MAIN_VALUE=$main_value" "HELPER_VALUE=$helper_value" \
      "VALID=$valid" "COUNTER_WIDTH_BITS=32" \
      "SOURCE_SEMANTICS=VERIFIED" "READ_ATOMICITY=WORD_ONLY" \
      "DELTA_POLICY=SAME_FIELD_TRUSTED_READS_ONLY"] " "]
  }
  flush stdout
}

proc f4g_emit_service_demand {hardware_name cycle status_result pending_result} {
  foreach {status_raw status_start_ms status_end_ms status_valid} $status_result break
  foreach {pending_raw pending_start_ms pending_end_ms pending_valid} $pending_result break
  set main_pending [field64 $status_raw 0 1]
  set helper_pending [field64 $status_raw 1 1]
  set tx_active [field64 $status_raw 2 1]
  set owner_main [field64 $status_raw 3 1]
  set ack [field64 $status_raw 4 1]
  set timeout [field64 $status_raw 5 1]
  set dco_error [field64 $status_raw 7 1]
  set reason [field64 $status_raw 8 8]
  set rt_state [field64 $status_raw 16 3]
  set status_time [high32_64 $status_raw]
  set main_pending_count [low32_64 $pending_raw]
  set helper_pending_count [high32_64 $pending_raw]
  puts [join [list STEP5_F4G_SERVICE_DEMAND \
    "board=$hardware_name" "cycle=$cycle" \
    "STATUS_HOST_START_MS=$status_start_ms" \
    "STATUS_HOST_END_MS=$status_end_ms" "STATUS_RAW=$status_raw" \
    "STATUS_VALID=$status_valid" "PENDING_HOST_START_MS=$pending_start_ms" \
    "PENDING_HOST_END_MS=$pending_end_ms" "PENDING_RAW=$pending_raw" \
    "PENDING_VALID=$pending_valid" "MAIN_PENDING=$main_pending" \
    "HELPER_PENDING=$helper_pending" "TX_ACTIVE=$tx_active" \
    "OWNER_MAIN=$owner_main" "ACK=$ack" "TIMEOUT=$timeout" \
    "DCO_ERROR=$dco_error" "REASON=$reason" "RT_STATE=$rt_state" \
    "STATUS_TIME=$status_time" "MAIN_PENDING_COUNT=$main_pending_count" \
    "HELPER_PENDING_COUNT=$helper_pending_count" \
    "ADMISSION_ELIGIBLE=UNKNOWN" \
    "DEMAND_RESIDUAL_PRESENT=UNKNOWN"] " "]
  flush stdout
}

proc f4g_emit_helper_position {hardware_name cycle} {
  set host_start_ms [clock milliseconds]
  set observation [read_position_observability]
  set tracker_raw [probe_read 39]
  set host_end_ms [clock milliseconds]
  foreach {valid accounting_before_raw accounting_after_raw position_raw \
      bootstrap_raw actuator_raw position_epoch target applied finc fdec \
      normal_completed dco_step bootstrap_completed bootstrap_done forced_finc \
      forced_fdec} $observation break
  set tracker_word [word64 $tracker_raw]
  set normal_request [expr {$tracker_word < 0 ? "INVALID" : (($tracker_word >> 32) & 0xffff)}]
  set residual UNKNOWN
  if {$valid && [f4g_is_number $target] && [f4g_is_number $applied]} {
    set residual [expr {$target != ($applied & 0xffff) ? 1 : 0}]
  }
  puts [join [list STEP5_F4G_HELPER_POSITION \
    "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "POSITION_VALID=$valid" "ACCOUNTING_BEFORE_RAW=$accounting_before_raw" \
    "ACCOUNTING_AFTER_RAW=$accounting_after_raw" "POSITION_RAW=$position_raw" \
    "BOOTSTRAP_RAW=$bootstrap_raw" "ACTUATOR_RAW=$actuator_raw" \
    "POSITION_EPOCH=$position_epoch" "HELPER_TARGET_CODE=$target" \
    "HELPER_APPLIED_CODE=$applied" "HELPER_RESIDUAL_PRESENT=$residual" \
    "HELPER_FINC=$finc" "HELPER_FDEC=$fdec" \
    "HELPER_NORMAL_REQUEST=$normal_request" \
    "HELPER_NORMAL_COMPLETED=$normal_completed" "DCO_STEP=$dco_step" \
    "HELPER_BOOTSTRAP_COMPLETED=$bootstrap_completed" \
    "HELPER_BOOTSTRAP_DONE=$bootstrap_done" "HELPER_FORCED_FINC=$forced_finc" \
    "HELPER_FORCED_FDEC=$forced_fdec" "TRACKER_RAW=$tracker_raw"] " "]
  flush stdout
  return [list $valid $residual $normal_request $normal_completed \
    $bootstrap_done $target $applied]
}

proc f4g_emit_wr_core {role hardware_name cycle prefix} {
  set host_start_ms [clock milliseconds]
  # WDIAGS_CTRL and the direct WR_SYNC probe are different interfaces.  F4G
  # keeps the historical CTRL decoder; F4H selects instance 0 for the
  # physical WR status predicate and records both sources independently.
  set wdiags_ctrl [wb_read $hardware_name 0x00100A04]
  set sstat [wb_read $hardware_name 0x00100A08]
  set ptp_meta [wb_read $hardware_name 0x00100A5C]
  set wr_failure [wb_read $hardware_name 0x00100A6C]
  set wr_state [wb_read $hardware_name 0x00100A4C]
  set pstat [wb_read $hardware_name 0x00100A0C]
  set lock_result [wb_read $hardware_name 0x00100A8C]
  set spll_state [wb_read $hardware_name 0x00100AA0]
  set phy_status_probe0 NOT_MEASURED
  if {$::f4g_phy_status_source eq "JTAG_PROBE0"} {
    set phy_status_probe0 [probe_read 0]
  }
  set entry_probe [probe_read 26]
  set reset_probe [probe_read 27]
  set host_end_ms [clock milliseconds]
  set direct_values [list $wdiags_ctrl $sstat $ptp_meta $wr_failure $wr_state \
    $pstat $lock_result $spll_state $entry_probe $reset_probe]
  if {$::f4g_phy_status_source eq "JTAG_PROBE0"} {
    lappend direct_values $phy_status_probe0
  }
  set direct_valid 1
  set transport_failure 0
  foreach value $direct_values {
    if {$value eq "TIMEOUT"} { set transport_failure 1 }
    if {![is_hex $value]} { set direct_valid 0 }
  }
  set role_identity_valid [f4e_identity_role_valid $role $hardware_name]
  set reset_state [f4g_update_reset_state $hardware_name $entry_probe $reset_probe]
  foreach {reset_valid reset_changed boot_generation cpu_reset_count \
      wr_core_reset_count si_drop_count} $reset_state break

  set wdiags_ctrl_valid [is_hex $wdiags_ctrl]
  set wdiags_ctrl_data_valid [field32 $wdiags_ctrl 0 1]
  set wdiags_ctrl_data_snapshot [field32 $wdiags_ctrl 8 1]
  set phy_status_valid [is_hex $phy_status_probe0]
  if {$::f4g_phy_status_source eq "JTAG_PROBE0"} {
    set phy_decode_source $phy_status_probe0
  } else {
    # Preserve the historical F4G decoder exactly for old captures.
    set phy_decode_source $wdiags_ctrl
    set phy_status_valid $wdiags_ctrl_valid
  }
  set si_config_done [field32 $phy_decode_source 0 1]
  set wr_ready [field32 $phy_decode_source 1 1]
  set core_tm_link_up [field32 $phy_decode_source 2 1]
  set core_link_ok [field32 $phy_decode_source 3 1]
  set wr_rx_ready [field32 $phy_decode_source 6 1]
  set wr_tx_ready [field32 $phy_decode_source 7 1]
  set cpu_reset_n [field32 $phy_decode_source 15 1]
  set phy_rx_locked_to_data NOT_MEASURED
  set phy_rx_locked_to_ref NOT_MEASURED
  if {$::f4g_phy_status_source eq "JTAG_PROBE0"} {
    set phy_rx_locked_to_data [field64 $phy_status_probe0 32 1]
    set phy_rx_locked_to_ref [field64 $phy_status_probe0 33 1]
  }
  set phy_link_usable 0
  if {$phy_status_valid && [f4g_is_number $si_config_done] &&
      [f4g_is_number $wr_ready] && [f4g_is_number $core_tm_link_up] &&
      [f4g_is_number $core_link_ok] && [f4g_is_number $wr_rx_ready] &&
      [f4g_is_number $wr_tx_ready] && $si_config_done == 1 &&
      $wr_ready == 1 && $core_tm_link_up == 1 && $core_link_ok == 1 &&
      $wr_rx_ready == 1 && $wr_tx_ready == 1} {
    set phy_link_usable 1
  }
  set phy_gate_failure_bits [f4g_phy_failure_bits $phy_status_valid \
    $si_config_done $wr_ready $core_tm_link_up $core_link_ok \
    $wr_rx_ready $wr_tx_ready]
  set ptp_state [field32 $ptp_meta 0 8]
  set pd_state [field32 $ptp_meta 8 8]
  set ext_state [field32 $ptp_meta 16 8]
  set wrc_mode [field32 $ptp_meta 24 8]
  set wr_state_value [field32 $wr_state 11 4]
  set wr_next_state [field32 $wr_state 15 4]
  set pstat_link [field32 $pstat 0 1]
  set pstat_locked [field32 $pstat 1 1]
  set spll_delock_count [field32 $spll_state 24 8]
  set wr_disable_valid [field32 $wr_failure 11 1]
  set wr_failure_reason [field32 $lock_result 9 7]
  if {$direct_valid && [f4g_is_number $wr_state_value] &&
      $wr_state_value > 0} {
    set ::f4g_wr_seen_active($hardware_name) 1
  }
  set terminal 0
  if {$direct_valid} {
    if {$wr_disable_valid == 1} { set terminal 1 }
    if {$wr_failure_reason >= 1 && $wr_failure_reason <= 7} { set terminal 1 }
    if {$::f4g_wr_seen_active($hardware_name) &&
        (($pd_state == 4) || ($ext_state == 0) || ($wr_state_value == 0))} {
      set terminal 1
    }
  }
  if {$terminal} {
    incr ::f4g_terminal_streak($hardware_name)
  } else {
    set ::f4g_terminal_streak($hardware_name) 0
  }
  if {$::f4g_terminal_streak($hardware_name) >= 2} {
    f4g_set_stop WR_SESSION_ENDED
  }
  set core_data_valid 1
  if {$::f4g_phy_status_source eq "JTAG_PROBE0"} {
    # A valid direct probe is physical evidence, but CTRL DATA_VALID remains
    # an independent diagnostic-data gate.  Do not manufacture WR_CORE_VALID
    # from a good probe when the WDIAGS control word says its snapshot is not
    # valid.
    set core_data_valid [expr {$wdiags_ctrl_data_valid == 1 ? 1 : 0}]
  }
  set core_valid [expr {$direct_valid && $role_identity_valid &&
    $reset_valid && $core_data_valid ? 1 : 0}]
  set phy_source_id [expr {$role eq "MASTER" ? "WR_SYNC_MASTER" : "WR_SYNC_SLAVE"}]
  puts [join [list $prefix \
    "role=$role" "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "WR_CORE_VALID=$core_valid" "DIRECT_VALID=$direct_valid" \
    "TRANSPORT_FAILURE=$transport_failure" \
    "ROLE_IDENTITY_VALID=$role_identity_valid" \
    "STATUS_RAW=$wdiags_ctrl" "STATUS_VALID=$wdiags_ctrl_valid" \
    "WDIAGS_CTRL_RAW=$wdiags_ctrl" "WDIAGS_CTRL_VALID=$wdiags_ctrl_valid" \
    "WDIAGS_CTRL_DATA_VALID=$wdiags_ctrl_data_valid" \
    "WDIAGS_CTRL_DATA_SNAPSHOT=$wdiags_ctrl_data_snapshot" \
    "WDIAGS_CTRL_ADDR=0x00100A04" "SSTAT_RAW=$sstat" \
    "PTP_META_RAW=$ptp_meta" "WR_FAILURE_RAW=$wr_failure" \
    "WR_STATE_RAW=$wr_state" "PSTAT_RAW=$pstat" \
    "LOCK_RESULT_RAW=$lock_result" "SPLL_STATE_RAW=$spll_state" \
    "ENTRY_PROBE_RAW=$entry_probe" "RESET_PROBE_RAW=$reset_probe" \
    "RESET_PROBE_SOURCE=JTAG_PROBE26_27" "SI_CONFIG_DONE=$si_config_done" \
    "WR_READY=$wr_ready" "CORE_TM_LINK_UP=$core_tm_link_up" \
    "CORE_LINK_OK=$core_link_ok" "WR_RX_READY=$wr_rx_ready" \
    "WR_TX_READY=$wr_tx_ready" "CPU_RESET_N=$cpu_reset_n" \
    "PHY_STATUS_PROBE0_RAW=$phy_status_probe0" \
    "PHY_STATUS_VALID=$phy_status_valid" \
    "PHY_STATUS_SOURCE=$::f4g_phy_status_source" \
    "PHY_STATUS_SOURCE_ID=$phy_source_id" "PHY_STATUS_INSTANCE=0" \
    "PHY_STATUS_WIDTH_BITS=64" "PHY_GATE_REQUIRED_MASK=000000CF" \
    "PHY_GATE_FAILURE_BITS=$phy_gate_failure_bits" \
    "PHY_RX_LOCKED_TO_DATA=$phy_rx_locked_to_data" \
    "PHY_RX_LOCKED_TO_REF=$phy_rx_locked_to_ref" \
    "WR_CORE_DATA_VALID=$core_data_valid" \
    "PHY_LINK_USABLE=$phy_link_usable" "PTP_STATE=$ptp_state" \
    "PD_STATE=$pd_state" "EXT_STATE=$ext_state" "WRC_MODE=$wrc_mode" \
    "CURRENT_WR_STATE=$wr_state_value" "WR_NEXT_STATE=$wr_next_state" \
    "PSTAT_ADDR=0x00100A0C" "PSTAT_LINK=$pstat_link" \
    "PSTAT_LOCKED=$pstat_locked" "SPLL_DELOCK_COUNT=$spll_delock_count" \
    "BOOT_GENERATION=$boot_generation" "CPU_RESET_COUNT=$cpu_reset_count" \
    "WR_CORE_RESET_COUNT=$wr_core_reset_count" \
    "SI_CONFIG_DROP_COUNT=$si_drop_count" "RESET_FIELDS_VALID=$reset_valid" \
    "RESET_CHANGED=$reset_changed" "TERMINAL=$terminal" \
    "TERMINAL_STREAK=$::f4g_terminal_streak($hardware_name)" \
    "WR_FAILURE_REASON=$wr_failure_reason" "WR_DISABLE_VALID=$wr_disable_valid" \
    "STOP_REASON=$::f4g_global_stop_reason"] " "]
  flush stdout
  return [list $core_valid $terminal $phy_link_usable $wr_state_value \
    $pstat_locked $role_identity_valid $reset_valid $reset_changed \
    $transport_failure]
}

proc f4g_update_core_health {hardware_name elapsed_ms helper_accepted \
    helper_transport_failure main_core_valid main_transport_failure \
    wr_core_valid wr_transport_failure {main_startup_waiting 0}} {
  if {$helper_accepted} {
    set ::f4g_helper_core_transport_streak($hardware_name) 0
    set ::f4g_last_helper_usable_ms($hardware_name) $elapsed_ms
  } elseif {$helper_transport_failure} {
    incr ::f4g_helper_core_transport_streak($hardware_name)
    if {$::f4g_helper_core_transport_streak($hardware_name) >= 3} {
      f4g_set_stop DATA_UNRESOLVED
    }
  }
  if {$main_core_valid} {
    set ::f4g_main_core_transport_streak($hardware_name) 0
    set ::f4g_last_main_usable_ms($hardware_name) $elapsed_ms
  } elseif {$main_transport_failure} {
    incr ::f4g_main_core_transport_streak($hardware_name)
    if {$::f4g_main_core_transport_streak($hardware_name) >= 3} {
      f4g_set_stop DATA_UNRESOLVED
    }
  }
  if {$wr_core_valid} {
    set ::f4g_wr_core_transport_streak($hardware_name) 0
  } elseif {$wr_transport_failure} {
    incr ::f4g_wr_core_transport_streak($hardware_name)
    if {$::f4g_wr_core_transport_streak($hardware_name) >= 3} {
      f4g_set_stop DATA_UNRESOLVED
    }
  }
  if {$::f4g_helper_no_core_since_ms($hardware_name) eq "INVALID"} {
    set ::f4g_helper_no_core_since_ms($hardware_name) $elapsed_ms
  }
  if {$::f4g_main_no_core_since_ms($hardware_name) eq "INVALID"} {
    set ::f4g_main_no_core_since_ms($hardware_name) $elapsed_ms
  }
  if {$::f4g_last_helper_usable_ms($hardware_name) ne "INVALID" &&
      $elapsed_ms - $::f4g_last_helper_usable_ms($hardware_name) >= 10000} {
    f4g_set_stop DATA_UNRESOLVED
  } elseif {$::f4g_last_helper_usable_ms($hardware_name) eq "INVALID" &&
      $elapsed_ms - $::f4g_helper_no_core_since_ms($hardware_name) >= 10000} {
    f4g_set_stop DATA_UNRESOLVED
  }
  if {!$main_startup_waiting} {
    if {$::f4g_last_main_usable_ms($hardware_name) ne "INVALID" &&
        $elapsed_ms - $::f4g_last_main_usable_ms($hardware_name) >= 10000} {
      f4g_set_stop DATA_UNRESOLVED
    } elseif {$::f4g_last_main_usable_ms($hardware_name) eq "INVALID" &&
        $elapsed_ms - $::f4g_main_no_core_since_ms($hardware_name) >= 10000} {
      f4g_set_stop DATA_UNRESOLVED
    }
  } else {
    # Before Helper lock and Main enable, an absent F4L frame is an expected
    # startup state, not a transport failure. Keep the no-core watchdog from
    # converting that startup state into DATA_UNRESOLVED.
    set ::f4g_main_no_core_since_ms($hardware_name) $elapsed_ms
    set ::f4g_last_main_usable_ms($hardware_name) INVALID
  }
}

proc f4g_update_phase_window {hardware_name helper_valid helper_locked \
    helper_fresh helper_output detector_valid detector_enabled \
    detector_freq_locked wr_valid phy_link_usable terminal elapsed_ms} {
  set current_qualified [expr {$helper_valid && $helper_locked eq "1" &&
    $detector_valid && $detector_enabled eq "1" &&
    $detector_freq_locked eq "1" && $wr_valid && $phy_link_usable &&
    !$terminal ? 1 : 0}]
  if {$current_qualified} {
    incr ::f4g_phase_qual_streak($hardware_name)
  } else {
    set ::f4g_phase_qual_streak($hardware_name) 0
  }
  if {$::f4g_phase_qual_streak($hardware_name) >= 2} {
    set ::f4g_phase_qualified_seen($hardware_name) 1
  }
  set phase_qualified [expr {$current_qualified &&
    $::f4g_phase_qualified_seen($hardware_name) ? 1 : 0}]

  # These are post-entry regression guards.  They are deliberately not used
  # to reject a pre-entry frame and phase=0 is not itself a rejection reason.
  if {$::f4g_phase_qualified_seen($hardware_name)} {
    if {$helper_valid && $helper_locked eq "0"} {
      incr ::f4g_helper_unlock_streak($hardware_name)
    } elseif {$helper_valid && $helper_locked eq "1"} {
      set ::f4g_helper_unlock_streak($hardware_name) 0
    }
    if {$helper_valid && $helper_fresh && [f4g_is_number $helper_output] &&
        ($helper_output <= 5 || $helper_output >= 65531)} {
      incr ::f4g_helper_rail_streak($hardware_name)
    } elseif {$helper_valid && $helper_fresh &&
        [f4g_is_number $helper_output]} {
      set ::f4g_helper_rail_streak($hardware_name) 0
    }
    if {$detector_valid && $detector_freq_locked eq "0"} {
      incr ::f4g_freq_unlock_streak($hardware_name)
    } elseif {$detector_valid && $detector_freq_locked eq "1"} {
      set ::f4g_freq_unlock_streak($hardware_name) 0
    }
    if {$::f4g_helper_unlock_streak($hardware_name) >= 3 ||
        $::f4g_helper_rail_streak($hardware_name) >= 3} {
      f4g_set_stop HELPER_REGRESSION
    } elseif {$::f4g_freq_unlock_streak($hardware_name) >= 3} {
      f4g_set_stop FREQ_REGRESSION
    }
    if {$::f4g_last_main_progress_ms($hardware_name) ne "INVALID" &&
        $elapsed_ms - $::f4g_last_main_progress_ms($hardware_name) >= 10000} {
      f4g_set_stop MAIN_UPDATE_STALL
    }
  }
  return [list $current_qualified $phase_qualified \
    $::f4g_phase_qual_streak($hardware_name) \
    $::f4g_phase_qualified_seen($hardware_name) \
    $::f4g_helper_unlock_streak($hardware_name) \
    $::f4g_helper_rail_streak($hardware_name) \
    $::f4g_freq_unlock_streak($hardware_name)]
}

proc f4g_emit_slave_context {hardware_name device_name cycle elapsed_ms} {
  set context_host_start [clock milliseconds]
  set probe_started 0
  set helper_attempts 0
  set helper_result [list 0 0 0 TIMEOUT TIMEOUT -1 -1 INVALID INVALID \
    INVALID 1 1 0 0 TRANSPORT_ERROR TIMEOUT TIMEOUT TIMEOUT]
  set helper_all_transport 1
  set helper_accepted 0
  set helper_fresh 0
  set helper_update INVALID
  set helper_delta INVALID
  set helper_state_valid 0
  set helper_locked INVALID
  set main_core_valid 0
  set main_fresh 0
  set main_ambiguous 0
  set main_delta INVALID
  set main_update INVALID
  set detector_valid 0
  set detector_enabled INVALID
  set detector_freq_locked INVALID
  set detector_phase_locked INVALID
  set helper_residual UNKNOWN
  set normal_request INVALID
  set normal_completed INVALID
  set bootstrap_done INVALID
  set wr_core_valid 0
  set terminal 0
  set phy_link_usable 0
  set wr_state_value INVALID
  set pstat_locked INVALID
  set wr_transport_failure 1
  set context_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name

    # Fixed order: Helper CORE, Helper state, Main CORE, detector, position,
    # individually timed L2 words, and finally WR core. All reads share this
    # one active source-probe lifecycle.
    set helper_capture [f4g_capture_helper_core $hardware_name $cycle]
    set helper_attempts [lindex $helper_capture 0]
    set helper_result [lindex $helper_capture 1]
    set helper_all_transport [lindex $helper_capture 2]
    set helper_accepted [lindex $helper_result 0]
    set helper_fresh 0
    set helper_update [lindex $helper_result 8]
    if {$helper_accepted} {
      if {$::f4g_last_helper_usable_ms($hardware_name) ne "INVALID"} {
        set helper_delta [counter_delta $::f4g_last_helper_update($hardware_name) \
          $helper_update 32]
      } else {
        set helper_delta INVALID
      }
      # The helper capture's update count is kept in the same compact CORE
      # contract. Use an independent last value for freshness.
      if {![info exists ::f4g_last_helper_update($hardware_name)] ||
          $::f4g_last_helper_update($hardware_name) eq "INVALID"} {
        set helper_delta INVALID
      } else {
        set helper_delta [counter_delta \
          $::f4g_last_helper_update($hardware_name) $helper_update 32]
        if {$helper_delta ne "INVALID" && $helper_delta <= 0x7fffffff &&
            $helper_delta > 0} { set helper_fresh 1 }
      }
      set ::f4g_last_helper_update($hardware_name) $helper_update
    }
    set helper_state [f4g_emit_helper_state $hardware_name $cycle]
    foreach {helper_state_valid helper_locked helper_lock_count \
        helper_threshold helper_lock_samples helper_state_raw \
        helper_limits_raw} $helper_state break
    set main_result [f4g_capture_main_core $hardware_name $cycle]
    foreach {main_core_valid main_fresh main_ambiguous main_delta \
        main_host_start main_host_end main_update main_pi_x main_pi_output \
        main_clamp_side main_freq_error main_state main_epoch main_magic \
        main_trace_valid} $main_result break
    set detector_result [f4g_emit_main_detector $hardware_name $cycle]
    foreach {detector_valid detector_stable detector_enabled detector_locked \
        detector_freq_locked detector_phase_locked detector_freq_count \
        detector_phase_count detector_freq_threshold detector_freq_samples \
        detector_phase_threshold detector_phase_samples} $detector_result break
    set position_result [f4g_emit_helper_position $hardware_name $cycle]
    foreach {position_valid helper_residual normal_request normal_completed \
        bootstrap_done helper_target helper_applied} $position_result break

    set status_result [f4g_read_l2_word 52]
    f4g_emit_l2_word $hardware_name $cycle 52 STATUS $status_result
    set pending_result [f4g_read_l2_word 53]
    f4g_emit_l2_word $hardware_name $cycle 53 PENDING $pending_result
    f4g_emit_service_demand $hardware_name $cycle $status_result $pending_result
    foreach {l2_probe l2_name} {54 START 55 COMPLETED 56 FAILED \
        57 MAX_WAIT 58 CURRENT_WAIT 59 LATENCY 60 FAILURE 61 FIRST_LOSS} {
      set l2_result [f4g_read_l2_word $l2_probe]
      f4g_emit_l2_word $hardware_name $cycle $l2_probe $l2_name $l2_result
    }
    set wr_result [f4g_emit_wr_core SLAVE $hardware_name $cycle \
      STEP5_F4G_WR_CORE]
    foreach {wr_core_valid terminal phy_link_usable wr_state_value \
        pstat_locked role_identity_valid reset_valid reset_changed \
        wr_transport_failure} $wr_result break
  } context_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  set context_host_end [clock milliseconds]
  set elapsed_final [expr {$context_host_end - $::f4g_session_start_ms}]
  if {$context_failed} {
    set helper_attempts 0
    set helper_accepted 0
    set helper_fresh 0
    set helper_all_transport 1
    set helper_locked INVALID
    set helper_state_valid 0
    set main_core_valid 0
    set main_fresh 0
    set main_delta INVALID
    set detector_valid 0
    set detector_enabled INVALID
    set detector_freq_locked INVALID
    set terminal 0
    set phy_link_usable 0
    set wr_core_valid 0
    set wr_transport_failure 1
    set position_valid 0
    set helper_residual UNKNOWN
    set normal_request INVALID
    set normal_completed INVALID
    set bootstrap_done INVALID
    set context_error [string map [list " " _ "\n" | "\r" |] $context_error]
    puts [join [list STEP5_F4G_CONTEXT_ERROR "role=SLAVE" \
      "board=$hardware_name" "cycle=$cycle" \
      "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
      "elapsed_ms=$elapsed_final" "error=$context_error"] " "]
    flush stdout
  }
  if {$::f4g_helper_no_core_since_ms($hardware_name) eq "INVALID"} {
    set ::f4g_helper_no_core_since_ms($hardware_name) $elapsed_final
  }
  if {$::f4g_main_no_core_since_ms($hardware_name) eq "INVALID"} {
    set ::f4g_main_no_core_since_ms($hardware_name) $elapsed_final
  }
  f4g_update_core_health $hardware_name $elapsed_final $helper_accepted \
    $helper_all_transport $main_core_valid 0 $wr_core_valid \
    $wr_transport_failure
  set phase_result [f4g_update_phase_window $hardware_name \
    [expr {$helper_accepted && $helper_state_valid ? 1 : 0}] \
    $helper_locked $helper_fresh [lindex $helper_result 9] \
    $detector_valid $detector_enabled $detector_freq_locked \
    $wr_core_valid $phy_link_usable $terminal $elapsed_final]
  foreach {phase_current phase_qualified phase_streak phase_seen \
      helper_unlock_streak helper_rail_streak freq_unlock_streak} \
      $phase_result break
  incr ::f4g_context_count($hardware_name)
  set ::f4g_cycle_count($hardware_name) $cycle
  puts [join [list STEP5_F4G_CYCLE \
    "role=SLAVE" "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
    "elapsed_ms=$elapsed_final" "context_duration_ms=[expr {$context_host_end - $context_host_start}]" \
    "helper_attempts=$helper_attempts" "HELPER_CORE_VALID=$helper_accepted" \
    "HELPER_CORE_FRESH=$helper_fresh" "HELPER_UPDATE_COUNT=$helper_update" \
    "HELPER_STATE_VALID=$helper_state_valid" "HELPER_LOCKED=$helper_locked" \
    "MAIN_CORE_VALID=$main_core_valid" "MAIN_CORE_FRESH=$main_fresh" \
    "MAIN_SAMPLE_N=$main_update" "MAIN_SAMPLE_N_DELTA=$main_delta" \
    "MAIN_DETECTOR_VALID=$detector_valid" "MAIN_ENABLED=$detector_enabled" \
    "MAIN_FREQ_LOCKED=$detector_freq_locked" \
    "MAIN_PHASE_LOCKED=$detector_phase_locked" \
    "POSITION_VALID=$position_valid" "HELPER_RESIDUAL_PRESENT=$helper_residual" \
    "HELPER_NORMAL_REQUEST=$normal_request" \
    "HELPER_NORMAL_COMPLETED=$normal_completed" \
    "HELPER_BOOTSTRAP_DONE=$bootstrap_done" "WR_CORE_VALID=$wr_core_valid" \
    "PHY_LINK_USABLE=$phy_link_usable" "CURRENT_WR_STATE=$wr_state_value" \
    "PSTAT_LOCKED=$pstat_locked" "TERMINAL=$terminal" \
    "PHASE_CURRENT=$phase_current" "PHASE_QUALIFIED=$phase_qualified" \
    "PHASE_QUAL_STREAK=$phase_streak" "PHASE_QUALIFIED_SEEN=$phase_seen" \
    "HELPER_UNLOCK_STREAK=$helper_unlock_streak" \
    "HELPER_RAIL_STREAK=$helper_rail_streak" \
    "FREQ_UNLOCK_STREAK=$freq_unlock_streak" \
    "STOP_REASON=$::f4g_global_stop_reason"] " "]
  flush stdout
  return [list $helper_accepted $helper_fresh $main_core_valid $main_fresh \
    $detector_valid $detector_enabled $detector_freq_locked \
    $detector_phase_locked $wr_core_valid $phy_link_usable $terminal \
    $phase_qualified]
}

proc f4g_emit_master_core {hardware_name device_name cycle} {
  set context_host_start [clock milliseconds]
  set probe_started 0
  set context_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    # Master is a background identity/liveness sample. Its optional position
    # probes are deliberately omitted so they cannot invalidate WR core.
    set wr_result [f4g_emit_wr_core MASTER $hardware_name $cycle \
      STEP5_F4G_MASTER_CORE]
    foreach {wr_core_valid terminal phy_link_usable wr_state_value \
        pstat_locked role_identity_valid reset_valid reset_changed \
        wr_transport_failure} $wr_result break
  } context_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  set context_host_end [clock milliseconds]
  if {$context_failed} {
    set wr_core_valid 0
    set terminal 0
    set phy_link_usable 0
    set wr_state_value INVALID
    set pstat_locked INVALID
    set wr_transport_failure 1
    set context_error [string map [list " " _ "\n" | "\r" |] $context_error]
    puts [join [list STEP5_F4G_CONTEXT_ERROR "role=MASTER" \
      "board=$hardware_name" "cycle=$cycle" \
      "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
      "error=$context_error"] " "]
    flush stdout
  }
  if {$wr_core_valid} {
    set ::f4g_wr_core_transport_streak($hardware_name) 0
  } elseif {$wr_transport_failure} {
    incr ::f4g_wr_core_transport_streak($hardware_name)
    if {$::f4g_wr_core_transport_streak($hardware_name) >= 3} {
      f4g_set_stop DATA_UNRESOLVED
    }
  }
  incr ::f4g_context_count($hardware_name)
  puts [join [list STEP5_F4G_MASTER_SAMPLE \
    "role=MASTER" "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
    "duration_ms=[expr {$context_host_end - $context_host_start}]" \
    "WR_CORE_VALID=$wr_core_valid" "PHY_LINK_USABLE=$phy_link_usable" \
    "CURRENT_WR_STATE=$wr_state_value" "PSTAT_LOCKED=$pstat_locked" \
    "TERMINAL=$terminal" "TRANSPORT_FAILURE=$wr_transport_failure" \
    "STOP_REASON=$::f4g_global_stop_reason"] " "]
  flush stdout
}

proc run_f4g_compact_progress_window {} {
  global samples target_duration_ms hard_duration_ms gap_ms
  set targets [f4e_collect_targets]
  set master_target ""
  set slave_target ""
  foreach target $targets {
    if {[lindex $target 0] eq "MASTER"} { set master_target $target }
    if {[lindex $target 0] eq "SLAVE"} { set slave_target $target }
  }
  set effective_duration $target_duration_ms
  if {$effective_duration <= 0} { set effective_duration 120000 }
  set hard_duration $hard_duration_ms
  if {$hard_duration < $effective_duration} { set hard_duration $effective_duration }
  puts [join [list STEP5_F4G_CONFIG \
    "experiment=$::f4g_experiment_name" \
    "run_role=$::f4g_run_role" "samples_max=$samples" \
    "target_duration_ms=$effective_duration" "hard_duration_ms=$hard_duration" \
    "cadence_hint_ms=$gap_ms" "slave_profile=CORE_ONLY" \
    "helper_core_offsets=0x00100B00,0x00100B14,0x00100B18,0x00100B1C" \
    "main_core_window=0x00100B58..0x00100BAC" \
    "main_core_fields=epoch,sample_n,pi_x,pi_output,clamp_side,state,freq_error" \
    "main_detector_window=0x00100AC4..0x00100ACC" \
    "helper_position_probes=42,43,44,49" "l2_probes=52..61" \
    "l2_counter_width_bits=32" "l2_multi_probe_atomicity=NOT_AVAILABLE" \
    "counter_delta_policy=SAME_FIELD_TRUSTED_READS_ONLY" \
    "phase_qualification=2_TRUSTED_FRAMES_HELPER_LOCKED_MAIN_FREQ_LOCKED" \
    "main_background_cadence_ms=3000" "helper_attempts_max=8" \
    "hard_deadline_includes_retries=1" "stop_on_owner_unresolved=1" \
    "read_only_observer=1" "one_reader=1" "reader_processes=1" \
    "no_control_write=1" "no_helper_pi_snapshot=1" \
    "no_debug_fifo_drain=1" "production_control_unchanged=1" \
    "source_contract=helper_source_contract.md" \
    "source_contract_verified=YES" "dynamic_owner_verified=NOT_AVAILABLE" \
    "runtime_image_verified=REQUIRED_AT_CAPTURE" \
    "wdiags_ctrl_addr=0x00100A04" "wdiags_ctrl_width_bits=32" \
    "phy_status_source=$::f4g_phy_status_source" \
    "phy_status_instance=0" "phy_status_width_bits=64" \
    "phy_required_bits=SI_CONFIG_DONE:0,WR_READY:1,CORE_TM_LINK_UP:2,CORE_LINK_OK:3,WR_RX_READY:6,WR_TX_READY:7" \
    "phy_required_mask=000000CF" "pstat_addr=0x00100A0C" \
    "pstat_link_bit=0" "pstat_locked_bit=1" \
    "step5_complete=NO" "merge_approved=NO"] " "]
  flush stdout
  if {[llength $targets] != 2 || $master_target eq "" || $slave_target eq ""} {
    puts [join [list STEP5_F4G_CONFIG_ERROR required=MASTER+SLAVE \
      "discovered=[llength $targets]"] " "]
    puts "STEP5_F4G_DONE run_end_reason=CONFIG_INVALID stop_reason=CONFIG_INVALID step5_complete=NO merge_approved=NO"
    flush stdout
    return
  }
  foreach target [list $master_target $slave_target] {
    f4g_initialize_board [lindex $target 0] [lindex $target 1]
    set ::f4g_last_helper_update([lindex $target 1]) INVALID
  }
  set ::f4g_global_stop_reason NONE
  set ::f4g_session_start_ms [clock milliseconds]
  set target_deadline [expr {$::f4g_session_start_ms + $effective_duration}]
  set hard_deadline [expr {$::f4g_session_start_ms + $hard_duration}]
  set next_slave_ms $::f4g_session_start_ms
  set next_master_ms $::f4g_session_start_ms
  set slave_cycle 0
  set master_cycle 0
  while {[clock milliseconds] < $hard_deadline &&
      [clock milliseconds] < $target_deadline && $slave_cycle < $samples &&
      $::f4g_global_stop_reason eq "NONE"} {
    set did_work 0
    set now [clock milliseconds]
    if {$now >= $next_slave_ms} {
      incr slave_cycle
      set slave_hardware [lindex $slave_target 1]
      set slave_device [lindex $slave_target 2]
      f4g_emit_slave_context $slave_hardware $slave_device $slave_cycle \
        [expr {[clock milliseconds] - $::f4g_session_start_ms}]
      set next_slave_ms [expr {[clock milliseconds] + 500}]
      set did_work 1
    }
    if {$::f4g_global_stop_reason ne "NONE"} { break }
    set now [clock milliseconds]
    if {$now >= $next_master_ms} {
      incr master_cycle
      set master_hardware [lindex $master_target 1]
      set master_device [lindex $master_target 2]
      f4g_emit_master_core $master_hardware $master_device $master_cycle
      set next_master_ms [expr {[clock milliseconds] + 3000}]
      set did_work 1
    }
    if {$::f4g_global_stop_reason ne "NONE"} { break }
    if {!$did_work} {
      set now [clock milliseconds]
      set next_due $next_slave_ms
      if {$next_master_ms < $next_due} { set next_due $next_master_ms }
      set remaining [expr {$next_due - $now}]
      if {$remaining > 100} { set remaining 100 }
      if {$remaining > 0} { after $remaining }
    }
  }
  set ::f4g_session_end_ms [clock milliseconds]
  set session_elapsed [expr {$::f4g_session_end_ms - $::f4g_session_start_ms}]
  if {$::f4g_global_stop_reason ne "NONE"} {
    set end_reason STOP_$::f4g_global_stop_reason
  } elseif {$slave_cycle >= $samples} {
    set end_reason SAMPLE_LIMIT
  } elseif {$session_elapsed >= $effective_duration} {
    set end_reason TARGET_REACHED
  } elseif {$session_elapsed >= $hard_duration} {
    set end_reason HARD_DEADLINE
  } else {
    set end_reason OBSERVER_EXIT
  }
  foreach target [list $master_target $slave_target] {
    set role [lindex $target 0]
    set hardware_name [lindex $target 1]
    set ::f4g_run_end_reason($hardware_name) $end_reason
    puts [join [list STEP5_F4G_ROLE_SUMMARY \
      "role=$role" "board=$hardware_name" \
      "contexts=$::f4g_context_count($hardware_name)" \
      "cycles=$::f4g_cycle_count($hardware_name)" \
      "phase_qualified_seen=$::f4g_phase_qualified_seen($hardware_name)" \
      "helper_transport_streak=$::f4g_helper_core_transport_streak($hardware_name)" \
      "main_transport_streak=$::f4g_main_core_transport_streak($hardware_name)" \
      "wr_transport_streak=$::f4g_wr_core_transport_streak($hardware_name)" \
      "helper_last_usable_ms=$::f4g_last_helper_usable_ms($hardware_name)" \
      "main_last_usable_ms=$::f4g_last_main_usable_ms($hardware_name)" \
      "terminal_streak=$::f4g_terminal_streak($hardware_name)" \
      "stop_reason=$::f4g_stop_reason($hardware_name)" \
      "run_end_reason=$end_reason"] " "]
  }
  puts [join [list STEP5_F4G_DONE \
    "session_elapsed_ms=$session_elapsed" \
    "target_duration_ms=$effective_duration" "hard_duration_ms=$hard_duration" \
    "slave_cycles=$slave_cycle" "master_samples=$master_cycle" \
    "run_end_reason=$end_reason" \
    "stop_reason=$::f4g_global_stop_reason" "single_reader=PASS" \
    "step5_complete=NO" "step5_pass=NO" "merge_approved=NO"] " "]
  flush stdout
}

# -------------------------------------------------------------------------
# F4I: minimal Main frequency/phase handoff audit
# -------------------------------------------------------------------------

proc f4i_set_stop {reason} {
  if {$::f4i_global_stop_reason ne "NONE"} { return }
  set ::f4i_global_stop_reason $reason
  foreach hardware_name [array names ::f4g_role] {
    set ::f4i_stop_reason($hardware_name) $reason
  }
}

proc f4i_initialize_board {role hardware_name} {
  # Reuse only the already-audited F4H WR/PHY decoder's state storage.  No
  # controller state is changed and the F4I state remains independent.
  f4g_initialize_board $role $hardware_name
  set ::f4i_last_trace_key($hardware_name) ""
  set ::f4i_last_domain($hardware_name) UNKNOWN
  set ::f4i_last_helper_update($hardware_name) INVALID
  set ::f4i_last_update($hardware_name) INVALID
  set ::f4i_last_progress_ms($hardware_name) INVALID
  set ::f4i_last_main_valid_ms($hardware_name) INVALID
  set ::f4i_helper_lock_seen($hardware_name) 0
  set ::f4i_trace_count($hardware_name) 0
  set ::f4i_trace_valid_count($hardware_name) 0
  set ::f4i_trace_unique_count($hardware_name) 0
  set ::f4i_trace_duplicate_count($hardware_name) 0
  set ::f4i_domain_change_count($hardware_name) 0
  set ::f4i_main_progress_count($hardware_name) 0
  set ::f4i_main_invalid_streak($hardware_name) 0
  set ::f4i_helper_unlock_streak($hardware_name) 0
  set ::f4i_helper_rail_streak($hardware_name) 0
  set ::f4i_phy_bad_streak($hardware_name) 0
  set ::f4i_metadata_seen($hardware_name) 0
  set ::f4i_next_service_ms($hardware_name) 0
  set ::f4i_stop_reason($hardware_name) NONE
  set ::f4i_run_end_reason($hardware_name) NOT_REACHED
}

proc f4i_frequency_sign {value} {
  if {![f4g_is_number $value]} { return UNKNOWN }
  if {$value > 0} { return POSITIVE }
  if {$value < 0} { return NEGATIVE }
  return ZERO
}

proc f4i_domain_from_state {state} {
  if {![f4g_is_number $state]} { return UNKNOWN }
  # Main trace state is published as enabled/frequency-locked/phase-locked/
  # overall-locked by task-diags.c.  A frequency-locked state selects the
  # phase error path in mpll_update(); this is an observed published domain,
  # not proof of the producer's exact control iteration.
  set freq_locked [field32 $state 1 1]
  if {$freq_locked eq "INVALID"} { return UNKNOWN }
  return [expr {$freq_locked == 1 ? "PHASE" : "FREQUENCY"}]
}

proc f4i_read_main_trace_minimal {hardware_name} {
  set read_start_ms [clock milliseconds]
  # Reuse the established compact reader.  It reads the causal core fields
  # before the epoch check and keeps optional fields explicitly separate; the
  # previous F4I implementation reread thirteen words serially and could not
  # finish before the live publisher advanced the epoch.
  set trace [read_main_trace $hardware_name]
  foreach {trace_ok epoch dref dout freq_error prelock_error pi_unclamped \
      pi_output clamp_side lock_count lock_count_max kp ki shift bias \
      update_count threshold lock_samples state y_min y_max anti_windup \
      pi_x magic} $trace break
  if {[info exists ::main_trace_epoch_before_raw($hardware_name)]} {
    set epoch_before_raw $::main_trace_epoch_before_raw($hardware_name)
  } else {
    set epoch_before_raw INVALID
  }
  if {[info exists ::main_trace_epoch_after_raw($hardware_name)]} {
    set epoch_after_raw $::main_trace_epoch_after_raw($hardware_name)
  } else {
    set epoch_after_raw INVALID
  }
  if {[info exists ::main_trace_magic_raw($hardware_name)]} {
    set magic_raw $::main_trace_magic_raw($hardware_name)
  } else {
    set magic_raw INVALID
  }
  set raw_values [list $epoch_before_raw [f4g_hex32 $dref] \
    [f4g_hex32 $dout] [f4g_hex32 $freq_error] [f4g_hex32 $prelock_error] \
    [f4g_hex32 $pi_unclamped] [f4g_hex32 $pi_output] \
    [f4g_hex32 $clamp_side] [f4g_hex32 $update_count] \
    [f4g_hex32 $state] [f4g_hex32 $pi_x] $epoch_after_raw $magic_raw]
  set read_end_ms [clock milliseconds]
  set ::f4i_last_raw_trace($hardware_name) $raw_values
  if {$trace_ok} {
    return [list 1 $epoch $dref $dout $freq_error $prelock_error \
      $pi_unclamped $pi_output $clamp_side $update_count $state $pi_x \
      $magic $read_start_ms $read_end_ms]
  }
  return [concat [list 0] [lrepeat 12 INVALID] [list $read_start_ms $read_end_ms]]
}

proc f4i_emit_main_metadata {hardware_name} {
  set host_start_ms [clock milliseconds]
  set kp [signed32 [wb_read $hardware_name 0x00100B80]]
  set ki [signed32 [wb_read $hardware_name 0x00100B84]]
  set shift [signed32 [wb_read $hardware_name 0x00100B88]]
  set bias [signed32 [wb_read $hardware_name 0x00100B8C]]
  set freq_threshold [word32 [wb_read $hardware_name 0x00100B94]]
  set freq_lock_samples [word32 [wb_read $hardware_name 0x00100B98]]
  set y_min [signed32 [wb_read $hardware_name 0x00100BA0]]
  set y_max [signed32 [wb_read $hardware_name 0x00100BA4]]
  set anti_windup [signed32 [wb_read $hardware_name 0x00100BA8]]
  set phase_limits [wb_read $hardware_name 0x00100ACC]
  set phase_threshold [field32 $phase_limits 0 16]
  set phase_lock_samples [field32 $phase_limits 16 16]
  set magic [word32 [wb_read $hardware_name 0x00100BDC]]
  set host_end_ms [clock milliseconds]
  set valid 1
  foreach value [list $kp $ki $shift $bias $freq_threshold $freq_lock_samples \
      $y_min $y_max $anti_windup $phase_threshold $phase_lock_samples $magic] {
    if {![f4g_is_number $value]} { set valid 0 }
  }
  puts [join [list STEP5_F4I_MAIN_METADATA \
    "board=$hardware_name" "host_start_ms=$host_start_ms" \
    "host_end_ms=$host_end_ms" \
    "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "METADATA_VALID=$valid" "METADATA_SOURCE=WB_WDIAGS_STATIC" \
    "MAIN_PI_KP=$kp" "MAIN_PI_KI=$ki" "MAIN_PI_SHIFT=$shift" \
    "MAIN_PI_BIAS=$bias" "MAIN_FREQ_THRESHOLD=$freq_threshold" \
    "MAIN_FREQ_LOCK_SAMPLES=$freq_lock_samples" \
    "MAIN_PHASE_THRESHOLD=$phase_threshold" \
    "MAIN_PHASE_LOCK_SAMPLES=$phase_lock_samples" "MAIN_PI_Y_MIN=$y_min" \
    "MAIN_PI_Y_MAX=$y_max" "MAIN_PI_ANTI_WINDUP=$anti_windup" \
    "MAIN_TRACE_MAGIC=$magic" "METADATA_SAME_ITERATION=NO"] " "]
  flush stdout
}

proc f4i_emit_main_trace {hardware_name sample elapsed_ms} {
  set trace [f4i_read_main_trace_minimal $hardware_name]
  foreach {trace_ok epoch dref dout freq_error prelock_error pi_unclamped \
      pi_output clamp_side update_count state pi_x magic read_start read_end} \
      $trace break
  set raw_values $::f4i_last_raw_trace($hardware_name)
  set epoch_before_raw [lindex $raw_values 0]
  set dref_raw [lindex $raw_values 1]
  set dout_raw [lindex $raw_values 2]
  set freq_raw [lindex $raw_values 3]
  set prelock_raw [lindex $raw_values 4]
  set pi_unclamped_raw [lindex $raw_values 5]
  set pi_output_raw [lindex $raw_values 6]
  set clamp_raw [lindex $raw_values 7]
  set update_raw [lindex $raw_values 8]
  set state_raw [lindex $raw_values 9]
  set pi_x_raw [lindex $raw_values 10]
  set epoch_after_raw [lindex $raw_values 11]
  set magic_raw [lindex $raw_values 12]
  set unique 0
  set dedup_skipped 0
  set advanced 0
  set ambiguous 0
  set delta INVALID
  set domain UNKNOWN
  set pi_x_classification UNKNOWN
  set freq_sign UNKNOWN
  set freq_abs_gt_50 UNKNOWN
  set pair_check UNKNOWN
  set main_enabled INVALID
  set main_freq_locked INVALID
  set main_phase_locked INVALID
  set main_locked INVALID
  if {$trace_ok} {
    incr ::f4i_trace_valid_count($hardware_name)
    set ::f4i_last_main_valid_ms($hardware_name) $elapsed_ms
    set main_enabled [field32 $state 0 1]
    set main_freq_locked [field32 $state 1 1]
    set main_phase_locked [field32 $state 2 1]
    set main_locked [field32 $state 3 1]
    set domain [f4i_domain_from_state $state]
    set pi_x_classification [expr {$domain eq "PHASE" ? \
      "PHASE_CONTEXT_OBSERVED" : ($domain eq "FREQUENCY" ? \
      "FREQUENCY_CONTEXT_OBSERVED" : "UNKNOWN")}]
    set freq_sign [f4i_frequency_sign $freq_error]
    set freq_abs_gt_50 [expr {abs($freq_error) > 50 ? 1 : 0}]
    if {$dref ne "INVALID" && $dout ne "INVALID" && $freq_error ne "INVALID"} {
      set pair_check [expr {$freq_error == ($dout - $dref) ? "PASS" : "FAIL"}]
    }
    set key "$epoch/$update_count"
    if {$key eq $::f4i_last_trace_key($hardware_name)} {
      incr ::f4i_trace_duplicate_count($hardware_name)
      set dedup_skipped 1
    } else {
      incr ::f4i_trace_unique_count($hardware_name)
      set unique 1
      if {$::f4i_last_domain($hardware_name) ne "UNKNOWN" &&
          $domain ne $::f4i_last_domain($hardware_name)} {
        incr ::f4i_domain_change_count($hardware_name)
      }
      set ::f4i_last_domain($hardware_name) $domain
      set ::f4i_last_trace_key($hardware_name) $key
    }
    if {$::f4i_last_update($hardware_name) ne "INVALID"} {
      set delta [counter_delta $::f4i_last_update($hardware_name) \
        $update_count 32]
      if {$delta eq "INVALID" || $delta > 0x7fffffff} {
        set delta INVALID
        set ambiguous 1
      } elseif {$delta > 0} {
        set advanced 1
        incr ::f4i_main_progress_count($hardware_name)
        set ::f4i_last_progress_ms($hardware_name) $elapsed_ms
      }
    }
    if {$::f4i_last_update($hardware_name) eq "INVALID" && $unique} {
      set ::f4i_last_progress_ms($hardware_name) $elapsed_ms
    }
    set ::f4i_last_update($hardware_name) $update_count
  }
  incr ::f4i_trace_count($hardware_name)
  puts [join [list STEP5_F4I_MAIN_TRACE \
    "board=$hardware_name" "sample=$sample" \
    "host_start_ms=$read_start" "host_end_ms=$read_end" \
    "elapsed_ms=$elapsed_ms" "MAIN_TRACE_VALID=$trace_ok" \
    "PUBLICATION_COHERENT=$trace_ok" "MAIN_TRACE_UNIQUE=$unique" \
    "TRACE_DEDUP_SKIPPED=$dedup_skipped" \
    "MAIN_TRACE_EPOCH_RAW_BEFORE=$epoch_before_raw" \
    "MAIN_TRACE_EPOCH_RAW_AFTER=$epoch_after_raw" \
    "MAIN_PUBLICATION_EPOCH=$epoch" "MAIN_PUBLICATION_EPOCH_SAME=\
[expr {[string equal -nocase $epoch_before_raw $epoch_after_raw] ? 1 : 0}]" \
    "MAIN_DREF_DT=$dref" "MAIN_DREF_DT_RAW=$dref_raw" \
    "MAIN_DOUT_DT=$dout" "MAIN_DOUT_DT_RAW=$dout_raw" \
    "MAIN_FREQ_ERROR=$freq_error" "MAIN_FREQ_ERROR_RAW=$freq_raw" \
    "MAIN_PRELOCK_ERROR=$prelock_error" "MAIN_PRELOCK_ERROR_RAW=$prelock_raw" \
    "MAIN_PI_UNCLAMPED=$pi_unclamped" \
    "MAIN_PI_UNCLAMPED_RAW=$pi_unclamped_raw" \
    "MAIN_PI_OUTPUT=$pi_output" "MAIN_PI_OUTPUT_RAW=$pi_output_raw" \
    "MAIN_PI_CLAMP_SIDE=$clamp_side" "MAIN_PI_CLAMP_SIDE_RAW=$clamp_raw" \
    "MAIN_SAMPLE_N=$update_count" "MAIN_SAMPLE_N_RAW=$update_raw" \
    "MAIN_SAMPLE_N_DELTA=$delta" "MAIN_SAMPLE_N_ADVANCED=$advanced" \
    "MAIN_SAMPLE_N_AMBIGUOUS=$ambiguous" "MAIN_STATE=$state" \
    "MAIN_STATE_RAW=$state_raw" "MAIN_PI_X=$pi_x" "MAIN_PI_X_RAW=$pi_x_raw" \
    "MAIN_TRACE_MAGIC=$magic" "MAIN_TRACE_MAGIC_RAW=$magic_raw" \
    "MAIN_ENABLED=$main_enabled" "MAIN_FREQ_LOCKED=$main_freq_locked" \
    "MAIN_PHASE_LOCKED=$main_phase_locked" "MAIN_LOCKED=$main_locked" \
    "MAIN_DOMAIN=$domain" "PI_X_CLASSIFICATION=$pi_x_classification" \
    "PRODUCER_DOMAIN_COHERENCE=UNPROVEN" "FREQ_ERROR_SIGN=$freq_sign" \
    "FREQ_ABS_GT_50=$freq_abs_gt_50" "FREQ_ERROR_PAIR_CHECK=$pair_check"] " "]
  flush stdout
  return [list $trace_ok $unique $advanced $domain $main_freq_locked \
    $main_phase_locked $main_locked $update_count $freq_error $pi_x \
    $pi_output $clamp_side]
}

proc f4i_emit_service_counters {hardware_name sample} {
  foreach {probe name} {54 START 55 COMPLETED 56 FAILED} {
    set result [f4g_read_l2_word $probe]
    foreach {raw host_start_ms host_end_ms valid} $result break
    set main_raw [f4g_raw_low32 $raw]
    set helper_raw [f4g_raw_high32 $raw]
    set main_value [low32_64 $raw]
    set helper_value [high32_64 $raw]
    puts [join [list STEP5_F4I_SERVICE_COUNTER \
      "board=$hardware_name" "sample=$sample" "probe=$probe" \
      "COUNTER_GROUP=$name" "host_start_ms=$host_start_ms" \
      "host_end_ms=$host_end_ms" \
      "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
      "RAW_PACKED=$raw" "MAIN_RAW=$main_raw" "HELPER_RAW=$helper_raw" \
      "MAIN_VALUE=$main_value" "HELPER_VALUE=$helper_value" \
      "VALID=$valid" "COUNTER_WIDTH_BITS=32" \
      "SOURCE_SEMANTICS=VERIFIED" "READ_ATOMICITY=WORD_ONLY" \
      "DELTA_POLICY=SAME_FIELD_TRUSTED_READS_ONLY"] " "]
  }
  flush stdout
}

proc f4i_update_health {hardware_name elapsed_ms main_valid main_advanced \
    helper_valid helper_locked helper_output wr_valid phy_link_usable terminal} {
  if {$main_valid} {
    set ::f4i_main_invalid_streak($hardware_name) 0
  } else {
    incr ::f4i_main_invalid_streak($hardware_name)
    if {$elapsed_ms >= 10000 &&
        ($::f4i_last_main_valid_ms($hardware_name) eq "INVALID" ||
         $elapsed_ms - $::f4i_last_main_valid_ms($hardware_name) >= 10000)} {
      f4i_set_stop DATA_UNRESOLVED
    }
  }
  if {$helper_valid && $helper_locked eq "1"} {
    set ::f4i_helper_lock_seen($hardware_name) 1
    set ::f4i_helper_unlock_streak($hardware_name) 0
  } elseif {$helper_valid && $helper_locked eq "0" &&
            $::f4i_helper_lock_seen($hardware_name)} {
    incr ::f4i_helper_unlock_streak($hardware_name)
  }
  if {$helper_valid && [f4g_is_number $helper_output] &&
      $::f4i_helper_lock_seen($hardware_name) &&
      ($helper_output <= 5 || $helper_output >= 65531)} {
    incr ::f4i_helper_rail_streak($hardware_name)
  } elseif {$helper_valid && [f4g_is_number $helper_output]} {
    set ::f4i_helper_rail_streak($hardware_name) 0
  }
  if {$::f4i_helper_unlock_streak($hardware_name) >= 3 ||
      $::f4i_helper_rail_streak($hardware_name) >= 3} {
    f4i_set_stop HELPER_REGRESSION
  }
  if {$wr_valid && !$phy_link_usable} {
    incr ::f4i_phy_bad_streak($hardware_name)
    if {$::f4i_phy_bad_streak($hardware_name) >= 3} {
      f4i_set_stop TRUE_PHY_GATE_NOT_MET
    }
  } elseif {$phy_link_usable} {
    set ::f4i_phy_bad_streak($hardware_name) 0
  }
  if {$terminal} { f4i_set_stop WR_SESSION_ENDED }
  if {$::f4g_global_stop_reason ne "NONE"} {
    f4i_set_stop $::f4g_global_stop_reason
  }
}

proc f4i_emit_slave_context {hardware_name device_name cycle elapsed_ms} {
  set context_host_start [clock milliseconds]
  set probe_started 0
  set helper_attempts 0
  set helper_accepted 0
  set helper_fresh 0
  set helper_update INVALID
  set helper_output INVALID
  set helper_state_valid 0
  set helper_locked INVALID
  set helper_lock_count INVALID
  set helper_residual UNKNOWN
  set helper_target INVALID
  set helper_applied INVALID
  set normal_request INVALID
  set normal_completed INVALID
  set bootstrap_done INVALID
  set position_valid 0
  set main_core_valid 0
  set main_unique 0
  set main_advanced 0
  set main_domain UNKNOWN
  set main_freq_locked INVALID
  set main_phase_locked INVALID
  set main_locked INVALID
  set main_update INVALID
  set main_freq_error INVALID
  set main_pi_x INVALID
  set main_pi_output INVALID
  set main_clamp_side INVALID
  set detector_valid 0
  set detector_enabled INVALID
  set detector_freq_locked INVALID
  set detector_phase_locked INVALID
  set wr_core_valid 0
  set phy_link_usable 0
  set terminal 0
  set pstat_locked INVALID
  set wr_transport_failure 1
  set service_read 0
  set context_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    if {!$::f4i_metadata_seen($hardware_name)} {
      f4i_emit_main_metadata $hardware_name
      set ::f4i_metadata_seen($hardware_name) 1
    }
    set helper_capture [f4g_capture_helper_core $hardware_name $cycle]
    set helper_attempts [lindex $helper_capture 0]
    set helper_result [lindex $helper_capture 1]
    set helper_accepted [lindex $helper_result 0]
    set helper_update [lindex $helper_result 8]
    set helper_output [lindex $helper_result 9]
    if {$helper_accepted && $::f4i_last_helper_update($hardware_name) ne "INVALID"} {
      set helper_delta [counter_delta $::f4i_last_helper_update($hardware_name) \
        $helper_update 32]
      if {$helper_delta ne "INVALID" && $helper_delta > 0 &&
          $helper_delta <= 0x7fffffff} { set helper_fresh 1 }
    }
    if {$helper_accepted} { set ::f4i_last_helper_update($hardware_name) $helper_update }
    set helper_state [f4g_emit_helper_state $hardware_name $cycle]
    foreach {helper_state_valid helper_locked helper_lock_count helper_threshold \
        helper_lock_samples helper_state_raw helper_limits_raw} $helper_state break
    set position_result [f4g_emit_helper_position $hardware_name $cycle]
    foreach {position_valid helper_residual normal_request normal_completed \
        bootstrap_done helper_target helper_applied} $position_result break
    set main_result [f4i_emit_main_trace $hardware_name $cycle $elapsed_ms]
    foreach {main_core_valid main_unique main_advanced main_domain \
        main_freq_locked main_phase_locked main_locked main_update \
        main_freq_error main_pi_x main_pi_output main_clamp_side} $main_result break
    set detector_result [f4g_emit_main_detector $hardware_name $cycle]
    foreach {detector_valid detector_stable detector_enabled detector_locked \
        detector_freq_locked detector_phase_locked detector_freq_count \
        detector_phase_count detector_freq_threshold detector_freq_samples \
        detector_phase_threshold detector_phase_samples} $detector_result break
    set status_result [f4g_read_l2_word 52]
    f4g_emit_l2_word $hardware_name $cycle 52 STATUS $status_result
    set pending_result [f4g_read_l2_word 53]
    f4g_emit_l2_word $hardware_name $cycle 53 PENDING $pending_result
    f4g_emit_service_demand $hardware_name $cycle $status_result $pending_result
    set wr_result [f4g_emit_wr_core SLAVE $hardware_name $cycle \
      STEP5_F4I_WR_CORE]
    foreach {wr_core_valid terminal phy_link_usable wr_state_value \
        pstat_locked role_identity_valid reset_valid reset_changed \
        wr_transport_failure} $wr_result break
    set now_elapsed [expr {[clock milliseconds] - $::f4i_session_start_ms}]
    if {$now_elapsed >= $::f4i_next_service_ms($hardware_name)} {
      f4i_emit_service_counters $hardware_name $cycle
      foreach {l2_probe l2_name} {57 MAX_WAIT 58 CURRENT_WAIT 59 LATENCY \
          60 FAILURE 61 FIRST_LOSS} {
        set l2_result [f4g_read_l2_word $l2_probe]
        f4g_emit_l2_word $hardware_name $cycle $l2_probe $l2_name $l2_result
      }
      set ::f4i_next_service_ms($hardware_name) [expr {$now_elapsed + 3000}]
      set service_read 1
    }
  } context_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  set context_host_end [clock milliseconds]
  set elapsed_final [expr {$context_host_end - $::f4i_session_start_ms}]
  if {$context_failed} {
    set helper_attempts 0
    set helper_accepted 0
    set helper_fresh 0
    set helper_update INVALID
    set helper_output INVALID
    set helper_state_valid 0
    set helper_locked INVALID
    set helper_lock_count INVALID
    set helper_residual UNKNOWN
    set helper_target INVALID
    set helper_applied INVALID
    set normal_request INVALID
    set normal_completed INVALID
    set bootstrap_done INVALID
    set main_core_valid 0
    set main_unique 0
    set main_advanced 0
    set main_domain UNKNOWN
    set main_freq_locked INVALID
    set main_phase_locked INVALID
    set main_locked INVALID
    set main_update INVALID
    set main_freq_error INVALID
    set main_pi_x INVALID
    set main_pi_output INVALID
    set main_clamp_side INVALID
    set detector_valid 0
    set detector_enabled INVALID
    set detector_freq_locked INVALID
    set detector_phase_locked INVALID
    set wr_core_valid 0
    set phy_link_usable 0
    set terminal 0
    set pstat_locked INVALID
    set wr_transport_failure 1
    set context_error [string map [list " " _ "\n" | "\r" |] $context_error]
    puts [join [list STEP5_F4I_CONTEXT_ERROR "role=SLAVE" \
      "board=$hardware_name" "cycle=$cycle" \
      "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
      "elapsed_ms=$elapsed_final" "error=$context_error"] " "]
    flush stdout
  }
  f4i_update_health $hardware_name $elapsed_final $main_core_valid \
    $main_advanced [expr {$helper_accepted && $helper_state_valid ? 1 : 0}] \
    $helper_locked $helper_output $wr_core_valid $phy_link_usable $terminal
  puts [join [list STEP5_F4I_CYCLE "role=SLAVE" "board=$hardware_name" \
    "cycle=$cycle" "host_start_ms=$context_host_start" \
    "host_end_ms=$context_host_end" "elapsed_ms=$elapsed_final" \
    "context_duration_ms=[expr {$context_host_end - $context_host_start}]" \
    "helper_attempts=$helper_attempts" "HELPER_CORE_VALID=$helper_accepted" \
    "HELPER_CORE_FRESH=$helper_fresh" "HELPER_UPDATE_COUNT=$helper_update" \
    "HELPER_STATE_VALID=$helper_state_valid" "HELPER_LOCKED=$helper_locked" \
    "HELPER_LOCK_COUNT=$helper_lock_count" \
    "POSITION_VALID=$position_valid" "HELPER_RESIDUAL_PRESENT=$helper_residual" \
    "HELPER_TARGET_CODE=$helper_target" "HELPER_APPLIED_CODE=$helper_applied" \
    "HELPER_NORMAL_REQUEST=$normal_request" \
    "HELPER_NORMAL_COMPLETED=$normal_completed" \
    "HELPER_BOOTSTRAP_DONE=$bootstrap_done" \
    "MAIN_CORE_VALID=$main_core_valid" "MAIN_TRACE_UNIQUE=$main_unique" \
    "MAIN_SAMPLE_N=$main_update" "MAIN_SAMPLE_N_ADVANCED=$main_advanced" \
    "MAIN_DOMAIN=$main_domain" "MAIN_FREQ_LOCKED=$main_freq_locked" \
    "MAIN_PHASE_LOCKED=$main_phase_locked" "MAIN_LOCKED=$main_locked" \
    "MAIN_DETECTOR_VALID=$detector_valid" \
    "MAIN_DETECTOR_FREQ_LOCKED=$detector_freq_locked" \
    "MAIN_DETECTOR_PHASE_LOCKED=$detector_phase_locked" \
    "WR_CORE_VALID=$wr_core_valid" "PHY_LINK_USABLE=$phy_link_usable" \
    "PSTAT_LOCKED=$pstat_locked" "TERMINAL=$terminal" \
    "SERVICE_READ=$service_read" "STOP_REASON=$::f4i_global_stop_reason"] " "]
  flush stdout
}

proc f4i_emit_master_context {hardware_name device_name sample} {
  set context_host_start [clock milliseconds]
  set probe_started 0
  set wr_core_valid 0
  set terminal 0
  set phy_link_usable 0
  set pstat_locked INVALID
  set wr_transport_failure 1
  set context_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set wr_result [f4g_emit_wr_core MASTER $hardware_name $sample \
      STEP5_F4I_WR_CORE]
    foreach {wr_core_valid terminal phy_link_usable wr_state_value \
        pstat_locked role_identity_valid reset_valid reset_changed \
        wr_transport_failure} $wr_result break
  } context_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  set context_host_end [clock milliseconds]
  if {$context_failed} {
    set wr_core_valid 0
    set terminal 0
    set phy_link_usable 0
    set pstat_locked INVALID
    set wr_transport_failure 1
    set context_error [string map [list " " _ "\n" | "\r" |] $context_error]
    puts [join [list STEP5_F4I_CONTEXT_ERROR "role=MASTER" \
      "board=$hardware_name" "sample=$sample" \
      "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
      "error=$context_error"] " "]
    flush stdout
  }
  set elapsed_ms [expr {$context_host_end - $::f4i_session_start_ms}]
  f4i_update_health $hardware_name $elapsed_ms 1 0 0 1 INVALID \
    $wr_core_valid $phy_link_usable $terminal
  puts [join [list STEP5_F4I_MASTER_SAMPLE "role=MASTER" \
    "board=$hardware_name" "sample=$sample" \
    "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
    "elapsed_ms=$elapsed_ms" "WR_CORE_VALID=$wr_core_valid" \
    "PHY_LINK_USABLE=$phy_link_usable" "PSTAT_LOCKED=$pstat_locked" \
    "TERMINAL=$terminal" "STOP_REASON=$::f4i_global_stop_reason"] " "]
  flush stdout
}

proc run_f4i_frequency_phase_handoff_audit {} {
  global samples target_duration_ms hard_duration_ms gap_ms
  set targets [f4e_collect_targets]
  set master_target ""
  set slave_target ""
  foreach target $targets {
    if {[lindex $target 0] eq "MASTER"} { set master_target $target }
    if {[lindex $target 0] eq "SLAVE"} { set slave_target $target }
  }
  set effective_duration $target_duration_ms
  if {$effective_duration <= 0} { set effective_duration 120000 }
  set hard_duration $hard_duration_ms
  if {$hard_duration < $effective_duration} { set hard_duration $effective_duration }
  puts [join [list STEP5_F4I_CONFIG \
    "experiment=EXP-S5-F4I-MAIN-FREQUENCY-PHASE-HANDOFF-AUDIT-20260916" \
    "run_role=f4i" "samples_max=$samples" "target_duration_ms=$effective_duration" \
    "hard_duration_ms=$hard_duration" "cadence_hint_ms=$gap_ms" \
    "main_trace_fields=epoch,sample_n,dref_dt,dout_dt,freq_error,prelock_error,pi_x,pi_output,clamp_side,state" \
    "main_trace_window=0x00100B58..0x00100BAC" \
    "main_trace_reader=ESTABLISHED_READ_MAIN_TRACE_COMPACT_CORE" \
    "main_trace_optional_fields=prelock,dref,dout,pi_unclamped,magic" \
    "main_domain_rule=trace_state_bit1_freq_locked" \
    "pi_x_classification=PHASE_CONTEXT_OBSERVED_OR_FREQUENCY_CONTEXT_OBSERVED" \
    "publication_coherence=EPOCH_BEFORE_EQUALS_EPOCH_AFTER_EVEN" \
    "producer_domain_coherence=UNPROVEN" \
    "main_trace_dedup_key=PUBLICATION_EPOCH_AND_SAMPLE_N" \
    "optional_metadata=CAPTURED_ONCE_AT_ENTRY_NOT_SAME_ITERATION" \
    "helper_core=F4F_COMPACT_SOURCE_CONTRACT" \
    "helper_position_probes=42,43,44,49" "l2_probes=52..61" \
    "phy_status_source=JTAG_PROBE0" "phy_status_instance=0" \
    "phy_status_width_bits=64" "phy_required_mask=000000CF" \
    "main_background_cadence_ms=3000" "l2_service_probes=54,55,56" \
    "read_only_observer=1" "one_reader=1" "reader_processes=1" \
    "no_control_write=1" "no_helper_pi_snapshot=1" "no_debug_fifo_drain=1" \
    "production_control_unchanged=1" "source_contract_verified=YES" \
    "dynamic_owner_verified=NOT_AVAILABLE" "step5_complete=NO" \
    "merge_approved=NO"] " "]
  flush stdout
  if {[llength $targets] != 2 || $master_target eq "" || $slave_target eq ""} {
    puts "STEP5_F4I_CONFIG_ERROR required=MASTER+SLAVE discovered=[llength $targets]"
    puts "STEP5_F4I_DONE run_end_reason=CONFIG_INVALID stop_reason=CONFIG_INVALID step5_complete=NO step5_pass=NO merge_approved=NO"
    flush stdout
    return
  }
  f4i_initialize_board MASTER [lindex $master_target 1]
  f4i_initialize_board SLAVE [lindex $slave_target 1]
  set ::f4g_run_role f4i
  set ::f4g_experiment_name EXP-S5-F4I-MAIN-FREQUENCY-PHASE-HANDOFF-AUDIT-20260916
  set ::f4g_phy_status_source JTAG_PROBE0
  set ::f4g_global_stop_reason NONE
  set ::f4i_global_stop_reason NONE
  set ::f4i_session_start_ms [clock milliseconds]
  set target_deadline [expr {$::f4i_session_start_ms + $effective_duration}]
  set hard_deadline [expr {$::f4i_session_start_ms + $hard_duration}]
  set next_slave_ms $::f4i_session_start_ms
  set next_master_ms $::f4i_session_start_ms
  set slave_cycle 0
  set master_sample 0
  while {[clock milliseconds] < $hard_deadline &&
      [clock milliseconds] < $target_deadline && $slave_cycle < $samples &&
      $::f4i_global_stop_reason eq "NONE" &&
      $::f4g_global_stop_reason eq "NONE"} {
    set did_work 0
    set now [clock milliseconds]
    if {$now >= $next_slave_ms} {
      incr slave_cycle
      f4i_emit_slave_context [lindex $slave_target 1] \
        [lindex $slave_target 2] $slave_cycle \
        [expr {[clock milliseconds] - $::f4i_session_start_ms}]
      set next_slave_ms [expr {[clock milliseconds] + $gap_ms}]
      set did_work 1
    }
    if {$::f4i_global_stop_reason ne "NONE" ||
        $::f4g_global_stop_reason ne "NONE"} { break }
    set now [clock milliseconds]
    if {$now >= $next_master_ms} {
      incr master_sample
      f4i_emit_master_context [lindex $master_target 1] \
        [lindex $master_target 2] $master_sample
      set next_master_ms [expr {[clock milliseconds] + 3000}]
      set did_work 1
    }
    if {$::f4i_global_stop_reason ne "NONE" ||
        $::f4g_global_stop_reason ne "NONE"} { break }
    if {!$did_work} {
      set now [clock milliseconds]
      set next_due $next_slave_ms
      if {$next_master_ms < $next_due} { set next_due $next_master_ms }
      set remaining [expr {$next_due - $now}]
      if {$remaining > 100} { set remaining 100 }
      if {$remaining > 0} { after $remaining }
    }
  }
  set ::f4i_session_end_ms [clock milliseconds]
  set session_elapsed [expr {$::f4i_session_end_ms - $::f4i_session_start_ms}]
  if {$::f4g_global_stop_reason ne "NONE"} {
    set ::f4i_global_stop_reason $::f4g_global_stop_reason
  }
  if {$::f4i_global_stop_reason ne "NONE"} {
    set end_reason STOP_$::f4i_global_stop_reason
  } elseif {$slave_cycle >= $samples} {
    set end_reason SAMPLE_LIMIT
  } elseif {$session_elapsed >= $effective_duration} {
    set end_reason TARGET_REACHED
  } elseif {$session_elapsed >= $hard_duration} {
    set end_reason HARD_DEADLINE
  } else {
    set end_reason OBSERVER_EXIT
  }
  foreach target [list $master_target $slave_target] {
    set role [lindex $target 0]
    set hardware_name [lindex $target 1]
    set ::f4i_run_end_reason($hardware_name) $end_reason
    puts [join [list STEP5_F4I_ROLE_SUMMARY "role=$role" \
      "board=$hardware_name" "trace_count=$::f4i_trace_count($hardware_name)" \
      "trace_valid_count=$::f4i_trace_valid_count($hardware_name)" \
      "trace_unique_count=$::f4i_trace_unique_count($hardware_name)" \
      "trace_duplicate_count=$::f4i_trace_duplicate_count($hardware_name)" \
      "domain_change_count=$::f4i_domain_change_count($hardware_name)" \
      "main_progress_count=$::f4i_main_progress_count($hardware_name)" \
      "stop_reason=$::f4i_stop_reason($hardware_name)" \
      "run_end_reason=$end_reason"] " "]
  }
  puts [join [list STEP5_F4I_DONE "session_elapsed_ms=$session_elapsed" \
    "target_duration_ms=$effective_duration" "hard_duration_ms=$hard_duration" \
    "slave_cycles=$slave_cycle" "master_samples=$master_sample" \
    "slave_trace_unique=$::f4i_trace_unique_count([lindex $slave_target 1])" \
    "slave_trace_duplicates=$::f4i_trace_duplicate_count([lindex $slave_target 1])" \
    "slave_domain_changes=$::f4i_domain_change_count([lindex $slave_target 1])" \
    "run_end_reason=$end_reason" "stop_reason=$::f4i_global_stop_reason" \
    "single_reader=PASS" "step5_complete=NO" "step5_pass=NO" \
    "merge_approved=NO"] " "]
  flush stdout
}

# -------------------------------------------------------------------------
# F4J: Main producer-handoff snapshot audit
# -------------------------------------------------------------------------

proc f4j_set_stop {reason} {
  if {$::f4j_global_stop_reason ne "NONE"} { return }
  set ::f4j_global_stop_reason $reason
  foreach hardware_name [array names ::f4j_stop_reason] {
    set ::f4j_stop_reason($hardware_name) $reason
  }
  if {$::f4g_global_stop_reason eq "NONE"} {
    f4g_set_stop $reason
  }
}

proc f4j_initialize_board {role hardware_name} {
  f4g_initialize_board $role $hardware_name
  set ::f4j_last_update_id($hardware_name) INVALID
  set ::f4j_last_sample_n($hardware_name) INVALID
  set ::f4j_last_init_generation($hardware_name) INVALID
  set ::f4j_last_producer_epoch($hardware_name) INVALID
  set ::f4j_no_valid_since_ms($hardware_name) INVALID
  set ::f4j_valid_count($hardware_name) 0
  set ::f4j_unique_count($hardware_name) 0
  set ::f4j_duplicate_count($hardware_name) 0
  set ::f4j_update_progress_count($hardware_name) 0
  set ::f4j_sample_progress_count($hardware_name) 0
  set ::f4j_bin_keys($hardware_name) {}
  set ::f4j_frequency_branch_count($hardware_name) 0
  set ::f4j_phase_branch_count($hardware_name) 0
  set ::f4j_phase_call_count($hardware_name) 0
  set ::f4j_phase_in_band_count($hardware_name) 0
  set ::f4j_phase_out_band_count($hardware_name) 0
  set ::f4j_helper_lock_seen($hardware_name) 0
  set ::f4j_helper_unlock_streak($hardware_name) 0
  set ::f4j_helper_rail_streak($hardware_name) 0
  set ::f4j_phy_bad_streak($hardware_name) 0
  set ::f4j_master_wr_transport_streak($hardware_name) 0
  set ::f4j_stop_reason($hardware_name) NONE
  set ::f4j_run_end_reason($hardware_name) NOT_REACHED
  set ::f4j_metadata_seen($hardware_name) 0
  set ::f4j_next_service_ms($hardware_name) 0
}

proc f4j_update_master_wr_health {hardware_name wr_valid wr_transport_failure} {
  if {$wr_valid} {
    set ::f4j_master_wr_transport_streak($hardware_name) 0
  } elseif {$wr_transport_failure} {
    incr ::f4j_master_wr_transport_streak($hardware_name)
    if {$::f4j_master_wr_transport_streak($hardware_name) >= 3} {
      f4j_set_stop DATA_UNRESOLVED
    }
  }
}

proc f4j_invalid_producer_result {host_start_ms host_end_ms attempts transport_failure} {
  set payload [lrepeat 33 INVALID]
  set fields [lrepeat 36 INVALID]
  return [concat [list 0] $fields [list $payload $host_start_ms $host_end_ms \
    $attempts $transport_failure]]
}

proc f4j_read_main_producer {hardware_name} {
  set host_start_ms [clock milliseconds]
  set attempts 0
  set transport_failure 0
  set result {}
  set producer_offsets {0x00100B5C 0x00100B60 0x00100B64 0x00100B68 \
    0x00100B6C 0x00100B70 0x00100B74 0x00100B78 0x00100B7C 0x00100B80 \
    0x00100B84 0x00100B88 0x00100B8C 0x00100B90 0x00100B94 0x00100B98 \
    0x00100B9C 0x00100BA0 0x00100BA4 0x00100BA8 0x00100BAC 0x00100BB0 \
    0x00100BB4 0x00100BB8 0x00100BBC 0x00100BC0 0x00100BC4 0x00100BC8 \
    0x00100BCC 0x00100BD0 0x00100BD4 0x00100BD8 0x00100BDC}
  for {set attempt 1} {$attempt <= 6} {incr attempt} {
    set attempts $attempt
    set publication_before_raw [wb_read $hardware_name 0x00100B58]
    set publication_before [word32 $publication_before_raw]
    if {$publication_before < 0 || ($publication_before & 1)} {
      if {$publication_before_raw eq "TIMEOUT"} { set transport_failure 1 }
      after 1
      continue
    }
    set payload {}
    foreach address $producer_offsets {
      set raw [wb_read $hardware_name $address]
      if {$raw eq "TIMEOUT"} { set transport_failure 1 }
      lappend payload $raw
    }
    set publication_after_raw [wb_read $hardware_name 0x00100B58]
    if {$publication_after_raw eq "TIMEOUT"} { set transport_failure 1 }
    set publication_after [word32 $publication_after_raw]
    set producer_epoch [word32 [lindex $payload 0]]
    set update_id [word32 [lindex $payload 1]]
    set init_generation [word32 [lindex $payload 2]]
    set producer_identity [word32 [lindex $payload 3]]
    set freq_error [signed32 [lindex $payload 4]]
    set branch_id [word32 [lindex $payload 5]]
    set branch_error [signed32 [lindex $payload 6]]
    set pi_x [signed32 [lindex $payload 7]]
    set pi_output [signed32 [lindex $payload 8]]
    set pi_clamp_side [signed32 [lindex $payload 9]]
    set flags [word32 [lindex $payload 10]]
    set freq_before [word32 [lindex $payload 11]]
    set freq_after [word32 [lindex $payload 12]]
    set phase_before [word32 [lindex $payload 13]]
    set phase_after [word32 [lindex $payload 14]]
    set sample_n [word32 [lindex $payload 15]]
    set source_ids [word32 [lindex $payload 16]]
    set total_updates [word32 [lindex $payload 17]]
    set freq_updates [word32 [lindex $payload 18]]
    set phase_updates [word32 [lindex $payload 19]]
    set freq_to_phase [word32 [lindex $payload 20]]
    set phase_to_freq [word32 [lindex $payload 21]]
    set phase_detector [word32 [lindex $payload 22]]
    set phase_in_band [word32 [lindex $payload 23]]
    set phase_out_band [word32 [lindex $payload 24]]
    set last_transition_update [word32 [lindex $payload 25]]
    set last_transition [word32 [lindex $payload 26]]
    set status [word32 [lindex $payload 27]]
    set last_freq_update [word32 [lindex $payload 28]]
    set last_phase_update [word32 [lindex $payload 29]]
    set frame_words [word32 [lindex $payload 30]]
    set version [word32 [lindex $payload 31]]
    set magic [word32 [lindex $payload 32]]
    set raw_valid 1
    foreach raw $payload {
      if {![is_hex $raw]} { set raw_valid 0 }
    }
    set publication_coherent [expr {
      $publication_after >= 0 && $publication_before == $publication_after &&
      !($publication_after & 1) ? 1 : 0}]
    set identity_dac [expr {$producer_identity < 0 ? -1 :
      ($producer_identity & 0xff)}]
    set identity_source_ids [expr {$producer_identity < 0 ? -1 :
      ((($producer_identity >> 8) & 0xff) |
       ((($producer_identity >> 16) & 0xff) << 8))}]
    set schema_ok [expr {$raw_valid && $publication_coherent &&
      $producer_epoch >= 0 && !($producer_epoch & 1) &&
      $status == 1 && $identity_dac == 0 &&
      $identity_source_ids == $source_ids && $frame_words == 30 &&
      $version == 1 && $magic == 0x4d50344a ? 1 : 0}]
    if {$schema_ok} {
      set result [list 1 $publication_before_raw $publication_after_raw \
        $publication_after $producer_epoch $update_id $init_generation \
        $producer_identity $freq_error $branch_id $branch_error $pi_x \
        $pi_output $pi_clamp_side $flags $freq_before $freq_after \
        $phase_before $phase_after $sample_n $source_ids $total_updates \
        $freq_updates $phase_updates $freq_to_phase $phase_to_freq \
        $phase_detector $phase_in_band $phase_out_band \
        $last_transition_update $last_transition $status $last_freq_update \
        $last_phase_update $frame_words $version $magic $payload \
        $host_start_ms [clock milliseconds] $attempts $transport_failure]
      break
    }
    after 1
  }
  if {$result eq ""} {
    set result [f4j_invalid_producer_result $host_start_ms \
      [clock milliseconds] $attempts $transport_failure]
  }
  return $result
}

proc f4j_emit_main_producer {hardware_name cycle elapsed_ms} {
  set result [f4j_read_main_producer $hardware_name]
  foreach {valid publication_before_raw publication_after_raw publication_epoch \
      producer_epoch update_id init_generation producer_identity freq_error \
      branch_id branch_error pi_x pi_output pi_clamp_side flags freq_before \
      freq_after phase_before phase_after sample_n source_ids total_updates \
      freq_updates phase_updates freq_to_phase phase_to_freq phase_detector \
      phase_in_band phase_out_band last_transition_update last_transition \
      status last_freq_update last_phase_update frame_words version magic \
      payload host_start_ms host_end_ms attempts transport_failure} $result break
  set publication_coherent [expr {$valid ? 1 : 0}]
  set raw_names {PRODUCER_EPOCH UPDATE_ID INIT_GENERATION PRODUCER_IDENTITY \
    FREQ_ERROR BRANCH_ID BRANCH_ERROR PI_X PI_OUTPUT PI_CLAMP_SIDE FLAGS \
    FREQ_COUNT_BEFORE FREQ_COUNT_AFTER PHASE_COUNT_BEFORE PHASE_COUNT_AFTER \
    SAMPLE_N SOURCE_IDS TOTAL_UPDATES FREQ_UPDATES PHASE_UPDATES \
    FREQ_TO_PHASE PHASE_TO_FREQ PHASE_DETECTOR PHASE_IN_BAND PHASE_OUT_BAND \
    LAST_TRANSITION_UPDATE LAST_TRANSITION STATUS LAST_FREQ_UPDATE \
    LAST_PHASE_UPDATE FRAME_WORDS VERSION MAGIC}
  set raw_pairs {}
  for {set i 0} {$i < [llength $raw_names]} {incr i} {
    lappend raw_pairs "[lindex $raw_names $i]_RAW=0x[lindex $payload $i]"
  }
  puts [join [concat [list STEP5_F4J_MAIN_PRODUCER \
    "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "elapsed_ms=$elapsed_ms" "READ_DURATION_MS=[expr {$host_end_ms - $host_start_ms}]" \
    "MAIN_PRODUCER_VALID=$valid" "PUBLICATION_COHERENT=$publication_coherent" \
    "PUBLICATION_EPOCH_RAW_BEFORE=0x$publication_before_raw" \
    "PUBLICATION_EPOCH_RAW_AFTER=0x$publication_after_raw" \
    "PUBLICATION_EPOCH=$publication_epoch" "PRODUCER_EPOCH=$producer_epoch" \
    "UPDATE_ID=$update_id" "INIT_GENERATION=$init_generation" \
    "PRODUCER_IDENTITY=$producer_identity" "FREQ_ERROR=$freq_error" \
    "BRANCH_ID=$branch_id" "BRANCH_ERROR=$branch_error" "PI_X=$pi_x" \
    "PI_OUTPUT=$pi_output" "PI_CLAMP_SIDE=$pi_clamp_side" "FLAGS=$flags" \
    "FREQ_COUNT_BEFORE=$freq_before" "FREQ_COUNT_AFTER=$freq_after" \
    "PHASE_COUNT_BEFORE=$phase_before" "PHASE_COUNT_AFTER=$phase_after" \
    "SAMPLE_N=$sample_n" "SOURCE_IDS=$source_ids" \
    "TOTAL_UPDATES=$total_updates" "FREQ_UPDATES=$freq_updates" \
    "PHASE_UPDATES=$phase_updates" "FREQ_TO_PHASE=$freq_to_phase" \
    "PHASE_TO_FREQ=$phase_to_freq" "PHASE_DETECTOR=$phase_detector" \
    "PHASE_IN_BAND=$phase_in_band" "PHASE_OUT_BAND=$phase_out_band" \
    "LAST_TRANSITION_UPDATE=$last_transition_update" \
    "LAST_TRANSITION=$last_transition" "STATUS=$status" \
    "LAST_FREQ_UPDATE=$last_freq_update" "LAST_PHASE_UPDATE=$last_phase_update" \
    "FRAME_WORDS=$frame_words" "SCHEMA_VERSION=$version" "MAGIC=$magic" \
    "SCHEMA_MAGIC_EXPECTED=4D50344A" "PRODUCER_SOURCE=MAIN_MPLL_UPDATE_DAC0" \
    "DYNAMIC_OWNER=F4J_MAIN_PRODUCER" "TRANSPORT_FAILURE=$transport_failure" \
    "ATTEMPTS=$attempts"] $raw_pairs] " "]
  flush stdout
  return $result
}

proc f4j_update_producer_state {hardware_name elapsed_ms result} {
  set valid [lindex $result 0]
  if {!$valid} {
    if {$::f4j_no_valid_since_ms($hardware_name) eq "INVALID"} {
      set ::f4j_no_valid_since_ms($hardware_name) $elapsed_ms
    } elseif {$elapsed_ms - $::f4j_no_valid_since_ms($hardware_name) >= 10000} {
      f4j_set_stop PRODUCER_NO_VALID_10S
    }
    return [list 0 0 0 INVALID INVALID]
  }
  set ::f4j_no_valid_since_ms($hardware_name) INVALID
  incr ::f4j_valid_count($hardware_name)
  set init_generation [lindex $result 6]
  set update_id [lindex $result 5]
  set sample_n [lindex $result 19]
  set producer_epoch [lindex $result 4]
  set branch_id [lindex $result 9]
  set flags [lindex $result 14]
  set freq_error [lindex $result 8]
  if {$::f4j_last_init_generation($hardware_name) ne "INVALID" &&
      $init_generation != $::f4j_last_init_generation($hardware_name)} {
    f4j_set_stop GENERATION_CHANGE
  }
  set update_advanced 0
  set sample_advanced 0
  if {$::f4j_last_update_id($hardware_name) ne "INVALID"} {
    set delta [counter_delta $::f4j_last_update_id($hardware_name) $update_id 32]
    if {$delta eq "INVALID" || $delta > 0x7fffffff} {
      f4j_set_stop PRODUCER_UPDATE_AMBIGUOUS
    } elseif {$delta > 0} {
      set update_advanced 1
      incr ::f4j_update_progress_count($hardware_name)
    } else {
      incr ::f4j_duplicate_count($hardware_name)
    }
  }
  if {$::f4j_last_sample_n($hardware_name) ne "INVALID"} {
    set sample_delta [counter_delta $::f4j_last_sample_n($hardware_name) $sample_n 32]
    if {$sample_delta eq "INVALID" || $sample_delta > 0x7fffffff} {
      f4j_set_stop PRODUCER_SAMPLE_AMBIGUOUS
    } elseif {$sample_delta > 0} {
      set sample_advanced 1
      incr ::f4j_sample_progress_count($hardware_name)
    }
  }
  if {$update_advanced || $::f4j_last_update_id($hardware_name) eq "INVALID"} {
    incr ::f4j_unique_count($hardware_name)
    set bin_key "${branch_id}:[expr {$freq_error / 50}]"
    if {[lsearch -exact $::f4j_bin_keys($hardware_name) $bin_key] < 0} {
      lappend ::f4j_bin_keys($hardware_name) $bin_key
    }
  }
  if {$branch_id == 1} { incr ::f4j_frequency_branch_count($hardware_name) }
  if {$branch_id == 2} { incr ::f4j_phase_branch_count($hardware_name) }
  if {$branch_id == 2 && ($flags & (1 << 5))} {
    incr ::f4j_phase_call_count($hardware_name)
  }
  if {$branch_id == 2 && ($flags & (1 << 6))} {
    incr ::f4j_phase_in_band_count($hardware_name)
  }
  if {$branch_id == 2 && ($flags & (1 << 7))} {
    incr ::f4j_phase_out_band_count($hardware_name)
  }
  set ::f4j_last_update_id($hardware_name) $update_id
  set ::f4j_last_sample_n($hardware_name) $sample_n
  set ::f4j_last_init_generation($hardware_name) $init_generation
  set ::f4j_last_producer_epoch($hardware_name) $producer_epoch
  return [list 1 $update_advanced $sample_advanced $update_id $branch_id]
}

proc f4j_update_health {hardware_name elapsed_ms helper_valid helper_locked \
    helper_output helper_transport main_valid main_transport wr_valid \
    phy_link_usable terminal} {
  f4g_update_core_health $hardware_name $elapsed_ms $helper_valid \
    $helper_transport $main_valid $main_transport $wr_valid \
    [expr {$wr_valid ? 0 : 1}]
  if {$helper_valid && $helper_locked eq "1"} {
    set ::f4j_helper_lock_seen($hardware_name) 1
    set ::f4j_helper_unlock_streak($hardware_name) 0
  } elseif {$helper_valid && $helper_locked eq "0" &&
      $::f4j_helper_lock_seen($hardware_name)} {
    incr ::f4j_helper_unlock_streak($hardware_name)
  }
  if {$helper_valid && [f4g_is_number $helper_output] &&
      $::f4j_helper_lock_seen($hardware_name) &&
      ($helper_output <= 5 || $helper_output >= 65531)} {
    incr ::f4j_helper_rail_streak($hardware_name)
  } elseif {$helper_valid && [f4g_is_number $helper_output]} {
    set ::f4j_helper_rail_streak($hardware_name) 0
  }
  if {$::f4j_helper_unlock_streak($hardware_name) >= 3 ||
      $::f4j_helper_rail_streak($hardware_name) >= 3} {
    f4j_set_stop HELPER_REGRESSION
  }
  if {$wr_valid && !$phy_link_usable} {
    incr ::f4j_phy_bad_streak($hardware_name)
    if {$::f4j_phy_bad_streak($hardware_name) >= 3} {
      f4j_set_stop TRUE_PHY_GATE_NOT_MET
    }
  } elseif {$phy_link_usable} {
    set ::f4j_phy_bad_streak($hardware_name) 0
  }
  if {$terminal} { f4j_set_stop WR_SESSION_ENDED }
  if {$::f4g_global_stop_reason ne "NONE" &&
      $::f4j_global_stop_reason eq "NONE"} {
    set ::f4j_global_stop_reason $::f4g_global_stop_reason
  }
}

proc f4j_emit_slave_context {hardware_name device_name cycle elapsed_ms} {
  set context_host_start [clock milliseconds]
  set probe_started 0
  set helper_attempts 0
  set helper_accepted 0
  set helper_transport_failure 1
  set helper_update INVALID
  set helper_output INVALID
  set helper_state_valid 0
  set helper_locked INVALID
  set helper_lock_count INVALID
  set helper_residual UNKNOWN
  set helper_target INVALID
  set helper_applied INVALID
  set normal_request INVALID
  set normal_completed INVALID
  set bootstrap_done INVALID
  set main_result [f4j_invalid_producer_result 0 0 0 1]
  set main_valid 0
  set main_update INVALID
  set main_advanced 0
  set main_branch INVALID
  set wr_core_valid 0
  set phy_link_usable 0
  set terminal 0
  set wr_transport_failure 1
  set service_read 0
  set context_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set helper_capture [f4g_capture_helper_core $hardware_name $cycle]
    set helper_attempts [lindex $helper_capture 0]
    set helper_result [lindex $helper_capture 1]
    set helper_accepted [lindex $helper_result 0]
    set helper_transport_failure [lindex $helper_capture 2]
    set helper_update [lindex $helper_result 8]
    set helper_output [lindex $helper_result 9]
    set helper_state [f4g_emit_helper_state $hardware_name $cycle]
    foreach {helper_state_valid helper_locked helper_lock_count helper_threshold \
        helper_lock_samples helper_state_raw helper_limits_raw} $helper_state break
    set position_result [f4g_emit_helper_position $hardware_name $cycle]
    foreach {position_valid helper_residual normal_request normal_completed \
        bootstrap_done helper_target helper_applied} $position_result break
    set main_result [f4j_emit_main_producer $hardware_name $cycle $elapsed_ms]
    set main_valid [lindex $main_result 0]
    set main_update [lindex $main_result 5]
    set main_state_update [f4j_update_producer_state $hardware_name \
      $elapsed_ms $main_result]
    set main_advanced [lindex $main_state_update 1]
    set main_branch [lindex $main_state_update 4]
    set status_result [f4g_read_l2_word 52]
    f4g_emit_l2_word $hardware_name $cycle 52 STATUS $status_result
    set pending_result [f4g_read_l2_word 53]
    f4g_emit_l2_word $hardware_name $cycle 53 PENDING $pending_result
    f4g_emit_service_demand $hardware_name $cycle $status_result $pending_result
    set wr_result [f4g_emit_wr_core SLAVE $hardware_name $cycle \
      STEP5_F4J_WR_CORE]
    foreach {wr_core_valid terminal phy_link_usable wr_state_value \
        pstat_locked role_identity_valid reset_valid reset_changed \
        wr_transport_failure} $wr_result break
    set now_elapsed [expr {[clock milliseconds] - $::f4j_session_start_ms}]
    if {$now_elapsed >= $::f4j_next_service_ms($hardware_name)} {
      foreach {l2_probe l2_name} {54 START 55 COMPLETED 56 FAILED 57 MAX_WAIT \
          58 CURRENT_WAIT 59 LATENCY 60 FAILURE 61 FIRST_LOSS} {
        set l2_result [f4g_read_l2_word $l2_probe]
        f4g_emit_l2_word $hardware_name $cycle $l2_probe $l2_name $l2_result
      }
      set ::f4j_next_service_ms($hardware_name) [expr {$now_elapsed + 3000}]
      set service_read 1
    }
  } context_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  set context_host_end [clock milliseconds]
  set elapsed_final [expr {$context_host_end - $::f4j_session_start_ms}]
  if {$context_failed} {
    set helper_accepted 0
    set helper_state_valid 0
    set helper_locked INVALID
    set helper_output INVALID
    set main_valid 0
    set main_update INVALID
    set main_advanced 0
    set main_branch INVALID
    set wr_core_valid 0
    set phy_link_usable 0
    set terminal 0
    set wr_transport_failure 1
    set context_error [string map [list " " _ "\n" | "\r" |] $context_error]
    puts [join [list STEP5_F4J_CONTEXT_ERROR "role=SLAVE" \
      "board=$hardware_name" "cycle=$cycle" \
      "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
      "elapsed_ms=$elapsed_final" "error=$context_error"] " "]
    flush stdout
  }
  f4j_update_health $hardware_name $elapsed_final \
    [expr {$helper_accepted && $helper_state_valid ? 1 : 0}] \
    $helper_locked $helper_output $helper_transport_failure $main_valid \
    [lindex $main_result 41] $wr_core_valid $phy_link_usable $terminal
  puts [join [list STEP5_F4J_CYCLE "role=SLAVE" "board=$hardware_name" \
    "cycle=$cycle" "host_start_ms=$context_host_start" \
    "host_end_ms=$context_host_end" "elapsed_ms=$elapsed_final" \
    "context_duration_ms=[expr {$context_host_end - $context_host_start}]" \
    "HELPER_ATTEMPTS=$helper_attempts" "HELPER_CORE_VALID=$helper_accepted" \
    "HELPER_UPDATE_COUNT=$helper_update" "HELPER_STATE_VALID=$helper_state_valid" \
    "HELPER_LOCKED=$helper_locked" "HELPER_LOCK_COUNT=$helper_lock_count" \
    "POSITION_VALID=$position_valid" "HELPER_RESIDUAL_PRESENT=$helper_residual" \
    "HELPER_TARGET_CODE=$helper_target" "HELPER_APPLIED_CODE=$helper_applied" \
    "HELPER_NORMAL_REQUEST=$normal_request" \
    "HELPER_NORMAL_COMPLETED=$normal_completed" \
    "HELPER_BOOTSTRAP_DONE=$bootstrap_done" "MAIN_PRODUCER_VALID=$main_valid" \
    "MAIN_UPDATE_ID=$main_update" "MAIN_UPDATE_ADVANCED=$main_advanced" \
    "MAIN_BRANCH_ID=$main_branch" "WR_CORE_VALID=$wr_core_valid" \
    "PHY_LINK_USABLE=$phy_link_usable" "PSTAT_LOCKED=$pstat_locked" \
    "TERMINAL=$terminal" "SERVICE_READ=$service_read" \
    "STOP_REASON=$::f4j_global_stop_reason"] " "]
  flush stdout
}

proc f4j_emit_master_context {hardware_name device_name sample} {
  set context_host_start [clock milliseconds]
  set probe_started 0
  set wr_core_valid 0
  set terminal 0
  set phy_link_usable 0
  set pstat_locked INVALID
  set wr_transport_failure 1
  set context_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set wr_result [f4g_emit_wr_core MASTER $hardware_name $sample \
      STEP5_F4J_WR_CORE]
    foreach {wr_core_valid terminal phy_link_usable wr_state_value \
        pstat_locked role_identity_valid reset_valid reset_changed \
        wr_transport_failure} $wr_result break
  } context_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  set context_host_end [clock milliseconds]
  if {$context_failed} {
    set wr_core_valid 0
    set terminal 0
    set phy_link_usable 0
    set pstat_locked INVALID
    set wr_transport_failure 1
  }
  set elapsed_ms [expr {$context_host_end - $::f4j_session_start_ms}]
  # F4J intentionally samples only the Master's WR background context.  Do
  # not feed an absent Master Helper/Main producer into the shared F4G health
  # gate: that gate is for the Slave's complete service window and would
  # otherwise raise DATA_UNRESOLVED after ten seconds by design.
  f4j_update_master_wr_health $hardware_name $wr_core_valid \
    $wr_transport_failure
  puts [join [list STEP5_F4J_MASTER_SAMPLE "role=MASTER" \
    "board=$hardware_name" "sample=$sample" \
    "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
    "elapsed_ms=$elapsed_ms" "WR_CORE_VALID=$wr_core_valid" \
    "PHY_LINK_USABLE=$phy_link_usable" "PSTAT_LOCKED=$pstat_locked" \
    "TERMINAL=$terminal" "STOP_REASON=$::f4j_global_stop_reason"] " "]
  flush stdout
}

# -------------------------------------------------------------------------
# F4L: Main phase-drift and PI-integrator balance audit
# -------------------------------------------------------------------------

proc f4l_set_stop {reason} {
  if {$::f4g_global_stop_reason ne "NONE"} { return }
  foreach hardware_name [array names ::f4l_stop_reason] {
    set ::f4l_stop_reason($hardware_name) $reason
  }
  f4g_set_stop $reason
}

proc f4l_initialize_board {role hardware_name} {
  f4g_initialize_board $role $hardware_name
  set ::f4l_last_source_epoch($hardware_name) INVALID
  set ::f4l_last_init_generation($hardware_name) INVALID
  set ::f4l_last_update_id($hardware_name) INVALID
  set ::f4l_last_page($hardware_name) INVALID
  set ::f4l_no_valid_since_ms($hardware_name) INVALID
  set ::f4l_valid_count($hardware_name) 0
  set ::f4l_unique_count($hardware_name) 0
  set ::f4l_duplicate_count($hardware_name) 0
  set ::f4l_stop_reason($hardware_name) NONE
  set ::f4l_run_end_reason($hardware_name) NOT_REACHED
  set ::f4l_next_service_ms($hardware_name) 0
  set ::f4l_schedule_last_sequence($hardware_name) INVALID
  set ::f4l_schedule_valid_count($hardware_name) 0
  set ::f4l_schedule_invalid_count($hardware_name) 0
  set ::f4l_schedule_last_main_enabled($hardware_name) INVALID
  set ::f4l_schedule_last_page($hardware_name) INVALID
  set ::f4l_schedule_last_enabled_rise($hardware_name) INVALID
  set ::f4l_schedule_last_enabled_fall($hardware_name) INVALID
  set ::f4l_schedule_last_page_advance($hardware_name) INVALID
  set ::f4l_schedule_last_page_reset($hardware_name) INVALID
  set ::f4l_schedule_last_page2_due($hardware_name) INVALID
  set ::f4l_schedule_last_page2_publish($hardware_name) INVALID
  set ::f4m_current_page($hardware_name) INVALID
  set ::f4m_previous_page($hardware_name) INVALID
  set ::f4m_page_rotation_count($hardware_name) 0
  set ::f4m_page_transition_mismatch_count($hardware_name) 0
  set ::f4m_first_loss_sample_count($hardware_name) 0
  for {set page 0} {$page < 3} {incr page} {
    set page_key "$hardware_name:$page"
    set ::f4l_page_valid_count($page_key) 0
    set ::f4l_page_seen($page_key) 0
    set ::f4m_page_publish_count($page_key) 0
    set ::f4m_page_due_count($page_key) 0
    set ::f4m_page_skip_count($page_key) 0
  }
}

# Record only unique, coherent page publications observed by this reader.
# The expected page is an observer-side inference from the previous unique
# page; a mismatch is therefore called a skip/mismatch, never a firmware
# scheduling failure.  This distinction is important when a producer reset
# or a slow reader aliases the page sequence.
proc f4m_record_page {hardware_name elapsed_ms result} {
  if {!$::f4m_enabled || ![lindex $result 0]} { return }
  set page [lindex $result 4]
  set source_epoch [lindex $result 5]
  set update_id [lindex $result 6]
  set init_generation [lindex $result 7]
  set previous $::f4m_current_page($hardware_name)
  set expected $page
  if {$previous ne "INVALID"} {
    set expected [expr {($previous + 1) % 3}]
  }
  incr ::f4m_page_due_count($hardware_name:$expected)
  incr ::f4m_page_publish_count($hardware_name:$page)
  set rotation 0
  set mismatch 0
  if {$previous ne "INVALID"} {
    if {$page == $expected} {
      incr ::f4m_page_rotation_count($hardware_name)
      set rotation 1
    } else {
      incr ::f4m_page_skip_count($hardware_name:$expected)
      incr ::f4m_page_transition_mismatch_count($hardware_name)
      set mismatch 1
    }
  }
  set ::f4m_previous_page($hardware_name) $previous
  set ::f4m_current_page($hardware_name) $page
  puts [join [list STEP5_F4M_PAGE_OBSERVATION \
    "board=$hardware_name" "elapsed_ms=$elapsed_ms" \
    "current_page=$page" "previous_page=$previous" \
    "expected_page=$expected" "page_rotation=$rotation" \
    "page_transition_mismatch=$mismatch" \
    "page_publish_count_0=$::f4m_page_publish_count($hardware_name:0)" \
    "page_publish_count_1=$::f4m_page_publish_count($hardware_name:1)" \
    "page_publish_count_2=$::f4m_page_publish_count($hardware_name:2)" \
    "page_due_count_0=$::f4m_page_due_count($hardware_name:0)" \
    "page_due_count_1=$::f4m_page_due_count($hardware_name:1)" \
    "page_due_count_2=$::f4m_page_due_count($hardware_name:2)" \
    "page_skip_count_0=$::f4m_page_skip_count($hardware_name:0)" \
    "page_skip_count_1=$::f4m_page_skip_count($hardware_name:1)" \
    "page_skip_count_2=$::f4m_page_skip_count($hardware_name:2)" \
    "page2_due_count=$::f4m_page_due_count($hardware_name:2)" \
    "page2_skip_count=$::f4m_page_skip_count($hardware_name:2)" \
    "page_rotation_count=$::f4m_page_rotation_count($hardware_name)" \
    "source_epoch=$source_epoch" "update_id=$update_id" \
    "init_generation=$init_generation" \
    "semantics=UNIQUE_COHERENT_READER_OBSERVATION" \
    "skip_semantics=OBSERVER_EXPECTED_NEXT_PAGE_MISMATCH" ] " "]
  flush stdout
}

# The WRS_S_LOCK trace already has a dedicated read-only tail bank.  Sample it
# together with the current Main/Helper frame so the first terminal transition
# can be aligned to firmware's remaining-ms clock, without a second reader or
# any diagnostic request that can perturb the shared bank.
proc f4m_read_s_lock_trace {hardware_name} {
  set host_start_ms [clock milliseconds]
  set addresses {0x00100BE0 0x00100BE4 0x00100BE8 0x00100BEC \
    0x00100BF0 0x00100BF4 0x00100BF8 0x00100BFC}
  set payload {}
  set valid 1
  foreach address $addresses {
    set raw [wb_read $hardware_name $address]
    lappend payload $raw
    if {![is_hex $raw]} { set valid 0 }
  }
  set host_end_ms [clock milliseconds]
  set magic [word32 [lindex $payload 0]]
  set stage [word32 [lindex $payload 1]]
  set retry [word32 [lindex $payload 2]]
  set entry_tics [word32 [lindex $payload 3]]
  set remaining_ms [word32 [lindex $payload 4]]
  set poll_ret [signed32 [lindex $payload 5]]
  set wr_state [word32 [lindex $payload 6]]
  set seq [word32 [lindex $payload 7]]
  set trace_valid [expr {$valid && $magic == 0x5752534c ? 1 : 0}]
  return [list $trace_valid $magic $stage $retry $entry_tics \
    $remaining_ms $poll_ret $wr_state $seq $payload $host_start_ms $host_end_ms]
}

proc f4m_emit_first_loss_sample {hardware_name cycle elapsed_ms main_result \
    helper_locked helper_residual helper_target helper_applied wr_result} {
  set trace [f4m_read_s_lock_trace $hardware_name]
  foreach {trace_valid magic stage retry entry_tics remaining_ms poll_ret \
      trace_wr_state seq payload host_start_ms host_end_ms} $trace break
  set first_loss [f4g_read_l2_word 61]
  foreach {first_loss_raw first_loss_start_ms first_loss_end_ms \
      first_loss_transport_valid} $first_loss break
  set main_valid [lindex $main_result 0]
  set main_page [lindex $main_result 4]
  set main_source_epoch [lindex $main_result 5]
  set main_update [lindex $main_result 6]
  set main_generation [lindex $main_result 7]
  set main_branch [lindex $main_result 9]
  set main_flags [lindex $main_result 10]
  set main_error [lindex $main_result 11]
  set main_freq_error [lindex $main_result 12]
  set main_pi_x [lindex $main_result 13]
  set main_pi_output [lindex $main_result 14]
  set main_phase_shift [lindex $main_result 16]
  set wr_core_valid [lindex $wr_result 0]
  set wr_terminal [lindex $wr_result 1]
  set wr_state_value [lindex $wr_result 3]
  set pstat_locked [lindex $wr_result 4]
  incr ::f4m_first_loss_sample_count($hardware_name)
  set current_page $::f4m_current_page($hardware_name)
  set previous_page $::f4m_previous_page($hardware_name)
  puts [join [list STEP5_F4M_FIRST_LOSS_SAMPLE \
    "role=SLAVE" "board=$hardware_name" "cycle=$cycle" \
    "elapsed_ms=$elapsed_ms" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "trace_duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "trace_valid=$trace_valid" "SLOCK_MAGIC_RAW=[lindex $payload 0]" \
    "SLOCK_STAGE=$stage" "SLOCK_RETRY=$retry" \
    "SLOCK_ENTRY_TICS=$entry_tics" "SLOCK_REMAINING_MS=$remaining_ms" \
    "SLOCK_POLL_RET=$poll_ret" "SLOCK_WR_STATE=$trace_wr_state" \
    "SLOCK_SEQ=$seq" "SLOCK_TRACE_MULTIWORD_ATOMICITY=NOT_AVAILABLE" \
    "MAIN_F4L_VALID=$main_valid" "MAIN_F4L_PAGE=$main_page" \
    "MAIN_F4L_CURRENT_PAGE=$current_page" \
    "MAIN_F4L_PREVIOUS_PAGE=$previous_page" \
    "MAIN_F4L_SOURCE_EPOCH=$main_source_epoch" \
    "MAIN_F4L_UPDATE_ID=$main_update" \
    "MAIN_F4L_INIT_GENERATION=$main_generation" \
    "MAIN_BRANCH_ID=$main_branch" "MAIN_FLAGS=$main_flags" \
    "MAIN_BRANCH_ERROR=$main_error" "MAIN_FREQ_ERROR=$main_freq_error" \
    "MAIN_PI_X=$main_pi_x" "MAIN_PI_OUTPUT=$main_pi_output" \
    "MAIN_PHASE_SHIFT_CURRENT=$main_phase_shift" \
    "HELPER_LOCKED=$helper_locked" \
    "HELPER_RESIDUAL_PRESENT=$helper_residual" \
    "HELPER_TARGET_CODE=$helper_target" \
    "HELPER_APPLIED_CODE=$helper_applied" \
    "WR_CORE_VALID=$wr_core_valid" "WR_TERMINAL=$wr_terminal" \
    "CURRENT_WR_STATE=$wr_state_value" "PSTAT_LOCKED=$pstat_locked" \
    "L2_FIRST_LOSS_RAW=$first_loss_raw" \
    "L2_FIRST_LOSS_VALID=$first_loss_transport_valid" \
    "L2_FIRST_LOSS_READ_START_MS=$first_loss_start_ms" \
    "L2_FIRST_LOSS_READ_END_MS=$first_loss_end_ms" \
    "sample_semantics=PASSIVE_S_LOCK_AND_MAIN_CORRELATION" ] " "]
  flush stdout
}

proc f4l_invalid_main_result {host_start_ms host_end_ms attempts transport_failure} {
  # Fields 1..21 are the bracketed publication/page payload, including the
  # raw 34-word payload at field 21.  Keep the result shape identical for all
  # retry failures so the caller never shifts a later field by accident.
  return [concat [list 0] [lrepeat 21 INVALID] [list $host_start_ms \
    $host_end_ms $attempts $transport_failure]]
}

# F4S reads the existing private tail window that the firmware fills with the
# passive Main producer-schedule shadow.  It is a separate seqlock from the
# 34-word F4L frame; the observer never claims the two windows are one atomic
# firmware cycle.
proc f4l_invalid_schedule_result {host_start_ms host_end_ms attempts transport_failure} {
  return [concat [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID INVALID INVALID INVALID] [list \
    $host_start_ms $host_end_ms $attempts $transport_failure]]
}

proc f4l_read_schedule_diag {hardware_name} {
  set host_start_ms [clock milliseconds]
  set attempts 0
  set transport_failure 0
  set result ""
  set base 0x00100BE0
  set offsets {}
  for {set i 0} {$i < 8} {incr i} {
    lappend offsets [format "0x%08X" [expr {$base + (4 * $i)}]]
  }
  for {set attempt 1} {$attempt <= 6} {incr attempt} {
    set attempts $attempt
    set magic_raw [wb_read $hardware_name [lindex $offsets 0]]
    set sequence_before_raw [wb_read $hardware_name [lindex $offsets 1]]
    if {$magic_raw eq "TIMEOUT" || $sequence_before_raw eq "TIMEOUT"} {
      set transport_failure 1
    }
    set sequence_before [word32 $sequence_before_raw]
    if {$sequence_before < 0 || ($sequence_before & 1)} {
      after 1
      continue
    }
    set payload [list $magic_raw $sequence_before_raw]
    for {set i 2} {$i < 8} {incr i} {
      set raw [wb_read $hardware_name [lindex $offsets $i]]
      if {$raw eq "TIMEOUT"} { set transport_failure 1 }
      lappend payload $raw
    }
    set sequence_after_raw [wb_read $hardware_name [lindex $offsets 1]]
    if {$sequence_after_raw eq "TIMEOUT"} { set transport_failure 1 }
    set sequence_after [word32 $sequence_after_raw]
    set raw_valid 1
    foreach raw $payload {
      if {![is_hex $raw]} { set raw_valid 0 }
    }
    set magic [word32 [lindex $payload 0]]
    set state_raw [lindex $payload 2]
    set state [word32 $state_raw]
    set main_enabled [field32 $state_raw 0 1]
    set page [field32 $state_raw 8 2]
    set enabled_rise [field32 $state_raw 16 16]
    set enabled_fall [word32 [lindex $payload 3]]
    set page_advance [word32 [lindex $payload 4]]
    set page_reset [word32 [lindex $payload 5]]
    set page2_due [word32 [lindex $payload 6]]
    set page2_publish [word32 [lindex $payload 7]]
    if {$raw_valid && $magic == $::f4l_schedule_magic &&
        $sequence_before >= 0 && $sequence_after == $sequence_before &&
        !($sequence_after & 1) && $state >= 0 &&
        $main_enabled ne "INVALID" && $page ne "INVALID" &&
        $enabled_rise ne "INVALID" && $enabled_fall >= 0 &&
        $page_advance >= 0 && $page_reset >= 0 &&
        $page2_due >= 0 && $page2_publish >= 0} {
      set result [list 1 $magic_raw $sequence_before_raw \
        $sequence_after_raw $sequence_after $state_raw $main_enabled $page \
        $enabled_rise $enabled_fall $page_advance $page_reset $page2_due \
        $page2_publish $payload $host_start_ms [clock milliseconds] \
        $attempts $transport_failure]
      break
    }
    after 1
  }
  if {$result eq ""} {
    set result [f4l_invalid_schedule_result $host_start_ms \
      [clock milliseconds] $attempts $transport_failure]
  }
  return $result
}

proc f4l_emit_schedule_diag {hardware_name cycle elapsed_ms} {
  set result [f4l_read_schedule_diag $hardware_name]
  set valid [lindex $result 0]
  set magic_raw [lindex $result 1]
  set sequence_before_raw [lindex $result 2]
  set sequence_after_raw [lindex $result 3]
  set sequence [lindex $result 4]
  set state_raw [lindex $result 5]
  set main_enabled [lindex $result 6]
  set page [lindex $result 7]
  set enabled_rise [lindex $result 8]
  set enabled_fall [lindex $result 9]
  set page_advance [lindex $result 10]
  set page_reset [lindex $result 11]
  set page2_due [lindex $result 12]
  set page2_publish [lindex $result 13]
  set payload [lindex $result 14]
  set host_start_ms [lindex $result 15]
  set host_end_ms [lindex $result 16]
  set attempts [lindex $result 17]
  set transport_failure [lindex $result 18]
  if {$valid} {
    incr ::f4l_schedule_valid_count($hardware_name)
    set ::f4l_schedule_last_sequence($hardware_name) $sequence
    set ::f4l_schedule_last_main_enabled($hardware_name) $main_enabled
    set ::f4l_schedule_last_page($hardware_name) $page
    set ::f4l_schedule_last_enabled_rise($hardware_name) $enabled_rise
    set ::f4l_schedule_last_enabled_fall($hardware_name) $enabled_fall
    set ::f4l_schedule_last_page_advance($hardware_name) $page_advance
    set ::f4l_schedule_last_page_reset($hardware_name) $page_reset
    set ::f4l_schedule_last_page2_due($hardware_name) $page2_due
    set ::f4l_schedule_last_page2_publish($hardware_name) $page2_publish
  } else {
    incr ::f4l_schedule_invalid_count($hardware_name)
  }
  set raw_pairs {}
  for {set i 0} {$i < 8} {incr i} {
    lappend raw_pairs [format "F4S_W%02d_RAW=%s" $i [lindex $payload $i]]
  }
  puts [join [concat [list STEP5_${::f4l_event_tag}_MAIN_SCHEDULE \
    "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "elapsed_ms=$elapsed_ms" \
    "READ_DURATION_MS=[expr {$host_end_ms - $host_start_ms}]" \
    "SCHEDULE_VALID=$valid" "TRANSPORT_COHERENT=[expr {$valid ? 1 : 0}]" \
    "MAGIC_RAW=$magic_raw" \
    "SEQUENCE_RAW_BEFORE=0x$sequence_before_raw" \
    "SEQUENCE_RAW_AFTER=0x$sequence_after_raw" "SEQUENCE=$sequence" \
    "STATE_RAW=$state_raw" "MAIN_ENABLED_CURRENT=$main_enabled" \
    "MAIN_ENABLED_RISE_COUNT=$enabled_rise" \
    "MAIN_ENABLED_FALL_COUNT=$enabled_fall" \
    "F4L_PAGE_SELECTOR_CURRENT=$page" \
    "F4L_PAGE_ADVANCE_COUNT=$page_advance" \
    "F4L_PAGE_RESET_TO_SUMMARY_COUNT=$page_reset" \
    "F4L_PAGE2_DUE_COUNT=$page2_due" \
    "F4L_PAGE2_PUBLISH_COUNT=$page2_publish" \
    "SCHEMA_MAGIC_EXPECTED=46345331" "FRAME_WORDS=8" \
    "TRANSPORT_FAILURE=$transport_failure" "ATTEMPTS=$attempts" \
    "SCHEDULE_SOURCE=TASK_DIAGS_F4L_MAIN_PRODUCER" \
    "NON_ATOMIC_WITH_F4L_FRAME=1"] $raw_pairs] " "]
  flush stdout
  return $result
}

proc f4l_read_main_diag {hardware_name} {
  set host_start_ms [clock milliseconds]
  set attempts 0
  set transport_failure 0
  set result ""
  set base 0x00100B58
  set offsets {}
  for {set i 0} {$i < 34} {incr i} {
    lappend offsets [format "0x%08X" [expr {$base + (4 * $i)}]]
  }
  for {set attempt 1} {$attempt <= 6} {incr attempt} {
    set attempts $attempt
    set publication_before_raw [wb_read $hardware_name $base]
    if {$publication_before_raw eq "TIMEOUT"} { set transport_failure 1 }
    set publication_before [word32 $publication_before_raw]
    if {$publication_before < 0 || ($publication_before & 1)} {
      after 1
      continue
    }
    set payload {}
    foreach address $offsets {
      set raw [wb_read $hardware_name $address]
      if {$raw eq "TIMEOUT"} { set transport_failure 1 }
      lappend payload $raw
    }
    set publication_after_raw [wb_read $hardware_name $base]
    if {$publication_after_raw eq "TIMEOUT"} { set transport_failure 1 }
    set publication_after [word32 $publication_after_raw]
    set raw_valid 1
    foreach raw $payload {
      if {![is_hex $raw]} { set raw_valid 0 }
    }
    set transport_epoch [word32 [lindex $payload 0]]
    set magic [word32 [lindex $payload 1]]
    set version_page_raw [lindex $payload 2]
    set version [field32 $version_page_raw 0 8]
    set page [field32 $version_page_raw 8 8]
    set source_epoch [word32 [lindex $payload 3]]
    set update_id [word32 [lindex $payload 4]]
    set init_generation [word32 [lindex $payload 5]]
    set producer_identity [word32 [lindex $payload 6]]
    set branch_flags_raw [lindex $payload 7]
    set branch_id [field32 $branch_flags_raw 0 8]
    set flags [field32 $branch_flags_raw 8 16]
    set clamp_code [field32 $branch_flags_raw 24 2]
    set branch_error [signed32 [lindex $payload 8]]
    set freq_error [signed32 [lindex $payload 9]]
    set pi_x [signed32 [lindex $payload 10]]
    set pi_output [signed32 [lindex $payload 11]]
    set phase_shift [signed32 [lindex $payload 12]]
    set total_updates [word32 [lindex $payload 13]]
    set frequency_updates [word32 [lindex $payload 14]]
    set phase_updates [word32 [lindex $payload 15]]
    set source_ids [word32 [lindex $payload 16]]
    set identity_dac [expr {$producer_identity < 0 ? -1 :
      ($producer_identity & 0xff)}]
    set identity_source_ids [expr {$producer_identity < 0 ? -1 :
      ((($producer_identity >> 8) & 0xff) |
       ((($producer_identity >> 16) & 0xff) << 8))}]
    set transport_coherent [expr {$raw_valid &&
      $publication_before >= 0 && $publication_after >= 0 &&
      $publication_before == $publication_after &&
      !($publication_after & 1) && $transport_epoch == $publication_after ? 1 : 0}]
    set schema_ok [expr {$transport_coherent &&
      $magic == 0x46344c31 && $version == 1 &&
      $page >= 0 && $page < 3 && $source_epoch >= 0 &&
      !($source_epoch & 1) && $source_epoch != 0 &&
      $update_id >= 0 && $init_generation >= 0 &&
      $identity_dac == 0 && $identity_source_ids == $source_ids &&
      $total_updates > 0 && $frequency_updates >= 0 &&
      $phase_updates >= 0 ? 1 : 0}]
    if {$schema_ok} {
      set result [list 1 $publication_before_raw $publication_after_raw \
        $publication_after $page $source_epoch $update_id $init_generation \
        $producer_identity $branch_id $flags $branch_error $freq_error \
        $pi_x $pi_output $clamp_code $phase_shift $total_updates \
        $frequency_updates $phase_updates $source_ids $payload \
        $host_start_ms [clock milliseconds] $attempts $transport_failure]
      break
    }
    after 1
  }
  if {$result eq ""} {
    set result [f4l_invalid_main_result $host_start_ms \
      [clock milliseconds] $attempts $transport_failure]
  }
  return $result
}

proc f4l_update_diag_state {hardware_name elapsed_ms result} {
  set valid [lindex $result 0]
  if {!$valid} {
    if {$::f4l_no_valid_since_ms($hardware_name) eq "INVALID"} {
      set ::f4l_no_valid_since_ms($hardware_name) $elapsed_ms
    } elseif {$elapsed_ms - $::f4l_no_valid_since_ms($hardware_name) >=
        $::f4l_no_valid_timeout_ms} {
      f4l_set_stop F4L_NO_VALID_TIMEOUT
    }
    return 0
  }
  set ::f4l_no_valid_since_ms($hardware_name) INVALID
  incr ::f4l_valid_count($hardware_name)
  set page [lindex $result 4]
  set source_epoch [lindex $result 5]
  set update_id [lindex $result 6]
  set init_generation [lindex $result 7]
  if {$::f4l_last_init_generation($hardware_name) ne "INVALID" &&
      $init_generation != $::f4l_last_init_generation($hardware_name)} {
    f4l_set_stop F4L_GENERATION_CHANGE
  }
  set key "$page:$source_epoch:$update_id"
  set last_key "$::f4l_last_page($hardware_name):$::f4l_last_source_epoch($hardware_name):$::f4l_last_update_id($hardware_name)"
  if {$::f4l_last_page($hardware_name) ne "INVALID" && $key eq $last_key} {
    incr ::f4l_duplicate_count($hardware_name)
  } else {
    incr ::f4l_unique_count($hardware_name)
  }
  set page_key "$hardware_name:$page"
  incr ::f4l_page_valid_count($page_key)
  set ::f4l_page_seen($page_key) 1
  set ::f4l_last_page($hardware_name) $page
  set ::f4l_last_source_epoch($hardware_name) $source_epoch
  set ::f4l_last_update_id($hardware_name) $update_id
  set ::f4l_last_init_generation($hardware_name) $init_generation
  return 1
}

proc f4l_emit_main_diag {hardware_name cycle elapsed_ms} {
  set result [f4l_read_main_diag $hardware_name]
  set valid [lindex $result 0]
  set publication_before_raw [lindex $result 1]
  set publication_after_raw [lindex $result 2]
  set publication_epoch [lindex $result 3]
  set page [lindex $result 4]
  set source_epoch [lindex $result 5]
  set update_id [lindex $result 6]
  set init_generation [lindex $result 7]
  set producer_identity [lindex $result 8]
  set branch_id [lindex $result 9]
  set flags [lindex $result 10]
  set branch_error [lindex $result 11]
  set freq_error [lindex $result 12]
  set pi_x [lindex $result 13]
  set pi_output [lindex $result 14]
  set clamp_code [lindex $result 15]
  set phase_shift [lindex $result 16]
  set total_updates [lindex $result 17]
  set frequency_updates [lindex $result 18]
  set phase_updates [lindex $result 19]
  set source_ids [lindex $result 20]
  set payload [lindex $result 21]
  set host_start_ms [lindex $result 22]
  set host_end_ms [lindex $result 23]
  set attempts [lindex $result 24]
  set transport_failure [lindex $result 25]
  set unique_before $::f4l_unique_count($hardware_name)
  set state_update [f4l_update_diag_state $hardware_name $elapsed_ms $result]
  set unique_observation [expr {$::f4l_unique_count($hardware_name) >
    $unique_before ? 1 : 0}]
  if {$::f4m_enabled && $unique_observation} {
    f4m_record_page $hardware_name $elapsed_ms $result
  }
  set raw_pairs {}
  for {set i 0} {$i < 34} {incr i} {
    lappend raw_pairs [format "F4L_W%02d_RAW=%s" $i [lindex $payload $i]]
  }
  set page_name UNKNOWN
  if {$page == 0} { set page_name SUMMARY }
  if {$page == 1} { set page_name INTEGRATOR }
  if {$page == 2} { set page_name HISTOGRAM }
  puts [join [concat [list STEP5_${::f4l_event_tag}_MAIN_DIAG \
    "board=$hardware_name" "cycle=$cycle" \
    "host_start_ms=$host_start_ms" "host_end_ms=$host_end_ms" \
    "elapsed_ms=$elapsed_ms" \
    "READ_DURATION_MS=[expr {$host_end_ms - $host_start_ms}]" \
    "MAIN_F4L_VALID=$valid" "TRANSPORT_COHERENT=[expr {$valid ? 1 : 0}]" \
    "PUBLICATION_EPOCH_RAW_BEFORE=0x$publication_before_raw" \
    "PUBLICATION_EPOCH_RAW_AFTER=0x$publication_after_raw" \
    "PUBLICATION_EPOCH=$publication_epoch" "PAGE=$page" \
    "PAGE_NAME=$page_name" "SOURCE_EPOCH=$source_epoch" \
    "UPDATE_ID=$update_id" "INIT_GENERATION=$init_generation" \
    "PRODUCER_IDENTITY=$producer_identity" "SOURCE_IDS=$source_ids" \
    "BRANCH_ID=$branch_id" "FLAGS=$flags" "BRANCH_ERROR=$branch_error" \
    "FREQ_ERROR=$freq_error" "PI_X=$pi_x" "PI_OUTPUT=$pi_output" \
    "PI_CLAMP_CODE=$clamp_code" "PHASE_SHIFT_CURRENT=$phase_shift" \
    "TOTAL_UPDATES=$total_updates" "FREQUENCY_UPDATES=$frequency_updates" \
    "PHASE_UPDATES=$phase_updates" "SCHEMA_MAGIC_EXPECTED=46344C31" \
    "SCHEMA_VERSION_EXPECTED=1" "FRAME_WORDS=34" \
    "SOURCE_FRAME_EPOCH_RAW=[lindex $payload 3]" \
    "STATE_UPDATE=$state_update" "TRANSPORT_FAILURE=$transport_failure" \
    "ATTEMPTS=$attempts" "UNIQUE_OBSERVATION=$unique_observation"] $raw_pairs] " "]
  flush stdout
  return $result
}

proc f4l_emit_master_context {hardware_name device_name sample} {
  set context_host_start [clock milliseconds]
  set probe_started 0
  set wr_core_valid 0
  set terminal 0
  set phy_link_usable 0
  set pstat_locked INVALID
  set wr_transport_failure 1
  set context_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set wr_result [f4g_emit_wr_core MASTER $hardware_name $sample \
      STEP5_${::f4l_event_tag}_WR_CORE]
    foreach {wr_core_valid terminal phy_link_usable wr_state_value \
        pstat_locked role_identity_valid reset_valid reset_changed \
        wr_transport_failure} $wr_result break
  } context_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  set context_host_end [clock milliseconds]
  if {$context_failed} {
    set wr_core_valid 0
    set terminal 0
    set phy_link_usable 0
    set pstat_locked INVALID
    set wr_transport_failure 1
  }
  set elapsed_ms [expr {$context_host_end - $::f4l_session_start_ms}]
  f4g_update_core_health $hardware_name $elapsed_ms 1 0 1 0 \
    $wr_core_valid $wr_transport_failure
  if {$terminal} { f4l_set_stop WR_SESSION_ENDED }
  puts [join [list STEP5_${::f4l_event_tag}_MASTER_SAMPLE "role=MASTER" \
    "board=$hardware_name" "sample=$sample" \
    "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
    "elapsed_ms=$elapsed_ms" "WR_CORE_VALID=$wr_core_valid" \
    "PHY_LINK_USABLE=$phy_link_usable" "PSTAT_LOCKED=$pstat_locked" \
    "TERMINAL=$terminal" "STOP_REASON=$::f4g_global_stop_reason"] " "]
  flush stdout
}

proc f4l_emit_slave_context {hardware_name device_name cycle elapsed_ms} {
  set context_host_start [clock milliseconds]
  set probe_started 0
  set helper_attempts 0
  set helper_accepted 0
  set helper_transport_failure 1
  set helper_update INVALID
  set helper_output INVALID
  set helper_state_valid 0
  set helper_locked INVALID
  set helper_lock_count INVALID
  set helper_residual UNKNOWN
  set helper_target INVALID
  set helper_applied INVALID
  set normal_request INVALID
  set normal_completed INVALID
  set bootstrap_done INVALID
  set main_result [f4l_invalid_main_result 0 0 0 1]
  set main_valid 0
  set main_update INVALID
  set main_page INVALID
  set main_source_epoch INVALID
  set main_transport_failure 1
  set main_state_raw INVALID
  set main_enabled INVALID
  set main_startup_waiting 0
  set schedule_result [f4l_invalid_schedule_result 0 0 0 1]
  set schedule_valid 0
  set schedule_main_enabled INVALID
  set schedule_page INVALID
  set schedule_enabled_rise INVALID
  set schedule_enabled_fall INVALID
  set schedule_page_advance INVALID
  set schedule_page_reset INVALID
  set schedule_page2_due INVALID
  set schedule_page2_publish INVALID
  set wr_core_valid 0
  set phy_link_usable 0
  set terminal 0
  set wr_transport_failure 1
  set service_read 0
  set context_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set helper_capture [f4g_capture_helper_core $hardware_name $cycle]
    set helper_attempts [lindex $helper_capture 0]
    set helper_result [lindex $helper_capture 1]
    set helper_accepted [lindex $helper_result 0]
    set helper_transport_failure [lindex $helper_capture 2]
    set helper_update [lindex $helper_result 8]
    set helper_output [lindex $helper_result 9]
    set helper_state [f4g_emit_helper_state $hardware_name $cycle]
    foreach {helper_state_valid helper_locked helper_lock_count helper_threshold \
        helper_lock_samples helper_state_raw helper_limits_raw} $helper_state break
    set position_result [f4g_emit_helper_position $hardware_name $cycle]
    foreach {position_valid helper_residual normal_request normal_completed \
        bootstrap_done helper_target helper_applied} $position_result break
    # F4M must not spend its first startup window issuing a long 34-word F4L
    # read while Main is still disabled.  The existing Main shadow at 0xAC4 is
    # passive and already part of the WDIAGS contract; use it only as a
    # readiness gate, never as a control input.
    if {$::f4m_enabled} {
      set main_state_raw [wb_read $hardware_name 0x00100AC4]
      set main_enabled [field32 $main_state_raw 0 1]
      set main_startup_waiting [expr {
        !($helper_locked eq "1" && [f4g_is_number $main_enabled] &&
          $main_enabled == 1) ? 1 : 0}]
    }
    if {$main_startup_waiting} {
      set main_result [f4l_invalid_main_result 0 0 0 0]
      if {$::f4m_startup_gate_since_ms eq "INVALID"} {
        set ::f4m_startup_gate_since_ms $elapsed_ms
      }
      puts [join [list STEP5_F4M_STARTUP_GATE \
        "board=$hardware_name" "cycle=$cycle" \
        "elapsed_ms=$elapsed_ms" "HELPER_LOCKED=$helper_locked" \
        "MAIN_STATE_RAW=$main_state_raw" "MAIN_ENABLED=$main_enabled" \
        "RESULT=WAIT" "condition=HELPER_LOCKED_AND_MAIN_ENABLED" \
        "timeout_ms=$::f4m_startup_gate_timeout_ms"] " "]
      flush stdout
    } else {
      set ::f4m_startup_gate_seen 1
      set main_result [f4l_emit_main_diag $hardware_name $cycle $elapsed_ms]
    }
    set main_valid [lindex $main_result 0]
    set main_page [lindex $main_result 4]
    set main_source_epoch [lindex $main_result 5]
    set main_update [lindex $main_result 6]
    set main_transport_failure [lindex $main_result 25]
    if {$::f4l_schedule_mode} {
      set schedule_result [f4l_emit_schedule_diag $hardware_name $cycle $elapsed_ms]
      set schedule_valid [lindex $schedule_result 0]
      set schedule_main_enabled [lindex $schedule_result 6]
      set schedule_page [lindex $schedule_result 7]
      set schedule_enabled_rise [lindex $schedule_result 8]
      set schedule_enabled_fall [lindex $schedule_result 9]
      set schedule_page_advance [lindex $schedule_result 10]
      set schedule_page_reset [lindex $schedule_result 11]
      set schedule_page2_due [lindex $schedule_result 12]
      set schedule_page2_publish [lindex $schedule_result 13]
    }
    set status_result [f4g_read_l2_word 52]
    f4g_emit_l2_word $hardware_name $cycle 52 STATUS $status_result
    set pending_result [f4g_read_l2_word 53]
    f4g_emit_l2_word $hardware_name $cycle 53 PENDING $pending_result
    f4g_emit_service_demand $hardware_name $cycle $status_result $pending_result
    set wr_result [f4g_emit_wr_core SLAVE $hardware_name $cycle \
      STEP5_${::f4l_event_tag}_WR_CORE]
    foreach {wr_core_valid terminal phy_link_usable wr_state_value \
        pstat_locked role_identity_valid reset_valid reset_changed \
        wr_transport_failure} $wr_result break
    if {$::f4m_enabled} {
      f4m_emit_first_loss_sample $hardware_name $cycle \
        [expr {[clock milliseconds] - $::f4l_session_start_ms}] \
        $main_result $helper_locked $helper_residual $helper_target \
        $helper_applied $wr_result
    }
    set now_elapsed [expr {[clock milliseconds] - $::f4l_session_start_ms}]
    if {$now_elapsed >= $::f4l_next_service_ms($hardware_name)} {
      foreach {l2_probe l2_name} {54 START 55 COMPLETED 56 FAILED 57 MAX_WAIT \
          58 CURRENT_WAIT 59 LATENCY 60 FAILURE 61 FIRST_LOSS} {
        set l2_result [f4g_read_l2_word $l2_probe]
        f4g_emit_l2_word $hardware_name $cycle $l2_probe $l2_name $l2_result
      }
      set ::f4l_next_service_ms($hardware_name) [expr {$now_elapsed + 3000}]
      set service_read 1
    }
  } context_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  set context_host_end [clock milliseconds]
  set elapsed_final [expr {$context_host_end - $::f4l_session_start_ms}]
  if {$context_failed} {
    set helper_accepted 0
    set helper_state_valid 0
    set helper_locked INVALID
    set helper_output INVALID
    set main_valid 0
    set main_page INVALID
    set main_source_epoch INVALID
    set main_update INVALID
    set main_transport_failure 1
    set wr_core_valid 0
    set phy_link_usable 0
    set terminal 0
    set wr_transport_failure 1
    set context_error [string map [list " " _ "\n" | "\r" |] $context_error]
    puts [join [list STEP5_${::f4l_event_tag}_CONTEXT_ERROR "role=SLAVE" \
      "board=$hardware_name" "cycle=$cycle" \
      "host_start_ms=$context_host_start" "host_end_ms=$context_host_end" \
      "elapsed_ms=$elapsed_final" "error=$context_error"] " "]
    flush stdout
  }
  f4g_update_core_health $hardware_name $elapsed_final \
    [expr {$helper_accepted && $helper_state_valid ? 1 : 0}] \
    $helper_transport_failure $main_valid $main_transport_failure \
    $wr_core_valid $wr_transport_failure $main_startup_waiting
  if {$::f4m_enabled && $main_startup_waiting &&
      $::f4m_startup_gate_since_ms ne "INVALID" &&
      $elapsed_final - $::f4m_startup_gate_since_ms >=
        $::f4m_startup_gate_timeout_ms} {
    f4g_set_stop STARTUP_GATE_NOT_REACHED
  }
  if {$terminal} { f4l_set_stop WR_SESSION_ENDED }
  puts [join [list STEP5_${::f4l_event_tag}_CYCLE "role=SLAVE" "board=$hardware_name" \
    "cycle=$cycle" "host_start_ms=$context_host_start" \
    "host_end_ms=$context_host_end" "elapsed_ms=$elapsed_final" \
    "context_duration_ms=[expr {$context_host_end - $context_host_start}]" \
    "HELPER_ATTEMPTS=$helper_attempts" "HELPER_CORE_VALID=$helper_accepted" \
    "HELPER_UPDATE_COUNT=$helper_update" "HELPER_STATE_VALID=$helper_state_valid" \
    "HELPER_LOCKED=$helper_locked" "HELPER_LOCK_COUNT=$helper_lock_count" \
    "POSITION_VALID=$position_valid" "HELPER_RESIDUAL_PRESENT=$helper_residual" \
    "HELPER_TARGET_CODE=$helper_target" "HELPER_APPLIED_CODE=$helper_applied" \
    "HELPER_NORMAL_REQUEST=$normal_request" \
    "HELPER_NORMAL_COMPLETED=$normal_completed" \
    "HELPER_BOOTSTRAP_DONE=$bootstrap_done" "MAIN_F4L_VALID=$main_valid" \
    "MAIN_STATE_RAW=$main_state_raw" "MAIN_ENABLED=$main_enabled" \
    "STARTUP_GATE_WAITING=$main_startup_waiting" \
    "MAIN_F4L_PAGE=$main_page" "MAIN_F4L_SOURCE_EPOCH=$main_source_epoch" \
    "MAIN_F4L_UPDATE_ID=$main_update" "WR_CORE_VALID=$wr_core_valid" \
    "SCHEDULE_VALID=$schedule_valid" \
    "SCHEDULE_MAIN_ENABLED=$schedule_main_enabled" \
    "SCHEDULE_PAGE=$schedule_page" \
    "SCHEDULE_ENABLED_RISE=$schedule_enabled_rise" \
    "SCHEDULE_ENABLED_FALL=$schedule_enabled_fall" \
    "SCHEDULE_PAGE_ADVANCE=$schedule_page_advance" \
    "SCHEDULE_PAGE_RESET=$schedule_page_reset" \
    "SCHEDULE_PAGE2_DUE=$schedule_page2_due" \
    "SCHEDULE_PAGE2_PUBLISH=$schedule_page2_publish" \
    "PHY_LINK_USABLE=$phy_link_usable" "PSTAT_LOCKED=$pstat_locked" \
    "TERMINAL=$terminal" "SERVICE_READ=$service_read" \
    "STOP_REASON=$::f4g_global_stop_reason"] " "]
  flush stdout
}

proc run_f4l_main_phase_drift_integrator_balance {} {
  global samples target_duration_ms hard_duration_ms gap_ms
  set event_tag $::f4l_event_tag
  set targets [f4e_collect_targets]
  set master_target ""
  set slave_target ""
  foreach target $targets {
    if {[lindex $target 0] eq "MASTER"} { set master_target $target }
    if {[lindex $target 0] eq "SLAVE"} { set slave_target $target }
  }
  set effective_duration $target_duration_ms
  if {$effective_duration <= 0} {
    set effective_duration $::f4l_contract_target_duration_ms
  }
  set hard_duration $hard_duration_ms
  if {!$::f4m_enabled} {
    # F4L has one fixed observer contract: 120 s formal capture and a hard
    # 130 s wall-clock ceiling.  This protects the experiment from an
    # accidental legacy/default 240 s invocation without touching firmware
    # timeout or lock-detector behavior.  F4M keeps its separately validated
    # startup gate and caller-provided duration.
    if {$effective_duration > $::f4l_contract_target_duration_ms} {
      set effective_duration $::f4l_contract_target_duration_ms
    }
    set hard_duration $::f4l_contract_hard_duration_ms
  }
  if {$hard_duration < $effective_duration} { set hard_duration $effective_duration }
  # F4L is a passive paged diagnostic.  Use the experiment contract's short
  # smoke/no-valid windows so a missing or stale frame stops promptly.  F4M
  # retains its separately validated longer startup gate because it adds the
  # first-loss rotation observation on top of F4L.  These are observer-only
  # windows; they do not change any firmware timeout, lock detector, or
  # control path.
  if {$::f4m_enabled} {
    set no_valid_timeout_ms 30000
    set smoke_duration 60000
  } else {
    set no_valid_timeout_ms 10000
    set smoke_duration 10000
  }
  set ::f4l_no_valid_timeout_ms $no_valid_timeout_ms
  set ::f4l_smoke_duration_ms $smoke_duration
  set s_lock_trace_addresses 0x00100BE0..0x00100BFC
  if {$::f4l_schedule_mode} {
    set s_lock_trace_addresses NOT_USED_F4S_SCHEDULE_OWNS_TAIL
  }
  puts [join [list STEP5_${event_tag}_CONFIG \
    "experiment=$::f4l_experiment_name" \
    "run_role=[string tolower $event_tag]" "samples_max=$samples" "smoke_duration_ms=$smoke_duration" \
    "no_valid_timeout_ms=$no_valid_timeout_ms" \
    "target_duration_ms=$effective_duration" "hard_duration_ms=$hard_duration" \
    "cadence_hint_ms=$gap_ms" "main_f4l_window=0x00100B58..0x00100BDC" \
    "main_f4l_magic=0x46344C31" "main_f4l_version=1" \
    "main_f4l_frame_words=34" "main_f4l_page_count=3" \
    "producer_source=MAIN_MPLL_UPDATE_DAC0" \
    "page0=SUMMARY_PAGE0" "page1=INTEGRATOR_PAGE1" \
    "page2=HISTOGRAM_PAGE2" \
    "publication_coherence=TRANSPORT_EPOCH_BEFORE_EQUALS_AFTER_EVEN" \
    "source_coherence=SOURCE_EPOCH_EVEN_AND_FRAME_STABLE" \
    "main_schedule_window=0x00100BE0..0x00100BFC" \
    "main_schedule_magic=0x46345331" "main_schedule_frame_words=8" \
    "main_schedule_source=TASK_DIAGS_F4L_MAIN_PRODUCER" \
    "main_schedule_non_atomic_with_f4l_frame=1" \
    "helper_core=F4G_COMPACT_SOURCE_CONTRACT" \
    "helper_position_probes=42,43,44,49" "l2_probes=52..61" \
    "phy_status_source=JTAG_PROBE0" "phy_status_instance=0" \
    "phy_status_width_bits=64" "phy_required_mask=000000CF" \
    "main_f4l_background_cadence_ms=2000" "read_only_observer=1" \
    "one_reader=1" "reader_processes=1" "no_control_write=1" \
    "no_helper_pi_snapshot=1" "no_debug_fifo_drain=1" \
    "no_shared_control_struct_extension=1" "no_rtl_or_sdb_change=1" \
    "control_parameters_unchanged=1" "step5_complete=NO" \
    "merge_approved=NO" "f4m_observer_enabled=$::f4m_enabled" \
    "startup_gate_condition=HELPER_LOCKED_AND_MAIN_ENABLED" \
    "startup_gate_timeout_ms=$::f4m_startup_gate_timeout_ms" \
     "s_lock_trace_addresses=$s_lock_trace_addresses" \
    "s_lock_trace_alignment=FIRMWARE_REMAINING_MS_AUXILIARY"] " "]
  flush stdout
  if {[llength $targets] != 2 || $master_target eq "" || $slave_target eq ""} {
    puts "STEP5_${event_tag}_CONFIG_ERROR required=MASTER+SLAVE discovered=[llength $targets]"
    puts "STEP5_${event_tag}_DONE run_end_reason=CONFIG_INVALID stop_reason=CONFIG_INVALID diagnostic_complete=NO step5_complete=NO step5_pass=NO merge_approved=NO"
    flush stdout
    return
  }
  f4l_initialize_board MASTER [lindex $master_target 1]
  f4l_initialize_board SLAVE [lindex $slave_target 1]
  set ::f4g_run_role [string tolower $event_tag]
  set ::f4g_experiment_name $::f4l_experiment_name
  set ::f4g_phy_status_source JTAG_PROBE0
  set ::f4g_global_stop_reason NONE
  set ::f4l_smoke_ok 0
  set ::f4l_session_start_ms [clock milliseconds]
  set ::f4g_session_start_ms $::f4l_session_start_ms
  set target_deadline [expr {$::f4l_session_start_ms + $effective_duration}]
  set hard_deadline [expr {$::f4l_session_start_ms + $hard_duration}]
  set next_slave_ms $::f4l_session_start_ms
  set next_master_ms $::f4l_session_start_ms
  set slave_cycle 0
  set master_sample 0
  set slave_name [lindex $slave_target 1]
  while {[clock milliseconds] < $hard_deadline &&
      [clock milliseconds] < $target_deadline && $slave_cycle < $samples &&
      $::f4g_global_stop_reason eq "NONE"} {
    set did_work 0
    set now [clock milliseconds]
    if {$now >= $next_slave_ms} {
      incr slave_cycle
      f4l_emit_slave_context [lindex $slave_target 1] \
        [lindex $slave_target 2] $slave_cycle \
        [expr {[clock milliseconds] - $::f4l_session_start_ms}]
      set next_slave_ms [expr {[clock milliseconds] + $gap_ms}]
      set did_work 1
      set elapsed_now [expr {[clock milliseconds] - $::f4l_session_start_ms}]
      if {!$::f4l_smoke_ok &&
          $elapsed_now >= $::f4l_smoke_duration_ms} {
        if {$::f4l_schedule_mode} {
          if {$::f4l_schedule_valid_count($slave_name) >= 3} {
            set ::f4l_smoke_ok 1
            puts [join [list STEP5_${event_tag}_SMOKE "board=$slave_name" \
              "elapsed_ms=$elapsed_now" "result=PASS" \
              "schedule_valid=$::f4l_schedule_valid_count($slave_name)" \
              "schedule_invalid=$::f4l_schedule_invalid_count($slave_name)" \
              "main_enabled=$::f4l_schedule_last_main_enabled($slave_name)" \
              "page=$::f4l_schedule_last_page($slave_name)" \
              "enabled_fall=$::f4l_schedule_last_enabled_fall($slave_name)" \
              "page_advance=$::f4l_schedule_last_page_advance($slave_name)" \
              "page_reset=$::f4l_schedule_last_page_reset($slave_name)" \
              "page2_due=$::f4l_schedule_last_page2_due($slave_name)" \
              "page2_publish=$::f4l_schedule_last_page2_publish($slave_name)"] " "]
            flush stdout
          } else {
            f4l_set_stop F4S_SCHEDULE_SCHEMA_NOT_READY
          }
        } else {
          set smoke_pages 1
          for {set page 0} {$page < 3} {incr page} {
            set page_key "$slave_name:$page"
            if {!$::f4l_page_seen($page_key)} { set smoke_pages 0 }
          }
          if {$::f4l_valid_count($slave_name) >= 3 && $smoke_pages} {
            set ::f4l_smoke_ok 1
            puts [join [list STEP5_${event_tag}_SMOKE "board=$slave_name" \
              "elapsed_ms=$elapsed_now" "result=PASS" \
              "valid=$::f4l_valid_count($slave_name)" \
              "unique=$::f4l_unique_count($slave_name)" \
              "page0=$::f4l_page_valid_count($slave_name:0)" \
              "page1=$::f4l_page_valid_count($slave_name:1)" \
              "page2=$::f4l_page_valid_count($slave_name:2)"] " "]
            flush stdout
          } else {
            f4l_set_stop F4L_SMOKE_SCHEMA_NOT_READY
          }
        }
      }
    }
    if {$::f4g_global_stop_reason ne "NONE"} { break }
    set now [clock milliseconds]
    if {$now >= $next_master_ms} {
      incr master_sample
      f4l_emit_master_context [lindex $master_target 1] \
        [lindex $master_target 2] $master_sample
      set next_master_ms [expr {[clock milliseconds] + 3000}]
      set did_work 1
    }
    if {$::f4g_global_stop_reason ne "NONE"} { break }
    if {!$did_work} {
      set now [clock milliseconds]
      set next_due $next_slave_ms
      if {$next_master_ms < $next_due} { set next_due $next_master_ms }
      set remaining [expr {$next_due - $now}]
      if {$remaining > 100} { set remaining 100 }
      if {$remaining > 0} { after $remaining }
    }
  }
  set ::f4l_session_end_ms [clock milliseconds]
  set session_elapsed [expr {$::f4l_session_end_ms - $::f4l_session_start_ms}]
  if {$::f4g_global_stop_reason ne "NONE"} {
    set end_reason STOP_$::f4g_global_stop_reason
  } elseif {!$::f4l_smoke_ok} {
    set end_reason SMOKE_NOT_REACHED
  } elseif {$slave_cycle >= $samples} {
    set end_reason SAMPLE_LIMIT
  } elseif {$session_elapsed >= $effective_duration} {
    set end_reason TARGET_REACHED
  } elseif {$session_elapsed >= $hard_duration} {
    set end_reason HARD_DEADLINE
  } else {
    set end_reason OBSERVER_EXIT
  }
  foreach target [list $master_target $slave_target] {
    set role [lindex $target 0]
    set hardware_name [lindex $target 1]
    set ::f4l_run_end_reason($hardware_name) $end_reason
    puts [join [list STEP5_${event_tag}_ROLE_SUMMARY "role=$role" \
      "board=$hardware_name" "diag_valid=$::f4l_valid_count($hardware_name)" \
      "diag_unique=$::f4l_unique_count($hardware_name)" \
      "diag_duplicates=$::f4l_duplicate_count($hardware_name)" \
      "page0=$::f4l_page_valid_count($hardware_name:0)" \
      "page1=$::f4l_page_valid_count($hardware_name:1)" \
      "page2=$::f4l_page_valid_count($hardware_name:2)" \
      "stop_reason=$::f4l_stop_reason($hardware_name)" \
      "run_end_reason=$end_reason"] " "]
  }
  set f4m_page_closure 0
  if {$::f4m_enabled} {
    set f4m_page_closure [expr {$::f4m_page_publish_count($slave_name:0) > 0 &&
      $::f4m_page_publish_count($slave_name:1) > 0 &&
      $::f4m_page_publish_count($slave_name:2) > 0 ? 1 : 0}]
  }
  puts [join [list STEP5_${event_tag}_DONE "session_elapsed_ms=$session_elapsed" \
    "target_duration_ms=$effective_duration" "hard_duration_ms=$hard_duration" \
    "slave_cycles=$slave_cycle" "master_samples=$master_sample" \
    "smoke_ok=$::f4l_smoke_ok" "diag_valid=$::f4l_valid_count($slave_name)" \
    "diag_unique=$::f4l_unique_count($slave_name)" \
    "page0=$::f4l_page_valid_count($slave_name:0)" \
    "page1=$::f4l_page_valid_count($slave_name:1)" \
    "page2=$::f4l_page_valid_count($slave_name:2)" \
    "schedule_valid=$::f4l_schedule_valid_count($slave_name)" \
    "schedule_invalid=$::f4l_schedule_invalid_count($slave_name)" \
    "schedule_main_enabled=$::f4l_schedule_last_main_enabled($slave_name)" \
    "schedule_page=$::f4l_schedule_last_page($slave_name)" \
    "schedule_enabled_rise=$::f4l_schedule_last_enabled_rise($slave_name)" \
    "schedule_enabled_fall=$::f4l_schedule_last_enabled_fall($slave_name)" \
    "schedule_page_advance=$::f4l_schedule_last_page_advance($slave_name)" \
    "schedule_page_reset=$::f4l_schedule_last_page_reset($slave_name)" \
    "schedule_page2_due=$::f4l_schedule_last_page2_due($slave_name)" \
    "schedule_page2_publish=$::f4l_schedule_last_page2_publish($slave_name)" \
    "page_publish_count_0=$::f4m_page_publish_count($slave_name:0)" \
    "page_publish_count_1=$::f4m_page_publish_count($slave_name:1)" \
    "page_publish_count_2=$::f4m_page_publish_count($slave_name:2)" \
    "page2_due_count=$::f4m_page_due_count($slave_name:2)" \
    "page2_skip_count=$::f4m_page_skip_count($slave_name:2)" \
    "page_rotation_count=$::f4m_page_rotation_count($slave_name)" \
    "page_transition_mismatch_count=$::f4m_page_transition_mismatch_count($slave_name)" \
    "first_loss_sample_count=$::f4m_first_loss_sample_count($slave_name)" \
    "page_closure=$f4m_page_closure" \
    "run_end_reason=$end_reason" "stop_reason=$::f4g_global_stop_reason" \
    "single_reader=PASS" "diagnostic_complete=PENDING_OFFLINE_ANALYSIS" \
    "step5_complete=NO" "step5_pass=NO" "merge_approved=NO"] " "]
  flush stdout
}

proc run_f4m_first_loss_full_rotation {} {
  # F4M reuses the established F4L reader and scheduler so that this run
  # changes only observer output: page-sequence bookkeeping plus the existing
  # WRS_S_LOCK tail snapshot.  The firmware image and all controller
  # parameters remain exactly those of the preceding F4L run.
  set ::f4m_enabled 1
  set ::f4m_startup_gate_timeout_ms 30000
  set ::f4m_startup_gate_since_ms INVALID
  set ::f4m_startup_gate_seen 0
  set ::f4l_event_tag F4M
  set ::f4l_experiment_name EXP-S5-F4M-F4L-FIRST-LOSS-FULL-ROTATION-20260916
  run_f4l_main_phase_drift_integrator_balance
}

proc run_f4j_main_producer_handoff_snapshot {} {
  global samples target_duration_ms hard_duration_ms gap_ms
  global f4k_arm f4k_expected_main_kp
  set targets [f4e_collect_targets]
  set master_target ""
  set slave_target ""
  foreach target $targets {
    if {[lindex $target 0] eq "MASTER"} { set master_target $target }
    if {[lindex $target 0] eq "SLAVE"} { set slave_target $target }
  }
  set effective_duration $target_duration_ms
  if {$effective_duration <= 0} { set effective_duration 120000 }
  set hard_duration $hard_duration_ms
  if {$hard_duration < $effective_duration} { set hard_duration $effective_duration }
  set production_control_unchanged [expr {$f4k_arm eq "UNSPECIFIED" ? 1 : 0}]
  set functional_scope [expr {$f4k_arm eq "UNSPECIFIED" ?
    "NONE" : "F4K_SLAVE_MAIN_KP_ONLY"}]
  puts [join [list STEP5_F4J_CONFIG \
    "experiment=EXP-S5-F4J-MAIN-PRODUCER-HANDOFF-SNAPSHOT-20260916" \
    "run_role=f4j" "samples_max=$samples" \
    "target_duration_ms=$effective_duration" "hard_duration_ms=$hard_duration" \
    "cadence_hint_ms=$gap_ms" "main_producer_window=0x00100B58..0x00100BDC" \
    "main_producer_magic=0x4D50344A" "main_producer_version=1" \
    "main_producer_frame_words=30" "producer_source=MAIN_MPLL_UPDATE_DAC0" \
    "publication_coherence=PUBLICATION_EPOCH_BEFORE_EQUALS_AFTER_EVEN" \
    "producer_coherence=PRODUCER_EPOCH_EVEN_AND_FRAME_STABLE" \
    "branch_formula_frequency=BRANCH_ERROR_EQUALS_MINUS20_TIMES_FREQ_ERROR" \
    "branch_formula_phase=SOURCE_CAPTURED_FINAL_SIGNED_ERROR" \
    "helper_core=F4F_COMPACT_SOURCE_CONTRACT" \
    "helper_position_probes=42,43,44,49" "l2_probes=52..61" \
    "phy_status_source=JTAG_PROBE0" "phy_status_instance=0" \
    "phy_status_width_bits=64" "phy_required_mask=000000CF" \
    "main_background_cadence_ms=3000" "read_only_observer=1" \
    "one_reader=1" "reader_processes=1" "no_control_write=1" \
    "no_helper_pi_snapshot=1" "no_debug_fifo_drain=1" \
    "production_control_unchanged=$production_control_unchanged" \
    "functional_experiment_scope=$functional_scope" \
    "source_contract_verified=YES" \
    "dynamic_owner_verified=F4J_EXPLICIT_SCHEMA" \
    "f4k_arm=$::f4k_arm" "configured_main_kp=$::f4k_expected_main_kp" \
    "configuration_provenance=identity_header" "step5_complete=NO" \
    "merge_approved=NO"] " "]
  flush stdout
  if {[llength $targets] != 2 || $master_target eq "" || $slave_target eq ""} {
    puts "STEP5_F4J_CONFIG_ERROR required=MASTER+SLAVE discovered=[llength $targets]"
    puts "STEP5_F4J_DONE run_end_reason=CONFIG_INVALID stop_reason=CONFIG_INVALID step5_complete=NO step5_pass=NO merge_approved=NO"
    flush stdout
    return
  }
  f4j_initialize_board MASTER [lindex $master_target 1]
  f4j_initialize_board SLAVE [lindex $slave_target 1]
  set ::f4g_run_role f4j
  set ::f4g_experiment_name EXP-S5-F4J-MAIN-PRODUCER-HANDOFF-SNAPSHOT-20260916
  set ::f4g_phy_status_source JTAG_PROBE0
  set ::f4g_global_stop_reason NONE
  set ::f4j_global_stop_reason NONE
  set ::f4j_session_start_ms [clock milliseconds]
  set ::f4g_session_start_ms $::f4j_session_start_ms
  set target_deadline [expr {$::f4j_session_start_ms + $effective_duration}]
  set hard_deadline [expr {$::f4j_session_start_ms + $hard_duration}]
  set next_slave_ms $::f4j_session_start_ms
  set next_master_ms $::f4j_session_start_ms
  set slave_cycle 0
  set master_sample 0
  while {[clock milliseconds] < $hard_deadline &&
      [clock milliseconds] < $target_deadline && $slave_cycle < $samples &&
      $::f4j_global_stop_reason eq "NONE" &&
      $::f4g_global_stop_reason eq "NONE"} {
    set did_work 0
    set now [clock milliseconds]
    if {$now >= $next_slave_ms} {
      incr slave_cycle
      f4j_emit_slave_context [lindex $slave_target 1] \
        [lindex $slave_target 2] $slave_cycle \
        [expr {[clock milliseconds] - $::f4j_session_start_ms}]
      set next_slave_ms [expr {[clock milliseconds] + $gap_ms}]
      set did_work 1
    }
    if {$::f4j_global_stop_reason ne "NONE" ||
        $::f4g_global_stop_reason ne "NONE"} { break }
    set now [clock milliseconds]
    if {$now >= $next_master_ms} {
      incr master_sample
      f4j_emit_master_context [lindex $master_target 1] \
        [lindex $master_target 2] $master_sample
      set next_master_ms [expr {[clock milliseconds] + 3000}]
      set did_work 1
    }
    if {$::f4j_global_stop_reason ne "NONE" ||
        $::f4g_global_stop_reason ne "NONE"} { break }
    if {!$did_work} {
      set now [clock milliseconds]
      set next_due $next_slave_ms
      if {$next_master_ms < $next_due} { set next_due $next_master_ms }
      set remaining [expr {$next_due - $now}]
      if {$remaining > 100} { set remaining 100 }
      if {$remaining > 0} { after $remaining }
    }
  }
  set ::f4j_session_end_ms [clock milliseconds]
  set session_elapsed [expr {$::f4j_session_end_ms - $::f4j_session_start_ms}]
  if {$::f4g_global_stop_reason ne "NONE" &&
      $::f4j_global_stop_reason eq "NONE"} {
    set ::f4j_global_stop_reason $::f4g_global_stop_reason
  }
  if {$::f4j_global_stop_reason ne "NONE"} {
    set end_reason STOP_$::f4j_global_stop_reason
  } elseif {$slave_cycle >= $samples} {
    set end_reason SAMPLE_LIMIT
  } elseif {$session_elapsed >= $effective_duration} {
    set end_reason TARGET_REACHED
  } elseif {$session_elapsed >= $hard_duration} {
    set end_reason HARD_DEADLINE
  } else {
    set end_reason OBSERVER_EXIT
  }
  foreach target [list $master_target $slave_target] {
    set role [lindex $target 0]
    set hardware_name [lindex $target 1]
    set ::f4j_run_end_reason($hardware_name) $end_reason
    puts [join [list STEP5_F4J_ROLE_SUMMARY "role=$role" \
      "board=$hardware_name" "producer_valid=$::f4j_valid_count($hardware_name)" \
      "producer_unique=$::f4j_unique_count($hardware_name)" \
      "producer_duplicates=$::f4j_duplicate_count($hardware_name)" \
      "update_progress=$::f4j_update_progress_count($hardware_name)" \
      "sample_progress=$::f4j_sample_progress_count($hardware_name)" \
      "branch_bins=[llength $::f4j_bin_keys($hardware_name)]" \
      "freq_branch=$::f4j_frequency_branch_count($hardware_name)" \
      "phase_branch=$::f4j_phase_branch_count($hardware_name)" \
      "phase_calls=$::f4j_phase_call_count($hardware_name)" \
      "phase_in_band=$::f4j_phase_in_band_count($hardware_name)" \
      "phase_out_band=$::f4j_phase_out_band_count($hardware_name)" \
      "stop_reason=$::f4j_stop_reason($hardware_name)" \
      "run_end_reason=$end_reason"] " "]
  }
  set slave_name [lindex $slave_target 1]
  puts [join [list STEP5_F4J_DONE "session_elapsed_ms=$session_elapsed" \
    "target_duration_ms=$effective_duration" "hard_duration_ms=$hard_duration" \
    "slave_cycles=$slave_cycle" "master_samples=$master_sample" \
    "producer_valid=$::f4j_valid_count($slave_name)" \
    "producer_unique=$::f4j_unique_count($slave_name)" \
    "producer_duplicates=$::f4j_duplicate_count($slave_name)" \
    "update_progress=$::f4j_update_progress_count($slave_name)" \
    "sample_progress=$::f4j_sample_progress_count($slave_name)" \
    "branch_bins=[llength $::f4j_bin_keys($slave_name)]" \
    "run_end_reason=$end_reason" "stop_reason=$::f4j_global_stop_reason" \
    "single_reader=PASS" "step5_complete=NO" "step5_pass=NO" \
    "merge_approved=NO"] " "]
  flush stdout
}

proc f4f_capture_profile {hardware_name device_name profile cycle} {
  set profile_start_ms [clock milliseconds]
  set final_result {}
  set attempts 0
  set probe_started 0
  set capture_error ""
  set capture_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    for {set retry_n 1} {$retry_n <= 8} {incr retry_n} {
      set attempts $retry_n
      set final_result [f4f_measurement_attempt $hardware_name $profile \
        $cycle $retry_n]
      if {[lindex $final_result 33]} { break }
      after 1
    }
  } capture_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  if {$capture_failed} {
    set profile_end_ms [clock milliseconds]
    set final_result [f4f_invalid_measurement_result $profile \
      $profile_start_ms $profile_end_ms]
    set attempts 1
    set safe_error [string map [list " " _ "\n" | "\r" |] $capture_error]
    puts [join [list STEP5_F4F_PROFILE_ERROR \
      "board=$hardware_name" "profile=$profile" "cycle=$cycle" \
      "host_start_ms=$profile_start_ms" "host_end_ms=$profile_end_ms" \
      "error=$safe_error"] " "]
    flush stdout
  }
  set profile_end_ms [clock milliseconds]
  set accepted [lindex $final_result 33]
  puts [join [list STEP5_F4F_PROFILE \
    "board=$hardware_name" \
    "profile=$profile" \
    "cycle=$cycle" \
    "attempts=$attempts" \
    "accepted=$accepted" \
    "profile_start_ms=$profile_start_ms" \
    "profile_end_ms=$profile_end_ms" \
    "profile_duration_ms=[expr {$profile_end_ms - $profile_start_ms}]" \
    "owner_unverified=[lindex $final_result 34]"] " "]
  flush stdout
  return [list $attempts $profile_start_ms $profile_end_ms $final_result]
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
  # Tcl catch returns 0 for success and non-zero for an exception.
  if {$read_ok} {
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

proc f4f_set_stop {reason} {
  if {$::f4f_global_stop_reason ne "NONE"} { return }
  set ::f4f_global_stop_reason $reason
  foreach hardware_name [array names ::f4f_role] {
    set ::f4f_stop_reason($hardware_name) $reason
  }
}

proc f4f_initialize_board {role hardware_name} {
  set ::f4f_role($hardware_name) $role
  set ::wb_toggle($hardware_name) 0
  set ::f4f_cycle_count($hardware_name) 0
  set ::f4f_full_cycles($hardware_name) 0
  set ::f4f_core_cycles($hardware_name) 0
  set ::f4f_full_accepted($hardware_name) 0
  set ::f4f_core_accepted($hardware_name) 0
  set ::f4f_core_fresh($hardware_name) 0
  set ::f4f_core_stale($hardware_name) 0
  set ::f4f_core_ambiguous($hardware_name) 0
  set ::f4f_core_first_accepted_ms($hardware_name) INVALID
  set ::f4f_core_last_accepted_ms($hardware_name) INVALID
  set ::f4f_core_last_update($hardware_name) INVALID
  set ::f4f_profile_transport_streak($hardware_name) 0
  set ::f4f_profile_no_core_since_ms($hardware_name) INVALID
  set ::f4f_background_count($hardware_name) 0
  set ::f4f_generation_baseline($hardware_name) INVALID
  set ::f4f_cpu_reset_baseline($hardware_name) INVALID
  set ::f4f_wr_reset_baseline($hardware_name) INVALID
  set ::f4f_si_drop_baseline($hardware_name) INVALID
  set ::f4f_reset_samples($hardware_name) 0
  set ::f4f_stop_reason($hardware_name) NONE
  set ::f4f_run_end_reason($hardware_name) NOT_REACHED
  set ::f4f_last_profile_end_ms($hardware_name) 0
}

proc f4f_update_reset_state {hardware_name entry_probe reset_probe} {
  set boot_generation [probe_high32 $entry_probe]
  set cpu_reset_count [probe_field32 $reset_probe 16 8]
  set wr_core_reset_count [probe_field32 $reset_probe 24 8]
  set si_drop_count [probe_field32 $reset_probe 40 8]
  set valid [expr {[string is integer -strict $boot_generation] && \
    [string is integer -strict $cpu_reset_count] && \
    [string is integer -strict $wr_core_reset_count] && \
    [string is integer -strict $si_drop_count] ? 1 : 0}]
  set changed 0
  if {$valid} {
    incr ::f4f_reset_samples($hardware_name)
    if {$::f4f_generation_baseline($hardware_name) eq "INVALID"} {
      set ::f4f_generation_baseline($hardware_name) $boot_generation
      set ::f4f_cpu_reset_baseline($hardware_name) $cpu_reset_count
      set ::f4f_wr_reset_baseline($hardware_name) $wr_core_reset_count
      set ::f4f_si_drop_baseline($hardware_name) $si_drop_count
    } elseif {$boot_generation != $::f4f_generation_baseline($hardware_name) || \
        $cpu_reset_count != $::f4f_cpu_reset_baseline($hardware_name) || \
        $wr_core_reset_count != $::f4f_wr_reset_baseline($hardware_name) || \
        $si_drop_count != $::f4f_si_drop_baseline($hardware_name)} {
      set changed 1
      f4f_set_stop RESET_OR_GENERATION_CHANGE
    }
  }
  return [list $valid $changed $boot_generation $cpu_reset_count \
    $wr_core_reset_count $si_drop_count]
}

proc f4f_update_profile_stats {hardware_name profile result elapsed_ms} {
  set accepted [lindex $result 33]
  set transport_error [lindex $result 27]
  set parse_error [lindex $result 28]
  set fresh 0
  set stale 0
  set ambiguous 0
  set producer_status NOT_MEASURED
  if {$profile eq "FULL"} {
    incr ::f4f_full_cycles($hardware_name)
    if {$accepted} { incr ::f4f_full_accepted($hardware_name) }
    set producer_status FULL_ACCEPTED_OR_REJECTED
  } else {
    incr ::f4f_core_cycles($hardware_name)
    if {$accepted} {
      incr ::f4f_core_accepted($hardware_name)
      set update_count [lindex $result 23]
      if {$::f4f_core_first_accepted_ms($hardware_name) eq "INVALID"} {
        set ::f4f_core_first_accepted_ms($hardware_name) $elapsed_ms
        set producer_status BASELINE
      } else {
        set delta [counter_delta $::f4f_core_last_update($hardware_name) \
          $update_count 32]
        if {$delta eq "INVALID" || $delta > 0x7fffffff} {
          set ambiguous 1
          incr ::f4f_core_ambiguous($hardware_name)
          set producer_status AMBIGUOUS
        } elseif {$delta > 0} {
          set fresh 1
          incr ::f4f_core_fresh($hardware_name)
          set producer_status FRESH
        } else {
          set stale 1
          incr ::f4f_core_stale($hardware_name)
          set producer_status STALE
        }
      }
      set ::f4f_core_last_update($hardware_name) $update_count
      set ::f4f_core_last_accepted_ms($hardware_name) $elapsed_ms
      set ::f4f_profile_no_core_since_ms($hardware_name) INVALID
    } else {
      # A changing epoch is the phenomenon under audit and must not be
      # mistaken for a transport outage.  The no-core guard therefore tracks
      # only transport/parse failures; the deadline remains responsible for
      # an epoch-only rejection run.
      set producer_status NOT_COHERENT
      if {$transport_error || $parse_error} {
        if {$::f4f_profile_no_core_since_ms($hardware_name) eq "INVALID"} {
          set ::f4f_profile_no_core_since_ms($hardware_name) $elapsed_ms
        }
        if {$elapsed_ms - $::f4f_profile_no_core_since_ms($hardware_name) >= 10000} {
          f4f_set_stop NO_CORE_WINDOW
        }
      }
    }
    if {$transport_error && !$accepted} {
      incr ::f4f_profile_transport_streak($hardware_name)
      if {$::f4f_profile_transport_streak($hardware_name) >= 3} {
        f4f_set_stop TRANSPORT_FAILURE
      }
    } else {
      set ::f4f_profile_transport_streak($hardware_name) 0
    }
  }
  return [list $fresh $stale $ambiguous $producer_status]
}

proc f4f_emit_background {role hardware_name device_name sample elapsed_ms} {
  set host_start_ms [clock milliseconds]
  set probe_started 0
  set read_error ""
  set status TIMEOUT
  set pstat TIMEOUT
  set wr_state TIMEOUT
  set spll_state TIMEOUT
  set wr_failure TIMEOUT
  set lock_result TIMEOUT
  set ptp_meta TIMEOUT
  set entry_probe TIMEOUT
  set reset_probe TIMEOUT
  set main_epoch TIMEOUT
  set main_update TIMEOUT
  set main_detector TIMEOUT
  set main_state TIMEOUT
  set position_raw TIMEOUT
  set accounting_raw TIMEOUT
  set l2_status TIMEOUT
  set l2_pending TIMEOUT
  set l2_completed TIMEOUT
  set read_failed [catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set probe_started 1
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set status [wb_read $hardware_name 0x00100A04]
    set pstat [wb_read $hardware_name 0x00100A0C]
    set wr_state [wb_read $hardware_name 0x00100A4C]
    set spll_state [wb_read $hardware_name 0x00100AA0]
    set wr_failure [wb_read $hardware_name 0x00100A6C]
    set lock_result [wb_read $hardware_name 0x00100A8C]
    set ptp_meta [wb_read $hardware_name 0x00100A5C]
    set entry_probe [probe_read 26]
    set reset_probe [probe_read 27]
    set main_epoch [wb_read $hardware_name 0x00100B58]
    set main_update [wb_read $hardware_name 0x00100B90]
    set main_detector [wb_read $hardware_name 0x00100AC4]
    set main_state [wb_read $hardware_name 0x00100B9C]
    set position_raw [probe_read 43]
    set accounting_raw [probe_read 44]
    set l2_status [probe_read 52]
    set l2_pending [probe_read 53]
    set l2_completed [probe_read 55]
  } read_error]
  if {$probe_started} { catch {end_insystem_source_probe} }
  set host_end_ms [clock milliseconds]
  set measured [list $status $pstat $wr_state $spll_state $wr_failure \
    $lock_result $ptp_meta $entry_probe $reset_probe $main_epoch $main_update \
    $main_detector $main_state $position_raw $accounting_raw $l2_status \
    $l2_pending $l2_completed]
  set valid 1
  set transport_error 0
  set parse_error 0
  foreach value $measured {
    if {$value eq "TIMEOUT"} { set transport_error 1 }
    if {![is_hex $value]} { set parse_error 1 }
    if {![is_hex $value]} { set valid 0 }
  }
  if {$read_failed} { set valid 0; set parse_error 1 }
  set reset_state [f4f_update_reset_state $hardware_name $entry_probe $reset_probe]
  foreach {reset_valid reset_changed boot_generation cpu_reset_count \
      wr_core_reset_count si_drop_count} $reset_state break
  set terminal 0
  set wr_failure_reason [field32 $lock_result 9 7]
  set wr_disable_valid [field32 $wr_failure 11 1]
  if {[string is integer -strict $wr_failure_reason] && \
      $wr_failure_reason >= 1 && $wr_failure_reason <= 7} {
    set terminal 1
  }
  if {[string is integer -strict $wr_disable_valid] && $wr_disable_valid == 1} {
    set terminal 1
  }
  if {$terminal} { f4f_set_stop WR_SESSION_ENDED }
  set safe_error [string map [list " " _ "\n" | "\r" |] $read_error]
  puts [join [list STEP5_F4F_BACKGROUND \
    "role=$role" \
    "board=$hardware_name" \
    "sample=$sample" \
    "elapsed_ms=$elapsed_ms" \
    "host_start_ms=$host_start_ms" \
    "host_end_ms=$host_end_ms" \
    "duration_ms=[expr {$host_end_ms - $host_start_ms}]" \
    "valid=$valid" \
    "transport_error=$transport_error" \
    "parse_error=$parse_error" \
    "status_raw=$status" \
    "pstat_raw=$pstat" \
    "wr_state_raw=$wr_state" \
    "spll_state_raw=$spll_state" \
    "wr_failure_raw=$wr_failure" \
    "lock_result_raw=$lock_result" \
    "ptp_meta_raw=$ptp_meta" \
    "entry_probe_raw=$entry_probe" \
    "reset_probe_raw=$reset_probe" \
    "main_epoch_raw=$main_epoch" \
    "main_update_raw=$main_update" \
    "main_detector_raw=$main_detector" \
    "main_state_raw=$main_state" \
    "position_raw=$position_raw" \
    "accounting_raw=$accounting_raw" \
    "l2_status_raw=$l2_status" \
    "l2_pending_raw=$l2_pending" \
    "l2_completed_raw=$l2_completed" \
    "reset_fields_valid=$reset_valid" \
    "reset_changed=$reset_changed" \
    "boot_generation=$boot_generation" \
    "cpu_reset_count=$cpu_reset_count" \
    "wr_core_reset_count=$wr_core_reset_count" \
    "si_config_drop_count=$si_drop_count" \
    "wr_failure_reason=$wr_failure_reason" \
    "wr_disable_valid=$wr_disable_valid" \
    "terminal=$terminal" \
    "stop_reason=$::f4f_global_stop_reason" \
    "read_error=$safe_error"] " "]
  incr ::f4f_background_count($hardware_name)
  flush stdout
}

proc run_f4f_helper_contract_audit {} {
  global samples target_duration_ms hard_duration_ms gap_ms
  set targets [f4e_collect_targets]
  set master_target ""
  set slave_target ""
  foreach target $targets {
    if {[lindex $target 0] eq "MASTER"} { set master_target $target }
    if {[lindex $target 0] eq "SLAVE"} { set slave_target $target }
  }
  set effective_duration $target_duration_ms
  if {$effective_duration <= 0} { set effective_duration $hard_duration_ms }
  puts [join [list STEP5_F4F_CONFIG \
    "experiment=EXP-S5-F4F-HELPER-MEASUREMENT-CONTRACT-AUDIT-20260915" \
    "run_role=f4f" \
    "samples_max=$samples" \
    "target_duration_ms=$effective_duration" \
    "hard_duration_ms=$hard_duration_ms" \
    "profiles=FULL,CORE" \
    "profile_order=FULL_then_CORE_alternating" \
    "full_attempts_max=8" \
    "core_attempts_max=8" \
    "full_window=0x00100B00..0x00100B24" \
    "core_offsets=0x00100B00,0x00100B14,0x00100B18,0x00100B1C" \
    "core_source_contract=vendor/wrpc-sw/dev/wdiags.c" \
    "core_enabled=1" \
    "background_cadence_ms=3000" \
    "read_only_observer=1" \
    "one_reader=1" \
    "reader_processes=1" \
    "no_control_write=1" \
    "no_helper_pi_snapshot=1" \
    "no_debug_fifo_drain=1" \
    "preserve_rejected_raw=1" \
    "owner_verification=UNVERIFIED" \
    "max_actual_ms=$hard_duration_ms"] " "]
  flush stdout
  if {[llength $targets] != 2 || $master_target eq "" || $slave_target eq ""} {
    puts [join [list STEP5_F4F_CONFIG_ERROR required=MASTER+SLAVE \
      discovered=[llength $targets]] " "]
    puts "STEP5_F4F_DONE run_end_reason=CONFIG_INVALID stop_reason=CONFIG_INVALID step5_complete=NO merge_approved=NO"
    flush stdout
    return
  }
  foreach target [list $master_target $slave_target] {
    f4f_initialize_board [lindex $target 0] [lindex $target 1]
  }
  set ::f4f_global_stop_reason NONE
  set ::f4f_session_start_ms [clock milliseconds]
  set target_deadline [expr {$::f4f_session_start_ms + $effective_duration}]
  set hard_deadline [expr {$::f4f_session_start_ms + $hard_duration_ms}]
  set next_slave_ms $::f4f_session_start_ms
  set next_slave_background_ms $::f4f_session_start_ms
  set next_master_background_ms $::f4f_session_start_ms
  set cycle 0
  set slave_background_sample 0
  set master_background_sample 0
  while {[clock milliseconds] < $hard_deadline && \
      [clock milliseconds] < $target_deadline && \
      $cycle < $samples && $::f4f_global_stop_reason eq "NONE"} {
    set did_work 0
    set now [clock milliseconds]
    if {$now >= $next_slave_ms} {
      incr cycle
      set profile [expr {$cycle % 2 ? "FULL" : "CORE"}]
      set slave_hardware [lindex $slave_target 1]
      set slave_device [lindex $slave_target 2]
      set capture [f4f_capture_profile $slave_hardware $slave_device \
        $profile $cycle]
      set profile_attempts [lindex $capture 0]
      set profile_start_ms [lindex $capture 1]
      set profile_end_ms [lindex $capture 2]
      set result [lindex $capture 3]
      set cycle_elapsed [expr {[clock milliseconds] - $::f4f_session_start_ms}]
      set profile_stats [f4f_update_profile_stats $slave_hardware $profile \
        $result $cycle_elapsed]
      foreach {fresh stale ambiguous producer_status} $profile_stats break
      set ::f4f_cycle_count($slave_hardware) $cycle
      set ::f4f_last_profile_end_ms($slave_hardware) $profile_end_ms
      puts [join [list STEP5_F4F_CYCLE \
        "role=SLAVE" \
        "board=$slave_hardware" \
        "cycle=$cycle" \
        "profile=$profile" \
        "profile_attempts=$profile_attempts" \
        "profile_start_ms=$profile_start_ms" \
        "profile_end_ms=$profile_end_ms" \
        "profile_duration_ms=[expr {$profile_end_ms - $profile_start_ms}]" \
        "elapsed_ms=$cycle_elapsed" \
        "accepted=[lindex $result 33]" \
        "fresh=$fresh" \
        "stale=$stale" \
        "ambiguous=$ambiguous" \
        "producer_status=$producer_status" \
        "update_count=[lindex $result 23]" \
        "epoch_before=[lindex $result 16]" \
        "epoch_after=[lindex $result 17]" \
        "TRANSPORT_ERROR=[lindex $result 27]" \
        "PARSE_ERROR=[lindex $result 28]" \
        "ODD_OR_SENTINEL=[lindex $result 29]" \
        "EPOCH_CHANGED=[lindex $result 30]" \
        "ARITHMETIC_MISMATCH=[lindex $result 31]" \
        "RANGE_MISMATCH=[lindex $result 32]" \
        "reason=[lindex $result 35]" \
        "stop_reason=$::f4f_global_stop_reason"] " "]
      flush stdout
      set next_slave_ms [expr {[clock milliseconds] + 500}]
      set did_work 1
      if {$::f4f_global_stop_reason eq "NONE" && \
          [clock milliseconds] >= $next_slave_background_ms} {
        incr slave_background_sample
        f4f_emit_background SLAVE $slave_hardware $slave_device \
          $slave_background_sample \
          [expr {[clock milliseconds] - $::f4f_session_start_ms}]
        set next_slave_background_ms [expr {[clock milliseconds] + 3000}]
      }
    }
    if {$::f4f_global_stop_reason ne "NONE"} { break }
    set now [clock milliseconds]
    if {$now >= $next_master_background_ms} {
      set master_hardware [lindex $master_target 1]
      set master_device [lindex $master_target 2]
      incr master_background_sample
      f4f_emit_background MASTER $master_hardware $master_device \
        $master_background_sample \
        [expr {[clock milliseconds] - $::f4f_session_start_ms}]
      set next_master_background_ms [expr {[clock milliseconds] + 3000}]
      set did_work 1
    }
    if {$::f4f_global_stop_reason ne "NONE"} { break }
    if {!$did_work} {
      set now [clock milliseconds]
      set next_due $next_slave_ms
      if {$next_slave_background_ms < $next_due} { set next_due $next_slave_background_ms }
      if {$next_master_background_ms < $next_due} { set next_due $next_master_background_ms }
      set remaining [expr {$next_due - $now}]
      if {$remaining > 0} {
        if {$remaining > 100} { set remaining 100 }
        after $remaining
      }
    }
  }
  set ::f4f_session_end_ms [clock milliseconds]
  set session_elapsed [expr {$::f4f_session_end_ms - $::f4f_session_start_ms}]
  if {$::f4f_global_stop_reason ne "NONE"} {
    set end_reason STOP_$::f4f_global_stop_reason
  } elseif {$cycle >= $samples} {
    set end_reason SAMPLE_LIMIT
  } elseif {$session_elapsed >= $effective_duration} {
    set end_reason TARGET_REACHED
  } elseif {$session_elapsed >= $hard_duration_ms} {
    set end_reason HARD_DEADLINE
  } else {
    set end_reason OBSERVER_EXIT
  }
  foreach target [list $master_target $slave_target] {
    set role [lindex $target 0]
    set hardware_name [lindex $target 1]
    set ::f4f_run_end_reason($hardware_name) $end_reason
    puts [join [list STEP5_F4F_ROLE_SUMMARY \
      "role=$role" \
      "board=$hardware_name" \
      "cycles=$::f4f_cycle_count($hardware_name)" \
      "full_cycles=$::f4f_full_cycles($hardware_name)" \
      "core_cycles=$::f4f_core_cycles($hardware_name)" \
      "full_accepted=$::f4f_full_accepted($hardware_name)" \
      "core_accepted=$::f4f_core_accepted($hardware_name)" \
      "core_fresh=$::f4f_core_fresh($hardware_name)" \
      "core_stale=$::f4f_core_stale($hardware_name)" \
      "core_ambiguous=$::f4f_core_ambiguous($hardware_name)" \
      "core_first_accepted_ms=$::f4f_core_first_accepted_ms($hardware_name)" \
      "core_last_accepted_ms=$::f4f_core_last_accepted_ms($hardware_name)" \
      "background_samples=$::f4f_background_count($hardware_name)" \
      "reset_samples=$::f4f_reset_samples($hardware_name)" \
      "stop_reason=$::f4f_stop_reason($hardware_name)" \
      "run_end_reason=$end_reason"] " "]
  }
  puts [join [list STEP5_F4F_DONE \
    "session_elapsed_ms=$session_elapsed" \
    "target_duration_ms=$effective_duration" \
    "hard_duration_ms=$hard_duration_ms" \
    "cycles=$cycle" \
    "slave_background_samples=$slave_background_sample" \
    "master_background_samples=$master_background_sample" \
    "run_end_reason=$end_reason" \
    "stop_reason=$::f4f_global_stop_reason" \
    "single_reader=PASS" \
    "step5_complete=NO" \
    "merge_approved=NO"] " "]
  flush stdout
}

if {$run_role eq "acquisition"} {
  run_f4e_acquisition
  exit 0
}

if {$run_role eq "f4f"} {
  run_f4f_helper_contract_audit
  exit 0
}

if {$run_role eq "f4g"} {
  set ::f4g_run_role f4g
  set ::f4g_experiment_name EXP-S5-F4G-COMPACT-HELPER-MAIN-SERVICE-WINDOW-20260915
  set ::f4g_phy_status_source WDIAGS_CTRL_LEGACY
  run_f4g_compact_progress_window
  exit 0
}

if {$run_role eq "f4h"} {
  set ::f4g_run_role f4h
  set ::f4g_experiment_name EXP-S5-F4H-PHY-STATUS-SOURCE-FIX-RETEST-20260916
  set ::f4g_phy_status_source JTAG_PROBE0
  run_f4g_compact_progress_window
  exit 0
}

if {$run_role eq "f4i"} {
  set ::f4g_run_role f4i
  set ::f4g_experiment_name EXP-S5-F4I-MAIN-FREQUENCY-PHASE-HANDOFF-AUDIT-20260916
  set ::f4g_phy_status_source JTAG_PROBE0
  run_f4i_frequency_phase_handoff_audit
  exit 0
}

if {$run_role eq "f4j"} {
  set ::f4g_run_role f4j
  set ::f4g_experiment_name EXP-S5-F4J-MAIN-PRODUCER-HANDOFF-SNAPSHOT-20260916
  set ::f4g_phy_status_source JTAG_PROBE0
  run_f4j_main_producer_handoff_snapshot
  exit 0
}

if {$run_role eq "f4l"} {
  set ::f4m_enabled 0
  set ::f4l_schedule_mode 0
  set ::f4l_event_tag F4L
  set ::f4l_experiment_name EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260919
  set ::f4g_run_role f4l
  set ::f4g_experiment_name $::f4l_experiment_name
  set ::f4g_phy_status_source JTAG_PROBE0
  run_f4l_main_phase_drift_integrator_balance
  exit 0
}

if {$run_role eq "f4s"} {
  set ::f4m_enabled 0
  set ::f4l_schedule_mode 1
  set ::f4l_event_tag F4S
  set ::f4l_experiment_name EXP-S5-F4L-PRODUCER-SCHEDULE-OBSERVABILITY-20260917
  set ::f4g_run_role f4s
  set ::f4g_experiment_name $::f4l_experiment_name
  set ::f4g_phy_status_source JTAG_PROBE0
  run_f4l_main_phase_drift_integrator_balance
  exit 0
}

if {$run_role eq "f4m"} {
  set ::f4g_phy_status_source JTAG_PROBE0
  run_f4m_first_loss_full_rotation
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
