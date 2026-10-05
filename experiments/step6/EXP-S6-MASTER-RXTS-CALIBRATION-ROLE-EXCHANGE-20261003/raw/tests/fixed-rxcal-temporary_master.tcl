package provide ::quartus::insystem_source_probe 1.0
set argv {};set ::rxcal_library_only 1
source {/home/b10504072/04_WR/scripts/jtag/run_step6_master_rxts_role_calibration.tcl}
unset ::rxcal_library_only
rename puts real_puts
proc puts {args} {lappend ::output [lindex $args end];return ""}
rename clock real_clock
proc clock {what} {if {$what eq "milliseconds"} {incr ::now 5;return $::now};return [real_clock $what]}
proc after {ms} {incr ::now $ms}
proc flush {args} {}
set ::now 0;set ::events {};set ::output {};set ::selected "";set ::scans 0
set ::mode(M) 2;set ::mode(S) 3;set ::role(M) master;set ::role(S) slave
set ::case temporary_master
proc start_insystem_source_probe {args} {set ::selected [lindex $args 1]}
proc end_insystem_source_probe {} {}
proc wb_sync_toggle {hw} {}
proc probe_word {idx} {
  if {$::case eq "reset" && [llength $::events]>4 && $idx==26} {return 0000000200000000}
  switch $idx {0 {return 00000001000080df} 26 {return 0000000100000000} 27 {return 0000000000000000}}
  return INVALID
}
proc wb_read {hw addr} {
  if {$::case eq "transport" && [llength $::events]>4} {return INVALID}
  switch $addr {
    0x00100ABC {return 00000001}
    0x00100AC4 {if {($::case eq "no_lock" && $hw eq "M") || ($::case eq "preflight_lock" && $hw eq "S")} {return 00000006};return 0000000e}
    0x00100A0C {return 00000002}
    0x00100AA0 {if {$::case eq "temporary_master" && $hw eq "S" && $::mode(S)==2} {return 00030005};return [format %08x [expr {$::mode($hw)<<16}]]}
    0x00100A98 {return 00000000}
  };return INVALID
}
proc drain_preexisting_uart {hw timeout} {if {$timeout<=0} {error "Bad budget"};return [list OK "" ""]}
proc send_vuart_command {hw command} {
  lappend ::events [list $hw $command];set ::key [list $hw $command]
  switch $command {
    {ptp master start} {set ::mode($hw) 2;set ::role($hw) master}
    {ptp slave start} {set ::mode($hw) 3;set ::role($hw) slave}
    ptp - {calibration status} {}
    default {error "Forbidden write"}
  };return OK
}
proc read_uart_available {hw maximum} {
  lassign $::key hw command;set text "wrc# "
  if {$::case eq "command_error" && $hw eq "S" && $command eq "ptp master start"} {
    set text "Lock timeout\nCommand \"ptp\": error -110\nwrc# "
    binary scan $text H* hex;return [list OK $hex $text]
  }
  if {$command eq "ptp"} {
    set role $::role($hw);if {$::case eq "wrong_role"} {set role gm}
    set text "running; e2e $role\nwrc# "
  } elseif {$command eq "calibration status"} {
    if {$::mode(M)==3 && $hw eq "M"} {incr ::scans}
    set done [expr {$::scans>0 || $::case eq "old_scan"}]
    if {$::case eq "missing_scan"} {set done 0}
    if {$done} {set active 7625;set scan 9500;set state 2;set count 5;set r 7600;set f 3650} else {
      set active 2389;set scan 0;set state 0;set count 0;set r 0;set f 0
    }
    if {$::case eq "bad_midpoint" && $done} {set active 7624}
    if {$::case eq "restore_lost" && $::mode(M)==2 && $::scans>0} {set active 2389}
    set text "RXTS_DIAG active_t24p_ps=$active phase_ps=4000 ptracker_ready=1\nRXTS_SCAN phase_ps=$scan rising_state=$state rising_count=$count rising_ps=$r falling_state=$state falling_count=$count falling_ps=$f\nwrc# "
    if {$::case eq "duplicate"} {append text $text}
  }
  binary scan $text H* hex;return [list OK $hex $text]
}
set ::error [catch {rxcal_run {M device MASTER} {S device SLAVE}} ::reason]
if {!$::error} {error "Invalid calibration accepted"}
if {$::role(M) ne "master" || $::role(S) ne "slave"} {error "Failed cal not restored"}
foreach hw {M S} {foreach cmd {{ptp master start} {ptp slave start}} {
          set n 0;foreach e $::events {if {$e eq [list $hw $cmd]} {incr n}};if {$n>1} {error "Control retry"}
        }}
real_puts "ACTUAL_QUARTUS_RXCAL=PASS hardware_session=0 case=temporary_master"
