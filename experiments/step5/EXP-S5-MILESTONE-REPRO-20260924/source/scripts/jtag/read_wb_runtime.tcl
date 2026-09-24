# DE5a White Rabbit runtime health dashboard。
#
# 這是一份 read-only JTAG 診斷腳本：
#   - instance 0..7 是 Direct Probe，只讀取目前訊號。
#   - instance 1 的 mailbox 只送出 Wishbone read，不送出 write。
#   - counter 以同一 JTAG session 的 before/after delta 判斷 activity。
#   - TIMEOUT 永遠保留為無效證據，不會被轉成 0，也不會直接判定硬體失敗。
#   - Wishbone request 使用 preload -> toggle commit，避免 bundled CDC race。
#
# 使用：
#   quartus_stp -t read_wb_runtime.tcl
#   quartus_stp -t read_wb_runtime.tcl --raw
# 預設只輸出單行訊號結果；--raw 另外保留 before/after 與完整 raw snapshot。

package require ::quartus::insystem_source_probe

set ::wb_toggle 0
array set ::snap {}
array set ::board_name {}
array set ::step_status {}
array set ::first_anomaly {}
array set ::step4b_allowed {}
array set ::step4b_result {}
array set ::step4b_boundary {}
array set ::step5_result {}
array set ::step5_boundary {}
set ::step4_master_status INFO
set ::step4_master_name ""
set ::step4a_master_status INFO
set ::board_count 0
set ::raw_mode 0
set ::max_read_attempts 5
set ::observation_gap_ms 5000
set ::wb_transport_protocol PRELOAD_THEN_TOGGLE_COMMIT
set ::wb_request_count 0
set ::wb_preload_count 0
set ::wb_commit_count 0
set ::wb_probe_read_count 0
set ::wb_preload_unexpected_trigger_count 0
set ::wb_probe_3way_match_count 0
set ::wb_stable_response_wrong_count 0
set ::wb_address_cross_contamination_count 0
set ::wb_timeout_count 0
set ::wb_invalid_count 0
set ::wb_stale_count 0
set ::wb_unstable_transaction_count 0
set ::wb_dmtd_ref_decrease_count 0
set ::wb_dmtd_fb_decrease_count 0
set ::wb_last_static_addr ""
set ::wb_last_static_value ""
if {[info exists argv] && [lsearch -exact $argv "--raw"] >= 0} {
  set ::raw_mode 1
}

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

proc safe_probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return "TIMEOUT"
  }
  if {![is_hex $value]} { return "INVALID" }
  return $value
}

proc stale_jtag_word {value} {
  set word [word32 $value]
  if {$word < 0} { return 0 }
  # A5A5xxxx is the observed stale/filler pattern from an invalid mailbox
  # transaction.  Do not let it enter enum or status judgement.
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
      set ptp_state [expr {$word & 0xff}]
      return [expr {$ptp_state >= 1 && $ptp_state <= 9}]
    }
    0x00100A0C {
      return [expr {($word & 0xfffffffc) == 0}]
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
    0x00100A64 - 0x00100A68 {
      set message [expr {($word >> 16) & 0xffff}]
      return [expr {$message == 0 ||
                    ($message >= 0x1000 && $message <= 0x1005)}]
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
      set sequence [expr {$word & 0xff}]
      set alignment [expr {($word >> 8) & 0xff}]
      set mode [expr {($word >> 16) & 0xff}]
      return [expr {$sequence <= 10 &&
                    $alignment <= 10 && $mode <= 3}]
    }
    0x00100AA4 {
      # OCER[7:0] is the functional source field.  The hand-maintained
      # spll_wb_slave.vhd exposes a live FB qualification counter in the
      # otherwise undefined upper bits, so the full word is intentionally
      # not stable and must not be constrained to zero.
      return 1
    }
    0x00100AA8 {
      # RCER is a full source-defined 32-bit control register.
      return 1
    }
  }
  return 1
}

proc probe_low32 {value} {
  return [word32 $value]
}

proc normalize_probe64 {value} {
  if {![is_hex $value]} { return $value }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  return [string repeat 0 [expr {16 - [string length $text]}]]$text
}

proc probe_equal64 {left right} {
  if {![is_hex $left] || ![is_hex $right]} { return 0 }
  return [expr {[normalize_probe64 $left] eq [normalize_probe64 $right]}]
}

proc completion_probe_valid {value expected_toggle} {
  if {![is_hex $value] || [stale_jtag_word $value]} { return 0 }
  set done_toggle [bit64_high $value 3]
  set active [bit64_high $value 4]
  return [expr {$done_toggle == $expected_toggle && $active == 0}]
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

proc probe_counter_hex {value} {
  # Store probe-derived counters in the same hexadecimal representation as
  # Wishbone counters so delta32() cannot mistake decimal text for hex.
  set numeric [word32 $value]
  if {$numeric < 0} { return "INVALID" }
  return [format %08X $numeric]
}

proc probe_high_counter_hex {value} {
  set numeric [probe_high32 $value]
  if {$numeric < 0} { return "INVALID" }
  return [format %08X $numeric]
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

proc probe_byte64 {value bit} {
  if {$bit < 32} { return [bit64_low $value $bit] }
  return [bit64_high $value [expr {$bit - 32}]]
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

proc special_value {value} {
  return [expr {$value eq "TIMEOUT" || $value eq "DECREASED" ||
                $value eq "INVALID"}]
}

proc numeric_value {value} {
  # Keep all status comparisons behind one guard.  Mailbox failures and
  # counter state markers are text, not integers, and must never reach expr.
  if {[special_value $value]} { return "" }
  if {![string is integer -strict $value]} { return "" }
  return $value
}

proc negative_value {value} {
  set numeric [numeric_value $value]
  if {$numeric eq ""} { return 0 }
  return [expr {$numeric < 0}]
}

proc numeric_equal {value expected} {
  set numeric [numeric_value $value]
  if {$numeric eq ""} { return 0 }
  return [expr {$numeric == $expected}]

}

proc numeric_greater_than {value expected} {
  set numeric [numeric_value $value]
  if {$numeric eq ""} { return 0 }
  return [expr {$numeric > $expected}]
}

proc display_value {value} {
  if {$value eq "TIMEOUT"} { return "TIMEOUT" }
  if {$value eq "DECREASED"} { return "counter decreased/reset" }
  if {$value eq "INVALID"} { return "JTAG read inconsistent" }
  if {[negative_value $value]} { return "TIMEOUT" }
  return $value
}

proc status_rank {status} {
  switch -- $status {
    PASS { return 0 }
    INFO { return 1 }
    WARN { return 2 }
    INVALID { return 2 }
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
    PASS { return "pass" }
    WARN { return "error" }
    FAIL { return "error" }
    INFO { return "info" }
    INVALID { return "info" }
  }
  # Keep the default UI contract closed: runtime lines may only use the
  # three dashboard states, even if a future caller passes an unknown value.
  return "info"
}

proc step_status_text {status} {
  if {$status eq "PASS"} { return "pass" }
  if {$status eq "WARN" || $status eq "FAIL"} { return "error" }
  if {$status eq "INVALID"} { return "NA" }
  return "NA"
}

proc regression_status {step status} {
  # A single dashboard snapshot is sufficient for the direct PHY gate, but
  # never for the Step 2/3 packet and handshake regression gates. Those
  # gates require focused repeated sampling. Any non-PASS Step 2/3 snapshot
  # is therefore RETEST/INVALID, not a hardware FAIL.
  if {$step == 1} {
    switch -- $status {
      PASS { return PASS }
      FAIL { return FAIL }
      INVALID - INFO - WARN { return INVALID }
    }
    return INVALID
  }
  if {$status eq "PASS"} { return PASS }
  return INVALID
}

proc mark_anomaly {board step status text} {
  if {$status eq "PASS" || $status eq "INFO"} { return }
  if {![info exists ::first_anomaly($board)] || $::first_anomaly($board) eq ""} {
    set ::first_anomaly($board) "Step $step：$text"
  }
}

proc exact_status {value expected} {
  if {$value eq "DECREASED"} { return "INFO" }
  set numeric [numeric_value $value]
  if {$numeric eq ""} { return "INVALID" }
  if {$numeric == $expected} { return "PASS" }
  return "FAIL"
}

proc positive_status {value} {
  if {$value eq "DECREASED"} { return "INFO" }
  set numeric [numeric_value $value]
  if {$numeric eq ""} { return "INVALID" }
  if {$numeric > 0} { return "PASS" }
  return "WARN"
}

proc required_positive_status {value} {
  if {$value eq "DECREASED"} { return "INFO" }
  set numeric [numeric_value $value]
  if {$numeric eq ""} { return "INVALID" }
  if {$numeric > 0} { return "PASS" }
  return "FAIL"
}

proc delta_status {value} {
  set numeric [numeric_value $value]
  if {$numeric eq "" && $value ne "DECREASED"} { return "INVALID" }
  if {$value eq "DECREASED"} { return "INFO" }
  if {$numeric > 0} { return "PASS" }
  # A one-window zero is not evidence that the packet path is broken.
  return "INFO"
}

proc required_delta_status {value} {
  set numeric [numeric_value $value]
  if {$numeric eq "" && $value ne "DECREASED"} { return "INVALID" }
  if {$value eq "DECREASED"} { return "INFO" }
  if {$numeric > 0} { return "PASS" }
  return "FAIL"
}

proc required_zero_delta_status {value} {
  if {$value eq "DECREASED"} { return "INVALID" }
  set numeric [numeric_value $value]
  if {$numeric eq ""} { return "INVALID" }
  if {$numeric == 0} { return "PASS" }
  return "FAIL"
}

proc spll_sequence_status {value} {
  # SEQ_DISABLED (7) and the zero-initialized diagnostic value are not
  # acceptable evidence of a started SoftPLL.  Values 1..6 and 8..10 are
  # source-defined active/terminal startup states.
  set numeric [numeric_value $value]
  if {$numeric eq ""} { return "INVALID" }
  if {$numeric == 0 || $numeric == 7} { return "FAIL" }
  if {$numeric >= 1 && $numeric <= 10} { return "PASS" }
  return "WARN"
}

proc nonzero_state_status {value} {
  set numeric [numeric_value $value]
  if {$numeric eq ""} { return "INVALID" }
  if {$numeric > 0} { return "PASS" }
  return "FAIL"
}

proc step4b_first_inactive_boundary {accepted_delta tag_delta trr_write_delta \
                                      trr_pop_delta irq_delta helper_delta} {
  if {![numeric_greater_than $accepted_delta 0]} { return "DMTD_ACCEPT" }
  if {![numeric_greater_than $tag_delta 0]} { return "DMTD_ACCEPT_TO_TAG" }
  if {![numeric_greater_than $trr_write_delta 0]} { return "TAG_TO_TRR_WRITE" }
  if {![numeric_greater_than $trr_pop_delta 0]} { return "TRR_WRITE_TO_TRR_POP" }
  if {![numeric_greater_than $irq_delta 0]} { return "TRR_POP_TO_IRQ" }
  if {![numeric_greater_than $helper_delta 0]} { return "IRQ_TO_HELPER_UPDATE" }
  return "ACTIVE"
}

proc step5_snapshot_boundary {label} {
  set helper_state [get_snap $::active_board $label spll_helper_state]
  set main_state [get_snap $::active_board $label spll_main_state]
  set pstat [get_snap $::active_board $label pstat]
  set helper_locked [field32 $helper_state 0 1]
  set main_enabled [field32 $main_state 0 1]
  set main_freq_locked [field32 $main_state 2 1]
  set main_phase_locked [field32 $main_state 3 1]
  set main_locked [field32 $main_state 1 1]
  set pstat_locked [bit32 $pstat 1]
  foreach value [list $helper_locked $main_enabled $main_freq_locked \
      $main_phase_locked $main_locked $pstat_locked] {
    if {$value < 0} { return "SOURCE_SEMANTICS_NOT_PROVEN" }
  }
  if {!$helper_locked} { return "HELPER_LOCK" }
  if {!$main_enabled} { return "MAIN_START" }
  if {!$main_freq_locked} { return "MAIN_FREQUENCY_LOCK" }
  if {!$main_phase_locked || !$main_locked} { return "MAIN_PHASE_LOCK" }
  if {!$pstat_locked} { return "PSTAT_LOCK" }
  return "STABLE_WINDOW_REQUIRED"
}

proc step5_snapshot_fully_locked {label} {
  set boundary [step5_snapshot_boundary $label]
  if {$boundary eq "SOURCE_SEMANTICS_NOT_PROVEN"} { return -1 }
  if {$boundary eq "STABLE_WINDOW_REQUIRED"} { return 1 }
  return 0
}

proc step5_print_lockdet {label} {
  set helper_state [get_snap $::active_board $label spll_helper_state]
  set helper_limits [get_snap $::active_board $label spll_helper_limits]
  set main_state [get_snap $::active_board $label spll_main_state]
  set main_limits [get_snap $::active_board $label spll_main_limits]
  set phase_limits [get_snap $::active_board $label spll_main_phase_limits]
  set pstat [get_snap $::active_board $label pstat]
  puts [format "STEP5_LOCKDET_%s: HELPER locked=%d changed=%d cnt=%d/%d threshold=%d ref_src=%d MAIN enabled=%d locked=%d freq=%d phase=%d freq_cnt=%d/%d phase_cnt=%d/%d PSTAT_locked=%d" \
    [string toupper $label] \
    [field32 $helper_state 0 1] [field32 $helper_state 1 1] \
    [field32 $helper_state 16 16] [field32 $helper_limits 16 16] \
    [field32 $helper_limits 0 16] [field32 $helper_state 8 8] \
    [field32 $main_state 0 1] [field32 $main_state 1 1] \
    [field32 $main_state 2 1] [field32 $main_state 3 1] \
    [field32 $main_state 8 12] [field32 $main_limits 16 16] \
    [field32 $main_state 20 12] [field32 $phase_limits 16 16] \
    [bit32 $pstat 1]]
}

proc probe_byte_counter_hex {value bit} {
  set numeric [probe_byte64 $value $bit]
  if {$numeric < 0} { return "INVALID" }
  return [format %08X $numeric]
}

proc raw_display {value} {
  if {$value eq "TIMEOUT"} { return "TIMEOUT" }
  if {![is_hex $value]} { return $value }
  return [format "0x%08X" [word32 $value]]
}

proc state_name {state} {
  switch -- $state {
    0 { return "SEQ_UNINITIALIZED" }
    1 { return "SEQ_START_EXT" }
    2 { return "SEQ_WAIT_EXT" }
    3 { return "SEQ_START_HELPER" }
    4 { return "SEQ_WAIT_HELPER" }
    5 { return "SEQ_START_MAIN" }
    6 { return "SEQ_WAIT_MAIN" }
    7 { return "SEQ_DISABLED" }
    8 { return "SEQ_READY" }
    9 { return "SEQ_CLEAR_DACS" }
    10 { return "SEQ_WAIT_CLEAR_DACS" }
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
  if {$mach eq "INVALID" || $macl eq "INVALID"} { return "INVALID" }
  if {$hi < 0 || $lo < 0} { return "TIMEOUT" }
  set mid [expr {$hi & 0xffff}]
  return [format "%02X:%02X:%02X:%02X:%02X:%02X" \
    [expr {($mid >> 8) & 0xff}] [expr {$mid & 0xff}] \
    [expr {($lo >> 24) & 0xff}] [expr {($lo >> 16) & 0xff}] \
    [expr {($lo >> 8) & 0xff}] [expr {$lo & 0xff}]]
}

proc wb_probe_read {} {
  incr ::wb_probe_read_count
  set value [safe_probe_read 1]
  if {$value eq "TIMEOUT"} {
    incr ::wb_timeout_count
    return $value
  }
  if {$value eq "INVALID"} {
    incr ::wb_invalid_count
    return $value
  }
  set value [normalize_probe64 $value]
  if {[stale_jtag_word $value]} { incr ::wb_stale_count }
  return $value
}

proc static_address_key {addr} {
  return [format "0x%08X" [expr {$addr & 0xffffffff}]]
}

proc note_stable_wb_result {addr value} {
  set key [static_address_key $addr]
  set word [probe_low32 $value]
  if {$key eq "0x00100124" && $word != 0x02000200} {
    incr ::wb_stable_response_wrong_count
  }
  if {$key eq "0x00100128" &&
      $word != 0x22334401 && $word != 0x22334402} {
    incr ::wb_stable_response_wrong_count
  }

  # Detect the previous static register being returned for the next static
  # request.  This is deliberately limited to the two immutable probes so a
  # changing DMTD counter is never misclassified as address contamination.
  if {($key eq "0x00100124" || $key eq "0x00100128") &&
      $::wb_last_static_addr ne "" && $key ne $::wb_last_static_addr &&
      [probe_low32 $value] == [probe_low32 $::wb_last_static_value]} {
    incr ::wb_address_cross_contamination_count
  }
  if {$key eq "0x00100124" || $key eq "0x00100128"} {
    set ::wb_last_static_addr $key
    set ::wb_last_static_value $value
  }
}

proc wb_read {addr} {
  # Phase 1: preload the complete multi-bit request while keeping the
  # currently completed toggle unchanged.  No transaction is expected here.
  set preload_toggle $::wb_toggle
  set preload_cmd [expr {$preload_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  incr ::wb_preload_count
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $preload_cmd] -value_in_hex
  }]} {
    incr ::wb_timeout_count
    return "TIMEOUT"
  }
  after 2
  set preload_probe [wb_probe_read]
  if {[is_hex $preload_probe] && ![stale_jtag_word $preload_probe] &&
      ![completion_probe_valid $preload_probe $preload_toggle]} {
    incr ::wb_preload_unexpected_trigger_count
  }

  # Phase 2: commit the identical request by changing only the toggle.
  set ::wb_toggle [expr {($preload_toggle ^ 1) & 1}]
  set expected_toggle $::wb_toggle
  set cmd [expr {$expected_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  incr ::wb_request_count
  incr ::wb_commit_count
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    incr ::wb_timeout_count
    return "TIMEOUT"
  }

  after 5
  set first_completion ""
  for {set n 0} {$n < 100} {incr n} {
    set value [wb_probe_read]
    if {[completion_probe_valid $value $expected_toggle]} {
      set first_completion $value
      break
    }
    after 1
  }
  if {$first_completion eq ""} {
    incr ::wb_timeout_count
    return "TIMEOUT"
  }

  # Require the complete 64-bit probe to remain coherent across three
  # samples.  This rejects the prior done-toggle/new-data visibility race.
  for {set attempt 1} {$attempt <= 10} {incr attempt} {
    set p1 [wb_probe_read]
    after 1
    set p2 [wb_probe_read]
    after 1
    set p3 [wb_probe_read]
    if {[completion_probe_valid $p1 $expected_toggle] &&
        [completion_probe_valid $p2 $expected_toggle] &&
        [completion_probe_valid $p3 $expected_toggle] &&
        [probe_equal64 $p1 $p2] && [probe_equal64 $p2 $p3]} {
      incr ::wb_probe_3way_match_count
      set result [format %08X [probe_low32 $p3]]
      note_stable_wb_result $addr $p3
      return $result
    }
    after 1
  }
  incr ::wb_unstable_transaction_count
  incr ::wb_timeout_count
  return "TIMEOUT"
}

proc wb_read_validated {addr} {
  # Retry only read-side evidence.  No Wishbone write or DATA_SNAPSHOT is
  # issued here.  A value that never passes the source-backed validator is
  # kept as INVALID so it cannot become a hardware FAIL.
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
  # Critical enum/status fields must be both source-valid and stable across
  # two accepted read transactions.  A changing counter is not used here;
  # callers keep free-running counters on wb_read() and judge them by delta.
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
  # Read a free-running counter twice.  A stale mailbox word is rejected;
  # an observed decrease is retained so the outer snapshot comparison can
  # report reset/clear/wrap as informational instead of hardware failure.
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set first [wb_read $addr]
    set second [wb_read $addr]
    if {[counter_value_valid $first] && [counter_value_valid $second]} {
      set a [word32 $first]
      set b [word32 $second]
      return [format %08X $b]
    }
    after 2
  }
  return "INVALID"
}

proc wb_sync_toggle {} {
  # 只讀取 mailbox completion 狀態；不寫入控制 register。
  set value [safe_probe_read 1]
  set current_done [bit64_high $value 3]
  if {$current_done < 0} { set current_done 0 }
  set ::wb_toggle $current_done
  if {$::raw_mode} {
    puts [format "RAW mailbox completion toggle wb_sync_toggle=%d" $current_done]
  }
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
  set ::active_board $board
  put_snap $board $label status [safe_probe_read 0]
  put_snap $board $label cpu [safe_probe_read 2]
  put_snap $board $label marker [safe_probe_read 3]
  put_snap $board $label store [safe_probe_read 4]
  put_snap $board $label store_count [safe_probe_read 5]
  put_snap $board $label exception [safe_probe_read 6]
  put_snap $board $label clock [safe_probe_read 7]

  # Persistent reset/re-entry evidence used by the Step 4 closure gate.
  # These are read-only Direct Probe fields already used by the focused
  # closure reader: probe 26 carries boot generation and probe 27 carries
  # sticky CPU/WR/SI reset counters.
  set entry_probe [safe_probe_read 26]
  set reset_sticky_probe [safe_probe_read 27]
  put_snap $board $label boot_generation [probe_high_counter_hex $entry_probe]
  put_snap $board $label cpu_reset_count \
    [probe_byte_counter_hex $reset_sticky_probe 16]
  put_snap $board $label wr_core_reset_count \
    [probe_byte_counter_hex $reset_sticky_probe 24]
  put_snap $board $label si_config_drop_count \
    [probe_byte_counter_hex $reset_sticky_probe 40]

  put_snap $board $label pps_cr [wb_read 0x00100300]
  put_snap $board $label pps_escr [wb_read 0x0010031C]
  put_snap $board $label ep_mach [wb_read_critical 0x00100124]
  put_snap $board $label ep_macl [wb_read_critical 0x00100128]
  put_snap $board $label ep_dsr [wb_read 0x00100138]
  put_snap $board $label ptp [wb_read_critical 0x00100A10]
  put_snap $board $label ptp_rx [wb_read_counter 0x00100A54]
  put_snap $board $label ptp_tx [wb_read_counter 0x00100A58]
  put_snap $board $label ptp_meta [wb_read_critical 0x00100A5C]
  put_snap $board $label tx [wb_read_counter 0x00100A18]
  put_snap $board $label rx [wb_read_counter 0x00100A1C]
  put_snap $board $label rxerr [wb_read_counter 0x00100A60]
  put_snap $board $label ptp_types [wb_read 0x00100A74]
  put_snap $board $label foreign_meta [wb_read_critical 0x00100A78]
  put_snap $board $label filter_meta [wb_read 0x00100A7C]
  put_snap $board $label parse_meta [wb_read_critical 0x00100A80]
  put_snap $board $label wr_rx_signal [wb_read_validated 0x00100A64]
  put_snap $board $label wr_tx_signal [wb_read_validated 0x00100A68]
  put_snap $board $label wr_failure [wb_read_critical 0x00100A6C]
  put_snap $board $label wr_state [wb_read_critical 0x00100A4C]
  put_snap $board $label wr_reject [wb_read_validated 0x00100A50]
  put_snap $board $label pstat [wb_read_validated 0x00100A0C]
  put_snap $board $label sstat [wb_read 0x00100A08]
  put_snap $board $label sec_h [wb_read 0x00100A20]
  put_snap $board $label sec_l [wb_read 0x00100A24]
  put_snap $board $label ns [wb_read 0x00100A28]

  # 這些地址與既有 Step 4 read-only scripts/source mapping 一致。
  put_snap $board $label lock_enable [wb_read_critical 0x00100A9C]
  put_snap $board $label lock_result [wb_read_critical 0x00100A8C]
  put_snap $board $label lock_polls [wb_read_counter 0x00100A90]
  put_snap $board $label lock_unlocked [wb_read_counter 0x00100A94]
  put_snap $board $label lock_calibration_fail [wb_read_counter 0x00100A98]
  put_snap $board $label spll_state [wb_read_critical 0x00100AA0]
  # OCER[7:0] is the functional field; the upper bits include a live
  # diagnostic alias, so do not require the full word to be stable.
  put_snap $board $label spll_ocer [wb_read_validated 0x00100AA4]
  put_snap $board $label spll_rcer [wb_read_critical 0x00100AA8]
  put_snap $board $label spll_occr [wb_read_critical 0x00100AAC]
  put_snap $board $label spll_trr_csr [wb_read 0x00100AB0]
  put_snap $board $label spll_dac_hpll [wb_read 0x00100AB4]
  put_snap $board $label spll_dac_main [wb_read 0x00100AB8]
  put_snap $board $label spll_helper_state [wb_read_critical 0x00100ABC]
  put_snap $board $label spll_helper_limits [wb_read_critical 0x00100AC0]
  put_snap $board $label spll_main_state [wb_read_critical 0x00100AC4]
  put_snap $board $label spll_main_limits [wb_read_critical 0x00100AC8]
  put_snap $board $label spll_main_phase_limits [wb_read_critical 0x00100ACC]
  put_snap $board $label spll_state_visit_mask [wb_read 0x00100AE0]
  put_snap $board $label spll_state_transitions [wb_read 0x00100AE4]
  put_snap $board $label spll_last_state [wb_read 0x00100AE8]
  put_snap $board $label dmtd_ref [wb_read 0x00100298]
  put_snap $board $label dmtd_fb [wb_read 0x0010029C]
  # Read-only aliases added for the functional WAIT_STABLE_0 stab_cntr max.
  # 0x274[31:16] is REF; 0x278[31:18] is the saturating 14-bit FB view.
  put_snap $board $label wait_stable0_max_ref [wb_read 0x00100274]
  put_snap $board $label wait_stable0_max_fb [wb_read 0x00100278]
  # In the current fresh Step 4 image these aliases expose the existing
  # GOT_EDGE high-qualification abort counters. Historical SOF
  # files may expose different source-defined fields at the same addresses.
  put_snap $board $label dmtd_ref_high_qual_abort [wb_read 0x001002A0]
  put_snap $board $label dmtd_fb_high_qual_abort [wb_read 0x001002A4]
  put_snap $board $label tag_valid [wb_read 0x00100284]
  put_snap $board $label trr_write [wb_read 0x00100288]
  put_snap $board $label trr_pop [wb_read 0x00100B54]
  put_snap $board $label irq [wb_read 0x00100AEC]
  put_snap $board $label helper_update [wb_read 0x00100B18]
  put_snap $board $label spll_helper_error [wb_read 0x00100AD8]
  put_snap $board $label spll_helper_output [wb_read 0x00100ADC]
  put_snap $board $label spll_init_count [wb_read 0x00100B44]
  put_snap $board $label eic_isr [wb_read 0x0010026C]
  put_snap $board $label current_tics [wb_read 0x00100B3C]
}

proc print_signal {status chinese symbol value expected explanation} {
  # Keep one compact record per signal.  Descriptive arguments remain in the
  # call sites/comments for source context but are not printed by default.
  set expected_display [expr {$status eq "INFO" || $status eq "INVALID" ? "NA" : $expected}]
  puts [format {[%s] %-24s 結果: %s/%s} \
    [status_text $status] $symbol [display_value $value] $expected_display]
}

proc print_delta {status chinese symbol before after delta explanation {expected "Δ>0"}} {
  set expected_display [expr {$status eq "INFO" || $status eq "INVALID" ? "NA" : $expected}]
  puts [format {[%s] %-24s 結果: Δ=%s/%s} \
    [status_text $status] $symbol [display_value $delta] $expected_display]
  if {$::raw_mode} {
    puts [format {RAW %-24s before=%s after=%s delta=%s} $symbol \
      [raw_display $before] [raw_display $after] [display_value $delta]]
  }
}

proc analyze_board {board} {
  set name $::board_name($board)
  set before before
  set after after
  set ::first_anomaly($board) ""
  puts ""
  puts "============================================================"
  puts [format "White Rabbit Runtime 診斷：%s" $name]
  puts "============================================================"

  # --------------------------------------------------------------
  # Step 1: status probe / PHY link
  # --------------------------------------------------------------
  puts ""
  puts "## \[Step 1\] PHY / 光纖 Link"
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
    set display [display_value $value]
    set expected_text $expected
    set explanation "此欄位由 instance 0 status probe 提供；不涉及 Wishbone transaction。"
    print_signal $current $chinese $symbol $display $expected_text $explanation
  }
  set value [bit64_high $status_raw 0]
  set rx_data_lock_status [exact_status $value 1]
  print_signal $rx_data_lock_status "RX locked to data" wr_rx_locked_to_data \
    [display_value $value] "1" \
    "instance 0 status probe bit 32；表示 recovered RX path 已鎖到資料。"
  set step1 [merge_status $step1 $rx_data_lock_status]
  set value [bit64_high $status_raw 1]
  print_signal INFO "RX lock to reference" wr_rx_locked_to_ref \
    [display_value $value] "依當次 PHY 狀態觀察" \
    "高 32 bit 的 bit 1；此欄位不是 RX lock to data 的替代品。"
  foreach raw_item {{8 MOD_PRS_n module-present pin 的原始 High/Low} {9 INTERRUPT_n interrupt pin 的原始 High/Low}} {
    set bit [lindex $raw_item 0]
    set value [bit64_low $status_raw $bit]
    print_signal INFO [lindex $raw_item 1] [lindex $raw_item 1] \
      [display_value $value] "raw pin" \
      [lindex $raw_item 2]
  }
  if {$step1 ne "PASS"} { mark_anomaly $board 1 $step1 "instance 0 status probe 的 PHY/link gate" }
  set ::step_status($board,1) $step1
  puts [format "Step 1 %s" [step_status_text $step1]]

  # --------------------------------------------------------------
  # Step 2: endpoint / MiniNIC / PTP
  # --------------------------------------------------------------
  puts ""
  puts "## \[Step 2\] Endpoint / MiniNIC / PTP"
  set step2 PASS
  set mach [get_snap $board $after ep_mach]
  set macl [get_snap $board $after ep_macl]
  set mac [mac_from_registers $mach $macl]
  set ptp_meta [get_snap $board $after ptp_meta]
  set mode [field32 $ptp_meta 24 8]
  # Keep the mailbox word in hexadecimal text while extracting fields;
  # converting it to a Tcl integer first would make a later field32() call
  # reinterpret the decimal text as hexadecimal.
  set ptp [get_snap $board $after ptp]
  # WDIAGS_PTP is a metadata-bearing word; the source-defined PTP state is
  # its low byte.  Keep the full word in RAW_SNAPSHOT, but compare only the
  # state field for the Step 2 role gate.
  set ptp_state [field32 $ptp 0 8]
  set mode_num [numeric_value $mode]
  set ptp_num [numeric_value $ptp_state]
  set role "UNKNOWN"
  if {$mode_num ne "" && $mode_num == 2} { set role MASTER }
  if {$mode_num ne "" && $mode_num == 3} { set role SLAVE }
  # The two DE5 fixtures have fixed physical roles.  WDIAGS_MODE remains
  # independent Step 2 evidence, but it must not route a board to the wrong
  # milestone when startup firmware is intentionally isolated or transitional.
  set observed_role $role
  set fixture_role UNKNOWN
  if {[string match "*1-11.1*" $name]} { set fixture_role MASTER }
  if {[string match "*1-11.2*" $name]} { set fixture_role SLAVE }
  set role_source WDIAGS_MODE
  if {$fixture_role ne "UNKNOWN"} {
    if {$role eq "UNKNOWN"} {
      set role $fixture_role
      set role_source FIXTURE_CABLE
    } elseif {$role ne $fixture_role} {
      set role $fixture_role
      set role_source FIXTURE_CABLE_CONFLICT
    }
  }
  if {$role_source ne "WDIAGS_MODE"} {
    print_signal INFO "Role routing" ROLE_ROUTING \
      [format "fixture=%s observed=%s" $role $observed_role] \
      "fixed cable map" \
      "Milestone routing only; WDIAGS_MODE remains independent Step 2 evidence."
  }
  set mac_status WARN
  set mac_expected "ROLE"
  if {$role eq "MASTER"} {
    set mac_expected "02:00:22:33:44:01"
    if {$mac eq "TIMEOUT" || $mac eq "INVALID"} {
      set mac_status INVALID
    } elseif {$mac ne "02:00:22:33:44:01"} {
      set mac_status FAIL
    } else {
      set mac_status PASS
    }
    set mode_status [exact_status $mode 2]
    set ptp_status [exact_status $ptp_state 6]
  } elseif {$role eq "SLAVE"} {
    set mac_expected "02:00:22:33:44:02"
    if {$mac eq "TIMEOUT" || $mac eq "INVALID"} {
      set mac_status INVALID
    } elseif {$mac ne "02:00:22:33:44:02"} {
      set mac_status FAIL
    } else {
      set mac_status PASS
    }
    set mode_status [exact_status $mode 3]
    # PPS_UNCALIBRATED is a permitted startup transition; it is not an
    # immediate Step 2 hardware failure.  Focused time-series decides whether
    # the Slave reaches steady PPS_SLAVE.
    if {$ptp_num ne "" && $ptp_num == 8} {
      set ptp_status INFO
    } else {
      set ptp_status [exact_status $ptp_state 9]
    }
  } else {
    if {$mode_num eq "" || $ptp_num eq ""} {
      set mac_status INVALID
      set mode_status INVALID
      set ptp_status INVALID
    } else {
      set mac_status WARN
      set mode_status WARN
      set ptp_status WARN
    }
  }
  set step2 [merge_status $step2 $mac_status]
  set step2 [merge_status $step2 $mode_status]
  set step2 [merge_status $step2 $ptp_status]
  print_signal $mac_status "MAC Address" EP_MAC_H/EP_MAC_L $mac $mac_expected ""
  print_signal $mode_status "WR Mode" WDIAGS_MODE \
    [format "%s %s" [display_value $mode] \
      [expr {[numeric_equal $mode 2] ? "MASTER" : \
        ([numeric_equal $mode 3] ? "SLAVE" : "UNKNOWN")}]] \
    [expr {$role eq "MASTER" ? "2 MASTER" : ($role eq "SLAVE" ? "3 SLAVE" : "ROLE")} ] ""
  print_signal $ptp_status "PTP State" WDIAGS_PTP \
    [format "%s %s (raw=%s)" [display_value $ptp_state] [ptp_state_name $ptp_state] \
      [display_value $ptp]] \
    [expr {$role eq "MASTER" ? "6 MASTER" : ($role eq "SLAVE" ? "9 SLAVE" : "ROLE")} ] ""

  set step2_activity_invalid 0
  array set step2_activity {}
  foreach counter {
    {ptp_rx "PPSI PTP RX counter" WDIAGS_PTP_RX "PPSI-level PTP RX counter"}
    {ptp_tx "PPSI PTP TX counter" WDIAGS_PTP_TX "PPSI-level PTP TX counter"}
    {tx "MiniNIC TX frame counter" WDIAGS_TX "minic_get_stats() 的 frame-level TX counter"}
    {rx "MiniNIC RX frame counter" WDIAGS_RX "minic_get_stats() 的 frame-level RX counter"}
  } {
    set field [lindex $counter 0]
    set chinese [lindex $counter 1]
    set symbol [lindex $counter 2]
    set b [get_snap $board $before $field]
    set a [get_snap $board $after $field]
    set d [delta32 $b $a]
    set current [delta_status $d]
    if {$current eq "INVALID"} { set step2_activity_invalid 1 }
    set step2_activity($field) $d
    print_delta $current $chinese $symbol \
      $b $a $d "" "Δ>0"
  }
  set rb [get_snap $board $before rxerr]
  set ra [get_snap $board $after rxerr]
  set rd [delta32 $rb $ra]
  if {$rd eq "TIMEOUT"} {
    set rxerr_status INVALID
    set rxerr_explanation "JTAG snapshot 至少一筆逾時，沒有足夠證據判斷新增 RX error。"
    set rxerr_expected "Δ=0"
  } elseif {$rd eq "DECREASED"} {
    # A decrease is not a new error. It is compatible with reset, clear, or
    # a non-atomic snapshot boundary, so keep it informational for Step 2.
    set rxerr_status INFO
    set rxerr_explanation "after 小於 before；這表示 counter reset/clear 或 snapshot 邊界，不把它解讀成新增 error。"
    set rxerr_expected "Δ=0"
  } elseif {[numeric_equal $rd 0]} {
    set rxerr_status PASS
    set rxerr_explanation "delta=0 表示本次沒有新增 RX error。"
    set rxerr_expected "Δ=0"
  } else {
    set rxerr_status WARN
    set rxerr_explanation "delta>0 表示本次觀測期間出現 RX error；不單獨推論根因。"
    set rxerr_expected "Δ=0"
  }
  if {$rxerr_status eq "INVALID"} { set step2_activity_invalid 1 }
  print_delta $rxerr_status "MiniNIC RX error counter" WDIAGS_RXERR \
    $rb $ra $rd \
    $rxerr_explanation $rxerr_expected
  # Keep the summary consistent with the signal line. A positive RXERR
  # delta is a warning, not a single-window hardware FAIL, but it must not
  # leave the Step summary as PASS.
  set step2 [merge_status $step2 $rxerr_status]
  # PTP_TX can legitimately be quiet in one observation window.  Step 2 still
  # needs simultaneous PTP RX and MiniNIC TX/RX activity; if those three do
  # not all move, keep the dashboard result as measurement-incomplete/retest
  # instead of claiming a hardware failure.
  set packet_path_active 1
  foreach field {ptp_rx tx rx} {
    if {![info exists step2_activity($field)] ||
        ![string is integer -strict $step2_activity($field)] ||
        $step2_activity($field) <= 0} {
      set packet_path_active 0
    }
  }
  if {($step2_activity_invalid || !$packet_path_active) && $step2 eq "PASS"} {
    set step2 INVALID
  }
  # A valid but non-expected role/state in one snapshot still needs focused
  # repeated sampling before it can be called a regression failure.
  if {$step2 eq "FAIL"} { set step2 INVALID }
  if {$step2 ne "PASS" && $step2 ne "INVALID"} { mark_anomaly $board 2 $step2 "Endpoint/MiniNIC/PTP role" }
  set ::step_status($board,2) $step2
  puts [format "Step 2 %s" [step_status_text $step2]]

  # --------------------------------------------------------------
  # Step 3: WR parent / signaling handshake
  # --------------------------------------------------------------
  puts ""
  puts "## \[Step 3\] WR Parent / Signaling"
  if {$role eq "MASTER"} {
    set step3 INFO
  } elseif {$role ne "SLAVE"} {
    set step3 INFO
  } else {
    set step3 PASS
    set state_inconsistent 0
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
    print_signal $fc_status "Foreign Master" WDIAGS_FOREIGN_META [display_value $fc] "1" ""
    print_signal $best_status "Best Foreign Index" WDIAGS_FOREIGN_META [display_value $best] "0" ""
    print_signal INFO "Parent Metadata" WDIAGS_FOREIGN_META \
      [format "detection=%s config=%s" [display_value $parent_detection] [display_value $parent_wr_config]] \
      "source-defined" ""
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
      print_signal $current $chinese $symbol [display_value $value] "1" \
        "WDIAGS_PARSE_META 的 source-backed parent flag。"
    }
    set rx_signal [get_snap $board $after wr_rx_signal]
    set tx_signal [get_snap $board $after wr_tx_signal]
    set rx_id [field32 $rx_signal 16 16]
    set rx_count [field32 $rx_signal 0 16]
    set tx_id [field32 $tx_signal 16 16]
    set tx_count [field32 $tx_signal 0 16]
    if {$rx_count < 0 || $rx_id < 0} {
      set rx_ok INVALID
    } else {
      set rx_ok [expr {$rx_count > 0 && $rx_id == 0x1001 ? "PASS" : "WARN"}]
    }
    if {$tx_count < 0 || $tx_id < 0} {
      set tx_ok INVALID
    } else {
      set tx_ok [expr {$tx_count > 0 && $tx_id == 0x1000 ? "PASS" : "WARN"}]
    }
    set step3 [merge_status $step3 $rx_ok]
    set step3 [merge_status $step3 $tx_ok]
    if {$rx_id < 0} { set rx_id_display "TIMEOUT" } else { set rx_id_display [format "0x%04X" $rx_id] }
    if {$tx_id < 0} { set tx_id_display "TIMEOUT" } else { set tx_id_display [format "0x%04X" $tx_id] }
    print_signal $rx_ok "WR RX Message" WR_RX_SIGNAL_DEBUG \
      [format "%s count=%s" [signal_name $rx_id] [display_value $rx_count]] \
      "LOCK 0x1001,count>0" ""
    print_signal $tx_ok "WR TX Message" WR_TX_SIGNAL_DEBUG \
      [format "%s count=%s" [signal_name $tx_id] [display_value $tx_count]] \
      "SLAVE_PRESENT 0x1000,count>0" ""
    # Keep the mailbox text for field32().  Converting to an integer first
    # would make field32() parse the decimal representation as hexadecimal.
    set failure_raw [get_snap $board $after wr_failure]
    set failure_word [word32 $failure_raw]
    set fail_state [field32 $failure_raw 16 8]
    set fail_count [field32 $failure_raw 0 16]
    set lock_enable [word32 [get_snap $board $after lock_enable]]
    set lock_status [required_positive_status $lock_enable]
    set post_step3_timeout 0
    set wr_state [get_snap $board $after wr_state]
    set state [field32 $wr_state 11 4]
    set next_state [field32 $wr_state 15 4]
    if {$state < 0 || $next_state < 0} {
      set state_ok INVALID
    } elseif {$state == 0} {
      if {$fail_state == 2 && $fail_count > 0 && $lock_enable > 0} {
        # The source-backed failure shadow proves that WRS_S_LOCK and
        # locking_enable() were reached before a later handshake timeout.
        # That later timeout belongs to the post-Step-3 boundary, not the
        # Step 3 acceptance gate.
        set state_ok INFO
        set post_step3_timeout 1
      } else {
        set state_ok INVALID
        set state_inconsistent 1
      }
    } else {
      set state_ok [expr {$state >= 1 && $state <= 8 ? "PASS" : "WARN"}]
    }
    if {!$post_step3_timeout} { set step3 [merge_status $step3 $state_ok] }
    print_signal $state_ok "WR State" WDIAGS_TEMP \
      [format "%s next=%s%s" [wr_state_name $state] [wr_state_name $next_state] \
        [expr {$post_step3_timeout ? " POST_STEP3_TIMEOUT" : ($state_inconsistent ? " READ_INCONSISTENT" : "")}]] \
      [expr {$post_step3_timeout ? "NA" : "WRS_S_LOCK=2"}] ""
    set step3 [merge_status $step3 $lock_status]
    print_signal $lock_status "WR lock enable 次數" LOCK_ENABLE \
      [display_value $lock_enable] "> 0" \
      "locking_enable() 已被呼叫的 read-only counter；不等於 SoftPLL 已 lock。"
    if {$post_step3_timeout} {
      print_signal INFO "Post-Step3 lock stage" WR_FAILURE_DEBUG \
        [format "TIMEOUT last_fail_state=%s failure_count=%s" [wr_state_name $fail_state] [display_value $fail_count]] \
        "NA" ""
    }
    # A single WR state/parent snapshot is not enough to declare Step 3
    # broken. Keep the individual signal evidence, but require focused
    # repeated sampling before exposing a regression FAIL.
    if {$step3 eq "FAIL"} { set step3 INVALID }
    if {$step3 ne "PASS" && $step3 ne "INFO" && $step3 ne "INVALID"} {
      mark_anomaly $board 3 $step3 "WR parent/signaling handshake"
    }
  }
  set ::step_status($board,3) $step3
  puts [format "Step 3 %s" [step_status_text $step3]]

  # --------------------------------------------------------------
  # Step 4: Master event-chain closure; Slave startup observation
  # --------------------------------------------------------------
  puts ""
  if {$role eq "MASTER"} {
    puts "## \[Step 4A\] Master SoftPLL Event Chain"
    set step4 PASS

    # Match the validated closure reader: the accepted event is the sum of
    # the source-backed REF/FB dmtd_event_sys counters, followed by TAG,
    # TRR write/pop, IRQ and helper activity in one before/after window.
    set ref_b [get_snap $board $before dmtd_ref]
    set ref_a [get_snap $board $after dmtd_ref]
    set ref_d [delta32 $ref_b $ref_a]
    set fb_b [get_snap $board $before dmtd_fb]
    set fb_a [get_snap $board $after dmtd_fb]
    set fb_d [delta32 $fb_b $fb_a]
    if {$ref_d eq "DECREASED"} { incr ::wb_dmtd_ref_decrease_count }
    if {$fb_d eq "DECREASED"} { incr ::wb_dmtd_fb_decrease_count }
    set ref_status [delta_status $ref_d]
    set fb_status [delta_status $fb_d]
    print_delta $ref_status "DMTD reference accepted event" DMTD_REF_ACCEPT_EVENT \
      $ref_b $ref_a $ref_d "wr_softpll_ng.vhd dmtd_event_sys REF counter" "Δ>=0"
    print_delta $fb_status "DMTD feedback accepted event" DMTD_FB_ACCEPT_EVENT \
      $fb_b $fb_a $fb_d "wr_softpll_ng.vhd dmtd_event_sys FB counter" "Δ>=0"
    set accepted_delta INVALID
    if {[string is integer -strict $ref_d] &&
        [string is integer -strict $fb_d]} {
      set accepted_delta [expr {$ref_d + $fb_d}]
    }
    set accepted_status [required_delta_status $accepted_delta]
    puts [format {[%s] %-24s 結果: Δ=%s/Δ>0} \
      [status_text $accepted_status] DMTD_ACCEPT [display_value $accepted_delta]]
    set step4 [merge_status $step4 $accepted_status]

    foreach counter {
      {tag_valid tag SPLL_TAG_VALID_COUNT}
      {trr_write TRR_WRITE SPLL_TRR_WRITE_COUNT}
      {trr_pop trr_pop WRPC_SPLL_TRR_POP_COUNT}
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
        $b $a $d "validated Step 4 downstream event-chain counter" "Δ>0"
    }

    # The closure is only PASS when no boot generation or reset/re-entry
    # counter changes during the same measurement window.
    foreach counter {
      {boot_generation BOOT_GENERATION}
      {cpu_reset_count CPU_RESET_COUNT}
      {wr_core_reset_count WR_CORE_RESET_COUNT}
      {si_config_drop_count SI_CONFIG_DROP_COUNT}
    } {
      set field [lindex $counter 0]
      set symbol [lindex $counter 1]
      set b [get_snap $board $before $field]
      set a [get_snap $board $after $field]
      set d [delta32 $b $a]
      set current [required_zero_delta_status $d]
      set step4 [merge_status $step4 $current]
      print_delta $current "Step 4 reset/re-entry guard" $symbol \
        $b $a $d "closure reader requires zero reset/re-entry delta" "Δ=0"
    }
    puts [format "STEP4A_MASTER_EVENT_CHAIN = %s" $step4]
    set ::step4_master_status $step4
    set ::step4_master_name $name
    if {$step4 ne "PASS"} { mark_anomaly $board 4 $step4 "SoftPLL accepted-event chain" }
  } elseif {$role ne "SLAVE"} {
    puts "## \[Step 4\] SoftPLL Startup"
    set step4 INFO
    set ::step4b_allowed($board) NO
    set ::step4b_result($board) NOT_APPLICABLE
    set ::step4b_boundary($board) NOT_APPLICABLE
  } else {
    puts "## \[Step 4B\] Slave SoftPLL Startup"

    # Step 4B is a gated Slave milestone.  A single dashboard observation is
    # deliberately not allowed to convert absent upstream service into a
    # SoftPLL failure claim.
    set step4b_allowed [expr {$::step_status($board,1) eq "PASS" &&
                              $::step_status($board,2) eq "PASS" &&
                              $::step_status($board,3) eq "PASS" ? "YES" : "NO"}]
    set ::step4b_allowed($board) $step4b_allowed

    if {$step4b_allowed eq "NO"} {
      if {$::step_status($board,1) ne "PASS"} {
        set blocker BLOCKED_BY_STEP1
      } elseif {$::step_status($board,2) ne "PASS"} {
        set blocker BLOCKED_BY_STEP2
      } else {
        set blocker BLOCKED_BY_STEP3
      }
      set step4 INFO
      set ::step4b_result($board) $blocker
      set ::step4b_boundary($board) UPSTREAM_PREREQUISITE
      print_signal INFO "Step4B upstream gate" STEP4B_UPSTREAM_GATE \
        "BLOCKED" "Step1=PASS,Step2=PASS,Step3=PASS" \
        "Step4B is not evaluated until the Slave upstream PHY/PTP/WR gates are established."
      puts [format "STEP4B_ALLOWED = NO"]
      puts [format "STEP4B_RESULT = %s" $blocker]
      puts "STEP4B_FIRST_INACTIVE_BOUNDARY = UPSTREAM_PREREQUISITE"
      puts "Step 4B BLOCKED (upstream prerequisite)"
    } else {
      # ------------------------------------------------------------
      # Startup control evidence: LOCK -> WRS_S_LOCK -> locking_enable()
      # -> spll_init(SLAVE) -> active sequencer/RCER/OCER.
      # ------------------------------------------------------------
      # Keep the mailbox word as hexadecimal text while extracting fields.
      # field32() performs the single hex parse; converting to a Tcl integer
      # first would make field32() reinterpret its decimal rendering as hex.
      set spll_state_raw [get_snap $board $after spll_state]
      set spll_mode [field32 $spll_state_raw 16 8]
      set spll_align [field32 $spll_state_raw 8 8]
      set spll_seq [field32 $spll_state_raw 0 8]
      set lock_enable [word32 [get_snap $board $after lock_enable]]
      set spll_init [word32 [get_snap $board $after spll_init_count]]
      set spll_visit [word32 [get_snap $board $after spll_state_visit_mask]]
      set spll_transitions [word32 [get_snap $board $after spll_state_transitions]]
      set spll_last [word32 [get_snap $board $after spll_last_state]]
      set spll_ocode [word32 [get_snap $board $after spll_ocer]]
      set spll_rcode [word32 [get_snap $board $after spll_rcer]]
      set spll_occr_code [word32 [get_snap $board $after spll_occr]]

      set startup_status PASS
      set current [required_positive_status $lock_enable]
      set startup_status [merge_status $startup_status $current]
      print_signal $current "LOCK_ENABLE_COUNT" LOCK_ENABLE_COUNT \
        [display_value $lock_enable] "> 0" \
        "wrpc_spll_locking_enable() entry counter。"
      set current [exact_status $spll_mode 3]
      set startup_status [merge_status $startup_status $current]
      print_signal $current "SoftPLL mode" SPLL_MODE \
        [format "%s (%s)" [display_value $spll_mode] [spll_mode_name $spll_mode]] \
        "3 SPLL_MODE_SLAVE" "spll_init(SPLL_MODE_SLAVE, ...) 的 source-backed shadow。"
      set current [spll_sequence_status $spll_seq]
      set startup_status [merge_status $startup_status $current]
      print_signal $current "SoftPLL sequencer" SPLL_SEQ_STATE \
        [format "%s (%s)" [display_value $spll_seq] [state_name $spll_seq]] \
        "active, not 0/7" "SEQ_DISABLED=7；0 是未初始化診斷值。"
      set current [nonzero_state_status $spll_visit]
      set startup_status [merge_status $startup_status $current]
      print_signal $current "SoftPLL state visits" SPLL_STATE_VISIT_MASK \
        [format "0x%08X" $spll_visit] "> 0" \
        "state visit mask proves the sequencer entered a source-defined state。"
      set current [required_positive_status $spll_init]
      set startup_status [merge_status $startup_status $current]
      print_signal $current "SoftPLL init count" SPLL_INIT_COUNT \
        [display_value $spll_init] "> 0" \
        "spll_init() entry counter。"
      set current [required_positive_status $spll_rcode]
      set startup_status [merge_status $startup_status $current]
      print_signal $current "Reference channel enable" RCER \
        [format "0x%08X" $spll_rcode] "> 0" \
        "SoftPLL RCER readback after Slave startup。"
      set current [required_positive_status $spll_ocode]
      set startup_status [merge_status $startup_status $current]
      print_signal $current "Output channel enable" OCER \
        [format "0x%08X" $spll_ocode] "> 0" \
        "SoftPLL OCER readback after spll_init()。"
      print_signal INFO "Alignment state" SPLL_ALIGN_STATE \
        [display_value $spll_align] "source-defined" \
        "SoftPLL ext.align_state；不是 Step5 lock 判定。"
      print_signal INFO "State transitions" SPLL_STATE_TRANSITIONS \
        [format "0x%08X" $spll_transitions] "source-defined" \
        "wrpc_spll_state_transition_count。"
      set last_status [spll_sequence_status $spll_last]
      print_signal INFO "Last sequencer state" SPLL_LAST_STATE \
        [format "%s (%s)" [display_value $spll_last] [state_name $spll_last]] \
        "source-defined" "診斷 shadow，不單獨宣告 Step5 lock。"
      print_signal INFO "Output control register" OCCR \
        [format "0x%08X" $spll_occr_code] "source-defined" \
        "SoftPLL OCCR readback；保留作 startup context。"

      # ------------------------------------------------------------
      # Fixed-window event processing evidence.  This is downstream of
      # startup and is required for a complete Step4B PASS.
      # ------------------------------------------------------------
      set ref_b [get_snap $board $before dmtd_ref]
      set ref_a [get_snap $board $after dmtd_ref]
      set ref_d [delta32 $ref_b $ref_a]
      set fb_b [get_snap $board $before dmtd_fb]
      set fb_a [get_snap $board $after dmtd_fb]
      set fb_d [delta32 $fb_b $fb_a]
      if {$ref_d eq "DECREASED"} { incr ::wb_dmtd_ref_decrease_count }
      if {$fb_d eq "DECREASED"} { incr ::wb_dmtd_fb_decrease_count }
      print_delta [delta_status $ref_d] "DMTD reference accepted event" DMTD_REF_ACCEPT_EVENT \
        $ref_b $ref_a $ref_d "source-backed dmtd_event_sys REF counter" "Δ>=0"
      print_delta [delta_status $fb_d] "DMTD feedback accepted event" DMTD_FB_ACCEPT_EVENT \
        $fb_b $fb_a $fb_d "source-backed dmtd_event_sys FB counter" "Δ>=0"
      set accepted_delta INVALID
      if {[string is integer -strict $ref_d] && [string is integer -strict $fb_d]} {
        set accepted_delta [expr {$ref_d + $fb_d}]
      }
      set event_status [required_delta_status $accepted_delta]
      puts [format {[%s] %-24s 結果: Δ=%s/Δ>0} \
        [status_text $event_status] DMTD_ACCEPT [display_value $accepted_delta]]

      set tag_delta INVALID
      set trr_write_delta INVALID
      set trr_pop_delta INVALID
      set irq_delta INVALID
      set helper_delta INVALID
      foreach counter {
        {tag_valid tag SPLL_TAG_VALID_COUNT}
        {trr_write TRR_WRITE SPLL_TRR_WRITE_COUNT}
        {trr_pop trr_pop WRPC_SPLL_TRR_POP_COUNT}
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
        set event_status [merge_status $event_status $current]
        if {$field eq "tag_valid"} { set tag_delta $d }
        if {$field eq "trr_write"} { set trr_write_delta $d }
        if {$field eq "trr_pop"} { set trr_pop_delta $d }
        if {$field eq "irq"} { set irq_delta $d }
        if {$field eq "helper_update"} { set helper_delta $d }
        print_delta $current $chinese $symbol $b $a $d \
          "source-backed Step4B downstream event counter" "Δ>0"
      }

      set reset_status PASS
      foreach counter {
        {boot_generation BOOT_GENERATION}
        {cpu_reset_count CPU_RESET_COUNT}
        {wr_core_reset_count WR_CORE_RESET_COUNT}
        {si_config_drop_count SI_CONFIG_DROP_COUNT}
      } {
        set field [lindex $counter 0]
        set symbol [lindex $counter 1]
        set b [get_snap $board $before $field]
        set a [get_snap $board $after $field]
        set d [delta32 $b $a]
        set current [required_zero_delta_status $d]
        set reset_status [merge_status $reset_status $current]
        print_delta $current "Step4B reset/re-entry guard" $symbol \
          $b $a $d "Step4B requires zero reset/re-entry delta" "Δ=0"
      }

      set ::step4b_boundary($board) \
        [step4b_first_inactive_boundary $accepted_delta $tag_delta \
          $trr_write_delta $trr_pop_delta $irq_delta $helper_delta]
      if {$startup_status eq "PASS" && $event_status eq "PASS" &&
          $reset_status eq "PASS"} {
        set step4 PASS
        set ::step4b_result($board) PASS
      } elseif {$startup_status eq "PASS"} {
        set step4 INFO
        set ::step4b_result($board) STARTUP_PROVEN_EVENT_PROCESSING_NOT_PROVEN
      } else {
        set step4 INFO
        set ::step4b_result($board) STARTUP_NOT_PROVEN
        set ::step4b_boundary($board) SPLL_STARTUP
      }
      puts "STEP4B_ALLOWED = YES"
      puts [format "STEP4B_RESULT = %s" $::step4b_result($board)]
      puts [format "STEP4B_FIRST_INACTIVE_BOUNDARY = %s" $::step4b_boundary($board)]
      if {$step4 eq "PASS"} {
        puts "Step 4B pass"
      } else {
        puts [format "Step 4B %s" $::step4b_result($board)]
      }
    }
  }
  set ::step_status($board,4) $step4
  if {$role eq "MASTER"} {
    set ::step4a_master_status $step4
    set ::step4_master_status $step4
    set ::step4_master_name $name
  }
  puts [format "Step 4 %s" [step_status_text $step4]]

  # --------------------------------------------------------------
  # Step 5: closed-loop lock observability.  A two-snapshot dashboard window
  # may characterize acquisition/loss, but never proves stable lock.
  # --------------------------------------------------------------
  puts ""
  puts "## \[Step 5\] Closed-loop Lock"
  set pstat_raw [get_snap $board $after pstat]
  set pstat_locked [bit32 $pstat_raw 1]
  set time_valid [bit64_low $status_raw 4]
  set ::active_board $board
  if {$role ne "SLAVE"} {
    set step5 INFO
    set ::step5_result($board) NOT_APPLICABLE_MASTER
    set ::step5_boundary($board) SLAVE_ONLY
    puts "STEP5_RESULT = NOT_APPLICABLE_MASTER"
    puts "STEP5_FIRST_INACTIVE_BOUNDARY = SLAVE_ONLY"
    puts "Step 5 NA (Step5 closed-loop gate is for Slave)"
  } elseif {$step4 ne "PASS"} {
    set step5 INFO
    set ::step5_result($board) UPSTREAM_NOT_READY
    set ::step5_boundary($board) UPSTREAM_STEP4B
    puts "STEP5_RESULT = UPSTREAM_NOT_READY"
    puts "STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B"
    puts "Step 5 NA"
  } else {
    step5_print_lockdet before
    step5_print_lockdet after
    set before_boundary [step5_snapshot_boundary before]
    set after_boundary [step5_snapshot_boundary after]
    set before_locked [step5_snapshot_fully_locked before]
    set after_locked [step5_snapshot_fully_locked after]
    set step5 INFO
    if {$before_locked < 0 || $after_locked < 0} {
      set result OBSERVABILITY_INVALID
      set boundary SOURCE_SEMANTICS_NOT_PROVEN
    } elseif {$before_locked == 1 && $after_locked == 0} {
      set result LOCK_ACQUIRED_THEN_LOST
      set boundary $after_boundary
    } elseif {$after_locked == 1} {
      set result LOCK_ACQUIRED_NOT_STABLE
      set boundary STABILITY_WINDOW
    } else {
      set result NEVER_LOCKED
      set boundary $after_boundary
    }
    set ::step5_result($board) $result
    set ::step5_boundary($board) $boundary
    print_signal [exact_status $pstat_locked 1] "PSTAT Locked" WDIAGS_PSTAT \
      [display_value $pstat_locked] "1" \
      "WDIAGS_PSTAT bit 1；只作上層 lock supporting evidence。"
    puts [format "STEP5_RESULT = %s" $result]
    puts [format "STEP5_FIRST_INACTIVE_BOUNDARY = %s" $boundary]
    puts "Step 5 NA (single window is not stable-lock proof)"
  }
  set ::step_status($board,5) $step5
  if {$step5 ne "PASS" && $step5 ne "INFO"} {
    mark_anomaly $board 5 $step5 "PSTAT.locked / closed-loop lock"
  }

  # --------------------------------------------------------------
  # Step 6: global time / execute_at(T)
  # --------------------------------------------------------------
  puts ""
  puts "## \[Step 6\] Global Time"
  set ::step_status($board,6) INFO
  if {$step5 ne "PASS"} {
    puts "Step 6 NA"
  } else {
    print_signal INFO "Global Time" WDIAGS_SEC_H/SEC_L/NS \
      [format "%s/%s/%s" [display_value [get_snap $board $after sec_h]] \
        [display_value [get_snap $board $after sec_l]] [display_value [get_snap $board $after ns]]] \
      "time_valid=1；execute_at(T) 尚未驗證" ""
    puts "Step 6 NA"
  }

  puts ""
  puts "============================================================"
  puts [format "White Rabbit Runtime 診斷：%s" $name]
  puts "============================================================"
  foreach step {1 2 3 4 5 6} {
    set s $::step_status($board,$step)
    if {$step == 1} { set label "PHY / Link" }
    if {$step == 2} { set label "Endpoint / PTP" }
    if {$step == 3} { set label "WR Handshake" }
    if {$step == 4} {
      set label [expr {$role eq "MASTER" ? "Step4A Master Event Chain" : "Step4B Slave SoftPLL Startup"}]
    }
    if {$step == 5} { set label "Closed-loop Lock" }
    if {$step == 6} { set label "Global Time" }
    if {$s eq "INFO"} { set shown "NA" }
    if {$s eq "INVALID"} { set shown "NA" }
    if {$s eq "PASS"} { set shown "pass" }
    if {$s eq "WARN"} { set shown "error" }
    if {$s eq "FAIL"} { set shown "error" }
    if {$step == 4 && $role eq "SLAVE"} {
      if {[info exists ::step4b_allowed($board)] &&
          $::step4b_allowed($board) eq "NO"} {
        set shown "blocked"
      } elseif {$s eq "PASS"} {
        set shown "pass"
      } else {
        set shown "NA"
      }
    }
    puts [format "Step %d %-22s %s" $step $label $shown]
  }
  set step1_reg [regression_status 1 $::step_status($board,1)]
  set step2_reg [regression_status 2 $::step_status($board,2)]
  # Step 3 is a Slave WR-handshake gate; it is not applicable to the Master.
  if {$role eq "MASTER"} {
    set step3_reg PASS
  } else {
    set step3_reg [regression_status 3 $::step_status($board,3)]
  }
  set step4_allowed [expr {$step1_reg eq "PASS" &&
                           $step2_reg eq "PASS" &&
                           $step3_reg eq "PASS" ? "YES" : "NO"}]
  if {$step1_reg eq "INVALID" || $step2_reg eq "INVALID" ||
      $step3_reg eq "INVALID"} {
    set failure_class "JTAG/DASHBOARD_MEASUREMENT_FAILURE"
  } elseif {$step1_reg eq "FAIL" || $step2_reg eq "FAIL" ||
            $step3_reg eq "FAIL"} {
    set failure_class "HARDWARE/FIRMWARE_FAILURE"
  } else {
    set failure_class "NO_FAILURE_EVIDENCE"
  }
  if {$::raw_mode} {
    puts [format "STEP1_REGRESSION = %s" $step1_reg]
    puts [format "STEP2_REGRESSION = %s" $step2_reg]
    puts [format "STEP3_REGRESSION = %s" $step3_reg]
    if {$role eq "MASTER"} {
      puts [format "STEP4A_RESULT = %s" $::step4a_master_status]
    } elseif {$role eq "SLAVE"} {
      puts [format "STEP4B_ALLOWED = %s" $::step4b_allowed($board)]
      puts [format "STEP4B_RESULT = %s" $::step4b_result($board)]
      puts [format "STEP4B_FIRST_INACTIVE_BOUNDARY = %s" $::step4b_boundary($board)]
    }
    if {[info exists ::step5_result($board)]} {
      puts [format "STEP5_RESULT = %s" $::step5_result($board)]
      puts [format "STEP5_FIRST_INACTIVE_BOUNDARY = %s" $::step5_boundary($board)]
    }
    puts [format "FAILURE_CLASSIFICATION = %s" $failure_class]
  }
  puts "============================================================"
}

proc print_raw_snapshot {board label} {
  puts [format "RAW_SNAPSHOT board=%s label=%s" $::board_name($board) $label]
  foreach field {status cpu marker store store_count exception clock \
    boot_generation cpu_reset_count wr_core_reset_count si_config_drop_count \
    pps_cr pps_escr ep_mach ep_macl ep_dsr ptp ptp_rx ptp_tx ptp_meta \
    tx rx rxerr ptp_types foreign_meta filter_meta parse_meta wr_rx_signal \
    wr_tx_signal wr_failure wr_state wr_reject pstat sstat sec_h sec_l ns \
    lock_enable lock_result lock_polls lock_unlocked lock_calibration_fail \
    spll_state spll_ocer spll_rcer spll_occr spll_trr_csr spll_dac_hpll \
    spll_dac_main spll_helper_state spll_helper_limits spll_main_state \
    spll_main_limits spll_main_phase_limits \
    spll_state_visit_mask spll_state_transitions spll_last_state \
    spll_init_count dmtd_ref dmtd_fb \
    dmtd_ref_high_qual_abort dmtd_fb_high_qual_abort tag_valid trr_write irq \
    helper_update spll_helper_error spll_helper_output eic_isr current_tics} {
    puts [format "  %-16s = %s" $field [get_snap $board $label $field]]
  }
}

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  set board [format "b%02d" $::board_count]
  incr ::board_count
  set ::board_name($board) $hardware_name
  set ::first_anomaly($board) ""
  set ::wb_last_static_addr ""
  set ::wb_last_static_value ""
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    collect_snapshot $board before
    after $::observation_gap_ms
    collect_snapshot $board after
    analyze_board $board
    if {$::raw_mode} {
      puts ""
      puts "================ RAW_SNAPSHOT ================"
      print_raw_snapshot $board before
      print_raw_snapshot $board after
    }
  } error_message]} {
    puts [format {[info] JTAG_EXCEPTION 結果: %s/NA} $error_message]
  }
  catch { end_insystem_source_probe }
}

puts ""
puts "============================================================"
puts "JTAG/WB transport health summary"
puts "============================================================"
puts [format "WB_TRANSPORT_PROTOCOL = %s" $::wb_transport_protocol]
puts [format "WB_REQUEST_COUNT = %d" $::wb_request_count]
puts [format "PRELOAD_COUNT = %d" $::wb_preload_count]
puts [format "COMMIT_COUNT = %d" $::wb_commit_count]
puts [format "WB_PROBE_READ_COUNT = %d" $::wb_probe_read_count]
puts [format "PRELOAD_UNEXPECTED_TRIGGER_COUNT = %d" $::wb_preload_unexpected_trigger_count]
puts [format "PROBE_3WAY_MATCH_COUNT = %d" $::wb_probe_3way_match_count]
puts [format "STABLE_RESPONSE_WRONG_COUNT = %d" $::wb_stable_response_wrong_count]
puts [format "ADDRESS_CROSS_CONTAMINATION_COUNT = %d" $::wb_address_cross_contamination_count]
puts [format "TIMEOUT_COUNT = %d" $::wb_timeout_count]
puts [format "INVALID_COUNT = %d" $::wb_invalid_count]
puts [format "STALE_A5A5_COUNT = %d" $::wb_stale_count]
puts [format "UNSTABLE_TRANSACTION_COUNT = %d" $::wb_unstable_transaction_count]
puts [format "DMTD_REF_DECREASE_COUNT = %d" $::wb_dmtd_ref_decrease_count]
puts [format "DMTD_FB_DECREASE_COUNT = %d" $::wb_dmtd_fb_decrease_count]
if {$::wb_preload_unexpected_trigger_count == 0 &&
    $::wb_stable_response_wrong_count == 0 &&
    $::wb_address_cross_contamination_count == 0 &&
    $::wb_timeout_count == 0 && $::wb_invalid_count == 0 &&
    $::wb_stale_count == 0 && $::wb_dmtd_ref_decrease_count == 0 &&
    $::wb_dmtd_fb_decrease_count == 0} {
  puts "PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS"
  puts "JTAG_WB_DIAGNOSTIC_PATH = TRUSTED"
} else {
  puts "PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = FAIL"
  puts "JTAG_WB_DIAGNOSTIC_PATH = NOT_TRUSTED"
}
puts "============================================================"

if {$::step4_master_name ne "" || [array size ::step4b_result] > 0} {
  puts ""
  puts "============================================================"
  if {$::step4_master_name ne ""} {
    puts [format "STEP4A_RESULT = %s" $::step4a_master_status]
  }
  foreach board [array names ::step4b_result] {
    puts [format "STEP4B_ALLOWED = %s" $::step4b_allowed($board)]
    puts [format "STEP4B_RESULT = %s" $::step4b_result($board)]
    puts [format "STEP4B_FIRST_INACTIVE_BOUNDARY = %s" $::step4b_boundary($board)]
  }
  foreach board [array names ::step5_result] {
    puts [format "STEP5_RESULT = %s" $::step5_result($board)]
    puts [format "STEP5_FIRST_INACTIVE_BOUNDARY = %s" $::step5_boundary($board)]
  }
  puts "============================================================"
}
