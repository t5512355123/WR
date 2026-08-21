# DE5a White Rabbit runtime health dashboard。
#
# 這是一份 read-only JTAG 診斷腳本：
#   - instance 0..7 是 Direct Probe，只讀取目前訊號。
#   - instance 1 的 mailbox 只送出 Wishbone read，不送出 write。
#   - counter 以同一 JTAG session 的 before/after delta 判斷 activity。
#   - TIMEOUT 永遠保留為無效證據，不會被轉成 0，也不會直接判定硬體失敗。
#
# 使用：
#   quartus_stp -t read_wb_runtime.tcl

package require ::quartus::insystem_source_probe

set ::wb_toggle 0
array set ::snap {}
array set ::board_name {}
array set ::step_status {}
array set ::first_anomaly {}
set ::board_count 0

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]+$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 8} {
    set text [string range $text end-7 end]
  }
  scan $text %x word
  return [expr {$word & 0xffffffff}]
}

proc probe_low32 {value} {
  return [word32 $value]
}

proc probe_high32 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  set text [string repeat 0 [expr {16 - [string length $text]}]]$text
  scan [string range $text 0 7] %x word
  return [expr {$word & 0xffffffff}]
}

proc low16 {value} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return [expr {$word & 0xffff}]
}

proc bit32 {value bit} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc bit64_low {value bit} {
  set word [probe_low32 $value]
  if {$word < 0 || $bit < 0 || $bit > 31} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc bit64_high {value bit} {
  set word [probe_high32 $value]
  if {$word < 0 || $bit < 0 || $bit > 31} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc field32 {value low width} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($word >> $low) & $mask}]
}

proc delta32 {before after} {
  set a [word32 $before]
  set b [word32 $after]
  if {$a < 0 || $b < 0} { return "TIMEOUT" }
  if {$b >= $a} { return [expr {$b - $a}] }
  # A diagnostic counter can be reset or rewritten between snapshots.  Do
  # not turn a decrease into a fabricated wrap-around activity delta.
  return "DECREASED"
}

proc status_rank {status} {
  switch -- $status {
    PASS { return 0 }
    INFO { return 1 }
    WARN { return 2 }
    FAIL { return 3 }
  }
  return 1
}

proc merge_status {current candidate} {
  if {[status_rank $candidate] > [status_rank $current]} {
    return $candidate
  }
  return $current
}

proc status_text {status} {
  switch -- $status {
    PASS { return "正常" }
    WARN { return "注意" }
    FAIL { return "異常" }
    INFO { return "資訊" }
  }
  return $status
}

proc mark_anomaly {board step status text} {
  if {$status eq "PASS" || $status eq "INFO"} { return }
  if {![info exists ::first_anomaly($board)] || $::first_anomaly($board) eq ""} {
    set ::first_anomaly($board) "Step $step：$text"
  }
}

proc exact_status {value expected} {
  if {$value eq "TIMEOUT" || $value < 0} { return "WARN" }
  if {$value == $expected} { return "PASS" }
  return "FAIL"
}

proc positive_status {value} {
  if {$value eq "TIMEOUT" || $value < 0} { return "WARN" }
  if {$value > 0} { return "PASS" }
  return "WARN"
}

proc required_positive_status {value} {
  if {$value eq "TIMEOUT" || $value < 0} { return "WARN" }
  if {$value > 0} { return "PASS" }
  return "FAIL"
}

proc delta_status {value} {
  if {$value eq "TIMEOUT" || $value eq "DECREASED" || $value < 0} { return "WARN" }
  if {$value > 0} { return "PASS" }
  return "WARN"
}

proc required_delta_status {value} {
  if {$value eq "TIMEOUT" || $value eq "DECREASED"} { return "WARN" }
  if {$value < 0} { return "WARN" }
  if {$value > 0} { return "PASS" }
  return "FAIL"
}

proc raw_display {value} {
  if {$value eq "TIMEOUT"} { return "TIMEOUT" }
  if {![is_hex $value]} { return $value }
  return [format "0x%08X" [word32 $value]]
}

proc state_name {state} {
  switch -- $state {
    0 { return "SEQ_START_EXT" }
    1 { return "SEQ_WAIT_EXT" }
    2 { return "SEQ_START_HELPER" }
    3 { return "SEQ_WAIT_HELPER" }
    4 { return "SEQ_START_MAIN" }
    5 { return "SEQ_WAIT_MAIN" }
    6 { return "SEQ_DISABLED" }
    7 { return "SEQ_READY" }
    8 { return "SEQ_CLEAR_DACS" }
    9 { return "SEQ_WAIT_CLEAR_DACS" }
  }
  return "UNKNOWN"
}

proc wr_state_name {state} {
  switch -- $state {
    0 { return "WRS_IDLE" }
    1 { return "WRS_PRESENT" }
    2 { return "WRS_S_LOCK" }
    3 { return "WRS_M_LOCK" }
    4 { return "WRS_LOCKED" }
    5 { return "WRS_CALIBRATION" }
    6 { return "WRS_CALIBRATED" }
    7 { return "WRS_RESP_CALIB_REQ" }
    8 { return "WRS_WR_LINK_ON" }
  }
  return "UNKNOWN"
}

proc ptp_state_name {state} {
  switch -- $state {
    1 { return "INITIALIZING" }
    2 { return "FAULTY" }
    3 { return "DISABLED" }
    4 { return "LISTENING" }
    5 { return "PRE_MASTER" }
    6 { return "MASTER" }
    7 { return "PASSIVE" }
    8 { return "UNCALIBRATED" }
    9 { return "SLAVE" }
  }
  return "UNKNOWN"
}

proc spll_mode_name {mode} {
  switch -- $mode {
    0 { return "SPLL_MODE_DISABLED" }
    1 { return "SPLL_MODE_GRAND_MASTER" }
    2 { return "SPLL_MODE_FREE_RUNNING_MASTER" }
    3 { return "SPLL_MODE_SLAVE" }
  }
  return "UNKNOWN"
}

proc signal_name {message_id} {
  switch -- $message_id {
    4096 { return "SLAVE_PRESENT" }
    4097 { return "LOCK" }
    4098 { return "LOCKED" }
    4099 { return "CALIBRATE" }
    4100 { return "CALIBRATED" }
    4101 { return "WR_MODE_ON" }
  }
  return "UNKNOWN"
}

proc mac_from_registers {mach macl} {
  set hi [word32 $mach]
  set lo [word32 $macl]
  if {$hi < 0 || $lo < 0} { return "TIMEOUT" }
  set mid [expr {$hi & 0xffff}]
  return [format "%02X:%02X:%02X:%02X:%02X:%02X" \
    [expr {($mid >> 8) & 0xff}] [expr {$mid & 0xff}] \
    [expr {($lo >> 24) & 0xff}] [expr {($lo >> 16) & 0xff}] \
    [expr {($lo >> 8) & 0xff}] [expr {$lo & 0xff}]]
}

proc wb_read {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set cmd [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [read_probe_data -instance_index 1 -value_in_hex]
    set word [probe_low32 $value]
    set done_toggle [bit64_high $value 3]
    set active [bit64_high $value 4]
    if {$word >= 0 && $done_toggle == $::wb_toggle && $active == 0} {
      return [format %08X $word]
    }
    after 1
  }
  return "TIMEOUT"
}

proc wb_sync_toggle {} {
  # 只讀取 mailbox completion 狀態；不寫入控制 register。
  set value [read_probe_data -instance_index 1 -value_in_hex]
  set current_done [bit64_high $value 3]
  if {$current_done < 0} { set current_done 0 }
  set ::wb_toggle $current_done
  puts [format {[資訊] mailbox completion toggle (wb_sync_toggle) = %d；僅同步讀取狀態} $current_done]
}

proc put_snap {board label field value} {
  set ::snap($board,$label,$field) $value
}

proc get_snap {board label field} {
  if {[info exists ::snap($board,$label,$field)]} {
    return $::snap($board,$label,$field)
  }
  return "TIMEOUT"
}

proc collect_snapshot {board label} {
  put_snap $board $label status [read_probe_data -instance_index 0 -value_in_hex]
  put_snap $board $label cpu [read_probe_data -instance_index 2 -value_in_hex]
  put_snap $board $label marker [read_probe_data -instance_index 3 -value_in_hex]
  put_snap $board $label store [read_probe_data -instance_index 4 -value_in_hex]
  put_snap $board $label store_count [read_probe_data -instance_index 5 -value_in_hex]
  put_snap $board $label exception [read_probe_data -instance_index 6 -value_in_hex]
  put_snap $board $label clock [read_probe_data -instance_index 7 -value_in_hex]

  put_snap $board $label pps_cr [wb_read 0x00100300]
  put_snap $board $label pps_escr [wb_read 0x0010031C]
  put_snap $board $label ep_mach [wb_read 0x00100124]
  put_snap $board $label ep_macl [wb_read 0x00100128]
  put_snap $board $label ep_dsr [wb_read 0x00100138]
  put_snap $board $label ptp [wb_read 0x00100A10]
  put_snap $board $label ptp_rx [wb_read 0x00100A54]
  put_snap $board $label ptp_tx [wb_read 0x00100A58]
  put_snap $board $label ptp_meta [wb_read 0x00100A5C]
  put_snap $board $label tx [wb_read 0x00100A18]
  put_snap $board $label rx [wb_read 0x00100A1C]
  put_snap $board $label rxerr [wb_read 0x00100A60]
  put_snap $board $label ptp_types [wb_read 0x00100A74]
  put_snap $board $label foreign_meta [wb_read 0x00100A78]
  put_snap $board $label filter_meta [wb_read 0x00100A7C]
  put_snap $board $label parse_meta [wb_read 0x00100A80]
  put_snap $board $label wr_rx_signal [wb_read 0x00100A64]
  put_snap $board $label wr_tx_signal [wb_read 0x00100A68]
  put_snap $board $label wr_failure [wb_read 0x00100A6C]
  put_snap $board $label wr_state [wb_read 0x00100A4C]
  put_snap $board $label wr_reject [wb_read 0x00100A50]
  put_snap $board $label pstat [wb_read 0x00100A0C]
  put_snap $board $label sstat [wb_read 0x00100A08]
  put_snap $board $label sec_h [wb_read 0x00100A20]
  put_snap $board $label sec_l [wb_read 0x00100A24]
  put_snap $board $label ns [wb_read 0x00100A28]

  # 這些地址與既有 Step 4 read-only scripts/source mapping 一致。
  put_snap $board $label lock_enable [wb_read 0x00100A9C]
  put_snap $board $label spll_state [wb_read 0x00100AA0]
  put_snap $board $label spll_ocer [wb_read 0x00100AA4]
  put_snap $board $label spll_rcer [wb_read 0x00100AA8]
  put_snap $board $label spll_trr_csr [wb_read 0x00100AB0]
  put_snap $board $label dmtd_ref [wb_read 0x00100298]
  put_snap $board $label dmtd_fb [wb_read 0x0010029C]
  put_snap $board $label dmtd_ref_seen [wb_read 0x001002A0]
  put_snap $board $label dmtd_fb_seen [wb_read 0x001002A4]
  put_snap $board $label tag_valid [wb_read 0x00100284]
  put_snap $board $label trr_write [wb_read 0x00100288]
  put_snap $board $label irq [wb_read 0x00100AEC]
  put_snap $board $label helper_update [wb_read 0x00100B18]
  put_snap $board $label eic_isr [wb_read 0x0010026C]
  put_snap $board $label current_tics [wb_read 0x00100B3C]
}

proc print_signal {status chinese symbol value expected explanation} {
  puts [format {[%s] %s (%s) = %s} [status_text $status] $chinese $symbol $value]
  puts [format {      預期值：%s；解釋：%s} $expected $explanation]
}

proc print_delta {status chinese symbol before after delta explanation {expected "delta > 0"}} {
  puts [format {[%s] %s (%s) = before=%s after=%s delta=%s} \
    [status_text $status] $chinese $symbol $before $after $delta]
  puts [format {      預期值：%s；解釋：%s} $expected $explanation]
}

proc analyze_board {board} {
  set name $::board_name($board)
  set before before
  set after after
  set ::first_anomaly($board) ""
  puts ""
  puts "================================================================"
  puts [format "White Rabbit runtime health dashboard：%s" $name]
  puts "================================================================"

  # --------------------------------------------------------------
  # Step 1: status probe / PHY link
  # --------------------------------------------------------------
  puts ""
  puts "\[Step 1\] PHY / 光纖 Link"
  set step1 PASS
  set status_raw [get_snap $board $after status]
  foreach item {
    {0 si_config_done {Silicon Interface 設定完成} 1}
    {1 wr_ready {WR core 就緒} 1}
    {2 core_tm_link_up {WR timing link 已建立} 1}
    {3 core_link_ok {WR link 檢查} 1}
    {6 wr_rx_ready {WR RX 就緒} 1}
    {7 wr_tx_ready {WR TX 就緒} 1}
    {11 core_phy_rst {PHY reset} 0}
    {12 si_id_error {Silicon Interface ID error} 0}
    {13 wr_rx_enc_err {WR RX encoding error} 0}
    {14 wr_tx_enc_err {WR TX encoding error} 0}
    {15 CPU_RESET_n {CPU reset 已解除} 1}
  } {
    set bit [lindex $item 0]
    set symbol [lindex $item 1]
    set chinese [lindex $item 2]
    set expected [lindex $item 3]
    set value [bit64_low $status_raw $bit]
    set current [exact_status $value $expected]
    set step1 [merge_status $step1 $current]
    set display [expr {$value < 0 ? "TIMEOUT" : $value}]
    set expected_text [expr {$expected == 1 ? "1 (正常為 High)" : "0 (正常為 Low)"}]
    set explanation "此欄位由 instance 0 status probe 提供；不涉及 Wishbone transaction。"
    print_signal $current $chinese $symbol $display $expected_text $explanation
  }
  set value [bit64_high $status_raw 0]
  set rx_data_lock_status [exact_status $value 1]
  print_signal $rx_data_lock_status "RX locked to data" wr_rx_locked_to_data \
    [expr {$value < 0 ? "TIMEOUT" : $value}] "1" \
    "instance 0 status probe bit 32；表示 recovered RX path 已鎖到資料。"
  set step1 [merge_status $step1 $rx_data_lock_status]
  set value [bit64_high $status_raw 1]
  print_signal INFO "RX lock to reference" wr_rx_locked_to_ref \
    [expr {$value < 0 ? "TIMEOUT" : $value}] "依當次 PHY 狀態觀察" \
    "高 32 bit 的 bit 1；此欄位不是 RX lock to data 的替代品。"
  foreach raw_item {{8 MOD_PRS_n module-present pin 的原始 High/Low} {9 INTERRUPT_n interrupt pin 的原始 High/Low}} {
    set bit [lindex $raw_item 0]
    set value [bit64_low $status_raw $bit]
    print_signal INFO [lindex $raw_item 1] [lindex $raw_item 1] \
      [expr {$value < 0 ? "TIMEOUT" : $value}] "只保留 raw pin 值" \
      [lindex $raw_item 2]
  }
  if {$step1 ne "PASS"} { mark_anomaly $board 1 $step1 "instance 0 status probe 的 PHY/link gate" }
  set ::step_status($board,1) $step1
  puts [format {Step 1 結果：[%s] %s} [status_text $step1] $step1]

  # --------------------------------------------------------------
  # Step 2: endpoint / MiniNIC / PTP
  # --------------------------------------------------------------
  puts ""
  puts "\[Step 2\] Endpoint / MiniNIC / PTP"
  set step2 PASS
  set mach [get_snap $board $after ep_mach]
  set macl [get_snap $board $after ep_macl]
  set mac [mac_from_registers $mach $macl]
  set ptp_meta [get_snap $board $after ptp_meta]
  set mode [field32 $ptp_meta 24 8]
  set ptp [word32 [get_snap $board $after ptp]]
  set role "UNKNOWN"
  if {$mode == 2} { set role MASTER }
  if {$mode == 3} { set role SLAVE }
  puts [format {[資訊] Endpoint MAC address (EP_MAC_H/EP_MAC_L) = %s；raw H=%s L=%s} \
    $mac [raw_display $mach] [raw_display $macl]]
  if {$role eq "MASTER"} {
    puts "      預期值：02:00:22:33:44:01；解釋：Master 的唯一 clock identity。"
    if {$mac eq "TIMEOUT"} {
      set step2 [merge_status $step2 WARN]
    } elseif {$mac ne "02:00:22:33:44:01"} {
      set step2 FAIL
    }
    set mode_status [exact_status $mode 2]
    set ptp_status [exact_status $ptp 6]
  } elseif {$role eq "SLAVE"} {
    puts "      預期值：02:00:22:33:44:02；解釋：Slave 的唯一 clock identity。"
    if {$mac eq "TIMEOUT"} {
      set step2 [merge_status $step2 WARN]
    } elseif {$mac ne "02:00:22:33:44:02"} {
      set step2 FAIL
    }
    set mode_status [exact_status $mode 3]
    if {$ptp == 8} { set ptp_status WARN } else { set ptp_status [exact_status $ptp 9] }
  } else {
    puts "      預期值：依 WDIAGS_MODE 判斷 Master/Slave；解釋：目前無法從 source-backed mode 判定角色。"
    set mode_status WARN
    set ptp_status WARN
  }
  set step2 [merge_status $step2 $mode_status]
  set step2 [merge_status $step2 $ptp_status]
  puts [format {[%s] PTP 狀態 (WDIAGS_PTP) = %s (%s)} [status_text $ptp_status] \
    [expr {$ptp < 0 ? "TIMEOUT" : $ptp}] [ptp_state_name $ptp]]
  if {$role eq "MASTER"} {
    set ptp_expectation "6 (MASTER)"
  } elseif {$role eq "SLAVE"} {
    set ptp_expectation "9 (SLAVE；startup 可暫時 8)"
  } else {
    set ptp_expectation "依角色"
  }
  puts [format {      預期值：%s；解釋：PTP state 由 source-backed WDIAGS_PTP 讀值解碼。} $ptp_expectation]
  puts [format {[%s] WDIAGS_MODE (WDIAGS_MODE) = %s (%s)} [status_text $mode_status] \
    [expr {$mode < 0 ? "TIMEOUT" : $mode}] [expr {$mode == 2 ? "MASTER" : ($mode == 3 ? "SLAVE" : "UNKNOWN")}]]
  puts "      預期值：Master=2、Slave=3；解釋：source-backed configured WRC mode，不是 PTP state。"

  foreach counter {
    {ptp_rx "PPSI PTP RX counter" WDIAGS_PTP_RX "PPSI-level PTP RX counter"}
    {ptp_tx "PPSI PTP TX counter" WDIAGS_PTP_TX "PPSI-level PTP TX counter"}
    {tx "MiniNIC TX frame counter" WDIAGS_TX "minic_get_stats() 的 frame-level TX counter"}
    {rx "MiniNIC RX frame counter" WDIAGS_RX "minic_get_stats() 的 frame-level RX counter"}
  } {
    set field [lindex $counter 0]
    set chinese [lindex $counter 1]
    set symbol [lindex $counter 2]
    set explanation [lindex $counter 3]
    set b [get_snap $board $before $field]
    set a [get_snap $board $after $field]
    set d [delta32 $b $a]
    set current [delta_status $d]
    set step2 [merge_status $step2 $current]
    print_delta $current $chinese $symbol \
      [raw_display $b] [raw_display $a] [expr {$d eq "TIMEOUT" ? "TIMEOUT" : [format "0x%08X" $d]}] \
      "$explanation；delta > 0 才代表本次觀測期間有 activity。"
  }
  set rb [get_snap $board $before rxerr]
  set ra [get_snap $board $after rxerr]
  set rd [delta32 $rb $ra]
  if {$rd eq "TIMEOUT"} {
    set rxerr_status WARN
    set rxerr_explanation "JTAG snapshot 至少一筆逾時，沒有足夠證據判斷新增 RX error。"
    set rxerr_expected "兩次有效讀值且 delta=0"
  } elseif {$rd eq "DECREASED"} {
    # A decrease is not a new error. It is compatible with reset, clear, or
    # a non-atomic snapshot boundary, so keep it informational for Step 2.
    set rxerr_status INFO
    set rxerr_explanation "after 小於 before；這表示 counter reset/clear 或 snapshot 邊界，不把它解讀成新增 error。"
    set rxerr_expected "delta=0；若 counter 下降，僅記錄為非單調讀值"
  } elseif {$rd == 0} {
    set rxerr_status PASS
    set rxerr_explanation "delta=0 表示本次沒有新增 RX error。"
    set rxerr_expected "delta=0（本次沒有新增 error）"
  } else {
    set rxerr_status WARN
    set rxerr_explanation "delta>0 表示本次觀測期間出現 RX error；不單獨推論根因。"
    set rxerr_expected "delta=0（本次沒有新增 error）"
  }
  set step2 [merge_status $step2 $rxerr_status]
  print_delta $rxerr_status "MiniNIC RX error counter" WDIAGS_RXERR \
    [raw_display $rb] [raw_display $ra] [expr {$rd eq "TIMEOUT" || $rd eq "DECREASED" ? $rd : [format "0x%08X" $rd]}] \
    $rxerr_explanation $rxerr_expected
  if {$step2 ne "PASS"} { mark_anomaly $board 2 $step2 "Endpoint/MiniNIC/PTP role 或 packet activity" }
  set ::step_status($board,2) $step2
  puts [format {Step 2 結果：[%s] %s} [status_text $step2] $step2]

  # --------------------------------------------------------------
  # Step 3: WR parent / signaling handshake
  # --------------------------------------------------------------
  puts ""
  puts "\[Step 3\] WR Parent + Signaling Handshake"
  if {$role eq "MASTER"} {
    set step3 INFO
    puts "\[資訊\] Master 端不需要 foreign-master discovery；保留 raw signaling 供追蹤。"
  } elseif {$role ne "SLAVE"} {
    set step3 INFO
    puts "\[資訊\] WDIAGS_MODE 尚未可靠判定，暫不判定 WR parent handshake。"
  } else {
    set step3 PASS
    set foreign [get_snap $board $after foreign_meta]
    set parse [get_snap $board $after parse_meta]
    set fc [field32 $foreign 0 8]
    set best [field32 $foreign 8 8]
    set parent_detection [field32 $foreign 16 8]
    set parent_wr_config [field32 $foreign 24 8]
    set parent_is_wr [bit32 $parse 24]
    set parent_wr_on [bit32 $parse 25]
    set parent_cal [bit32 $parse 26]
    set fc_status [exact_status $fc 1]
    set best_status [exact_status $best 0]
    set step3 [merge_status $step3 $fc_status]
    set step3 [merge_status $step3 $best_status]
    puts [format {[%s] Foreign master count (WDIAGS_FOREIGN_META) = %s} [status_text $fc_status] [expr {$fc < 0 ? "TIMEOUT" : $fc}]]
    puts "      預期值：1；解釋：foreign record 已建立。"
    puts [format {[%s] Best foreign index (WDIAGS_FOREIGN_META) = %s} [status_text $best_status] [expr {$best < 0 ? "TIMEOUT" : $best}]]
    puts "      預期值：0；解釋：目前選取第 0 筆 foreign master。"
    puts [format {[資訊] Parent detection / WR config (WDIAGS_FOREIGN_META) = %s / %s} \
      [expr {$parent_detection < 0 ? "TIMEOUT" : $parent_detection}] \
      [expr {$parent_wr_config < 0 ? "TIMEOUT" : $parent_wr_config}]]
    puts "      預期值：依 source-defined parent metadata；不以單一值猜測 calibration。"
    foreach item {{24 parentIsWRnode "Parent is WR node"} {25 parentWrModeOn "Parent WR mode on"} {26 parentCalibrated "Parent calibrated"}} {
      set bit [lindex $item 0]
      set symbol [lindex $item 1]
      set chinese [lindex $item 2]
      set value [bit32 $parse $bit]
      if {$symbol eq "parentWrModeOn" && $value >= 0} {
        # This flag is useful context, but is not a minimum Step 3 gate.
        set current INFO
      } else {
        set current [exact_status $value 1]
        if {$symbol ne "parentWrModeOn"} { set step3 [merge_status $step3 $current] }
      }
      print_signal $current $chinese $symbol [expr {$value < 0 ? "TIMEOUT" : $value}] "1" \
        "WDIAGS_PARSE_META 的 source-backed parent flag。"
    }
    set rx_signal [get_snap $board $after wr_rx_signal]
    set tx_signal [get_snap $board $after wr_tx_signal]
    set rx_id [field32 $rx_signal 16 16]
    set rx_count [field32 $rx_signal 0 16]
    set tx_id [field32 $tx_signal 16 16]
    set tx_count [field32 $tx_signal 0 16]
    set rx_ok [expr {$rx_count > 0 && $rx_id == 0x1001 ? "PASS" : "WARN"}]
    set tx_ok [expr {$tx_count > 0 && $tx_id == 0x1000 ? "PASS" : "WARN"}]
    set step3 [merge_status $step3 $rx_ok]
    set step3 [merge_status $step3 $tx_ok]
    if {$rx_id < 0} { set rx_id_display "TIMEOUT" } else { set rx_id_display [format "0x%04X" $rx_id] }
    if {$tx_id < 0} { set tx_id_display "TIMEOUT" } else { set tx_id_display [format "0x%04X" $tx_id] }
    puts [format {[%s] WR RX message (WR_RX_SIGNAL_DEBUG) = %s (%s), count=%s} [status_text $rx_ok] \
      $rx_id_display [signal_name $rx_id] [expr {$rx_count < 0 ? "TIMEOUT" : $rx_count}]]
    puts "      預期值：last RX=0x1001 (LOCK) 且 count>0；解釋：source-backed signaling shadow。"
    puts [format {[%s] WR TX message (WR_TX_SIGNAL_DEBUG) = %s (%s), count=%s} [status_text $tx_ok] \
      $tx_id_display [signal_name $tx_id] [expr {$tx_count < 0 ? "TIMEOUT" : $tx_count}]]
    puts "      預期值：last TX=0x1000 (SLAVE_PRESENT) 且 count>0；解釋：source-backed signaling shadow。"
    set wr_state [get_snap $board $after wr_state]
    set state [field32 $wr_state 11 4]
    set next_state [field32 $wr_state 15 4]
    set state_ok [expr {$state >= 2 && $state <= 8 ? "PASS" : "WARN"}]
    set step3 [merge_status $step3 $state_ok]
    puts [format {[%s] WR state (WDIAGS_TEMP) = %s (%s), next=%s (%s)} [status_text $state_ok] \
      [expr {$state < 0 ? "TIMEOUT" : $state}] [wr_state_name $state] \
      [expr {$next_state < 0 ? "TIMEOUT" : $next_state}] [wr_state_name $next_state]]
    puts "      預期值：已觀測或已通過 WRS_S_LOCK=2；解釋：此 shadow 是目前 WR state/next_state。"
    set lock_enable [word32 [get_snap $board $after lock_enable]]
    set lock_status [required_positive_status $lock_enable]
    set step3 [merge_status $step3 $lock_status]
    print_signal $lock_status "WR lock enable 次數" LOCK_ENABLE \
      [expr {$lock_enable < 0 ? "TIMEOUT" : $lock_enable}] "> 0" \
      "locking_enable() 已被呼叫的 read-only counter；不等於 SoftPLL 已 lock。"
    if {$step3 ne "PASS"} { mark_anomaly $board 3 $step3 "WR parent/signaling handshake" }
  }
  set ::step_status($board,3) $step3
  puts [format {Step 3 結果：[%s] %s} [status_text $step3] $step3]

  # --------------------------------------------------------------
  # Step 4: SoftPLL startup, not closed-loop lock
  # --------------------------------------------------------------
  puts ""
  puts "\[Step 4\] SoftPLL Startup（只判斷啟動，不判斷完整 lock）"
  if {$role ne "SLAVE"} {
    set step4 INFO
    puts "\[資訊\] 本 dashboard 的 Step 4 gate 以 Slave SoftPLL startup 為主；此板卡角色不套用該 gate。"
  } else {
    set step4 PASS
    set lock_enable [word32 [get_snap $board $after lock_enable]]
    set lock_status [required_positive_status $lock_enable]
    set step4 [merge_status $step4 $lock_status]
    print_signal $lock_status "SoftPLL channel enable" LOCK_ENABLE \
      [expr {$lock_enable < 0 ? "TIMEOUT" : $lock_enable}] "> 0" \
      "只表示 locking_enable() 路徑曾被啟用，不把它當成 lock。"
    set spll_word [word32 [get_snap $board $after spll_state]]
    set seq [expr {$spll_word < 0 ? -1 : ($spll_word & 0xff)}]
    set spll_mode [expr {$spll_word < 0 ? -1 : (($spll_word >> 16) & 0xff)}]
    set mode_status [exact_status $spll_mode 3]
    set seq_status [expr {$seq < 0 ? "WARN" : ($seq == 6 ? "FAIL" : "PASS")}]
    set step4 [merge_status $step4 $mode_status]
    set step4 [merge_status $step4 $seq_status]
    puts [format {[%s] SoftPLL mode (SPLL_STATE) = %s (%s)} [status_text $mode_status] \
      [expr {$spll_mode < 0 ? "TIMEOUT" : $spll_mode}] [spll_mode_name $spll_mode]]
    puts "      預期值：3 (SPLL_MODE_SLAVE)；解釋：由 softpll_export.h 定義。"
    puts [format {[%s] SoftPLL sequencer (SPLL_STATE) = %s (%s)} [status_text $seq_status] \
      [expr {$seq < 0 ? "TIMEOUT" : $seq}] [state_name $seq]]
    puts "      預期值：不是 SEQ_DISABLED；解釋：本階段只要求離開 disabled/idle，不要求 helper/main locked。"
    set rcer [word32 [get_snap $board $after spll_rcer]]
    set ocer [word32 [get_snap $board $after spll_ocer]]
    set rcer_status [required_positive_status $rcer]
    set ocer_status [positive_status $ocer]
    set step4 [merge_status $step4 $rcer_status]
    print_signal $rcer_status "SoftPLL reference channel enable" RCER \
      [expr {$rcer < 0 ? "TIMEOUT" : [format "0x%08X" $rcer]}] "非零" \
      "既有 Step 4 shadow 的 SPLL->RCER read-only value；本階段要求 reference channel enabled。"
    print_signal $ocer_status "SoftPLL output channel enable" OCER \
      [expr {$ocer < 0 ? "TIMEOUT" : [format "0x%08X" $ocer]}] "依當次設計" \
      "只顯示 source-backed shadow，不因非零自行宣稱 output lock。"
    foreach counter {
      {dmtd_ref "DMTD reference event" SPLL_DMTD_REF_EVENTS}
      {dmtd_fb "DMTD feedback event" SPLL_DMTD_FB_EVENTS}
      {tag_valid tag SPLL_TAG_VALID_COUNT}
      {trr_write TRR_WRITE SPLL_TRR_WRITE_COUNT}
      {irq IRQ WDIAGS_IRQ_COUNT}
      {helper_update HELPER_UPDATE WDIAGS_HELPER_UPDATE_COUNT}
    } {
      set field [lindex $counter 0]
      set chinese [lindex $counter 1]
      set symbol [lindex $counter 2]
      set b [get_snap $board $before $field]
      set a [get_snap $board $after $field]
      set d [delta32 $b $a]
      set current [required_delta_status $d]
      set step4 [merge_status $step4 $current]
      print_delta $current $chinese $symbol \
        [raw_display $b] [raw_display $a] [expr {$d eq "TIMEOUT" || $d eq "DECREASED" ? $d : [format "0x%08X" $d]}] \
        "兩次 snapshot 的 delta > 0 才算本次觀測期間 sustained activity；孤立非零值不算。"
    }
    if {$step4 ne "PASS"} { mark_anomaly $board 4 $step4 "SoftPLL startup event chain" }
  }
  set ::step_status($board,4) $step4
  puts [format {Step 4 結果：[%s] %s} [status_text $step4] $step4]

  # --------------------------------------------------------------
  # Step 5: closed-loop lock, informational until Step 4 passes
  # --------------------------------------------------------------
  puts ""
  puts "\[Step 5\] Closed-loop Lock"
  set pstat_raw [get_snap $board $after pstat]
  set pstat_locked [bit32 $pstat_raw 1]
  set time_valid [bit64_low $status_raw 4]
  set lock_display [expr {$pstat_locked < 0 ? "TIMEOUT" : $pstat_locked}]
  if {$step4 ne "PASS"} {
    set step5 INFO
    puts "\[資訊\] Step 4 尚未通過，本階段暫不判定。"
    puts [format {[資訊] PSTAT.locked (WDIAGS_PSTAT bit 1) = %s} $lock_display]
  } else {
    set step5 [exact_status $pstat_locked 1]
    puts [format {[%s] PSTAT.locked (WDIAGS_PSTAT bit 1) = %s} [status_text $step5] $lock_display]
    puts "      預期值：1；解釋：這是 closed-loop lock evidence，不是 Step 4 startup gate。"
  }
  puts [format {[資訊] time_valid (instance 0 status bit 4) = %s；PSTAT raw=%s} \
    [expr {$time_valid < 0 ? "TIMEOUT" : $time_valid}] [raw_display $pstat_raw]]
  puts "      預期值：Step 5 才判定；解釋：time_valid=1 不會被拿來反推 Step 4 PASS。"
  set ::step_status($board,5) $step5
  if {$step5 ne "PASS" && $step5 ne "INFO"} {
    mark_anomaly $board 5 $step5 "PSTAT.locked / closed-loop lock"
  }

  # --------------------------------------------------------------
  # Step 6: global time / execute_at(T)
  # --------------------------------------------------------------
  puts ""
  puts "\[Step 6\] Global Time / execute_at(T)"
  set ::step_status($board,6) INFO
  puts [format {[資訊] SEC_H/SEC_L/NS (WDIAGS_SEC_H/WDIAGS_SEC_L/WDIAGS_NS) = %s / %s / %s} \
    [raw_display [get_snap $board $after sec_h]] [raw_display [get_snap $board $after sec_l]] [raw_display [get_snap $board $after ns]]]
  puts [format "      time_valid (status bit 4) = %s；解釋：可顯示目前 local time counter，但 deterministic execute_at(T) 尚未在本專案觀測。" \
    [expr {$time_valid < 0 ? "TIMEOUT" : $time_valid}]]
  puts "\[資訊\] execute_at(T) = 尚未驗證；本 Tcl 不會寫入任何 target time 或 control register。"

  puts ""
  puts "---------------- 本板卡總結 ----------------"
  puts [format "板卡角色：%s" $role]
  foreach step {1 2 3 4 5 6} {
    set s $::step_status($board,$step)
    if {$step == 1} { set label "PHY / Link" }
    if {$step == 2} { set label "Endpoint / PTP" }
    if {$step == 3} { set label "WR Handshake" }
    if {$step == 4} { set label "SoftPLL Startup" }
    if {$step == 5} { set label "Closed-loop Lock" }
    if {$step == 6} { set label "Global Time" }
    if {$s eq "INFO"} { set shown "尚未判定" }
    if {$s eq "PASS"} { set shown "PASS" }
    if {$s eq "WARN"} { set shown "注意" }
    if {$s eq "FAIL"} { set shown "FAIL" }
    puts [format "Step %d %-22s : %s" $step $label $shown]
  }
  if {$::first_anomaly($board) eq ""} {
    puts "第一個異常節點：本次沒有觀測到 FAIL/WARN；仍須以 raw evidence 追溯。"
  } else {
    puts [format "第一個異常節點：%s" $::first_anomaly($board)]
  }
  if {$::first_anomaly($board) ne ""} {
    puts "建議下一個檢查：先針對上面列出的第一個異常節點做 read-only correlation，再往下游檢查；本 dashboard 不預設 DMTD 為 blocker。"
  } else {
    puts "建議下一個檢查：只針對本次第一個 FAIL/WARN 節點做下一個 read-only correlation。"
  }
}

proc print_raw_snapshot {board label} {
  puts [format "RAW_SNAPSHOT board=%s label=%s" $::board_name($board) $label]
  foreach field {status cpu marker store store_count exception clock \
    pps_cr pps_escr ep_mach ep_macl ep_dsr ptp ptp_rx ptp_tx ptp_meta \
    tx rx rxerr ptp_types foreign_meta filter_meta parse_meta wr_rx_signal \
    wr_tx_signal wr_failure wr_state wr_reject pstat sstat sec_h sec_l ns \
    lock_enable spll_state spll_ocer spll_rcer spll_trr_csr dmtd_ref dmtd_fb \
    dmtd_ref_seen dmtd_fb_seen tag_valid trr_write irq helper_update eic_isr current_tics} {
    puts [format "  %-16s = %s" $field [get_snap $board $label $field]]
  }
}

puts "================================================================"
puts "White Rabbit 繁體中文 runtime health dashboard"
puts "read-only：不寫 Wishbone control register、不 program FPGA、不改變 WR behavior"
puts "================================================================"

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  set board [format "b%02d" $::board_count]
  incr ::board_count
  set ::board_name($board) $hardware_name
  set ::first_anomaly($board) ""
  puts ""
  puts [format "=== 連接 %s ===" $hardware_name]
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    collect_snapshot $board before
    after 750
    collect_snapshot $board after
    analyze_board $board
    puts ""
    puts "================ 原始 Debug 值 ================"
    print_raw_snapshot $board before
    print_raw_snapshot $board after
  } error_message]} {
    puts [format {[注意] %s：JTAG 讀取流程發生例外；未將例外轉成硬體 FAIL} $error_message]
  }
  catch { end_insystem_source_probe }
}

puts ""
puts "================================================================"
puts "White Rabbit dashboard 完成"
puts "================================================================"
