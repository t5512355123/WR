# 讀取 Slave 的 DCO/SoftPLL actuation 唯讀 probe。
# bit 0..15  : SI5340 runtime DCO 完成步數
# bit 16     : runtime transaction busy
# bit 17     : runtime transaction error
# bit 18     : SI5340 static configuration done
# bit 19     : SoftPLL HPLL load pulse
# bit 20..31 : HPLL load counter
# bit 32     : SoftPLL DPLL load pulse
# bit 33..43 : DPLL load counter

package require ::quartus::insystem_source_probe

set gap_ms 1000
if {[llength $argv] >= 1} {
  set gap_ms [expr {int([lindex $argv 0])}]
}

proc read_dco_word {} {
  set value [read_probe_data -instance_index 8 -value_in_hex]
  scan $value %x word
  return [format %016X $word]
}

puts [format "DCO_ACTIVITY_CONFIG gap_ms=%d" $gap_ms]
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set first [read_dco_word]
    after $gap_ms
    set second [read_dco_word]
    puts [format "DCO_ACTIVITY A=%s B=%s" $first $second]
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
