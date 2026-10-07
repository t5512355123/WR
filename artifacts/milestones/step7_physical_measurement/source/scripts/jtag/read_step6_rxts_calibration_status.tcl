# One bounded READ-ONLY firmware-status query per board. Never exchange roles.
set rxstatus_args $argv
set argv {}
if {![llength [info commands rxcal_command]]} {
  set ::rxcal_library_only 1
  source [file join [file dirname [info script]] run_step6_master_rxts_role_calibration.tcl]
  unset ::rxcal_library_only
}
set argv $rxstatus_args
if {[llength $argv]} { error "No options: read-only two-board status" }
set begin [clock milliseconds];set ::rxcal_deadline [expr {$begin+120000}]
set targets {}
foreach name {1-11.1 1-11.2} rxstatus_physical_role {MASTER SLAVE} {
  set found {}
  foreach hw [get_hardware_names] {if {[string first $name $hw]>=0} {lappend found $hw}}
  if {[llength $found]!=1} {error "Missing/ambiguous board"}
  set hw [lindex $found 0];set devices [get_device_names -hardware_name $hw]
  if {[llength $devices]!=1} {error "Missing/ambiguous FPGA"}
  lappend targets [list $hw [lindex $devices 0] $rxstatus_physical_role]
}
puts "RXSTATUS_CONFIG read_only=1 max_actual_ms=120000 role_changed=0"
set rc [catch {
  foreach target $targets rxstatus_expected_mode {2 3} {
    set before [rxcal_health $target]
    set init0 [word32 [wb_read [lindex $target 0] 0x00100B44]]
    set d [rxcal_status [rxcal_command $target "calibration status"]]
    set after [rxcal_health $target]
    set init1 [word32 [wb_read [lindex $target 0] 0x00100B44]]
    if {$init0 eq "INVALID" || $init1 eq "INVALID" || $init0!=$init1 ||
        [dict get $before mode]!=$rxstatus_expected_mode || [dict get $after mode]!=$rxstatus_expected_mode} {
      error "Role/SoftPLL generation changed or invalid"
    }
    puts "RXSTATUS_DATA board={[lindex $target 0]} INIT=$init0 data={$d}"
  }
  rxcal_budget 1
  puts "RXSTATUS_DONE boards=2 elapsed_ms=[expr {[clock milliseconds]-$begin}] goal_pass=0"
} reason]
catch {end_insystem_source_probe}
if {$rc} {error $reason}
