# WDIAGS firmware-to-JTAG register-map self-test。
#
# 只讀取 firmware 的 snapshot request/ack counters 與 mapping
# counter/inverse，不寫入任何設定。這些欄位必須與目前 firmware header
# 的 source-backed map 一致；不再期待舊版的固定 magic words。
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

proc mapping_sample_valid {snapshot_req snapshot_ack counter inverse} {
  if {$snapshot_req eq "TIMEOUT" || $snapshot_ack eq "TIMEOUT" ||
      $counter eq "TIMEOUT" || $inverse eq "TIMEOUT"} {
    return 0
  }
  if {[scan $snapshot_req %x snapshot_req_value] != 1 ||
      [scan $snapshot_ack %x snapshot_ack_value] != 1 ||
      [scan $counter %x counter_value] != 1 ||
      [scan $inverse %x inverse_value] != 1} {
    return 0
  }
  # 0x134/0x138 are mapping counter/inverse only before the first
  # snapshot request. After that request they are owned by the frozen-bank
  # overlay, so a non-zero request/ack count is not a valid mapping sample.
  set expected_inverse [expr {(~$counter_value) & 0xffffffff}]
  return [expr {$snapshot_req_value == 0 &&
                $snapshot_ack_value == 0 &&
                $inverse_value == $expected_inverse}]
}

proc wb_sync_toggle {} {
  set value [read_probe_data -instance_index 1 -value_in_hex]
  scan $value %x word
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
}

proc read_map_sample {hardware_name label} {
  for {set attempt 1} {$attempt <= 5} {incr attempt} {
    set status [read_probe_data -instance_index 0 -value_in_hex]
    set snapshot_req [wb_read 0x00100B2C]
    set snapshot_ack [wb_read 0x00100B30]
    set counter [wb_read 0x00100B34]
    set inverse [wb_read 0x00100B38]
    set mode_meta [wb_read 0x00100A5C]
    set ptp [wb_read 0x00100A10]
    set valid [mapping_sample_valid $snapshot_req $snapshot_ack $counter $inverse]
    puts [format "WDIAGS_MAP_SAMPLE board=%s label=%s attempt=%d valid=%d status=%s SNAPSHOT_REQ_COUNT=%s SNAPSHOT_ACK_COUNT=%s COUNTER=%s INVERSE=%s PTP_META=%s PTP=%s" \
          $hardware_name $label $attempt $valid $status $snapshot_req $snapshot_ack $counter $inverse $mode_meta $ptp]
    flush stdout
    if {$valid} {
      return $valid
    }
    after 20
  }
  return 0
}

puts [format "WDIAGS_MAP_CONFIG gap_ms=%d expected_snapshot_req_count=0 expected_snapshot_ack_count=0 expected_inverse=bitwise_not_counter" $gap_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    set begin_valid [read_map_sample $hardware_name BEGIN]
    after $gap_ms
    set end_valid [read_map_sample $hardware_name END]
    puts [format "WDIAGS_MAP_RESULT board=%s begin_valid=%d end_valid=%d" \
          $hardware_name $begin_valid $end_valid]
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "WDIAGS_MAP_DONE"
