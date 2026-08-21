# White Rabbit Master PTP / Slave parent 長時間唯讀觀測。
#
# 用法：
#   quartus_stp -t read_master_ptp_slave_parent_long.tcl ?samples? ?gap_ms?
#
# 預設為 150 筆、每筆間隔 2 秒，約 5 分鐘。只讀既有 status probe 與
# Wishbone diagnostic mailbox，不寫入 WR 設定、不寫 DATA_SNAPSHOT，也不
# 需要重新編譯或燒錄。欄位刻意保持精簡，以降低 JTAG 觀測本身的干擾。

package require ::quartus::insystem_source_probe

set samples 150
set gap_ms 2000
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
set ::max_read_attempts 5

proc wb_sync_toggle {} {
  set value [read_probe_data -instance_index 1 -value_in_hex]
  if {![regexp {^[0-9A-Fa-f]{1,16}$} $value]} {
    set ::wb_toggle 0
    return
  }
  scan $value %x word
  set current_done [expr {(($word >> 35) & 1)}]
  set ::wb_toggle $current_done
}

proc wb_read {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set cmd [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [read_probe_data -instance_index 1 -value_in_hex]
    if {![regexp {^[0-9A-Fa-f]{1,16}$} $value]} {
      after 1
      continue
    }
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

proc word32 {value} {
  if {![regexp {^[0-9A-Fa-f]{1,8}$} $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc validated_register {addr value} {
  set word [word32 $value]
  if {$word < 0 || ((($word >> 16) & 0xffff) == 0xA5A5)} { return 0 }
  set key [format "0x%08X" [expr {$addr & 0xffffffff}]]
  switch -- $key {
    0x00100124 {
      return [expr {$word == 0x02000200}]
    }
    0x00100128 {
      return [expr {$word == 0x22334401 || $word == 0x22334402}]
    }
    0x00100A10 {
      return [expr {$word >= 1 && $word <= 9}]
    }
    0x00100A5C {
      set state [expr {$word & 0xff}]
      set mode [expr {($word >> 24) & 0xff}]
      return [expr {$state >= 1 && $state <= 9 && ($mode == 2 || $mode == 3)}]
    }
    0x00100A78 {
      set count [expr {$word & 0xff}]
      set best [expr {($word >> 8) & 0xff}]
      set detection [expr {($word >> 16) & 0xff}]
      set config [expr {($word >> 24) & 0xff}]
      return [expr {(($count == 0 && $best == 0xff) ||
                    ($count > 0 && $best < $count)) &&
                    $detection <= 7 && $config <= 7}]
    }
    0x00100A80 {
      return [expr {(($word >> 24) & 0xff) <= 7}]
    }
    0x00100AA0 {
      return [expr {(($word >> 16) & 0xff) <= 3}]
    }
  }
  return 1
}

proc wb_read_validated {addr} {
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set value [wb_read $addr]
    if {[validated_register $addr $value]} { return $value }
    after 2
  }
  return "INVALID"
}

proc read_min_sample {board sample} {
  set status [read_probe_data -instance_index 0 -value_in_hex]
  set marker_raw [read_probe_data -instance_index 3 -value_in_hex]
  set cpu_raw [read_probe_data -instance_index 2 -value_in_hex]

  scan $status %x status_word
  scan $marker_raw %x marker_word
  scan $cpu_raw %x cpu_word

  set status_low [expr {$status_word & 0xff}]
  set marker [expr {$marker_word & 0xffffffff}]
  set marker_seen [expr {(($marker_word >> 32) & 1)}]
  set cpu_fault [expr {(($cpu_word >> 33) & 1)}]
  set im_valid [expr {(($cpu_word >> 34) & 1)}]

  set sstat [wb_read 0x00100A08]
  set pstat [wb_read 0x00100A0C]
  set ptp [wb_read_validated 0x00100A10]
  set ptp_rx [wb_read 0x00100A54]
  set ptp_tx [wb_read 0x00100A58]
  set ptp_meta [wb_read_validated 0x00100A5C]
  set foreign_meta [wb_read_validated 0x00100A78]
  set parse_meta [wb_read_validated 0x00100A80]
  set spll_state [wb_read_validated 0x00100AA0]
  set spll_ocer [wb_read 0x00100AA4]
  set spll_rcer [wb_read 0x00100AA8]
  set spll_occr [wb_read 0x00100AAC]
  set spll_trr_csr [wb_read 0x00100AB0]
  set spll_eic_imr [wb_read 0x00100AF0]
  set spll_eic_isr [wb_read 0x00100AF4]
  set ref_count [wb_read 0x00100AD0]
  set tag_count [wb_read 0x00100AD4]
  set helper_error [wb_read 0x00100AD8]
  set irq_count [wb_read 0x00100AEC]
  set tag_valid [wb_read 0x00100AF8]
  set trr_write [wb_read 0x00100AFC]
  set tag_source [wb_read 0x0010028C]

  set valid 1
  foreach value [list $status $marker_raw $cpu_raw $ptp $ptp_meta \
      $foreign_meta $parse_meta $spll_state] {
    if {![regexp {^[0-9A-Fa-f]{1,16}$} $value]} { set valid 0 }
  }
  if {!$valid} {
    puts [format "MIN_SAMPLE board=%s sample=%03d valid=0 STATUS=%s PTP=%s PTP_META=%s FOREIGN=%s PARSE=%s SPLL_STATE=%s" \
      $board $sample $status $ptp $ptp_meta $foreign_meta $parse_meta $spll_state]
    flush stdout
    return
  }

  scan $ptp_meta %x ptp_meta_word
  set mode [expr {(($ptp_meta_word >> 24) & 0xff)}]
  puts [format "MIN_SAMPLE board=%s sample=%03d status=%02X marker=%08X seen=%d fault=%d im_valid=%d MODE=%d PTP=%s PTP_RX=%s PTP_TX=%s SSTAT=%s PSTAT=%s FOREIGN=%s PARSE=%s SPLL_STATE=%s OCER=%s RCER=%s OCCR=%s TRR_CSR=%s EIC_IMR=%s EIC_ISR=%s REF=%s TAG=%s TAG_SOURCE=%s TAG_VALID=%s TRR_WRITE=%s IRQ=%s HELPER_ERROR=%s" \
        $board $sample $status_low $marker $marker_seen $cpu_fault $im_valid \
        $mode $ptp $ptp_rx $ptp_tx $sstat $pstat $foreign_meta $parse_meta \
        $spll_state $spll_ocer $spll_rcer $spll_occr $spll_trr_csr \
        $spll_eic_imr $spll_eic_isr $ref_count $tag_count $tag_source $tag_valid $trr_write \
        $irq_count $helper_error]
  flush stdout
}

puts [format "MINIMAL_RUNTIME_CONFIG samples=%d gap_ms=%d" $samples $gap_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== MINIMAL_BOARD ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_min_sample $hardware_name $sample
      if {$sample < $samples && $gap_ms > 0} {
        after $gap_ms
      }
    }
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "MINIMAL_RUNTIME_DONE"
