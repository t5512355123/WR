# Quartus STP syntax/compile-only harness for the re-arm observer.
# The mocked empty hardware list stops before any JTAG read or write.
set ::wf_library_only 1
set argv [list PARSE_ONLY 10000 300 300 40000]
proc get_hardware_names {} { return {} }
set target_script [file normalize [file join [file dirname [info script]] .. jtag read_step6b_rearm_repeatability.tcl]]
if {[catch {source $target_script} message options]} {
  if {[string match "*both DE5a targets are required*" $message]} {
    puts "STEP6B_REARM_TCL_PARSE=PASS"
    exit 0
  }
  puts stderr [format "STEP6B_REARM_TCL_PARSE=FAIL ERROR=%s" $message]
  exit 1
}
puts stderr "STEP6B_REARM_TCL_PARSE=FAIL observer did not stop at mocked hardware boundary"
exit 1
