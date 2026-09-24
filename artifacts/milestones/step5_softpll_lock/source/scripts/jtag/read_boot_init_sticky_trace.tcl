# Firmware-only per-command boot-init sticky trace (read-only).
#
# Usage:
#   quartus_stp -t read_boot_init_sticky_trace.tcl ?samples? ?gap_ms? ?filter?
#
# The command trace is carried in the otherwise-unused high bits of
# WDIAGS_PSTAT (0x00100A0C). The existing link/locked bits 0..1 are preserved.
# The command-loop transition trace is carried in ASTAT (0x00100A14) bits
# 8..14; ASTAT bits 0..7 keep the regular auxiliary state. The
# built-in DE5a init sequence is expected to be:
#   1 vlan off; 2 ptp stop; 3 mode master; 4 ptp start
#
# This script reads WDIAGS_PSTAT and WDIAGS_PTPSTAT only. It does not write a
# Wishbone register, request a snapshot, or alter WR/SoftPLL control.

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

proc rc_class_name {value} {
  switch -- $value {
    0 { return NOT_RUN }
    1 { return OK }
    2 { return POSITIVE }
    3 { return NEGATIVE }
    default { return INVALID }
  }
}

proc read_trace_sample {hardware_name sample start_ms} {
  set pstat_raw [wb_read $hardware_name 0x00100A0C]
  set astat_raw [wb_read $hardware_name 0x00100A14]
  set ptp_raw [wb_read $hardware_name 0x00100A10]
  set pstat [word32 $pstat_raw]
  set astat [word32 $astat_raw]
  set ptp [word32 $ptp_raw]
  set elapsed [expr {[clock milliseconds] - $start_ms}]
  if {$pstat < 0 || $astat < 0 || $ptp < 0} {
    puts [format "BOOT_INIT_TRACE_SAMPLE board=%s sample=%03d elapsed_ms=%d PSTAT=%s ASTAT=%s PTPSTAT=%s TRACE=INVALID" \
      $hardware_name $sample $elapsed [display32 $pstat_raw] [display32 $astat_raw] [display32 $ptp_raw]]
  } else {
    set trace [expr {($pstat >> 2) & 0xff}]
    set rc [expr {($pstat >> 18) & 0xff}]
    set transition [expr {($astat >> 8) & 0x7f}]
    set ptp_state [expr {$ptp & 0xff}]
    set cmd1_rc [expr {$rc & 3}]
    set cmd2_rc [expr {($rc >> 2) & 3}]
    set cmd3_rc [expr {($rc >> 4) & 3}]
    set cmd4_rc [expr {($rc >> 6) & 3}]
    puts [format "BOOT_INIT_TRACE_SAMPLE board=%s sample=%03d elapsed_ms=%d PSTAT=%s ASTAT=%s PTPSTAT=%s PTP_STATE=%d LINK=%d LOCKED=%d TRACE_VALID=%d SCRIPT_ENTER=%d CURRENT_INDEX=%d CMD1_BEFORE=%d CMD1_AFTER=%d CMD2_BEFORE=%d CMD2_AFTER=%d CMD3_BEFORE=%d CMD3_AFTER=%d CMD4_BEFORE=%d CMD4_AFTER=%d CMD1_RC_CLASS=%s CMD2_RC_CLASS=%s CMD3_RC_CLASS=%s CMD4_RC_CLASS=%s MODE_MASTER_CALL_COUNT=%d MODE_MASTER_RETURN_COUNT=%d CMD1_AFTER_PUBLISHED=%d AFTER_SHELL_EXEC_RETURN=%d BEFORE_BUILD_INIT_READCMD=%d AFTER_BUILD_INIT_READCMD=%d NEXT_COMMAND_PTR_VALID=%d NEXT_COMMAND_INDEX_SET=%d CMD2_BEFORE_PUBLISHED=%d" \
      $hardware_name $sample $elapsed [display32 $pstat_raw] [display32 $astat_raw] [display32 $ptp_raw] $ptp_state \
      [expr {$pstat & 1}] [expr {($pstat >> 1) & 1}] \
      [expr {($pstat >> 30) & 1}] [expr {($pstat >> 26) & 1}] \
      [expr {($pstat >> 27) & 7}] \
      [expr {$trace & 1}] [expr {($trace >> 4) & 1}] \
      [expr {($trace >> 1) & 1}] [expr {($trace >> 5) & 1}] \
      [expr {($trace >> 2) & 1}] [expr {($trace >> 6) & 1}] \
      [expr {($trace >> 3) & 1}] [expr {($trace >> 7) & 1}] \
      [rc_class_name $cmd1_rc] [rc_class_name $cmd2_rc] \
      [rc_class_name $cmd3_rc] [rc_class_name $cmd4_rc] \
      [expr {($pstat >> 10) & 0xf}] [expr {($pstat >> 14) & 0xf}] \
      [expr {$transition & 1}] [expr {($transition >> 1) & 1}] \
      [expr {($transition >> 2) & 1}] [expr {($transition >> 3) & 1}] \
      [expr {($transition >> 4) & 1}] [expr {($transition >> 5) & 1}] \
      [expr {($transition >> 6) & 1}]]
  }
  flush stdout
}

puts [format "BOOT_INIT_TRACE_CONFIG samples=%d gap_ms=%d filter=%s" \
  $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== BOOT_INIT_TRACE_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_trace_sample $hardware_name $sample $start_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
  } error_message]} {
    puts [format "BOOT_INIT_TRACE_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "BOOT_INIT_TRACE_DONE"
