# Same-update RAM history; single observer, no control/calibration commands.
package require ::quartus::insystem_source_probe
set saved_args $argv
set argv {}
set ::step6_vuart_library_only 1
source [file join [file dirname [info script]] read_step6_ip_vuart.tcl]
unset ::step6_vuart_library_only
set argv $saved_args
if {[llength $argv]} { error "No options: one bounded frozen16-record snapshot" }

proc ts4_u32 {w at} { return [expr 0x[lindex $w $at]] }
proc ts4_s64 {w at} {
  set v [expr {([ts4_u32 $w $at]<<32) | [ts4_u32 $w [expr {$at+1}]]}]
  if {$v >= 0x8000000000000000} { set v [expr {$v-0x10000000000000000}] }
  return $v
}
proc ts4_time {w at} {
  if {(([ts4_u32 $w $at]>>24)&0xc0) == 0x80} { error "Incorrect stamp flag" }
  return [expr {[ts4_s64 $w $at]*1000000000*65536 + [ts4_s64 $w [expr {$at+2}]]}]
}
proc ts4_math {w} {
  if {[llength $w]!=86} { error "Wrong timestamp schema" }
  foreach word $w { if {![regexp {^[0-9a-f]{8}$} $word]} { error "Malformed timestamp word" } }
  if {[ts4_u32 $w 9]!=1 || ([ts4_u32 $w 6]>>24)!=9 || [ts4_u32 $w 12]!=0} {
    error "Not normal-feedback E2E DelayResp"
  }
  for {set i 0} {$i<4} {incr i} {
    set raw($i) [ts4_time $w [expr {16+$i*4}]]
    set cal($i) [ts4_time $w [expr {32+$i*4}]]
    set delta [ts4_time $w [expr {48+$i*4}]]
    set sign [expr {$i%2 ? -1 : 1}]
    if {$cal($i)!=$raw($i)+$sign*$delta} { error "Raw/calibrated fixed-delta mismatch" }
  }
  set rf [expr {$raw(1)-$raw(0)}]; set rr [expr {$raw(3)-$raw(2)}]
  set cf [expr {$cal(1)-$cal(0)}]; set cr [expr {$cal(3)-$cal(2)}]
  if {[ts4_time $w 80]!=$rf+$rr || [ts4_time $w 64]!=$cf+$cr} {
    error "RTT four-stamp identity mismatch"
  }
  if {[ts4_time $w 76]!=[ts4_time $w 68]-$cf} { error "CKO identity mismatch" }
  if {abs(2*[ts4_time $w 72]-[ts4_time $w 64])*1000>4*65536 ||
      abs([ts4_time $w 68]-[ts4_time $w 72]-[ts4_s64 $w 84])*1000>2*65536} {
    error "Mean/asymmetry identity mismatch"
  }
}
proc ts4_parse_page {text page prior_id prior_total} {
  if {![regexp {TS4_PAGE v=1 snapshot=([0-9a-f]{8}) total=([0-9a-f]{8}) page=([0-9]+) count=([0-9]+) words=([0-9]+)} $text -> id total p count words]} {
    error "Missing TS4 header"
  }
  if {$p!=$page || $count!=16 || $words!=86 ||
      ($page>0 && ($id ne $prior_id || $total ne $prior_total))} { error "Changed/wrong TS4 snapshot" }
  if {![regexp "TS4_END snapshot=$id page=${page}(?:\\r|\\n)" $text]} { error "Missing TS4 completion" }
  set records {}
  foreach line [split $text "\n"] {
    set line [string trim $line]
    if {![string match TS4_V1* $line]} { continue }
    if {![regexp {^TS4_V1 idx=([0-9]+) words=(.*)$} $line -> index data] || $index!=$page} {
      error "Wrong TS4 record index"
    }
    set w [split $data " "]
    ts4_math $w
    if {[ts4_u32 $w 0] != (([expr 0x$total]-16+$page+1)&0xffffffff)} {
      error "TS4 serial mismatch"
    }
    lappend records $w
  }
  if {[llength $records]!=1} { error "Missing/duplicate TS4 record" }
  return [list $id $total [lindex $records 0]]
}

proc ts4_select {target} {
  lassign $target hw device role
  catch {end_insystem_source_probe}
  start_insystem_source_probe -hardware_name $hw -device_name $device
  wb_sync_toggle $hw
}
proc ts4_health {target} {
  lassign $target hw device role
  ts4_select $target
  set st [word64 [probe_word 0]]
  set en [word64 [probe_word 26]]; set rs [word64 [probe_word 27]]
  set es [word32 [wb_read $hw 0x0010031C]]
  set h [word32 [wb_read $hw 0x00100ABC]]
  set m [word32 [wb_read $hw 0x00100AC4]]
  set p [word32 [wb_read $hw 0x00100A0C]]
  foreach value [list $st $en $rs $es $h $m $p] {
    if {$value eq "INVALID"} { error "Invalid health transport" }
  }
  set sig [list [expr {($en>>32)&0xffffffff}] [expr {($rs>>16)&0xff}] \
    [expr {($rs>>24)&0xff}] [expr {($rs>>32)&0xff}] [expr {($rs>>40)&0xff}]]
  if {![info exists ::ts4_reset($hw)]} { set ::ts4_reset($hw) $sig }
  if {$sig ne $::ts4_reset($hw)} { error "Reset identity changed" }
  foreach bit {0 1 2 3 6 7 15 32} {
    if {!(($st>>$bit)&1)} { error "Link/clock/reset gate lost" }
  }
  if {!($h&1) || ($role eq "SLAVE" && (($m&0xe)!=0xe || ($p&2)!=2))} { error "PLL health lost" }
  if {$role eq "MASTER" && (!(($st>>4)&1) || ($es&0xc)!=0xc)} { error "Master local validity lost" }
  # Tcl %X may narrow to32 bits even with width16; retain both raw halves.
  set st_hex [format %08X%08X [expr {($st>>32)&0xffffffff}] [expr {$st&0xffffffff}]]
  puts "TS4_HEALTH_OK role=$role STATUS=$st_hex ESCR=[format %08X $es] H=[format %08X $h] M=[format %08X $m] P=[format %08X $p] RESET={$sig}"
  flush stdout
}

if {[info exists ::ts4_library_only] && $::ts4_library_only} { return }
set begin [clock milliseconds]; set deadline [expr {$begin+360000}]
set targets {}
foreach name {1-11.1 1-11.2} role {MASTER SLAVE} {
  set matches {}
  foreach hw [get_hardware_names] { if {[string first $name $hw]>=0} { lappend matches $hw } }
  if {[llength $matches]!=1} { error "Missing/ambiguous board $name" }
  set hw [lindex $matches 0]; set devices [get_device_names -hardware_name $hw]
  if {![llength $devices]} { error "Missing target device" }
  lappend targets [list $hw [lindex $devices 0] $role]
}
puts "TS4_CONFIG schema=1 records=16 max_actual_ms=360000 fixed_mode=0 history_continuous=0"
set completed 0; set failure ""
if {[catch {
  foreach target $targets { ts4_health $target }
  set slave [lindex $targets 1]; lassign $slave hw device role
  ts4_select $slave
  set ready 0; set quiet_since -1
  set gate_start [clock milliseconds]
  while {[clock milliseconds]-$gate_start<30000} {
    set now [clock milliseconds]
    if {[stable_shell_ready $hw]} {
      if {$quiet_since<0} { set quiet_since $now }
      if {$now-$quiet_since>=1000} { set ready 1; break }
    } else { set quiet_since -1 }
    after 100
  }
  if {!$ready} { error "Shell not ready/quiet" }
  lassign [drain_preexisting_uart $hw 30000] status hex text
  puts "TS4_PREEXISTING status=$status hex=$hex"
  if {$status ne "OK"} { error "Failed pre-drain" }
  set id ""; set total ""; set first_generation ""; set seen {}
  for {set page 0} {$page<16} {incr page} {
    if {[clock milliseconds]>=$deadline} { error "Actual capture deadline" }
    set start [clock milliseconds]
    if {[send_vuart_command $hw "pll ts4 $page"] ne "OK"} { error "Command delivery failed" }
    set remaining [expr {min(30000,$deadline-[clock milliseconds])}]
    if {$remaining<=0} { error "Actual capture deadline" }
    lassign [capture_vuart_reply $hw $remaining] status hex text
    set end [clock milliseconds]
    puts "TS4_REPLY page=$page start_ms=[expr {$start-$begin}] end_ms=[expr {$end-$begin}] status=$status hex=$hex"
    if {$status ne "OK"} { error "Reply transport failed" }
    lassign [ts4_parse_page $text $page $id $total] id total w
    set generation [list [lindex $w 11] [lindex $w 13] [lrange $w 6 8]]
    if {$page==0} { set first_generation $generation }
    if {$generation ne $first_generation} { error "History changed init/source generation" }
    if {[lsearch -exact $seen [lindex $w 1]]>=0} { error "Duplicate UCNT" }
    lappend seen [lindex $w 1]
    incr completed
    if {$completed==2} { puts "TS4_SMOKE_PASS records=2 snapshot=$id math_verified=1" }
    # Same reader retains frozen history. Bracket live health every four pages.
    if {$completed%4==0} {
      foreach target $targets { ts4_health $target }
      ts4_select $slave
    }
    flush stdout
  }
} failure]} { puts "TS4_STOP reason={$failure} records=$completed" }
catch {end_insystem_source_probe}
puts "TS4_DONE records=$completed elapsed_ms=[expr {[clock milliseconds]-$begin}]"
if {$completed!=16} { error "Incomplete TS4 diagnosis: $failure" }
