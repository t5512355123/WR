# White Rabbit Step5 SoftPLL re-init causality audit.
#
# This is a read-only observer.  It does not send a shell command and does
# not write a functional control register.  The private WDIAGS words at
# 0x1e0..0x1fc are used as a temporary attribution overlay:
#   0x1e0..0x1ec : last reason/mode/flags/tics
#   0x1f0..0x1fc : sixteen 8-bit reason counters, packed four per word
#
# Usage:
#   quartus_stp -t read_step5_spll_reinit_causality_audit.tcl ?samples? ?gap_ms? ?board_filter?

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
array set ::accounting_reject_count {}
array set ::measurement_failures {}
array set ::init_event_count {}
array set ::aligned_event_count {}
array set ::exact_reason_event_count {}
array set ::init_first {}
array set ::init_final {}
array set ::helper_epoch_first {}
array set ::helper_epoch_final {}
array set ::helper_update_first {}
array set ::helper_update_final {}
array set ::reset_first {}
array set ::reset_final {}
array set ::last_reason_final {}
array set ::last_reason_name_final {}
array set ::last_reason_delta_final {}
array set ::cause_final {}
array set ::cause_index_final {}

array set ::reason_names {
  0 UNKNOWN
  1 WRPC_LOCKING_ENABLE
  2 WRPC_LOCKING_RESET
  3 PTP_SET_MODE_GM
  4 PTP_SET_MODE_MASTER
  5 PTP_LINK_DOWN
  6 SHELL_CMD_PLL
  7 FREQMON
  8 RTS_SET_MODE
  9 RTS_LOCK_CHANNEL
  10 RXTS_CALIBRATION
  11 ERTM14_PHY_CALIBRATION
  12 ERTM14_BOARD_INIT
  13 RT_IPC_MODE
  14 RT_IPC_DISABLE
  15 RT_IPC_SLAVE
}

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

proc counter_delta32 {first last} {
  if {$first eq "INVALID" || $last eq "INVALID"} { return INVALID }
  if {![string is integer -strict $first] || ![string is integer -strict $last]} {
    return INVALID
  }
  if {$last >= $first} { return [expr {$last - $first}] }
  # These counters cannot wrap during a 1800-sample audit.  A decrease is a
  # reset/reinitialization signal, not fabricated wrap-around activity.
  return DECREASED
}

proc reason_name {reason} {
  if {$reason eq "INVALID"} { return INVALID }
  if {[info exists ::reason_names($reason)]} { return $::reason_names($reason) }
  return UNKNOWN
}

proc frame_valid {ctrl_begin ctrl_end} {
  set a [word32 $ctrl_begin]
  set b [word32 $ctrl_end]
  if {$a < 0 || $b < 0} { return 0 }
  return [expr {(($a & 1) != 0) && (($b & 1) != 0) && $a == $b}]
}

proc read_coherent_measurement {hardware_name} {
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
      if {$tag ne "INVALID" && $expected ne "INVALID" && $freq ne "INVALID" &&
          $freq == ($tag - $expected)} {
        return [list 1 $epoch_after $tag $expected $freq $preclamp $helper_error \
          $update_count $helper_output $ref_accept $fb_accept]
      }
      incr ::accounting_reject_count($hardware_name)
    }
  }
  return [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
}

proc read_reason_snapshot {hardware_name} {
  # The task writes the timestamp before the packed counters.  Bracket the
  # snapshot with that timestamp so a refresh in the middle of the MMIO
  # sequence is retried instead of being treated as a real source change.
  for {set attempt 0} {$attempt < 4} {incr attempt} {
    set stamp_before [word32 [wb_read $hardware_name 0x00100BEC]]
    set last_reason [word32 [wb_read $hardware_name 0x00100BE0]]
    set last_mode [word32 [wb_read $hardware_name 0x00100BE4]]
    set last_flags [word32 [wb_read $hardware_name 0x00100BE8]]
    set last_tics [word32 [wb_read $hardware_name 0x00100BEC]]
    set counters {}
    for {set i 0} {$i < 4} {incr i} {
      set packed [word32 [wb_read $hardware_name [expr {0x00100BF0 + $i * 4}]]]
      if {$packed < 0} {
        lappend counters INVALID INVALID INVALID INVALID
      } else {
        for {set j 0} {$j < 4} {incr j} {
          lappend counters [expr {($packed >> ($j * 8)) & 0xff}]
        }
      }
    }
    set stamp_after [word32 [wb_read $hardware_name 0x00100BEC]]
    if {$stamp_before == $stamp_after} {
      return [list $last_reason $last_mode $last_flags $last_tics $counters]
    }
    after 2
  }
  return [list INVALID INVALID INVALID INVALID [lrepeat 16 INVALID]]
}

proc initialize_board {hardware_name} {
  set ::sample_count($hardware_name) 0
  set ::coherent_count($hardware_name) 0
  set ::accounting_reject_count($hardware_name) 0
  set ::measurement_failures($hardware_name) 0
  set ::init_event_count($hardware_name) 0
  set ::aligned_event_count($hardware_name) 0
  set ::exact_reason_event_count($hardware_name) 0
  set ::init_first($hardware_name) INVALID
  set ::init_final($hardware_name) INVALID
  set ::helper_epoch_first($hardware_name) INVALID
  set ::helper_epoch_final($hardware_name) INVALID
  set ::helper_update_first($hardware_name) INVALID
  set ::helper_update_final($hardware_name) INVALID
  set ::reset_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::last_reason_final($hardware_name) INVALID
  set ::last_reason_name_final($hardware_name) INVALID
  set ::last_reason_delta_final($hardware_name) NONE
  set ::cause_final($hardware_name) NONE
  set ::cause_index_final($hardware_name) NONE
}

proc reason_deltas {previous current} {
  set changed {}
  set invalid 0
  for {set i 0} {$i < 16} {incr i} {
    set before [lindex $previous $i]
    set after [lindex $current $i]
    if {$before eq "INVALID" || $after eq "INVALID"} {
      set invalid 1
    } elseif {$after > $before} {
      lappend changed [list $i [expr {$after - $before}]]
    } elseif {$after < $before} {
      set invalid 1
    }
  }
  return [list $changed $invalid]
}

proc emit_sample {hardware_name sample elapsed_ms} {
  set measurement [read_coherent_measurement $hardware_name]
  foreach {measurement_ok epoch tag expected freq preclamp helper_error update_count helper_output ref_accept fb_accept} $measurement break
  set reason_snapshot [read_reason_snapshot $hardware_name]
  foreach {last_reason last_mode last_flags last_reason_tics reason_counters} $reason_snapshot break

  set init_count [word32 [wb_read $hardware_name 0x00100B44]]
  set clear_dacs [word32 [wb_read $hardware_name 0x00100B48]]
  set last_init_tics [word32 [wb_read $hardware_name 0x00100B4C]]
  set state [wb_read $hardware_name 0x00100AA0]
  set state_transitions [word32 [wb_read $hardware_name 0x00100AE4]]
  set last_state [word32 [wb_read $hardware_name 0x00100AE8]]
  set helper_state [wb_read $hardware_name 0x00100ABC]
  set helper_limits [wb_read $hardware_name 0x00100AC0]
  set main_state [wb_read $hardware_name 0x00100AC4]
  set ptp_state [word32 [wb_read $hardware_name 0x00100A10]]
  set ptp_meta [word32 [wb_read $hardware_name 0x00100A5C]]
  set wr_state [word32 [wb_read $hardware_name 0x00100A4C]]
  set wr_rx_signal [word32 [wb_read $hardware_name 0x00100A64]]
  set wr_tx_signal [word32 [wb_read $hardware_name 0x00100A68]]
  set reset_entry [probe_read 26]
  set reset_sticky [probe_read 27]
  set boot_generation [probe_high32 $reset_entry]
  set cpu_reset [probe_field32 $reset_sticky 16 8]
  set wr_reset [probe_field32 $reset_sticky 24 8]
  set si_drop [probe_field32 $reset_sticky 40 8]
  set helper_locked [field32 $helper_state 0 1]
  set helper_lock_count [field32 $helper_state 16 16]
  set helper_lock_samples [field32 $helper_limits 16 16]
  set main_enabled [field32 $main_state 0 1]
  set main_freq_locked [field32 $main_state 1 1]
  set main_phase_locked [field32 $main_state 2 1]
  set main_locked [field32 $main_state 3 1]
  set pstat_locked [field32 [wb_read $hardware_name 0x00100A0C] 0 1]

  if {$::sample_count($hardware_name) == 0} {
    set ::init_first($hardware_name) $init_count
    set ::helper_epoch_first($hardware_name) $epoch
    set ::helper_update_first($hardware_name) $update_count
    set ::reset_first($hardware_name) [list $boot_generation $cpu_reset $wr_reset $si_drop]
    set ::previous_init($hardware_name) $init_count
    set ::previous_epoch($hardware_name) $epoch
    set ::previous_update($hardware_name) $update_count
    set ::previous_reasons($hardware_name) $reason_counters
    set ::pending_init_sample($hardware_name) NONE
    set ::pending_reason($hardware_name) INVALID
  } else {
    set init_delta [counter_delta32 $::previous_init($hardware_name) $init_count]
    set epoch_reset [expr {$epoch ne "INVALID" && $::previous_epoch($hardware_name) ne "INVALID" && $epoch < $::previous_epoch($hardware_name)}]
    set update_reset [expr {$update_count ne "INVALID" && $::previous_update($hardware_name) ne "INVALID" && $update_count < $::previous_update($hardware_name)}]
    set helper_reset [expr {$epoch_reset || $update_reset}]
    set exact_changed 0
    set event_reason INVALID
    set event_reason_delta NONE
    if {$init_delta ne "INVALID" && $init_delta ne "DECREASED" && $init_delta > 0} {
      incr ::init_event_count($hardware_name)
      set reason_result [reason_deltas $::previous_reasons($hardware_name) $reason_counters]
      set changed [lindex $reason_result 0]
      set reason_invalid [lindex $reason_result 1]
      if {!$reason_invalid && [llength $changed] == 1} {
        set event_reason [lindex [lindex $changed 0] 0]
        set event_reason_delta [lindex [lindex $changed 0] 1]
        if {$event_reason == $last_reason} {
          set exact_changed 1
          incr ::exact_reason_event_count($hardware_name)
          set ::cause_final($hardware_name) [reason_name $event_reason]
          set ::cause_index_final($hardware_name) $event_reason
          set ::last_reason_delta_final($hardware_name) $event_reason_delta
        }
      }
      set ::pending_init_sample($hardware_name) $sample
      set ::pending_reason($hardware_name) $event_reason
    }
    if {$helper_reset && $::pending_init_sample($hardware_name) ne "NONE" &&
        $sample - $::pending_init_sample($hardware_name) <= 2} {
      incr ::aligned_event_count($hardware_name)
      set ::pending_init_sample($hardware_name) NONE
    }
    set ::previous_init($hardware_name) $init_count
    set ::previous_epoch($hardware_name) $epoch
    set ::previous_update($hardware_name) $update_count
    set ::previous_reasons($hardware_name) $reason_counters
  }

  set ::sample_count($hardware_name) [expr {$::sample_count($hardware_name) + 1}]
  if {$measurement_ok} {
    incr ::coherent_count($hardware_name)
  } else {
    incr ::measurement_failures($hardware_name)
  }
  set ::init_final($hardware_name) $init_count
  set ::helper_epoch_final($hardware_name) $epoch
  set ::helper_update_final($hardware_name) $update_count
  set ::reset_final($hardware_name) [list $boot_generation $cpu_reset $wr_reset $si_drop]
  set ::last_reason_final($hardware_name) $last_reason
  set ::last_reason_name_final($hardware_name) [reason_name $last_reason]

  puts [format "STEP5_SPLL_REINIT_SAMPLE board=%s sample=%d elapsed_ms=%d COHERENT=%d EPOCH=%s TAG_DELTA=%s EXPECTED_DELTA=%s FREQ_ERROR=%s HELPER_UPDATE_COUNT=%s DMTD_REF_ACCEPT_COUNT=%s DMTD_FB_ACCEPT_COUNT=%s SPLL_INIT_COUNT=%s CLEAR_DACS_COUNT=%s LAST_INIT_TICS=%s LAST_REASON=%s LAST_REASON_NAME=%s LAST_REASON_MODE=%s LAST_REASON_FLAGS=%s LAST_REASON_TICS=%s REASON_COUNTS=%s SPLL_STATE=%s STATE_TRANSITIONS=%s LAST_STATE=%s HELPER_LOCKED=%s HELPER_LOCK_COUNT=%s HELPER_LOCK_SAMPLES=%s MAIN_ENABLED=%s MAIN_FREQ_LOCKED=%s MAIN_PHASE_LOCKED=%s MAIN_LOCKED=%s PSTAT_LOCKED=%s PTP_STATE=%s PTP_META=%s WR_STATE=%s WR_RX_SIGNAL=%s WR_TX_SIGNAL=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
    $hardware_name $sample $elapsed_ms $measurement_ok $epoch $tag $expected $freq $update_count $ref_accept $fb_accept $init_count $clear_dacs $last_init_tics $last_reason [reason_name $last_reason] $last_mode $last_flags $last_reason_tics [join $reason_counters ,] $state $state_transitions $last_state $helper_locked $helper_lock_count $helper_lock_samples $main_enabled $main_freq_locked $main_phase_locked $main_locked $pstat_locked $ptp_state $ptp_meta $wr_state $wr_rx_signal $wr_tx_signal $boot_generation $cpu_reset $wr_reset $si_drop]
  flush stdout
}

proc emit_summary {hardware_name} {
  foreach {boot0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {boot1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  set boot_delta [expr {$boot0 ne "INVALID" && $boot1 ne "INVALID" ? ($boot1 - $boot0) : "INVALID"}]
  set cpu_delta [expr {$cpu0 ne "INVALID" && $cpu1 ne "INVALID" ? ($cpu1 - $cpu0) : "INVALID"}]
  set wr_delta [expr {$wr0 ne "INVALID" && $wr1 ne "INVALID" ? ($wr1 - $wr0) : "INVALID"}]
  set si_delta [expr {$si0 ne "INVALID" && $si1 ne "INVALID" ? ($si1 - $si0) : "INVALID"}]
  set reset_stable [expr {$boot_delta eq "0" && $cpu_delta eq "0" && $wr_delta eq "0" && $si_delta eq "0" ? "PASS" : "FAIL"}]
  set measurement_result [expr {$::coherent_count($hardware_name) > 0 && $::measurement_failures($hardware_name) == 0 ? "PASS" : "FAIL"}]
  set causal_result [expr {$::init_event_count($hardware_name) > 0 &&
      $::aligned_event_count($hardware_name) > 0 &&
      $::exact_reason_event_count($hardware_name) > 0 ? "CONFIRMED" : "NOT_CONFIRMED"}]
  puts [format "STEP5_SPLL_REINIT_CAUSALITY_SUMMARY board=%s SAMPLES=%d COHERENT_MEASUREMENT_SNAPSHOTS=%d MEASUREMENT_ACCOUNTING_FAILS=%d ACCOUNTING_REJECTED=%d SPLL_INIT_COUNT_FIRST=%s SPLL_INIT_COUNT_FINAL=%s SPLL_INIT_COUNT_DELTA=%s REINIT_EVENTS=%d HELPER_EPOCH_FIRST=%s HELPER_EPOCH_FINAL=%s HELPER_UPDATE_FIRST=%s HELPER_UPDATE_FINAL=%s HELPER_EPOCH_OR_UPDATE_RESET_ALIGNED=%d EXACTLY_ONE_REASON_CHANGED=%d LAST_REASON=%s LAST_REASON_NAME=%s REASON_INDEX=%s REASON_DELTA=%s SPLL_REINIT_DURING_LOCK_ATTEMPT=%s SPLL_REINIT_CAUSE=%s RESET_BOOT_GENERATION_DELTA=%s RESET_CPU_DELTA=%s RESET_WR_CORE_DELTA=%s RESET_SI_CONFIG_DELTA=%s RESET_STABLE=%s MEASUREMENT_COHERENCE=%s NOTE=0x1e0..0x1fc_is_read_only_reinit_attribution_overlay" \
    $hardware_name $::sample_count($hardware_name) $::coherent_count($hardware_name) $::measurement_failures($hardware_name) $::accounting_reject_count($hardware_name) $::init_first($hardware_name) $::init_final($hardware_name) [counter_delta32 $::init_first($hardware_name) $::init_final($hardware_name)] $::init_event_count($hardware_name) $::helper_epoch_first($hardware_name) $::helper_epoch_final($hardware_name) $::helper_update_first($hardware_name) $::helper_update_final($hardware_name) $::aligned_event_count($hardware_name) $::exact_reason_event_count($hardware_name) $::last_reason_final($hardware_name) $::last_reason_name_final($hardware_name) $::cause_index_final($hardware_name) $::last_reason_delta_final($hardware_name) $causal_result $::cause_final($hardware_name) $boot_delta $cpu_delta $wr_delta $si_delta $reset_stable $measurement_result]
  flush stdout
}

puts [format "STEP5_SPLL_REINIT_CAUSALITY_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-6208-64-SPLL-REINIT-CAUSALITY-AUDIT read_only_observer=1 shell_commands=0 bootstrap_steps=6208 normal_hpll_tracker=1 code_per_physical_step=64 kp=-150 ki=-2 threshold=200 lock_samples=10000 reason_overlay=0x00100BE0..0x00100BFC packed_reason_counter_width=8" $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  initialize_board $hardware_name
  puts [format "=== STEP5_SPLL_REINIT_CAUSALITY_BOARD %s ===" $hardware_name]
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
    puts [format "STEP5_SPLL_REINIT_CAUSALITY_ERROR board=%s message=%s error_info=%s" $hardware_name $error_message [string map [list "\n" " | "] $::errorInfo]]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_SPLL_REINIT_CAUSALITY_DONE"
