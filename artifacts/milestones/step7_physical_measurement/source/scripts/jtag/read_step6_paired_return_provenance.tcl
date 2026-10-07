# One observer, rapid two-board page-zero requests BEFORE draining either reply.
# Existing passive RAM snapshots only. No firmware/control/calibration change.
set argv_saved $argv
set argv {}
set ::ts4_library_only 1
source [file join [file dirname [info script]] read_step6_four_timestamp_diagnostic.tcl]
unset ::ts4_library_only
set ::rxts_library_only 1
source [file join [file dirname [info script]] read_step6_rxts_packet_diagnostic.tcl]
unset ::rxts_library_only
set argv $argv_saved
if {[llength $argv]} { error "No options: one paired immutable snapshot" }

proc pair_s32 {words index} {
  set v [ts4_u32 $words $index]
  if {$v>=0x80000000} { set v [expr {$v-0x100000000}] }
  return $v
}
proc pair_rx_math {line} {
  if {![regexp {^RXTS_V1 idx=([0-9]+) words=(.*)$} $line -> index payload]} { error "Bad RX row" }
  set w [split $payload " "]
  if {[llength $w]!=18} { error "Wrong RX schema" }
  set sec [expr {([ts4_u32 $w 5]<<32)|[ts4_u32 $w 6]}]
  set ns [pair_s32 $w 7]; set phase [pair_s32 $w 8]
  set t24p [pair_s32 $w 9]; set period [ts4_u32 $w 17]
  set flags [ts4_u32 $w 4]
  if {$period!=8000 || $phase<0 || $phase>=8000 || $t24p<0 || $t24p>=8000} {
    error "Invalid RX scale/calibration"
  }
  set pr [expr {$phase-$t24p}]; if {$pr<0} { incr pr 8000 }
  set pf [expr {$phase-$t24p+4000}]
  if {$pf<0} { incr pf 8000 }; if {$pf>=8000} { incr pf -8000 }
  set falling [expr {$pr>6000 || $pr<2000}]
  if {$falling} {
    if {($flags>>17)&1} { incr ns -8 }
    set fine [expr {$pf+4000}]
    if {$fine>=8000} { incr fine -8000; incr ns 8 }
  } else { set fine $pr }
  if {$ns>=1000000000} { incr ns -1000000000; incr sec }
  set actual_sec [expr {([ts4_u32 $w 10]<<32)|[ts4_u32 $w 11]}]
  if {$sec!=$actual_sec || $ns!=[pair_s32 $w 12] || $fine!=[pair_s32 $w 13] ||
      $falling!=(($flags>>18)&1)} { error "RX linearization identity mismatch" }
}
proc pair_prepare {target deadline begin} {
  lassign $target hw device role
  ts4_select $target
  set quiet -1; set ready 0; set start [clock milliseconds]
  while {[clock milliseconds]-$start<30000 && [clock milliseconds]<$deadline} {
    set now [clock milliseconds]
    if {[stable_shell_ready $hw]} {
      if {$quiet<0} { set quiet $now }
      if {$now-$quiet>=1000} { set ready 1; break }
    } else { set quiet -1 }
    after 100
  }
  if {!$ready} { error "Shell not quiet/ready" }
  lassign [drain_preexisting_uart $hw 30000] status hex text
  puts "PAIR_PREEXISTING role=$role status=$status hex=$hex"
  if {$status ne "OK"} { error "Pre-drain failed" }
  if {[send_vuart_command $hw "mac get"] ne "OK"} { error "MAC query failed" }
  lassign [capture_vuart_reply $hw 30000] status hex text
  puts "PAIR_MAC_REPLY role=$role status=$status hex=$hex"
  set macs [regexp -all -inline {MAC-address: ([0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5})} $text]
  if {$status ne "OK" || [llength $macs]!=2} { error "Missing/ambiguous live MAC" }
  set mac [string tolower [lindex $macs 1]]
  set compact [string map {: ""} $mac]
  set id "[string range $compact 0 5]fffe[string range $compact 6 11]"
  set ::pair_clock_id($role) $id
  puts "PAIR_ID role=$role mac=$mac clockid=$id port=1"
  ts4_health $target
}
proc pair_reply {target kind page start begin deadline} {
  lassign $target hw device role
  ts4_select $target
  set remain [expr {min(30000,$deadline-[clock milliseconds])}]
  if {$remain<=0} { error "Paired actual deadline" }
  lassign [capture_vuart_reply $hw $remain] status hex text
  set end [clock milliseconds]
  if {$kind eq "TS4"} {
    puts "TS4_REPLY page=$page start_ms=[expr {$start-$begin}] end_ms=[expr {$end-$begin}] status=$status hex=$hex"
  } else {
    puts "RXTS_REPLY board={$hw} capture=0 page=$page start_ms=[expr {$start-$begin}] end_ms=[expr {$end-$begin}] status=$status hex=$hex"
  }
  if {$status ne "OK"} { error "Paired reply transport failed" }
  return $text
}
proc pair_rx_page {target text page id total} {
  lassign $target hw device role
  lassign [rxts_parse_page $text $page $id $total] id total count rows
  if {$count!=32} { error "Require complete warmed32 RX history" }
  puts "RXTS_CAPTURE_PAGE board={$hw} capture=0 snapshot=$id total=$total page=$page count=$count"
  foreach row $rows {
    pair_rx_math $row
    regexp {words=(.*)$} $row -> payload
    set w [split $payload " "]
    if {[ts4_u32 $w 1]>>24 != 1 || ([ts4_u32 $w 4]&0xffff)!=1 ||
        "[lindex $w 2][lindex $w 3]" ne $::pair_clock_id(SLAVE)} {
      error "Master RX is not live Slave DelayReq/port"
    }
    puts "RXTS_RECORD board={$hw} capture=0 snapshot=$id $row"
  }
  return [list $id $total]
}
proc pair_ts_identity {w} {
  if {([ts4_u32 $w 6]&0xffff)!=1 ||
      "[lindex $w 7][lindex $w 8]" ne $::pair_clock_id(MASTER)} {
    error "Slave TS4 is not from live Master/port"
  }
}

if {[info exists ::pair_library_only] && $::pair_library_only} { return }
set begin [clock milliseconds]; set deadline [expr {$begin+360000}]
set targets {}
foreach name {1-11.1 1-11.2} role {MASTER SLAVE} {
  set found {}
  foreach hw [get_hardware_names] { if {[string first $name $hw]>=0} { lappend found $hw } }
  if {[llength $found]!=1} { error "Ambiguous/missing board $name" }
  set hw [lindex $found 0]; set devices [get_device_names -hardware_name $hw]
  if {![llength $devices]} { error "Missing device $name" }
  lappend targets [list $hw [lindex $devices 0] $role]
}
set master [lindex $targets 0]; set slave [lindex $targets 1]
puts "PAIR_CONFIG max_actual_ms=360000 snapshots=2 commands=passive_pages_and_mac fifo_bytes=1024 cross_board_atomic=0"
set nr 0; set nt 0; set failure ""
if {[catch {
  # Both UARTs must be empty before rapid requests; prep has no snapshot command.
  foreach target $targets { pair_prepare $target $deadline $begin }
  # Page output bounds audited against actual1024-byte FIFOs. Request both
  # snapshots before reading either; exact sequence/time joins, not this host
  # interval, establish overlap. No duplicate page-zero or automatic retry.
  foreach target [list $slave $master] kind {TS4 RXTS} command {"pll ts4 0" "pll rxts 0"} {
    ts4_select $target; lassign $target hw device role
    set prime($kind) [clock milliseconds]
    if {[send_vuart_command $hw $command] ne "OK"} { error "Snapshot request delivery failed" }
    puts "PAIR_FREEZE_REQUEST role=$role kind=$kind start_ms=[expr {$prime($kind)-$begin}] end_ms=[expr {[clock milliseconds]-$begin}]"
  }
  set text [pair_reply $master RXTS 0 $prime(RXTS) $begin $deadline]
  lassign [pair_rx_page $master $text 0 "" ""] rxid rxtotal
  set nr 4
  set text [pair_reply $slave TS4 0 $prime(TS4) $begin $deadline]
  lassign [ts4_parse_page $text 0 "" ""] tsid tstotal w
  pair_ts_identity $w
  set generation [list [lindex $w 11] [lindex $w 13] [lrange $w 6 8]]
  set seen [list [lindex $w 1]]; set nt 1
  puts "PAIR_SMOKE_PASS master_rows=4 slave_rows=1 rx_snapshot=$rxid ts_snapshot=$tsid"
  foreach target $targets { ts4_health $target }
  for {set page 1} {$page<8} {incr page} {
    ts4_select $master; lassign $master hw device role
    set start [clock milliseconds]
    if {$start>=$deadline} { error "Paired actual deadline" }
    if {[send_vuart_command $hw "pll rxts $page"] ne "OK"} { error "RX page delivery failed" }
    set text [pair_reply $master RXTS $page $start $begin $deadline]
    lassign [pair_rx_page $master $text $page $rxid $rxtotal] rxid rxtotal
    incr nr 4
    if {$page%3==0} { foreach target $targets { ts4_health $target } }
    flush stdout
  }
  puts "RXTS_CAPTURE_DONE board={[lindex $master 0]} capture=0 snapshot=$rxid records=$nr"
  for {set page 1} {$page<16} {incr page} {
    ts4_select $slave; lassign $slave hw device role
    set start [clock milliseconds]
    if {$start>=$deadline} { error "Paired actual deadline" }
    if {[send_vuart_command $hw "pll ts4 $page"] ne "OK"} { error "TS4 page delivery failed" }
    set text [pair_reply $slave TS4 $page $start $begin $deadline]
    lassign [ts4_parse_page $text $page $tsid $tstotal] tsid tstotal w
    pair_ts_identity $w
    if {[list [lindex $w 11] [lindex $w 13] [lrange $w 6 8]] ne $generation} { error "Changed TS4 generation" }
    if {[lsearch -exact $seen [lindex $w 1]]>=0} { error "Duplicate TS4 update" }
    lappend seen [lindex $w 1]; incr nt
    if {$nt==2} { puts "TS4_SMOKE_PASS records=2 snapshot=$tsid math_verified=1" }
    if {$nt%4==0} { foreach target $targets { ts4_health $target } }
    flush stdout
  }
  foreach target $targets { ts4_health $target }
} failure]} { puts "PAIR_STOP reason={$failure} master_records=$nr slave_records=$nt" }
catch {end_insystem_source_probe}
set elapsed [expr {[clock milliseconds]-$begin}]
puts "TS4_DONE records=$nt elapsed_ms=$elapsed"
puts "PAIR_DONE master_records=$nr slave_records=$nt elapsed_ms=$elapsed"
if {$nr!=32 || $nt!=16 || $failure ne "" || $elapsed>360000} { error "Paired provenance incomplete: $failure" }
