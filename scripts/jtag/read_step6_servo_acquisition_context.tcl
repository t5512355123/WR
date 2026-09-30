# Dedicated read-only Step 6 acquisition trace for the Slave.
#
# Unlike the acceptance/interleaved observer, structural trust is independent
# of Global Time validity. Global-Time and lock signals are still recorded.
# The acquisition window is fixed at 600 seconds and uses guarded primary and
# context WDIAGS publications joined by UCNT. No target/control writes, reset,
# or FPGA programming are performed.
#
# Run only through the experiment's durable-log wrapper.

package require ::quartus::insystem_source_probe

set duration_ms 600000
set sample_ms 250
set board_filter "1-11.2"
set phase_context 2
set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]
set ::s6_acq_rows 0
set ::s6_acq_samples 0
set ::s6_acq_structurally_trusted 0
set ::s6_acq_qualifying 0
set ::s6_acq_invalid_streak 0
set ::s6_acq_reset_stop 0
set ::s6_acq_board_count 0
set ::s6_acq_phase_context $phase_context
array set ::s6_acq_reset_baseline {}

proc s6_a_us {} {
  if {[catch {clock clicks -milliseconds} value]} {
    error "relative elapsed-time clock unavailable"
  }
  return [expr {$value * 1000}]
}

proc s6_a_monotonic_us {} {
  return [s6_a_us]
}

proc s6_a_signed32 {raw} {
  set value [word32 $raw]
  if {$value < 0} { return -1 }
  if {$value >= 0x80000000} { return [expr {$value - 0x100000000}] }
  return $value
}

proc s6_a_unsigned64_words {high_raw low_raw} {
  if {![is_hex $high_raw] || ![is_hex $low_raw]} { return "NA" }
  set high [word32 $high_raw]
  set low [word32 $low_raw]
  if {$high < 0 || $low < 0} { return "NA" }
  return [expr {($high << 32) | $low}]
}

proc s6_a_read_phase_context_frame {} {
  set wait_start_ms [clock milliseconds]
  set wait_ms -1
  set baseline_raw [wb_read 0x00100B34]
  set baseline_word [word32 $baseline_raw]
  set baseline_epoch -1
  if {$baseline_word >= 0} {
    set baseline_epoch [expr {$baseline_word & 0xffff}]
  }
  set epoch_before -1
  set epoch_after -1
  set frame_start_us "NA"
  set frame_end_us "NA"
  set frame_valid 0
  set context_ucnt_raw "TIMEOUT"
  set dms_hi_raw "TIMEOUT"
  set dms_lo_raw "TIMEOUT"
  set setp_raw "TIMEOUT"
  set dms_ps "NA"
  set setp_ps "NA"
  set payload_valid 0
  set frame_found 0

  while {[clock milliseconds] - $wait_start_ms < 350} {
    set candidate_raw [wb_read 0x00100B34]
    set candidate_word [word32 $candidate_raw]
    if {$candidate_word >= 0} {
      set candidate_epoch [expr {$candidate_word & 0xffff}]
      if {$baseline_epoch < 0} {
        set baseline_epoch $candidate_epoch
        set baseline_raw $candidate_raw
      } elseif {$candidate_epoch != $baseline_epoch} {
        set ctrl_before_raw [wb_read 0x00100A04]
        set ctrl_before_word [word32 $ctrl_before_raw]
        set inverse_before_raw [wb_read 0x00100B38]
        set inverse_before_word [word32 $inverse_before_raw]
        if {$ctrl_before_word >= 0 && ($ctrl_before_word & 1) &&
            $inverse_before_word >= 0 &&
            (($candidate_epoch ^ ($inverse_before_word & 0xffff)) == 0xffff)} {
          set epoch_before $candidate_epoch
          set frame_start_us [s6_a_us]
          set wait_ms [expr {[clock milliseconds] - $wait_start_ms}]
          set context_ucnt_raw [wb_read 0x00100A48]
          set dms_hi_raw [wb_read 0x00100A34]
          set dms_lo_raw [wb_read 0x00100A38]
          set setp_raw [wb_read 0x00100A44]
          set dms_ps [s6_a_unsigned64_words $dms_hi_raw $dms_lo_raw]
          set setp_ps [s6_a_signed32 $setp_raw]
          set payload_valid [expr {
            [is_hex $context_ucnt_raw] && [is_hex $dms_hi_raw] &&
            [is_hex $dms_lo_raw] && [is_hex $setp_raw] && $dms_ps ne "NA" ? 1 : 0}]
          set epoch_after_raw [wb_read 0x00100B34]
          set ctrl_after_raw [wb_read 0x00100A04]
          set frame_end_us [s6_a_us]
          set epoch_after_word [word32 $epoch_after_raw]
          set ctrl_after_word [word32 $ctrl_after_raw]
          if {$epoch_after_word >= 0} {
            set epoch_after [expr {$epoch_after_word & 0xffff}]
          }
          set valid_after [expr {$ctrl_after_word >= 0 ? ($ctrl_after_word & 1) : 0}]
          set frame_valid [expr {
            $payload_valid && ($ctrl_before_word & 1) && $valid_after &&
            $epoch_before >= 0 && $epoch_before == $epoch_after ? 1 : 0}]
          set frame_found 1
          break
        }
      }
    }
    after 1
  }
  if {!$frame_found} {
    set wait_ms [expr {[clock milliseconds] - $wait_start_ms}]
  }
  return [list $context_ucnt_raw $dms_hi_raw $dms_lo_raw $setp_raw \
    $dms_ps $setp_ps $payload_valid $frame_valid $epoch_before $epoch_after \
    $frame_start_us $frame_end_us $wait_ms]
}

proc s6_a_snapshot {snapshot0 snapshot1_before snapshot1_after status escr} {
  set tai -1
  set cycles -1
  set snapshot_valid -1
  set snapshot_count -1
  set time_valid -1
  set pps_valid -1
  set stable 0
  if {[is_hex $snapshot0] && [is_hex $snapshot1_before] &&
      [is_hex $snapshot1_after]} {
    set high0 [probe_high32 $snapshot0]
    set low0 [word32 $snapshot0]
    set low1 [word32 $snapshot1_after]
    set low1_before [word32 $snapshot1_before]
    if {$high0 >= 0 && $low0 >= 0 && $low1 >= 0 && $low1_before >= 0} {
      set stable [expr {
        [normalize_probe64 $snapshot1_before] eq \
        [normalize_probe64 $snapshot1_after] ? 1 : 0}]
      set tai [expr {(($high0 & 0xff) << 32) | $low0}]
      set cycles [expr {(($high0 & 0x00ffffff) | (($low1 & 0xf) << 24))}]
      set time_valid [expr {($low1 >> 4) & 1}]
      set pps_valid [expr {($low1 >> 5) & 1}]
      set snapshot_valid [expr {($low1 >> 6) & 1}]
      set snapshot_count [expr {($low1 >> 7) & 0xffff}]
    }
  }
  set status_time_valid [bit64_low $status 4]
  set status_pps_valid [bit64_low $status 5]
  set escr_word [word32 $escr]
  set escr_time_valid -1
  set escr_pps_valid -1
  if {$escr_word >= 0} {
    set escr_time_valid [expr {($escr_word >> 3) & 1}]
    set escr_pps_valid [expr {($escr_word >> 2) & 1}]
  }
  set global_valid [expr {
    $stable && $snapshot_valid == 1 && $time_valid == 1 && $pps_valid == 1 &&
    $status_time_valid == 1 && $status_pps_valid == 1 &&
    $escr_time_valid == 1 && $escr_pps_valid == 1 ? 1 : 0}]
  return [list $tai $cycles $stable $snapshot_valid $snapshot_count \
    $time_valid $pps_valid $status_time_valid $status_pps_valid \
    $escr_time_valid $escr_pps_valid $global_valid]
}

proc s6_a_capture {hardware_name sample elapsed_ms} {
  incr ::s6_acq_rows
  set row_start_us [s6_a_us]
  set phase_context $::s6_acq_phase_context

  # Global-Time frame is a separate group. Probe 63 is read on both sides of
  # probe 62, matching the dashboard's sequence-stability rule. These fields
  # are not asserted to be atomic with the servo mailbox group below.
  set health_start_us [s6_a_us]
  set status [safe_probe_read 0]
  set live [safe_probe_read 64]
  set time_seq_before [safe_probe_read 63]
  set time_snapshot [safe_probe_read 62]
  set time_seq_after [safe_probe_read 63]
  set time_escr [wb_read 0x0010031C]
  set health_end_us [s6_a_us]

  # The lock registers are source-mapped, read-only state summaries.
  set helper_word_raw [wb_read 0x00100ABC]
  set main_word_raw [wb_read 0x00100AC4]
  set pstat_raw [wb_read 0x00100A0C]
  set helper_word [word32 $helper_word_raw]
  set main_word [word32 $main_word_raw]
  set pstat_word [word32 $pstat_raw]
  set helper_lock [expr {$helper_word < 0 ? -1 : ($helper_word & 1)}]
  set main_lock [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  set pstat_lock [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]

  # Snapshot this row's starting WDIAGS epoch, wait for the next publication,
  # then read the minimal CKO/SSTAT/UCNT payload immediately. Comparing only
  # with the previous row is insufficient because rows are >100 ms apart.
  set critical_start_us [s6_a_us]
  set diag_wait_start_ms [clock milliseconds]
  set diag_wait_ms -1
  set diag_valid_before -1
  set diag_valid_after -1
  set diag_epoch_before -1
  set diag_epoch_after -1
  set diag_epoch_stable 0
  set diag_epoch_before_ok 0
  set diag_epoch_after_ok 0
  set diag_frame_valid 0
  set diag_ctrl_before_raw "TIMEOUT"
  set diag_ctrl_after_raw "TIMEOUT"
  set diag_epoch_before_raw "TIMEOUT"
  set diag_epoch_after_raw "TIMEOUT"
  set diag_inverse_before_raw "TIMEOUT"
  set diag_epoch_wait_baseline -1
  set diag_epoch_wait_baseline_raw [wb_read 0x00100B34]
  set diag_epoch_wait_baseline_word [word32 $diag_epoch_wait_baseline_raw]
  if {$diag_epoch_wait_baseline_word >= 0} {
    set diag_epoch_wait_baseline [expr {$diag_epoch_wait_baseline_word & 0xffff}]
  }
  set cko_raw "TIMEOUT"
  set sstat_raw "TIMEOUT"
  set ucnt_raw "TIMEOUT"
  set dms_hi_raw "SKIPPED"
  set dms_lo_raw "SKIPPED"
  set setp_raw "SKIPPED"
  set dms_ps "NA"
  set setp_ps "NA"
  set phase_context_start_us "NA"
  set phase_context_end_us "NA"
  set phase_context_valid [expr {$phase_context == 0 ? 1 : 0}]
  set context_ucnt_raw "SKIPPED"
  set context_frame_valid 0
  set context_update_match 0
  set context_epoch_before -1
  set context_epoch_after -1
  set context_frame_start_us "NA"
  set context_frame_end_us "NA"
  set context_wait_ms -1
  set cko_host_us "NA"
  set frame_start_us "NA"
  set critical_end_us "NA"
  set frame_found 0
  while {[clock milliseconds] - $diag_wait_start_ms < 350} {
    set candidate_raw [wb_read 0x00100B34]
    set candidate_word [word32 $candidate_raw]
    if {$candidate_word >= 0} {
      set candidate_epoch [expr {$candidate_word & 0xffff}]
      if {$diag_epoch_wait_baseline < 0} {
        set diag_epoch_wait_baseline $candidate_epoch
        set diag_epoch_wait_baseline_raw $candidate_raw
      } elseif {$candidate_epoch != $diag_epoch_wait_baseline} {
        set ctrl_candidate_raw [wb_read 0x00100A04]
        set ctrl_candidate_word [word32 $ctrl_candidate_raw]
        if {$ctrl_candidate_word >= 0 && ($ctrl_candidate_word & 1)} {
          set inverse_candidate_raw [wb_read 0x00100B38]
          set inverse_candidate_word [word32 $inverse_candidate_raw]
          if {$inverse_candidate_word >= 0 &&
              (($candidate_epoch ^ ($inverse_candidate_word & 0xffff)) == 0xffff)} {
            set diag_ctrl_before_raw $ctrl_candidate_raw
            set diag_epoch_before_raw $candidate_raw
            set diag_inverse_before_raw $inverse_candidate_raw
            set diag_valid_before 1
            set diag_epoch_before $candidate_epoch
            set diag_epoch_before_ok 1
            set frame_start_us [s6_a_us]
            set diag_wait_ms [expr {([clock milliseconds] - $diag_wait_start_ms)}]
            set cko_raw [wb_read 0x00100A40]
            set cko_host_us [s6_a_us]
            set sstat_raw [wb_read 0x00100A08]
            set ucnt_raw [wb_read 0x00100A48]
            if {$phase_context == 1} {
              set phase_context_start_us [s6_a_us]
              set dms_hi_raw [wb_read 0x00100A34]
              set dms_lo_raw [wb_read 0x00100A38]
              set setp_raw [wb_read 0x00100A44]
              set phase_context_end_us [s6_a_us]
              set dms_ps [s6_a_unsigned64_words $dms_hi_raw $dms_lo_raw]
              set setp_ps [s6_a_signed32 $setp_raw]
              set phase_context_valid [expr {
                [is_hex $dms_hi_raw] && [is_hex $dms_lo_raw] &&
                [is_hex $setp_raw] && $dms_ps ne "NA" ? 1 : 0}]
            }
            set diag_epoch_after_raw [wb_read 0x00100B34]
            set diag_ctrl_after_raw [wb_read 0x00100A04]
            set critical_end_us [s6_a_us]
            set diag_epoch_after_word [word32 $diag_epoch_after_raw]
            set diag_ctrl_after_word [word32 $diag_ctrl_after_raw]
            if {$diag_epoch_after_word >= 0} {
              set diag_epoch_after [expr {$diag_epoch_after_word & 0xffff}]
              set diag_epoch_after_ok 1
            }
            if {$diag_ctrl_after_word >= 0} {
              set diag_valid_after [expr {$diag_ctrl_after_word & 1}]
            }
            set diag_epoch_stable [expr {
              $diag_epoch_before >= 0 &&
              $diag_epoch_before == $diag_epoch_after ? 1 : 0}]
            set diag_frame_valid [expr {
              $diag_valid_before == 1 && $diag_valid_after == 1 &&
              $diag_epoch_before_ok && $diag_epoch_after_ok &&
              $diag_epoch_stable ? 1 : 0}]
            set frame_found 1
            break
          }
        }
      }
    }
    after 1
  }
  if {!$frame_found} {
    set diag_wait_ms [expr {[clock milliseconds] - $diag_wait_start_ms}]
    set critical_end_us [s6_a_us]
  }

  if {$phase_context == 1} {
    set context_ucnt_raw $ucnt_raw
    set context_frame_valid $diag_frame_valid
    set context_update_match $phase_context_valid
    set context_epoch_before $diag_epoch_before
    set context_epoch_after $diag_epoch_after
    set context_frame_start_us $frame_start_us
    set context_frame_end_us $critical_end_us
    set context_wait_ms $diag_wait_ms
  } elseif {$phase_context == 2 && $frame_found && $diag_frame_valid} {
    lassign [s6_a_read_phase_context_frame] context_ucnt_raw dms_hi_raw \
      dms_lo_raw setp_raw dms_ps setp_ps phase_context_valid \
      context_frame_valid context_epoch_before context_epoch_after \
      context_frame_start_us context_frame_end_us context_wait_ms
    set phase_context_start_us $context_frame_start_us
    set phase_context_end_us $context_frame_end_us
    set core_ucnt_word [word32 $ucnt_raw]
    set context_ucnt_word [word32 $context_ucnt_raw]
    set context_update_match [expr {
      $core_ucnt_word >= 0 && $core_ucnt_word == $context_ucnt_word ? 1 : 0}]
  } elseif {$phase_context == 2} {
    set phase_context_valid 0
  }

  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set row_end_us [s6_a_us]

  set ucnt [word32 $ucnt_raw]
  set sstat [word32 $sstat_raw]
  set dc0 [word32 $diag_ctrl_before_raw]
  set dc1 [word32 $diag_ctrl_after_raw]
  set de0_raw [word32 $diag_epoch_before_raw]
  set di0_raw [word32 $diag_inverse_before_raw]
  set de1_raw [word32 $diag_epoch_after_raw]
  set cko [s6_a_signed32 $cko_raw]
  set servo_state [expr {$sstat < 0 ? -1 : (($sstat >> 8) & 0xf)}]
  # Match Step 1's exact read-only status-probe prerequisites from
  # read_wb_runtime.tcl; a valid Global-Time snapshot alone does not replace
  # the dashboard's PHY/link gate.
  set status_si_config_done [bit64_low $status 0]
  set status_wr_ready [bit64_low $status 1]
  set status_tm_link [bit64_low $status 2]
  set status_link_ok [bit64_low $status 3]
  set status_rx_ready [bit64_low $status 6]
  set status_tx_ready [bit64_low $status 7]
  set status_cpu_reset_n [bit64_low $status 15]
  set status_rx_locked_to_data [bit64_high $status 0]
  set step1_values [list $status_si_config_done $status_wr_ready \
    $status_tm_link $status_link_ok $status_rx_ready $status_tx_ready \
    $status_cpu_reset_n $status_rx_locked_to_data]
  if {[lsearch -exact $step1_values -1] >= 0} {
    set step1_gate -1
  } else {
    set step1_gate [expr {
      $status_si_config_done == 1 && $status_wr_ready == 1 &&
      $status_tm_link == 1 && $status_link_ok == 1 &&
      $status_rx_ready == 1 && $status_tx_ready == 1 &&
      $status_cpu_reset_n == 1 && $status_rx_locked_to_data == 1 ? 1 : 0}]
  }
  set reads_valid [expr {
    [is_hex $status] && [is_hex $live] && [is_hex $time_seq_before] &&
    [is_hex $time_snapshot] && [is_hex $time_seq_after] &&
    [is_hex $time_escr] && [is_hex $cko_raw] &&
    $dc0 >= 0 && $dc1 >= 0 && $de0_raw >= 0 && $di0_raw >= 0 &&
    $de1_raw >= 0 &&
    $helper_word >= 0 && $main_word >= 0 &&
    $pstat_word >= 0 && $ucnt >= 0 && $sstat >= 0 &&
    $cko >= -2147483648 && $phase_context_valid ? 1 : 0}]
  lassign [s6_a_snapshot $time_snapshot $time_seq_before $time_seq_after \
    $status $time_escr] tai cycles snapshot_stable snapshot_valid snapshot_count \
    snapshot_time_valid snapshot_pps_valid status_time_valid status_pps_valid \
    escr_time_valid escr_pps_valid global_valid
  set context_frame_match [expr {
    $phase_context == 0 ||
    ($context_frame_valid && $context_update_match) ? 1 : 0}]
  set diagnostic_frame_match [expr {
    $diag_frame_valid && $context_frame_match ? 1 : 0}]
  set structurally_trusted [expr {$reads_valid && $diagnostic_frame_match ? 1 : 0}]
  set qualifies [expr {
    $structurally_trusted && $global_valid &&
    $step1_gate == 1 &&
    $helper_lock == 1 && $main_lock == 1 &&
    $main_freq == 1 && $main_phase == 1 && $pstat_lock == 1 &&
    abs($cko) < 60 ? 1 : 0}]
  set row_ms [expr {($row_end_us - $row_start_us) / 1000.0}]

  set boot [probe_high_counter_hex $entry]
  set cpu [probe_byte_counter_hex $reset 16]
  set wr [probe_byte_counter_hex $reset 24]
  set si [probe_byte_counter_hex $reset 40]
  set reset_changed 0
  foreach {key value} [list boot $boot cpu $cpu wr $wr si $si] {
    if {$value ne "INVALID" && $value ne "TIMEOUT"} {
      if {[info exists ::s6_acq_reset_baseline($hardware_name,$key)] &&
          $::s6_acq_reset_baseline($hardware_name,$key) ne $value} {
        set reset_changed 1
      }
      if {![info exists ::s6_acq_reset_baseline($hardware_name,$key)]} {
        set ::s6_acq_reset_baseline($hardware_name,$key) $value
      }
    }
  }
  set reset_signature_valid [expr {
    $boot ne "INVALID" && $boot ne "TIMEOUT" &&
    $cpu ne "INVALID" && $cpu ne "TIMEOUT" &&
    $wr ne "INVALID" && $wr ne "TIMEOUT" &&
    $si ne "INVALID" && $si ne "TIMEOUT" ? 1 : 0}]
  if {!$reset_signature_valid} {
    set reads_valid 0
    set structurally_trusted 0
    set qualifies 0
  }
  if {$reset_changed} { set ::s6_acq_reset_stop 1 }

  if {$structurally_trusted} {
    incr ::s6_acq_structurally_trusted
    set ::s6_acq_invalid_streak 0
  } else {
    incr ::s6_acq_invalid_streak
  }
  if {$qualifies} { incr ::s6_acq_qualifying }

  puts [format "S6_ACQ_TIMING board=%s sample=%04d DIAG_WAIT_START_US=%s DIAG_EPOCH_WAIT_BASELINE=%d FRAME_START_US=%s CKO_HOST_US=%s PHASE_CONTEXT_START_US=%s PHASE_CONTEXT_END_US=%s FRAME_END_US=%s DIAG_WAIT_MS=%d" \
    $hardware_name $sample $critical_start_us $diag_epoch_wait_baseline \
    $frame_start_us $cko_host_us $phase_context_start_us \
    $phase_context_end_us $critical_end_us $diag_wait_ms]
  puts [format "S6_ACQ_CONTEXT_TIMING board=%s sample=%04d PHASE_CONTEXT_FRAME_START_US=%s PHASE_CONTEXT_FRAME_END_US=%s PHASE_CONTEXT_WAIT_MS=%d PHASE_CONTEXT_FRAME_VALID=%d PHASE_CONTEXT_EPOCH_BEFORE=%d PHASE_CONTEXT_EPOCH_AFTER=%d PHASE_CONTEXT_UCNT=%s" \
    $hardware_name $sample $context_frame_start_us $context_frame_end_us \
    $context_wait_ms $context_frame_valid $context_epoch_before \
    $context_epoch_after $context_ucnt_raw]
  puts [format "S6_ACQ_SAMPLE board=%s sample=%04d elapsed_ms=%d row_ms=%.3f HEALTH_START_US=%s HEALTH_END_US=%s DIAG_WAIT_START_US=%s DIAG_WAIT_MS=%d DIAG_EPOCH_WAIT_BASELINE=%d FRAME_START_US=%s CKO_HOST_US=%s PHASE_CONTEXT_START_US=%s PHASE_CONTEXT_END_US=%s FRAME_END_US=%s ROW_END_US=%s READS_VALID=%d STRUCTURALLY_TRUSTED_ROW=%d STEP6_QUALIFYING_ROW=%d TAI=%s CYCLES=%s GLOBAL_TIME_VALID=%d SNAPSHOT_STABLE=%d SNAPSHOT_VALID=%d SNAPSHOT_COUNT=%d STATUS_TIME_VALID=%d STATUS_PPS_VALID=%d ESCR_TIME_VALID=%d ESCR_PPS_VALID=%d STEP1_GATE=%d STATUS_SI_CONFIG_DONE=%d STATUS_WR_READY=%d STATUS_TM_LINK=%d STATUS_LINK_OK=%d STATUS_RX_READY=%d STATUS_TX_READY=%d STATUS_CPU_RESET_N=%d STATUS_RX_LOCKED_TO_DATA=%d HELPER_LOCK=%d MAIN_LOCK=%d MAIN_FREQ_LOCK=%d MAIN_PHASE_LOCK=%d PSTAT_LOCK=%d DIAG_VALID_BEFORE=%d DIAG_VALID_AFTER=%d DIAG_EPOCH_BEFORE=%d DIAG_EPOCH_AFTER=%d DIAG_EPOCH_STABLE=%d DIAG_EPOCH_BEFORE_OK=%d DIAG_FRAME_VALID=%d UCNT=%s SSTAT=%s SERVO_STATE=%d CKO_RAW=%s CKO_PS=%d BOOT_GENERATION=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s RESET_CHANGED=%d PHASE_CONTEXT=%d PHASE_CONTEXT_VALID=%d DMS_HI=%s DMS_LO=%s DMS_PS=%s SETP_RAW=%s SETP_PS=%s PHASE_CONTEXT_FRAME_VALID=%d PHASE_CONTEXT_MATCH=%d PHASE_CONTEXT_UCNT=%s PHASE_CONTEXT_EPOCH_BEFORE=%d PHASE_CONTEXT_EPOCH_AFTER=%d PHASE_CONTEXT_FRAME_START_US=%s PHASE_CONTEXT_FRAME_END_US=%s PHASE_CONTEXT_WAIT_MS=%d" \
    $hardware_name $sample $elapsed_ms $row_ms $health_start_us $health_end_us \
    $critical_start_us $diag_wait_ms $diag_epoch_wait_baseline $frame_start_us \
    $cko_host_us $phase_context_start_us $phase_context_end_us \
    $critical_end_us $row_end_us $reads_valid \
    $structurally_trusted $qualifies $tai $cycles $global_valid $snapshot_stable \
    $snapshot_valid $snapshot_count $status_time_valid $status_pps_valid \
    $escr_time_valid $escr_pps_valid $step1_gate $status_si_config_done \
    $status_wr_ready $status_tm_link $status_link_ok $status_rx_ready \
    $status_tx_ready $status_cpu_reset_n $status_rx_locked_to_data \
    $helper_lock $main_lock $main_freq \
    $main_phase $pstat_lock $diag_valid_before $diag_valid_after \
    $diag_epoch_before $diag_epoch_after $diag_epoch_stable \
    $diag_epoch_before_ok $diag_frame_valid $ucnt_raw $sstat_raw \
    $servo_state $cko_raw $cko $boot $cpu $wr $si $reset_changed \
    $phase_context $phase_context_valid $dms_hi_raw $dms_lo_raw $dms_ps \
    $setp_raw $setp_ps $context_frame_valid $context_update_match \
    $context_ucnt_raw $context_epoch_before $context_epoch_after \
    $context_frame_start_us $context_frame_end_us $context_wait_ms]
  flush stdout
  return [list $reset_changed $structurally_trusted $servo_state $step1_gate $helper_lock $main_freq $main_phase $main_lock $pstat_lock $global_valid $row_start_us $row_end_us]
}

set ::s6_acq_stop_reason "NO_MATCHING_BOARD"
set ::s6_acq_requested_duration_ms 600000
puts "S6_ACQ_CONFIG board_filter=$board_filter sample_ms=$sample_ms phase_context=2 context_join=MATCHED_UCNT_SEPARATE_FRAMES requested_duration_ms=600000 structural_valid_ignores_global_time=1 read_only=1 wb_register_writes=0 fpga_program=0 reset=0"
puts "S6_ACQ_CONTEXT_FIELDS primary=CKO,SSTAT,UCNT,epoch_before,epoch_after,frame_valid context=UCNT,SETP,DMS_HI,DMS_LO,epoch_before,epoch_after,frame_valid"
flush stdout

foreach hardware_name [get_hardware_names] {
  if {[string first $board_filter $hardware_name] < 0} { continue }
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { continue }
  set device_name [lindex $devices 0]
  incr ::s6_acq_board_count
  puts [format "S6_ACQ_BOARD board=%s device=%s" $hardware_name $device_name]
  flush stdout
  catch {end_insystem_source_probe}

  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
  } setup_error]} {
    set ::s6_acq_stop_reason "OBSERVER_SETUP_ERROR"
    puts [format "S6_ACQ_ERROR board=%s message=%s" $hardware_name $setup_error]
    puts [format "S6_ACQ_STOP board=%s REQUESTED_DURATION_MS=600000 LAST_ROW_START_MS=NA LAST_ROW_END_MS=NA ELAPSED_MS=0 STOP_REASON=%s" $hardware_name $::s6_acq_stop_reason]
    flush stdout
    break
  }

  set acquisition_start_us [s6_a_monotonic_us]
  set last_row_start_ms "NA"
  set last_row_end_ms "NA"
  set sample 0
  set ::s6_acq_stop_reason "DURATION_LIMIT"
  puts [format "S6_ACQ_START board=%s ACQ_START_MONOTONIC_US=%s REQUESTED_DURATION_MS=600000" $hardware_name $acquisition_start_us]
  flush stdout

  while {1} {
    set now_us [s6_a_monotonic_us]
    set elapsed_before_ms [expr {($now_us - $acquisition_start_us) / 1000}]
    if {$elapsed_before_ms >= 600000} {
      set ::s6_acq_stop_reason "DURATION_LIMIT"
      break
    }

    set sample_index $sample
    if {[catch {
      s6_a_capture $hardware_name $sample_index $elapsed_before_ms
    } capture_result]} {
      set ::s6_acq_stop_reason "OBSERVER_READ_ERROR"
      puts [format "S6_ACQ_ERROR board=%s sample=%d message=%s" $hardware_name $sample_index $capture_result]
      flush stdout
      break
    }
    lassign $capture_result reset_changed structural_trusted servo_state step1_gate helper_lock main_freq main_phase main_lock pstat_lock global_valid row_start_us row_end_us
    incr sample
    incr ::s6_acq_samples

    set last_row_start_ms [expr {($row_start_us - $acquisition_start_us) / 1000}]
    set last_row_end_ms [expr {($row_end_us - $acquisition_start_us) / 1000}]

    if {$reset_changed} {
      set ::s6_acq_stop_reason "RESET_SIGNATURE_CHANGED"
      break
    }
    if {$step1_gate != 1} {
      set ::s6_acq_stop_reason "STEP1_GATE_LOST_OR_INVALID"
      break
    }
    if {$helper_lock != 1 || $main_freq != 1 || $main_phase != 1 ||
        $main_lock != 1 || $pstat_lock != 1} {
      set ::s6_acq_stop_reason "STEP5_LOCK_GATE_LOST_OR_INVALID"
      break
    }
    if {$structural_trusted && $servo_state == 4} {
      set ::s6_acq_stop_reason "TRACK_PHASE_REACHED"
      break
    }
    if {$::s6_acq_invalid_streak >= 5} {
      set ::s6_acq_stop_reason "FIVE_CONSECUTIVE_STRUCTURALLY_INVALID_ROWS"
      break
    }

    set completed_us [s6_a_monotonic_us]
    if {[expr {($completed_us - $acquisition_start_us) / 1000}] >= 600000} {
      set ::s6_acq_stop_reason "DURATION_LIMIT"
      break
    }
    after $sample_ms
  }

  set final_us [s6_a_monotonic_us]
  set elapsed_final_ms [expr {($final_us - $acquisition_start_us) / 1000}]
  puts [format "S6_ACQ_STOP board=%s REQUESTED_DURATION_MS=600000 LAST_ROW_START_MS=%s LAST_ROW_END_MS=%s ELAPSED_MS=%d STOP_REASON=%s"     $hardware_name $last_row_start_ms $last_row_end_ms $elapsed_final_ms $::s6_acq_stop_reason]
  puts [format "S6_ACQ_BOARD_DONE board=%s samples=%d structurally_trusted=%d step6_qualifying=%d invalid_streak=%d"     $hardware_name $::s6_acq_samples $::s6_acq_structurally_trusted     $::s6_acq_qualifying $::s6_acq_invalid_streak]
  flush stdout
  catch {end_insystem_source_probe}
  break
}

if {$::s6_acq_board_count == 0} {
  set ::s6_acq_stop_reason "NO_MATCHING_BOARD"
}
puts [format "S6_ACQ_SUMMARY boards=%d samples=%d structurally_trusted=%d step6_qualifying=%d stop_reason=%s timeout_count=%d invalid_count=%d"   $::s6_acq_board_count $::s6_acq_samples $::s6_acq_structurally_trusted   $::s6_acq_qualifying $::s6_acq_stop_reason $::wb_timeout_count $::wb_invalid_count]
puts "S6_ACQ_DONE"
flush stdout
