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
# Usage:
#   quartus_stp -t read_step5_hpll_absolute_target_tracker.tcl ?samples? ?gap_ms?

package require ::quartus::insystem_source_probe

set samples 120
set gap_ms 1000
set poll_attempts 25
set board_filter ""
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
  set dco_raw [probe_read 8]
  set pstat [wb_read $hardware_name 0x00100A0C]
  set helper_state [wb_read $hardware_name 0x00100ABC]
  set helper_error [wb_read $hardware_name 0x00100AD8]
  set helper_output [wb_read $hardware_name 0x00100ADC]
  set tag_count [wb_read $hardware_name 0x00100AD4]

  set tracker_word [word64 $tracker_raw]
  set burst_word [word64 $burst_raw]
  set dco_word [word64 $dco_raw]
  set target [field_bits $tracker_word 0 0xffff]
  set applied [field_bits $tracker_word 16 0xffff]
  set normal_req [field_bits $tracker_word 32 0xffff]
  set normal_done [field_bits $tracker_word 48 0xffff]
  set trigger [field_bits $burst_word 0 0xff]
  set forced_pending [field_bits $burst_word 8 0xff]
  set forced_done [field_bits $burst_word 16 0xff]
  set step [field_bits $burst_word 48 0xffff]
  set rt_state [field_bits $dco_word 0 0x7]
  set gap INVALID
  set quantized_settled UNKNOWN
  if {$target ne "INVALID" && $applied ne "INVALID"} {
    set gap [expr {$target - $applied}]
    if {[expr {abs($gap) < 34}]} {
      set quantized_settled PASS
    } else {
      set quantized_settled NOT_SETTLED
    }
  }

  if {$sample == 1} {
    set ::tracker_first($hardware_name) [list $target $applied $normal_req $normal_done]
    set ::burst_first($hardware_name) [list $trigger $forced_pending $forced_done $step]
  }
  set ::tracker_last($hardware_name) [list $target $applied $normal_req $normal_done]
  set ::burst_last($hardware_name) [list $trigger $forced_pending $forced_done $step]

  puts [format "STEP5_TRACKER_SAMPLE board=%s sample=%03d elapsed_ms=%d TRACKER_RAW=%s TARGET_CODE=%s APPLIED_CODE=%s TARGET_MINUS_APPLIED=%s QUANTIZED_SETTLED=%s NORMAL_HPLL_REQUEST_COUNT=%s NORMAL_HPLL_COMPLETED_COUNT=%s BURST_RAW=%s BURST_TRIGGER_COUNT=%s FORCED_HPLL_PENDING_COUNT=%s FORCED_HPLL_COMPLETED_COUNT=%s DCO_STEP_COUNT=%s RT_STATE=%s PSTAT=%s HELPER_STATE=%s HELPER_ERROR=%s HELPER_OUTPUT=%s TAG_COUNT=%s" \
    $hardware_name $sample $elapsed_ms [display64 $tracker_raw] $target $applied $gap $quantized_settled $normal_req $normal_done \
    [display64 $burst_raw] $trigger $forced_pending $forced_done $step $rt_state $pstat $helper_state $helper_error $helper_output $tag_count]
  flush stdout
}

proc emit_delta {hardware_name} {
  if {![info exists ::tracker_first($hardware_name)] ||
      ![info exists ::tracker_last($hardware_name)]} {
    puts [format "STEP5_TRACKER_DELTA board=%s status=NO_VALID_SAMPLE" $hardware_name]
    return
  }
  foreach {t0 a0 r0 c0} $::tracker_first($hardware_name) break
  foreach {t1 a1 r1 c1} $::tracker_last($hardware_name) break
  foreach {b0 p0 f0 s0} $::burst_first($hardware_name) break
  foreach {b1 p1 f1 s1} $::burst_last($hardware_name) break
  set dt [expr {$t1 - $t0}]
  set da [expr {$a1 - $a0}]
  set dr [expr {$r1 - $r0}]
  set dc [expr {$c1 - $c0}]
  set db [expr {$b1 - $b0}]
  set dp [expr {$p1 - $p0}]
  set df [expr {$f1 - $f0}]
  set ds [expr {$s1 - $s0}]
  set initial_gap [expr {$t0 - $a0}]
  set final_gap [expr {$t1 - $a1}]
  set progress "INCONCLUSIVE"
  if {abs($final_gap) < abs($initial_gap)} { set progress "TOWARD_TARGET" }
  if {$dc == 0 && abs($final_gap) < 34 &&
      $db == 0 && $dp == 0 && $df == 0} {
    set transaction_accounting "PASS_SETTLED"
  } elseif {$dr == $dc && $dc > 0 && $db == 0 && $dp == 0 && $df == 0 &&
            (abs($da) == (34 * $dc))} {
    set transaction_accounting "PASS_QUANTIZED_NET"
  } else {
    set transaction_accounting "CHECK_FINE_GRAIN"
  }
  set quantized_settled "NOT_SETTLED"
  if {abs($final_gap) < 34} { set quantized_settled "PASS" }
  puts [format "STEP5_TRACKER_DELTA board=%s TARGET_DELTA=%d APPLIED_DELTA=%d NORMAL_REQUEST_DELTA=%d NORMAL_COMPLETED_DELTA=%d BURST_TRIGGER_DELTA=%d FORCED_PENDING_DELTA=%d FORCED_COMPLETED_DELTA=%d DCO_STEP_DELTA=%d INITIAL_TARGET_MINUS_APPLIED=%d FINAL_TARGET_MINUS_APPLIED=%d QUANTIZED_SETTLED=%s TRACKER_PROGRESS=%s NORMAL_TRANSACTION_ACCOUNTING=%s" \
    $hardware_name $dt $da $dr $dc $db $dp $df $ds $initial_gap $final_gap $quantized_settled $progress $transaction_accounting]
  flush stdout
}

puts [format "STEP5_HPLL_ABSOLUTE_TARGET_TRACKER_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-TRACKER-34-QUANTIZED-RESIDUAL-CLOSED-LOOP-20260830 read_only=1 probe=39" $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== STEP5_HPLL_ABSOLUTE_TARGET_TRACKER_BOARD %s ===" $hardware_name]
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
    puts [format "STEP5_HPLL_ABSOLUTE_TARGET_TRACKER_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_HPLL_ABSOLUTE_TARGET_TRACKER_DONE"
