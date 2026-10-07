# Firmware-only audit of build_init_readcmd() static-p lifetime.
#
# Usage:
#   quartus_stp -t read_boot_init_static_p_preboot_caller_audit.tcl ?samples? ?gap_ms? ?filter?
#
# The firmware keeps a global build_init_readcmd() call count that is never
# reset at shell_boot_script() entry. It also snapshots the last caller seen
# before boot (NONE, BOOT_SCRIPT, SHOW_BUILD_INIT, or OTHER). PSTAT/ASTAT keep
# the first boot-script call state and the snapshot in their high bits.

package require ::quartus::insystem_source_probe

set samples 12
set gap_ms 1000
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

proc caller_name {value} {
  switch -- $value {
    0 { return NONE }
    1 { return BOOT_SCRIPT }
    2 { return SHOW_BUILD_INIT }
    3 { return OTHER }
    default { return INVALID }
  }
}

proc read_static_p_audit_sample {hardware_name sample start_ms} {
  set pstat_raw [wb_read $hardware_name 0x00100A0C]
  set astat_raw [wb_read $hardware_name 0x00100A14]
  set ptp_raw [wb_read $hardware_name 0x00100A10]
  set pstat [word32 $pstat_raw]
  set astat [word32 $astat_raw]
  set ptp [word32 $ptp_raw]
  set elapsed [expr {[clock milliseconds] - $start_ms}]
  if {$pstat < 0 || $astat < 0 || $ptp < 0} {
    puts [format "BOOT_INIT_STATIC_P_AUDIT_SAMPLE board=%s sample=%03d elapsed_ms=%d PSTAT=%s ASTAT=%s PTPSTAT=%s TRACE=INVALID" \
      $hardware_name $sample $elapsed [display32 $pstat_raw] [display32 $astat_raw] [display32 $ptp_raw]]
  } else {
    set flags [expr {($astat >> 24) & 0xff}]
    set caller_id [expr {($flags >> 6) & 0x3}]
    puts [format "BOOT_INIT_STATIC_P_AUDIT_SAMPLE board=%s sample=%03d elapsed_ms=%d PSTAT=%s ASTAT=%s PTPSTAT=%s PTP_STATE=%d LINK=%d LOCKED=%d GLOBAL_BUILD_INIT_CALL_COUNT=%d PREBOOT_LAST_CALLER_ID=%d PREBOOT_LAST_CALLER=%s CALL1_P_OFFSET_BEFORE=%d CALL1_RETURN_P_OFFSET_STICKY=%d CALL1_CMD_LEN=%d CALL1_I_VALUE=%d CALL1_CURRENT_CHAR_AFTER=%d CALL1_DELIMITER_SEEN=%d CALL1_RESET_TRIGGERED=%d CALL1_END_OF_STRING_SEEN=%d CALL1_BEFORE_VALID=%d CALL1_AFTER_VALID=%d TRACE_VALID=%d" \
      $hardware_name $sample $elapsed [display32 $pstat_raw] [display32 $astat_raw] [display32 $ptp_raw] \
      [expr {$ptp & 0xff}] [expr {$pstat & 1}] [expr {($pstat >> 1) & 1}] \
      [expr {($pstat >> 26) & 0x3f}] $caller_id [caller_name $caller_id] \
      [expr {($pstat >> 2) & 0xff}] [expr {($pstat >> 10) & 0xff}] \
      [expr {($pstat >> 18) & 0xff}] [expr {($astat >> 8) & 0xff}] \
      [expr {($astat >> 16) & 0xff}] [expr {$flags & 1}] \
      [expr {($flags >> 1) & 1}] [expr {($flags >> 2) & 1}] \
      [expr {($flags >> 3) & 1}] [expr {($flags >> 4) & 1}] \
      [expr {($flags >> 5) & 1}]]
  }
  flush stdout
}

puts [format "BOOT_INIT_STATIC_P_AUDIT_CONFIG samples=%d gap_ms=%d filter=%s" \
  $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== BOOT_INIT_STATIC_P_AUDIT_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_static_p_audit_sample $hardware_name $sample $start_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
  } error_message]} {
    puts [format "BOOT_INIT_STATIC_P_AUDIT_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "BOOT_INIT_STATIC_P_AUDIT_DONE"
