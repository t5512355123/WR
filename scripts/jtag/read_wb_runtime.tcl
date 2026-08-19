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
    # Endpoint registers: verify that the two WR nodes have distinct clock IDs.
    # The generic board derives the PTP clock identity from this MAC address.
    set ep_mach [wb_read 0x00100124]
    set ep_macl [wb_read 0x00100128]
    puts "EP_MAC_H:     $ep_mach"
    puts "EP_MAC_L:     $ep_macl"
    puts "EP_DSR:       [wb_read 0x00100138]"
    puts "CPU_RESET:    [wb_read 0x00100D00]"
    puts "CPU_DBGSTAT:  [wb_read 0x00100D80]"
    puts "CPU_DBGREADY: [wb_read 0x00100D88]"
    puts "CPU_MBX:      [wb_read 0x00100D90]"
    puts "WDIAGS_VER:   [wb_read 0x00100A00]"
    puts "WDIAGS_CTRL:  [wb_read 0x00100A04]"
    puts "WDIAGS_SSTAT: [wb_read 0x00100A08]"
    puts "WDIAGS_PSTAT: [wb_read 0x00100A0C]"
    puts "WDIAGS_PTP:   [wb_read 0x00100A10]"
    puts "WDIAGS_PTP_RX:[wb_read 0x00100A54]"
    puts "WDIAGS_PTP_TX:[wb_read 0x00100A58]"
    set wr_rx_reject_debug [wb_read 0x00100A50]
    puts "WR_SIGNAL_REJECT:$wr_rx_reject_debug"
    set ptp_meta [wb_read 0x00100A5C]
    puts "WDIAGS_PTP_META:$ptp_meta"
    scan $ptp_meta %x ptp_meta_word
    puts [format "WDIAGS_MODE:   %d" [expr {($ptp_meta_word >> 24) & 0xff}]]
    puts "WDIAGS_PTP_TYPES:[wb_read 0x00100A74]"
    puts "WDIAGS_FOREIGN_META:[wb_read 0x00100A78]"
    puts "WDIAGS_FILTER_META:[wb_read 0x00100A7C]"
    puts "WDIAGS_PARSE_META:[wb_read 0x00100A80]"
    puts "WDIAGS_TX:    [wb_read 0x00100A18]"
    puts "WDIAGS_RX:    [wb_read 0x00100A1C]"
    puts "WDIAGS_SEC_H: [wb_read 0x00100A20]"
    puts "WDIAGS_SEC_L: [wb_read 0x00100A24]"
    puts "WDIAGS_NS:    [wb_read 0x00100A28]"
    puts "WDIAGS_MU_H:  [wb_read 0x00100A2C]"
    puts "WDIAGS_MU_L:  [wb_read 0x00100A30]"
    puts "WDIAGS_DMS_H: [wb_read 0x00100A34]"
    puts "WDIAGS_DMS_L: [wb_read 0x00100A38]"
    puts "WDIAGS_ASYM:  [wb_read 0x00100A3C]"
    puts "WDIAGS_CKO:   [wb_read 0x00100A40]"
    puts "WDIAGS_SETP:  [wb_read 0x00100A44]"
    puts "WDIAGS_UCNT:  [wb_read 0x00100A48]"
    puts "WDIAGS_TEMP:  [wb_read 0x00100A4C]"
    puts "WDIAGS_RXERR: [wb_read 0x00100A60]"
    puts "WDIAGS_RESTART:[wb_read 0x00100A6C]"
    puts "WDIAGS_SLIDE: [wb_read 0x00100A70]"
    puts "WDIAGS_SPLL_HY:[wb_read 0x00100A84]"
    puts "WDIAGS_SPLL_MY:[wb_read 0x00100A88]"
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
