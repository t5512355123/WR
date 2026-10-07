# Read-only RX-error source attribution for the Slave JTAG image.
#
# Usage:
#   quartus_stp -t read_rx_error_attribution.tcl quiet 300
#   quartus_stp -t read_rx_error_attribution.tcl dashboard 300
#
# The quiet phase performs no periodic JTAG reads.  The dashboard phase
# applies the normal read-only Wishbone/JTAG observation load every five
# seconds.  Neither phase writes a control register.

package require ::quartus::insystem_source_probe

set ::wb_toggle 0
set ::max_read_attempts 5
set ::phase [lindex $argv 0]
set ::duration_seconds [lindex $argv 1]

if {$::phase ne "quiet" && $::phase ne "dashboard"} {
  puts "USAGE: read_rx_error_attribution.tcl quiet|dashboard duration_seconds"
  exit 2
}
if {![string is integer -strict $::duration_seconds] ||
    $::duration_seconds <= 0} {
  puts "duration_seconds must be a positive integer"
  exit 2
}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]+$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 8} {
    set text [string range $text end-7 end]
  }
  scan $text %x word
  return [expr {$word & 0xffffffff}]
}

proc probe_low32 {value} {
  return [word32 $value]
}

proc probe_high32 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  set text [string repeat 0 [expr {16 - [string length $text]}]]$text
  scan [string range $text 0 7] %x word
  return [expr {$word & 0xffffffff}]
}

proc bit64_low {value bit} {
  set word [probe_low32 $value]
  if {$word < 0 || $bit < 0 || $bit > 31} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc bit64_high {value bit} {
  set word [probe_high32 $value]
  if {$word < 0 || $bit < 0 || $bit > 31} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc safe_probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return "TIMEOUT"
  }
  if {![is_hex $value]} { return "INVALID" }
  return $value
}

proc wb_read {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set cmd [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return "TIMEOUT"
  }
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [safe_probe_read 1]
    set word [probe_low32 $value]
    set done_toggle [bit64_high $value 3]
    set active [bit64_high $value 4]
    if {$word >= 0 && $done_toggle == $::wb_toggle && $active == 0} {
      return [format %08X $word]
    }
    after 1
  }
  return "TIMEOUT"
}

proc wb_sync_toggle {} {
  set value [safe_probe_read 1]
  set current_done [bit64_high $value 3]
  if {$current_done < 0} { set current_done 0 }
  set ::wb_toggle $current_done
}

proc read_counter {addr} {
  set first [wb_read $addr]
  set second [wb_read $addr]
  if {[word32 $first] < 0 || [word32 $second] < 0} {
    return "INVALID"
  }
  return [format %08X [word32 $second]]
}

proc delta32 {before after} {
  set b [word32 $before]
  set a [word32 $after]
  if {$b < 0 || $a < 0} { return "INVALID" }
  if {$a < $b} { return "DECREASED" }
  return [expr {$a - $b}]
}

proc display32 {value} {
  set word [word32 $value]
  if {$word < 0} { return $value }
  return [format "0x%08X" $word]
}

proc state_name {state} {
  switch -- $state {
    8 { return "UNCALIBRATED" }
    9 { return "SLAVE" }
  }
  return "OTHER"
}

proc sync_snapshot {} {
  set value [safe_probe_read 0]
  return [list $value \
    [bit64_low $value 3] \
    [bit64_low $value 2]]
}

proc attribution_snapshot {label} {
  set p0 [safe_probe_read 45]
  set p1 [safe_probe_read 46]
  set p2 [safe_probe_read 47]
  set p3 [safe_probe_read 48]
  set rxerr [read_counter 0x00100A60]
  set ptp [read_counter 0x00100A10]
  set sync [sync_snapshot]
  set sync_raw [lindex $sync 0]
  set link_ok [lindex $sync 1]
  set tm_link_up [lindex $sync 2]

  set enc [probe_low32 $p0]
  set disperr [probe_high32 $p0]
  set errdetect [probe_low32 $p1]
  set sync_loss [probe_high32 $p1]
  set lock_loss [probe_low32 $p2]
  set link_drop [probe_high32 $p2]
  set tm_link_drop [probe_low32 $p3]

  puts [format "ATTR_SNAPSHOT phase=%s label=%s ptp=%s ptp_name=%s core_link_ok=%d core_tm_link_up=%d sync_raw=%s minic_rxerr=%s phy_enc=%s phy_disperr=%s phy_errdetect=%s phy_sync_loss=%s phy_lock_loss=%s core_link_drop=%s core_tm_link_drop=%s" \
    $::phase $label [display32 $ptp] \
    [state_name [expr {[word32 $ptp] & 0xff}]] \
    $link_ok $tm_link_up $sync_raw [display32 $rxerr] \
    [display32 $enc] [display32 $disperr] [display32 $errdetect] \
    [display32 $sync_loss] [display32 $lock_loss] \
    [display32 $link_drop] [display32 $tm_link_drop]]

  return [dict create \
    rxerr $rxerr \
    phy_enc $enc \
    phy_disperr $disperr \
    phy_errdetect $errdetect \
    phy_sync_loss $sync_loss \
    phy_lock_loss $lock_loss \
    core_link_drop $link_drop \
    core_tm_link_drop $tm_link_drop \
    ptp $ptp \
    link_ok $link_ok \
    tm_link_up $tm_link_up]
}

proc assert_ready {snapshot} {
  set ptp [word32 [dict get $snapshot ptp]]
  set link_ok [dict get $snapshot link_ok]
  set tm_link_up [dict get $snapshot tm_link_up]
  if {$ptp < 0 || ($ptp & 0xff) != 9 ||
      $link_ok != 1 || $tm_link_up != 1} {
    puts [format "ATTR_PRECONDITION=FAIL ptp=%s core_link_ok=%s core_tm_link_up=%s" \
      [display32 [dict get $snapshot ptp]] $link_ok $tm_link_up]
    return 0
  }
  puts "ATTR_PRECONDITION=PASS ptp=SLAVE core_link_ok=1 core_tm_link_up=1"
  return 1
}

proc dashboard_load_once {} {
  # All accesses are read-only.  This is intentionally a compact version of
  # the normal dashboard cadence, used only to test whether observation load
  # correlates with MiniNIC RX errors.
  foreach addr {
    0x00100A10 0x00100A54 0x00100A58 0x00100A60
    0x00100A64 0x00100A68 0x00100A6C 0x00100A4C
    0x00100A0C 0x00100AA4 0x00100AA8
  } {
    wb_read $addr
  }
  safe_probe_read 0
  safe_probe_read 45
  safe_probe_read 46
  safe_probe_read 47
  safe_probe_read 48
}

set ::matched 0
foreach hardware_name [get_hardware_names] {
  if {[string first "1-11.2" $hardware_name] < 0} { continue }
  set ::matched 1
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
  wb_sync_toggle

  puts "ATTRIBUTION_BOARD=$hardware_name"
  set before [attribution_snapshot before]
  if {![assert_ready $before]} {
    catch {end_insystem_source_probe}
    exit 3
  }

  set duration_ms [expr {$::duration_seconds * 1000}]
  if {$::phase eq "quiet"} {
    puts [format "ATTR_PHASE_START=quiet duration_seconds=%d" $::duration_seconds]
    after $duration_ms
  } else {
    puts [format "ATTR_PHASE_START=dashboard duration_seconds=%d cadence_seconds=5" $::duration_seconds]
    for {set elapsed 0} {$elapsed < $duration_ms} {incr elapsed 5000} {
      dashboard_load_once
      after 5000
    }
  }

  set after [attribution_snapshot after]
  puts "ATTR_DELTAS"
  foreach field {rxerr phy_enc phy_disperr phy_errdetect phy_sync_loss \
                 phy_lock_loss core_link_drop core_tm_link_drop} {
    puts [format "  %s_delta=%s" $field \
      [delta32 [dict get $before $field] [dict get $after $field]]]
  }
  puts [format "ATTR_PHASE_RESULT=%s" $::phase]
  puts "ATTRIBUTION_COMPLETE=YES"
  catch {end_insystem_source_probe}
}

if {!$::matched} {
  puts "ATTRIBUTION_BOARD=DE5 [1-11.2] NOT_FOUND"
  exit 4
}
