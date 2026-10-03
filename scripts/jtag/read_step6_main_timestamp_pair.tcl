# Existing passive RAM pages only. TS4 freezes first; the longer PHIST ring
# then overlaps it. One UART: drain page0 before the second freeze (FIFO1024).
set saved_args $argv; set argv {}; set ::phist_library_only 1
source [file join [file dirname [info script]] read_step6_phase_history.tcl]
unset ::phist_library_only; set argv $saved_args
if {[llength $argv]} { error "No options: one immutable paired history" }
proc mtp_reply {hw kind page begin deadline} {
    set start [clock milliseconds]
    if {$start >= $deadline} { error "Actual paired deadline" }
    if {[send_vuart_command $hw "pll [string tolower $kind] $page"] ne "OK"} {
        error "Passive page delivery failed"
    }
    set remain [expr {min(30000,$deadline-[clock milliseconds])}]
    if {$remain<=0} { error "Actual paired deadline" }
    lassign [capture_vuart_reply $hw $remain] status hex text
    set end [clock milliseconds]
    puts "${kind}_REPLY page=$page start_ms=[expr {$start-$begin}] end_ms=[expr {$end-$begin}] status=$status hex=$hex"
    flush stdout
    if {$status ne "OK" || $end>$deadline} { error "Passive page reply/deadline failed" }
    return $text
}
if {[info exists ::mtp_library_only] && $::mtp_library_only} { return }
set begin [clock milliseconds]; set deadline [expr {$begin+480000}]
set targets {}
foreach name {1-11.1 1-11.2} role {MASTER SLAVE} {
    set found {}; foreach hw [get_hardware_names] {
        if {[string first $name $hw]>=0} { lappend found $hw }
    }
    if {[llength $found]!=1} { error "Missing/ambiguous paired board" }
    set hw [lindex $found 0]; set devices [get_device_names -hardware_name $hw]
    if {![llength $devices]} { error "Missing paired device" }
    lappend targets [list $hw [lindex $devices 0] $role]
}
puts "MTP_CONFIG ts4_records=16 phist_records=32 min_joined=12 max_actual_ms=480000 control_changed=0 cycle_atomic=0"
set nt 0; set np 0; set failure ""
if {[catch {
    foreach target $targets { ts4_health $target }
    set slave [lindex $targets 1]; ts4_select $slave
    lassign $slave hw device role
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
    puts "MTP_PREEXISTING status=$status hex=$hex"
    if {$status ne "OK"} { error "Pre-drain failed" }
    set text [mtp_reply $hw TS4 0 $begin $deadline]
    lassign [ts4_parse_page $text 0 "" ""] tid ttotal w
    set tg [list [lindex $w 11] [lindex $w 13] [lrange $w 6 8]]
    set nt 1
    set text [mtp_reply $hw PHIST 0 $begin $deadline]
    lassign [phist_parse $text 0 "" ""] pid ptotal prows
    set pg ""; foreach pw $prows {
        set g [list [lindex $pw 6] [lindex $pw 18] [lindex $pw 27]]
        if {$pg eq ""} { set pg $g }; if {$g ne $pg} { error "Changed Main/tracker generation" }
    }
    set np 2
    # Both totals increment at the same source hook once per accepted WR update.
    # Skew20 leaves at least12 of16 TS4 records in the32-entry PHIST ring.
    set skew [expr {([expr 0x$ptotal]-[expr 0x$ttotal])&0xffffffff}]
    puts "MTP_FREEZE_SKEW ts4_total=$ttotal phist_total=$ptotal updates=$skew"
    if {$skew>20} { error "Snapshots lack required source-proven overlap" }
    puts "MTP_SMOKE_PASS ts4_records=1 phist_records=2 skew_updates=$skew"
    # Never request either page0 again: snapshots stay immutable while read.
    for {set page 1} {$page<16} {incr page} {
        set text [mtp_reply $hw PHIST $page $begin $deadline]
        lassign [phist_parse $text $page $pid $ptotal] pid ptotal prows
        foreach pw $prows {
            if {[list [lindex $pw 6] [lindex $pw 18] [lindex $pw 27]] ne $pg} {
                error "Changed Main/tracker generation"
            }
        }
        incr np 2
        if {$np%8==0} { foreach target $targets { ts4_health $target }; ts4_select $slave }
    }
    for {set page 1} {$page<16} {incr page} {
        set text [mtp_reply $hw TS4 $page $begin $deadline]
        lassign [ts4_parse_page $text $page $tid $ttotal] tid ttotal w
        if {[list [lindex $w 11] [lindex $w 13] [lrange $w 6 8]] ne $tg} {
            error "Changed timestamp/source generation"
        }
        incr nt
        if {$nt%4==0} { foreach target $targets { ts4_health $target }; ts4_select $slave }
    }
    foreach target $targets { ts4_health $target }
} failure]} { puts "MTP_STOP reason={$failure} ts4_records=$nt phist_records=$np" }
catch {end_insystem_source_probe}
set elapsed [expr {[clock milliseconds]-$begin}]
puts "MTP_DONE ts4_records=$nt phist_records=$np elapsed_ms=$elapsed"
if {$failure ne "" || $nt!=16 || $np!=32 || $elapsed>480000} {
    error "Incomplete paired diagnostic: $failure"
}
