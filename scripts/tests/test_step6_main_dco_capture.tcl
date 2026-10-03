# Offline actual reader procedure on Quartus Tcl; no hardware session opened.
set argv {}; set ::dco_capture_library_only 1
source [file join [file dirname [info script]] .. jtag read_step6_main_dco_capture.tcl]
set ::test_meta 0000000020020000; set ::written {}; set ::torn 0
proc probe_word {i} {
  if {$i==72} {
    if {$::torn} {return 0000000020020006}
    return $::test_meta
  }
  return 0000800000008000
}
proc write_source_data {args} {
  if {[lindex $args 1]!=72} {error "Wrong debug source"}
  lappend ::written [lindex $args 1]
  set toggle [lindex $args 3]
  set ::test_meta [format %016X [expr {0x20020002 | $toggle}]]
}
set values [dco_capture]
if {[llength $values]!=4 || $::written ne "72"} {error "Wrong capture/write scope"}
# Make the closing meta change after the first ACK. This must reject, not retry
# a different source group or silently accept two snapshots as one.
rename probe_word probe_word_original
set ::reads 0
proc probe_word {i} {
  if {$i==72} {
    incr ::reads
    if {$::reads>=3} {return 0000000020020006}
  }
  return [probe_word_original $i]
}
set ::test_meta 0000000020020000
if {![catch {dco_capture} why] || $why ne "Capture changed/second observer"} {
  error "Torn snapshot did not fail closed: $why"
}
puts "ACTUAL_QUARTUS_TCL_DCO_CAPTURE=PASS private_source_only=1 coherent=1 torn_rejected=1 hardware_session=0"
