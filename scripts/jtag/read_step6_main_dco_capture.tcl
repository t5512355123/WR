# Debug capture only; source72 toggles observation, never PLL/control. No VUART.
set saved_args $argv; set argv {}; set ::ts4_library_only 1
source [file join [file dirname [info script]] read_step6_four_timestamp_diagnostic.tcl]
unset ::ts4_library_only; set argv $saved_args
if {[llength $argv]} { error "No options: one bounded60-sample diagnostic" }
proc dco_raw {instance} {
  set raw [probe_word $instance]
  if {![regexp {^[0-9a-fA-F]{1,16}$} $raw]} { error "Invalid probe$instance" }
  return [string toupper [string repeat 0 [expr {16-[string length $raw]}]]$raw]
}
proc dco_require_image {hw device} {
  # ts4_health leaves its last board session open. Quartus instance discovery
  # opens its own session, so close ours first; never run two JTAG sessions.
  end_insystem_source_probe
  set instances [get_insystem_source_probe_instance_info -hardware_name $hw -device_name $device]
  # Actual Quartus17 inventory has four-character IDs, not the full HDL string:
  # {72 1 64 A_V1} {73 1 64 N_V1} {74 1 64 S_V1}. Check exact unique tuples;
  # dco_capture additionally checks payload schema/init/ACK and sequence.
  foreach expected {{72 1 64 A_V1} {73 1 64 N_V1} {74 1 64 S_V1}} {
    set matches {}
    foreach item $instances {
      if {[lindex $item 0]==[lindex $expected 0]} {lappend matches $item}
    }
    if {[llength $matches]!=1 || [lindex $matches 0] ne $expected} {
      error "Wrong image: instance contract $expected"
    }
  }
  return $instances
}
proc dco_capture {} {
  set old [word64 [dco_raw 72]]
  set toggle [expr {($old&1)^1}]; set seq [expr {((($old>>1)&0xffff)+1)&0xffff}]
  write_source_data -instance_index 72 -value $toggle -value_in_hex
  set deadline [expr {[clock milliseconds]+400}]; set ready 0
  while {[clock milliseconds]<$deadline} {
    set a [dco_raw 72]; set n [word64 $a]
    if {($n&1)==$toggle && (($n>>1)&0xffff)==$seq} {set ready 1; break}
    after 5
  }
  if {!$ready} { error "Capture ACK/sequence timeout" }
  if {(($n>>29)&7)!=1 || !(($n>>17)&1) || (($n>>21)&7)} {
    error "Capture schema/init/ACK-error/DCO-error/timeout failure"
  }
  set p [dco_raw 73]; set c [dco_raw 74]; set b [dco_raw 72]
  if {$a ne $b} { error "Capture changed/second observer" }
  return [list $a $p $c $b]
}
proc dco_guarded_group {hw addresses} {
  set deadline [expr {[clock milliseconds]+600}]
  while {[clock milliseconds]<$deadline} {
    set e0 [wb_read $hw 0x00100B34]; set c0 [wb_read $hw 0x00100A04]
    set payload {}
    foreach address $addresses {lappend payload [wb_read $hw $address]}
    set e1 [wb_read $hw 0x00100B34]; set c1 [wb_read $hw 0x00100A04]
    set good 1
    foreach raw [concat [list $e0 $c0 $e1 $c1] $payload] {
      if {![is_hex $raw]} {set good 0}
    }
    if {$good && ([word32 $c0]&1) && ([word32 $c1]&1) &&
        (([word32 $e0]^[word32 $e1])&0xffff)==0} {
      return [concat [list $e0 $c0] $payload [list $e1 $c1]]
    }
  }
  error "No fresh coherent diagnostic group within600ms"
}
proc dco_frame {hw} {
  # Same seven-read publication frame as the established strict reader.
  return [dco_guarded_group $hw {0x00100A48 0x00100A40 0x00100A08}]
}
proc dco_lock_frame {hw} {
  set values [dco_guarded_group $hw {0x00100ABC 0x00100AC4 0x00100A0C}]
  lassign $values e0 c0 h m p e1 c1
  if {!([word32 $h]&1) || ([word32 $m]&0xe)!=0xe || !([word32 $p]&2)} {
    error "Slave lock loss"
  }
  return $values
}
if {[info exists ::dco_capture_library_only] && $::dco_capture_library_only} {return}
set begin [clock milliseconds]; set deadline [expr {$begin+120000}]; set targets {}
foreach name {1-11.1 1-11.2} role {MASTER SLAVE} {
  set found {}; foreach hw [get_hardware_names] {if {[string first $name $hw]>=0} {lappend found $hw}}
  if {[llength $found]!=1} {error "Missing/ambiguous target"}
  set hw [lindex $found 0]; set devices [get_device_names -hardware_name $hw]
  if {![llength $devices]} {error "Missing device"}
  lappend targets [list $hw [lindex $devices 0] $role]
}
puts "MAIN_DCO_CONFIG schema=2 samples=60 max_actual_ms=120000 control_changed=0 applied_position_is_virtual=1 cross_group_atomic=0"
set completed 0
if {[catch {
  foreach target $targets {ts4_health $target}
  set slave [lindex $targets 1]; lassign $slave hw device role
  set instances [dco_require_image $hw $device]
  puts "MAIN_DCO_INSTANCES {$instances}"; ts4_select $slave
  for {set n 0} {$n<60} {incr n} {
    set start [clock milliseconds]; if {$start>=$deadline} {error "Actual deadline"}
    lassign [dco_capture] a pos cnt b; set capture_end [clock milliseconds]
    puts "MAIN_DCO_CAPTURE_RAW n=$n start_ms=[expr {$start-$begin}] capture_end_ms=[expr {$capture_end-$begin}] META0=$a POSITION=$pos COUNTS=$cnt META1=$b"
    flush stdout
    set wr_start [clock milliseconds]
    lassign [dco_frame $hw] e0 c0 u k s e1 c1
    set wr_end [clock milliseconds]; set lock_start [clock milliseconds]
    lassign [dco_lock_frame $hw] le0 lc0 h m p le1 lc1
    set lock_end [clock milliseconds]
    set l2 [dco_raw 52]; set failed [dco_raw 56]; set wait [dco_raw 57]
    set current_wait [dco_raw 58]; set latency [dco_raw 59]; set failure [dco_raw 60]
    if {([word64 $l2]&0xf0)!=0 || [word64 $failed]!=0 || [word64 $failure]!=0} {
      error "L2 ACK/timeout/first-loss/DCO-error/failure evidence"
    }
    set end [clock milliseconds]
    puts "MAIN_DCO_SAMPLE n=$n start_ms=[expr {$start-$begin}] capture_end_ms=[expr {$capture_end-$begin}] wr_start_ms=[expr {$wr_start-$begin}] wr_end_ms=[expr {$wr_end-$begin}] lock_start_ms=[expr {$lock_start-$begin}] lock_end_ms=[expr {$lock_end-$begin}] end_ms=[expr {$end-$begin}] META0=$a POSITION=$pos COUNTS=$cnt META1=$b E0=$e0 C0=$c0 UCNT=$u CKO=$k SSTAT=$s E1=$e1 C1=$c1 LE0=$le0 LC0=$lc0 H=$h M=$m P=$p LE1=$le1 LC1=$lc1 L2=$l2 FAILED=$failed WAIT=$wait CURRENT_WAIT=$current_wait LATENCY=$latency FAILURE=$failure"
    incr completed; if {$completed==3} {puts "MAIN_DCO_SMOKE_PASS samples=3"}
    if {$completed%10==0} {foreach target $targets {ts4_health $target}; ts4_select $slave}
    flush stdout
    set remaining [expr {min(1000-($end-$start),$deadline-[clock milliseconds])}]
    if {$remaining>0 && $n<59} {after $remaining}
  }
  foreach target $targets {ts4_health $target}
} failure]} {puts "MAIN_DCO_STOP samples=$completed reason={$failure}"}
catch {end_insystem_source_probe}
puts "MAIN_DCO_DONE samples=$completed elapsed_ms=[expr {[clock milliseconds]-$begin}]"
if {$completed!=60} {error "Incomplete Main DCO diagnostic: $failure"}
