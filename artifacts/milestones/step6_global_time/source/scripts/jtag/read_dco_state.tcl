# 讀取 Slave DCO controller 的唯讀狀態鏈。
# 目前 Slave top 的 DCO probe 是固定 instance 8，資料配置與
# si5340a_controller_dco.v 的 dco_debug 完全一致：
# [2:0] rt_state, [3] bus_state, [4] bus_done, [5] static_ready,
# [6] dpll_pending, [7] hpll_pending, [8] dpll_prev_valid,
# [9] hpll_prev_valid, [10] select_dpll, [11] rt_dir,
# [12] dpll_dir, [13] hpll_dir, [14] runtime_start, [15] bus_enable,
# [16] DPLL_LOAD, [17] HPLL_LOAD, [18] error, [19] busy,
# [35:20] completed steps, [51:36] previous DPLL data,
# [52] runtime_start_hold, [63:53] previous HPLL data (低 11 位).

package require ::quartus::insystem_source_probe

set gap_ms 1000
if {[llength $argv] >= 1} {
  set gap_ms [expr {int([lindex $argv 0])}]
}

proc read_state_word {} {
  set value [read_probe_data -instance_index 8 -value_in_hex]
  scan $value %x word
  return [format %016X $word]
}

proc decode_state {word} {
  scan $word %x value
  set rt_state [expr {$value & 0x7}]
  set bus_state [expr {($value >> 3) & 1}]
  set bus_done [expr {($value >> 4) & 1}]
  set ready [expr {($value >> 5) & 1}]
  set runtime_start [expr {($value >> 14) & 1}]
  set bus_enable [expr {($value >> 15) & 1}]
  set dpll_load [expr {($value >> 16) & 1}]
  set hpll_load [expr {($value >> 17) & 1}]
  set error [expr {($value >> 18) & 1}]
  set busy [expr {($value >> 19) & 1}]
  set steps [expr {($value >> 20) & 0xffff}]
  set hold [expr {($value >> 52) & 1}]
  return [format "rt_state=%d bus_state=%d bus_done=%d ready=%d start=%d enable=%d dpll_load=%d hpll_load=%d error=%d busy=%d steps=%d hold=%d" \
    $rt_state $bus_state $bus_done $ready $runtime_start $bus_enable \
    $dpll_load $hpll_load $error $busy $steps $hold]
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
    puts [format "DCO_STATE A=%s (%s) B=%s (%s)" $first [decode_state $first] $second [decode_state $second]]
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
