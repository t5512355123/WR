# BOOT generation persistence diagnostic.
#
# The CRT records a magic sentinel, a generation counter, and a four-word
# history of build_init_readcmd_p at _entry in the fixed .debug_precrt area:
#   0x0002e010  p raw at reset entry
#   0x0002e014  p raw after BSS/data initialization
#   0x0002e018  BOOT_MAGIC
#   0x0002e01c  BOOT_GENERATION
#   0x0002e020  P_AT_ENTRY_HISTORY[0]
#   0x0002e024  P_AT_ENTRY_HISTORY[1]
#   0x0002e028  P_AT_ENTRY_HISTORY[2]
#   0x0002e02c  P_AT_ENTRY_HISTORY[3]
#
# Optional argument: settle time in milliseconds before holding the CPU.
# Use 0 for an immediate sample and a positive value to observe whether the
# running image re-entered _entry without FPGA reconfiguration.

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

proc cpu_host_read_word {host_reads} {
  # UDATA is exposed through the host-endian CSR path; convert the settled
  # read back to the CPU's 32-bit word representation.
  set word [byte_swap32 [string trim [lindex [split $host_reads "/"] 1]]]
  if {$word < 0} { return -1 }
  return [format %08X $word]
}

set settle_ms 0
if {[llength $argv] > 0} {
  set settle_ms [lindex $argv 0]
  if {![string is integer -strict $settle_ms] || $settle_ms < 0} {
    error "settle_ms must be a non-negative integer"
  }
}

puts [format "BOOT_GENERATION_CONFIG settle_ms=%d precrt_byte=0x0002E010 magic=0x424F4F54 expected_shell_init_cmd=FROM_CURRENT_ELF" $settle_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== BOOT_GENERATION_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name -device_name $device_name
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    if {$settle_ms > 0} { after $settle_ms }
    set hold [wb_write $hardware_name 0x00100D00 1]

    set p_reset_host [cpu_host_read $hardware_name 0x0000B804]
    set p_after_host [cpu_host_read $hardware_name 0x0000B805]
    set magic_host [cpu_host_read $hardware_name 0x0000B806]
    set generation_host [cpu_host_read $hardware_name 0x0000B807]
    set history0_host [cpu_host_read $hardware_name 0x0000B808]
    set history1_host [cpu_host_read $hardware_name 0x0000B809]
    set history2_host [cpu_host_read $hardware_name 0x0000B80A]
    set history3_host [cpu_host_read $hardware_name 0x0000B80B]

    set p_reset [cpu_host_read_word $p_reset_host]
    set p_after [cpu_host_read_word $p_after_host]
    set magic [cpu_host_read_word $magic_host]
    set generation [cpu_host_read_word $generation_host]
    set history0 [cpu_host_read_word $history0_host]
    set history1 [cpu_host_read_word $history1_host]
    set history2 [cpu_host_read_word $history2_host]
    set history3 [cpu_host_read_word $history3_host]
    set release [wb_write $hardware_name 0x00100D00 0]

    puts [format "BOOT_GENERATION_SAMPLE board=%s CPU_HOLD=%s SETTLE_MS=%d MAGIC=%s GENERATION=%s HISTORY0=%s HISTORY1=%s HISTORY2=%s HISTORY3=%s P_RAW_AT_RESET_ENTRY=%s P_RAW_AFTER_DATA_INIT=%s CPU_RELEASE=%s" \
      $hardware_name $hold $settle_ms [display32 $magic] [display32 $generation] \
      [display32 $history0] [display32 $history1] [display32 $history2] [display32 $history3] \
      [display32 $p_reset] [display32 $p_after] $release]
    puts [format "BOOT_GENERATION_READS board=%s MAGIC_READS=%s GENERATION_READS=%s HISTORY0_READS=%s HISTORY1_READS=%s HISTORY2_READS=%s HISTORY3_READS=%s" \
      $hardware_name $magic_host $generation_host $history0_host $history1_host $history2_host $history3_host]
    puts [format "BOOT_GENERATION_CPU_WORDS board=%s MAGIC=%s GENERATION=%s HISTORY0=%s HISTORY1=%s HISTORY2=%s HISTORY3=%s" \
      $hardware_name [display32 $magic] [display32 $generation] [display32 $history0] \
      [display32 $history1] [display32 $history2] [display32 $history3]]
  } error_message]} {
    puts [format "BOOT_GENERATION_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "BOOT_GENERATION_DONE"
