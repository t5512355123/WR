# White Rabbit SoftPLL 原始唯讀診斷。
#
# 本腳本只透過既有 Wishbone mailbox 讀取 register，不寫入 WR 設定，
# 不寫入 WDIAGS_CTRL.DATA_SNAPSHOT，也不改變 PHY、servo 或 SoftPLL 控制。
# 用法：
#   quartus_stp -t read_spll_diag_raw.tcl ?gap_ms?
#
# 每張板建立一次 source probe，並在同一個 JTAG session 內做兩次讀取。
# 兩次讀值用來檢查計數器是否真的隨 runtime 活動增加。

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
  set current_done [expr {(($word >> 35) & 1)}]
  set ::wb_toggle $current_done
}

proc read_diag {label} {
  set status [read_probe_data -instance_index 0 -value_in_hex]
  set ctrl [wb_read 0x00100904]
  set sstat [wb_read 0x00100908]
  set pstat [wb_read 0x0010090C]
  set pps [wb_read 0x0010031C]
  set lock [wb_read 0x0010098C]
  set unlocked [wb_read 0x00100994]
  set rcer [wb_read 0x00100224]
  set ocer [wb_read 0x00100228]
  set trr_csr [wb_read 0x00100280]
  set raw_valid [wb_read 0x00100284]
  set raw_write [wb_read 0x00100288]
  set raw_source [wb_read 0x0010028C]
  set shadow_ref [wb_read 0x001009D0]
  set shadow_tag [wb_read 0x001009D4]
  set shadow_valid [wb_read 0x001009F8]
  set shadow_write [wb_read 0x001009FC]
  set helper [wb_read 0x001009BC]
  set main [wb_read 0x001009C4]
  set visit [wb_read 0x001009E0]
  set transitions [wb_read 0x001009E4]
  set last_state [wb_read 0x001009E8]
  puts [format "RAW_SAMPLE label=%s status=%s" $label $status]
  puts [format "RAW_CORE: CTRL=%s SSTAT=%s PSTAT=%s PPS_ESCR=%s" \
        $ctrl $sstat $pstat $pps]
  puts [format "RAW_LOCK: RESULT=%s UNLOCKED=%s HELPER=%s MAIN=%s" \
        $lock $unlocked $helper $main]
  puts [format "RAW_HW: RCER=%s OCER=%s TRR_CSR=%s" $rcer $ocer $trr_csr]
  puts [format "RAW_COUNTER: TAG_VALID=%s TRR_WRITE=%s TAG_SOURCE=%s" \
        $raw_valid $raw_write $raw_source]
  puts [format "SHADOW_COUNTER: REF=%s TAG=%s TAG_VALID=%s TRR_WRITE=%s" \
        $shadow_ref $shadow_tag $shadow_valid $shadow_write]
  puts [format "RAW_STATE: VISIT=%s TRANSITIONS=%s LAST_STATE=%s" \
        $visit $transitions $last_state]
  flush stdout
}

puts [format "RAW_DIAG_CONFIG gap_ms=%d" $gap_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    read_diag BEGIN
    after $gap_ms
    read_diag END
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

