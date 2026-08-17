# 讀取 Slave DCO controller 的唯讀狀態鏈。
# [2:0] rt_state, [3] bus_state, [4] bus_done, [5] static_ready,
# [6] dpll_pending, [7] hpll_pending, [8] dpll_prev_valid,
# [9] hpll_prev_valid, [10] select_dpll, [11] rt_dir,
# [12] dpll_dir, [13] hpll_dir, [14] runtime_start, [15] bus_enable,
# [21:16] I2C state, [22] bus_start, [23] static_start,
# [24] system_start, [25] user_start_rise, [26] initial_start,
# [27] error, [28] busy, [29] DPLL load, [30] HPLL load,
# [47:32] completed steps, [63:48] last HPLL data.

package require ::quartus::insystem_source_probe

set gap_ms 1000
if {[llength $argv] >= 1} {
  set gap_ms [expr {int([lindex $argv 0])}]
}

proc read_state_word {} {
  set value [read_probe_data -instance_index 9 -value_in_hex]
  scan $value %x word
  return [format %016X $word]
}

puts [format "DCO_STATE_CONFIG gap_ms=%d" $gap_ms]
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set first [read_state_word]
    after $gap_ms
    set second [read_state_word]
    puts [format "DCO_STATE A=%s B=%s" $first $second]
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
