# Step 6 read-only startup/admission boundary trace for the pinned Slave SOF.
#
# This is diagnostic-only. It issues Wishbone reads through the established
# preload/toggle mailbox reader and never writes a functional register,
# requests a Helper PI snapshot, resets, or programs an FPGA.
#
# Fixed capture: 300 seconds, 250 ms post-row delay, one Slave board/session.
# Each non-atomic register group has its own host-time bracket. The phase
# primary/context pair alone uses the existing guarded publication contract
# and UCNT join; it is not claimed to be a single-cycle cross-group snapshot.

package require ::quartus::insystem_source_probe

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

set ::s6s_duration_ms 300000
set ::s6s_sample_delay_ms 250
set ::s6s_board_filter "1-11.2"
set ::s6s_structural_invalid_streak 0
set ::s6s_structurally_trusted 0
set ::s6s_samples 0
set ::s6s_ready_rows 0
set ::s6s_ready_since_us ""
set ::s6s_stop_reason NO_MATCHING_BOARD
array set ::s6s_group_invalid_streak {ADMISSION 0 SPLL 0 EVENTS 0}
array set ::s6s_reset_baseline {}

proc s6s_now_us {} {
  if {[catch {clock clicks -milliseconds} value]} {
    error "monotonic elapsed-time clock unavailable"
  }
  return [expr {$value * 1000}]
}

proc s6s_signed32 {raw} {
  set value [word32 $raw]
  if {$value < 0} { return NA }
  if {$value >= 0x80000000} { return [expr {$value - 0x100000000}] }
  return $value
}

proc s6s_word_valid {raw} {
  return [expr {[is_hex $raw] && ![stale_jtag_word $raw] ? 1 : 0}]
}

proc s6s_unsigned64_words {high_raw low_raw} {
  if {![is_hex $high_raw] || ![is_hex $low_raw]} { return NA }
  set high [word32 $high_raw]
  set low [word32 $low_raw]
  if {$high < 0 || $low < 0} { return NA }
  return [expr {($high << 32) | $low}]
}

proc s6s_read_group {fields} {
  set start_us [s6s_now_us]
  set values [dict create]
  set group_valid 1
  foreach field $fields {
    lassign $field name kind address
    switch -- $kind {
      PROBE {
        set raw [safe_probe_read $address]
        set field_valid [expr {[is_hex $raw] && ![stale_jtag_word $raw]}]
      }
      WB {
        set raw [wb_read $address]
        set field_valid [register_value_valid $address $raw]
      }
      WB_STABLE {
        set raw [wb_read_critical $address]
        set field_valid [register_value_valid $address $raw]
      }
      WB_COUNTER {
        set raw [wb_read_counter $address]
        set field_valid [counter_value_valid $raw]
      }
      default { error "unknown read kind $kind for $name" }
    }
    dict set values ${name}_RAW $raw
    if {!$field_valid} { set group_valid 0 }
  }
  set end_us [s6s_now_us]
  return [dict create START_US $start_us END_US $end_us VALID $group_valid VALUES $values]
}

proc s6s_emit_group {board sample name group} {
  set values [dict get $group VALUES]
  set fields ""
  dict for {key value} $values {
    append fields " $key=$value"
  }
  set start_us [dict get $group START_US]
  set end_us [dict get $group END_US]
  puts [format "S6S_GROUP board=%s sample=%04d group=%s start_us=%s end_us=%s elapsed_us=%d valid=%d%s" \
    $board $sample $name $start_us $end_us [expr {$end_us - $start_us}] \
    [dict get $group VALID] $fields]
}

proc s6s_phase_primary {} {
  set start_us [s6s_now_us]
  set wait_start_ms [clock milliseconds]
  set epoch_baseline_raw [wb_read 0x00100B34]
  set epoch_baseline_word [word32 $epoch_baseline_raw]
  set epoch_baseline -1
  if {$epoch_baseline_word >= 0 && [s6s_word_valid $epoch_baseline_raw]} {
    set epoch_baseline [expr {$epoch_baseline_word & 0xffff}]
  }
  set epoch_before -1
  set epoch_after -1
  set cko_raw TIMEOUT
  set sstat_raw TIMEOUT
  set ucnt_raw TIMEOUT
  set valid 0
  set wait_ms -1
  set frame_start_us NA
  set frame_end_us NA

  while {[clock milliseconds] - $wait_start_ms < 350} {
    set candidate_raw [wb_read 0x00100B34]
    set candidate_word [word32 $candidate_raw]
    if {$candidate_word >= 0 && [s6s_word_valid $candidate_raw]} {
      set candidate_epoch [expr {$candidate_word & 0xffff}]
      if {$epoch_baseline < 0} {
        set epoch_baseline $candidate_epoch
        set epoch_baseline_raw $candidate_raw
      } elseif {$candidate_epoch != $epoch_baseline} {
        set ctrl_before_raw [wb_read 0x00100A04]
        set ctrl_before [word32 $ctrl_before_raw]
        set inverse_raw [wb_read 0x00100B38]
        set inverse [word32 $inverse_raw]
        if {$ctrl_before >= 0 && [s6s_word_valid $ctrl_before_raw] &&
            ($ctrl_before & 1) && $inverse >= 0 &&
            [s6s_word_valid $inverse_raw] &&
            (($candidate_epoch ^ ($inverse & 0xffff)) == 0xffff)} {
          set epoch_before $candidate_epoch
          set frame_start_us [s6s_now_us]
          set wait_ms [expr {[clock milliseconds] - $wait_start_ms}]
          set cko_raw [wb_read 0x00100A40]
          set sstat_raw [wb_read 0x00100A08]
          set ucnt_raw [wb_read 0x00100A48]
          set epoch_after_raw [wb_read 0x00100B34]
          set ctrl_after_raw [wb_read 0x00100A04]
          set frame_end_us [s6s_now_us]
          set epoch_after_word [word32 $epoch_after_raw]
          set ctrl_after [word32 $ctrl_after_raw]
          if {$epoch_after_word >= 0} {
            set epoch_after [expr {$epoch_after_word & 0xffff}]
          }
          set valid [expr {
            [s6s_word_valid $cko_raw] && [s6s_word_valid $sstat_raw] &&
            [s6s_word_valid $ucnt_raw] &&
            $epoch_before >= 0 && $epoch_before == $epoch_after &&
            [s6s_word_valid $epoch_after_raw] && $ctrl_after >= 0 &&
            [s6s_word_valid $ctrl_after_raw] && ($ctrl_after & 1) ? 1 : 0}]
          break
        }
      }
    }
    after 1
  }
  if {$wait_ms < 0} { set wait_ms [expr {[clock milliseconds] - $wait_start_ms}] }
  if {$frame_end_us eq "NA"} { set frame_end_us [s6s_now_us] }
  set end_us [s6s_now_us]
  return [dict create START_US $start_us END_US $end_us WAIT_MS $wait_ms \
    EPOCH_BASELINE_RAW $epoch_baseline_raw EPOCH_BEFORE $epoch_before \
    EPOCH_AFTER $epoch_after CKO_RAW $cko_raw SSTAT_RAW $sstat_raw \
    UCNT_RAW $ucnt_raw VALID $valid FRAME_START_US $frame_start_us \
    FRAME_END_US $frame_end_us]
}

proc s6s_phase_context {} {
  set start_us [s6s_now_us]
  set wait_start_ms [clock milliseconds]
  set baseline_raw [wb_read 0x00100B34]
  set baseline_word [word32 $baseline_raw]
  set baseline_epoch -1
  if {$baseline_word >= 0 && [s6s_word_valid $baseline_raw]} {
    set baseline_epoch [expr {$baseline_word & 0xffff}]
  }
  set epoch_before -1
  set epoch_after -1
  set ucnt_raw TIMEOUT
  set dms_hi_raw TIMEOUT
  set dms_lo_raw TIMEOUT
  set setp_raw TIMEOUT
  set payload_valid 0
  set frame_valid 0
  set frame_start_us NA
  set frame_end_us NA

  while {[clock milliseconds] - $wait_start_ms < 350} {
    set candidate_raw [wb_read 0x00100B34]
    set candidate_word [word32 $candidate_raw]
    if {$candidate_word >= 0 && [s6s_word_valid $candidate_raw]} {
      set candidate_epoch [expr {$candidate_word & 0xffff}]
      if {$baseline_epoch < 0} {
        set baseline_epoch $candidate_epoch
        set baseline_raw $candidate_raw
      } elseif {$candidate_epoch != $baseline_epoch} {
        set ctrl_before_raw [wb_read 0x00100A04]
        set ctrl_before [word32 $ctrl_before_raw]
        set inverse_raw [wb_read 0x00100B38]
        set inverse [word32 $inverse_raw]
        if {$ctrl_before >= 0 && [s6s_word_valid $ctrl_before_raw] &&
            ($ctrl_before & 1) && $inverse >= 0 &&
            [s6s_word_valid $inverse_raw] &&
            (($candidate_epoch ^ ($inverse & 0xffff)) == 0xffff)} {
          set epoch_before $candidate_epoch
          set frame_start_us [s6s_now_us]
          set ucnt_raw [wb_read 0x00100A48]
          set dms_hi_raw [wb_read 0x00100A34]
          set dms_lo_raw [wb_read 0x00100A38]
          set setp_raw [wb_read 0x00100A44]
          set payload_valid [expr {
            [s6s_word_valid $ucnt_raw] && [s6s_word_valid $dms_hi_raw] &&
            [s6s_word_valid $dms_lo_raw] && [s6s_word_valid $setp_raw] ? 1 : 0}]
          set epoch_after_raw [wb_read 0x00100B34]
          set ctrl_after_raw [wb_read 0x00100A04]
          set frame_end_us [s6s_now_us]
          set epoch_after_word [word32 $epoch_after_raw]
          set ctrl_after [word32 $ctrl_after_raw]
          if {$epoch_after_word >= 0} {
            set epoch_after [expr {$epoch_after_word & 0xffff}]
          }
          set frame_valid [expr {
            $payload_valid && $epoch_before >= 0 &&
            $epoch_before == $epoch_after && $ctrl_after >= 0 &&
            [s6s_word_valid $epoch_after_raw] &&
            [s6s_word_valid $ctrl_after_raw] && ($ctrl_after & 1) ? 1 : 0}]
          break
        }
      }
    }
    after 1
  }
  if {$frame_end_us eq "NA"} { set frame_end_us [s6s_now_us] }
  set wait_ms [expr {[clock milliseconds] - $wait_start_ms}]
  set end_us [s6s_now_us]
  set dms_ps [s6s_unsigned64_words $dms_hi_raw $dms_lo_raw]
  set setp_ps [s6s_signed32 $setp_raw]
  return [dict create START_US $start_us END_US $end_us WAIT_MS $wait_ms \
    EPOCH_BEFORE $epoch_before EPOCH_AFTER $epoch_after UCNT_RAW $ucnt_raw \
    DMS_HI_RAW $dms_hi_raw DMS_LO_RAW $dms_lo_raw DMS_PS $dms_ps \
    SETP_RAW $setp_raw SETP_PS $setp_ps VALID $frame_valid \
    FRAME_START_US $frame_start_us FRAME_END_US $frame_end_us]
}

proc s6s_update_group_streak {name valid} {
  if {$valid} {
    set ::s6s_group_invalid_streak($name) 0
  } else {
    incr ::s6s_group_invalid_streak($name)
  }
  return $::s6s_group_invalid_streak($name)
}

proc s6s_decode_health {health_group} {
  set values [dict get $health_group VALUES]
  set status [dict get $values STATUS_RAW]
  set helper_raw [dict get $values HELPER_STATE_RAW]
  set main_raw [dict get $values MAIN_STATE_RAW]
  set pstat_raw [dict get $values PSTAT_RAW]
  set entry_raw [dict get $values RESET_ENTRY_RAW]
  set sticky_raw [dict get $values RESET_STICKY_RAW]

  set required_one_bits [list [bit64_low $status 0] [bit64_low $status 1] \
    [bit64_low $status 2] [bit64_low $status 3] [bit64_low $status 6] \
    [bit64_low $status 7] [bit64_low $status 15] [bit64_high $status 0]]
  set required_zero_bits [list [bit64_low $status 11] \
    [bit64_low $status 12] [bit64_low $status 13] [bit64_low $status 14]]
  if {[lsearch -exact $required_one_bits -1] >= 0 ||
      [lsearch -exact $required_zero_bits -1] >= 0} {
    set step1 -1
  } else {
    set step1 [expr {
      [lsearch -exact $required_one_bits 0] < 0 &&
      [lsearch -exact $required_zero_bits 1] < 0 ? 1 : 0}]
  }

  set helper_word [word32 $helper_raw]
  set main_word [word32 $main_raw]
  set pstat_word [word32 $pstat_raw]
  set helper_lock [expr {$helper_word < 0 ? -1 : ($helper_word & 1)}]
  set main_enabled [expr {$main_word < 0 ? -1 : ($main_word & 1)}]
  # Source packing in task-diags.c: enabled[0], locked[1], freq[2], phase[3].
  set main_lock [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  set pstat_lock [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]
  set boot [probe_high_counter_hex $entry_raw]
  set cpu [probe_byte_counter_hex $sticky_raw 16]
  set wr [probe_byte_counter_hex $sticky_raw 24]
  set si [probe_byte_counter_hex $sticky_raw 40]
  set reset_valid [expr {
    $boot ni {INVALID TIMEOUT} && $cpu ni {INVALID TIMEOUT} &&
    $wr ni {INVALID TIMEOUT} && $si ni {INVALID TIMEOUT} ? 1 : 0}]
  return [dict create STEP1_GATE $step1 \
    STATUS_CORE_PHY_RESET [bit64_low $status 11] \
    STATUS_SI_ID_ERROR [bit64_low $status 12] \
    STATUS_RX_ENCODING_ERROR [bit64_low $status 13] \
    STATUS_TX_ENCODING_ERROR [bit64_low $status 14] \
    HELPER_LOCK $helper_lock MAIN_ENABLED $main_enabled \
    MAIN_FREQ_LOCK $main_freq MAIN_PHASE_LOCK $main_phase MAIN_LOCK $main_lock \
    PSTAT_LOCK $pstat_lock BOOT_GENERATION $boot CPU_RESET_COUNT $cpu \
    WR_CORE_RESET_COUNT $wr SI_CONFIG_DROP_COUNT $si \
    RESET_SIGNATURE_VALID $reset_valid]
}

proc s6s_reset_changed {decoded} {
  if {![dict get $decoded RESET_SIGNATURE_VALID]} { return 0 }
  foreach field {BOOT_GENERATION CPU_RESET_COUNT WR_CORE_RESET_COUNT SI_CONFIG_DROP_COUNT} {
    set value [dict get $decoded $field]
    if {![info exists ::s6s_reset_baseline($field)]} {
      set ::s6s_reset_baseline($field) $value
    } elseif {$::s6s_reset_baseline($field) ne $value} {
      return 1
    }
  }
  return 0
}

proc s6s_emit_phase {board sample primary context} {
  set primary_ucnt [word32 [dict get $primary UCNT_RAW]]
  set context_ucnt [word32 [dict get $context UCNT_RAW]]
  set ucnt_match [expr {
    [dict get $primary VALID] && [dict get $context VALID] &&
    $primary_ucnt >= 0 && $primary_ucnt == $context_ucnt ? 1 : 0}]
  set valid [expr {$ucnt_match ? 1 : 0}]
  set sstat_raw [dict get $primary SSTAT_RAW]
  set sstat_word [word32 $sstat_raw]
  set servo_state [expr {$sstat_word < 0 ? -1 : (($sstat_word >> 8) & 0xf)}]
  set cko_ps [s6s_signed32 [dict get $primary CKO_RAW]]
  set dms_ps [dict get $context DMS_PS]
  set setp_ps [dict get $context SETP_PS]
  puts [format "S6S_PHASE board=%s sample=%04d valid=%d primary_valid=%d primary_start_us=%s primary_end_us=%s primary_wait_ms=%s epoch_before=%s epoch_after=%s CKO_RAW=%s SSTAT_RAW=%s UCNT_RAW=%s context_valid=%d context_start_us=%s context_end_us=%s context_wait_ms=%s context_epoch_before=%s context_epoch_after=%s context_UCNT_RAW=%s DMS_HI_RAW=%s DMS_LO_RAW=%s SETP_RAW=%s UCNT_MATCH=%d SERVO_STATE=%d CKO_PS=%s DMS_PS=%s SETP_PS=%s" \
    $board $sample $valid [dict get $primary VALID] \
    [dict get $primary FRAME_START_US] [dict get $primary FRAME_END_US] \
    [dict get $primary WAIT_MS] [dict get $primary EPOCH_BEFORE] \
    [dict get $primary EPOCH_AFTER] [dict get $primary CKO_RAW] \
    $sstat_raw [dict get $primary UCNT_RAW] [dict get $context VALID] \
    [dict get $context FRAME_START_US] [dict get $context FRAME_END_US] \
    [dict get $context WAIT_MS] [dict get $context EPOCH_BEFORE] \
    [dict get $context EPOCH_AFTER] [dict get $context UCNT_RAW] \
    [dict get $context DMS_HI_RAW] [dict get $context DMS_LO_RAW] \
    [dict get $context SETP_RAW] $ucnt_match $servo_state $cko_ps $dms_ps $setp_ps]
  return [dict create VALID $valid UCNT_MATCH $ucnt_match SERVO_STATE $servo_state \
    CKO_PS $cko_ps DMS_PS $dms_ps SETP_PS $setp_ps \
    UCNT_RAW [dict get $primary UCNT_RAW]]
}

set ::s6s_health_fields {
  {STATUS PROBE 0}
  {RESET_ENTRY PROBE 26}
  {RESET_STICKY PROBE 27}
  {HELPER_STATE WB 0x00100ABC}
  {MAIN_STATE WB 0x00100AC4}
  {PSTAT WB 0x00100A0C}
}
set ::s6s_admission_fields {
  {PTP_STATE WB_STABLE 0x00100A10}
  {PTP_RX_COUNT WB_COUNTER 0x00100A54}
  {PTP_TX_COUNT WB_COUNTER 0x00100A58}
  {ETH_TX_COUNT WB_COUNTER 0x00100A18}
  {ETH_RX_COUNT WB_COUNTER 0x00100A1C}
  {PTP_META WB_STABLE 0x00100A5C}
  {WR_RX_SIGNAL WB 0x00100A64}
  {WR_TX_SIGNAL WB 0x00100A68}
  {WR_FAILURE WB_STABLE 0x00100A6C}
  {WR_REJECT WB 0x00100A50}
  {WR_STATE WB_STABLE 0x00100A4C}
  {LOCK_RESULT WB_STABLE 0x00100A8C}
  {WR_LOCK_POLL_COUNT WB_COUNTER 0x00100A90}
  {LOCK_UNLOCKED_COUNT WB_COUNTER 0x00100A94}
  {LOCK_CALIB_FAIL_COUNT WB_COUNTER 0x00100A98}
  {LOCK_ENABLE_COUNT WB_STABLE 0x00100A9C}
}
set ::s6s_spll_fields {
  {SPLL_WORD WB 0x00100AA0}
  {SPLL_STATE_VISIT_MASK WB_COUNTER 0x00100AE0}
  {SPLL_STATE_TRANSITIONS WB_COUNTER 0x00100AE4}
  {SPLL_LAST_STATE WB 0x00100AE8}
  {SPLL_INIT_COUNT WB_COUNTER 0x00100B44}
  {SPLL_CLEAR_DACS_COUNT WB_COUNTER 0x00100B48}
  {SPLL_LAST_INIT_TICS WB_COUNTER 0x00100B4C}
  {SPLL_HELPER_STATE WB 0x00100ABC}
  {SPLL_HELPER_LIMITS WB_STABLE 0x00100AC0}
  {SPLL_MAIN_STATE WB 0x00100AC4}
  {SPLL_MAIN_LIMITS WB_STABLE 0x00100AC8}
  {SPLL_MAIN_PHASE_LIMITS WB_STABLE 0x00100ACC}
  {SPLL_DAC_HPLL WB 0x00100AB4}
  {SPLL_DAC_MAIN WB 0x00100AB8}
  {SPLL_HELPER_ERROR WB 0x00100AD8}
  {SPLL_HELPER_OUTPUT WB 0x00100ADC}
}
set ::s6s_event_fields {
  {DMTD_REF_ACCEPT_COUNT WB_COUNTER 0x0010022C}
  {DMTD_FB_ACCEPT_COUNT WB_COUNTER 0x00100230}
  {DMTD_REF_EVENT_COUNT WB_COUNTER 0x00100298}
  {DMTD_FB_EVENT_COUNT WB_COUNTER 0x0010029C}
  {TAG_VALID_COUNT WB_COUNTER 0x00100284}
  {TRR_WRITE_COUNT WB_COUNTER 0x00100288}
  {TRR_POP_COUNT WB_COUNTER 0x00100B54}
  {IRQ_COUNT WB_COUNTER 0x00100AEC}
  {HELPER_UPDATE_COUNT WB_COUNTER 0x00100B18}
}

puts "S6S_CONFIG board_filter=$::s6s_board_filter duration_ms=$::s6s_duration_ms sample_delay_ms=$::s6s_sample_delay_ms source_commit=9c9afa345c1de03760ec9ee07eb742888c3fa8fe slave_sof_sha256=13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19 master_sof_sha256=697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a read_only=1 wb_functional_writes=0 helper_pi_snapshot=0 reset=0 fpga_program=0"
puts "S6S_GROUP_CONTRACT health=Step1+locks+reset admission=PTP+WR+lock-poll spll=mode+sequencer+state+helper+main events=DMTD-accept-to-helper-update phase=guarded-primary-and-context-joined-by-UCNT cross_group_atomic=0"
flush stdout

set matching_hardware {}
foreach hardware_name [get_hardware_names] {
  if {[string first $::s6s_board_filter $hardware_name] >= 0} {
    lappend matching_hardware $hardware_name
  }
}
if {[llength $matching_hardware] != 1} {
  set ::s6s_stop_reason [expr {[llength $matching_hardware] == 0 ? "NO_MATCHING_BOARD" : "AMBIGUOUS_BOARD_IDENTITY"}]
  puts [format "S6S_STOP board=NONE duration_ms=0 samples=0 structurally_trusted=0 stop_reason=%s" $::s6s_stop_reason]
} else {
  set hardware_name [lindex $matching_hardware 0]
  set board_tag [string map {" " "_" "[" "" "]" ""} $hardware_name]
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} {
    set ::s6s_stop_reason NO_DEVICE
    puts [format "S6S_STOP board=%s duration_ms=0 samples=0 structurally_trusted=0 stop_reason=%s" $board_tag $::s6s_stop_reason]
  } else {
    set device_name [lindex $device_names 0]
    catch {end_insystem_source_probe}
    if {[catch {
      start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
      wb_sync_toggle
    } setup_error]} {
      set ::s6s_stop_reason READER_SETUP_ERROR
      puts [format "S6S_ERROR board=%s stage=setup detail=%s" $board_tag $setup_error]
      puts [format "S6S_STOP board=%s duration_ms=0 samples=0 structurally_trusted=0 stop_reason=%s" $board_tag $::s6s_stop_reason]
    } else {
      puts [format "S6S_BOARD board=%s device=%s" $board_tag $device_name]
      set capture_start_us [s6s_now_us]
      set previous_row_start_us ""
      set last_row_start_ms NA
      set last_row_end_ms NA
      set ::s6s_stop_reason DURATION_LIMIT
      while {1} {
        set before_row_us [s6s_now_us]
        set elapsed_before_ms [expr {($before_row_us - $capture_start_us) / 1000}]
        if {$elapsed_before_ms >= $::s6s_duration_ms} {
          set ::s6s_stop_reason DURATION_LIMIT
          break
        }
        set sample $::s6s_samples
        set row_start_us $before_row_us
        if {[catch {
          set health_group [s6s_read_group $::s6s_health_fields]
          set admission_group [s6s_read_group $::s6s_admission_fields]
          set spll_group [s6s_read_group $::s6s_spll_fields]
          set events_group [s6s_read_group $::s6s_event_fields]
          set primary [s6s_phase_primary]
          set context [s6s_phase_context]
          set phase [s6s_emit_phase $board_tag $sample $primary $context]
          set decoded [s6s_decode_health $health_group]
          set reset_changed [s6s_reset_changed $decoded]
        } capture_error]} {
          set ::s6s_stop_reason FATAL_READER_ERROR
          puts [format "S6S_ERROR board=%s sample=%04d stage=capture detail=%s" $board_tag $sample $capture_error]
          flush stdout
          break
        }

        s6s_emit_group $board_tag $sample HEALTH $health_group
        s6s_emit_group $board_tag $sample ADMISSION $admission_group
        s6s_emit_group $board_tag $sample SPLL $spll_group
        s6s_emit_group $board_tag $sample EVENTS $events_group

        set health_reads_valid [expr {
          [dict get $health_group VALID] &&
          [dict get $decoded RESET_SIGNATURE_VALID] && !$reset_changed &&
          [dict get $decoded STEP1_GATE] >= 0 &&
          [dict get $decoded STATUS_CORE_PHY_RESET] >= 0 &&
          [dict get $decoded STATUS_SI_ID_ERROR] >= 0 &&
          [dict get $decoded STATUS_RX_ENCODING_ERROR] >= 0 &&
          [dict get $decoded STATUS_TX_ENCODING_ERROR] >= 0 &&
          [dict get $decoded HELPER_LOCK] >= 0 &&
          [dict get $decoded MAIN_ENABLED] >= 0 &&
          [dict get $decoded MAIN_FREQ_LOCK] >= 0 &&
          [dict get $decoded MAIN_PHASE_LOCK] >= 0 &&
          [dict get $decoded MAIN_LOCK] >= 0 &&
          [dict get $decoded PSTAT_LOCK] >= 0 ? 1 : 0}]
        set health_ready [expr {
          $health_reads_valid && [dict get $decoded STEP1_GATE] == 1 &&
          [dict get $decoded MAIN_ENABLED] == 1 &&
          [dict get $decoded HELPER_LOCK] == 1 &&
          [dict get $decoded MAIN_FREQ_LOCK] == 1 &&
          [dict get $decoded MAIN_PHASE_LOCK] == 1 &&
          [dict get $decoded MAIN_LOCK] == 1 &&
          [dict get $decoded PSTAT_LOCK] == 1 ? 1 : 0}]
        if {$health_ready} {
          if {$::s6s_ready_rows == 0} { set ::s6s_ready_since_us [s6s_now_us] }
          incr ::s6s_ready_rows
          set ready_streak_ms [expr {([s6s_now_us] - $::s6s_ready_since_us) / 1000}]
        } else {
          set ::s6s_ready_rows 0
          set ::s6s_ready_since_us ""
          set ready_streak_ms 0
        }

        set structural_trusted [expr {
          $health_reads_valid && [dict get $phase VALID] &&
          [dict get $decoded RESET_SIGNATURE_VALID] && !$reset_changed ? 1 : 0}]
        if {$structural_trusted} {
          incr ::s6s_structurally_trusted
          set ::s6s_structural_invalid_streak 0
        } else {
          incr ::s6s_structural_invalid_streak
        }
        foreach group_name {ADMISSION SPLL EVENTS} {
          switch -- $group_name {
            ADMISSION { set group_value $admission_group }
            SPLL { set group_value $spll_group }
            EVENTS { set group_value $events_group }
          }
          s6s_update_group_streak $group_name [dict get $group_value VALID]
        }

        set row_end_us [s6s_now_us]
        set spacing_ms NA
        if {$previous_row_start_us ne ""} {
          set spacing_ms [format %.3f [expr {($row_start_us - $previous_row_start_us) / 1000.0}]]
        }
        set previous_row_start_us $row_start_us
        set last_row_start_ms [expr {($row_start_us - $capture_start_us) / 1000}]
        set last_row_end_ms [expr {($row_end_us - $capture_start_us) / 1000}]
        set elapsed_ms $last_row_end_ms

        set helper_raw [word32 [dict get [dict get $spll_group VALUES] SPLL_HELPER_STATE_RAW]]
        set helper_limits [word32 [dict get [dict get $spll_group VALUES] SPLL_HELPER_LIMITS_RAW]]
        set main_raw [word32 [dict get [dict get $spll_group VALUES] SPLL_MAIN_STATE_RAW]]
        set spll_raw [word32 [dict get [dict get $spll_group VALUES] SPLL_WORD_RAW]]
        set helper_ref_src [expr {$helper_raw < 0 ? -1 : (($helper_raw >> 8) & 0xff)}]
        set helper_lock_count [expr {$helper_raw < 0 ? -1 : (($helper_raw >> 16) & 0xffff)}]
        set helper_threshold [expr {$helper_limits < 0 ? -1 : ($helper_limits & 0xffff)}]
        set helper_lock_samples [expr {$helper_limits < 0 ? -1 : (($helper_limits >> 16) & 0xffff)}]
        set spll_main_enabled [expr {$main_raw < 0 ? -1 : ($main_raw & 1)}]
        set seq_state [expr {$spll_raw < 0 ? -1 : ($spll_raw & 0xff)}]
        set align_state [expr {$spll_raw < 0 ? -1 : (($spll_raw >> 8) & 0xff)}]
        set spll_mode [expr {$spll_raw < 0 ? -1 : (($spll_raw >> 16) & 0xff)}]
        set delock_count [expr {$spll_raw < 0 ? -1 : (($spll_raw >> 24) & 0xff)}]
        set sstat_raw [dict get $phase SERVO_STATE]
        set cko_ps [dict get $phase CKO_PS]
        set dms_ps [dict get $phase DMS_PS]
        set setp_ps [dict get $phase SETP_PS]
        puts [format "S6S_ROW board=%s sample=%04d elapsed_ms=%d ROW_START_US=%s ROW_END_US=%s ROW_SPACING_MS=%s HEALTH_READS_VALID=%d STEP1_GATE=%d STEP1_CORE_PHY_RESET=%d STEP1_SI_ID_ERROR=%d STEP1_RX_ENCODING_ERROR=%d STEP1_TX_ENCODING_ERROR=%d HELPER_LOCK=%d MAIN_ENABLED=%d HELPER_REF_SRC=%d HELPER_LOCK_COUNT=%d HELPER_LOCK_THRESHOLD=%d HELPER_LOCK_SAMPLES=%d SPLL_GROUP_MAIN_ENABLED=%d MAIN_FREQ_LOCK=%d MAIN_PHASE_LOCK=%d MAIN_LOCK=%d PSTAT_LOCK=%d SPLL_MODE=%d SPLL_SEQ_STATE=%d SPLL_ALIGN_STATE=%d SPLL_DELOCK_COUNT=%d STRUCTURALLY_TRUSTED_ROW=%d RESET_CHANGED=%d HEALTH_READY_ROW=%d READY_STREAK_ROWS=%d READY_STREAK_MS=%d PHASE_VALID=%d SERVO_STATE=%d CKO_PS=%s DMS_PS=%s SETP_PS=%s UCNT_RAW=%s ADMISSION_GROUP_VALID=%d SPLL_GROUP_VALID=%d EVENTS_GROUP_VALID=%d STRUCTURAL_INVALID_STREAK=%d ADMISSION_INVALID_STREAK=%d SPLL_INVALID_STREAK=%d EVENTS_INVALID_STREAK=%d" \
          $board_tag $sample $elapsed_ms $row_start_us $row_end_us $spacing_ms \
          $health_reads_valid [dict get $decoded STEP1_GATE] \
          [dict get $decoded STATUS_CORE_PHY_RESET] \
          [dict get $decoded STATUS_SI_ID_ERROR] \
          [dict get $decoded STATUS_RX_ENCODING_ERROR] \
          [dict get $decoded STATUS_TX_ENCODING_ERROR] \
          [dict get $decoded HELPER_LOCK] [dict get $decoded MAIN_ENABLED] \
          $helper_ref_src $helper_lock_count $helper_threshold \
          $helper_lock_samples $spll_main_enabled \
          [dict get $decoded MAIN_FREQ_LOCK] [dict get $decoded MAIN_PHASE_LOCK] \
          [dict get $decoded MAIN_LOCK] [dict get $decoded PSTAT_LOCK] \
          $spll_mode $seq_state $align_state $delock_count $structural_trusted \
          $reset_changed $health_ready $::s6s_ready_rows $ready_streak_ms \
          [dict get $phase VALID] [dict get $phase SERVO_STATE] $cko_ps $dms_ps \
          $setp_ps [dict get $phase UCNT_RAW] [dict get $admission_group VALID] \
          [dict get $spll_group VALID] [dict get $events_group VALID] \
          $::s6s_structural_invalid_streak \
          $::s6s_group_invalid_streak(ADMISSION) $::s6s_group_invalid_streak(SPLL) \
          $::s6s_group_invalid_streak(EVENTS)]
        flush stdout
        incr ::s6s_samples

        if {$reset_changed} {
          set ::s6s_stop_reason RESET_SIGNATURE_CHANGED
          break
        }
        if {$::s6s_structural_invalid_streak >= 5} {
          set ::s6s_stop_reason FIVE_CONSECUTIVE_STRUCTURALLY_UNTRUSTED_ROWS
          break
        }
        set group_failed 0
        foreach group_name {ADMISSION SPLL EVENTS} {
          if {$::s6s_group_invalid_streak($group_name) >= 5} { set group_failed 1 }
        }
        if {$group_failed} {
          set ::s6s_stop_reason FIVE_CONSECUTIVE_INVALID_REQUIRED_GROUP_ROWS
          break
        }
        if {$structural_trusted && $sstat_raw in {3 4 5}} {
          set ::s6s_stop_reason PHASE_STATE_BOUNDARY
          break
        }
        if {$health_ready && $::s6s_ready_rows >= 10 && $ready_streak_ms >= 10000} {
          set ::s6s_stop_reason READINESS_REACHED
          break
        }
        if {$elapsed_ms >= $::s6s_duration_ms} {
          set ::s6s_stop_reason DURATION_LIMIT
          break
        }
        after $::s6s_sample_delay_ms
      }

      set final_us [s6s_now_us]
      set final_elapsed_ms [expr {($final_us - $capture_start_us) / 1000}]
      puts [format "S6S_STOP board=%s duration_ms=%d elapsed_ms=%d last_row_start_ms=%s last_row_end_ms=%s samples=%d structurally_trusted=%d structural_invalid_streak=%d admission_invalid_streak=%d spll_invalid_streak=%d events_invalid_streak=%d ready_streak_rows=%d stop_reason=%s wb_timeout_count=%d wb_invalid_count=%d" \
        $board_tag $::s6s_duration_ms $final_elapsed_ms $last_row_start_ms \
        $last_row_end_ms $::s6s_samples $::s6s_structurally_trusted \
        $::s6s_structural_invalid_streak $::s6s_group_invalid_streak(ADMISSION) \
        $::s6s_group_invalid_streak(SPLL) $::s6s_group_invalid_streak(EVENTS) \
        $::s6s_ready_rows $::s6s_stop_reason $::wb_timeout_count $::wb_invalid_count]
      flush stdout
      catch {end_insystem_source_probe}
    }
  }
}

puts [format "S6S_DONE stop_reason=%s samples=%d structurally_trusted=%d" \
  $::s6s_stop_reason $::s6s_samples $::s6s_structurally_trusted]
flush stdout
