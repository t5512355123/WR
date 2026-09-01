# Read-only JTAG/Wishbone completion visibility audit.
#
# This is the same workload as read_jtag_wb_readpath_stability.tcl, but a
# completed mailbox response is accepted only after the complete 64-bit probe
# word is stable across three samples.  It deliberately keeps one source
# probe session open and performs no firmware, RTL, PI, or snapshot writes.
#
# Usage:
#   quartus_stp -t read_jtag_wb_completion_stable_double_sample.tcl \
#     ?iterations? ?board_filter?

package require ::quartus::insystem_source_probe

set iterations 500
set board_filter {DE5 [1-11.2]}
if {[llength $argv] >= 1} { set iterations [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set board_filter [lindex $argv 1] }
if {$iterations <= 0} { error "iterations must be > 0" }

set STATIC_SIGNATURE_ADDR 0x00100124
set STATIC_SIGNATURE_EXPECTED 0x02000200
set BOARD_ID_ADDR 0x00100128
set BOARD_ID_EXPECTED 0x22334402
set DMTD_REF_ADDR 0x00100298
set DMTD_FB_ADDR 0x0010029C

set ::wb_toggle 0
set ::total_wb_requests 0
set ::total_probe_reads 0
set ::static_signature_mismatch 0
set ::board_id_mismatch 0
set ::stale_a5a5_count 0
set ::timeout_count 0
set ::invalid_count 0
set ::address_cross_contamination_count 0
set ::dmtd_ref_decrease_count 0
set ::dmtd_fb_decrease_count 0
set ::dmtd_ref_triple_valid 0
set ::dmtd_fb_triple_valid 0
set ::static_sequence_valid 0
set ::address_sequence_valid 0
set ::initial_completion_unstable_count 0
set ::initial_data_wrong_but_stabilized_correct_count 0
set ::stable_response_wrong_count 0
set ::probe_stabilization_timeout_count 0
set ::probe_2way_match_count 0
set ::probe_3way_match_count 0
set ::stable_transaction_count 0
set ::unstable_transaction_count 0
set ::first_error_recorded 0
set ::first_error_text ""

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]+$} $value]
}

proc normalize64 {value} {
  if {![is_hex $value]} { return $value }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  return [string repeat 0 [expr {16 - [string length $text]}]]$text
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  set text [normalize64 $value]
  set word 0
  scan [string range $text 8 15] %x word
  return [expr {$word & 0xffffffff}]
}

proc high32 {value} {
  if {![is_hex $value]} { return -1 }
  set text [normalize64 $value]
  set word 0
  scan [string range $text 0 7] %x word
  return [expr {$word & 0xffffffff}]
}

proc high_bit {value bit} {
  set word [high32 $value]
  if {$word < 0 || $bit < 0 || $bit > 31} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc stale_jtag_word {value} {
  set word [word32 $value]
  if {$word < 0} { return 0 }
  return [expr {(($word >> 16) & 0xffff) == 0xA5A5}]
}

proc value_usable {value} {
  if {$value eq "TIMEOUT" || $value eq "INVALID" || $value eq "UNSTABLE"} { return 0 }
  set word [word32 $value]
  return [expr {$word >= 0 && ![stale_jtag_word $value]}]
}

proc probe_equal {left right} {
  if {![is_hex $left] || ![is_hex $right]} { return 0 }
  return [expr {[normalize64 $left] eq [normalize64 $right]}]
}

proc remember_first_error {text} {
  if {!$::first_error_recorded} {
    set ::first_error_recorded 1
    set ::first_error_text $text
  }
}

proc safe_probe_read {} {
  incr ::total_probe_reads
  if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
    return "TIMEOUT"
  }
  if {![is_hex $value]} { return "INVALID" }
  return [normalize64 $value]
}

proc note_probe_value {label value iteration} {
  if {$value eq "TIMEOUT"} {
    return
  }
  if {$value eq "INVALID" || ![is_hex $value]} {
    incr ::invalid_count
    remember_first_error [format "iteration=%d label=%s value=%s classification=INVALID" $iteration $label $value]
  } elseif {[stale_jtag_word $value]} {
    incr ::stale_a5a5_count
    remember_first_error [format "iteration=%d label=%s value=%s classification=STALE_A5A5" $iteration $label $value]
  }
}

proc completion_probe_valid {value expected_toggle} {
  if {![is_hex $value] || [stale_jtag_word $value]} { return 0 }
  set done_toggle [high_bit $value 3]
  set active [high_bit $value 4]
  return [expr {$done_toggle == $expected_toggle && $active == 0}]
}

proc mailbox_read_stable {label addr expected iteration} {
  set ::wb_toggle [expr {($::wb_toggle ^ 1) & 1}]
  set expected_toggle $::wb_toggle
  set cmd [expr {$expected_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  incr ::total_wb_requests
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    incr ::timeout_count
    return [list TIMEOUT 0 "" "" "" ""]
  }

  after 5
  set first_completion ""
  for {set n 0} {$n < 100} {incr n} {
    set probe [safe_probe_read]
    note_probe_value $label $probe $iteration
    if {[completion_probe_valid $probe $expected_toggle]} {
      set first_completion $probe
      break
    }
    after 1
  }
  if {$first_completion eq ""} {
    incr ::timeout_count
    remember_first_error [format "iteration=%d label=%s address=0x%08X classification=COMPLETION_TIMEOUT" \
      $iteration $label $addr]
    return [list TIMEOUT 0 "" "" "" ""]
  }

  # Do not trust the first done/idle observation.  Require P1=P2=P3 on the
  # full 64-bit probe word, with a 1 ms gap between P1/P2 and P2/P3.
  set stable 0
  set stable1 ""
  set stable2 ""
  set stable3 ""
  set last1 ""
  set last2 ""
  set last3 ""
  for {set attempt 1} {$attempt <= 10} {incr attempt} {
    set p1 [safe_probe_read]
    note_probe_value $label $p1 $iteration
    after 1
    set p2 [safe_probe_read]
    note_probe_value $label $p2 $iteration
    after 1
    set p3 [safe_probe_read]
    note_probe_value $label $p3 $iteration
    set last1 $p1
    set last2 $p2
    set last3 $p3
    if {[is_hex $p1] && [is_hex $p2] && [is_hex $p3] &&
        [completion_probe_valid $p1 $expected_toggle] &&
        [completion_probe_valid $p2 $expected_toggle] &&
        [completion_probe_valid $p3 $expected_toggle] &&
        [probe_equal $p1 $p2] && [probe_equal $p2 $p3]} {
      set stable 1
      set stable1 $p1
      set stable2 $p2
      set stable3 $p3
      break
    }
    after 1
  }

  set initial_unstable [expr {![probe_equal $first_completion $last1] ||
                              ![probe_equal $last1 $last2] ||
                              ![probe_equal $last2 $last3]}]
  if {$initial_unstable} {
    incr ::initial_completion_unstable_count
  }

  if {$stable} {
    incr ::stable_transaction_count
    incr ::probe_3way_match_count
    if {[probe_equal $stable1 $stable2]} { incr ::probe_2way_match_count }
    if {$expected >= 0} {
      set first_word [word32 $first_completion]
      set final_word [word32 $stable3]
      if {$first_word != $expected && $final_word == $expected} {
        incr ::initial_data_wrong_but_stabilized_correct_count
      }
      if {$final_word != $expected} {
        incr ::stable_response_wrong_count
      }
    }
    if {$initial_unstable} {
      remember_first_error [format \
        "iteration=%d requested=%s address=0x%08X first_completion_probe=%s stable_probe_1=%s stable_probe_2=%s stable_probe_3=%s first_result=%08X final_result=%08X classification=INITIAL_UNSTABLE_THEN_STABLE" \
        $iteration $label $addr [normalize64 $first_completion] [normalize64 $stable1] \
        [normalize64 $stable2] [normalize64 $stable3] [word32 $first_completion] [word32 $stable3]]
    }
    return [list $stable3 1 $first_completion $stable1 $stable2 $stable3]
  }

  incr ::unstable_transaction_count
  incr ::probe_stabilization_timeout_count
  remember_first_error [format \
    "iteration=%d requested=%s address=0x%08X first_completion_probe=%s stable_probe_1=%s stable_probe_2=%s stable_probe_3=%s classification=PROBE_STABILIZATION_TIMEOUT" \
    $iteration $label $addr [normalize64 $first_completion] [normalize64 $last1] \
    [normalize64 $last2] [normalize64 $last3]]
  return [list UNSTABLE 0 $first_completion $last1 $last2 $last3]
}

proc audited_read {label addr expected iteration prev_label_name prev_value_name prev_stable_name} {
  upvar 1 $prev_label_name previous_label
  upvar 1 $prev_value_name previous_value
  upvar 1 $prev_stable_name previous_stable
  set tuple [mailbox_read_stable $label $addr $expected $iteration]
  set value [lindex $tuple 0]
  set current_stable [lindex $tuple 1]
  if {$current_stable && $previous_stable && [value_usable $value] &&
      [value_usable $previous_value] && $label ne $previous_label &&
      [word32 $value] == [word32 $previous_value]} {
    set current_static [expr {$label eq "STATIC_A" || $label eq "STATIC_B"}]
    set previous_static [expr {$previous_label eq "STATIC_A" || $previous_label eq "STATIC_B"}]
    if {$current_static || $previous_static} {
      incr ::address_cross_contamination_count
      remember_first_error [format \
        "iteration=%d requested=%s previous=%s observed=%s classification=PREVIOUS_RESPONSE_REPLAY_AFTER_STABILIZATION" \
        $iteration $label $previous_label $value]
    }
  }
  set previous_label $label
  set previous_value $value
  set previous_stable $current_stable
  set ::last_read_stable $current_stable
  set ::last_read_first_probe [lindex $tuple 2]
  set ::last_read_stable_probe1 [lindex $tuple 3]
  set ::last_read_stable_probe2 [lindex $tuple 4]
  set ::last_read_stable_probe3 [lindex $tuple 5]
  return $value
}

proc checked_static_read {label addr expected iteration prev_label_name prev_value_name prev_stable_name} {
  upvar 1 $prev_label_name previous_label
  upvar 1 $prev_value_name previous_value
  upvar 1 $prev_stable_name previous_stable
  set local_previous_label $previous_label
  set local_previous_value $previous_value
  set local_previous_stable $previous_stable
  set value [audited_read $label $addr $expected $iteration \
    local_previous_label local_previous_value local_previous_stable]
  set previous_label $local_previous_label
  set previous_value $local_previous_value
  set previous_stable $local_previous_stable
  if {!$::last_read_stable || ![value_usable $value]} { return 0 }
  if {[word32 $value] != $expected} {
    if {$label eq "STATIC_A"} { incr ::static_signature_mismatch }
    if {$label eq "STATIC_B"} { incr ::board_id_mismatch }
    remember_first_error [format "iteration=%d requested=%s expected=%08X observed=%s classification=STABLE_RESPONSE_WRONG" \
      $iteration $label $expected $value]
    return 0
  }
  return 1
}

proc stable_dynamic_read {label addr iteration} {
  set tuple [mailbox_read_stable $label $addr -1 $iteration]
  if {[lindex $tuple 1]} { return [lindex $tuple 0] }
  return "UNSTABLE"
}

proc check_monotonic_triple {label values iteration} {
  if {[llength $values] != 3} { return 0 }
  foreach value $values { if {![value_usable $value]} { return 0 } }
  set first [word32 [lindex $values 0]]
  set second [word32 [lindex $values 1]]
  set third [word32 [lindex $values 2]]
  if {$second < $first || $third < $second} {
    if {$label eq "DMTD_REF"} { incr ::dmtd_ref_decrease_count }
    if {$label eq "DMTD_FB"} { incr ::dmtd_fb_decrease_count }
    remember_first_error [format "iteration=%d requested=%s values=%s classification=COUNTER_DECREASE_AFTER_STABILIZATION" \
      $iteration $label [join $values ,]]
    return 0
  }
  return 1
}

proc run_iteration {iteration} {
  # A. Immutable/static registers: A1 B1 A2 B2 A3 B3.
  set previous_label ""
  set previous_value ""
  set previous_stable 0
  set static_ok 1
  foreach item {
    {STATIC_A 0x00100124 0x02000200}
    {STATIC_B 0x00100128 0x22334402}
    {STATIC_A 0x00100124 0x02000200}
    {STATIC_B 0x00100128 0x22334402}
    {STATIC_A 0x00100124 0x02000200}
    {STATIC_B 0x00100128 0x22334402}
  } {
    if {![checked_static_read [lindex $item 0] [lindex $item 1] [lindex $item 2] \
        $iteration previous_label previous_value previous_stable]} { set static_ok 0 }
  }
  if {$static_ok} { incr ::static_sequence_valid }

  # B. Same-address DMTD triples.
  set ref_values {}
  for {set n 0} {$n < 3} {incr n} {
    lappend ref_values [stable_dynamic_read DMTD_REF $::DMTD_REF_ADDR $iteration]
  }
  if {[check_monotonic_triple DMTD_REF $ref_values $iteration]} { incr ::dmtd_ref_triple_valid }

  set fb_values {}
  for {set n 0} {$n < 3} {incr n} {
    lappend fb_values [stable_dynamic_read DMTD_FB $::DMTD_FB_ADDR $iteration]
  }
  if {[check_monotonic_triple DMTD_FB $fb_values $iteration]} { incr ::dmtd_fb_triple_valid }

  # C. Address switching: STATIC_A -> REF -> STATIC_B -> FB -> ...
  set previous_label ""
  set previous_value ""
  set previous_stable 0
  set address_ok 1
  if {![checked_static_read STATIC_A $::STATIC_SIGNATURE_ADDR $::STATIC_SIGNATURE_EXPECTED \
      $iteration previous_label previous_value previous_stable]} { set address_ok 0 }
  if {![value_usable [stable_dynamic_read DMTD_REF $::DMTD_REF_ADDR $iteration]]} { set address_ok 0 }
  if {![checked_static_read STATIC_B $::BOARD_ID_ADDR $::BOARD_ID_EXPECTED \
      $iteration previous_label previous_value previous_stable]} { set address_ok 0 }
  if {![value_usable [stable_dynamic_read DMTD_FB $::DMTD_FB_ADDR $iteration]]} { set address_ok 0 }
  if {![checked_static_read STATIC_A $::STATIC_SIGNATURE_ADDR $::STATIC_SIGNATURE_EXPECTED \
      $iteration previous_label previous_value previous_stable]} { set address_ok 0 }
  if {![value_usable [stable_dynamic_read DMTD_REF $::DMTD_REF_ADDR $iteration]]} { set address_ok 0 }
  if {![checked_static_read STATIC_B $::BOARD_ID_ADDR $::BOARD_ID_EXPECTED \
      $iteration previous_label previous_value previous_stable]} { set address_ok 0 }
  if {![value_usable [stable_dynamic_read DMTD_FB $::DMTD_FB_ADDR $iteration]]} { set address_ok 0 }
  if {$address_ok} { incr ::address_sequence_valid }
}

set selected_hardware ""
set selected_device ""
foreach hardware_name [get_hardware_names] {
  if {$hardware_name ne $board_filter} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set selected_hardware $hardware_name
  set selected_device [lindex $device_names 0]
  break
}
if {$selected_hardware eq ""} { error [format "board not found: %s" $board_filter] }

puts [format "JTAG_WB_COMPLETION_STABLE_AUDIT_START board=%s device=%s iterations=%d" \
  $selected_hardware $selected_device $iterations]
puts [format "STATIC_SIGNATURE addr=0x%08X expected=0x%08X" $STATIC_SIGNATURE_ADDR $STATIC_SIGNATURE_EXPECTED]
puts [format "BOARD_ID addr=0x%08X expected=0x%08X" $BOARD_ID_ADDR $BOARD_ID_EXPECTED]
puts [format "DMTD_REF addr=0x%08X DMTD_FB addr=0x%08X" $DMTD_REF_ADDR $DMTD_FB_ADDR]

set probe_started 0
if {[catch {
  start_insystem_source_probe -hardware_name $selected_hardware -device_name $selected_device
  set probe_started 1
  set sync_value [safe_probe_read]
  set sync_done [high_bit $sync_value 3]
  if {$sync_done >= 0} { set ::wb_toggle $sync_done }
  for {set iteration 1} {$iteration <= $iterations} {incr iteration} {
    run_iteration $iteration
  }
} error_message]} {
  puts [format "JTAG_WB_COMPLETION_STABLE_EXCEPTION %s" $error_message]
}
if {$probe_started} { catch {end_insystem_source_probe} }

puts ""
puts "JTAG_WB_COMPLETION_STABLE_AUDIT_SUMMARY"
puts [format "ITERATIONS = %d" $iterations]
puts [format "TOTAL_WB_REQUESTS = %d" $::total_wb_requests]
puts [format "TOTAL_PROBE_READS = %d" $::total_probe_reads]
puts [format "STATIC_SIGNATURE_MISMATCH = %d" $::static_signature_mismatch]
puts [format "BOARD_ID_MISMATCH = %d" $::board_id_mismatch]
puts [format "STALE_A5A5_COUNT = %d" $::stale_a5a5_count]
puts [format "TIMEOUT_COUNT = %d" $::timeout_count]
puts [format "INVALID_COUNT = %d" $::invalid_count]
puts [format "ADDRESS_CROSS_CONTAMINATION_COUNT = %d" $::address_cross_contamination_count]
puts [format "DMTD_REF_DECREASE_COUNT = %d" $::dmtd_ref_decrease_count]
puts [format "DMTD_FB_DECREASE_COUNT = %d" $::dmtd_fb_decrease_count]
puts [format "DMTD_REF_TRIPLE_VALID = %d" $::dmtd_ref_triple_valid]
puts [format "DMTD_FB_TRIPLE_VALID = %d" $::dmtd_fb_triple_valid]
puts [format "INITIAL_COMPLETION_UNSTABLE_COUNT = %d" $::initial_completion_unstable_count]
puts [format "INITIAL_DATA_WRONG_BUT_STABILIZED_CORRECT_COUNT = %d" $::initial_data_wrong_but_stabilized_correct_count]
puts [format "STABLE_RESPONSE_WRONG_COUNT = %d" $::stable_response_wrong_count]
puts [format "PROBE_STABILIZATION_TIMEOUT_COUNT = %d" $::probe_stabilization_timeout_count]
puts [format "PROBE_2WAY_MATCH_COUNT = %d" $::probe_2way_match_count]
puts [format "PROBE_3WAY_MATCH_COUNT = %d" $::probe_3way_match_count]
puts [format "STABLE_TRANSACTION_COUNT = %d" $::stable_transaction_count]
puts [format "UNSTABLE_TRANSACTION_COUNT = %d" $::unstable_transaction_count]
puts [format "STATIC_SEQUENCE_VALID = %d" $::static_sequence_valid]
puts [format "ADDRESS_SEQUENCE_VALID = %d" $::address_sequence_valid]
if {$::first_error_recorded} {
  puts [format "FIRST_ERROR = %s" $::first_error_text]
} else {
  puts "FIRST_ERROR = NONE"
}

set generic_fail [expr {$::static_signature_mismatch > 0 || $::board_id_mismatch > 0 ||
                         $::stale_a5a5_count > 0 || $::timeout_count > 0 ||
                         $::invalid_count > 0 || $::address_cross_contamination_count > 0 ||
                         $::stable_response_wrong_count > 0}]
if {$generic_fail} {
  puts "JTAG_WB_TRANSACTION_PATH = FAIL"
  puts "JTAG_PROBE_OR_MAILBOX_STABILITY = FAIL"
} elseif {$::initial_data_wrong_but_stabilized_correct_count > 0 ||
          $::initial_completion_unstable_count > 0} {
  puts "JTAG_WB_TRANSACTION_PATH = PASS"
  puts "JTAG_PROBE_COMPLETION_VISIBILITY_RACE = CONFIRMED"
  puts "STABLE_DOUBLE_SAMPLE_MITIGATION = PASS"
} else {
  puts "JTAG_WB_COMPLETION_STABLE_DOUBLE_SAMPLE = PASS"
}
