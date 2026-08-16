package require ::quartus::insystem_source_probe

set ::wb_toggle 0

proc wb_read {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set cmd [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [read_probe_data -instance_index 1 -value_in_hex]
    scan $value %x word
    set done_toggle [expr {(($word >> 35) & 1)}]
    set active [expr {(($word >> 36) & 1)}]
    if {$done_toggle == $::wb_toggle && $active == 0} {
      return [format %08X [expr {$word & 0xffffffff}]]
    }
    after 1
  }
  return "TIMEOUT"
}

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    puts "status_probe: [read_probe_data -instance_index 0 -value_in_hex]"
    puts "PPS_CR:       [wb_read 0x00100300]"
    puts "PPS_ESCR:     [wb_read 0x0010031c]"
    puts "SPLL_CSR:     [wb_read 0x00100200]"
    puts "SPLL_ECCR:    [wb_read 0x00100204]"
    puts "SPLL_OCCR:    [wb_read 0x00100210]"
    puts "SYSC_RSTR:    [wb_read 0x00100400]"
    puts "SYSC_GPSR:    [wb_read 0x00100404]"
    puts "CPU_DBGSTAT:  [wb_read 0x00100B80]"
    puts "CPU_DBGREADY: [wb_read 0x00100B88]"
    puts "CPU_MBX:      [wb_read 0x00100B90]"
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
