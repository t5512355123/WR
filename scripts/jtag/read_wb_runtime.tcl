package require ::quartus::insystem_source_probe

set ::wb_toggle 0

proc decode_cpu_probe {hex_value} {
  scan $hex_value %x value
  set pc [expr {$value & 0xffffffff}]
  set reset [expr {($value >> 32) & 1}]
  set fault [expr {($value >> 33) & 1}]
  set im_valid [expr {($value >> 34) & 1}]
  puts [format "cpu_debug: PC=0x%08X reset=%d fault=%d im_valid=%d" \
        $pc $reset $fault $im_valid]
}

proc read_cpu_probe {label} {
  set value [read_probe_data -instance_index 2 -value_in_hex]
  puts "${label}:    $value"
  decode_cpu_probe $value
  return $value
}

proc read_marker_probe {label} {
  set value [read_probe_data -instance_index 3 -value_in_hex]
  scan $value %x word
  set marker [expr {$word & 0xffffffff}]
  set seen [expr {($word >> 32) & 1}]
  puts [format "%s: 0x%08X seen=%d" $label $marker $seen]
}

proc read_store_probe {label} {
  set value [read_probe_data -instance_index 4 -value_in_hex]
  scan $value %x word
  set addr [expr {$word & 0xffffffff}]
  set data [expr {($word >> 32) & 0xffffffff}]
  puts [format "%s: addr=0x%08X data=0x%08X" $label $addr $data]
}

proc read_store_count_probe {label} {
  set value [read_probe_data -instance_index 5 -value_in_hex]
  scan $value %x word
  puts [format "%s: %d (0x%08X)" $label [expr {$word & 0xffffffff}] [expr {$word & 0xffffffff}]]
}

proc read_exception_probe {label} {
  set value [read_probe_data -instance_index 6 -value_in_hex]
  scan $value %x word
  set mepc [expr {$word & 0xffffffff}]
  set mcause [expr {($word >> 32) & 0xffffffff}]
  puts [format "%s: mepc=0x%08X mcause=0x%08X" $label $mepc $mcause]
}

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

proc wb_sync_toggle {} {
  # The mailbox completion toggle survives between quartus_stp sessions.
  # Start with the opposite value so the first command cannot match stale data.
  set value [read_probe_data -instance_index 1 -value_in_hex]
  scan $value %x word
  set current_done [expr {(($word >> 35) & 1)}]
  # wb_read flips the variable before sending a command.
  set ::wb_toggle $current_done
  puts [format "mailbox initial done=%d next_toggle=%d" $current_done [expr {$current_done ^ 1}]]
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
    read_cpu_probe "cpu_probe_1"
    after 50
    read_cpu_probe "cpu_probe_2"
    read_marker_probe "cpu_marker"
    read_store_probe "cpu_last_internal_store"
    read_store_count_probe "cpu_internal_store_count"
    read_exception_probe "cpu_exception"
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
    puts "CPU_DBGREADY: [wb_read 0x00100B88]"
    puts "CPU_MBX:      [wb_read 0x00100B90]"
    puts "WDIAGS_VER:   [wb_read 0x00100900]"
    puts "WDIAGS_CTRL:  [wb_read 0x00100904]"
    puts "WDIAGS_SSTAT: [wb_read 0x00100908]"
    puts "WDIAGS_PSTAT: [wb_read 0x0010090C]"
    puts "WDIAGS_PTP:   [wb_read 0x00100910]"
    puts "WDIAGS_PTP_RX:[wb_read 0x00100954]"
    puts "WDIAGS_PTP_TX:[wb_read 0x00100958]"
    puts "WDIAGS_PTP_META:[wb_read 0x0010095C]"
    puts "WDIAGS_PTP_TYPES:[wb_read 0x00100974]"
    puts "WDIAGS_FOREIGN_META:[wb_read 0x00100978]"
    puts "WDIAGS_FILTER_META:[wb_read 0x0010097C]"
    puts "WDIAGS_PARSE_META:[wb_read 0x00100980]"
    puts "WDIAGS_TX:    [wb_read 0x00100918]"
    puts "WDIAGS_RX:    [wb_read 0x0010091C]"
    puts "WDIAGS_SEC_H: [wb_read 0x00100920]"
    puts "WDIAGS_SEC_L: [wb_read 0x00100924]"
    puts "WDIAGS_NS:    [wb_read 0x00100928]"
    puts "WDIAGS_MU_H:  [wb_read 0x0010092C]"
    puts "WDIAGS_MU_L:  [wb_read 0x00100930]"
    puts "WDIAGS_DMS_H: [wb_read 0x00100934]"
    puts "WDIAGS_DMS_L: [wb_read 0x00100938]"
    puts "WDIAGS_ASYM:  [wb_read 0x0010093C]"
    puts "WDIAGS_CKO:   [wb_read 0x00100940]"
    puts "WDIAGS_SETP:  [wb_read 0x00100944]"
    puts "WDIAGS_UCNT:  [wb_read 0x00100948]"
    puts "WDIAGS_TEMP:  [wb_read 0x0010094C]"
    puts "WDIAGS_RXERR: [wb_read 0x00100960]"
    puts "WDIAGS_RESTART:[wb_read 0x0010096C]"
    puts "WDIAGS_SLIDE: [wb_read 0x00100970]"
    puts "WDIAGS_SPLL_HY:[wb_read 0x00100984]"
    puts "WDIAGS_SPLL_MY:[wb_read 0x00100988]"
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
