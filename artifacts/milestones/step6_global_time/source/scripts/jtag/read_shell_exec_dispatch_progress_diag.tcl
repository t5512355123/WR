# Firmware-only shell_exec() dispatch progress diagnostic (read-only).
#
# Usage:
#   quartus_stp -t read_shell_exec_dispatch_progress_diag.tcl ?samples? ?gap_ms? ?filter?
#
# The existing WDIAG_PTPSTAT low byte remains the PPSI PTP state. While this
# diagnostic is active, its high bits carry a shell dispatch bitmap:
#   progress bit 0  SHELL_EXEC_ENTER
#   progress bit 1  TOKENIZE_DONE
#   progress bit 2  COMMAND_NAME_PARSED
#   progress bit 3  COMMAND_LOOKUP_BEGIN
#   progress bit 4  COMMAND_LOOKUP_MATCH_INDEX valid
#   progress bit 5  COMMAND_HANDLER_FOUND
#   progress bit 6  BEFORE_HANDLER_CALL
#   progress bit 7  AFTER_HANDLER_RETURN
#   progress bits 8..13 COMMAND_LOOKUP_MATCH_INDEX (6-bit command-table index)

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

proc read_dispatch_sample {hardware_name sample start_ms} {
  set raw [wb_read $hardware_name 0x00100A10]
  set word [word32 $raw]
  set elapsed [expr {[clock milliseconds] - $start_ms}]
  if {$word < 0} {
    puts [format "SHELL_EXEC_DIAG_SAMPLE board=%s sample=%03d elapsed_ms=%d RAW=%s PTP_STATE=INVALID SHELL_EXEC_ENTER=INVALID TOKENIZE_DONE=INVALID COMMAND_NAME_PARSED=INVALID COMMAND_LOOKUP_BEGIN=INVALID COMMAND_LOOKUP_MATCH_INDEX=INVALID COMMAND_HANDLER_FOUND=INVALID BEFORE_HANDLER_CALL=INVALID AFTER_HANDLER_RETURN=INVALID" \
      $hardware_name $sample $elapsed [display32 $raw]]
  } else {
    set progress [expr {($word >> 8) & 0xffff}]
    set ptp_state [expr {$word & 0xff}]
    set match_index [expr {($progress >> 8) & 0x3f}]
    puts [format "SHELL_EXEC_DIAG_SAMPLE board=%s sample=%03d elapsed_ms=%d RAW=%s PTP_STATE=%d SHELL_EXEC_ENTER=%d TOKENIZE_DONE=%d COMMAND_NAME_PARSED=%d COMMAND_LOOKUP_BEGIN=%d COMMAND_LOOKUP_MATCH_INDEX_VALID=%d COMMAND_LOOKUP_MATCH_INDEX=%d COMMAND_HANDLER_FOUND=%d BEFORE_HANDLER_CALL=%d AFTER_HANDLER_RETURN=%d" \
      $hardware_name $sample $elapsed [display32 $raw] $ptp_state \
      [expr {$progress & 1}] [expr {($progress >> 1) & 1}] \
      [expr {($progress >> 2) & 1}] [expr {($progress >> 3) & 1}] \
      [expr {($progress >> 4) & 1}] $match_index \
      [expr {($progress >> 5) & 1}] [expr {($progress >> 6) & 1}] \
      [expr {($progress >> 7) & 1}]]
  }
  flush stdout
}

puts [format "SHELL_EXEC_DIAG_CONFIG samples=%d gap_ms=%d filter=%s" \
  $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== SHELL_EXEC_DIAG_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_dispatch_sample $hardware_name $sample $start_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
  } error_message]} {
    puts [format "SHELL_EXEC_DIAG_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "SHELL_EXEC_DIAG_DONE"
