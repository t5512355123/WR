# Read the sticky RAM port-B q sequence around reset release.
# Probe 15: q while reset [63:32], release cycle 0 [31:0].
# Probe 16: release cycle 1 [63:32], release cycle 2 [31:0].
# Probe 17: release cycle 3 [63:32], q immediately before first load [31:0].
# Probe 18: q at first internal load [31:0].
# Probe 19: flags/state: bit 0 reset-q seen, bit 1 release seen,
# bit 2 release sequence complete, bit 3 first load seen, bits 6:4
# release capture state, bit 8 reset active now, bit 9 CPU reset active now.

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

puts "CPU_RAM_PORT_B_RESET_RELEASE_INITIAL_Q_CONFIG probes=15,16,17,18,19 filter=$board_filter"

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== CPU_RAM_PORT_B_RESET_RELEASE_INITIAL_Q_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name -device_name $device_name
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name

    set probe0 [probe_read 15]
    set probe1 [probe_read 16]
    set probe2 [probe_read 17]
    set probe3 [probe_read 18]
    set meta_probe [probe_read 19]
    set payload0 [number $probe0]
    set payload1 [number $probe1]
    set payload2 [number $probe2]
    set payload3 [number $probe3]
    set meta [number $meta_probe]
    if {$payload0 < 0 || $payload1 < 0 || $payload2 < 0 || $payload3 < 0 || $meta < 0} {
      puts [format "CPU_RAM_PORT_B_RESET_RELEASE_INITIAL_Q_SAMPLE board=%s PROBE15=%s PROBE16=%s PROBE17=%s PROBE18=%s META_PROBE=%s STATUS=INVALID" \
        $hardware_name $probe0 $probe1 $probe2 $probe3 $meta_probe]
    } else {
      set q_while_reset [expr {($payload0 >> 32) & 0xffffffff}]
      set q_release0 [expr {$payload0 & 0xffffffff}]
      set q_release1 [expr {($payload1 >> 32) & 0xffffffff}]
      set q_release2 [expr {$payload1 & 0xffffffff}]
      set q_release3 [expr {($payload2 >> 32) & 0xffffffff}]
      set q_before_load [expr {$payload2 & 0xffffffff}]
      set q_at_load [expr {$payload3 & 0xffffffff}]
      set reset_q_seen [expr {$meta & 1}]
      set release_seen [expr {($meta >> 1) & 1}]
      set release_complete [expr {($meta >> 2) & 1}]
      set first_load_seen [expr {($meta >> 3) & 1}]
      set release_state [expr {($meta >> 4) & 7}]
      set reset_active_now [expr {($meta >> 8) & 1}]
      set cpu_reset_active_now [expr {($meta >> 9) & 1}]
      puts [format "CPU_RAM_PORT_B_RESET_RELEASE_INITIAL_Q_SAMPLE board=%s PROBE15=%s PROBE16=%s PROBE17=%s PROBE18=%s META_PROBE=%s Q_WHILE_RESET=%s Q_RELEASE_CYCLE_0=%s Q_RELEASE_CYCLE_1=%s Q_RELEASE_CYCLE_2=%s Q_RELEASE_CYCLE_3=%s Q_BEFORE_FIRST_INTERNAL_LOAD=%s Q_AT_FIRST_INTERNAL_LOAD=%s RESET_Q_SEEN=%d RESET_RELEASE_SEEN=%d RELEASE_SEQUENCE_COMPLETE=%d FIRST_INTERNAL_LOAD_SEEN=%d RELEASE_STATE=%d RESET_ASSERTED_NOW=%d CPU_RESET_ACTIVE_NOW=%d" \
        $hardware_name $probe0 $probe1 $probe2 $probe3 $meta_probe \
        [display32 $q_while_reset] [display32 $q_release0] [display32 $q_release1] \
        [display32 $q_release2] [display32 $q_release3] [display32 $q_before_load] \
        [display32 $q_at_load] $reset_q_seen $release_seen $release_complete \
        $first_load_seen $release_state $reset_active_now $cpu_reset_active_now]
    }
  } error_message]} {
    puts [format "CPU_RAM_PORT_B_RESET_RELEASE_INITIAL_Q_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "CPU_RAM_PORT_B_RESET_RELEASE_INITIAL_Q_DONE"
