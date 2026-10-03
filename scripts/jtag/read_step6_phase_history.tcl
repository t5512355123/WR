# One passive32-record history, two rows/page, no PLL/control writes.
set saved_args $argv; set argv {}; set ::ts4_library_only 1
source [file join [file dirname [info script]] read_step6_four_timestamp_diagnostic.tcl]
unset ::ts4_library_only; set argv $saved_args
if {[llength $argv]} { error "No options: one immutable32 history" }
proc phist_parse {text page prior_id prior_total} {
  set headers [regexp -all -inline -line {^PHIST_PAGE v=1 snapshot=([0-9a-f]{8}) total=([0-9a-f]{8}) page=([0-9]+) count=([0-9]+) words=36\r?$} $text]
  if {[llength $headers]!=5} { error "Missing/duplicate PHIST header" }
  lassign $headers all id total p count
  if {$p!=$page || $count!=32 || ($page>0 && ($id ne $prior_id || $total ne $prior_total))} { error "Wrong/changed PHIST snapshot" }
  set ends [regexp -all -inline -line "^PHIST_END snapshot=$id page=$page\\r?$" $text]
  if {[llength $ends]!=1} { error "Missing/duplicate PHIST end" }
  set rows {}
  foreach line [split $text "\n"] {
    set line [string trim $line]; if {![string match PHIST_V1* $line]} {continue}
    if {![regexp {^PHIST_V1 idx=([0-9]+) words=(.*)$} $line -> index payload]} { error "Bad PHIST row" }
    set w [split $payload " "]
    if {$index!=$page*2+[llength $rows] || [llength $w]!=36} { error "Bad PHIST index/schema" }
    foreach word $w { if {![regexp {^[0-9a-f]{8}$} $word]} { error "Malformed PHIST word" } }
    if {[ts4_u32 $w 0]!=(([expr 0x$total]-32+$index+1)&0xffffffff)} { error "PHIST serial mismatch" }
    if {[ts4_u32 $w 16]!=1 || [ts4_u32 $w 26]!=1 || ([ts4_u32 $w 34]&1) || ([ts4_u32 $w 35]&1)} { error "Incoherent source group" }
    lappend rows $w
  }
  if {[llength $rows]!=2} { error "Incomplete PHIST page" }
  return [list $id $total $rows]
}
if {[info exists ::phist_library_only] && $::phist_library_only} { return }
set begin [clock milliseconds]; set deadline [expr {$begin+240000}]
set targets {}
foreach name {1-11.1 1-11.2} role {MASTER SLAVE} {
  set found {}; foreach hw [get_hardware_names] { if {[string first $name $hw]>=0} { lappend found $hw } }
  if {[llength $found]!=1} { error "Missing/ambiguous target" }
  set hw [lindex $found 0]; set devices [get_device_names -hardware_name $hw]
  if {![llength $devices]} { error "Missing device" }
  lappend targets [list $hw [lindex $devices 0] $role]
}
puts "PHIST_CONFIG records=32 max_actual_ms=240000 control_changed=0 packet_atomic=0"
set completed 0; set failure ""
if {[catch {
  foreach target $targets { ts4_health $target }
  set slave [lindex $targets 1]; lassign $slave hw device role; ts4_select $slave
  set ready 0; set quiet -1; set start [clock milliseconds]
  while {[clock milliseconds]-$start<30000} {
    set now [clock milliseconds]
    if {[stable_shell_ready $hw]} {
      if {$quiet<0} { set quiet $now }; if {$now-$quiet>=1000} { set ready 1; break }
    } else { set quiet -1 }
    after 100
  }
  if {!$ready} { error "Shell not quiet/ready" }
  lassign [drain_preexisting_uart $hw 30000] status hex text
  puts "PHIST_PREEXISTING status=$status hex=$hex"
  if {$status ne "OK"} { error "Pre-drain failed" }
  set id ""; set total ""; set generation ""
  for {set page 0} {$page<16} {incr page} {
    set start [clock milliseconds]; if {$start>=$deadline} { error "Actual deadline" }
    if {[send_vuart_command $hw "pll phist $page"] ne "OK"} { error "Command delivery failed" }
    set remaining [expr {min(30000,$deadline-[clock milliseconds])}]
    if {$remaining<=0} { error "Actual deadline" }
    lassign [capture_vuart_reply $hw $remaining] status hex text
    puts "PHIST_REPLY page=$page start_ms=[expr {$start-$begin}] end_ms=[expr {[clock milliseconds]-$begin}] status=$status hex=$hex"
    if {$status ne "OK"} { error "Reply transport failed" }
    lassign [phist_parse $text $page $id $total] id total rows
    foreach w $rows {
      set g [list [lindex $w 6] [lindex $w 18] [lindex $w 27]]
      if {$generation eq ""} { set generation $g }
      if {$g ne $generation} { error "History init/tracker generation changed" }
    }
    incr completed 2
    if {$page==0} { puts "PHIST_SMOKE_PASS records=2 snapshot=$id" }
    if {$completed%8==0} { foreach target $targets { ts4_health $target }; ts4_select $slave }
    flush stdout
  }
} failure]} { puts "PHIST_STOP reason={$failure} records=$completed" }
catch {end_insystem_source_probe}
puts "PHIST_DONE records=$completed elapsed_ms=[expr {[clock milliseconds]-$begin}]"
if {$completed!=32} { error "Incomplete PHIST capture: $failure" }
