# Read the first-load same-edge port-A activity capture and primitive q_b.
# Probe 23: port-A byte address [63:32], port-A write data [31:0].
# Probe 24: port-B byte address [63:32], primitive q_b at first load [31:0].
# Probe 25: bit 0 capture seen, bit 1 port-A write enable, bits 5:2 port-A
# byte enable, bit 6 same primitive word address, bit 7 internal load, bit 8
# reset active now, bit 9 CPU reset active now.

package require ::quartus::insystem_source_probe

set board_filter ""
if {[llength $argv] >= 1} { set board_filter [lindex $argv 0] }

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]+$} $value]
}

proc number {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x result
  return $result
}

proc display32 {value} {
  if {[string is integer -strict $value]} {
    set word $value
  } else {
    set word [number $value]
  }
  if {$word < 0} { return $value }
  return [format %08X [expr {$word & 0xffffffff}]]
}

proc selected_board {hardware_name} {
  if {$::board_filter eq ""} { return 1 }
  return [expr {[string first $::board_filter $hardware_name] >= 0}]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  return [string trim $value]
}

puts "CPU_RAM_PORT_A_ACTIVITY_CONFIG probes=23,24,25 first_internal_load=true filter=$board_filter"

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== CPU_RAM_PORT_A_ACTIVITY_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name -device_name $device_name
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name

    set probe0 [probe_read 23]
    set probe1 [probe_read 24]
    set meta_probe [probe_read 25]
    set payload0 [number $probe0]
    set payload1 [number $probe1]
    set meta [number $meta_probe]
    if {$payload0 < 0 || $payload1 < 0 || $meta < 0} {
      puts [format "CPU_RAM_PORT_A_ACTIVITY_SAMPLE board=%s PROBE23=%s PROBE24=%s META_PROBE=%s STATUS=INVALID" \
        $hardware_name $probe0 $probe1 $meta_probe]
    } else {
      set port_a_addr [expr {($payload0 >> 32) & 0xffffffff}]
      set port_a_data [expr {$payload0 & 0xffffffff}]
      set port_b_addr [expr {($payload1 >> 32) & 0xffffffff}]
      set q_b [expr {$payload1 & 0xffffffff}]
      set capture_seen [expr {$meta & 1}]
      set port_a_write_enable [expr {($meta >> 1) & 1}]
      set port_a_byte_enable [expr {($meta >> 2) & 0xf}]
      set same_address [expr {($meta >> 6) & 1}]
      set internal_load [expr {($meta >> 7) & 1}]
      set reset_active_now [expr {($meta >> 8) & 1}]
      set cpu_reset_active_now [expr {($meta >> 9) & 1}]
      puts [format "CPU_RAM_PORT_A_ACTIVITY_SAMPLE board=%s PROBE23=%s PROBE24=%s META_PROBE=%s PORT_A_ADDR_AT_B_FIRST_LOAD=%s PORT_A_WRITE_ENABLE_AT_B_FIRST_LOAD=%d PORT_A_BYTE_ENABLE_AT_B_FIRST_LOAD=0x%X PORT_A_WRITE_DATA_AT_B_FIRST_LOAD=%s PORT_B_ADDR_AT_FIRST_LOAD=%s PRIMITIVE_Q_B_AT_FIRST_LOAD=%s CAPTURE_SEEN=%d SAME_PRIMITIVE_WORD_ADDRESS=%d INTERNAL_LOAD=%d RESET_ASSERTED_NOW=%d CPU_RESET_ACTIVE_NOW=%d" \
        $hardware_name $probe0 $probe1 $meta_probe \
        [display32 $port_a_addr] $port_a_write_enable $port_a_byte_enable \
        [display32 $port_a_data] [display32 $port_b_addr] [display32 $q_b] \
        $capture_seen $same_address $internal_load $reset_active_now $cpu_reset_active_now]
    }
  } error_message]} {
    puts [format "CPU_RAM_PORT_A_ACTIVITY_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "CPU_RAM_PORT_A_ACTIVITY_DONE"
