# White Rabbit Step5 coherent closed-loop trajectory audit.
#
# This observer is paired with the single Step5 functional change:
# ENABLE_NORMAL_HPLL_TRACKER = 1 on the Slave.  DMTD/helper fields are read
# from the coherent WDIAGS seqlock payload.  TARGET/APPLIED/FINC/FDEC and the
# completed-transaction counters are independently bracketed by the existing
# completion epoch probes 43/44.  Lock/status fields are read from the same
# sample and are never used to manufacture a Step5 pass.
#
# Usage:
#   quartus_stp -t read_step5_coherent_closed_loop_trajectory_audit.tcl ?samples? ?gap_ms? ?board_filter?

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
array set ::measurement_failures {}
array set ::position_count {}
array set ::position_failures {}
array set ::transaction_failures {}
array set ::dco_failures {}
array set ::freq_count {}
array set ::freq_sum {}
array set ::freq_sumsq {}
array set ::freq_min {}
array set ::freq_max {}
array set ::freq_first {}
array set ::freq_last {}
array set ::extreme_count {}
array set ::extreme_max_abs {}
array set ::preclamp_first {}
array set ::preclamp_final {}
array set ::helper_error_final {}
array set ::helper_output_final {}
array set ::last_epoch {}
array set ::last_update_count {}
array set ::last_ref_accept_count {}
array set ::last_fb_accept_count {}
array set ::helper_lock_max {}
array set ::helper_lock_final {}
array set ::helper_locked_seen {}
array set ::helper_locked_final {}
array set ::helper_first_locked_sample {}
array set ::main_enabled_final {}
array set ::main_freq_locked_final {}
array set ::main_phase_locked_final {}
array set ::main_locked_final {}
array set ::pstat_locked_final {}
array set ::spll_delock_first {}
array set ::spll_delock_max {}
array set ::spll_delock_final {}
array set ::full_lock_started_ms {}
array set ::full_lock_last_ms {}
array set ::full_lock_max_ms {}
array set ::tracker_first {}
array set ::tracker_final {}
array set ::burst_first {}
array set ::burst_final {}
array set ::bootstrap_first {}
array set ::bootstrap_final {}
array set ::position_first {}
array set ::position_final {}
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
  if {$word < 0} { set word [expr {$word + 0x10000000000000000}] }
  return $word
}

proc signed32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  if {$word >= 0x80000000} { return [expr {$word - 0x100000000}] }
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
    return INVALID
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

proc display_value {value} {
  if {![is_hex $value]} { return $value }
  return [string toupper $value]
}

proc wb_read {hardware_name addr} {
  global poll_attempts
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex}]} {
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

proc read_coherent_measurement {hardware_name} {
  # WDIAGS private CPU offsets: epoch, tag, expected, freq, preclamp,
  # helper error, update count, helper output, ref accepts, fb accepts.
  for {set attempt 0} {$attempt < 8} {incr attempt} {
    set epoch_before [word32 [wb_read $hardware_name 0x00100B00]]
    if {$epoch_before < 0 || ($epoch_before & 1)} { continue }
    set tag [signed32 [wb_read $hardware_name 0x00100B04]]
    set expected [signed32 [wb_read $hardware_name 0x00100B08]]
    set freq [signed32 [wb_read $hardware_name 0x00100B0C]]
    set preclamp [signed32 [wb_read $hardware_name 0x00100B10]]
    set helper_error [signed32 [wb_read $hardware_name 0x00100B14]]
    set update_count [word32 [wb_read $hardware_name 0x00100B18]]
    set helper_output [signed32 [wb_read $hardware_name 0x00100B1C]]
    set ref_accept [word32 [wb_read $hardware_name 0x00100B20]]
    set fb_accept [word32 [wb_read $hardware_name 0x00100B24]]
    set epoch_after [word32 [wb_read $hardware_name 0x00100B00]]
    if {$epoch_before == $epoch_after && $epoch_after >= 0 && !($epoch_after & 1)} {
      return [list 1 $epoch_after $tag $expected $freq $preclamp $helper_error \
        $update_count $helper_output $ref_accept $fb_accept]
    }
  }
  return [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
}

proc read_stable_position {} {
  # Probe 43 contains target/applied/FINC/FDEC. Probe 44 contains completed
  # counters and a completion epoch. Only an unchanged pair is accepted.
  for {set attempt 0} {$attempt < 10} {incr attempt} {
    set accounting_before [probe_read 44]
    set position [probe_read 43]
    set accounting_after [probe_read 44]
    set epoch_before [word64 $accounting_before]
    set epoch_after [word64 $accounting_after]
    if {$epoch_before >= 0 && $epoch_after >= 0 && [word64 $position] >= 0 &&
        [string equal -nocase $accounting_before $accounting_after]} {
      set position_word [word64 $position]
      set accounting_word $epoch_after
      set target [expr {($position_word >> 0) & 0xffff}]
      set applied [expr {($position_word >> 16) & 0xffff}]
      set finc [expr {($position_word >> 32) & 0xffff}]
      set fdec [expr {($position_word >> 48) & 0xffff}]
      set normal_done [expr {($accounting_word >> 0) & 0xffff}]
      set dco_step [expr {($accounting_word >> 16) & 0xffff}]
      set bootstrap_completed [expr {($accounting_word >> 32) & 0xffff}]
      set epoch [expr {($accounting_word >> 48) & 0xffff}]
      return [list 1 $epoch $target $applied $finc $fdec $normal_done $dco_step $bootstrap_completed]
    }
    after 1
  }
  return [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
}

proc read_helper_pair {hardware_name} {
  for {set attempt 0} {$attempt < 4} {incr attempt} {
    set state [wb_read $hardware_name 0x00100ABC]
    set limits [wb_read $hardware_name 0x00100AC0]
    set threshold [field32 $limits 0 16]
    set lock_samples [field32 $limits 16 16]
    set lock_count [field32 $state 16 16]
    set locked [field32 $state 0 1]
    if {$threshold eq "200" && $lock_samples eq "10000" &&
        $lock_count ne "INVALID" && $lock_count <= $lock_samples &&
        ($locked == 0 || ($locked == 1 && $lock_count == $lock_samples))} {
      return [list $state $limits]
    }
    after 2
  }
  return [list INVALID INVALID]
}

proc initialize_board {hardware_name} {
  set ::sample_count($hardware_name) 0
  set ::coherent_count($hardware_name) 0
  set ::rejected_count($hardware_name) 0
  set ::measurement_failures($hardware_name) 0
  set ::position_count($hardware_name) 0
  set ::position_failures($hardware_name) 0
  set ::transaction_failures($hardware_name) 0
  set ::dco_failures($hardware_name) 0
  set ::freq_count($hardware_name) 0
  set ::freq_sum($hardware_name) 0.0
  set ::freq_sumsq($hardware_name) 0.0
  set ::freq_min($hardware_name) INVALID
  set ::freq_max($hardware_name) INVALID
  set ::freq_first($hardware_name) INVALID
  set ::freq_last($hardware_name) INVALID
  set ::extreme_count($hardware_name) 0
  set ::extreme_max_abs($hardware_name) 0
  set ::preclamp_first($hardware_name) INVALID
  set ::preclamp_final($hardware_name) INVALID
  set ::helper_error_final($hardware_name) INVALID
  set ::helper_output_final($hardware_name) INVALID
  set ::last_epoch($hardware_name) INVALID
  set ::last_update_count($hardware_name) INVALID
  set ::last_ref_accept_count($hardware_name) INVALID
  set ::last_fb_accept_count($hardware_name) INVALID
  set ::helper_lock_max($hardware_name) 0
  set ::helper_lock_final($hardware_name) INVALID
  set ::helper_locked_seen($hardware_name) 0
  set ::helper_locked_final($hardware_name) INVALID
  set ::helper_first_locked_sample($hardware_name) NONE
  set ::main_enabled_final($hardware_name) INVALID
  set ::main_freq_locked_final($hardware_name) INVALID
  set ::main_phase_locked_final($hardware_name) INVALID
  set ::main_locked_final($hardware_name) INVALID
  set ::pstat_locked_final($hardware_name) INVALID
  set ::spll_delock_first($hardware_name) INVALID
  set ::spll_delock_max($hardware_name) 0
  set ::spll_delock_final($hardware_name) INVALID
  set ::full_lock_started_ms($hardware_name) NONE
  set ::full_lock_last_ms($hardware_name) NONE
  set ::full_lock_max_ms($hardware_name) 0
  set ::tracker_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::tracker_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::burst_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::burst_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::bootstrap_first($hardware_name) INVALID
  set ::bootstrap_final($hardware_name) INVALID
  set ::position_first($hardware_name) [list INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
  set ::position_final($hardware_name) [list INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
  set ::reset_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::elapsed_final($hardware_name) 0
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
    if {$abs_freq > $::extreme_max_abs($hardware_name)} { set ::extreme_max_abs($hardware_name) $abs_freq }
  }
}

proc emit_sample {hardware_name sample elapsed_ms} {
  set ctrl_begin [wb_read $hardware_name 0x00100A04]
  set measurement [read_coherent_measurement $hardware_name]
  foreach {measurement_ok epoch tag_delta expected_delta freq_error preclamp helper_error update_count helper_output ref_accept fb_accept} $measurement break
  set position [read_stable_position]
  foreach {position_ok position_epoch target applied finc fdec normal_done dco_step bootstrap_completed} $position break
  set tracker_word [word64 [probe_read 39]]
  set burst_word [word64 [probe_read 37]]
  set bootstrap_word [word64 [probe_read 42]]
  set entry_probe [probe_read 26]
  set reset_probe [probe_read 27]
  foreach {helper_state helper_limits} [read_helper_pair $hardware_name] break
  set main_state [wb_read $hardware_name 0x00100AC4]
  set pstat [wb_read $hardware_name 0x00100A0C]
  set spll_state [wb_read $hardware_name 0x00100AA0]
  set ctrl_end [wb_read $hardware_name 0x00100A04]

  set target_probe [expr {$tracker_word < 0 ? "INVALID" : (($tracker_word >> 0) & 0xffff)}]
  set applied_probe [expr {$tracker_word < 0 ? "INVALID" : (($tracker_word >> 16) & 0xffff)}]
  set normal_req [expr {$tracker_word < 0 ? "INVALID" : (($tracker_word >> 32) & 0xffff)}]
  set forced_trigger [expr {$burst_word < 0 ? "INVALID" : (($burst_word >> 0) & 0xff)}]
  set forced_pending [expr {$burst_word < 0 ? "INVALID" : (($burst_word >> 8) & 0xff)}]
  set forced_done [expr {$burst_word < 0 ? "INVALID" : (($burst_word >> 16) & 0xff)}]
  set bootstrap_probe [expr {$bootstrap_word < 0 ? "INVALID" : (($bootstrap_word >> 16) & 0xffff)}]
  set bootstrap_done [expr {$bootstrap_word < 0 ? "INVALID" : (($bootstrap_word >> 33) & 1)}]
  set entry_generation [probe_high32 $entry_probe]
  set cpu_reset [probe_field32 $reset_probe 16 8]
  set wr_reset [probe_field32 $reset_probe 24 8]
  set si_drop [probe_field32 $reset_probe 40 8]
  set helper_locked [field32 $helper_state 0 1]
  set helper_lock_count [field32 $helper_state 16 16]
  set main_enabled [field32 $main_state 0 1]
  set main_locked [field32 $main_state 1 1]
  set main_freq_locked [field32 $main_state 2 1]
  set main_phase_locked [field32 $main_state 3 1]
  set pstat_locked [field32 $pstat 1 1]
  set spll_delock [field32 $spll_state 24 8]
  set valid [frame_valid $ctrl_begin $ctrl_end]

  if {$sample == 1} {
    initialize_board $hardware_name
    set ::tracker_first($hardware_name) [list $target_probe $applied_probe $normal_req $normal_done]
    set ::burst_first($hardware_name) [list $forced_trigger $forced_pending $forced_done $dco_step]
    set ::bootstrap_first($hardware_name) $bootstrap_completed
    set ::position_first($hardware_name) [list $position_ok $position_epoch $target $applied $finc $fdec $normal_done $dco_step $bootstrap_completed]
    set ::reset_first($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
    set ::spll_delock_first($hardware_name) $spll_delock
  }
  incr ::sample_count($hardware_name)
  set ::elapsed_final($hardware_name) $elapsed_ms
  set ::tracker_final($hardware_name) [list $target_probe $applied_probe $normal_req $normal_done]
  set ::burst_final($hardware_name) [list $forced_trigger $forced_pending $forced_done $dco_step]
  set ::bootstrap_final($hardware_name) $bootstrap_completed
  set ::position_final($hardware_name) [list $position_ok $position_epoch $target $applied $finc $fdec $normal_done $dco_step $bootstrap_completed]
  set ::reset_final($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
  set ::spll_delock_final($hardware_name) $spll_delock
  if {$spll_delock ne "INVALID" && $spll_delock > $::spll_delock_max($hardware_name)} { set ::spll_delock_max($hardware_name) $spll_delock }

  if {$measurement_ok} {
    incr ::coherent_count($hardware_name)
    set ::last_epoch($hardware_name) $epoch
    set ::last_update_count($hardware_name) $update_count
    set ::last_ref_accept_count($hardware_name) $ref_accept
    set ::last_fb_accept_count($hardware_name) $fb_accept
    set ::preclamp_final($hardware_name) $preclamp
    set ::helper_error_final($hardware_name) $helper_error
    set ::helper_output_final($hardware_name) $helper_output
    if {$::freq_count($hardware_name) == 0} { set ::preclamp_first($hardware_name) $preclamp }
    if {$tag_delta eq "INVALID" || $expected_delta eq "INVALID" || $freq_error eq "INVALID" ||
        $freq_error != ($tag_delta - $expected_delta)} {
      incr ::measurement_failures($hardware_name)
    } else {
      update_frequency_stats $hardware_name $freq_error
    }
  } else {
    incr ::rejected_count($hardware_name)
  }

  if {$position_ok} {
    incr ::position_count($hardware_name)
    if {$applied ne "INVALID" && $finc ne "INVALID" && $fdec ne "INVALID"} {
      set expected_applied [expr {(5 + 64 * ($finc - $fdec)) & 0xffff}]
      if {$applied != $expected_applied} { incr ::position_failures($hardware_name) }
    }
    if {$normal_done ne "INVALID" && $finc ne "INVALID" && $fdec ne "INVALID" &&
        (($finc + $fdec) & 0xffff) != $normal_done} { incr ::transaction_failures($hardware_name) }
    if {$dco_step ne "INVALID" && $bootstrap_completed ne "INVALID" && $normal_done ne "INVALID" &&
        (($bootstrap_completed + $normal_done) & 0xffff) != $dco_step} { incr ::dco_failures($hardware_name) }
  }

  if {$valid && $helper_lock_count ne "INVALID"} {
    set ::helper_lock_final($hardware_name) $helper_lock_count
    if {$helper_lock_count > $::helper_lock_max($hardware_name)} { set ::helper_lock_max($hardware_name) $helper_lock_count }
    if {$helper_locked ne "INVALID"} {
      set ::helper_locked_final($hardware_name) $helper_locked
      if {$helper_locked} {
        incr ::helper_locked_seen($hardware_name)
        if {$::helper_first_locked_sample($hardware_name) eq "NONE"} { set ::helper_first_locked_sample($hardware_name) $sample }
      }
    }
    set ::main_enabled_final($hardware_name) $main_enabled
    set ::main_freq_locked_final($hardware_name) $main_freq_locked
    set ::main_phase_locked_final($hardware_name) $main_phase_locked
    set ::main_locked_final($hardware_name) $main_locked
    set ::pstat_locked_final($hardware_name) $pstat_locked
    set full_locked [expr {$helper_locked == 1 && $main_enabled == 1 && $main_freq_locked == 1 &&
      $main_phase_locked == 1 && $main_locked == 1 && $pstat_locked == 1}]
    if {$full_locked} {
      if {$::full_lock_started_ms($hardware_name) eq "NONE"} { set ::full_lock_started_ms($hardware_name) $elapsed_ms }
      set ::full_lock_last_ms($hardware_name) $elapsed_ms
    } elseif {$::full_lock_started_ms($hardware_name) ne "NONE"} {
      set span [expr {$::full_lock_last_ms($hardware_name) - $::full_lock_started_ms($hardware_name)}]
      if {$span > $::full_lock_max_ms($hardware_name)} { set ::full_lock_max_ms($hardware_name) $span }
      set ::full_lock_started_ms($hardware_name) NONE
      set ::full_lock_last_ms($hardware_name) NONE
    }
  }

  puts [format "STEP5_CLOSED_LOOP_SAMPLE board=%s sample=%d elapsed_ms=%d FRAME_VALID=%d COHERENT=%d EPOCH=%s TAG_DELTA_USED=%s EXPECTED_DELTA_USED=%s FREQ_ERROR_USED=%s PRECLAMP_ERROR=%s HELPER_ERROR=%s HELPER_OUTPUT=%s HELPER_UPDATE_COUNT=%s DMTD_REF_ACCEPT_COUNT=%s DMTD_FB_ACCEPT_COUNT=%s POSITION_VALID=%d POSITION_EPOCH=%s TARGET_CODE=%s APPLIED_CODE=%s FINC_COMPLETED=%s FDEC_COMPLETED=%s NORMAL_REQ=%s NORMAL_COMPLETED=%s DCO_STEP=%s BOOTSTRAP_COMPLETED=%s BOOTSTRAP_DONE=%s HELPER_LOCKED=%s HELPER_LOCK_COUNT=%s MAIN_ENABLED=%s MAIN_FREQ_LOCKED=%s MAIN_PHASE_LOCKED=%s MAIN_LOCKED=%s PSTAT_LOCKED=%s SPLL_DELOCK_COUNT=%s FORCED_COMPLETED=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
    $hardware_name $sample $elapsed_ms $valid $measurement_ok $epoch $tag_delta $expected_delta $freq_error $preclamp $helper_error $helper_output $update_count $ref_accept $fb_accept $position_ok $position_epoch $target $applied $finc $fdec $normal_req $normal_done $dco_step $bootstrap_completed $bootstrap_done $helper_locked $helper_lock_count $main_enabled $main_freq_locked $main_phase_locked $main_locked $pstat_locked $spll_delock $forced_done $entry_generation $cpu_reset $wr_reset $si_drop]
  flush stdout
}

proc emit_summary {hardware_name} {
  foreach {target0 applied0 req0 done0} $::tracker_first($hardware_name) break
  foreach {target1 applied1 req1 done1} $::tracker_final($hardware_name) break
  foreach {trigger0 pending0 forced0 step0} $::burst_first($hardware_name) break
  foreach {trigger1 pending1 forced1 step1} $::burst_final($hardware_name) break
  foreach {posok0 posepoch0 ptarget0 papplied0 finc0 fdec0 pnormal0 pdco0 pboot0} $::position_first($hardware_name) break
  foreach {posok1 posepoch1 ptarget1 papplied1 finc1 fdec1 pnormal1 pdco1 pboot1} $::position_final($hardware_name) break
  foreach {gen0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {gen1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  set req_delta [counter_delta $req0 $req1 16]
  set done_delta [counter_delta $pnormal0 $pnormal1 16]
  set finc_delta [counter_delta $finc0 $finc1 16]
  set fdec_delta [counter_delta $fdec0 $fdec1 16]
  set dco_delta [counter_delta $pdco0 $pdco1 16]
  set forced_delta [counter_delta $forced0 $forced1 8]
  set bootstrap_delta [counter_delta $pboot0 $pboot1 16]
  set gen_delta [counter_delta $gen0 $gen1 32]
  set cpu_delta [counter_delta $cpu0 $cpu1 8]
  set wr_delta [counter_delta $wr0 $wr1 8]
  set si_delta [counter_delta $si0 $si1 8]
  set expected_net [expr {$finc_delta eq "INVALID" || $fdec_delta eq "INVALID" ? "INVALID" : ($finc_delta - $fdec_delta)}]
  set expected_applied [expr {$expected_net eq "INVALID" ? "INVALID" : ((5 + 64 * $expected_net) & 0xffff)}]
  set freq_mean INVALID
  set freq_rms INVALID
  if {$::freq_count($hardware_name) > 0} {
    set freq_mean [expr {$::freq_sum($hardware_name) / double($::freq_count($hardware_name))}]
    set freq_rms [expr {sqrt($::freq_sumsq($hardware_name) / double($::freq_count($hardware_name)))}]
  }
  set position_accounting [expr {$::position_count($hardware_name) > 0 && $::position_failures($hardware_name) == 0 &&
    $::transaction_failures($hardware_name) == 0 && $::dco_failures($hardware_name) == 0 ? "PASS" : "FAIL"}]
  set measurement_accounting [expr {$::coherent_count($hardware_name) > 0 && $::measurement_failures($hardware_name) == 0 ? "PASS" : "FAIL"}]
  set reset_result [expr {$gen_delta eq "0" && $cpu_delta eq "0" && $wr_delta eq "0" && $si_delta eq "0" ? "PASS" : "FAIL"}]
  set full_span_ms $::full_lock_max_ms($hardware_name)
  if {$::full_lock_started_ms($hardware_name) ne "NONE"} {
    set live_span [expr {$::full_lock_last_ms($hardware_name) - $::full_lock_started_ms($hardware_name)}]
    if {$live_span > $full_span_ms} { set full_span_ms $live_span }
  }
  set full_chain_300s [expr {$full_span_ms >= 300000}]
  set step5_candidate [expr {$full_chain_300s && $::helper_locked_final($hardware_name) == 1 &&
    $::main_enabled_final($hardware_name) == 1 && $::main_freq_locked_final($hardware_name) == 1 &&
    $::main_phase_locked_final($hardware_name) == 1 && $::main_locked_final($hardware_name) == 1 &&
    $::pstat_locked_final($hardware_name) == 1 && $reset_result eq "PASS" &&
    $measurement_accounting eq "PASS" && $position_accounting eq "PASS" ? "CANDIDATE" : "NOT_COMPLETE"}]
  puts [format "STEP5_CLOSED_LOOP_TRAJECTORY_SUMMARY board=%s SAMPLES=%d COHERENT_MEASUREMENT_SNAPSHOTS=%d REJECTED_EPOCH_SNAPSHOTS=%d MEASUREMENT_ACCOUNTING_FAILS=%d POSITION_SNAPSHOTS=%d POSITION_INVARIANT_FAILS=%d TRANSACTION_INVARIANT_FAILS=%d DCO_INVARIANT_FAILS=%d FREQ_ERROR_MEAN=%s FREQ_ERROR_RMS=%s FREQ_ERROR_MIN=%s FREQ_ERROR_MAX=%s FREQ_ERROR_FIRST=%s FREQ_ERROR_LAST=%s EXTREME_THRESHOLD=1000000 EXTREME_COHERENT_SAMPLES=%d EXTREME_MAX_ABS=%s TARGET_FINAL=%s APPLIED_FINAL=%s EXPECTED_APPLIED_FROM_DELTA=%s NORMAL_REQ_DELTA=%s NORMAL_COMPLETED_DELTA=%s FINC_DELTA=%s FDEC_DELTA=%s DCO_STEP_DELTA=%s BOOTSTRAP_DELTA=%s FORCED_COMPLETED_DELTA=%s BOOTSTRAP_COMPLETED_FINAL=%s BOOTSTRAP_DONE_FINAL=%s HELPER_LOCK_COUNT_MAX=%s HELPER_LOCK_COUNT_FINAL=%s HELPER_LOCKED_SEEN=%d HELPER_LOCKED_FINAL=%s FIRST_HELPER_LOCK_SAMPLE=%s MAIN_ENABLED_FINAL=%s MAIN_FREQ_LOCKED_FINAL=%s MAIN_PHASE_LOCKED_FINAL=%s MAIN_LOCKED_FINAL=%s PSTAT_LOCKED_FINAL=%s FULL_CHAIN_MAX_SECONDS=%.3f FULL_CHAIN_300S=%s STEP5_CHAIN_RESULT=%s SPLL_DELOCK_COUNT_FIRST=%s SPLL_DELOCK_COUNT_MAX=%s SPLL_DELOCK_COUNT_FINAL=%s RESET_BOOT_GENERATION_DELTA=%s RESET_CPU_DELTA=%s RESET_WR_CORE_DELTA=%s RESET_SI_CONFIG_DELTA=%s MEASUREMENT_COHERENCE=%s POSITION_ACCOUNTING=%s RESET_STABLE=%s LAST_EPOCH=%s LAST_HELPER_UPDATE_COUNT=%s LAST_DMTD_REF_ACCEPT_COUNT=%s LAST_DMTD_FB_ACCEPT_COUNT=%s PRECLAMP_FIRST=%s PRECLAMP_FINAL=%s HELPER_ERROR_FINAL=%s HELPER_OUTPUT_FINAL=%s" \
    $hardware_name $::sample_count($hardware_name) $::coherent_count($hardware_name) $::rejected_count($hardware_name) $::measurement_failures($hardware_name) $::position_count($hardware_name) $::position_failures($hardware_name) $::transaction_failures($hardware_name) $::dco_failures($hardware_name) $freq_mean $freq_rms $::freq_min($hardware_name) $::freq_max($hardware_name) $::freq_first($hardware_name) $::freq_last($hardware_name) $::extreme_count($hardware_name) $::extreme_max_abs($hardware_name) $ptarget1 $papplied1 $expected_applied $req_delta $done_delta $finc_delta $fdec_delta $dco_delta $bootstrap_delta $forced_delta $pboot1 [expr {[word32 [probe_read 42]] < 0 ? "INVALID" : (([word64 [probe_read 42]] >> 33) & 1)}] $::helper_lock_max($hardware_name) $::helper_lock_final($hardware_name) $::helper_locked_seen($hardware_name) $::helper_locked_final($hardware_name) $::helper_first_locked_sample($hardware_name) $::main_enabled_final($hardware_name) $::main_freq_locked_final($hardware_name) $::main_phase_locked_final($hardware_name) $::main_locked_final($hardware_name) $::pstat_locked_final($hardware_name) [expr {$full_span_ms / 1000.0}] $full_chain_300s $step5_candidate $::spll_delock_first($hardware_name) $::spll_delock_max($hardware_name) $::spll_delock_final($hardware_name) $gen_delta $cpu_delta $wr_delta $si_delta $measurement_accounting $position_accounting $reset_result $::last_epoch($hardware_name) $::last_update_count($hardware_name) $::last_ref_accept_count($hardware_name) $::last_fb_accept_count($hardware_name) $::preclamp_first($hardware_name) $::preclamp_final($hardware_name) $::helper_error_final($hardware_name) $::helper_output_final($hardware_name)]
  flush stdout
}

puts [format "STEP5_CLOSED_LOOP_TRAJECTORY_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-6208-64-COHERENT-CLOSED-LOOP-TRAJECTORY-AUDIT read_only_observer=1 normal_hpll_tracker=1 bootstrap_steps=6208 code_per_physical_step=64 kp=-150 ki=-2 threshold=200 lock_samples=10000 measurement_window=0x00100B00..0x00100B24 position_probes=43,44 cadence_ms=%d" $samples $gap_ms $board_filter $gap_ms]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== STEP5_CLOSED_LOOP_TRAJECTORY_BOARD %s ===" $hardware_name]
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
    puts [format "STEP5_CLOSED_LOOP_TRAJECTORY_ERROR board=%s message=%s error_info=%s" $hardware_name $error_message [string map [list "\n" " | "] $::errorInfo]]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_CLOSED_LOOP_TRAJECTORY_DONE"
