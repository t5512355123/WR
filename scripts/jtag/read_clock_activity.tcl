# 讀取目前診斷 SOF 的 clock_activity_probe（JTAG instance 7）。
# 這個腳本只讀取 probe，不寫入 WR、PHY、SoftPLL 或 SI5340 設定。
# probe 欄位：
#   [15:0]  QSFPA_REFCLK 域活動計數
#   [31:16] QSFPB_REFCLK / DMTD 域活動計數
#   [47:32] recovered RX clock 域活動計數
#   [48]    reference toggle
#   [49]    DMTD toggle
#   [50]    RX toggle
#   [51]    PHY ready
#   [52]    RX locked to reference
#   [53]    RX locked to data
#   [63:54] 保留為 0；不要把它們解讀成 clock/reset/link 狀態
# 用法：quartus_stp -t read_clock_activity.tcl ?gap_ms?

package require ::quartus::insystem_source_probe

set gap_ms 1000
if {[llength $argv] >= 1} {
  set gap_ms [expr {int([lindex $argv 0])}]
}
if {$gap_ms < 0} {
  error "gap_ms must be >= 0"
}

proc print_activity {label} {
  set value [read_probe_data -instance_index 7 -value_in_hex]
  scan $value %x word
  set ref_count [expr {$word & 0xffff}]
  set dmtd_count [expr {($word >> 16) & 0xffff}]
  set rx_count [expr {($word >> 32) & 0xffff}]
  set ref_toggle [expr {($word >> 48) & 1}]
  set dmtd_toggle [expr {($word >> 49) & 1}]
  set rx_toggle [expr {($word >> 50) & 1}]
  set phy_ready [expr {($word >> 51) & 1}]
  set rx_ref_lock [expr {($word >> 52) & 1}]
  set rx_data_lock [expr {($word >> 53) & 1}]
  puts [format "CLOCK_ACTIVITY label=%s raw=%016X REF=%d DMTD=%d RX=%d TOGGLE=%d/%d/%d PHY_READY=%d RX_LOCK_REF=%d RX_LOCK_DATA=%d RESERVED_HIGH=0x%03X" \
        $label $word $ref_count $dmtd_count $rx_count $ref_toggle $dmtd_toggle \
        $rx_toggle $phy_ready $rx_ref_lock $rx_data_lock [expr {($word >> 54) & 0x3ff}]]
  flush stdout
}

puts [format "CLOCK_ACTIVITY_CONFIG gap_ms=%d" $gap_ms]
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    print_activity BEGIN
    after $gap_ms
    print_activity END
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
