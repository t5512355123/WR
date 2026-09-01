# Read-only JTAG/Wishbone mailbox stability audit.
#
# This observer deliberately keeps one in-system source-probe session open for
# the complete run.  It only submits Wishbone read requests through mailbox
# instance 1; it does not write firmware, RTL, PI, or snapshot controls.
#
# Usage:
#   quartus_stp -t read_jtag_wb_readpath_stability.tcl ?iterations? ?board_filter?
#
# The audit checks:
#   A. 0x00100124 / 0x00100128 static identity reads in A1 B1 A2 B2 A3 B3
#   B. DMTD_REF / DMTD_FB same-address triples for monotonicity
#   C. STATIC_A -> DMTD_REF -> STATIC_B -> DMTD_FB address switching

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
set ::total_wb_reads 0
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
set ::board_sequence_valid 0
set ::address_sequence_valid 0
set ::first_error_recorded 0
set ::first_error_text ""

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]+$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 8} {
    set text [string range $text end-7 end]
  }
  set word 0
  scan $text %x word
  return [expr {$word & 0xffffffff}]
}

proc high32 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  set text [string repeat 0 [expr {16 - [string length $text]}]]$text
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

proc safe_probe_read {} {
  if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
    return "TIMEOUT"
  }
  if {![is_hex $value]} { return "INVALID" }
  return $value
}

proc remember_first_error {text} {
  if {!$::first_error_recorded} {
    set ::first_error_recorded 1
    set ::first_error_text $text
  }
}

proc mailbox_read {addr} {
  incr ::wb_toggle
  set ::wb_toggle [expr {$::wb_toggle & 1}]
  set cmd [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  incr ::total_wb_reads
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    incr ::timeout_count
    return "TIMEOUT"
  }
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [safe_probe_read]
    set word [word32 $value]
    set done_toggle [high_bit $value 3]
    set active [high_bit $value 4]
    if {$word >= 0 && $done_toggle == $::wb_toggle && $active == 0} {
      if {[stale_jtag_word $value]} { incr ::stale_a5a5_count }
      return [format %08X $word]
    }
    after 1
  }
  incr ::timeout_count
  return "TIMEOUT"
}

proc value_usable {value} {
  if {$value eq "TIMEOUT" || $value eq "INVALID"} { return 0 }
  set word [word32 $value]
  if {$word < 0 || [stale_jtag_word $value]} { return 0 }
  return 1
}

proc note_invalid_value {label value iteration} {
  if {$value eq "TIMEOUT"} {
    remember_first_error [format "iteration=%d label=%s classification=TIMEOUT" $iteration $label]
  } elseif {$value eq "INVALID" || ![is_hex $value]} {
    incr ::invalid_count
    remember_first_error [format "iteration=%d label=%s value=%s classification=INVALID" $iteration $label $value]
  } elseif {[stale_jtag_word $value]} {
    remember_first_error [format "iteration=%d label=%s value=%s classification=STALE_A5A5" $iteration $label $value]
  }
}

proc audited_read {label addr iteration prev_label_name prev_value_name} {
  upvar 1 $prev_label_name previous_label
  upvar 1 $prev_value_name previous_value
  set value [mailbox_read $addr]
  note_invalid_value $label $value $iteration

  # An equal response immediately after a different-address request is
  # evidence of previous-address replay only when the current request has a
  # known invariant value, or the previous request had one.
  if {$previous_label ne "" && $label ne $previous_label &&
      [value_usable $value] && [value_usable $previous_value] &&
      [word32 $value] == [word32 $previous_value]} {
    set current_static [expr {$label eq "STATIC_A" || $label eq "STATIC_B"}]
    set previous_static [expr {$previous_label eq "STATIC_A" || $previous_label eq "STATIC_B"}]
    if {$current_static || $previous_static} {
      incr ::address_cross_contamination_count
      remember_first_error [format "iteration=%d requested=%s previous=%s observed=%s classification=PREVIOUS_RESPONSE_REPLAY" \
        $iteration $label $previous_label $value]
    }
  }
  set previous_label $label
  set previous_value $value
  return $value
}

proc checked_static_read {label addr expected iteration prev_label_name prev_value_name} {
  upvar 1 $prev_label_name previous_label
  upvar 1 $prev_value_name previous_value
  # audited_read() updates caller-local state through upvar.  Keep a local
  # alias here because this validation wrapper is one call frame deeper.
  set local_previous_label $previous_label
  set local_previous_value $previous_value
  set value [audited_read $label $addr $iteration local_previous_label local_previous_value]
  set previous_label $local_previous_label
  set previous_value $local_previous_value
  if {![value_usable $value]} { return 0 }
  if {[word32 $value] != $expected} {
    if {$label eq "STATIC_A"} { incr ::static_signature_mismatch }
    if {$label eq "STATIC_B"} { incr ::board_id_mismatch }
    remember_first_error [format "iteration=%d requested=%s expected=%08X observed=%s" \
      $iteration $label $expected $value]
    return 0
  }
  return 1
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
    remember_first_error [format "iteration=%d requested=%s values=%s classification=COUNTER_DECREASE" \
      $iteration $label [join $values ,]]
    return 0
  }
  return 1
}

proc run_iteration {iteration} {
  # A. Static registers: A1 B1 A2 B2 A3 B3.
  set previous_label ""
  set previous_value ""
  set static_ok 1
  if {![checked_static_read STATIC_A $::STATIC_SIGNATURE_ADDR $::STATIC_SIGNATURE_EXPECTED $iteration previous_label previous_value]} { set static_ok 0 }
  if {![checked_static_read STATIC_B $::BOARD_ID_ADDR $::BOARD_ID_EXPECTED $iteration previous_label previous_value]} { set static_ok 0 }
  if {![checked_static_read STATIC_A $::STATIC_SIGNATURE_ADDR $::STATIC_SIGNATURE_EXPECTED $iteration previous_label previous_value]} { set static_ok 0 }
  if {![checked_static_read STATIC_B $::BOARD_ID_ADDR $::BOARD_ID_EXPECTED $iteration previous_label previous_value]} { set static_ok 0 }
  if {![checked_static_read STATIC_A $::STATIC_SIGNATURE_ADDR $::STATIC_SIGNATURE_EXPECTED $iteration previous_label previous_value]} { set static_ok 0 }
  if {![checked_static_read STATIC_B $::BOARD_ID_ADDR $::BOARD_ID_EXPECTED $iteration previous_label previous_value]} { set static_ok 0 }
  if {$static_ok} { incr ::static_sequence_valid }

  # B. Same-address DMTD triples.
  set previous_label ""
  set previous_value ""
  set ref_values {}
  for {set n 0} {$n < 3} {incr n} {
    lappend ref_values [audited_read DMTD_REF $::DMTD_REF_ADDR $iteration previous_label previous_value]
  }
  if {[check_monotonic_triple DMTD_REF $ref_values $iteration]} { incr ::dmtd_ref_triple_valid }

  set previous_label ""
  set previous_value ""
  set fb_values {}
  for {set n 0} {$n < 3} {incr n} {
    lappend fb_values [audited_read DMTD_FB $::DMTD_FB_ADDR $iteration previous_label previous_value]
  }
  if {[check_monotonic_triple DMTD_FB $fb_values $iteration]} { incr ::dmtd_fb_triple_valid }

  # C. Address switching contamination sequence.
  set previous_label ""
  set previous_value ""
  set address_ok 1
  set value [audited_read STATIC_A $::STATIC_SIGNATURE_ADDR $iteration previous_label previous_value]
  if {![value_usable $value] || [word32 $value] != $::STATIC_SIGNATURE_EXPECTED} { set address_ok 0 }
  set value [audited_read DMTD_REF $::DMTD_REF_ADDR $iteration previous_label previous_value]
  if {![value_usable $value]} { set address_ok 0 }
  set value [audited_read STATIC_B $::BOARD_ID_ADDR $iteration previous_label previous_value]
  if {![value_usable $value] || [word32 $value] != $::BOARD_ID_EXPECTED} { set address_ok 0 }
  set value [audited_read DMTD_FB $::DMTD_FB_ADDR $iteration previous_label previous_value]
  if {![value_usable $value]} { set address_ok 0 }
  set value [audited_read STATIC_A $::STATIC_SIGNATURE_ADDR $iteration previous_label previous_value]
  if {![value_usable $value] || [word32 $value] != $::STATIC_SIGNATURE_EXPECTED} { set address_ok 0 }
  set value [audited_read DMTD_REF $::DMTD_REF_ADDR $iteration previous_label previous_value]
  if {![value_usable $value]} { set address_ok 0 }
  set value [audited_read STATIC_B $::BOARD_ID_ADDR $iteration previous_label previous_value]
  if {![value_usable $value] || [word32 $value] != $::BOARD_ID_EXPECTED} { set address_ok 0 }
  set value [audited_read DMTD_FB $::DMTD_FB_ADDR $iteration previous_label previous_value]
  if {![value_usable $value]} { set address_ok 0 }
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
if {$selected_hardware eq ""} {
  error [format "board not found: %s" $board_filter]
}

puts [format "JTAG_WB_READPATH_AUDIT_START board=%s device=%s iterations=%d" \
  $selected_hardware $selected_device $iterations]
puts [format "STATIC_SIGNATURE addr=0x%08X expected=0x%08X" $STATIC_SIGNATURE_ADDR $STATIC_SIGNATURE_EXPECTED]
puts [format "BOARD_ID addr=0x%08X expected=0x%08X" $BOARD_ID_ADDR $BOARD_ID_EXPECTED]
puts [format "DMTD_REF addr=0x%08X DMTD_FB addr=0x%08X" $DMTD_REF_ADDR $DMTD_FB_ADDR]

set probe_started 0
if {[catch {
  start_insystem_source_probe -hardware_name $selected_hardware -device_name $selected_device
  set probe_started 1
  # Synchronize the local toggle with the mailbox before the first request.
  set sync_value [safe_probe_read]
  set sync_done [high_bit $sync_value 3]
  if {$sync_done >= 0} { set ::wb_toggle $sync_done }
  for {set iteration 1} {$iteration <= $iterations} {incr iteration} {
    run_iteration $iteration
  }
} error_message]} {
  puts [format "JTAG_WB_READPATH_EXCEPTION %s" $error_message]
}
if {$probe_started} { catch {end_insystem_source_probe} }

puts ""
puts "JTAG_WB_READPATH_AUDIT_SUMMARY"
puts [format "ITERATIONS = %d" $iterations]
puts [format "TOTAL_WB_READS = %d" $::total_wb_reads]
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
puts [format "STATIC_SEQUENCE_VALID = %d" $::static_sequence_valid]
puts [format "ADDRESS_SEQUENCE_VALID = %d" $::address_sequence_valid]
if {$::first_error_recorded} {
  puts [format "FIRST_ERROR = %s" $::first_error_text]
} else {
  puts "FIRST_ERROR = NONE"
}

set static_fail [expr {$::static_signature_mismatch > 0 || $::board_id_mismatch > 0}]
set generic_fail [expr {$static_fail || $::stale_a5a5_count > 0 ||
                          $::timeout_count > 0 || $::invalid_count > 0 ||
                          $::address_cross_contamination_count > 0}]
set dmtd_fail [expr {$::dmtd_ref_decrease_count > 0 || $::dmtd_fb_decrease_count > 0}]
if {$generic_fail} {
  puts "GENERIC_JTAG_WB_READ_PATH_STABILITY = FAIL"
  puts "JTAG_WB_MAILBOX_INSTABILITY = CONFIRMED"
} elseif {$dmtd_fail} {
  puts "GENERIC_JTAG_WB_READ_PATH_STABILITY = PASS"
  puts "DMTD_COUNTER_READ_STABILITY = FAIL"
} else {
  puts "JTAG_WB_READ_PATH_STABILITY = PASS"
}
