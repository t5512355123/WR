# White Rabbit WR parent/signaling/lock handoff 的唯讀聚焦觀測。
#
# 用法：
#   quartus_stp -t read_wr_handshake_focused.tcl ?samples? ?gap_ms?
#
# 只讀取定位第一個斷點所需的 mailbox 欄位，不寫入 WR 控制設定，
# 也不寫入 DATA_SNAPSHOT。這不是同步成功判定工具；它只用來區分：
# parent selection、WR signaling RX、local state、WR lock handoff、RCER。

package require ::quartus::insystem_source_probe

set samples 60
set gap_ms 1000
if {[llength $argv] >= 1} {
  set samples [expr {int([lindex $argv 0])}]
}
if {[llength $argv] >= 2} {
  set gap_ms [expr {int([lindex $argv 1])}]
}
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
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

proc u32 {value} {
  return [regexp {^[0-9A-Fa-f]{1,8}$} $value]
}

proc u64 {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc read_focused_sample {hardware_name sample} {
  set status [read_probe_data -instance_index 0 -value_in_hex]
  set ptp_meta [wb_read 0x0010095C]
  set foreign_meta [wb_read 0x00100978]
  set parse_meta [wb_read 0x00100980]
  set wr_state [wb_read 0x0010094C]
  set wr_rx [wb_read 0x00100964]
  set wr_tx [wb_read 0x00100968]
  set wr_fail [wb_read 0x0010096C]
  set wr_reject [wb_read 0x00100950]
  set wr_lock_result [wb_read 0x0010098C]
  set wr_lock_polls [wb_read 0x00100990]
  set wr_lock_enable [wb_read 0x0010099C]
  set rcer [wb_read 0x001009A8]
  set sstat [wb_read 0x00100908]
  set pstat [wb_read 0x0010090C]

  set valid 1
  if {![u64 $status]} {
    set valid 0
  }
  foreach value [list $ptp_meta $foreign_meta $parse_meta $wr_state \
      $wr_rx $wr_tx $wr_fail $wr_reject $wr_lock_result $wr_lock_polls \
      $wr_lock_enable $rcer $sstat $pstat] {
    if {![u32 $value]} {
      set valid 0
    }
  }

  if {$valid} {
    scan $status %x status_word
    scan $ptp_meta %x ptp_meta_word
    scan $foreign_meta %x foreign_word
    scan $parse_meta %x parse_word
    scan $wr_state %x state_word
    scan $wr_rx %x rx_word
    scan $wr_tx %x tx_word
    scan $wr_fail %x fail_word
    scan $wr_reject %x reject_word
    scan $wr_lock_result %x lock_result_word
    scan $wr_lock_polls %x lock_polls_word
    scan $wr_lock_enable %x lock_enable_word
    scan $rcer %x rcer_word
    scan $sstat %x sstat_word
    scan $pstat %x pstat_word

    set status_low [expr {$status_word & 0xff}]
    set foreign_count [expr {$foreign_word & 0xff}]
    set foreign_best [expr {($foreign_word >> 8) & 0xff}]
    set parent_detection [expr {($foreign_word >> 16) & 0xff}]
    set parent_wr_config [expr {($foreign_word >> 24) & 0xff}]
    set parent_is_wr [expr {($parse_word >> 24) & 1}]
    set parent_mode_on [expr {($parse_word >> 25) & 1}]
    set parent_calibrated [expr {($parse_word >> 26) & 1}]
    set wr_mode [expr {($ptp_meta_word >> 24) & 0xff}]
    set local_state [expr {($state_word >> 11) & 0xf}]
    set next_state [expr {($state_word >> 15) & 0xf}]
    set rx_msg [expr {($rx_word >> 16) & 0xffff}]
    set rx_count [expr {$rx_word & 0xffff}]
    set tx_msg [expr {($tx_word >> 16) & 0xffff}]
    set tx_count [expr {$tx_word & 0xffff}]
    set fail_role [expr {($fail_word >> 24) & 0xff}]
    set fail_state [expr {($fail_word >> 16) & 0xff}]
    set fail_count [expr {$fail_word & 0xffff}]
    set reject_reason [expr {$reject_word & 0xff}]
    set reject_count [expr {($reject_word >> 8) & 0x00ffffff}]
    set lock_result [expr {$lock_result_word & 0xff}]
    set spll_locked [expr {($lock_result_word >> 8) & 1}]
    set lock_polls_value $lock_polls_word
    set lock_enable_value $lock_enable_word
    set rcer_value $rcer_word
    set sstat_value $sstat_word
    set pstat_value $pstat_word

    puts [format "FOCUSED_SAMPLE board=%s sample=%03d valid=1 status=%02X wr_mode=%d foreign=%d/%d detection=%d wr_config=%d parent=%d/%d/%d local_state=%d next_state=%d rx=0x%04X/%d tx=0x%04X/%d fail=%d/%d/%d reject=%d/%d lock=%d/%d polls=%d enable=%d rcer=0x%08X sstat=0x%08X pstat=0x%08X" \
      $hardware_name $sample $status_low $wr_mode $foreign_count $foreign_best \
      $parent_detection $parent_wr_config $parent_is_wr $parent_mode_on \
      $parent_calibrated $local_state $next_state $rx_msg $rx_count $tx_msg \
      $tx_count $fail_role $fail_state $fail_count $reject_reason $reject_count \
      $lock_result $spll_locked $lock_polls_value $lock_enable_value \
      $rcer_value $sstat_value $pstat_value]
  } else {
    puts [format "FOCUSED_SAMPLE board=%s sample=%03d valid=0 status=%s" \
      $hardware_name $sample $status]
  }
  flush stdout
}

puts [format "FOCUSED_CONFIG samples=%d gap_ms=%d" $samples $gap_ms]
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== FOCUSED_BOARD ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_focused_sample $hardware_name $sample
      if {$sample < $samples && $gap_ms > 0} {
        after $gap_ms
      }
    }
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
puts "FOCUSED_DONE"
