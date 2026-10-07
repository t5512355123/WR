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
  switch $::test_wrong_image {
    1 {return {{72 1 64 A_V1}}}
    2 {return {{72 1 32 A_V1} {73 1 64 N_V1} {74 1 64 S_V1}}}
    3 {return {{72 1 64 A_V1} {72 1 64 A_V1} {73 1 64 N_V1} {74 1 64 S_V1}}}
    4 {return {{72 1 64 Z_V1} {73 1 64 N_V1} {74 1 64 S_V1}}}
    5 {return {{72 2 64 A_V1} {73 1 64 N_V1} {74 1 64 S_V1}}}
  }
  return {{72 1 64 A_V1} {73 1 64 N_V1} {74 1 64 S_V1}}
}
if {[llength [dco_require_image test_hw test_device]]!=3 || $::test_active} {
  error "Image discovery/session ownership failed"
}
foreach bad {1 2 3 4 5} {
  set ::test_active 1; set ::test_wrong_image $bad
  if {![catch {dco_require_image test_hw test_device} why] ||
      [string first "Wrong image: instance contract" $why]!=0} {
    error "Wrong image/width/duplicate/name/source not rejected: $why"
  }
}
# The actual two source-guarded groups must each be seven reads, not a
# ten-read combined publication window. Invalid epochs/locks still fail.
set ::test_wb_reads {}; set ::test_bad_epoch 0; set ::test_bad_lock 0; set ::test_epoch 2
proc wb_read {hw address} {
  lappend ::test_wb_reads $address
  switch $address {
    0x00100B34 {
      if {$::test_bad_epoch} {incr ::test_epoch}
      return [format %08X $::test_epoch]
    }
    0x00100A04 {return 00000001}
    0x00100A48 {return 00000064}
    0x00100A40 {return FFFFFFFE}
    0x00100A08 {return 00000401}
    0x00100ABC {return 00000001}
    0x00100AC4 {if {$::test_bad_lock} {return 00000003};return 0000000F}
    0x00100A0C {return 00000003}
    default {error "Unexpected diagnostic address"}
  }
}
if {[llength [dco_frame test_hw]]!=7 || [llength $::test_wb_reads]!=7} {
  error "Wrong primary frame scope"
}
set ::test_wb_reads {}
if {[llength [dco_lock_frame test_hw]]!=7 || [llength $::test_wb_reads]!=7} {
  error "Wrong lock frame scope"
}
set ::test_bad_lock 1
if {![catch {dco_lock_frame test_hw} why] || $why ne "Slave lock loss"} {
  error "Lock loss not rejected"
}
set ::test_bad_lock 0; set ::test_bad_epoch 1
foreach group {dco_frame dco_lock_frame} {
  if {![catch {$group test_hw} why] ||
      $why ne "No fresh coherent diagnostic group within600ms"} {
    error "Torn group not rejected: $group $why"
  }
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
puts "ACTUAL_QUARTUS_TCL_DCO_CAPTURE=PASS private_source_only=1 coherent=1 torn_rejected=1 session_ownership=1 wrong_image_rejected=1 separate_seven_read_groups=1 hardware_session=0"
