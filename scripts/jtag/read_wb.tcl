package require ::quartus::insystem_source_probe

set ::wb_toggle 0
proc wb_read {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set cmd [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  puts [format "  request toggle=%d addr=0x%08X cmd=0x%024X" $::wb_toggle $addr $cmd]
  write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  after 5
  set last_word 0
  for {set n 0} {$n < 100} {incr n} {
    set value [read_probe_data -instance_index 1 -value_in_hex]
    scan $value %x word
    set last_word $word
    set done_toggle [expr {(($word >> 35) & 1)}]
    set active [expr {(($word >> 36) & 1)}]
    # ack/err are one-cycle result flags; the done toggle is the persistent
    # completion marker that can safely be sampled over JTAG.
    if {$done_toggle == $::wb_toggle && $active == 0} {
      return [format %08X [expr {$word & 0xffffffff}]]
    }
    after 1
  }
  puts [format "  timeout last_probe=0x%016X" $last_word]
  return "TIMEOUT"
}

proc wb_write {addr data} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set cmd [expr {$::wb_toggle | (1 << 1) | (0xf << 2) |
                (($addr & 0xffffffff) << 6) |
                (($data & 0xffffffff) << 38)}]
  puts [format "  write toggle=%d addr=0x%08X data=0x%08X" $::wb_toggle $addr $data]
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

proc wb_read_twice {addr} {
  # The CPU UDATA path is registered: the first read can reflect the
  # previous address while the new IRAM address is settling.
  set first [wb_read $addr]
  set second [wb_read $addr]
  return "$first / $second"
}

proc wb_sync_toggle {} {
  # The mailbox completion toggle survives between quartus_stp sessions.
  # Start with the opposite value so the first command cannot match stale data.
  set value [read_probe_data -instance_index 1 -value_in_hex]
  scan $value %x word
  set current_done [expr {(($word >> 35) & 1)}]
  set ::wb_toggle [expr {$current_done ^ 1}]
  puts [format "mailbox initial done=%d next_toggle=%d" $current_done $::wb_toggle]
}

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  # A previous Tcl invocation can leave the session open after a transport error.
  # Close it before opening this hardware, then close it again on every exit path.
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    puts "status_probe: [read_probe_data -instance_index 0 -value_in_hex]"
    wb_sync_toggle
    puts "PPS_CR:       [wb_read 0x00100300]"
    puts "PPS_ESCR:     [wb_read 0x0010031c]"
    puts "SPLL_CSR:     [wb_read 0x00100200]"
    puts "SPLL_ECCR:    [wb_read 0x00100204]"
    puts "SPLL_OCCR:    [wb_read 0x00100210]"
    puts "SYSC_RSTR:    [wb_read 0x00100400]"
    puts "SYSC_GPSR:    [wb_read 0x00100404]"
    puts "CPU_RESET:    [wb_read 0x00100B00]"
    puts "CPU_DBGSTAT:  [wb_read 0x00100B80]"
    puts "CPU_DBGFORCE: [wb_read 0x00100B84]"
    puts "CPU_DBGREADY: [wb_read 0x00100B88]"
    puts "CPU_MBX:      [wb_read 0x00100B90]"
    # The CPU IRAM host mux is selected only while the CPU reset bit is set.
    # Hold the CPU briefly so UADDR really selects IRAM address zero, then
    # release it so the firmware can restart normally.
    puts "CPU_HOLD:     [wb_write 0x00100B00 1]"
    puts "CPU_UADDR_WR: [wb_write 0x00100B04 0]"
    puts "CPU_IRAM0:    [wb_read_twice 0x00100B08]"
    puts "CPU_RELEASE:  [wb_write 0x00100B00 0]"
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
