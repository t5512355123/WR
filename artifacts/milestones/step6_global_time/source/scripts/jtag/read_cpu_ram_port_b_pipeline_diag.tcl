# Read the sticky first internal CPU data-load observation at the RAM port-B
# boundary.  Probe 11 contains request address [31:0] and the clocked
# registered-address mirror [63:32].  Probe 12 contains q cycle 1 [31:0] and
# q cycle 2 [63:32].  Probe 13 contains byte enable [3:0], request/q1/q2
# seen bits [4:6], and expected-address match bit 7.

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

puts "CPU_RAM_PORT_B_PIPELINE_CONFIG first_internal_load=true expected_addr=0001C304 addr_probe=11 q_probe=12 meta_probe=13 port_b_rden=not_exposed filter=$board_filter"

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== CPU_RAM_PORT_B_PIPELINE_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name -device_name $device_name
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name

    set addr_probe [probe_read 11]
    set q_probe [probe_read 12]
    set meta_probe [probe_read 13]
    set addr_payload [number $addr_probe]
    set q_payload [number $q_probe]
    set meta_payload [number $meta_probe]
    if {$addr_payload < 0 || $q_payload < 0 || $meta_payload < 0} {
      puts [format "CPU_RAM_PORT_B_PIPELINE_SAMPLE board=%s ADDR_PROBE=%s Q_PROBE=%s META_PROBE=%s STATUS=INVALID" \
        $hardware_name $addr_probe $q_probe $meta_probe]
    } else {
      set request_addr [expr {$addr_payload & 0xffffffff}]
      set registered_addr [expr {($addr_payload >> 32) & 0xffffffff}]
      set q_cycle1 [expr {$q_payload & 0xffffffff}]
      set q_cycle2 [expr {($q_payload >> 32) & 0xffffffff}]
      set byte_enable [expr {$meta_payload & 0xf}]
      set request_seen [expr {($meta_payload >> 4) & 1}]
      set q1_seen [expr {($meta_payload >> 5) & 1}]
      set q2_seen [expr {($meta_payload >> 6) & 1}]
      set expected_match [expr {($meta_payload >> 7) & 1}]
      puts [format "CPU_RAM_PORT_B_PIPELINE_SAMPLE board=%s ADDR_PROBE=%s Q_PROBE=%s META_PROBE=%s PORT_B_ADDR_REQUEST=%s PORT_B_ADDR_REGISTERED=%s PORT_B_Q_CYCLE_1=%s PORT_B_Q_CYCLE_2=%s BYTE_ENABLE=%X REQUEST_SEEN=%d Q1_SEEN=%d Q2_SEEN=%d EXPECTED_ADDR_MATCH=%d PORT_B_RDEN=NOT_EXPOSED" \
        $hardware_name $addr_probe $q_probe $meta_probe \
        [display32 $request_addr] [display32 $registered_addr] \
        [display32 $q_cycle1] [display32 $q_cycle2] $byte_enable \
        $request_seen $q1_seen $q2_seen $expected_match]
    }
  } error_message]} {
    puts [format "CPU_RAM_PORT_B_PIPELINE_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "CPU_RAM_PORT_B_PIPELINE_DONE"
