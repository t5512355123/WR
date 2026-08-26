# Read the raw q_b tap exported from generic_dpram and compare it with
# dm_mem_rdata at the first internal CPU load.
# Probe 20: primitive q_b before [63:32], primitive q_b at load [31:0].
# Probe 21: primitive q_b after load [63:32], dm_mem_rdata at load [31:0].
# Probe 22: bit 0 load seen, bit 1 after seen, bit 2 q_b/dm equality,
# bits 4:3 capture state, bit 8 reset active now, bit 9 CPU reset active now.

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

puts "CPU_RAM_DIRECT_Q_B_CONFIG probes=20,21,22 first_internal_load=true filter=$board_filter"

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== CPU_RAM_DIRECT_Q_B_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name -device_name $device_name
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name

    set probe0 [probe_read 20]
    set probe1 [probe_read 21]
    set meta_probe [probe_read 22]
    set payload0 [number $probe0]
    set payload1 [number $probe1]
    set meta [number $meta_probe]
    if {$payload0 < 0 || $payload1 < 0 || $meta < 0} {
      puts [format "CPU_RAM_DIRECT_Q_B_SAMPLE board=%s PROBE20=%s PROBE21=%s META_PROBE=%s STATUS=INVALID" \
        $hardware_name $probe0 $probe1 $meta_probe]
    } else {
      set q_before [expr {($payload0 >> 32) & 0xffffffff}]
      set q_at [expr {$payload0 & 0xffffffff}]
      set q_after [expr {($payload1 >> 32) & 0xffffffff}]
      set dm_at [expr {$payload1 & 0xffffffff}]
      set load_seen [expr {$meta & 1}]
      set after_seen [expr {($meta >> 1) & 1}]
      set same_at_load [expr {($meta >> 2) & 1}]
      set capture_state [expr {($meta >> 3) & 3}]
      set reset_active_now [expr {($meta >> 8) & 1}]
      set cpu_reset_active_now [expr {($meta >> 9) & 1}]
      puts [format "CPU_RAM_DIRECT_Q_B_SAMPLE board=%s PROBE20=%s PROBE21=%s META_PROBE=%s PRIMITIVE_Q_B_BEFORE_LOAD=%s PRIMITIVE_Q_B_AT_LOAD=%s PRIMITIVE_Q_B_AFTER_LOAD=%s DM_MEM_RDATA_AT_LOAD=%s FIRST_INTERNAL_LOAD_SEEN=%d AFTER_LOAD_SEEN=%d PRIMITIVE_DM_EQUAL_AT_LOAD=%d CAPTURE_STATE=%d RESET_ASSERTED_NOW=%d CPU_RESET_ACTIVE_NOW=%d" \
        $hardware_name $probe0 $probe1 $meta_probe \
        [display32 $q_before] [display32 $q_at] [display32 $q_after] \
        [display32 $dm_at] $load_seen $after_seen $same_at_load \
        $capture_state $reset_active_now $cpu_reset_active_now]
    }
  } error_message]} {
    puts [format "CPU_RAM_DIRECT_Q_B_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "CPU_RAM_DIRECT_Q_B_DONE"
