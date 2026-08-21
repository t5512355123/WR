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
set ::max_read_attempts 5
array set ::focus_stats {}

proc wb_read {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set cmd [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return "TIMEOUT"
  }
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [safe_probe_read 1]
    if {![u64 $value]} {
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

proc wb_sync_toggle {} {
  set value [safe_probe_read 1]
  if {![u64 $value]} {
    set ::wb_toggle 0
    return
  }
  scan $value %x word
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
}

proc u32 {value} {
  return [regexp {^[0-9A-Fa-f]{1,8}$} $value]
}

proc u64 {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc safe_probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return "TIMEOUT"
  }
  if {![u64 $value]} { return "INVALID" }
  return $value
}

proc word32 {value} {
  if {![u32 $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc stale_jtag_word {value} {
  set word [word32 $value]
  if {$word < 0} { return 0 }
  return [expr {(($word >> 16) & 0xffff) == 0xA5A5}]
}

proc register_value_valid {addr value} {
  set word [word32 $value]
  if {$word < 0 || [stale_jtag_word $value]} { return 0 }
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
      set ptp_state [expr {$word & 0xff}]
      set mode [expr {($word >> 24) & 0xff}]
      return [expr {$ptp_state >= 1 && $ptp_state <= 9 &&
                    ($mode == 2 || $mode == 3)}]
    }
    0x00100A78 {
      set count [expr {$word & 0xff}]
      set best [expr {($word >> 8) & 0xff}]
      set detection [expr {($word >> 16) & 0xff}]
      set wr_config [expr {($word >> 24) & 0xff}]
      set no_record [expr {$count == 0 && $best == 0xff}]
      set record [expr {$count > 0 && $best < $count}]
      return [expr {($no_record || $record) &&
                    $detection <= 7 && $wr_config <= 7}]
    }
    0x00100A80 {
      return [expr {(($word >> 24) & 0xff) <= 7}]
    }
    0x00100A50 {
      set reason [expr {$word & 0xff}]
      return [expr {$reason <= 4}]
    }
    0x00100A6C {
      set role [expr {($word >> 24) & 0xff}]
      set state [expr {($word >> 16) & 0xff}]
      return [expr {$role <= 3 && $state <= 8}]
    }
    0x00100A4C {
      set tag [expr {($word >> 28) & 0xf}]
      set state [expr {($word >> 11) & 0xf}]
      set next_state [expr {($word >> 15) & 0xf}]
      set mode [expr {($word >> 21) & 0x7}]
      return [expr {$tag == 0xA && $state <= 8 && $next_state <= 8 &&
                    $mode <= 7}]
    }
    0x00100A9C {
      return 1
    }
    0x00100AA0 {
      return [expr {(($word >> 16) & 0xff) <= 3}]
    }
    0x00100AA4 - 0x00100AA8 {
      return [expr {$word <= 0xff}]
    }
  }
  return 1
}

proc wb_read_validated {addr} {
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set value [wb_read $addr]
    if {[register_value_valid $addr $value]} {
      return $value
    }
    after 2
  }
  return "INVALID"
}

proc wb_read_critical {addr} {
  # Critical enum/status fields need two consecutive source-valid reads.
  # If the mailbox keeps returning stale/filler data or a torn snapshot, the
  # field is rejected as INVALID instead of becoming a hardware failure.
  set previous ""
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set value [wb_read $addr]
    if {[register_value_valid $addr $value]} {
      if {$previous ne "" && [word32 $previous] == [word32 $value]} {
        return $value
      }
      set previous $value
    } else {
      set previous ""
    }
    after 2
  }
  return "INVALID"
}

proc counter_value_valid {value} {
  set word [word32 $value]
  return [expr {$word >= 0 && ![stale_jtag_word $value]}]
}

proc wb_read_counter {addr} {
  # Keep torn/stale counter values out of the time-series.  A counter must be
  # non-decreasing across two immediate reads; otherwise retry the mailbox
  # transaction and leave the sample invalid if it cannot be stabilized.
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set first [wb_read $addr]
    set second [wb_read $addr]
    if {[counter_value_valid $first] && [counter_value_valid $second]} {
      set a [word32 $first]
      set b [word32 $second]
      if {$b >= $a} { return [format %08X $b] }
    }
    after 2
  }
  return "INVALID"
}

proc focus_mac {mach macl} {
  set hi [word32 $mach]
  set lo [word32 $macl]
  if {$hi < 0 || $lo < 0} { return "INVALID" }
  set mid [expr {$hi & 0xffff}]
  return [format "%02X:%02X:%02X:%02X:%02X:%02X" \
    [expr {($mid >> 8) & 0xff}] [expr {$mid & 0xff}] \
    [expr {($lo >> 24) & 0xff}] [expr {($lo >> 16) & 0xff}] \
    [expr {($lo >> 8) & 0xff}] [expr {$lo & 0xff}]]
}

proc focus_init {board} {
  foreach field {valid invalid step2_candidate step3_candidate state_idle \
      state_good first_ptp_rx last_ptp_rx first_ptp_tx last_ptp_tx \
      first_tx last_tx first_rx last_rx \
      first_rxerr last_rxerr first_mac last_mac first_mode last_mode \
      first_ptp last_ptp ptp9_seen counter_decreased step3_good step3_bad \
      post_step3_timeout} {
    set ::focus_stats($board,$field) 0
  }
  set ::focus_stats($board,step2_candidate) 1
  set ::focus_stats($board,step3_candidate) 1
  set ::focus_stats($board,first_mac) ""
  set ::focus_stats($board,last_mac) ""
}

proc focus_get {board field} {
  if {[info exists ::focus_stats($board,$field)]} {
    return $::focus_stats($board,$field)
  }
  return 0
}

proc focus_note_valid {board mode ptp mac foreign_count foreign_best parent_is_wr \
    parent_cal rx_id rx_count tx_id tx_count state fail_state fail_count \
    lock_enable ptp_rx ptp_tx tx rx rxerr} {
  incr ::focus_stats($board,valid)
  if {[focus_get $board valid] > 1} {
    foreach pair [list \
        [list $ptp_rx last_ptp_rx] [list $ptp_tx last_ptp_tx] \
        [list $tx last_tx] [list $rx last_rx] [list $rxerr last_rxerr]] {
      set current [lindex $pair 0]
      set previous [focus_get $board [lindex $pair 1]]
      if {$current < $previous} { set ::focus_stats($board,counter_decreased) 1 }
    }
  }
  if {[focus_get $board first_mac] eq ""} {
    set ::focus_stats($board,first_mac) $mac
    set ::focus_stats($board,first_ptp_rx) $ptp_rx
    set ::focus_stats($board,first_ptp_tx) $ptp_tx
    set ::focus_stats($board,first_tx) $tx
    set ::focus_stats($board,first_rx) $rx
    set ::focus_stats($board,first_rxerr) $rxerr
    set ::focus_stats($board,first_ptp) $ptp
    set ::focus_stats($board,first_mode) $mode
  }
  set ::focus_stats($board,last_mac) $mac
  set ::focus_stats($board,last_ptp_rx) $ptp_rx
  set ::focus_stats($board,last_ptp_tx) $ptp_tx
  set ::focus_stats($board,last_tx) $tx
  set ::focus_stats($board,last_rx) $rx
  set ::focus_stats($board,last_rxerr) $rxerr
  set ::focus_stats($board,last_ptp) $ptp
  set ::focus_stats($board,last_mode) $mode
  if {$mode == 3 && $ptp == 9} { set ::focus_stats($board,ptp9_seen) 1 }
  if {$mode != 2 && $mode != 3} { set ::focus_stats($board,step2_candidate) 0 }
  if {$mac ne "02:00:22:33:44:01" && $mac ne "02:00:22:33:44:02"} {
    set ::focus_stats($board,step2_candidate) 0
  }
  if {$mode == 2 && ($ptp != 6 || $mac ne "02:00:22:33:44:01")} {
    set ::focus_stats($board,step2_candidate) 0
  }
  if {$mode == 3 && $ptp != 9 && $ptp != 8} {
    set ::focus_stats($board,step2_candidate) 0
  }
  if {$mode == 3 && ($foreign_count == 1 && $foreign_best == 0 &&
      $parent_is_wr == 1 && $parent_cal == 1 && $rx_id == 0x1001 &&
      $rx_count > 0 && $tx_id == 0x1000 && $tx_count > 0)} {
    incr ::focus_stats($board,step3_good)
  } elseif {$mode == 3} {
    incr ::focus_stats($board,step3_bad)
  }
  if {$mode == 3 && !($foreign_count == 1 && $foreign_best == 0 &&
      $parent_is_wr == 1 && $parent_cal == 1 && $rx_id == 0x1001 &&
      $rx_count > 0 && $tx_id == 0x1000 && $tx_count > 0)} {
    set ::focus_stats($board,step3_candidate) 0
  }
  if {$mode == 3 && $state == 0} { incr ::focus_stats($board,state_idle) }
  if {$mode == 3 && $state >= 1 && $state <= 8} { incr ::focus_stats($board,state_good) }
  if {$mode == 3 && $state == 0 && $fail_state == 2 && $fail_count > 0 &&
      $lock_enable > 0} {
    incr ::focus_stats($board,post_step3_timeout)
  }
}

proc focus_summary {board hardware_name} {
  set valid [focus_get $board valid]
  set invalid [focus_get $board invalid]
  set ptx_delta -1
  if {$valid == 0} {
    set step2 INVALID
    set step3 INVALID
  } else {
    set first_mode [focus_get $board first_mode]
    set last_mode [focus_get $board last_mode]
    set first_ptp_rx [focus_get $board first_ptp_rx]
    set last_ptp_rx [focus_get $board last_ptp_rx]
    set first_tx [focus_get $board first_tx]
    set last_tx [focus_get $board last_tx]
    set first_rx [focus_get $board first_rx]
    set last_rx [focus_get $board last_rx]
    set first_rxerr [focus_get $board first_rxerr]
    set last_rxerr [focus_get $board last_rxerr]
    set first_ptp_tx [focus_get $board first_ptp_tx]
    set last_ptp_tx [focus_get $board last_ptp_tx]
    set ptx_delta [expr {$first_ptp_tx >= 0 && $last_ptp_tx >= $first_ptp_tx ?
                         $last_ptp_tx - $first_ptp_tx : -1}]
    # PTP_TX is a useful diagnostic, but a short-window zero does not prove
    # that the packet path is broken when PTP_RX and both MiniNIC counters
    # are active.  A decrease remains invalid/retest via counter_decreased.
    set traffic_ok [expr {$first_ptp_rx >= 0 && $last_ptp_rx > $first_ptp_rx &&
                          $first_tx >= 0 && $last_tx > $first_tx &&
                          $first_rx >= 0 && $last_rx > $first_rx &&
                          $first_rxerr >= 0 && $last_rxerr == $first_rxerr}]
    set step2 [expr {[focus_get $board step2_candidate] && $valid >= 2 &&
      $first_mode == $last_mode &&
      (($last_mode == 2 && [focus_get $board first_ptp] == 6) ||
       ($last_mode == 3 && [focus_get $board ptp9_seen])) &&
      $traffic_ok ? "PASS" : "FAIL"}]
    if {[focus_get $board counter_decreased]} { set step2 INVALID }
    if {$last_mode == 3} {
      if {[focus_get $board step3_good] > 0 && [focus_get $board post_step3_timeout] > 0} {
        set step3 PASS
      } elseif {[focus_get $board step3_good] == 0 && [focus_get $board step3_bad] > 0} {
        set step3 FAIL
      } elseif {[focus_get $board step3_bad] > 0 || [focus_get $board state_idle] > 0} {
        set step3 INVALID
      } else {
        set step3 PASS
      }
    } else {
      set step3 NA
    }
  }
  puts [format "FOCUSED_GATE board=%s valid_samples=%d invalid_samples=%d counter_decreased=%d PTP_TX_DELTA=%d STEP2_REGRESSION=%s STEP3_REGRESSION=%s POST_STEP3_LOCK_STAGE=%s STATE_EVIDENCE=%s signal_good=%d signal_bad=%d state_idle=%d state_good=%d" \
    $hardware_name $valid $invalid [focus_get $board counter_decreased] $ptx_delta $step2 $step3 \
    [expr {[focus_get $board post_step3_timeout] > 0 ? "TIMEOUT" : "NOT_OBSERVED"}] \
    [expr {[focus_get $board state_idle] > 0 ? "READ_INCONSISTENT" : "STABLE"}] \
    [focus_get $board step3_good] \
    [focus_get $board step3_bad] [focus_get $board state_idle] [focus_get $board state_good]]
}

proc read_focused_sample {hardware_name sample} {
  set status [safe_probe_read 0]
  set ep_mach [wb_read_critical 0x00100124]
  set ep_macl [wb_read_critical 0x00100128]
  set ptp [wb_read_critical 0x00100A10]
  set ptp_meta [wb_read_critical 0x00100A5C]
  set ptp_rx [wb_read_counter 0x00100A54]
  set ptp_tx [wb_read_counter 0x00100A58]
  set minic_tx [wb_read_counter 0x00100A18]
  set minic_rx [wb_read_counter 0x00100A1C]
  set rxerr [wb_read_counter 0x00100A60]
  set foreign_meta [wb_read_critical 0x00100A78]
  set parse_meta [wb_read_critical 0x00100A80]
  set wr_state [wb_read_critical 0x00100A4C]
  set wr_rx [wb_read 0x00100A64]
  set wr_tx [wb_read 0x00100A68]
  set wr_fail [wb_read_critical 0x00100A6C]
  set wr_reject [wb_read_critical 0x00100A50]
  set wr_lock_result [wb_read_critical 0x00100A8C]
  set wr_lock_polls [wb_read_critical 0x00100A90]
  set wr_lock_enable [wb_read_critical 0x00100A9C]
  set rcer [wb_read_critical 0x00100AA8]
  set sstat [wb_read_critical 0x00100A08]
  set pstat [wb_read_critical 0x00100A0C]

  set valid 1
  if {![u64 $status]} {
    set valid 0
  }
  foreach value [list $ep_mach $ep_macl $ptp $ptp_meta $ptp_rx $ptp_tx \
      $minic_tx $minic_rx $rxerr $foreign_meta $parse_meta $wr_state \
      $wr_rx $wr_tx $wr_fail $wr_reject $wr_lock_result $wr_lock_polls \
      $wr_lock_enable $rcer $sstat $pstat] {
    if {![u32 $value]} {
      set valid 0
    }
  }

  if {$valid} {
    scan $status %x status_word
    scan $ep_mach %x ep_mach_word
    scan $ep_macl %x ep_macl_word
    scan $ptp %x ptp_word
    scan $ptp_meta %x ptp_meta_word
    scan $ptp_rx %x ptp_rx_word
    scan $ptp_tx %x ptp_tx_word
    scan $minic_tx %x minic_tx_word
    scan $minic_rx %x minic_rx_word
    scan $rxerr %x rxerr_word
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
    set mac [focus_mac $ep_mach $ep_macl]
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

    focus_note_valid $hardware_name $wr_mode $ptp_word $mac \
      $foreign_count $foreign_best $parent_is_wr $parent_calibrated \
      $rx_msg $rx_count $tx_msg $tx_count $local_state \
      $fail_state $fail_count $lock_enable_value \
      $ptp_rx_word $ptp_tx_word $minic_tx_word $minic_rx_word $rxerr_word

    puts [format "FOCUSED_SAMPLE board=%s sample=%03d valid=1 status=%02X mac=%s mode=%d ptp=%d ptp_rx=%d ptp_tx=%d minic_tx=%d minic_rx=%d rxerr=%d foreign=%d/%d detection=%d wr_config=%d parent=%d/%d/%d local_state=%d next_state=%d rx=0x%04X/%d tx=0x%04X/%d fail=%d/%d/%d reject=%d/%d lock=%d/%d polls=%d enable=%d rcer=0x%08X sstat=0x%08X pstat=0x%08X" \
      $hardware_name $sample $status_low $mac $wr_mode $ptp_word $ptp_rx_word $ptp_tx_word \
      $minic_tx_word $minic_rx_word $rxerr_word $foreign_count $foreign_best \
      $parent_detection $parent_wr_config $parent_is_wr $parent_mode_on \
      $parent_calibrated $local_state $next_state $rx_msg $rx_count $tx_msg \
      $tx_count $fail_role $fail_state $fail_count $reject_reason $reject_count \
      $lock_result $spll_locked $lock_polls_value $lock_enable_value \
      $rcer_value $sstat_value $pstat_value]
  } else {
    incr ::focus_stats($hardware_name,invalid)
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
  focus_init $hardware_name
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
  focus_summary $hardware_name $hardware_name
  catch { end_insystem_source_probe }
}
puts "FOCUSED_DONE"
