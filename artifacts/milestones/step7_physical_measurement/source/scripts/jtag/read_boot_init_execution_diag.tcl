# Firmware-only boot-init execution diagnostic (read-only).
#
# Usage:
#   quartus_stp -t read_boot_init_execution_diag.tcl ?samples? ?gap_ms? ?filter?
#
# WDIAG_PTPSTAT bits 0..7 remain the PPSI PTP state. Bits 8..31 expose the
# boot-init evidence written by firmware:
#   8..11   BOOT_INIT_SCRIPT_ENTER_COUNT
#   12..15  BOOT_INIT_COMMAND_INDEX (1-based current/last command)
#   16..23  MODE_MASTER_CALL_COUNT
#   24..31  MODE_MASTER_RETURN_COUNT
#
# This script only reads the existing source probe and Wishbone diagnostics
# area. It does not write a Wishbone register, request a snapshot, or alter
# WR/SoftPLL control.

package require ::quartus::insystem_source_probe

set samples 5
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

proc read_diag_sample {hardware_name sample start_ms} {
  set raw [wb_read $hardware_name 0x00100A10]
  set word [word32 $raw]
  set elapsed [expr {[clock milliseconds] - $start_ms}]
  if {$word < 0} {
    puts [format "BOOT_INIT_DIAG_SAMPLE board=%s sample=%03d elapsed_ms=%d RAW=%s PTP_STATE=INVALID BOOT_INIT_SCRIPT_ENTER_COUNT=INVALID BOOT_INIT_COMMAND_INDEX=INVALID MODE_MASTER_CALL_COUNT=INVALID MODE_MASTER_RETURN_COUNT=INVALID" \
      $hardware_name $sample $elapsed [display32 $raw]]
  } else {
    set ptp_state [expr {$word & 0xff}]
    set enter_count [expr {($word >> 8) & 0xf}]
    set command_index [expr {($word >> 12) & 0xf}]
    set master_call_count [expr {($word >> 16) & 0xff}]
    set master_return_count [expr {($word >> 24) & 0xff}]
    puts [format "BOOT_INIT_DIAG_SAMPLE board=%s sample=%03d elapsed_ms=%d RAW=%s PTP_STATE=%d BOOT_INIT_SCRIPT_ENTER_COUNT=%d BOOT_INIT_COMMAND_INDEX=%d MODE_MASTER_CALL_COUNT=%d MODE_MASTER_RETURN_COUNT=%d" \
      $hardware_name $sample $elapsed [display32 $raw] $ptp_state \
      $enter_count $command_index $master_call_count $master_return_count]
  }
  flush stdout
}

puts [format "BOOT_INIT_DIAG_CONFIG samples=%d gap_ms=%d filter=%s" \
  $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== BOOT_INIT_DIAG_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_diag_sample $hardware_name $sample $start_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
  } error_message]} {
    puts [format "BOOT_INIT_DIAG_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "BOOT_INIT_DIAG_DONE"
