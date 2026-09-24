# Read the sticky first internal CPU data-load observation.
#
# Probe 9 carries the request address in [31:0] and the following RAM return
# word in [63:32].  Probe 10 carries byte enable [3:0], request-seen bit 4,
# return-seen bit 5, and expected-address match bit 6.

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

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  return [string trim $value]
}

proc selected_board {hardware_name} {
  if {$::board_filter eq ""} { return 1 }
  return [expr {[string first $::board_filter $hardware_name] >= 0}]
}

puts "CPU_DATA_PORT_IDENTITY_CONFIG first_internal_load=true expected_addr=0001C304 addr_probe=9 meta_probe=10 filter=$board_filter"

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== CPU_DATA_PORT_IDENTITY_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name -device_name $device_name
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name

    set addr_probe [probe_read 9]
    set meta_probe [probe_read 10]
    set addr_payload [number $addr_probe]
    set meta_payload [number $meta_probe]
    if {$addr_payload < 0 || $meta_payload < 0} {
      puts [format "CPU_DATA_PORT_IDENTITY_SAMPLE board=%s ADDR_PROBE=%s META_PROBE=%s STATUS=INVALID" \
        $hardware_name $addr_probe $meta_probe]
    } else {
      set data_addr [expr {$addr_payload & 0xffffffff}]
      set return_data [expr {($addr_payload >> 32) & 0xffffffff}]
      set byte_enable [expr {$meta_payload & 0xf}]
      set read_seen [expr {($meta_payload >> 4) & 1}]
      set return_seen [expr {($meta_payload >> 5) & 1}]
      set expected_match [expr {($meta_payload >> 6) & 1}]
      puts [format "CPU_DATA_PORT_IDENTITY_SAMPLE board=%s ADDR_PROBE=%s META_PROBE=%s DATA_ADDR=%s RETURN_DATA=%s BYTE_ENABLE=%X READ_SEEN=%d RETURN_SEEN=%d EXPECTED_ADDR_MATCH=%d" \
        $hardware_name $addr_probe $meta_probe [display32 $data_addr] \
        [display32 $return_data] $byte_enable $read_seen $return_seen $expected_match]
    }
  } error_message]} {
    puts [format "CPU_DATA_PORT_IDENTITY_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "CPU_DATA_PORT_IDENTITY_DONE"
