# White Rabbit JTAG 唯讀時間序列觀測：每張板只建立一次 source probe。
#
# 用法：
#   quartus_stp -t read_wb_timeseries_session.tcl ?samples? ?gap_ms? ?max_retries?
#
# 本腳本不寫入 WR 設定，也不寫入 DATA_SNAPSHOT；只透過既有 mailbox
# 讀取診斷 register。CTRL_BEGIN/CTRL_END 用來標記該列是否可採信。

package require ::quartus::insystem_source_probe

set samples 60
set gap_ms 1000
set max_retries 3
if {[llength $argv] >= 1} {
  set samples [expr {int([lindex $argv 0])}]
}
if {[llength $argv] >= 2} {
  set gap_ms [expr {int([lindex $argv 1])}]
}
if {[llength $argv] >= 3} {
  set max_retries [expr {int([lindex $argv 2])}]
}
if {$samples <= 0 || $gap_ms < 0 || $max_retries < 0} {
  error "samples must be > 0, gap_ms must be >= 0, and max_retries must be >= 0"
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

proc is_u32 {value} {
  return [regexp {^[0-9A-Fa-f]{1,8}$} $value]
}

proc read_diag_sample {hardware_name sample attempt} {
  set status [read_probe_data -instance_index 0 -value_in_hex]
  set ctrl_begin [wb_read 0x00100904]
  set ver [wb_read 0x00100900]
  set spll_csr [wb_read 0x00100200]
  set spll_eccr [wb_read 0x00100204]
  set spll_occr [wb_read 0x00100210]
  set sstat [wb_read 0x00100908]
  set pstat [wb_read 0x0010090C]
  set ptp [wb_read 0x00100910]
  set ptp_rx [wb_read 0x00100954]
  set ptp_tx [wb_read 0x00100958]
  set ptp_meta [wb_read 0x0010095C]
  set foreign_meta [wb_read 0x00100978]
  set filter_meta [wb_read 0x0010097C]
  set parse_meta [wb_read 0x00100980]
  set dms_h [wb_read 0x00100934]
  set dms_l [wb_read 0x00100938]
  set cko [wb_read 0x00100940]
  set setp [wb_read 0x00100944]
  set ucnt [wb_read 0x00100948]
  set pps_cr [wb_read 0x00100300]
  set pps_escr [wb_read 0x0010031C]
  set spll_hy [wb_read 0x00100984]
  set spll_my [wb_read 0x00100988]
  set spll_csr_end [wb_read 0x00100200]
  set spll_eccr_end [wb_read 0x00100204]
  set spll_occr_end [wb_read 0x00100210]
  set ctrl_end [wb_read 0x00100904]

  set frame_valid 1
  foreach value [list $ctrl_begin $ver $spll_csr $spll_eccr $spll_occr \
      $sstat $pstat $ptp $ptp_rx $ptp_tx \
      $ptp_meta $foreign_meta $filter_meta $parse_meta $dms_h $dms_l \
      $cko $setp $ucnt $pps_cr $pps_escr $spll_hy $spll_my \
      $spll_csr_end $spll_eccr_end $spll_occr_end $ctrl_end] {
    if {![is_u32 $value]} {
      set frame_valid 0
    }
  }
  if {$frame_valid} {
    scan $ctrl_begin %x ctrl_begin_word
    scan $ctrl_end %x ctrl_end_word
    set frame_valid [expr {(($ctrl_begin_word & 1) != 0) &&
                           (($ctrl_end_word & 1) != 0) &&
                           ($ctrl_begin_word == $ctrl_end_word)}]
  }
  set spll_block_valid [expr {$spll_csr == $spll_csr_end &&
                              $spll_eccr == $spll_eccr_end &&
                              $spll_occr == $spll_occr_end}]
  set frame_valid [expr {$frame_valid && $spll_block_valid}]

  scan $status %x status_word
  set status_low [expr {$status_word & 0xff}]
  set time_valid [expr {($status_low >> 4) & 1}]
  set pps_valid [expr {($status_low >> 5) & 1}]
  scan $sstat %x sstat_word
  set wr_valid [expr {$sstat_word & 1}]
  set servo_state [expr {($sstat_word >> 8) & 0xf}]
  scan $pstat %x pstat_word
  set link_up [expr {$pstat_word & 1}]
  set spll_locked [expr {($pstat_word >> 1) & 1}]
  scan $ptp_meta %x ptp_meta_word
  set wr_mode [expr {($ptp_meta_word >> 24) & 0xff}]
  scan $foreign_meta %x foreign_word
  set foreign_count [expr {$foreign_word & 0xff}]
  set foreign_best [expr {($foreign_word >> 8) & 0xff}]
  set parent_detection [expr {($foreign_word >> 16) & 0xff}]
  set parent_wr_config [expr {($foreign_word >> 24) & 0xff}]
  scan $parse_meta %x parse_word
  set parent_is_wr [expr {($parse_word >> 24) & 1}]
  set parent_wr_mode_on [expr {($parse_word >> 25) & 1}]
  set parent_calibrated [expr {($parse_word >> 26) & 1}]

  puts [format "SESSION_SAMPLE board=%s sample=%03d attempt=%d status=%s" \
        $hardware_name $sample $attempt $status]
  puts [format "FRAME_VALID: %d CTRL_BEGIN=%s CTRL_END=%s RETRY_INDEX=%d" \
        $frame_valid $ctrl_begin $ctrl_end $attempt]
  puts [format "SPLL_BLOCK_VALID: %d A=%s/%s/%s B=%s/%s/%s" \
        $spll_block_valid $spll_csr $spll_eccr $spll_occr \
        $spll_csr_end $spll_eccr_end $spll_occr_end]
  puts "WDIAGS_VER:$ver SPLL_CSR:$spll_csr SPLL_ECCR:$spll_eccr SPLL_OCCR:$spll_occr"
  puts "WDIAGS_SSTAT:$sstat WDIAGS_PSTAT:$pstat WDIAGS_PTP:$ptp"
  puts "WDIAGS_PTP_RX:$ptp_rx WDIAGS_PTP_TX:$ptp_tx WDIAGS_PTP_META:$ptp_meta"
  puts "WDIAGS_FOREIGN_META:$foreign_meta WDIAGS_FILTER_META:$filter_meta WDIAGS_PARSE_META:$parse_meta"
  puts "WDIAGS_DMS_H:$dms_h WDIAGS_DMS_L:$dms_l WDIAGS_CKO:$cko WDIAGS_SETP:$setp WDIAGS_UCNT:$ucnt"
  puts "PPS_CR:$pps_cr PPS_ESCR:$pps_escr WDIAGS_SPLL_HY:$spll_hy WDIAGS_SPLL_MY:$spll_my"
  puts [format "DECODE: status_low=%02X time_valid=%d pps_valid=%d wr_mode=%d sstat_wr_valid=%d servo_state=%d link_up=%d spll_locked=%d" \
        $status_low $time_valid $pps_valid $wr_mode $wr_valid $servo_state $link_up $spll_locked]
  puts [format "PARENT: foreign_count=%d foreign_best=%d detection=%d wr_config=%d is_wr=%d mode_on=%d calibrated=%d" \
        $foreign_count $foreign_best $parent_detection $parent_wr_config \
        $parent_is_wr $parent_wr_mode_on $parent_calibrated]
  flush stdout
  return $frame_valid
}

puts [format "SESSION_TIME_SERIES_CONFIG samples=%d gap_ms=%d max_retries=%d" \
      $samples $gap_ms $max_retries]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== SESSION_BOARD ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set accepted 0
      for {set attempt 0} {$attempt <= $max_retries} {incr attempt} {
        set accepted [read_diag_sample $hardware_name $sample $attempt]
        if {$accepted} {
          break
        }
        if {$attempt < $max_retries} {
          after 10
        }
      }
      set retries_used [expr {$attempt > $max_retries ? $max_retries : $attempt}]
      puts [format "SESSION_SAMPLE_RESULT board=%s sample=%03d accepted=%d retries=%d" \
            $hardware_name $sample $accepted $retries_used]
      flush stdout
      if {$sample < $samples && $gap_ms > 0} {
        after $gap_ms
      }
    }
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "SESSION_TIME_SERIES_DONE"
