# Read-only Step 6 observer for WR re-arm continuity and sampled stable offset.
# Uses one Slave JTAG session; no firmware, control, or mailbox writes.

package require ::quartus::insystem_source_probe

set ::trial_id "EXP-S6-WR-REARM-TO-STABLE-WINDOW-TRACE-20261001"
set ::pretrigger_timeout_ms 600000
set ::stable_window_ms 300000
set ::total_timeout_ms 900000
set ::sample_delay_ms 100
set ::invalid_row_limit 5
set ::clock_source UNKNOWN
set ::last_clock_ms -1
set ::last_clock_initialized 0

proc s6e_now_ms {} {
  set value ""
  if {![catch {clock clicks -milliseconds} clicks_value] &&
      [string is double -strict $clicks_value] &&
      [scan $clicks_value %f clicks_numeric] == 1} {
    set value [expr {wide(round($clicks_numeric))}]
    set ::clock_source clock_clicks_ms
  }
  if {$value eq ""} {
    set uptime_ms -1
    if {[catch {
      set uptime_fd [open /proc/uptime r]
      set uptime_line [gets $uptime_fd]
      close $uptime_fd
      if {![regexp {^([0-9]+)\.([0-9]+)} $uptime_line -> uptime_seconds uptime_fraction]} {
        error "invalid /proc/uptime record"
      }
      set uptime_fraction [string range "${uptime_fraction}000" 0 2]
      if {[scan $uptime_seconds %d uptime_seconds_numeric] != 1 ||
          [scan $uptime_fraction %d uptime_fraction_numeric] != 1} {
        error "invalid /proc/uptime fields"
      }
      set uptime_ms [expr {$uptime_seconds_numeric * 1000 + $uptime_fraction_numeric}]
    }]} {
      error "no supported monotonic elapsed-time clock"
    }
    set value $uptime_ms
    set ::clock_source proc_uptime_ms
  }
  if {$::last_clock_initialized && $value < $::last_clock_ms} {
    error "monotonic elapsed-time clock moved backwards"
  }
  set ::last_clock_ms $value
  set ::last_clock_initialized 1
  return $value
}

set ::capture_start_ms [s6e_now_ms]
set ::sample_count 0
set ::read_valid_count 0
set ::invalid_row_streak 0
set ::step1_established 0
set ::active_wr_seen 0
set ::failure_event_pending 0
set ::terminal_streak 0
set ::event_triggered 0
set ::event_kind NONE
set ::event_read_begin_ms -1
set ::event_read_end_ms -1
set ::event_elapsed_ms -1
set ::stop_reason NONE
set ::last_row_end_ms -1
array set ::reset_baseline {}
set ::previous_failure_count -1

set ::wb_library_mode 1
set ::repo_root [file normalize [file join [file dirname [info script]] .. .. .. ..]]
source [file join $::repo_root scripts jtag read_wb_runtime.tcl]
source [file join [file dirname [info script]] rearm_stable_policy.tcl]

proc s6e_raw_valid {value} {
  if {![is_hex $value]} { return 0 }
  set text $value
  if {[string length $text] > 8} {
    set high_word [word32 [string range $text 0 end-8]]
    if {$high_word >= 0 && (($high_word >> 16) & 0xffff) == 0xA5A5} {
      return 0
    }
  }
  if {[stale_jtag_word $value]} { return 0 }
  return [expr {[word32 $value] >= 0}]
}

proc s6e_status_step1 {status} {
  if {![is_hex $status]} { return -1 }
  foreach bit {0 1 2 3 6 7 15} {
    if {[bit32 $status $bit] != 1} { return 0 }
  }
  foreach bit {11 12 13 14} {
    if {[bit32 $status $bit] != 0} { return 0 }
  }
  if {[bit64_high $status 0] != 1} { return 0 }
  return 1
}

proc s6e_timed_read {reader addr} {
  set begin [s6e_now_ms]
  set value [uplevel #0 [list $reader $addr]]
  set end [s6e_now_ms]
  return [list $value $begin $end]
}

proc s6e_signal_id {word} {
  set value [word32 $word]
  if {$value < 0} { return -1 }
  return [expr {($value >> 16) & 0xffff}]
}

proc s6e_signal_count {word} {
  set value [word32 $word]
  if {$value < 0} { return -1 }
  return [expr {$value & 0xffff}]
}

proc s6e_state_name {state} {
  switch -- $state {
    0 { return WRS_IDLE }
    1 { return WRS_PRESENT }
    2 { return WRS_S_LOCK }
    3 { return WRS_M_LOCK }
    4 { return WRS_LOCKED }
    5 { return WRS_CALIBRATION }
    6 { return WRS_CALIBRATED }
    7 { return WRS_RESP_CALIB_REQ }
    8 { return WRS_WR_LINK_ON }
  }
  return UNKNOWN
}

proc s6r_signed32 {raw} {
  set value [word32 $raw]
  if {$value < 0} { return -1 }
  if {$value >= 0x80000000} { return [expr {$value - 0x100000000}] }
  return $value
}

proc s6r_u64 {raw} {
  if {![regexp {^[0-9A-Fa-f]{1,16}$} $raw]} { return -1 }
  if {![s6e_raw_valid $raw]} { return -1 }
  scan $raw %x value
  return $value
}

proc s6r_read_phase_frame {} {
  set wait_begin [s6e_now_ms]
  set baseline_raw [wb_read 0x00100B34]
  set baseline_word [word32 $baseline_raw]
  set baseline_epoch [expr {$baseline_word < 0 ? -1 : ($baseline_word & 0xffff)}]
  set result [dict create FRAME_VALID 0 WAIT_BEGIN_MS $wait_begin \
    FRAME_START_MS -1 FRAME_END_MS -1 WAIT_MS -1 \
    CTRL_BEFORE_RAW TIMEOUT CTRL_AFTER_RAW TIMEOUT \
    DATA_VALID_BEFORE -1 DATA_VALID_AFTER -1 SNAPSHOT_BEFORE -1 SNAPSHOT_AFTER -1 \
    MAP_BEFORE_RAW TIMEOUT MAP_AFTER_RAW TIMEOUT \
    INVERSE_BEFORE_RAW TIMEOUT INVERSE_AFTER_RAW TIMEOUT \
    MAP_EPOCH_BEFORE -1 MAP_EPOCH_AFTER -1 \
    A6C_READ_BEGIN_MS -1 A6C_READ_END_MS -1 \
    A8C_READ_BEGIN_MS -1 A8C_READ_END_MS -1 \
    WR_STATE_READ_BEGIN_MS -1 WR_STATE_READ_END_MS -1 \
    WR_RX_READ_BEGIN_MS -1 WR_RX_READ_END_MS -1 \
    WR_TX_READ_BEGIN_MS -1 WR_TX_READ_END_MS -1 \
    WR_STATE_RAW TIMEOUT WR_RX_RAW TIMEOUT WR_TX_RAW TIMEOUT \
    WR_FAILURE_RAW TIMEOUT LOCK_RESULT_RAW TIMEOUT \
    SSTAT_RAW TIMEOUT PSTAT_RAW TIMEOUT PTP_STATE_RAW TIMEOUT PTP_META_RAW TIMEOUT \
    CKO_RAW TIMEOUT SETP_RAW TIMEOUT UCNT_RAW TIMEOUT \
    SPLL_STATE_RAW TIMEOUT HELPER_STATE_RAW TIMEOUT MAIN_STATE_RAW TIMEOUT]

  while {[s6e_now_ms] - $wait_begin < 350} {
    set map_candidate_raw [wb_read 0x00100B34]
    set map_candidate [word32 $map_candidate_raw]
    if {$map_candidate >= 0} {
      set epoch [expr {$map_candidate & 0xffff}]
      if {$baseline_epoch < 0} {
        set baseline_epoch $epoch
      } elseif {$epoch != $baseline_epoch} {
        set ctrl_before_raw [wb_read 0x00100A04]
        set map_before_raw $map_candidate_raw
        set inverse_before_raw [wb_read 0x00100B38]
        set ctrl_before [word32 $ctrl_before_raw]
        set map_before [word32 $map_before_raw]
        set inverse_before [word32 $inverse_before_raw]
        set data_valid_before [expr {$ctrl_before < 0 ? 0 : ($ctrl_before & 1)}]
        set snapshot_before [expr {$ctrl_before < 0 ? -1 : (($ctrl_before >> 8) & 1)}]
        if {$data_valid_before == 1 && $snapshot_before == 0 &&
            $map_before >= 0 && $inverse_before >= 0 &&
            (($map_before ^ $inverse_before) & 0xffffffff) == 0xffffffff} {
          set frame_start [s6e_now_ms]
          set payload {}
          foreach {name address reader} {
            WR_STATE_RAW 0x00100A4C wb_read_critical
            WR_RX_RAW 0x00100A64 wb_read_validated
            WR_TX_RAW 0x00100A68 wb_read_validated
            WR_FAILURE_RAW 0x00100A6C wb_read_validated
            LOCK_RESULT_RAW 0x00100A8C wb_read
            SSTAT_RAW 0x00100A08 wb_read_validated
            PSTAT_RAW 0x00100A0C wb_read_validated
            PTP_STATE_RAW 0x00100A10 wb_read_validated
            PTP_META_RAW 0x00100A5C wb_read_validated
            CKO_RAW 0x00100A40 wb_read_validated
            SETP_RAW 0x00100A44 wb_read_validated
            UCNT_RAW 0x00100A48 wb_read_validated
            SPLL_STATE_RAW 0x00100AA0 wb_read_validated
            HELPER_STATE_RAW 0x00100ABC wb_read_validated
            MAIN_STATE_RAW 0x00100AC4 wb_read_validated
          } {
            if {$name eq "WR_FAILURE_RAW"} {
              lassign [s6e_timed_read $reader $address] value begin end
              dict set result A6C_READ_BEGIN_MS $begin
              dict set result A6C_READ_END_MS $end
            } elseif {$name eq "LOCK_RESULT_RAW"} {
              lassign [s6e_timed_read $reader $address] value begin end
              dict set result A8C_READ_BEGIN_MS $begin
              dict set result A8C_READ_END_MS $end
            } elseif {$name in {WR_STATE_RAW WR_RX_RAW WR_TX_RAW}} {
              lassign [s6e_timed_read $reader $address] value begin end
              dict set result ${name}_READ_BEGIN_MS $begin
              dict set result ${name}_READ_END_MS $end
            } else {
              set value [$reader $address]
            }
            dict set payload $name $value
          }
          set map_after_raw [wb_read 0x00100B34]
          set inverse_after_raw [wb_read 0x00100B38]
          set ctrl_after_raw [wb_read 0x00100A04]
          set frame_end [s6e_now_ms]
          set map_after [word32 $map_after_raw]
          set inverse_after [word32 $inverse_after_raw]
          set ctrl_after [word32 $ctrl_after_raw]
          set data_valid_after [expr {$ctrl_after < 0 ? 0 : ($ctrl_after & 1)}]
          set snapshot_after [expr {$ctrl_after < 0 ? -1 : (($ctrl_after >> 8) & 1)}]
          set frame_valid 1
          dict for {key value} $payload {
            if {![s6e_raw_valid $value]} { set frame_valid 0 }
          }
          if {$map_after < 0 || $inverse_after < 0 || $ctrl_after < 0 ||
              $map_before != $map_after || $inverse_before != $inverse_after ||
              (($map_after ^ $inverse_after) & 0xffffffff) != 0xffffffff ||
              $data_valid_after != 1 || $snapshot_after != 0} {
            set frame_valid 0
          }
          dict set result FRAME_VALID $frame_valid
          dict set result WAIT_MS [expr {$frame_start - $wait_begin}]
          dict set result FRAME_START_MS $frame_start
          dict set result FRAME_END_MS $frame_end
          dict set result CTRL_BEFORE_RAW $ctrl_before_raw
          dict set result CTRL_AFTER_RAW $ctrl_after_raw
          dict set result DATA_VALID_BEFORE $data_valid_before
          dict set result DATA_VALID_AFTER $data_valid_after
          dict set result SNAPSHOT_BEFORE $snapshot_before
          dict set result SNAPSHOT_AFTER $snapshot_after
          dict set result MAP_BEFORE_RAW $map_before_raw
          dict set result MAP_AFTER_RAW $map_after_raw
          dict set result INVERSE_BEFORE_RAW $inverse_before_raw
          dict set result INVERSE_AFTER_RAW $inverse_after_raw
          dict set result MAP_EPOCH_BEFORE [expr {$map_before & 0xffff}]
          dict set result MAP_EPOCH_AFTER [expr {$map_after & 0xffff}]
          dict for {key value} $payload { dict set result $key $value }
          break
        }
        set baseline_epoch $epoch
      }
    }
    after 1
  }
  if {[dict get $result WAIT_MS] < 0} {
    dict set result WAIT_MS [expr {[s6e_now_ms] - $wait_begin}]
  }
  return $result
}

proc s6r_read_global_time {status_raw} {
  set frame_begin [s6e_now_ms]
  set live_raw [safe_probe_read 64]
  set seq_before_raw [safe_probe_read 63]
  set snapshot_raw [safe_probe_read 62]
  set seq_after_raw [safe_probe_read 63]
  set frame_end [s6e_now_ms]
  set live [s6r_u64 $live_raw]
  set seq_before [s6r_u64 $seq_before_raw]
  set snapshot [s6r_u64 $snapshot_raw]
  set seq_after [s6r_u64 $seq_after_raw]
  set status [s6r_u64 $status_raw]
  set stable [expr {$seq_before >= 0 && $seq_before == $seq_after ? 1 : 0}]
  set frame_valid [expr {$live >= 0 && $seq_before >= 0 && $snapshot >= 0 &&
    $seq_after >= 0 && $status >= 0 && $stable ? 1 : 0}]
  set tai NA
  set cycles NA
  set time_valid -1
  set pps_valid -1
  set snapshot_valid -1
  set snapshot_count -1
  set live_tai_low NA
  set live_cycles NA
  set status_time_valid -1
  set status_pps_valid -1
  if {$frame_valid} {
    set tai [expr {$snapshot & 0xffffffffff}]
    set cycles [expr {(($snapshot >> 40) & 0xffffff) | (($seq_after & 0xf) << 24)}]
    set time_valid [expr {($seq_after >> 4) & 1}]
    set pps_valid [expr {($seq_after >> 5) & 1}]
    set snapshot_valid [expr {($seq_after >> 6) & 1}]
    set snapshot_count [expr {($seq_after >> 7) & 0xffff}]
    set live_tai_low [expr {$live & 0xfffffffff}]
    set live_cycles [expr {($live >> 36) & 0xfffffff}]
    set status_time_valid [expr {($status >> 4) & 1}]
    set status_pps_valid [expr {($status >> 5) & 1}]
  }
  set time_ok [expr {$frame_valid && $snapshot_valid == 1 &&
    $time_valid == 1 && $pps_valid == 1 &&
    $status_time_valid == 1 && $status_pps_valid == 1 ? 1 : 0}]
  return [dict create GLOBAL_FRAME_VALID $frame_valid GLOBAL_TIME_OK $time_ok \
    TIME_FRAME_BEGIN_MS $frame_begin TIME_FRAME_END_MS $frame_end \
    LIVE_RAW $live_raw TIME_SEQ_BEFORE_RAW $seq_before_raw \
    TIME_SNAPSHOT_RAW $snapshot_raw TIME_SEQ_AFTER_RAW $seq_after_raw \
    TIME_SEQ_STABLE $stable TAI $tai CYCLES $cycles \
    LIVE_TAI_LOW $live_tai_low LIVE_CYCLES $live_cycles \
    TIME_VALID $time_valid PPS_VALID $pps_valid SNAPSHOT_VALID $snapshot_valid \
    SNAPSHOT_COUNT $snapshot_count STATUS_TIME_VALID $status_time_valid \
    STATUS_PPS_VALID $status_pps_valid]
}

proc s6e_read_row {sample elapsed_ms} {
  set row_start [s6e_now_ms]
  set health_begin [s6e_now_ms]
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set health_end [s6e_now_ms]

  # One active WDIAGS publication is protected by DATA_VALID and the
  # firmware mapping counter/inverse. Global Time uses its own 63/62/63
  # snapshot guard in this same JTAG session.
  set phase [s6r_read_phase_frame]
  set global_time [s6r_read_global_time $status]
  set row_end [s6e_now_ms]
  set elapsed_ms [expr {$row_end - $::capture_start_ms}]
  set row_spacing -1
  if {$::last_row_end_ms >= 0} {
    set row_spacing [expr {$row_start - $::last_row_end_ms}]
  }
  set ::last_row_end_ms $row_end

  set boot_generation [probe_high_counter_hex $entry]
  set cpu_reset_count [probe_byte_counter_hex $reset 16]
  set wr_core_reset_count [probe_byte_counter_hex $reset 24]
  set si_config_drop_count [probe_byte_counter_hex $reset 40]
  set reset_signature_valid 1
  foreach value [list $boot_generation $cpu_reset_count $wr_core_reset_count $si_config_drop_count] {
    if {$value eq "INVALID" || $value eq "TIMEOUT"} { set reset_signature_valid 0 }
  }
  set step1_gate [s6e_status_step1 $status]
  set state_raw [dict get $phase WR_STATE_RAW]
  set tx_raw [dict get $phase WR_TX_RAW]
  set rx_raw [dict get $phase WR_RX_RAW]
  set state_word [word32 $state_raw]
  set state_value [expr {$state_word < 0 ? -1 : (($state_word >> 11) & 0xf)}]
  set next_state [expr {$state_word < 0 ? -1 : (($state_word >> 15) & 0xf)}]
  set wr_tag [expr {$state_word < 0 ? -1 : (($state_word >> 28) & 0xf)}]
  set wr_mode [expr {$state_word < 0 ? -1 : (($state_word >> 21) & 0x7)}]
  set wr_mode_on [expr {$state_word < 0 ? -1 : ($state_word & 1)}]
  set parent_is_wr [expr {$state_word < 0 ? -1 : (($state_word >> 3) & 1)}]
  set parent_wr_config [expr {$state_word < 0 ? -1 : (($state_word >> 8) & 0x7)}]
  set parent_detection [expr {$state_word < 0 ? -1 : (($state_word >> 19) & 0x3)}]
  set rx_id [s6e_signal_id $rx_raw]
  set rx_count [s6e_signal_count $rx_raw]
  set tx_id [s6e_signal_id $tx_raw]
  set tx_count [s6e_signal_count $tx_raw]
  set state_valid [expr {
    [s6e_raw_valid $state_raw] && $wr_tag == 0xA &&
    $state_value >= 0 && $state_value <= 8 &&
    $next_state >= 0 && $next_state <= 8}]
  set rx_valid [expr {[s6e_raw_valid $rx_raw] && $rx_id >= 0 && $rx_count >= 0}]
  set tx_valid [expr {[s6e_raw_valid $tx_raw] && $tx_id >= 0 && $tx_count >= 0}]
  set event_kind NONE
  set event_begin -1
  set event_end -1
  if {$state_valid && $state_value == 2 && $next_state == 4} {
    set event_kind SLOCK_HANDOFF_NEXT_LOCKED
    set event_begin [dict get $phase WR_STATE_READ_BEGIN_MS]
    set event_end [dict get $phase WR_STATE_READ_END_MS]
  } elseif {$state_valid && $state_value == 4} {
    set event_kind WRS_LOCKED_STATE
    set event_begin [dict get $phase WR_STATE_READ_BEGIN_MS]
    set event_end [dict get $phase WR_STATE_READ_END_MS]
  } elseif {$tx_valid && $tx_id == 0x1002 && $tx_count > 0} {
    set event_kind TX_LOCKED_SEND_SUCCESS
    set event_begin [dict get $phase WR_TX_READ_BEGIN_MS]
    set event_end [dict get $phase WR_TX_READ_END_MS]
  }
  set event_evidence_valid [expr {$state_valid && $tx_valid ? 1 : 0}]

  set failure_raw [dict get $phase WR_FAILURE_RAW]
  set lock_result_raw [dict get $phase LOCK_RESULT_RAW]
  set decoded [::s6r::decode_failure_words $failure_raw $lock_result_raw]
  set failure_count [dict get $decoded FAILURE_COUNT_U8]
  set failure_reason [dict get $decoded FAILURE_REASON]
  set failure_reason_valid [dict get $decoded VALID]
  set disable_valid [dict get $decoded DISABLE_VALID]
  set disable_cause [dict get $decoded DISABLE_CAUSE]
  set disable_ptp_state [dict get $decoded DISABLE_PTP_STATE]
  set wr_role [dict get $decoded FAILED_ROLE]
  set wr_failed_state [dict get $decoded FAILED_STATE]

  set frame_valid [dict get $phase FRAME_VALID]
  set global_frame_valid [dict get $global_time GLOBAL_FRAME_VALID]
  set raw_valid [expr {
    [s6e_raw_valid $status] && [s6e_raw_valid $entry] &&
    [s6e_raw_valid $reset] && $reset_signature_valid &&
    $frame_valid == 1 && $global_frame_valid == 1 &&
    $step1_gate >= 0 && $state_valid && $rx_valid && $tx_valid &&
    [dict get $decoded VALID] == 1}]
  set cko_raw [dict get $phase CKO_RAW]
  set setp_raw [dict get $phase SETP_RAW]
  set sstat_raw [dict get $phase SSTAT_RAW]
  set ucnt_raw [dict get $phase UCNT_RAW]
  set cko_ps [s6r_signed32 $cko_raw]
  set setp_ps [s6r_signed32 $setp_raw]
  set sstat_word [word32 $sstat_raw]
  set servo_state [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 8) & 0xf)}]
  set spll_word [word32 [dict get $phase SPLL_STATE_RAW]]
  set helper_word [word32 [dict get $phase HELPER_STATE_RAW]]
  set main_word [word32 [dict get $phase MAIN_STATE_RAW]]
  set pstat_word [word32 [dict get $phase PSTAT_RAW]]
  set ptp_state_word [word32 [dict get $phase PTP_STATE_RAW]]
  set ptp_meta_word [word32 [dict get $phase PTP_META_RAW]]
  set helper_lock [expr {$helper_word < 0 ? -1 : ($helper_word & 1)}]
  set main_enabled [expr {$main_word < 0 ? -1 : ($main_word & 1)}]
  set main_lock [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq_lock [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase_lock [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  set pstat_lock [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]
  set spll_sequence [expr {$spll_word < 0 ? -1 : ($spll_word & 0xff)}]
  set ptp_state [expr {$ptp_state_word < 0 ? -1 : ($ptp_state_word & 0xff)}]
  set ptp_meta_state [expr {$ptp_meta_word < 0 ? -1 : ($ptp_meta_word & 0xff)}]
  set pdstate [expr {$ptp_meta_word < 0 ? -1 : (($ptp_meta_word >> 8) & 0xff)}]
  set extstate [expr {$ptp_meta_word < 0 ? -1 : (($ptp_meta_word >> 16) & 0xff)}]
  set protocol_extension [expr {$ptp_meta_word < 0 ? -1 : (($ptp_meta_word >> 24) & 0xff)}]

  set row [dict create \
    SAMPLE $sample ELAPSED_MS $elapsed_ms ROW_START_MS $row_start ROW_END_MS $row_end \
    ROW_SPACING_MS $row_spacing HEALTH_BEGIN_MS $health_begin HEALTH_END_MS $health_end \
    STATUS_RAW $status ENTRY_RAW $entry RESET_RAW $reset \
    STEP1_GATE $step1_gate BOOT_GENERATION $boot_generation CPU_RESET_COUNT $cpu_reset_count \
    WR_CORE_RESET_COUNT $wr_core_reset_count SI_CONFIG_DROP_COUNT $si_config_drop_count \
    RESET_SIGNATURE_VALID $reset_signature_valid RESET_CHANGED 0 \
    READ_VALID $raw_valid ROW_RAW_VALID $raw_valid EVENT_EVIDENCE_VALID $event_evidence_valid \
    CONTEXT_READ_VALID [expr {$frame_valid && $global_frame_valid}] \
    WR_STATE_RAW $state_raw WR_STATE $state_value WR_STATE_NAME [s6e_state_name $state_value] \
    WR_NEXT_STATE $next_state WR_TAG $wr_tag WR_MODE $wr_mode WR_MODE_ON $wr_mode_on \
    PARENT_IS_WR $parent_is_wr PARENT_WR_CONFIG $parent_wr_config PARENT_DETECTION $parent_detection \
    STATE_READ_VALID $state_valid STATE_READ_BEGIN_MS [dict get $phase WR_STATE_READ_BEGIN_MS] \
    STATE_READ_END_MS [dict get $phase WR_STATE_READ_END_MS] \
    WR_RX_RAW $rx_raw WR_RX_ID $rx_id WR_RX_COUNT $rx_count RX_READ_VALID $rx_valid \
    RX_READ_BEGIN_MS [dict get $phase WR_RX_READ_BEGIN_MS] RX_READ_END_MS [dict get $phase WR_RX_READ_END_MS] \
    WR_TX_RAW $tx_raw WR_TX_ID $tx_id WR_TX_COUNT $tx_count TX_READ_VALID $tx_valid \
    TX_READ_BEGIN_MS [dict get $phase WR_TX_READ_BEGIN_MS] TX_READ_END_MS [dict get $phase WR_TX_READ_END_MS] \
    ROW_EVENT_KIND $event_kind EVENT_READ_BEGIN_MS $event_begin EVENT_READ_END_MS $event_end \
    EVENT_ELAPSED_MS [expr {$event_end < 0 ? -1 : ($event_end - $::capture_start_ms)}] \
    WR_FAILURE_RAW $failure_raw WR_FAILURE_COUNT_U8 $failure_count \
    WR_FAILURE_ROLE $wr_role WR_FAILURE_STATE $wr_failed_state \
    A6C_READ_BEGIN_MS [dict get $phase A6C_READ_BEGIN_MS] A6C_READ_END_MS [dict get $phase A6C_READ_END_MS] \
    WR_FAILURE_REASON_VALID $failure_reason_valid WR_FAILURE_REASON $failure_reason \
    WR_DISABLE_VALID $disable_valid WR_DISABLE_CAUSE $disable_cause WR_DISABLE_PTP_STATE $disable_ptp_state \
    LOCK_RESULT_RAW $lock_result_raw A8C_RESULT [dict get $decoded A8C_RESULT] \
    A8C_CHECK_LOCK [dict get $decoded A8C_CHECK_LOCK] A8C_FAILURE_TICS_LOW16 [dict get $decoded FAILURE_TICS_LOW16] \
    A8C_READ_BEGIN_MS [dict get $phase A8C_READ_BEGIN_MS] A8C_READ_END_MS [dict get $phase A8C_READ_END_MS] \
    DIAG_FRAME_VALID $frame_valid DIAG_WAIT_BEGIN_MS [dict get $phase WAIT_BEGIN_MS] \
    DIAG_WAIT_MS [dict get $phase WAIT_MS] DIAG_FRAME_START_MS [dict get $phase FRAME_START_MS] \
    DIAG_FRAME_END_MS [dict get $phase FRAME_END_MS] \
    DIAG_CTRL_BEFORE_RAW [dict get $phase CTRL_BEFORE_RAW] DIAG_CTRL_AFTER_RAW [dict get $phase CTRL_AFTER_RAW] \
    DIAG_VALID_BEFORE [dict get $phase DATA_VALID_BEFORE] DIAG_VALID_AFTER [dict get $phase DATA_VALID_AFTER] \
    DIAG_SNAPSHOT_BEFORE [dict get $phase SNAPSHOT_BEFORE] DIAG_SNAPSHOT_AFTER [dict get $phase SNAPSHOT_AFTER] \
    DIAG_MAP_BEFORE_RAW [dict get $phase MAP_BEFORE_RAW] DIAG_MAP_AFTER_RAW [dict get $phase MAP_AFTER_RAW] \
    DIAG_INVERSE_BEFORE_RAW [dict get $phase INVERSE_BEFORE_RAW] DIAG_INVERSE_AFTER_RAW [dict get $phase INVERSE_AFTER_RAW] \
    DIAG_MAP_EPOCH_BEFORE [dict get $phase MAP_EPOCH_BEFORE] DIAG_MAP_EPOCH_AFTER [dict get $phase MAP_EPOCH_AFTER] \
    SPLL_STATE_RAW [dict get $phase SPLL_STATE_RAW] SPLL_SEQ_STATE $spll_sequence \
    HELPER_STATE_RAW [dict get $phase HELPER_STATE_RAW] HELPER_LOCK $helper_lock \
    MAIN_STATE_RAW [dict get $phase MAIN_STATE_RAW] MAIN_ENABLED $main_enabled \
    MAIN_FREQ_LOCK $main_freq_lock MAIN_PHASE_LOCK $main_phase_lock MAIN_LOCK $main_lock \
    PSTAT_RAW [dict get $phase PSTAT_RAW] PSTAT_LOCK $pstat_lock \
    SSTAT_RAW $sstat_raw SERVO_STATE $servo_state CKO_RAW $cko_raw CKO_PS $cko_ps \
    SETP_RAW $setp_raw SETP_PS $setp_ps UCNT_RAW $ucnt_raw UCNT [word32 $ucnt_raw] \
    PTP_STATE_RAW [dict get $phase PTP_STATE_RAW] PTP_STATE $ptp_state \
    PTP_META_RAW [dict get $phase PTP_META_RAW] PTP_META_STATE $ptp_meta_state \
    PDSTATE $pdstate EXTSTATE $extstate PROTOCOL_EXTENSION $protocol_extension]
  dict for {key value} $global_time { dict set row $key $value }
  return $row
}
proc s6r_emit_sample {row} {
  set keys {
    SAMPLE ELAPSED_MS ROW_START_MS ROW_END_MS ROW_SPACING_MS
    ROW_RAW_VALID RESET_SIGNATURE_VALID RESET_CHANGED
    STATUS_RAW ENTRY_RAW RESET_RAW BOOT_GENERATION CPU_RESET_COUNT WR_CORE_RESET_COUNT SI_CONFIG_DROP_COUNT
    STEP1_GATE
    DIAG_FRAME_VALID DIAG_WAIT_BEGIN_MS DIAG_WAIT_MS DIAG_FRAME_START_MS DIAG_FRAME_END_MS
    DIAG_CTRL_BEFORE_RAW DIAG_CTRL_AFTER_RAW DIAG_VALID_BEFORE DIAG_VALID_AFTER
    DIAG_SNAPSHOT_BEFORE DIAG_SNAPSHOT_AFTER DIAG_MAP_BEFORE_RAW DIAG_MAP_AFTER_RAW
    DIAG_INVERSE_BEFORE_RAW DIAG_INVERSE_AFTER_RAW DIAG_MAP_EPOCH_BEFORE DIAG_MAP_EPOCH_AFTER
    GLOBAL_FRAME_VALID TIME_FRAME_BEGIN_MS TIME_FRAME_END_MS LIVE_RAW LIVE_TAI_LOW LIVE_CYCLES
    TIME_SEQ_BEFORE_RAW TIME_SEQ_AFTER_RAW TIME_SNAPSHOT_RAW TIME_SEQ_STABLE
    TIME_VALID PPS_VALID SNAPSHOT_VALID SNAPSHOT_COUNT
    STATUS_TIME_VALID STATUS_PPS_VALID GLOBAL_TIME_OK TAI CYCLES
    WR_STATE_RAW WR_STATE WR_STATE_NAME WR_NEXT_STATE STATE_READ_VALID STATE_READ_BEGIN_MS STATE_READ_END_MS
    WR_RX_RAW WR_RX_ID WR_RX_COUNT RX_READ_VALID RX_READ_BEGIN_MS RX_READ_END_MS
    WR_TX_RAW WR_TX_ID WR_TX_COUNT TX_READ_VALID TX_READ_BEGIN_MS TX_READ_END_MS
    ROW_EVENT_KIND EVENT_EVIDENCE_VALID EVENT_READ_BEGIN_MS EVENT_READ_END_MS EVENT_ELAPSED_MS
    WR_FAILURE_RAW WR_FAILURE_COUNT_U8 WR_FAILURE_ROLE WR_FAILURE_STATE WR_FAILURE_REASON_VALID WR_FAILURE_REASON
    FAILURE_DELTA_U8 NEW_FAILURE_RECORD A6C_READ_BEGIN_MS A6C_READ_END_MS
    LOCK_RESULT_RAW A8C_RESULT A8C_CHECK_LOCK A8C_FAILURE_TICS_LOW16 A8C_READ_BEGIN_MS A8C_READ_END_MS
    WR_DISABLE_VALID WR_DISABLE_CAUSE WR_DISABLE_PTP_STATE
    SPLL_STATE_RAW SPLL_SEQ_STATE HELPER_STATE_RAW HELPER_LOCK MAIN_STATE_RAW MAIN_ENABLED
    MAIN_FREQ_LOCK MAIN_PHASE_LOCK MAIN_LOCK PSTAT_RAW PSTAT_LOCK
    PTP_STATE_RAW PTP_STATE PTP_META_RAW PTP_META_STATE PDSTATE EXTSTATE PROTOCOL_EXTENSION
    SSTAT_RAW SERVO_STATE CKO_RAW CKO_PS SETP_RAW SETP_PS UCNT_RAW UCNT
    PUB_STATUS UCNT_DELTA INITIAL_S_LOCK_SEEN TIMEOUT_FAILURE_SEEN RECOVERY_PRESENT_SEEN RECOVERY_S_LOCK_SEEN
    SUCCESS_EVENT_SEEN RECOVERY_ADMISSION_SUPPORTED STABLE_WINDOW_STARTED STABLE_WINDOW_ROWS
    STABLE_WINDOW_START_MS STABLE_WINDOW_LAST_MS STABLE_WINDOW_ELAPSED_MS INVALID_STREAK
    POLICY_STOP_REASON STOP_CANDIDATE
  }
  set fields {}
  foreach key $keys {
    if {[dict exists $row $key]} {
      set value [dict get $row $key]
    } else {
      set value NA
    }
    set value [string map [list " " "_" "\t" "_" "\r" "_" "\n" "_"] $value]
    lappend fields [format "%s=%s" $key $value]
  }
  puts "S6R_SAMPLE [join $fields { }]"
  flush stdout
}

proc s6r_stop {reason elapsed_ms samples raw_valid_count} {
  set ::stop_reason $reason
  puts [format "S6R_STOP board=DE5_1-11.2 elapsed_ms=%d samples=%d raw_valid=%d invalid_streak=%d recovery_admission=%d stable_window_started=%d stable_rows=%d reason=%s" \
    $elapsed_ms $samples $raw_valid_count [dict get $::policy_state INVALID_STREAK] \
    [dict get $::policy_state RECOVERY_ADMISSION] \
    [dict get $::policy_state STABLE_WINDOW_STARTED] \
    [dict get $::policy_state STABLE_WINDOW_ROWS] $reason]
  flush stdout
}

puts [format "S6R_CONFIG trial=%s target=DE5_1-11.2 source_baseline=00d1a6a5154238700bbcd674e2638a0e6f15932e admission_limit_ms=%d stable_window_ms=%d total_limit_ms=%d minimum_sample_delay_ms=%d read_only=1 compile=0 program=0 reset=0 power_cycle=0" \
  $::trial_id $::pretrigger_timeout_ms $::stable_window_ms $::total_timeout_ms $::sample_delay_ms]
puts "S6R_SOURCE_CONTRACT wdiags_data_valid=0x00100A04.bit0 mapping_epoch=0x00100B34 mapping_inverse=0x00100B38 guarded_wdiags=1 global_time_probe_order=63,62,63 global_time_sequence_stable_required=1 cross_group_atomic=0 ucnt_unique_publication_required=1"
puts "S6R_EVENT_CONTRACT slock_next_locked=WR_STATE_2_NEXT_4 wrs_locked_state=4 tx_success=ID_0x1002_COUNT_GT_0 failure_A6C_and_lock_result_A8C_are_separate_timestamped_reads=1"
puts [format "S6R_CLOCK source=%s capture_start_monotonic_ms=%d" $::clock_source $::capture_start_ms]
flush stdout

set ::targets {}
foreach hardware_name [get_hardware_names] {
  if {[string first "1-11.2" $hardware_name] < 0} { continue }
  foreach device_name [get_device_names -hardware_name $hardware_name] {
    lappend ::targets [list $hardware_name $device_name]
  }
}
if {[llength $::targets] != 1} {
  set ::policy_state [::s6r::new_state]
  s6r_stop NO_OR_AMBIGUOUS_SLAVE_TARGET 0 0 0
  puts [format "S6R_SUMMARY trial=%s samples=0 raw_valid=0 stop_reason=%s target_count=%d" \
    $::trial_id $::stop_reason [llength $::targets]]
  puts "S6R_DONE"
  flush stdout
  exit 2
}

lassign [lindex $::targets 0] ::hardware_name ::device_name
puts [format "S6R_BOARD board=DE5_1-11.2 hardware=%s device=%s" $::hardware_name $::device_name]
flush stdout

set ::policy_state [::s6r::new_state]
set ::stop_reason NONE
set ::sample_count 0
set ::raw_valid_count 0
set ::reset_signature_initialized 0
array set ::reset_baseline {}
catch {end_insystem_source_probe}

if {[catch {
  start_insystem_source_probe -hardware_name $::hardware_name -device_name $::device_name
  wb_sync_toggle

  while {$::stop_reason eq "NONE"} {
    set elapsed_before [expr {[s6e_now_ms] - $::capture_start_ms}]
    if {[catch {set row [s6e_read_row $::sample_count $elapsed_before]} row_error]} {
      set elapsed_now [expr {[s6e_now_ms] - $::capture_start_ms}]
      puts [format "S6R_FATAL board=DE5_1-11.2 sample=%d elapsed_ms=%d error=%s" \
        $::sample_count $elapsed_now [string map [list " " "_" "\t" "_"] $row_error]]
      s6r_stop FATAL_JTAG_OR_TCL_ERROR $elapsed_now $::sample_count $::raw_valid_count
      break
    }

    # Reset signature only becomes a baseline when every component is valid.
    set reset_valid [dict get $row RESET_SIGNATURE_VALID]
    set reset_changed 0
    if {$reset_valid == 1} {
      set signature [list [dict get $row BOOT_GENERATION] [dict get $row CPU_RESET_COUNT] \
        [dict get $row WR_CORE_RESET_COUNT] [dict get $row SI_CONFIG_DROP_COUNT]]
      if {!$::reset_signature_initialized} {
        foreach {name value} [list boot [lindex $signature 0] cpu [lindex $signature 1] \
            wr [lindex $signature 2] si [lindex $signature 3]] {
          set ::reset_baseline($name) $value
        }
        set ::reset_signature_initialized 1
      } elseif {[lindex $signature 0] ne $::reset_baseline(boot) || \
          [lindex $signature 1] ne $::reset_baseline(cpu) || \
          [lindex $signature 2] ne $::reset_baseline(wr) || \
          [lindex $signature 3] ne $::reset_baseline(si)} {
        set reset_changed 1
      }
    }
    dict set row RESET_SIGNATURE_VALID $reset_valid
    dict set row RESET_CHANGED $reset_changed

    set policy_input [dict create \
      ROW_END_MS [dict get $row ELAPSED_MS] \
      RESET_CHANGED $reset_changed RESET_SIGNATURE_VALID $reset_valid \
      DISABLE_VALID [dict get $row WR_DISABLE_VALID] \
      ROW_RAW_VALID [dict get $row ROW_RAW_VALID] STEP1_GATE [dict get $row STEP1_GATE] \
      FAILURE_COUNT_U8 [dict get $row WR_FAILURE_COUNT_U8] \
      FAILURE_REASON_VALID [dict get $row WR_FAILURE_REASON_VALID] \
      FAILURE_REASON [dict get $row WR_FAILURE_REASON] WR_STATE [dict get $row WR_STATE] \
      ROW_EVENT_KIND [dict get $row ROW_EVENT_KIND] \
      EVENT_EVIDENCE_VALID [dict get $row EVENT_EVIDENCE_VALID] \
      EVENT_ELAPSED_MS [dict get $row EVENT_ELAPSED_MS] \
      DIAG_FRAME_VALID [dict get $row DIAG_FRAME_VALID] \
      GLOBAL_FRAME_VALID [dict get $row GLOBAL_FRAME_VALID] \
      GLOBAL_TIME_OK [dict get $row GLOBAL_TIME_OK] UCNT [dict get $row UCNT] \
      CKO_PS [dict get $row CKO_PS] SSTAT_RAW [dict get $row SSTAT_RAW] \
      SETP_PS [dict get $row SETP_PS] SERVO_STATE [dict get $row SERVO_STATE] \
      HELPER_LOCK [dict get $row HELPER_LOCK] MAIN_ENABLED [dict get $row MAIN_ENABLED] \
      MAIN_FREQ_LOCK [dict get $row MAIN_FREQ_LOCK] MAIN_PHASE_LOCK [dict get $row MAIN_PHASE_LOCK] \
      MAIN_LOCK [dict get $row MAIN_LOCK] PSTAT_LOCK [dict get $row PSTAT_LOCK]]
    set decision [::s6r::step $::policy_state $policy_input]
    set ::policy_state [dict get $decision STATE]
    set policy_row [dict get $decision ROW]
    set policy_stop [dict get $decision STOP_REASON]
    foreach key {FAILURE_DELTA_U8 NEW_FAILURE_RECORD PUB_STATUS UCNT_DELTA \
        STABLE_WINDOW_ELAPSED_MS STOP_CANDIDATE} {
      if {[dict exists $policy_row $key]} { dict set row $key [dict get $policy_row $key] }
    }
    dict set row POLICY_ELAPSED_MS [dict get $row ELAPSED_MS]
    dict set row POLICY_STOP_REASON $policy_stop
    dict set row INITIAL_S_LOCK_SEEN [dict get $::policy_state INITIAL_S_LOCK_SEEN]
    dict set row TIMEOUT_FAILURE_SEEN [dict get $::policy_state TIMEOUT_FAILURE_SEEN]
    dict set row RECOVERY_PRESENT_SEEN [dict get $::policy_state RECOVERY_PRESENT_SEEN]
    dict set row RECOVERY_S_LOCK_SEEN [dict get $::policy_state RECOVERY_S_LOCK_SEEN]
    dict set row SUCCESS_EVENT_SEEN [dict get $::policy_state SUCCESS_EVENT_SEEN]
    dict set row RECOVERY_ADMISSION_SUPPORTED [dict get $::policy_state RECOVERY_ADMISSION]
    dict set row STABLE_WINDOW_STARTED [dict get $::policy_state STABLE_WINDOW_STARTED]
    dict set row STABLE_WINDOW_ROWS [dict get $::policy_state STABLE_WINDOW_ROWS]
    dict set row STABLE_WINDOW_START_MS [dict get $::policy_state STABLE_WINDOW_START_MS]
    dict set row STABLE_WINDOW_LAST_MS [dict get $::policy_state STABLE_WINDOW_LAST_MS]
    dict set row INVALID_STREAK [dict get $::policy_state INVALID_STREAK]
    if {![dict exists $row FAILURE_DELTA_U8]} { dict set row FAILURE_DELTA_U8 0 }
    if {![dict exists $row NEW_FAILURE_RECORD]} { dict set row NEW_FAILURE_RECORD 0 }
    if {![dict exists $row PUB_STATUS]} { dict set row PUB_STATUS INVALID }
    if {![dict exists $row UCNT_DELTA]} { dict set row UCNT_DELTA -1 }
    if {![dict exists $row STOP_CANDIDATE]} { dict set row STOP_CANDIDATE $policy_stop }

    incr ::sample_count
    if {[dict get $row ROW_RAW_VALID] == 1} { incr ::raw_valid_count }
    s6r_emit_sample $row

    if {$policy_stop ne "NONE"} {
      s6r_stop $policy_stop [dict get $row ELAPSED_MS] $::sample_count $::raw_valid_count
    } else {
      after $::sample_delay_ms
    }
  }
} fatal_error]} {
  if {$::stop_reason eq "NONE"} {
    set elapsed_now [expr {[s6e_now_ms] - $::capture_start_ms}]
    puts [format "S6R_FATAL board=DE5_1-11.2 elapsed_ms=%d error=%s" \
      $elapsed_now [string map [list " " "_" "\t" "_"] $fatal_error]]
    s6r_stop FATAL_JTAG_OR_TCL_ERROR $elapsed_now $::sample_count $::raw_valid_count
  }
}

catch {end_insystem_source_probe}
if {$::stop_reason eq "NONE"} {
  s6r_stop OBSERVER_EXIT_WITHOUT_STOP_REASON \
    [expr {[s6e_now_ms] - $::capture_start_ms}] $::sample_count $::raw_valid_count
}
puts [format "S6R_SUMMARY trial=%s board=DE5_1-11.2 samples=%d raw_valid=%d recovery_admission_supported=%d success_event_seen=%d stable_window_started=%d stable_window_rows=%d stable_window_elapsed_ms=%d invalid_streak=%d stop_reason=%s wb_timeouts=%d wb_invalid=%d" \
  $::trial_id $::sample_count $::raw_valid_count \
  [dict get $::policy_state RECOVERY_ADMISSION] [dict get $::policy_state SUCCESS_EVENT_SEEN] \
  [dict get $::policy_state STABLE_WINDOW_STARTED] [dict get $::policy_state STABLE_WINDOW_ROWS] \
  [expr {[dict get $::policy_state STABLE_WINDOW_STARTED] ? \
    [dict get $::policy_state STABLE_WINDOW_LAST_MS] - [dict get $::policy_state STABLE_WINDOW_START_MS] : -1}] \
  [dict get $::policy_state INVALID_STREAK] $::stop_reason $::wb_timeout_count $::wb_invalid_count]
puts "S6R_DONE"
flush stdout
