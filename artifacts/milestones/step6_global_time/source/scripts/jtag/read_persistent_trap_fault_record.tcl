# Read the persistent synchronous-fault record from the CPU-local .debug_precrt
# area after a capture. This uses the existing CPU host readback path only to
# hold/release the CPU around the read; it does not reset the CPU or alter WR,
# PHY, SoftPLL, timer, IRQ or exception state.

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

proc cpu_host_read_word {hardware_name word_address} {
  wb_write $hardware_name 0x00100D04 $word_address
  wb_read $hardware_name 0x00100D08
  set settled [wb_read $hardware_name 0x00100D08]
  return [display32 [byte_swap32 $settled]]
}

set fault_fields {
  FAULT_MAGIC 0x0000B81E
  FAULT_COUNT 0x0000B81F
  FAULT_MCAUSE 0x0000B820
  FAULT_MEPC 0x0000B821
  FAULT_MTVAL 0x0000B822
  FAULT_RA 0x0000B823
  FAULT_SP 0x0000B824
  FAULT_BOOT_GENERATION 0x0000B825
  FAULT_LAST_MODE_MASTER_STAGE 0x0000B826
  FAULT_LAST_SPLL_CHECK_LOCK_STAGE 0x0000B827
}

puts "PERSISTENT_TRAP_FAULT_CONFIG debug_precrt_byte=0x0002E078 cpu_host_readback=1 cpu_hold_release=1 reset_write=0"

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== PERSISTENT_TRAP_FAULT_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set hold [wb_write $hardware_name 0x00100D00 1]
    set values {}
    foreach {name address} $fault_fields {
      lappend values $name [cpu_host_read_word $hardware_name $address]
    }
    set release [wb_write $hardware_name 0x00100D00 0]
    puts [format "PERSISTENT_TRAP_FAULT_SAMPLE board=%s CPU_HOLD=%s CPU_RELEASE=%s %s" \
      $hardware_name $hold $release [join $values " "]]
  } error_message]} {
    puts [format "PERSISTENT_TRAP_FAULT_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "PERSISTENT_TRAP_FAULT_DONE"
