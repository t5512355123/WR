# Firmware-only audit of static build_init_readcmd() pointer lifetime.
#
# Usage:
#   quartus_stp -t read_boot_init_static_p_startup_lifetime_diag.tcl ?samples? ?gap_ms? ?filter?
#
# PSTAT/ASTAT carry six startup checkpoints. Each value is the offset of the
# file-scope build_init_readcmd_p from shell_init_cmd; no raw pointer is read.

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
  if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
    set ::wb_toggle($hardware_name) 0
    return
  }
  if {[is_hex $value]} {
    scan $value %x word
    set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc wb_startup_sample {hardware_name sample start_ms} {
  set pstat_raw [wb_read $hardware_name 0x00100A0C]
  set astat_raw [wb_read $hardware_name 0x00100A14]
  set pstat [word32 $pstat_raw]
  set astat [word32 $astat_raw]
  set elapsed [expr {[clock milliseconds] - $start_ms}]
  if {$pstat < 0 || $astat < 0} {
    puts [format "BOOT_INIT_STATIC_P_STARTUP_SAMPLE board=%s sample=%03d elapsed_ms=%d PSTAT=%s ASTAT=%s TRACE=INVALID" \
      $hardware_name $sample $elapsed [display32 $pstat_raw] [display32 $astat_raw]]
  } else {
    set valid [expr {($astat >> 14) & 0x3f}]
    puts [format "BOOT_INIT_STATIC_P_STARTUP_SAMPLE board=%s sample=%03d elapsed_ms=%d PSTAT=%s ASTAT=%s VALID_MASK=0x%02X TRACE_VALID=%d LINK=%d LOCKED=%d AUX=%d P_AT_RESET_EARLY=%d P_AFTER_BSS_DATA_INIT=%d P_AFTER_BOARD_INIT=%d P_AFTER_SHELL_INIT=%d P_BEFORE_SHELL_BOOT_SCRIPT=%d P_AT_BOOT_SCRIPT_ENTRY=%d VALID_RESET=%d VALID_BSS=%d VALID_BOARD=%d VALID_SHELL=%d VALID_BEFORE=%d VALID_ENTRY=%d" \
      $hardware_name $sample $elapsed [display32 $pstat_raw] [display32 $astat_raw] \
      $valid [expr {($astat >> 20) & 1}] [expr {$pstat & 1}] \
      [expr {($pstat >> 1) & 1}] [expr {$astat & 0xff}] \
      [expr {($pstat >> 2) & 0x3f}] [expr {($pstat >> 8) & 0x3f}] \
      [expr {($pstat >> 14) & 0x3f}] [expr {($pstat >> 20) & 0x3f}] \
      [expr {($pstat >> 26) & 0x3f}] [expr {($astat >> 8) & 0x3f}] \
      [expr {$valid & 1}] [expr {($valid >> 1) & 1}] \
      [expr {($valid >> 2) & 1}] [expr {($valid >> 3) & 1}] \
      [expr {($valid >> 4) & 1}] [expr {($valid >> 5) & 1}]]
  }
  flush stdout
}

proc selected_board {hardware_name} {
  if {$::board_filter eq ""} { return 1 }
  return [expr {[string first $::board_filter $hardware_name] >= 0}]
}

puts [format "BOOT_INIT_STATIC_P_STARTUP_CONFIG samples=%d gap_ms=%d filter=%s" \
  $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== BOOT_INIT_STATIC_P_STARTUP_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      wb_startup_sample $hardware_name $sample $start_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
  } error_message]} {
    puts [format "BOOT_INIT_STATIC_P_STARTUP_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "BOOT_INIT_STATIC_P_STARTUP_DONE"
