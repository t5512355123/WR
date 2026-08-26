# Direct CPU-held read of the static p storage.
#
# This diagnostic does not use the firmware's pre-main capture.  It asserts
# the CPU reset/hold through the CSR mailbox, selects the pointer storage
# address through CPU_UADDR, and reads CPU_UDATA twice.  The settled host read
# is byte-swapped back to the CPU's 32-bit word representation.

package require ::quartus::insystem_source_probe

array set ::wb_toggle {}
set board_filter ""
if {[llength $argv] >= 1} { set board_filter [lindex $argv 0] }

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

proc byte_swap32 {value} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return [expr {(($word & 0x000000ff) << 24) |
                (($word & 0x0000ff00) << 8) |
                (($word & 0x00ff0000) >> 8) |
                (($word & 0xff000000) >> 24)}]
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

proc selected_board {hardware_name} {
  if {$::board_filter eq ""} { return 1 }
  return [expr {[string first $::board_filter $hardware_name] >= 0}]
}

proc cpu_host_read_word {hardware_name word_address} {
  wb_write $hardware_name 0x00100D04 $word_address
  set first [wb_read $hardware_name 0x00100D08]
  set second [wb_read $hardware_name 0x00100D08]
  set settled [string trim [lindex [split "$first / $second" "/"] 1]]
  set word [byte_swap32 $settled]
  if {$word < 0} { return "-1|$first / $second" }
  return "[format %08X $word]|$first / $second"
}

puts "CPU_HELD_DIRECT_P_STORAGE_CONFIG p_byte=0x0001C304 p_word=0x000070C1 mif_expected=0x00017938 filter=$board_filter"

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== CPU_HELD_DIRECT_P_STORAGE_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name -device_name $device_name
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set hold [wb_write $hardware_name 0x00100D00 1]
    set result [cpu_host_read_word $hardware_name 0x000070C1]
    set cpu_word [lindex [split $result "|"] 0]
    set host_reads [lindex [split $result "|"] 1]
    set release [wb_write $hardware_name 0x00100D00 0]
    puts [format "CPU_HELD_DIRECT_P_STORAGE_SAMPLE board=%s CPU_HOLD=%s DIRECT_STORAGE_CPU_WORD=%s HOST_READS=%s MIF_EXPECTED=00017938 CPU_RELEASE=%s" \
      $hardware_name $hold [display32 $cpu_word] $host_reads $release]
  } error_message]} {
    puts [format "CPU_HELD_DIRECT_P_STORAGE_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "CPU_HELD_DIRECT_P_STORAGE_DONE"
