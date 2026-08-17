# 讀取 Slave SI5340 page-3/0x0339 的唯讀 readback probe。
# bit 0..7   : 最近一次讀回的 0x0339 值
# bit 8      : readback valid
# bit 9      : sticky ACK/NACK error
# bit 10     : 讀回值符合最近一次 DPLL/HPLL mask command
# bit 11..15 : I2C controller state
# bit 16..31 : readback transaction count
# bit 32..47 : completed DCO step count
# bit 48..63 : 最近一次 HPLL data

package require ::quartus::insystem_source_probe

proc read_readback_word {} {
  set value [read_probe_data -instance_index 10 -value_in_hex]
  scan $value %x word
  return [format %016X $word]
}

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    puts [format "DCO_READBACK value=%s" [read_readback_word]]
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
