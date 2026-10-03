# Explicit CONTROL experiment, NOT a read-only dashboard or default programmer.
# Fixed role exchange on SAME gateware; built-in Slave calibrator only. No
# calibration force/setp, PLL gain/sps/DAC command, reset or invented T24P.
set rxcal_saved_args $argv
set argv {}
set ::ts4_library_only 1
source [file join [file dirname [info script]] read_step6_four_timestamp_diagnostic.tcl]
unset ::ts4_library_only
set argv $rxcal_saved_args
if {[llength $argv]} { error "No options: fixed bounded role-calibration experiment" }

proc rxcal_budget {maximum} {
  set left [expr {$::rxcal_deadline-[clock milliseconds]}]
  if {$left<=0} { error "RXCAL actual deadline reached" }
  return [expr {min($left,$maximum)}]
}
proc rxcal_command {target command} {
  if {$command ni {"ptp master start" "ptp slave start" "ptp" "calibration status"}} {
    error "Non-allowlisted control command"
  }
  ts4_select $target
  lassign $target hw device physical_role
  lassign [drain_preexisting_uart $hw [rxcal_budget 30000]] status hex text
  puts "RXCAL_PREDRAIN board={$hw} status=$status hex=$hex"
  if {$status ne "OK"} { error "RXCAL pre-drain failure" }
  rxcal_budget 45000
  if {[send_vuart_command $hw $command] ne "OK"} { error "RXCAL delivery failure; no retry" }
  lassign [capture_vuart_reply $hw [rxcal_budget 45000]] status hex text
  puts "RXCAL_REPLY board={$hw} command={$command} status=$status hex=$hex"
  if {$status ne "OK" || [regexp -nocase {unknown (?:sub)?command|unrecognized command|command failed|Command "[^"]+": error -?[0-9]+} $text]} {
    error "RXCAL incomplete/failed command; no retry"
  }
  return $text
}
proc rxcal_status {text} {
  set a [regexp -all -inline {RXTS_DIAG active_t24p_ps=([0-9]+) phase_ps=(-?[0-9]+) ptracker_ready=([01])} $text]
  set b [regexp -all -inline {RXTS_SCAN phase_ps=([0-9]+) rising_state=([0-9]+) rising_count=([0-9]+) rising_ps=(-?[0-9]+) falling_state=([0-9]+) falling_count=([0-9]+) falling_ps=(-?[0-9]+)} $text]
  if {[llength $a]!=4 || [llength $b]!=8} { error "Missing/duplicate calibration status" }
  set active [lindex $a 1]
  if {$active<0 || $active>=8000} { error "Calibration value out of range" }
  foreach i {2 5} { if {[lindex $b $i]>2} { error "Invalid scan state" } }
  foreach i {3 6} { if {[lindex $b $i]>5} { error "Invalid scan count" } }
  if {[lindex $b 1]>9500 || [lindex $b 1]%100!=0} { error "Invalid scan position" }
  return [dict create active $active ready [lindex $a 3] scan [lindex $b 1] \
    rising_state [lindex $b 2] rising_count [lindex $b 3] rising [lindex $b 4] \
    falling_state [lindex $b 5] falling_count [lindex $b 6] falling [lindex $b 7]]
}
proc rxcal_measured {d} {
  if {[dict get $d rising_state]!=2 || [dict get $d falling_state]!=2 ||
      [dict get $d rising_count]<5 || [dict get $d falling_count]<5 ||
      [dict get $d scan]<9500 || ![dict get $d ready]} { return 0 }
  set r [dict get $d rising]; set f [dict get $d falling]
  if {$r<0 || $r>=8000 || $f<0 || $f>=8000 || $r==$f} {
    error "Invalid completed transition scan"
  }
  # Literal built-in calib_t24p_process() midpoint, not a fitted value.
  if {$f>$r} { incr f -4000 } else { incr f 4000 }
  set sum [expr {$r+$f}]
  # C integer division truncates toward zero (Tcl floors negatives).
  set midpoint [expr {$sum<0 ? -(-$sum/2) : $sum/2}]
  if {$midpoint<0} { incr midpoint 8000 }
  if {$midpoint>=8000} { incr midpoint -8000 }
  if {$midpoint!=[dict get $d active]} { error "Active value not fresh measured midpoint" }
  return 1
}
proc rxcal_health {target} {
  rxcal_budget 10000
  ts4_select $target
  lassign $target hw device physical_role
  set st [word64 [probe_word 0]]
  set en [word64 [probe_word 26]]; set rs [word64 [probe_word 27]]
  set h [word32 [wb_read $hw 0x00100ABC]]
  set m [word32 [wb_read $hw 0x00100AC4]]
  set p [word32 [wb_read $hw 0x00100A0C]]
  set ss [word32 [wb_read $hw 0x00100AA0]]
  set cf [word32 [wb_read $hw 0x00100A98]]
  foreach v [list $st $en $rs $h $m $p $ss $cf] {
    if {$v eq "INVALID"} { error "RXCAL transport failure" }
  }
  set sig [list [expr {($en>>32)&0xffffffff}] [expr {($rs>>16)&0xff}] \
    [expr {($rs>>24)&0xff}] [expr {($rs>>32)&0xff}] [expr {($rs>>40)&0xff}]]
  if {![info exists ::rxcal_reset($hw)]} { set ::rxcal_reset($hw) $sig }
  if {$sig ne $::rxcal_reset($hw)} { error "RXCAL boot/reset changed" }
  foreach bit {0 1 2 3 6 7 15 32} {
    if {!(($st>>$bit)&1)} { error "RXCAL link/clock gate lost" }
  }
  set st_hex [format %08X%08X [expr {($st>>32)&0xffffffff}] [expr {$st&0xffffffff}]]
  puts "RXCAL_HEALTH board={$hw} STATUS=$st_hex H=[format %08X $h] M=[format %08X $m] P=[format %08X $p] SPLL=[format %08X $ss] CALFAIL=$cf RESET={$sig}"
  return [dict create helper [expr {$h&1}] main [expr {($m&14)==14 && ($p&2)!=0}] \
    mode [expr {($ss>>16)&255}] calfail $cf]
}
proc rxcal_role {target role} {
  if {$role ni {master slave}} { error "Invalid fixed role" }
  rxcal_command $target "ptp $role start"
  set text [rxcal_command $target "ptp"]
  if {[regexp -all "running; e2e ${role}(?:\\r|\\n)" $text]!=1} {
    error "Runtime PTP role not confirmed"
  }
  puts "RXCAL_ROLE board={[lindex $target 0]} role=$role verified=1"
}
proc rxcal_run {master slave} {
  set begin [clock milliseconds]
  # Reserve120s of the hard600s bound for one role-restoration attempt.
  set ::rxcal_deadline [expr {$begin+480000}]
  set changed 0; set measurement ""; set failure ""; set restore_failure ""
  puts "RXCAL_CONFIG control=role_exchange calibrator=builtin same_gateware=1 calibration_wait_ms=240000 max_actual_ms=600000 parameters_changed=0"
  set rc [catch {
    set hm [rxcal_health $master]; set hs [rxcal_health $slave]
    if {[dict get $hm mode]!=2 || ![dict get $hm helper] || [dict get $hm calfail]!=0 ||
        [dict get $hs mode]!=3 || ![dict get $hs helper] || ![dict get $hs main]} {
      error "Original role/lock preflight not established"
    }
    set prior [rxcal_status [rxcal_command $master "calibration status"]]
    if {[dict get $prior rising_state]!=0 || [dict get $prior falling_state]!=0} {
      error "Master scan not fresh boot; do not overwrite prior experiment"
    }
    # Mark before first write so partial command delivery still enters restore.
    set changed 1
    rxcal_role $slave master
    set h [rxcal_health $slave]
    if {[dict get $h mode]!=2 || ![dict get $h helper]} { error "Temporary Master not locked" }
    rxcal_role $master slave
    set started [clock milliseconds]; set good 0; set previous ""
    set ::rxcal_deadline [expr {min($begin+480000,$started+240000)}]
    while {[clock milliseconds]-$started<240000 && [clock milliseconds]-$begin<480000} {
      set hm [rxcal_health $master]; set hs [rxcal_health $slave]
      if {[dict get $hm calfail]!=0 || [dict get $hs mode]!=2 || ![dict get $hs helper]} {
        error "Calibration failed or temporary Master lost"
      }
      set d [rxcal_status [rxcal_command $master "calibration status"]]
      rxcal_budget 1
      puts "RXCAL_SCAN elapsed_ms=[expr {[clock milliseconds]-$begin}] data={$d}"
      if {[dict get $hm mode]==3 && [dict get $hm helper] && [dict get $hm main] && [rxcal_measured $d]} {
        if {$previous eq $d} { incr good } else { set good 1 }
        set previous $d
        if {$good>=2} { set measurement $d; break }
      } else { set good 0; set previous "" }
      after 1000
    }
    if {$measurement eq ""} { error "No qualified actual calibration in240s" }
    puts "RXCAL_MEASUREMENT active_t24p_ps=[dict get $measurement active] scan={$measurement}"
  } reason]
  if {$rc} { set failure $reason; puts "RXCAL_FAILURE reason={$failure}" }
  # One explicit restoration attempt per board, even after bounded cal failure.
  # Health guard must still establish trusted transport/reset before writes.
  if {$changed} {
    set ::rxcal_deadline [expr {$begin+600000}]
    # Attempt each board once even if the other role's query is unconfirmed.
    # A fresh trusted health check precedes EACH write; no blind transport retry.
    foreach target [list $master $slave] role {master slave} {
      if {[catch {
        rxcal_health $master; rxcal_health $slave
        rxcal_role $target $role
      } reason]} {
        append restore_failure " $reason;"
        puts "RXCAL_RESTORE_FAILURE board={[lindex $target 0]} reason={$reason}"
      }
    }
    if {[catch {
      set d [rxcal_status [rxcal_command $master "calibration status"]]
      if {$measurement ne "" && [dict get $d active]!=[dict get $measurement active]} {
        error "Measured calibration lost on role restore"
      }
      if {$restore_failure eq ""} {
        puts "RXCAL_RESTORE roles_verified=1 active_t24p_ps=[dict get $d active]"
      }
    } reason]} {
      append restore_failure " $reason;"
      puts "RXCAL_RESTORE_FAILURE reason={$reason}"
    }
  }
  set elapsed [expr {[clock milliseconds]-$begin}]
  puts "RXCAL_DONE measured=[expr {$measurement ne ""}] restored=[expr {$changed && $restore_failure eq ""}] elapsed_ms=$elapsed goal_pass=0"
  if {$failure ne "" || $restore_failure ne "" || $measurement eq "" || $elapsed>600000} {
    error "Role calibration not qualified: $failure; restore=$restore_failure"
  }
}
if {[info exists ::rxcal_library_only] && $::rxcal_library_only} { return }
set targets {}
foreach name {1-11.1 1-11.2} role {MASTER SLAVE} {
  set found {}
  foreach hw [get_hardware_names] { if {[string first $name $hw]>=0} { lappend found $hw } }
  if {[llength $found]!=1} { error "Ambiguous/missing board $name" }
  set hw [lindex $found 0]; set devices [get_device_names -hardware_name $hw]
  if {[llength $devices]!=1} { error "Ambiguous/missing FPGA $name" }
  lappend targets [list $hw [lindex $devices 0] $role]
}
set rc [catch {rxcal_run {*}$targets} reason]
catch {end_insystem_source_probe}
if {$rc} { error $reason }
