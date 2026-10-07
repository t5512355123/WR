# Correlate the first target read with the preceding RAM port-B address/q.
# Probe 11: target request address [31:0], target registered-address mirror
# [63:32]. Probe 12: target q cycle 1 [31:0], q cycle 2 [63:32].
# Probe 13: byte enable [3:0], request/q1/q2 seen [4:6], address match [7].
# Probe 14: previous port-B address [63:32], q before target update [31:0].

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

proc mif_word_at_byte_address {mif_path byte_address} {
  if {$mif_path eq "" || ![file exists $mif_path]} { return NOT_FOUND }
  set target [expr {$byte_address >> 2}]
  if {[catch {set handle [open $mif_path r]}]} { return NOT_FOUND }
  set result NOT_FOUND
  while {[gets $handle line] >= 0} {
    if {[regexp -nocase {^\s*([0-9A-Fa-f]+)\s*:\s*([0-9A-Fa-f]+)} $line -> address word]} {
      scan $address %x parsed_address
      if {$parsed_address == $target} {
        set result $word
        break
      }
    }
  }
  close $handle
  return $result
}

puts "CPU_RAM_PORT_B_PREV_CORRELATION_CONFIG first_internal_load=true target_addr=0001C304 addr_probe=11 q01_probe=12 meta_probe=13 prev_q_probe=14 port_b_rden=not_exposed filter=$board_filter"

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== CPU_RAM_PORT_B_PREV_CORRELATION_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    catch { end_insystem_source_probe }
    get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name -device_name $device_name
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name

    set addr_probe [probe_read 11]
    set q_probe [probe_read 12]
    set meta_probe [probe_read 13]
    set prev_q_probe [probe_read 14]
    set addr_payload [number $addr_probe]
    set q_payload [number $q_probe]
    set meta_payload [number $meta_probe]
    set prev_q_payload [number $prev_q_probe]
    if {$addr_payload < 0 || $q_payload < 0 || $meta_payload < 0 || $prev_q_payload < 0} {
      puts [format "CPU_RAM_PORT_B_PREV_CORRELATION_SAMPLE board=%s ADDR_PROBE=%s Q01_PROBE=%s META_PROBE=%s PREV_Q_PROBE=%s STATUS=INVALID" \
        $hardware_name $addr_probe $q_probe $meta_probe $prev_q_probe]
    } else {
      set target_addr [expr {$addr_payload & 0xffffffff}]
      set target_registered [expr {($addr_payload >> 32) & 0xffffffff}]
      set q_before_target [expr {$prev_q_payload & 0xffffffff}]
      set prev_addr [expr {($prev_q_payload >> 32) & 0xffffffff}]
      set q_target_cycle1 [expr {$q_payload & 0xffffffff}]
      set q_target_cycle2 [expr {($q_payload >> 32) & 0xffffffff}]
      set byte_enable [expr {$meta_payload & 0xf}]
      set request_seen [expr {($meta_payload >> 4) & 1}]
      set q1_seen [expr {($meta_payload >> 5) & 1}]
      set q2_seen [expr {($meta_payload >> 6) & 1}]
      set expected_match [expr {($meta_payload >> 7) & 1}]
      if {[string first "1-11.1" $hardware_name] >= 0} {
        set mif_path [file join [pwd] build firmware master wrc.mif]
      } elseif {[string first "1-11.2" $hardware_name] >= 0} {
        set mif_path [file join [pwd] build firmware slave wrc.mif]
      } else {
        set mif_path ""
      }
      set mif_prev [mif_word_at_byte_address $mif_path $prev_addr]
      puts [format "CPU_RAM_PORT_B_PREV_CORRELATION_SAMPLE board=%s ADDR_PROBE=%s Q01_PROBE=%s META_PROBE=%s PREV_Q_PROBE=%s B_ADDR_PREV=%s B_ADDR_TARGET=%s B_ADDR_REGISTERED=%s B_RDEN=NOT_EXPOSED B_Q_BEFORE_TARGET=%s B_Q_TARGET_CYCLE1=%s B_Q_TARGET_CYCLE2=%s MIF_WORD_AT_PREV_ADDR=%s BYTE_ENABLE=%X REQUEST_SEEN=%d Q1_SEEN=%d Q2_SEEN=%d EXPECTED_ADDR_MATCH=%d" \
        $hardware_name $addr_probe $q_probe $meta_probe $prev_q_probe \
        [display32 $prev_addr] [display32 $target_addr] [display32 $target_registered] \
        [display32 $q_before_target] [display32 $q_target_cycle1] \
        [display32 $q_target_cycle2] [display32 $mif_prev] $byte_enable \
        $request_seen $q1_seen $q2_seen $expected_match]
    }
  } error_message]} {
    puts [format "CPU_RAM_PORT_B_PREV_CORRELATION_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "CPU_RAM_PORT_B_PREV_CORRELATION_DONE"
