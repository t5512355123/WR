# B image boot role/state transition timeline (read-only).
#
# Usage:
#   quartus_stp -t read_boot_role_timeline.tcl ?samples? ?gap_ms? ?filter?
#
# The script reads one fixed set of status and Wishbone fields for every
# sample. It does not write a Wishbone register, request DATA_SNAPSHOT, or
# alter WR/SoftPLL control. A filter such as 1-11.1 selects one cable.

package require ::quartus::insystem_source_probe

set samples 120
set gap_ms 100
set board_filter ""
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

array set ::wb_toggle {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]+$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc display32 {value} {
  set word [word32 $value]
  if {$word < 0} { return $value }
  return [format %08X $word]
}

proc bit32 {value bit} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc field32 {value lsb width} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($word >> $lsb) & $mask}]
}

proc ptp_state_name {state} {
  switch -- $state {
    1 { return INITIALIZING }
    2 { return FAULTY }
    3 { return DISABLED }
    4 { return LISTENING }
    5 { return PASSIVE }
    6 { return MASTER }
    7 { return PASSIVE }
    8 { return UNCALIBRATED }
    9 { return SLAVE }
  }
  return UNKNOWN
}

proc mode_name {mode} {
  switch -- $mode {
    2 { return MASTER }
    3 { return SLAVE }
  }
  return UNKNOWN
}

proc mac_from_registers {mach macl} {
  set hi [word32 $mach]
  set lo [word32 $macl]
  if {$hi < 0 || $lo < 0} { return INVALID }
  set mid [expr {$hi & 0xffff}]
  return [format "%02X:%02X:%02X:%02X:%02X:%02X" \
    [expr {($mid >> 8) & 0xff}] [expr {$mid & 0xff}] \
    [expr {($lo >> 24) & 0xff}] [expr {($lo >> 16) & 0xff}] \
    [expr {($lo >> 8) & 0xff}] [expr {$lo & 0xff}]]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc wb_read {hardware_name addr} {
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 5
  for {set n 0} {$n < 100} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value TIMEOUT
    }
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} {
        return [format %08X [expr {$word & 0xffffffff}]]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc wb_sync_toggle {hardware_name} {
  set value [probe_read 1]
  if {[is_hex $value]} {
    scan $value %x word
    set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc selected_board {hardware_name} {
  if {$::board_filter eq ""} { return 1 }
  return [expr {[string first $::board_filter $hardware_name] >= 0}]
}

proc read_timeline_sample {hardware_name sample start_ms} {
  set status [probe_read 0]
  set marker [probe_read 3]
  set ep_mach [wb_read $hardware_name 0x00100124]
  set ep_macl [wb_read $hardware_name 0x00100128]
  set ptp [wb_read $hardware_name 0x00100A10]
  set ptp_rx [wb_read $hardware_name 0x00100A54]
  set ptp_tx [wb_read $hardware_name 0x00100A58]
  set ptp_meta [wb_read $hardware_name 0x00100A5C]
  set foreign_meta [wb_read $hardware_name 0x00100A78]
  set parse_meta [wb_read $hardware_name 0x00100A80]
  set lock_enable [wb_read $hardware_name 0x00100A9C]
  set pstat [wb_read $hardware_name 0x00100A0C]

  set status_word [word32 $status]
  if {$status_word < 0} {
    set cpu_reset INVALID
  } else {
    set cpu_reset [expr {($status_word >> 15) & 1}]
  }
  set mode [field32 $ptp_meta 24 8]
  set state [field32 $ptp_meta 0 8]
  set foreign_count [field32 $foreign_meta 0 8]
  set foreign_best [field32 $foreign_meta 8 8]
  set detection [field32 $foreign_meta 16 8]
  set wr_config [field32 $foreign_meta 24 8]
  set parent_is_wr [bit32 $parse_meta 24]
  set parent_mode_on [bit32 $parse_meta 25]
  set parent_cal [bit32 $parse_meta 26]
  set elapsed [expr {[clock milliseconds] - $start_ms}]

  puts [format "TIMELINE_SAMPLE board=%s sample=%03d elapsed_ms=%d STATUS=%s CPU_RESET_N=%s MARKER=%s MAC=%s MODE=%s(%s) PTP=%s(%s) PTP_RX=%s PTP_TX=%s FOREIGN=%s BEST=%s DETECTION=%s WR_CONFIG=%s PARENT_IS_WR=%s PARENT_MODE_ON=%s PARENT_CAL=%s LOCK_ENABLE=%s PSTAT=%s" \
    $hardware_name $sample $elapsed [display32 $status] $cpu_reset \
    [display32 $marker] [mac_from_registers $ep_mach $ep_macl] \
    [expr {$mode < 0 ? "INVALID" : $mode}] [mode_name $mode] \
    [expr {$state < 0 ? "INVALID" : $state}] [ptp_state_name $state] \
    [display32 $ptp_rx] [display32 $ptp_tx] \
    [expr {$foreign_count < 0 ? "INVALID" : $foreign_count}] \
    [expr {$foreign_best < 0 ? "INVALID" : $foreign_best}] \
    [expr {$detection < 0 ? "INVALID" : $detection}] \
    [expr {$wr_config < 0 ? "INVALID" : $wr_config}] \
    $parent_is_wr $parent_mode_on $parent_cal [display32 $lock_enable] \
    [display32 $pstat]]
  flush stdout
}

puts [format "BOOT_ROLE_TIMELINE_CONFIG samples=%d gap_ms=%d filter=%s" \
  $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== BOOT_ROLE_TIMELINE_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_timeline_sample $hardware_name $sample $start_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
  } error_message]} {
    puts [format "BOOT_ROLE_TIMELINE_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "BOOT_ROLE_TIMELINE_DONE"
