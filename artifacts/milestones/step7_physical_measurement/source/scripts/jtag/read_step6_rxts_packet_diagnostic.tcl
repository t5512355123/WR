# Passive packet RAM snapshot; a single session alternates the two boards.
package require ::quartus::insystem_source_probe
set saved_args $argv
set argv {}
set ::step6_vuart_library_only 1
source [file join [file dirname [info script]] read_step6_ip_vuart.tcl]
unset ::step6_vuart_library_only
set argv $saved_args
set repetitions 1
if {[llength $argv]} { set repetitions [expr {int([lindex $argv 0])}] }
if {$repetitions<1 || $repetitions>4} { error "One to four snapshots per board only" }

proc rxts_parse_page {text page prior_id prior_total} {
  if {![regexp {RXTS_PAGE v=1 snapshot=([0-9a-f]{8}) total=([0-9a-f]{8}) page=([0-9]+) count=([0-9]+)} $text -> id total received count]} {
    error "Missing RXTS versioned header"
  }
  if {$received!=$page || $count<0 || $count>32 ||
      ($page>0 && ($id ne $prior_id || $total ne $prior_total))} {
    error "Changed/invalid RXTS snapshot"
  }
  if {![regexp "RXTS_END snapshot=$id page=${page}(?:\\r|\\n)" $text]} {
    error "Missing RXTS page completion"
  }
  set rows {}
  foreach line [split $text "\n"] {
    set line [string trim $line]
    if {![string match RXTS_V1* $line]} { continue }
    if {![regexp {^RXTS_V1 idx=([0-9]+) words=(.*)$} $line -> index words]} {
      error "Malformed RXTS record"
    }
    set words [split $words " "]
    if {[llength $words]!=18} { error "Incomplete RXTS record" }
    foreach word $words {
      if {![regexp {^[0-9a-f]{8}$} $word]} { error "Malformed RXTS word" }
    }
    if {$index!=$page*4+[llength $rows]} { error "Wrong RXTS record index" }
    lappend rows $line
  }
  set expected [expr {max(0,min(4,$count-$page*4))}]
  if {[llength $rows]!=$expected} { error "Dropped RXTS records" }
  return [list $id $total $count $rows]
}

proc rxts_health {hw master} {
  set st [word64 [probe_word 0]]
  set en [word64 [probe_word 26]]
  set rs [word64 [probe_word 27]]
  set es [word32 [wb_read $hw 0x0010031C]]
  set h [word32 [wb_read $hw 0x00100ABC]]
  set m [word32 [wb_read $hw 0x00100AC4]]
  set p [word32 [wb_read $hw 0x00100A0C]]
  foreach value [list $st $en $rs $es $h $m $p] {
    if {$value eq "INVALID"} { error "Invalid live health read" }
  }
  set sig [list [expr {($en>>32)&0xffffffff}] \
    [expr {($rs>>16)&0xff}] [expr {($rs>>24)&0xff}] \
    [expr {($rs>>32)&0xff}] [expr {($rs>>40)&0xff}]]
  if {![info exists ::rxts_reset($hw)]} { set ::rxts_reset($hw) $sig }
  if {$sig ne $::rxts_reset($hw)} { error "Reset identity changed" }
  foreach bit {0 1 2 3 6 7 15 32} {
    if {!(($st>>$bit)&1)} { error "Link/clock/reset prerequisite lost" }
  }
  if {!(($h&1)==1) || (!$master && (($m&0xe)!=0xe || ($p&2)!=2))} {
    error "PLL lock prerequisite lost"
  }
  set time_valid [expr {(($st>>4)&1) && (($es&0xc)==0xc)}]
  if {$master && !$time_valid} { error "Master local time invalid" }
  puts "RXTS_HEALTH board={$hw} master=$master TIME_VALID=$time_valid RESET={$sig} STATUS=[format %016X $st] ESCR=[format %08X $es]"
}

if {[info exists ::rxts_library_only] && $::rxts_library_only} { return }
set begin [clock milliseconds]
set deadline [expr {$begin+540000}]
set targets {}
foreach name {1-11.1 1-11.2} {
  set matches {}
  foreach hw [get_hardware_names] {
    if {[string first $name $hw]>=0} { lappend matches $hw }
  }
  if {[llength $matches]!=1} { error "Missing/ambiguous DE5 target $name" }
  set hw [lindex $matches 0]
  set devices [get_device_names -hardware_name $hw]
  if {![llength $devices]} { error "Missing device on $hw" }
  lappend targets [list $hw [lindex $devices 0] [expr {$name eq "1-11.1"}]]
}
puts "RXTS_CONFIG schema=1 repetitions=$repetitions deadline_ms=540000 controls_changed=0 history_continuous=0"
set completed 0
set failure ""
if {[catch {
  for {set pass 0} {$pass<$repetitions} {incr pass} {
    foreach target $targets {
      lassign $target hw device master
      catch {end_insystem_source_probe}
      start_insystem_source_probe -hardware_name $hw -device_name $device
      wb_sync_toggle $hw
      set quiet_since -1
      set ready 0
      set gate_start [clock milliseconds]
      while {[clock milliseconds]-$gate_start<30000 && [clock milliseconds]<$deadline} {
        set now [clock milliseconds]
        if {[stable_shell_ready $hw]} {
          if {$quiet_since<0} { set quiet_since $now }
          if {$now-$quiet_since>=1000} { set ready 1; break }
        } else { set quiet_since -1 }
        after 100
      }
      if {!$ready} { error "Shell not ready/quiet" }
      rxts_health $hw $master
      lassign [drain_preexisting_uart $hw 30000] status hex text
      puts "RXTS_PREEXISTING board={$hw} status=$status hex=$hex"
      if {$status ne "OK"} { error "Failed VUART pre-drain" }
      set id ""; set total ""; set count 32
      for {set page 0} {$page<8 && $page*4<$count} {incr page} {
        if {[clock milliseconds]>=$deadline} { error "Diagnostic deadline reached" }
        rxts_health $hw $master
        set start [clock milliseconds]
        if {[send_vuart_command $hw "pll rxts $page"] ne "OK"} { error "RXTS command delivery failed" }
        set remaining [expr {min(30000,$deadline-[clock milliseconds])}]
        if {$remaining<=0} { error "Diagnostic deadline reached" }
        lassign [capture_vuart_reply $hw $remaining] status hex text
        set end [clock milliseconds]
        puts "RXTS_REPLY board={$hw} capture=$pass page=$page start_ms=[expr {$start-$begin}] end_ms=[expr {$end-$begin}] status=$status hex=$hex"
        if {$status ne "OK"} { error "RXTS reply transport failed" }
        lassign [rxts_parse_page $text $page $id $total] id total count rows
        puts "RXTS_CAPTURE_PAGE board={$hw} capture=$pass snapshot=$id total=$total page=$page count=$count"
        foreach row $rows { puts "RXTS_RECORD board={$hw} capture=$pass snapshot=$id $row" }
        rxts_health $hw $master
        flush stdout
      }
      if {$count<8} { error "Insufficient packet history" }
      incr completed
      puts "RXTS_CAPTURE_DONE board={$hw} capture=$pass snapshot=$id records=$count"
      end_insystem_source_probe
    }
  }
} failure]} {
  puts "RXTS_STOP reason={$failure} completed=$completed"
}
catch {end_insystem_source_probe}
puts "RXTS_DONE completed=$completed required=[expr {$repetitions*2}] elapsed_ms=[expr {[clock milliseconds]-$begin}]"
if {$completed!=$repetitions*2} { error "RXTS diagnostic incomplete: $failure" }
