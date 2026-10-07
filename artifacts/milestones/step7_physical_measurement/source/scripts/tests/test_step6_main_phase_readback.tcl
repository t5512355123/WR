# Native Tcl offline mock test. quartus_sh -t, no JTAG package or hardware.
source scripts/jtag/step6_main_phase_readback_lib.tcl
rename puts original_puts
proc puts {args} {set ::last_line [lindex $args end]}
proc flush {args} {}
proc s6_a_us {} {return 1000000}
proc is_hex {v} {return [regexp {^[0-9A-Fa-f]{1,16}$} $v]}
proc word32 {v} {
  if {![is_hex $v]} {return -1}
  set number [expr 0x$v]
  return [expr {$number & 0xffffffff}]
}
proc s6_a_signed32 {v} {
  set n [word32 $v]
  return [expr {$n >= 0x80000000 ? $n-0x100000000 : $n}]
}
proc wb_read {address} {
  lappend ::addresses $address
  set raw [lindex $::responses $::response_index]
  incr ::response_index
  return $raw
}
set normal {00000002 46344C31 00000101 00000002 00000010 00000001 00000002 FFFFFC00 00000002}
proc run_mock {frame expected {u1 00000007} {pair 00000007}} {
  set ::response_index 0
  set ::addresses {}
  set ::responses [concat {00000007} $frame $frame $frame [list $u1]]
  if {$frame eq $::normal} {set ::responses [concat {00000007} $frame [list $u1]]}
  set value [s6_main_phase_readback {DE5 [1-11.2]} 0 $pair 0]
  if {$value != $expected} {error "unexpected frame verdict=$value wanted=$expected"}
  incr ::tests
}
set tests 0
run_mock $normal 1
if {[string first PHASE_CURRENT_UNITS=-1024 $::last_line] < 0 ||
    [string first PHASE_CURRENT_PS=-1000 $::last_line] < 0 ||
    [string first SERVO_UPDATE_MATCH=1 $::last_line] < 0} {error "signed/current/join decoding failed"}
foreach {index value} {8 00000004 3 00000003 1 A5A50158 2 00000002
                       2 00000301 3 00000000 7 TIMEOUT 4 00000000} {
  set torn [lreplace $normal $index $index $value]
  run_mock $torn 0
}
set torn [lreplace $normal 0 0 00000003]
set torn [lreplace $torn 8 8 00000003]
run_mock $torn 0
run_mock $normal 1 00000008
if {[string first SERVO_UPDATE_MATCH=0 $::last_line] < 0} {error "UCNT change accepted"}
run_mock $normal 1 00000007 00000006
if {[string first SERVO_UPDATE_MATCH=0 $::last_line] < 0} {error "wrong servo pair accepted"}
if {[lindex $::addresses 0] ne "0x00100A48" ||
    [lindex $::addresses end] ne "0x00100A48" ||
    [lindex $::addresses 8] ne "0x00100B88"} {error "mapping failed"}
original_puts "NATIVE_TCL_MAIN_PHASE_READBACK_TESTS=$tests PASS hardware_access=0"
