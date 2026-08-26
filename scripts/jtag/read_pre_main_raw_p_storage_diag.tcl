# Pre-main CRT diagnostic for the raw static pointer storage.
#
# The firmware captures the 32-bit contents of build_init_readcmd_p at
# _entry, before BSS/data initialization, and again immediately before main.
# The samples are kept in the fixed .debug_precrt area at byte addresses
# 0x0002e010 and 0x0002e014.  CPU host access reads that RAM while the CPU is
# held in reset; it does not modify firmware state.

package require ::quartus::insystem_source_probe

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

proc wb_write {hardware_name addr data} {
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (1 << 1) | (0xf << 2) |
                (($addr & 0xffffffff) << 6) |
                (($data & 0xffffffff) << 38)}]
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

proc cpu_host_read {hardware_name word_address} {
  wb_write $hardware_name 0x00100D04 $word_address
  # UDATA is registered; the second read is the settled value.
  set first [wb_read $hardware_name 0x00100D08]
  set second [wb_read $hardware_name 0x00100D08]
  return "$first / $second"
}

puts "PRE_MAIN_RAW_P_STORAGE_CONFIG reset_byte=0x0002E010 after_data_byte=0x0002E014 expected_shell_init_cmd=FROM_CURRENT_ELF"

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== PRE_MAIN_RAW_P_STORAGE_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name -device_name $device_name
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set hold [wb_write $hardware_name 0x00100D00 1]
    set reset_entry [cpu_host_read $hardware_name 0x0000B804]
    set after_data [cpu_host_read $hardware_name 0x0000B805]
    puts [format "PRE_MAIN_RAW_P_STORAGE_SAMPLE board=%s CPU_HOLD=%s P_RAW_AT_RESET_ENTRY=%s P_RAW_AFTER_DATA_INIT=%s EXPECTED_SHELL_INIT_CMD=FROM_CURRENT_ELF" \
      $hardware_name $hold [display32 [string trim [lindex [split $reset_entry "/"] 1]]] \
      [display32 [string trim [lindex [split $after_data "/"] 1]]]]
    puts [format "PRE_MAIN_RAW_P_STORAGE_READS board=%s RESET_READS=%s AFTER_DATA_READS=%s CPU_RELEASE=%s" \
      $hardware_name $reset_entry $after_data \
      [wb_write $hardware_name 0x00100D00 0]]
  } error_message]} {
    puts [format "PRE_MAIN_RAW_P_STORAGE_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "PRE_MAIN_RAW_P_STORAGE_DONE"
