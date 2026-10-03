# Offline actual reader procedure on Quartus Tcl; no hardware session opened.
set argv {}; set ::dco_capture_library_only 1
source [file join [file dirname [info script]] .. jtag read_step6_main_dco_capture.tcl]
# Model Quartus discovery owning its own session. Health leaves one active;
# the actual reader must close it before querying instances.
set ::test_active 1; set ::test_wrong_image 0
proc end_insystem_source_probe {} {
  if {!$::test_active} {error "No health session to close"}
  set ::test_active 0
}
proc get_insystem_source_probe_instance_info {args} {
  if {$::test_active} {error "Second JTAG session"}
  if {$::test_wrong_image} {return WR_S6_MAIN_DCO_META_V1}
  return {WR_S6_MAIN_DCO_META_V1 WR_S6_MAIN_DCO_POSITION_V1 WR_S6_MAIN_DCO_COUNTS_V1}
}
if {[llength [dco_require_image test_hw test_device]]!=3 || $::test_active} {
  error "Image discovery/session ownership failed"
}
set ::test_active 1; set ::test_wrong_image 1
if {![catch {dco_require_image test_hw test_device} why] ||
    $why ne "Wrong image: missingWR_S6_MAIN_DCO_POSITION_V1"} {
  error "Incomplete image not rejected: $why"
}
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
puts "ACTUAL_QUARTUS_TCL_DCO_CAPTURE=PASS private_source_only=1 coherent=1 torn_rejected=1 session_ownership=1 wrong_image_rejected=1 hardware_session=0"
