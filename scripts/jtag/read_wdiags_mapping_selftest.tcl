# WDIAGS firmware-to-JTAG register-map self-test。
#
# 只讀取 firmware 每秒寫入的 magic words 與 counter，不寫入任何設定。
# 用法：
#   quartus_stp -t read_wdiags_mapping_selftest.tcl ?gap_ms?

package require ::quartus::insystem_source_probe

set gap_ms 1000
if {[llength $argv] >= 1} {
  set gap_ms [expr {int([lindex $argv 0])}]
}
if {$gap_ms < 0} {
  error "gap_ms must be >= 0"
}

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

proc wb_sync_toggle {} {
  set value [read_probe_data -instance_index 1 -value_in_hex]
  scan $value %x word
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
}

proc read_map_sample {hardware_name label} {
  set status [read_probe_data -instance_index 0 -value_in_hex]
  set magic_a [wb_read 0x00100B2C]
  set magic_b [wb_read 0x00100B30]
  set counter [wb_read 0x00100B34]
  set inverse [wb_read 0x00100B38]
  set mode_meta [wb_read 0x00100A5C]
  set ptp [wb_read 0x00100A10]
  puts [format "WDIAGS_MAP_SAMPLE board=%s label=%s status=%s MAGIC_A=%s MAGIC_B=%s COUNTER=%s INVERSE=%s PTP_META=%s PTP=%s" \
        $hardware_name $label $status $magic_a $magic_b $counter $inverse $mode_meta $ptp]
  flush stdout
}

puts [format "WDIAGS_MAP_CONFIG gap_ms=%d expected_magic_a=A5A5122C expected_magic_b=A5A51330" $gap_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    read_map_sample $hardware_name BEGIN
    after $gap_ms
    read_map_sample $hardware_name END
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "WDIAGS_MAP_DONE"
