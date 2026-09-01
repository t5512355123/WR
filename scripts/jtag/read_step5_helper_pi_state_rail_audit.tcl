# Read-only Helper PI state and rail audit for Step5.
#
# The firmware mirror publishes one completed Helper PI update through the
# private WDIAGS snapshot bank at 0x158..0x1dc.  V3 uses a serialized
# request -> frozen bank -> ACK transaction.  The request generation is
# written into the bank's own PI_TRACE_EPOCH (odd while publishing, even
# after commit), so BANK_SEQ and the other forensic overlays never decide
# frame validity.  Probe 43/44 provide the signed physical-position context.
#
# Usage:
#   quartus_stp -t read_step5_helper_pi_state_rail_audit.tcl ?samples? ?gap_ms? ?board_filter?

package require ::quartus::insystem_source_probe

set samples 600
set gap_ms 100
set board_filter ""
set poll_attempts 100
set snapshot_poll_attempts 1000
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

set PI_KP -150
set PI_KI -1
set PI_SHIFT 12
set PI_BIAS 5
set PI_Y_MIN 5
set PI_Y_MAX 65531

array set ::wb_toggle {}
array set ::sample_count {}
array set ::valid_frame_count {}
array set ::invalid_frame_count {}
array set ::pi_present_count {}
array set ::pi_snapshot_reject_count {}
array set ::pi_accounting_fail_count {}
array set ::pi_output_mismatch_count {}
array set ::anti_windup_violation_count {}
array set ::low_rail_count {}
array set ::high_rail_count {}
array set ::zero_crossing_count {}
array set ::physical_position_mismatch_count {}
array set ::first_high_rail_sample {}
array set ::first_low_rail_sample {}
array set ::first_zero_crossing_sample {}
array set ::first_low_leave_sample {}
array set ::high_seen {}
array set ::high_to_low_seen {}
array set ::zero_crossing_seen {}
array set ::low_after_zero_seen {}
array set ::cycle_complete {}
array set ::previous_freq_error {}
array set ::previous_pi_epoch {}
array set ::previous_helper_count {}
array set ::previous_helper_error_in_band {}
array set ::helper_epoch_reset_count {}
array set ::helper_error_count {}
array set ::helper_error_sum {}
array set ::helper_error_sumsq {}
array set ::helper_error_max_abs {}
array set ::helper_error_in_band_count {}
array set ::raw_error_count {}
array set ::raw_error_positive_count {}
array set ::raw_error_sum {}
array set ::raw_error_min {}
array set ::raw_error_max {}
array set ::unclamped_below_min_count {}
array set ::freq_error_count {}
array set ::freq_error_sum {}
array set ::freq_error_sumsq {}
array set ::freq_error_max_abs {}
array set ::helper_lock_max {}
array set ::helper_lock_rise_events {}
array set ::helper_lock_fall_events {}
array set ::error_band_exit_events {}
array set ::spll_init_first {}
array set ::spll_init_final {}
array set ::clear_dacs_first {}
array set ::clear_dacs_final {}
array set ::spll_delock_first {}
array set ::spll_delock_final {}
array set ::normal_req_first {}
array set ::normal_req_final {}
array set ::normal_completed_first {}
array set ::normal_completed_final {}
array set ::dco_step_first {}
array set ::dco_step_final {}
array set ::forced_completed_first {}
array set ::forced_completed_final {}
array set ::bootstrap_completed_first {}
array set ::bootstrap_completed_final {}
array set ::bootstrap_done_final {}
array set ::main_enabled_first {}
array set ::main_enabled_final {}
array set ::main_freq_locked_first {}
array set ::main_freq_locked_final {}
array set ::main_phase_locked_first {}
array set ::main_phase_locked_final {}
array set ::main_locked_first {}
array set ::main_locked_final {}
array set ::pstat_locked_first {}
array set ::pstat_locked_final {}
array set ::tag_valid_first {}
array set ::tag_valid_final {}
array set ::normal_completed_first {}
array set ::normal_completed_final {}
array set ::position_applied_final {}
array set ::position_target_final {}
array set ::helper_error_final {}
array set ::helper_output_final {}
array set ::helper_locked_final {}
array set ::helper_count_final {}
array set ::pi_epoch_final {}
array set ::pi_before_final {}
array set ::pi_i_new_final {}
array set ::pi_after_final {}
array set ::pi_unclamped_final {}
array set ::pi_clamped_final {}
array set ::pi_side_final {}
array set ::pi_raw_error_final {}
array set ::pi_ld_error_final {}
array set ::pi_prop_final {}
array set ::pi_preround_final {}
array set ::pi_y_min_final {}
array set ::pi_y_max_final {}
array set ::reset_first {}
array set ::reset_final {}
array set ::elapsed_final {}
array set ::snapshot_next_seq {}
array set ::snapshot_req_first {}
array set ::snapshot_req_final {}
array set ::snapshot_ack_first {}
array set ::snapshot_ack_final {}
array set ::snapshot_ack_seq_final {}
array set ::snapshot_ack_mismatch_count {}
array set ::snapshot_ack_timeout_count {}
array set ::snapshot_epoch_generation_mismatch_count {}
array set ::snapshot_epoch_changed_count {}
array set ::snapshot_bank_commit_first {}
array set ::snapshot_bank_commit_final {}
array set ::snapshot_overwrite_first {}
array set ::snapshot_overwrite_final {}
array set ::snapshot_request_seq_final {}
array set ::snapshot_last_req_seq_final {}
array set ::snapshot_bank_seq_final {}
array set ::primary_reject_count {}

set ::primary_reject_reason_order {
  REQUEST_DATA_WRITE_FAIL
  REQUEST_TRIGGER_WRITE_FAIL
  ACK_TIMEOUT
  ACK_BEGIN_MISMATCH
  EPOCH_BEGIN_INVALID
  EPOCH_GENERATION_MISMATCH
  PAYLOAD_READ_INVALID
  EPOCH_CHANGED_DURING_READ
  ACK_END_MISMATCH
  MAGIC_MISMATCH
  PI_MATH_HEADER_FAIL
  PI_MATH_CONSTANT_FAIL
  PI_MATH_RAW_ERROR_FAIL
  PI_MATH_I_NEW_FAIL
  PI_MATH_INTEGRATOR_FAIL
  PI_MATH_PROP_FAIL
  PI_MATH_PREROUND_FAIL
  PI_MATH_OUTPUT_FAIL
  PI_MATH_CLAMP_FAIL
  POSITION_CONTEXT_FAIL
  OTHER
}

set ::snapshot_last_primary_reason OTHER
set ::snapshot_last_failed_field NONE

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc word64 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  set text [string repeat 0 [expr {16 - [string length $text]}]]$text
  scan $text %x word
  return $word
}

proc signed32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  if {$word >= 0x80000000} {
    return [expr {$word - 0x100000000}]
  }
  return $word
}

proc signed64_words {lo_raw hi_raw} {
  set lo [word32 $lo_raw]
  set hi [word32 $hi_raw]
  if {$lo < 0 || $hi < 0} { return INVALID }
  set value [expr {$hi * 4294967296 + $lo}]
  if {$hi >= 0x80000000} {
    return [expr {$value - 18446744073709551616}]
  }
  return $value
}

proc display_value {value} {
  if {![is_hex $value]} { return $value }
  return [string toupper $value]
}

proc probe_high32 {value} {
  if {![is_hex $value]} { return INVALID }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  set text [string repeat 0 [expr {16 - [string length $text]}]]$text
  scan [string range $text 0 7] %x word
  return [expr {$word & 0xffffffff}]
}

proc probe_field32 {value low width} {
  set high [probe_high32 $value]
  if {$high eq "INVALID"} { return INVALID }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($high >> $low) & $mask}]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return INVALID
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc wb_read {hardware_name addr} {
  global poll_attempts
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return INVALID
  }
  after 5
  for {set n 0} {$n < $poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value INVALID
    }
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} {
        return [format %08X [expr {$word & 0xffffffff}]]
      }
    }
    after 1
  }
  return INVALID
}

proc wb_command_hex {toggle write addr data} {
  # The mailbox source is 96 bits wide: data[31:0] is carried in command
  # bits 69:38.  Tcl's integer formatter is only wide enough for the lower
  # 64 bits on the Quartus 17.0 host, so build the high and low words as
  # separate fields instead of formatting one 96-bit integer.
  set data32 [expr {$data & 0xffffffff}]
  set addr32 [expr {$addr & 0xffffffff}]
  set high32 [expr {($data32 >> 26) & 0x3f}]
  set low64 [expr {(($data32 & 0x03ffffff) << 38) |
                   (($addr32 & 0xffffffff) << 6) |
                   (($write & 1) << 1) |
                   (($toggle & 1) | (0xf << 2))}]
  return [format %08X%016X $high32 $low64]
}

proc wb_write {hardware_name addr data} {
  global poll_attempts
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [wb_command_hex $toggle 1 $addr $data]
  if {[catch {
    write_source_data -instance_index 1 -value $cmd -value_in_hex
  }]} {
    return 0
  }
  after 5
  for {set n 0} {$n < $poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value INVALID
    }
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} {
        # The mailbox ACK/ERR flags are one-clock result strobes.  Once the
        # transaction is complete they may already be low, so completion is
        # determined by the persistent done toggle, as in wb_read.
        return 1
      }
    }
    after 1
  }
  return 0
}

proc wb_sync_toggle {hardware_name} {
  set value [probe_read 1]
  if {[is_hex $value]} {
    scan $value %x word
    set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc counter_delta {first last width} {
  if {$first eq "INVALID" || $last eq "INVALID"} { return INVALID }
  if {![string is integer -strict $first] || ![string is integer -strict $last]} {
    return INVALID
  }
  set modulus [expr {1 << $width}]
  if {$last >= $first} { return [expr {$last - $first}] }
  return [expr {$last + $modulus - $first}]
}

proc frame_valid {ctrl_begin ctrl_end} {
  set a [word32 $ctrl_begin]
  set b [word32 $ctrl_end]
  if {$a < 0 || $b < 0} { return 0 }
  return [expr {(($a & 1) != 0) && (($b & 1) != 0) && $a == $b}]
}

proc set_snapshot_reject {reason field} {
  set ::snapshot_last_primary_reason $reason
  set ::snapshot_last_failed_field $field
}

proc set_pi_math_failure {reason field detail} {
  set ::snapshot_last_primary_reason $reason
  set ::snapshot_last_failed_field $field
  set ::pi_math_last_reason [format "field=%s %s" $field $detail]
}

proc record_primary_reject {hardware_name sample request_seq frame_valid reason field} {
  if {$frame_valid} {
    set reason NONE
    set field NONE
  } else {
    if {$reason eq "" || $reason eq "NONE"} { set reason OTHER }
    if {[lsearch -exact $::primary_reject_reason_order $reason] < 0} {
      set reason OTHER
    }
    set key [format "%s|%s" $hardware_name $reason]
    if {![info exists ::primary_reject_count($key)]} {
      set ::primary_reject_count($key) 0
    }
    incr ::primary_reject_count($key)
  }
  puts [format "V3_REJECT_ATTRIBUTION board=%s sample=%d request_seq=%s FRAME_VALID=%d PRIMARY_REJECT_REASON=%s FAILED_FIELD=%s" \
    $hardware_name $sample $request_seq $frame_valid $reason $field]
}

proc read_stable_position_pair {} {
  for {set attempt 0} {$attempt < 10} {incr attempt} {
    set accounting_before [probe_read 44]
    set position [probe_read 43]
    set accounting_after [probe_read 44]
    if {[is_hex $accounting_before] && [is_hex $position] &&
        [is_hex $accounting_after] &&
        [string equal -nocase $accounting_before $accounting_after]} {
      return [list $position $accounting_after]
    }
    after 1
  }
  return [list INVALID INVALID]
}

proc next_snapshot_seq {hardware_name} {
  if {![info exists ::snapshot_next_seq($hardware_name)]} {
    set ::snapshot_next_seq($hardware_name) 1
  }
  if {![info exists ::snapshot_ack_mismatch_count($hardware_name)]} {
    set ::snapshot_ack_mismatch_count($hardware_name) 0
  }
  set seq $::snapshot_next_seq($hardware_name)
  incr ::snapshot_next_seq($hardware_name)
  if {$::snapshot_next_seq($hardware_name) >= 0xffffffff} {
    set ::snapshot_next_seq($hardware_name) 1
  }
  return $seq
}

proc request_atomic_pi_snapshot {hardware_name request_seq} {
  global snapshot_poll_attempts
  set ::snapshot_last_primary_reason OTHER
  set ::snapshot_last_failed_field NONE
  # SYSCON BASE_SYSCON + DIAG_DAT/DIAG_CR.  The one enabled RW word is index 0.
  set data_write_ok [wb_write $hardware_name 0x0010042C $request_seq]
  set cr_write_ok [wb_write $hardware_name 0x00100428 0x80000000]
  if {$request_seq == 1} {
    set diag_nw [wb_read $hardware_name 0x00100424]
    set diag_cr_read [wb_write $hardware_name 0x00100428 0]
    set request_readback [wb_read $hardware_name 0x0010042C]
    set diag_cr_after [wb_read $hardware_name 0x00100428]
    set cpu_store [probe_read 4]
    set cpu_store_count [probe_read 5]
    set cpu_data_diag_addr [probe_read 9]
    set cpu_data_diag_meta [probe_read 10]
    puts [format "ATOMIC_TRANSPORT_PROBE board=%s DATA_WRITE_DONE=%d CR_WRITE_DONE=%d DIAG_NW=%s DIAG_CR_READ_DONE=%d REQUEST_READBACK=%s DIAG_CR_AFTER=%s CPU_STORE=%s CPU_STORE_COUNT=%s CPU_DATA_DIAG_ADDR=%s CPU_DATA_DIAG_META=%s" \
      $hardware_name $data_write_ok $cr_write_ok $diag_nw $diag_cr_read $request_readback \
      $diag_cr_after $cpu_store $cpu_store_count $cpu_data_diag_addr $cpu_data_diag_meta]
  }
  if {!$data_write_ok} {
    set_snapshot_reject REQUEST_DATA_WRITE_FAIL DIAG_DAT
    return 0
  }
  if {!$cr_write_ok} {
    set_snapshot_reject REQUEST_TRIGGER_WRITE_FAIL DIAG_CR
    return 0
  }
  for {set n 0} {$n < $snapshot_poll_attempts} {incr n} {
    set ack [word32 [wb_read $hardware_name 0x00100B28]]
    if {$ack >= 0 && $ack == $request_seq} {
      return 1
    }
    after 1
  }
  incr ::snapshot_ack_timeout_count($hardware_name)
  set_snapshot_reject ACK_TIMEOUT SNAPSHOT_ACK_SEQ
  return 0
}

proc read_pi_snapshot {hardware_name request_seq} {
  # Firmware ACK is published only after the full bank has been copied and
  # committed with the request generation in PI_TRACE_EPOCH.  The in-band
  # epoch and the second ACK read are the transport-level checks required by
  # Step5; BANK_SEQ is retained only as forensic data.
  if {![request_atomic_pi_snapshot $hardware_name $request_seq]} {
    set ::snapshot_bank_seq_final($hardware_name) INVALID
    return [read_pi_snapshot_invalid]
  }
  set ack_begin_raw [wb_read $hardware_name 0x00100B28]
  set ack_begin [word32 $ack_begin_raw]
  if {$ack_begin < 0 || $ack_begin != $request_seq} {
    incr ::snapshot_ack_mismatch_count($hardware_name)
    set_snapshot_reject ACK_BEGIN_MISMATCH SNAPSHOT_ACK_SEQ_BEGIN
    return [read_pi_snapshot_invalid]
  }
  set epoch_begin [wb_read $hardware_name 0x00100B58]
  set epoch_word [word32 $epoch_begin]
  set tag_raw [wb_read $hardware_name 0x00100B5C]
  set p_adder [wb_read $hardware_name 0x00100B60]
  set p_setpoint [wb_read $hardware_name 0x00100B64]
  set raw_error [wb_read $hardware_name 0x00100B68]
  set ld_error [wb_read $hardware_name 0x00100B6C]
  set lock_state [wb_read $hardware_name 0x00100B70]
  set before_lo [wb_read $hardware_name 0x00100B74]
  set before_hi [wb_read $hardware_name 0x00100B78]
  set i_new_lo [wb_read $hardware_name 0x00100B7C]
  set i_new_hi [wb_read $hardware_name 0x00100B80]
  set after_lo [wb_read $hardware_name 0x00100B84]
  set after_hi [wb_read $hardware_name 0x00100B88]
  set prop_lo [wb_read $hardware_name 0x00100B8C]
  set prop_hi [wb_read $hardware_name 0x00100B90]
  set preround_lo [wb_read $hardware_name 0x00100B94]
  set preround_hi [wb_read $hardware_name 0x00100B98]
  set unclamped [wb_read $hardware_name 0x00100B9C]
  set y_min [wb_read $hardware_name 0x00100BA0]
  set y_max [wb_read $hardware_name 0x00100BA4]
  set clamp_side [wb_read $hardware_name 0x00100BA8]
  set final_output [wb_read $hardware_name 0x00100BAC]
  set x [wb_read $hardware_name 0x00100BB0]
  set kp [wb_read $hardware_name 0x00100BB4]
  set ki [wb_read $hardware_name 0x00100BB8]
  set shift [wb_read $hardware_name 0x00100BBC]
  set bias [wb_read $hardware_name 0x00100BC0]
  set anti_windup [wb_read $hardware_name 0x00100BC4]
  set update_count [wb_read $hardware_name 0x00100BC8]
  set freq_error [wb_read $hardware_name 0x00100BCC]
  set lock_threshold [wb_read $hardware_name 0x00100BD0]
  set lock_samples [wb_read $hardware_name 0x00100BD4]
  set ref_src [wb_read $hardware_name 0x00100BD8]
  set magic [wb_read $hardware_name 0x00100BDC]
  set bank_seq_end [word32 [wb_read $hardware_name 0x00100B40]]
  set epoch_end [wb_read $hardware_name 0x00100B58]
  set ack_end [word32 [wb_read $hardware_name 0x00100B28]]
  set epoch_begin_word [word32 $epoch_begin]
  set epoch_end_word [word32 $epoch_end]
  set magic_word [word32 $magic]
  set expected_epoch [expr {($request_seq * 2) & 0xffffffff}]
  set epoch_changed 0
  if {$epoch_begin_word >= 0 && $epoch_end_word >= 0 &&
      $epoch_begin_word != $epoch_end_word} {
    set epoch_changed 1
    incr ::snapshot_epoch_changed_count($hardware_name)
  }
  set epoch_generation_ok [expr {$epoch_begin_word >= 0 &&
      $epoch_end_word >= 0 && $epoch_begin_word == $expected_epoch &&
      $epoch_end_word == $expected_epoch && !($epoch_begin_word & 1) &&
      !($epoch_end_word & 1)}]
  if {$epoch_begin_word < 0} {
    incr ::snapshot_epoch_generation_mismatch_count($hardware_name)
    set_snapshot_reject EPOCH_BEGIN_INVALID PI_TRACE_EPOCH_BEGIN
    return [read_pi_snapshot_invalid]
  }
  if {!$epoch_generation_ok} {
    incr ::snapshot_epoch_generation_mismatch_count($hardware_name)
    set_snapshot_reject EPOCH_GENERATION_MISMATCH PI_TRACE_EPOCH
    return [read_pi_snapshot_invalid]
  }

  set payload_pairs [list \
    PI_TRACE_EPOCH_BEGIN $epoch_begin \
    PI_TAG_RAW $tag_raw \
    PI_P_ADDER $p_adder \
    PI_P_SETPOINT $p_setpoint \
    PI_RAW_ERROR $raw_error \
    PI_LD_ERROR $ld_error \
    PI_HELPER_STATE $lock_state \
    PI_INTEGRATOR_BEFORE_LO $before_lo \
    PI_INTEGRATOR_BEFORE_HI $before_hi \
    PI_I_NEW_LO $i_new_lo \
    PI_I_NEW_HI $i_new_hi \
    PI_INTEGRATOR_AFTER_LO $after_lo \
    PI_INTEGRATOR_AFTER_HI $after_hi \
    PI_PROP_TERM_LO $prop_lo \
    PI_PROP_TERM_HI $prop_hi \
    PI_Y_PREROUND_LO $preround_lo \
    PI_Y_PREROUND_HI $preround_hi \
    PI_UNCLAMPED_OUTPUT $unclamped \
    PI_Y_MIN $y_min \
    PI_Y_MAX $y_max \
    PI_CLAMP_SIDE $clamp_side \
    PI_CLAMPED_OUTPUT $final_output \
    PI_X $x \
    PI_KP $kp \
    PI_KI $ki \
    PI_SHIFT $shift \
    PI_BIAS $bias \
    PI_ANTI_WINDUP $anti_windup \
    PI_UPDATE_COUNT $update_count \
    PI_FREQ_ERROR $freq_error \
    PI_LOCK_THRESHOLD $lock_threshold \
    PI_LOCK_SAMPLES $lock_samples \
    PI_REF_SRC $ref_src \
    PI_TRACE_MAGIC $magic \
    PI_TRACE_EPOCH_END $epoch_end]
  set first_bad_field NONE
  foreach {field value} $payload_pairs {
    if {![is_hex $value]} {
      set first_bad_field $field
      break
    }
  }
  if {$first_bad_field ne "NONE"} {
    set_snapshot_reject PAYLOAD_READ_INVALID $first_bad_field
    return [read_pi_snapshot_invalid]
  }
  if {$epoch_changed} {
    set_snapshot_reject EPOCH_CHANGED_DURING_READ PI_TRACE_EPOCH
    return [read_pi_snapshot_invalid]
  }
  if {$ack_end < 0 || $ack_end != $request_seq} {
    incr ::snapshot_ack_mismatch_count($hardware_name)
    set_snapshot_reject ACK_END_MISMATCH SNAPSHOT_ACK_SEQ_END
    return [read_pi_snapshot_invalid]
  }
  if {$magic_word != 1} {
    set_snapshot_reject MAGIC_MISMATCH PI_TRACE_MAGIC
    return [read_pi_snapshot_invalid]
  }
  set ::snapshot_bank_seq_final($hardware_name) $bank_seq_end
  return [list 1 $epoch_word $tag_raw $p_adder $p_setpoint $raw_error \
    $ld_error $lock_state $before_lo $before_hi $i_new_lo $i_new_hi \
    $after_lo $after_hi $prop_lo $prop_hi $preround_lo $preround_hi \
    $unclamped $y_min $y_max $clamp_side $final_output $x $kp $ki \
    $shift $bias $anti_windup $update_count $freq_error $lock_threshold \
    $lock_samples $ref_src $magic]
}

proc pi_snapshot_math_valid {snapshot} {
  global PI_KP PI_KI PI_SHIFT PI_BIAS PI_Y_MIN PI_Y_MAX
  set ::pi_math_last_reason UNKNOWN
  foreach {pi_valid pi_epoch tag_raw p_adder p_setpoint raw_error_raw ld_error_raw \
           lock_state_raw before_lo before_hi i_new_lo i_new_hi after_lo after_hi \
           prop_lo prop_hi preround_lo preround_hi unclamped_raw y_min_raw y_max_raw \
           side_raw final_raw x_raw kp_raw ki_raw shift_raw bias_raw anti_windup_raw \
           update_count_raw freq_error_raw lock_threshold_raw lock_samples_raw ref_src_raw \
           magic_raw} $snapshot break
  set epoch [word32 $pi_epoch]
  set magic [word32 $magic_raw]
  if {!$pi_valid || $epoch < 1 || ($epoch & 1) || $magic != 1} {
    set_pi_math_failure PI_MATH_HEADER_FAIL PI_TRACE_HEADER \
      [format "pi_valid=%s epoch=%s magic=%s" $pi_valid $epoch $magic]
    return 0
  }
  set before [signed64_words $before_lo $before_hi]
  set i_new [signed64_words $i_new_lo $i_new_hi]
  set after [signed64_words $after_lo $after_hi]
  set prop [signed64_words $prop_lo $prop_hi]
  set preround [signed64_words $preround_lo $preround_hi]
  set tag [signed32 $tag_raw]
  set adder [signed32 $p_adder]
  set setpoint [signed32 $p_setpoint]
  set raw_error [signed32 $raw_error_raw]
  set ld_error [signed32 $ld_error_raw]
  set lock_state [word32 $lock_state_raw]
  set unclamped [signed32 $unclamped_raw]
  set y_min [signed32 $y_min_raw]
  set y_max [signed32 $y_max_raw]
  set side [signed32 $side_raw]
  set final_output [signed32 $final_raw]
  set x [signed32 $x_raw]
  set kp [signed32 $kp_raw]
  set ki [signed32 $ki_raw]
  set shift [signed32 $shift_raw]
  set bias [signed32 $bias_raw]
  set anti_windup [signed32 $anti_windup_raw]
  set update_count [word32 $update_count_raw]
  set freq_error [signed32 $freq_error_raw]
  set lock_threshold [signed32 $lock_threshold_raw]
  set lock_samples [signed32 $lock_samples_raw]
  set ref_src [signed32 $ref_src_raw]

  if {$kp != $PI_KP || $ki != $PI_KI || $shift != $PI_SHIFT ||
      $bias != $PI_BIAS || $y_min != $PI_Y_MIN || $y_max != $PI_Y_MAX ||
      $anti_windup != 1 || $lock_threshold != 200 || $lock_samples != 10000} {
    set_pi_math_failure PI_MATH_CONSTANT_FAIL PI_CONSTANTS \
      [format "kp=%s ki=%s shift=%s bias=%s ymin=%s ymax=%s anti=%s threshold=%s samples=%s" \
        $kp $ki $shift $bias $y_min $y_max $anti_windup $lock_threshold $lock_samples]
    return 0
  }

  set invalid_fields [list \
    PI_INTEGRATOR_BEFORE $before \
    PI_I_NEW $i_new \
    PI_INTEGRATOR_AFTER $after \
    PI_PROP_TERM $prop \
    PI_Y_PREROUND $preround \
    PI_TAG_RAW $tag \
    PI_P_ADDER $adder \
    PI_P_SETPOINT $setpoint \
    PI_RAW_ERROR $raw_error \
    PI_LD_ERROR $ld_error \
    PI_HELPER_STATE $lock_state \
    PI_UNCLAMPED_OUTPUT $unclamped \
    PI_Y_MIN $y_min \
    PI_Y_MAX $y_max \
    PI_CLAMP_SIDE $side \
    PI_CLAMPED_OUTPUT $final_output \
    PI_X $x \
    PI_KP $kp \
    PI_KI $ki \
    PI_SHIFT $shift \
    PI_BIAS $bias \
    PI_ANTI_WINDUP $anti_windup \
    PI_UPDATE_COUNT $update_count \
    PI_FREQ_ERROR $freq_error \
    PI_LOCK_THRESHOLD $lock_threshold \
    PI_LOCK_SAMPLES $lock_samples \
    PI_REF_SRC $ref_src]
  foreach {field value} $invalid_fields {
    if {$value eq "INVALID" || ($field eq "PI_HELPER_STATE" && $value < 0) ||
        ($field eq "PI_UPDATE_COUNT" && $value < 0)} {
      set_pi_math_failure PI_MATH_HEADER_FAIL $field INVALID_FIELD
      return 0
    }
  }

  if {$tag + $adder - $setpoint != $raw_error} {
    set_pi_math_failure PI_MATH_RAW_ERROR_FAIL PI_RAW_ERROR \
      [format "expected=%s actual=%s" [expr {$tag + $adder - $setpoint}] $raw_error]
    return 0
  }
  set expected_ld_error $raw_error
  if {$expected_ld_error < -150000} { set expected_ld_error -150000 }
  if {$expected_ld_error > 150000} { set expected_ld_error 150000 }
  if {$ld_error != $expected_ld_error} {
    set_pi_math_failure PI_MATH_RAW_ERROR_FAIL PI_LD_ERROR \
      [format "expected=%s actual=%s" $expected_ld_error $ld_error]
    return 0
  }

  set expected_prop [expr {$x * $kp}]
  set expected_i_new [expr {$before + $ki * $ld_error}]
  set expected_preround [expr {$expected_i_new + $expected_prop + (1 << ($shift - 1))}]
  set expected_unclamped [expr {($expected_preround >> $shift) + $bias}]
  set expected_clamped $expected_unclamped
  set expected_side 0
  if {$expected_clamped < $y_min} {
    set expected_clamped $y_min
    set expected_side -1
  } elseif {$expected_clamped > $y_max} {
    set expected_clamped $y_max
    set expected_side 1
  }
  set expected_after $expected_i_new
  if {$expected_side == -1 && !($anti_windup && $expected_i_new > $before)} {
    set expected_after $before
  } elseif {$expected_side == 1 && !($anti_windup && $expected_i_new < $before)} {
    set expected_after $before
  }

  if {$i_new != $expected_i_new} {
    set_pi_math_failure PI_MATH_I_NEW_FAIL PI_I_NEW \
      [format "expected=%s actual=%s" $expected_i_new $i_new]
    return 0
  }
  if {$after != $expected_after} {
    set_pi_math_failure PI_MATH_INTEGRATOR_FAIL PI_INTEGRATOR_AFTER \
      [format "expected=%s actual=%s" $expected_after $after]
    return 0
  }
  if {$prop != $expected_prop} {
    set_pi_math_failure PI_MATH_PROP_FAIL PI_PROP_TERM \
      [format "expected=%s actual=%s x=%s kp=%s" $expected_prop $prop $x $kp]
    return 0
  }
  if {$preround != $expected_preround} {
    set_pi_math_failure PI_MATH_PREROUND_FAIL PI_Y_PREROUND \
      [format "expected=%s actual=%s" $expected_preround $preround]
    return 0
  }
  if {$unclamped != $expected_unclamped || $final_output != $expected_clamped} {
    set_pi_math_failure PI_MATH_OUTPUT_FAIL PI_OUTPUT \
      [format "expected_unclamped=%s actual_unclamped=%s expected_output=%s actual_output=%s" \
        $expected_unclamped $unclamped $expected_clamped $final_output]
    return 0
  }
  if {$side != $expected_side} {
    set_pi_math_failure PI_MATH_CLAMP_FAIL PI_CLAMP_SIDE \
      [format "expected=%s actual=%s" $expected_side $side]
    return 0
  }
  set ::snapshot_last_primary_reason NONE
  set ::snapshot_last_failed_field NONE
  return 1
}

proc read_pi_snapshot_checked {hardware_name} {
  set request_seq [next_snapshot_seq $hardware_name]
  set ::snapshot_request_seq_final($hardware_name) $request_seq
  set snapshot [read_pi_snapshot $hardware_name $request_seq]
  if {[lindex $snapshot 0] && [pi_snapshot_math_valid $snapshot]} {
    return [list 1 0 {*}$snapshot]
  }
  if {[lindex $snapshot 0]} {
    puts [format "PI_MATH_REJECT board=%s request_seq=%d reason=%s" \
      $hardware_name $request_seq $::pi_math_last_reason]
  }
  return [list 0 1 {*}$snapshot]
}

proc read_pi_snapshot_invalid {} {
  return [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID]
}

proc initialize_board {hardware_name} {
  set ::sample_count($hardware_name) 0
  set ::valid_frame_count($hardware_name) 0
  set ::invalid_frame_count($hardware_name) 0
  set ::pi_present_count($hardware_name) 0
  set ::pi_snapshot_reject_count($hardware_name) 0
  set ::pi_accounting_fail_count($hardware_name) 0
  set ::pi_output_mismatch_count($hardware_name) 0
  set ::anti_windup_violation_count($hardware_name) 0
  set ::low_rail_count($hardware_name) 0
  set ::high_rail_count($hardware_name) 0
  set ::zero_crossing_count($hardware_name) 0
  set ::physical_position_mismatch_count($hardware_name) 0
  set ::first_high_rail_sample($hardware_name) NONE
  set ::first_low_rail_sample($hardware_name) NONE
  set ::first_zero_crossing_sample($hardware_name) NONE
  set ::first_low_leave_sample($hardware_name) NONE
  set ::high_seen($hardware_name) 0
  set ::high_to_low_seen($hardware_name) 0
  set ::zero_crossing_seen($hardware_name) 0
  set ::low_after_zero_seen($hardware_name) 0
  set ::cycle_complete($hardware_name) 0
  set ::previous_freq_error($hardware_name) INVALID
  set ::previous_pi_epoch($hardware_name) INVALID
  set ::previous_helper_count($hardware_name) INVALID
  set ::previous_helper_error_in_band($hardware_name) INVALID
  set ::helper_epoch_reset_count($hardware_name) 0
  set ::helper_error_count($hardware_name) 0
  set ::helper_error_sum($hardware_name) 0
  set ::helper_error_sumsq($hardware_name) 0.0
  set ::helper_error_max_abs($hardware_name) 0
  set ::helper_error_in_band_count($hardware_name) 0
  set ::raw_error_count($hardware_name) 0
  set ::raw_error_positive_count($hardware_name) 0
  set ::raw_error_sum($hardware_name) 0
  set ::raw_error_min($hardware_name) INVALID
  set ::raw_error_max($hardware_name) INVALID
  set ::unclamped_below_min_count($hardware_name) 0
  set ::freq_error_count($hardware_name) 0
  set ::freq_error_sum($hardware_name) 0
  set ::freq_error_sumsq($hardware_name) 0.0
  set ::freq_error_max_abs($hardware_name) 0
  set ::helper_lock_max($hardware_name) 0
  set ::helper_lock_rise_events($hardware_name) 0
  set ::helper_lock_fall_events($hardware_name) 0
  set ::error_band_exit_events($hardware_name) 0
  set ::spll_init_first($hardware_name) INVALID
  set ::spll_init_final($hardware_name) INVALID
  set ::clear_dacs_first($hardware_name) INVALID
  set ::clear_dacs_final($hardware_name) INVALID
  set ::spll_delock_first($hardware_name) INVALID
  set ::spll_delock_final($hardware_name) INVALID
  set ::normal_req_first($hardware_name) INVALID
  set ::normal_req_final($hardware_name) INVALID
  set ::normal_completed_first($hardware_name) INVALID
  set ::normal_completed_final($hardware_name) INVALID
  set ::dco_step_first($hardware_name) INVALID
  set ::dco_step_final($hardware_name) INVALID
  set ::forced_completed_first($hardware_name) INVALID
  set ::forced_completed_final($hardware_name) INVALID
  set ::bootstrap_completed_first($hardware_name) INVALID
  set ::bootstrap_completed_final($hardware_name) INVALID
  set ::bootstrap_done_final($hardware_name) INVALID
  set ::main_enabled_first($hardware_name) INVALID
  set ::main_enabled_final($hardware_name) INVALID
  set ::main_freq_locked_first($hardware_name) INVALID
  set ::main_freq_locked_final($hardware_name) INVALID
  set ::main_phase_locked_first($hardware_name) INVALID
  set ::main_phase_locked_final($hardware_name) INVALID
  set ::main_locked_first($hardware_name) INVALID
  set ::main_locked_final($hardware_name) INVALID
  set ::pstat_locked_first($hardware_name) INVALID
  set ::pstat_locked_final($hardware_name) INVALID
  set ::tag_valid_first($hardware_name) INVALID
  set ::tag_valid_final($hardware_name) INVALID
  set ::normal_completed_first($hardware_name) INVALID
  set ::normal_completed_final($hardware_name) INVALID
  set ::position_applied_final($hardware_name) INVALID
  set ::position_target_final($hardware_name) INVALID
  set ::helper_error_final($hardware_name) INVALID
  set ::helper_output_final($hardware_name) INVALID
  set ::helper_locked_final($hardware_name) INVALID
  set ::helper_count_final($hardware_name) INVALID
  set ::pi_epoch_final($hardware_name) INVALID
  set ::pi_before_final($hardware_name) INVALID
  set ::pi_i_new_final($hardware_name) INVALID
  set ::pi_after_final($hardware_name) INVALID
  set ::pi_unclamped_final($hardware_name) INVALID
  set ::pi_clamped_final($hardware_name) INVALID
  set ::pi_side_final($hardware_name) INVALID
  set ::pi_raw_error_final($hardware_name) INVALID
  set ::pi_ld_error_final($hardware_name) INVALID
  set ::pi_prop_final($hardware_name) INVALID
  set ::pi_preround_final($hardware_name) INVALID
  set ::pi_y_min_final($hardware_name) INVALID
  set ::pi_y_max_final($hardware_name) INVALID
  set ::reset_first($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::reset_final($hardware_name) [list INVALID INVALID INVALID INVALID]
  set ::elapsed_final($hardware_name) 0
  set ::snapshot_req_first($hardware_name) INVALID
  set ::snapshot_req_final($hardware_name) INVALID
  set ::snapshot_ack_first($hardware_name) INVALID
  set ::snapshot_ack_final($hardware_name) INVALID
  set ::snapshot_ack_seq_final($hardware_name) INVALID
  set ::snapshot_ack_mismatch_count($hardware_name) 0
  set ::snapshot_ack_timeout_count($hardware_name) 0
  set ::snapshot_epoch_generation_mismatch_count($hardware_name) 0
  set ::snapshot_epoch_changed_count($hardware_name) 0
  set ::snapshot_bank_commit_first($hardware_name) INVALID
  set ::snapshot_bank_commit_final($hardware_name) INVALID
  set ::snapshot_overwrite_first($hardware_name) INVALID
  set ::snapshot_overwrite_final($hardware_name) INVALID
  set ::snapshot_request_seq_final($hardware_name) INVALID
  set ::snapshot_last_req_seq_final($hardware_name) INVALID
  set ::snapshot_bank_seq_final($hardware_name) INVALID
  foreach reason $::primary_reject_reason_order {
    set key [format "%s|%s" $hardware_name $reason]
    set ::primary_reject_count($key) 0
  }
  set ::snapshot_last_primary_reason OTHER
  set ::snapshot_last_failed_field NONE

  # Capture the transport baseline before sample 1 issues its first request.
  # This makes the report deltas cover exactly all requested samples.
  set ::snapshot_req_first($hardware_name) [word32 [wb_read $hardware_name 0x00100B2C]]
  set ::snapshot_ack_first($hardware_name) [word32 [wb_read $hardware_name 0x00100B30]]
  set ::snapshot_bank_commit_first($hardware_name) [word32 [wb_read $hardware_name 0x00100B34]]
  set ::snapshot_overwrite_first($hardware_name) [word32 [wb_read $hardware_name 0x00100B38]]
}

proc emit_sample {hardware_name sample elapsed_ms} {
  global PI_KP PI_KI PI_SHIFT PI_BIAS PI_Y_MIN PI_Y_MAX
  foreach {position_raw accounting_raw} [read_stable_position_pair] break
  set position_word [word64 $position_raw]
  set accounting_word [word64 $accounting_raw]
  set position_target INVALID
  set position_applied INVALID
  set normal_completed INVALID
  set normal_finc INVALID
  set normal_fdec INVALID
  if {$position_word >= 0} {
    set position_target [expr {$position_word & 0xffff}]
    set position_applied [expr {($position_word >> 16) & 0xffff}]
    set normal_finc [expr {($position_word >> 32) & 0xffff}]
    set normal_fdec [expr {($position_word >> 48) & 0xffff}]
  }
  if {$accounting_word >= 0} {
    set normal_completed [expr {$accounting_word & 0xffff}]
    set dco_step [expr {($accounting_word >> 16) & 0xffff}]
    set bootstrap_completed_counter [expr {($accounting_word >> 32) & 0xffff}]
  } else {
    set dco_step INVALID
    set bootstrap_completed_counter INVALID
  }
  set tracker_word [word64 [probe_read 39]]
  set burst_wide_word [word64 [probe_read 41]]
  set bootstrap_word [word64 [probe_read 42]]
  if {$tracker_word >= 0} {
    set normal_req [expr {($tracker_word >> 32) & 0xffff}]
  } else {
    set normal_req INVALID
  }
  if {$burst_wide_word >= 0} {
    set forced_completed [expr {($burst_wide_word >> 32) & 0xffff}]
  } else {
    set forced_completed INVALID
  }
  if {$bootstrap_word >= 0} {
    set bootstrap_done [expr {($bootstrap_word >> 33) & 1}]
  } else {
    set bootstrap_done INVALID
  }
  set entry_probe [probe_read 26]
  set reset_probe [probe_read 27]
  set entry_generation [probe_high32 $entry_probe]
  set cpu_reset [probe_field32 $reset_probe 16 8]
  set wr_reset [probe_field32 $reset_probe 24 8]
  set si_drop [probe_field32 $reset_probe 40 8]

  set checked_snapshot [read_pi_snapshot_checked $hardware_name]
  set checked_valid [lindex $checked_snapshot 0]
  set checked_rejects [lindex $checked_snapshot 1]
  incr ::pi_snapshot_reject_count($hardware_name) $checked_rejects
  set raw_snapshot [lrange $checked_snapshot 2 end]
  set snapshot_req_count [word32 [wb_read $hardware_name 0x00100B2C]]
  set snapshot_ack_count [word32 [wb_read $hardware_name 0x00100B30]]
  set snapshot_ack_seq [word32 [wb_read $hardware_name 0x00100B28]]
  set snapshot_bank_commit_count [word32 [wb_read $hardware_name 0x00100B34]]
  set snapshot_overwrite_count [word32 [wb_read $hardware_name 0x00100B38]]
  set snapshot_last_req_seq [word32 [wb_read $hardware_name 0x00100B3C]]
  foreach {pi_valid pi_epoch tag_raw p_adder p_setpoint raw_error_raw ld_error_raw \
           helper_state_raw before_lo before_hi i_new_lo i_new_hi after_lo after_hi \
           prop_lo prop_hi preround_lo preround_hi unclamped_raw y_min_raw y_max_raw \
           side_raw final_raw x_raw kp_raw ki_raw shift_raw bias_raw anti_windup_raw \
           update_count_raw freq_error_raw lock_threshold_raw lock_samples_raw ref_src_raw \
           trace_magic_raw} $raw_snapshot break
  set ctrl_valid $checked_valid
  set pi_before [signed64_words $before_lo $before_hi]
  set pi_i_new [signed64_words $i_new_lo $i_new_hi]
  set pi_after [signed64_words $after_lo $after_hi]
  set pi_prop [signed64_words $prop_lo $prop_hi]
  set pi_preround [signed64_words $preround_lo $preround_hi]
  set pi_tag_raw [signed32 $tag_raw]
  set pi_p_adder [signed32 $p_adder]
  set pi_p_setpoint [signed32 $p_setpoint]
  set pi_raw_error [signed32 $raw_error_raw]
  set pi_ld_error [signed32 $ld_error_raw]
  set pi_unclamped [signed32 $unclamped_raw]
  set pi_y_min [signed32 $y_min_raw]
  set pi_y_max [signed32 $y_max_raw]
  set pi_side [signed32 $side_raw]
  set pi_clamped [signed32 $final_raw]
  set pi_x [signed32 $x_raw]
  set pi_kp [signed32 $kp_raw]
  set pi_ki [signed32 $ki_raw]
  set pi_shift [signed32 $shift_raw]
  set pi_bias [signed32 $bias_raw]
  set pi_anti_windup [signed32 $anti_windup_raw]
  set pi_update_count [word32 $update_count_raw]
  set freq_error [signed32 $freq_error_raw]
  set pi_lock_threshold [signed32 $lock_threshold_raw]
  set pi_lock_samples [signed32 $lock_samples_raw]
  set pi_ref_src [signed32 $ref_src_raw]
  set pi_trace_magic [word32 $trace_magic_raw]
  set helper_error $pi_ld_error
  set helper_output $pi_clamped
  set helper_locked [probe_field32 $helper_state_raw 0 1]
  set helper_count [probe_field32 $helper_state_raw 16 16]
  set tag_valid [signed32 [wb_read $hardware_name 0x00100AF8]]
  if {$tag_valid < 0} { set tag_valid INVALID }
  set spll_init_count [word32 [wb_read $hardware_name 0x00100B44]]
  if {$spll_init_count < 0} { set spll_init_count INVALID }
  set clear_dacs_count [word32 [wb_read $hardware_name 0x00100B48]]
  if {$clear_dacs_count < 0} { set clear_dacs_count INVALID }
  set spll_state [wb_read $hardware_name 0x00100AA0]
  set spll_delock [probe_field32 $spll_state 24 8]
  set main_state [wb_read $hardware_name 0x00100AC4]
  set pstat [wb_read $hardware_name 0x00100A0C]
  set main_enabled [probe_field32 $main_state 0 1]
  set main_locked [probe_field32 $main_state 1 1]
  set main_freq_locked [probe_field32 $main_state 2 1]
  set main_phase_locked [probe_field32 $main_state 3 1]
  set pstat_locked [probe_field32 $pstat 1 1]

  set position_context_ok 1
  set position_context_field NONE
  if {$position_applied eq "INVALID" || $normal_finc eq "INVALID" ||
      $normal_fdec eq "INVALID"} {
    set position_context_ok 0
    set position_context_field POSITION_APPLIED_OR_FIN_COUNT
  } else {
    set expected_applied [expr {(5 + 64 * ($normal_finc - $normal_fdec)) & 0xffff}]
    if {$position_applied != $expected_applied} {
      set position_context_ok 0
      set position_context_field POSITION_APPLIED
      incr ::physical_position_mismatch_count($hardware_name)
    }
  }

  if {$sample == 1} {
    set ::tag_valid_first($hardware_name) $tag_valid
    set ::normal_completed_first($hardware_name) $normal_completed
    set ::normal_req_first($hardware_name) $normal_req
    set ::dco_step_first($hardware_name) $dco_step
    set ::forced_completed_first($hardware_name) $forced_completed
    set ::bootstrap_completed_first($hardware_name) $bootstrap_completed_counter
    set ::bootstrap_done_final($hardware_name) $bootstrap_done
    set ::spll_init_first($hardware_name) $spll_init_count
    set ::clear_dacs_first($hardware_name) $clear_dacs_count
    set ::spll_delock_first($hardware_name) $spll_delock
    set ::main_enabled_first($hardware_name) $main_enabled
    set ::main_freq_locked_first($hardware_name) $main_freq_locked
    set ::main_phase_locked_first($hardware_name) $main_phase_locked
    set ::main_locked_first($hardware_name) $main_locked
    set ::pstat_locked_first($hardware_name) $pstat_locked
    set ::reset_first($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]
    set ::snapshot_req_first($hardware_name) $snapshot_req_count
    set ::snapshot_ack_first($hardware_name) $snapshot_ack_count
    set ::snapshot_bank_commit_first($hardware_name) $snapshot_bank_commit_count
    set ::snapshot_overwrite_first($hardware_name) $snapshot_overwrite_count
  }
  incr ::sample_count($hardware_name)
  set ::elapsed_final($hardware_name) $elapsed_ms
  set ::tag_valid_final($hardware_name) $tag_valid
  set ::normal_req_final($hardware_name) $normal_req
  set ::normal_completed_final($hardware_name) $normal_completed
  set ::dco_step_final($hardware_name) $dco_step
  set ::forced_completed_final($hardware_name) $forced_completed
  set ::bootstrap_completed_final($hardware_name) $bootstrap_completed_counter
  set ::bootstrap_done_final($hardware_name) $bootstrap_done
  set ::spll_init_final($hardware_name) $spll_init_count
  set ::clear_dacs_final($hardware_name) $clear_dacs_count
  set ::spll_delock_final($hardware_name) $spll_delock
  set ::main_enabled_final($hardware_name) $main_enabled
  set ::main_freq_locked_final($hardware_name) $main_freq_locked
  set ::main_phase_locked_final($hardware_name) $main_phase_locked
  set ::main_locked_final($hardware_name) $main_locked
  set ::pstat_locked_final($hardware_name) $pstat_locked
  set ::snapshot_req_final($hardware_name) $snapshot_req_count
  set ::snapshot_ack_final($hardware_name) $snapshot_ack_count
  set ::snapshot_ack_seq_final($hardware_name) $snapshot_ack_seq
  set ::snapshot_bank_commit_final($hardware_name) $snapshot_bank_commit_count
  set ::snapshot_overwrite_final($hardware_name) $snapshot_overwrite_count
  set ::snapshot_last_req_seq_final($hardware_name) $snapshot_last_req_seq
  set ::position_target_final($hardware_name) $position_target
  set ::position_applied_final($hardware_name) $position_applied
  set ::helper_error_final($hardware_name) $helper_error
  set ::helper_output_final($hardware_name) $helper_output
  set ::helper_locked_final($hardware_name) $helper_locked
  set ::helper_count_final($hardware_name) $helper_count
  set ::pi_epoch_final($hardware_name) $pi_epoch
  set ::pi_before_final($hardware_name) $pi_before
  set ::pi_i_new_final($hardware_name) $pi_i_new
  set ::pi_after_final($hardware_name) $pi_after
  set ::pi_unclamped_final($hardware_name) $pi_unclamped
  set ::pi_clamped_final($hardware_name) $pi_clamped
  set ::pi_side_final($hardware_name) $pi_side
  set ::pi_raw_error_final($hardware_name) $pi_raw_error
  set ::pi_ld_error_final($hardware_name) $pi_ld_error
  set ::pi_prop_final($hardware_name) $pi_prop
  set ::pi_preround_final($hardware_name) $pi_preround
  set ::pi_y_min_final($hardware_name) $pi_y_min
  set ::pi_y_max_final($hardware_name) $pi_y_max
  set ::reset_final($hardware_name) [list $entry_generation $cpu_reset $wr_reset $si_drop]

  set valid [expr {$ctrl_valid && $helper_error ne "INVALID" && $position_context_ok}]
  set primary_reason $::snapshot_last_primary_reason
  set primary_field $::snapshot_last_failed_field
  if {$ctrl_valid && $helper_error ne "INVALID" && !$position_context_ok} {
    set primary_reason POSITION_CONTEXT_FAIL
    set primary_field $position_context_field
  }
  if {!$valid && ($primary_reason eq "" || $primary_reason eq "NONE") &&
      $helper_error eq "INVALID"} {
    set primary_reason PAYLOAD_READ_INVALID
    set primary_field PI_LD_ERROR
  }
  record_primary_reject $hardware_name $sample $::snapshot_request_seq_final($hardware_name) \
    $valid $primary_reason $primary_field
  if {$valid} {
    incr ::valid_frame_count($hardware_name)
  } else {
    incr ::invalid_frame_count($hardware_name)
  }

  set pi_present [expr {$valid && $pi_epoch ne "INVALID" && $pi_epoch != 0}]
  if {$pi_present} {
    incr ::pi_present_count($hardware_name)
    if {$::previous_pi_epoch($hardware_name) ne "INVALID" &&
        $pi_epoch < $::previous_pi_epoch($hardware_name)} {
      incr ::helper_epoch_reset_count($hardware_name)
    }
    set ::previous_pi_epoch($hardware_name) $pi_epoch

    set abs_helper_error [expr {abs($helper_error)}]
    incr ::helper_error_count($hardware_name)
    set ::helper_error_sum($hardware_name) [expr {$::helper_error_sum($hardware_name) + $helper_error}]
    set ::helper_error_sumsq($hardware_name) [expr {$::helper_error_sumsq($hardware_name) + double($helper_error) * double($helper_error)}]
    if {$abs_helper_error > $::helper_error_max_abs($hardware_name)} {
      set ::helper_error_max_abs($hardware_name) $abs_helper_error
    }
    set helper_error_in_band [expr {$abs_helper_error <= 200}]
    if {$helper_error_in_band} {
      incr ::helper_error_in_band_count($hardware_name)
    }
    if {$::previous_helper_error_in_band($hardware_name) ne "INVALID" &&
        $::previous_helper_error_in_band($hardware_name) && !$helper_error_in_band} {
      incr ::error_band_exit_events($hardware_name)
    }
    set ::previous_helper_error_in_band($hardware_name) $helper_error_in_band

    if {$pi_raw_error ne "INVALID"} {
      incr ::raw_error_count($hardware_name)
      if {$pi_raw_error > 0} {
        incr ::raw_error_positive_count($hardware_name)
      }
      set ::raw_error_sum($hardware_name) [expr {$::raw_error_sum($hardware_name) + $pi_raw_error}]
      if {$::raw_error_min($hardware_name) eq "INVALID" ||
          $pi_raw_error < $::raw_error_min($hardware_name)} {
        set ::raw_error_min($hardware_name) $pi_raw_error
      }
      if {$::raw_error_max($hardware_name) eq "INVALID" ||
          $pi_raw_error > $::raw_error_max($hardware_name)} {
        set ::raw_error_max($hardware_name) $pi_raw_error
      }
    }
    if {$pi_unclamped ne "INVALID" && $pi_y_min ne "INVALID" &&
        $pi_unclamped < $pi_y_min} {
      incr ::unclamped_below_min_count($hardware_name)
    }

    if {$freq_error ne "INVALID"} {
      incr ::freq_error_count($hardware_name)
      set ::freq_error_sum($hardware_name) [expr {$::freq_error_sum($hardware_name) + $freq_error}]
      set ::freq_error_sumsq($hardware_name) [expr {$::freq_error_sumsq($hardware_name) + double($freq_error) * double($freq_error)}]
      set abs_freq_error [expr {abs($freq_error)}]
      if {$abs_freq_error > $::freq_error_max_abs($hardware_name)} {
        set ::freq_error_max_abs($hardware_name) $abs_freq_error
      }
    }

    if {$helper_count ne "INVALID"} {
      if {$helper_count > $::helper_lock_max($hardware_name)} {
        set ::helper_lock_max($hardware_name) $helper_count
      }
      if {$::previous_helper_count($hardware_name) ne "INVALID"} {
        if {$helper_count > $::previous_helper_count($hardware_name)} {
          incr ::helper_lock_rise_events($hardware_name)
        } elseif {$helper_count < $::previous_helper_count($hardware_name)} {
          incr ::helper_lock_fall_events($hardware_name)
        }
      }
      set ::previous_helper_count($hardware_name) $helper_count
    }

    set expected_i_new [expr {$pi_before + $PI_KI * $helper_error}]
    set expected_unclamped [expr {(($expected_i_new + $PI_KP * $helper_error + (1 << ($PI_SHIFT - 1))) >> $PI_SHIFT) + $PI_BIAS}]
    set expected_clamped $expected_unclamped
    set expected_side 0
    if {$expected_clamped < $PI_Y_MIN} {
      set expected_clamped $PI_Y_MIN
      set expected_side -1
    } elseif {$expected_clamped > $PI_Y_MAX} {
      set expected_clamped $PI_Y_MAX
      set expected_side 1
    }
    set expected_after $expected_i_new
    if {$expected_side == -1 && $expected_i_new <= $pi_before} {
      set expected_after $pi_before
    } elseif {$expected_side == 1 && $expected_i_new >= $pi_before} {
      set expected_after $pi_before
    }
    if {$pi_i_new != $expected_i_new || $pi_after != $expected_after ||
        $pi_unclamped != $expected_unclamped || $pi_clamped != $expected_clamped ||
        $pi_side != $expected_side} {
      incr ::pi_accounting_fail_count($hardware_name)
    }
    if {$pi_clamped != $helper_output} {
      incr ::pi_output_mismatch_count($hardware_name)
    }
    if {$pi_side == -1 && $pi_unclamped < $PI_Y_MIN && $helper_error > 0 &&
        $pi_after != $pi_before} {
      incr ::anti_windup_violation_count($hardware_name)
    }
    if {$pi_side == 1 && $pi_unclamped > $PI_Y_MAX && $helper_error < 0 &&
        $pi_after != $pi_before} {
      incr ::anti_windup_violation_count($hardware_name)
    }
    if {$pi_side == -1 && $pi_clamped == $PI_Y_MIN} {
      incr ::low_rail_count($hardware_name)
      if {$::first_low_rail_sample($hardware_name) eq "NONE"} {
        set ::first_low_rail_sample($hardware_name) $sample
      }
      if {$::high_seen($hardware_name)} {
        set ::high_to_low_seen($hardware_name) 1
      }
      if {$::zero_crossing_seen($hardware_name)} {
        set ::low_after_zero_seen($hardware_name) 1
      }
    }
    if {$pi_side == 1 && $pi_clamped == $PI_Y_MAX} {
      incr ::high_rail_count($hardware_name)
      set ::high_seen($hardware_name) 1
      if {$::first_high_rail_sample($hardware_name) eq "NONE"} {
        set ::first_high_rail_sample($hardware_name) $sample
      }
    }
    if {$freq_error ne "INVALID" && $::previous_freq_error($hardware_name) ne "INVALID" &&
        $::previous_freq_error($hardware_name) > 0 && $freq_error <= 0} {
      incr ::zero_crossing_count($hardware_name)
      set ::zero_crossing_seen($hardware_name) 1
      if {$::first_zero_crossing_sample($hardware_name) eq "NONE"} {
        set ::first_zero_crossing_sample($hardware_name) $sample
      }
    }
    if {$::low_after_zero_seen($hardware_name) &&
        !($pi_side == -1 && $pi_clamped == $PI_Y_MIN) &&
        $::first_low_leave_sample($hardware_name) eq "NONE"} {
      set ::first_low_leave_sample($hardware_name) $sample
    }
    if {$::high_to_low_seen($hardware_name) && $::zero_crossing_seen($hardware_name) &&
        $::low_after_zero_seen($hardware_name) &&
        $::first_low_leave_sample($hardware_name) ne "NONE"} {
      set ::cycle_complete($hardware_name) 1
    }
    set ::previous_freq_error($hardware_name) $freq_error
  }

  puts [format "STEP5_PI_SAMPLE board=%s sample=%d elapsed_ms=%d FRAME_VALID=%d PI_TRACE_PRESENT=%d PI_SNAPSHOT_REJECTS=%d PI_EPOCH=%s TAG_RAW=%s P_ADDER=%s P_SETPOINT=%s RAW_ERROR=%s LD_ERROR=%s PI_INTEGRATOR_BEFORE=%s PI_I_NEW=%s PI_INTEGRATOR_AFTER=%s PI_PROP_TERM=%s PI_Y_PREROUND=%s PI_UNCLAMPED_OUTPUT=%s PI_Y_MIN=%s PI_Y_MAX=%s PI_CLAMPED_OUTPUT=%s PI_CLAMP_SIDE=%s HELPER_ERROR=%s HELPER_OUTPUT=%s FREQ_ERROR=%s TARGET_CODE=%s APPLIED_CODE=%s NORMAL_REQ=%s NORMAL_COMPLETED=%s NORMAL_FINC=%s NORMAL_FDEC=%s DCO_STEP=%s FORCED_COMPLETED=%s BOOTSTRAP_COMPLETED=%s BOOTSTRAP_DONE=%s SPLL_INIT_COUNT=%s CLEAR_DACS_COUNT=%s SPLL_DELOCK_COUNT=%s MAIN_ENABLED=%s MAIN_FREQ_LOCKED=%s MAIN_PHASE_LOCKED=%s MAIN_LOCKED=%s PSTAT_LOCKED=%s HELPER_LOCKED=%s HELPER_LOCK_COUNT=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
    $hardware_name $sample $elapsed_ms $valid $pi_present $checked_rejects $pi_epoch \
    $pi_tag_raw $pi_p_adder $pi_p_setpoint $pi_raw_error $pi_ld_error $pi_before $pi_i_new $pi_after $pi_prop $pi_preround \
    $pi_unclamped $pi_y_min $pi_y_max $pi_clamped $pi_side $helper_error $helper_output $freq_error \
    $position_target $position_applied $normal_req $normal_completed $normal_finc $normal_fdec $dco_step $forced_completed \
    $bootstrap_completed_counter $bootstrap_done $spll_init_count $clear_dacs_count $spll_delock $main_enabled $main_freq_locked $main_phase_locked $main_locked $pstat_locked $helper_locked $helper_count \
    $entry_generation $cpu_reset $wr_reset $si_drop]
  puts [format "STEP5_ATOMIC_SNAPSHOT_SAMPLE board=%s sample=%d REQUEST_SEQ=%s LAST_REQ_SEQ=%s BANK_SEQ=%s SNAPSHOT_ACK_SEQ=%s SNAPSHOT_REQ_COUNT=%s SNAPSHOT_BANK_COMMIT_COUNT=%s SNAPSHOT_ACK_COUNT=%s SNAPSHOT_OVERWRITE_COUNT=%s ACK_TIMEOUT=%d ACK_MISMATCH=%d EPOCH_GENERATION_MISMATCH=%d EPOCH_CHANGED_DURING_READ=%d" \
    $hardware_name $sample $::snapshot_request_seq_final($hardware_name) $snapshot_last_req_seq \
    $::snapshot_bank_seq_final($hardware_name) $snapshot_ack_seq $snapshot_req_count \
    $snapshot_bank_commit_count $snapshot_ack_count $snapshot_overwrite_count \
    $::snapshot_ack_timeout_count($hardware_name) \
    $::snapshot_ack_mismatch_count($hardware_name) \
    $::snapshot_epoch_generation_mismatch_count($hardware_name) \
    $::snapshot_epoch_changed_count($hardware_name)]
  flush stdout
}

proc emit_summary {hardware_name} {
  global PI_KP PI_KI PI_SHIFT PI_BIAS PI_Y_MIN PI_Y_MAX
  set valid $::valid_frame_count($hardware_name)
  set invalid $::invalid_frame_count($hardware_name)
  set pi_count $::pi_present_count($hardware_name)
  set rail_fraction [expr {$pi_count > 0 ? 100.0 * $::low_rail_count($hardware_name) / double($pi_count) : 0.0}]
  set high_fraction [expr {$pi_count > 0 ? 100.0 * $::high_rail_count($hardware_name) / double($pi_count) : 0.0}]
  set no_rail_fraction [expr {$pi_count > 0 ? 100.0 - $rail_fraction - $high_fraction : 0.0}]
  set pi_fraction [expr {$::sample_count($hardware_name) > 0 ? 100.0 * $::pi_present_count($hardware_name) / double($::sample_count($hardware_name)) : 0.0}]
  foreach {gen0 cpu0 wr0 si0} $::reset_first($hardware_name) break
  foreach {gen1 cpu1 wr1 si1} $::reset_final($hardware_name) break
  set gen_delta [expr {($gen0 ne "INVALID" && $gen1 ne "INVALID") ? ($gen1 - $gen0) : "INVALID"}]
  set cpu_delta [expr {($cpu0 ne "INVALID" && $cpu1 ne "INVALID") ? ($cpu1 - $cpu0) : "INVALID"}]
  set wr_delta [expr {($wr0 ne "INVALID" && $wr1 ne "INVALID") ? ($wr1 - $wr0) : "INVALID"}]
  set si_delta [expr {($si0 ne "INVALID" && $si1 ne "INVALID") ? ($si1 - $si0) : "INVALID"}]
  set error_count $::helper_error_count($hardware_name)
  if {$error_count > 0} {
    set helper_error_mean [expr {$::helper_error_sum($hardware_name) / double($error_count)}]
    set helper_error_rms [expr {sqrt($::helper_error_sumsq($hardware_name) / double($error_count))}]
    set helper_error_fraction [expr {100.0 * $::helper_error_in_band_count($hardware_name) / double($error_count)}]
  } else {
    set helper_error_mean INVALID
    set helper_error_rms INVALID
    set helper_error_fraction INVALID
  }
  set freq_count $::freq_error_count($hardware_name)
  if {$freq_count > 0} {
    set freq_error_mean [expr {$::freq_error_sum($hardware_name) / double($freq_count)}]
    set freq_error_rms [expr {sqrt($::freq_error_sumsq($hardware_name) / double($freq_count))}]
  } else {
    set freq_error_mean INVALID
    set freq_error_rms INVALID
  }
  set raw_count $::raw_error_count($hardware_name)
  if {$raw_count > 0} {
    set raw_error_mean [expr {$::raw_error_sum($hardware_name) / double($raw_count)}]
    set raw_error_positive_fraction [expr {100.0 * $::raw_error_positive_count($hardware_name) / double($raw_count)}]
  } else {
    set raw_error_mean INVALID
    set raw_error_positive_fraction INVALID
  }
  set spll_init_delta [counter_delta $::spll_init_first($hardware_name) $::spll_init_final($hardware_name) 32]
  set clear_dacs_delta [counter_delta $::clear_dacs_first($hardware_name) $::clear_dacs_final($hardware_name) 32]
  set normal_req_delta [counter_delta $::normal_req_first($hardware_name) $::normal_req_final($hardware_name) 16]
  set normal_completed_delta [counter_delta $::normal_completed_first($hardware_name) $::normal_completed_final($hardware_name) 16]
  set dco_step_delta [counter_delta $::dco_step_first($hardware_name) $::dco_step_final($hardware_name) 16]
  set forced_completed_delta [counter_delta $::forced_completed_first($hardware_name) $::forced_completed_final($hardware_name) 16]
  set bootstrap_completed_delta [counter_delta $::bootstrap_completed_first($hardware_name) $::bootstrap_completed_final($hardware_name) 16]
  set snapshot_req_delta [counter_delta $::snapshot_req_first($hardware_name) $::snapshot_req_final($hardware_name) 32]
  set snapshot_ack_delta [counter_delta $::snapshot_ack_first($hardware_name) $::snapshot_ack_final($hardware_name) 32]
  set snapshot_bank_commit_delta [counter_delta $::snapshot_bank_commit_first($hardware_name) $::snapshot_bank_commit_final($hardware_name) 32]
  set snapshot_overwrite_delta [counter_delta $::snapshot_overwrite_first($hardware_name) $::snapshot_overwrite_final($hardware_name) 32]
  set transaction_accounting [expr {$normal_req_delta ne "INVALID" && $normal_completed_delta ne "INVALID" &&
    $normal_req_delta == $normal_completed_delta ? "PASS" : "CHECK"}]
  set position_accounting [expr {$::physical_position_mismatch_count($hardware_name) == 0 &&
    $::position_applied_final($hardware_name) ne "INVALID" ? "PASS" : "CHECK"}]
  set measurement_coherence [expr {$::pi_present_count($hardware_name) > 0 &&
    $::pi_accounting_fail_count($hardware_name) == 0 &&
    $::pi_output_mismatch_count($hardware_name) == 0 ? "PASS" : "CHECK"}]
  set reset_stable [expr {$gen_delta ne "INVALID" && $cpu_delta ne "INVALID" &&
    $wr_delta ne "INVALID" && $si_delta ne "INVALID" &&
    $gen_delta == 0 && $cpu_delta == 0 && $wr_delta == 0 && $si_delta == 0 ? "PASS" : "CHECK"}]
  set snapshot_transport_v3 [expr {
    $valid * 100 >= $::sample_count($hardware_name) * 99 &&
    $::invalid_frame_count($hardware_name) * 100 <= $::sample_count($hardware_name) &&
    $pi_count * 100 >= $::sample_count($hardware_name) * 99 &&
    $::snapshot_ack_timeout_count($hardware_name) == 0 &&
    $::snapshot_ack_mismatch_count($hardware_name) == 0 &&
    $::snapshot_epoch_generation_mismatch_count($hardware_name) == 0 &&
    $::snapshot_epoch_changed_count($hardware_name) == 0 &&
    $measurement_coherence eq "PASS" &&
    $position_accounting eq "PASS" &&
    $transaction_accounting eq "PASS" &&
    $reset_stable eq "PASS" ? "PASS" : "FAIL"}]
  if {$error_count == 0} {
    set dynamics_candidate INSUFFICIENT_DATA
  } elseif {$helper_error_fraction < 100.0 &&
            ($::helper_lock_rise_events($hardware_name) > 0 ||
             $::helper_lock_fall_events($hardware_name) > 0 ||
             $::error_band_exit_events($hardware_name) > 0)} {
    set dynamics_candidate UNDERDAMPED_OR_OVERAGGRESSIVE_CANDIDATE
  } elseif {$helper_error_fraction < 100.0 &&
            ($rail_fraction + $high_fraction) >= 90.0} {
    set dynamics_candidate STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT_CANDIDATE
  } else {
    set dynamics_candidate NO_LOCK_DYNAMIC_SIGNATURE
  }
  set low_rail_saturation [expr {$pi_count > 0 &&
    $::low_rail_count($hardware_name) == $pi_count &&
    $raw_count == $pi_count &&
    $::raw_error_positive_count($hardware_name) == $raw_count &&
    $::unclamped_below_min_count($hardware_name) == $pi_count &&
    $::pi_clamped_final($hardware_name) == $PI_Y_MIN ? "CONFIRMED" : "NO"}]
  if {$low_rail_saturation eq "CONFIRMED"} {
    set causality_case A
    set actuator_range_limit "CONFIRMED"
  } elseif {$pi_count > 0 && $raw_count == $pi_count &&
            $error_count == $pi_count &&
            $raw_error_positive_fraction < 100.0 &&
            $::helper_error_max_abs($hardware_name) == 150000} {
    set causality_case B
    set actuator_range_limit NOT_CONFIRMED
  } elseif {$pi_count > 0 && $::low_rail_count($hardware_name) == $pi_count &&
            $::unclamped_below_min_count($hardware_name) == 0} {
    set causality_case C
    set actuator_range_limit NOT_CONFIRMED
  } else {
    set causality_case UNRESOLVED
    set actuator_range_limit NOT_CONFIRMED
  }
  set window_seconds [expr {$::elapsed_final($hardware_name) / 1000.0}]
  puts [format "STEP5_GUARDED_HELPER_DYNAMICS_SUMMARY board=%s SAMPLES=%d VALID_FRAMES=%d INVALID_FRAMES=%d WINDOW_SECONDS=%.3f PI_TRACE_PRESENT=%d PI_TRACE_FRACTION=%.3f PI_SNAPSHOT_REJECTS=%d PI_ACCOUNTING_FAILS=%d PI_OUTPUT_MISMATCH_FAILS=%d ANTI_WINDUP_VIOLATIONS=%d HELPER_ERROR_SAMPLES=%d HELPER_ERROR_MEAN=%s HELPER_ERROR_RMS=%s HELPER_ERROR_MAX_ABS=%s FRACTION_ABS_ERROR_LE_200=%s RAW_ERROR_SAMPLES=%d RAW_ERROR_MEAN=%s RAW_ERROR_MIN=%s RAW_ERROR_MAX=%s RAW_ERROR_POSITIVE_FRACTION=%s UNCLAMPED_BELOW_MIN_SAMPLES=%d LOW_RAIL_SAMPLES=%d LOW_RAIL_FRACTION=%.3f HIGH_RAIL_SAMPLES=%d HIGH_RAIL_FRACTION=%.3f NO_RAIL_FRACTION=%.3f LOCK_COUNT_MAX=%d LOCK_COUNT_FINAL=%s LOCK_COUNT_RISE_EVENTS=%d LOCK_COUNT_FALL_EVENTS=%d ERROR_BAND_EXIT_EVENTS=%d DYNAMICS_CANDIDATE=%s LOW_RAIL_SATURATION=%s ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY=%s CAUSALITY_CASE=%s FREQ_ERROR_SAMPLES=%d FREQ_ERROR_MEAN=%s FREQ_ERROR_RMS=%s FREQ_ERROR_MAX_ABS=%d FREQ_ZERO_CROSSINGS=%d RAIL_TO_RAIL_CYCLE_COMPLETE=%d POSITION_CONTEXT_FAILS=%d MEASUREMENT_COHERENCE=%s POSITION_ACCOUNTING=%s TRANSACTION_ACCOUNTING=%s SPLL_INIT_COUNT_FIRST=%s SPLL_INIT_COUNT_FINAL=%s POST_INITIAL_SPLL_INIT_DELTA=%s CLEAR_DACS_COUNT_FIRST=%s CLEAR_DACS_COUNT_FINAL=%s CLEAR_DACS_DELTA=%s HELPER_EPOCH_RESET_COUNT=%d NORMAL_REQ_DELTA=%s NORMAL_COMPLETED_DELTA=%s DCO_STEP_DELTA=%s FORCED_COMPLETED_DELTA=%s BOOTSTRAP_COMPLETED_FINAL=%s BOOTSTRAP_COMPLETED_DELTA=%s BOOTSTRAP_DONE_FINAL=%s MAIN_ENABLED_FINAL=%s MAIN_FREQ_LOCKED_FINAL=%s MAIN_PHASE_LOCKED_FINAL=%s MAIN_LOCKED_FINAL=%s PSTAT_LOCKED_FINAL=%s HELPER_LOCKED_FINAL=%s HELPER_LOCK_COUNT_FINAL=%s SPLL_DELOCK_COUNT_FIRST=%s SPLL_DELOCK_COUNT_FINAL=%s RESET_BOOT_GENERATION_DELTA=%s RESET_CPU_DELTA=%s RESET_WR_CORE_DELTA=%s RESET_SI_CONFIG_DELTA=%s RESET_STABLE=%s KP=%d KI=%d SHIFT=%d BIAS=%d Y_MIN=%d Y_MAX=%d TAG_VALID_FIRST=%s TAG_VALID_FINAL=%s NORMAL_COMPLETED_FIRST=%s NORMAL_COMPLETED_FINAL=%s TARGET_FINAL=%s APPLIED_FINAL=%s HELPER_ERROR_FINAL=%s HELPER_OUTPUT_FINAL=%s PI_EPOCH_FINAL=%s PI_INTEGRATOR_BEFORE_FINAL=%s PI_I_NEW_FINAL=%s PI_INTEGRATOR_AFTER_FINAL=%s PI_UNCLAMPED_FINAL=%s PI_CLAMPED_FINAL=%s PI_CLAMP_SIDE_FINAL=%s RAW_ERROR_FINAL=%s LD_ERROR_FINAL=%s PI_PROP_TERM_FINAL=%s PI_Y_PREROUND_FINAL=%s" \
    $hardware_name $::sample_count($hardware_name) $valid $::invalid_frame_count($hardware_name) $window_seconds \
    $::pi_present_count($hardware_name) $pi_fraction $::pi_snapshot_reject_count($hardware_name) \
    $::pi_accounting_fail_count($hardware_name) $::pi_output_mismatch_count($hardware_name) \
    $::anti_windup_violation_count($hardware_name) $error_count $helper_error_mean $helper_error_rms \
    $::helper_error_max_abs($hardware_name) $helper_error_fraction \
    $::raw_error_count($hardware_name) $raw_error_mean $::raw_error_min($hardware_name) $::raw_error_max($hardware_name) \
    $raw_error_positive_fraction $::unclamped_below_min_count($hardware_name) \
    $::low_rail_count($hardware_name) $rail_fraction $::high_rail_count($hardware_name) $high_fraction $no_rail_fraction \
    $::helper_lock_max($hardware_name) \
    $::helper_count_final($hardware_name) $::helper_lock_rise_events($hardware_name) $::helper_lock_fall_events($hardware_name) \
    $::error_band_exit_events($hardware_name) $dynamics_candidate $low_rail_saturation $actuator_range_limit $causality_case \
    $freq_count $freq_error_mean $freq_error_rms \
    $::freq_error_max_abs($hardware_name) $::zero_crossing_count($hardware_name) $::cycle_complete($hardware_name) \
    $::physical_position_mismatch_count($hardware_name) $measurement_coherence $position_accounting $transaction_accounting \
    $::spll_init_first($hardware_name) $::spll_init_final($hardware_name) $spll_init_delta \
    $::clear_dacs_first($hardware_name) $::clear_dacs_final($hardware_name) $clear_dacs_delta \
    $::helper_epoch_reset_count($hardware_name) $normal_req_delta $normal_completed_delta $dco_step_delta \
    $forced_completed_delta $::bootstrap_completed_final($hardware_name) $bootstrap_completed_delta \
    $::bootstrap_done_final($hardware_name) $::main_enabled_final($hardware_name) $::main_freq_locked_final($hardware_name) \
    $::main_phase_locked_final($hardware_name) $::main_locked_final($hardware_name) $::pstat_locked_final($hardware_name) \
    $::helper_locked_final($hardware_name) $::helper_count_final($hardware_name) $::spll_delock_first($hardware_name) \
    $::spll_delock_final($hardware_name) $gen_delta $cpu_delta $wr_delta $si_delta $reset_stable \
    $PI_KP $PI_KI $PI_SHIFT $PI_BIAS $PI_Y_MIN $PI_Y_MAX $::tag_valid_first($hardware_name) \
    $::tag_valid_final($hardware_name) $::normal_completed_first($hardware_name) $::normal_completed_final($hardware_name) \
    $::position_target_final($hardware_name) $::position_applied_final($hardware_name) $::helper_error_final($hardware_name) \
    $::helper_output_final($hardware_name) $::pi_epoch_final($hardware_name) $::pi_before_final($hardware_name) \
    $::pi_i_new_final($hardware_name) $::pi_after_final($hardware_name) $::pi_unclamped_final($hardware_name) \
    $::pi_clamped_final($hardware_name) $::pi_side_final($hardware_name) $::pi_raw_error_final($hardware_name) \
    $::pi_ld_error_final($hardware_name) $::pi_prop_final($hardware_name) $::pi_preround_final($hardware_name)]
  puts [format "STEP5_ATOMIC_SNAPSHOT_TRANSPORT_V3 board=%s SAMPLES=%d VALID_FRAMES=%d INVALID_FRAMES=%d PI_TRACE_PRESENT=%d SNAPSHOT_REQ_COUNT=%s SNAPSHOT_BANK_COMMIT_COUNT=%s SNAPSHOT_ACK_COUNT=%s SNAPSHOT_OVERWRITE_COUNT=%s SNAPSHOT_REQ_DELTA=%s SNAPSHOT_BANK_COMMIT_DELTA=%s SNAPSHOT_ACK_DELTA=%s SNAPSHOT_OVERWRITE_DELTA=%s LAST_REQ_SEQ=%s LAST_BANK_SEQ=%s LAST_ACK_SEQ=%s ACK_TIMEOUT=%d ACK_MISMATCH=%d EPOCH_GENERATION_MISMATCH=%d EPOCH_CHANGED_DURING_READ=%d ATOMIC_SNAPSHOT_TRANSPORT_V3=%s" \
    $hardware_name $::sample_count($hardware_name) $valid $::invalid_frame_count($hardware_name) $pi_count \
    $::snapshot_req_final($hardware_name) $::snapshot_bank_commit_final($hardware_name) \
    $::snapshot_ack_final($hardware_name) $::snapshot_overwrite_final($hardware_name) \
    $snapshot_req_delta $snapshot_bank_commit_delta $snapshot_ack_delta $snapshot_overwrite_delta \
    $::snapshot_last_req_seq_final($hardware_name) $::snapshot_bank_seq_final($hardware_name) \
    $::snapshot_ack_seq_final($hardware_name) $::snapshot_ack_timeout_count($hardware_name) \
     $::snapshot_ack_mismatch_count($hardware_name) $::snapshot_epoch_generation_mismatch_count($hardware_name) \
     $::snapshot_epoch_changed_count($hardware_name) $snapshot_transport_v3]
  set primary_sum 0
  set primary_fields {}
  foreach reason $::primary_reject_reason_order {
    set key [format "%s|%s" $hardware_name $reason]
    set count $::primary_reject_count($key)
    incr primary_sum $count
    lappend primary_fields [format "REJECT_%s=%d" $reason $count]
  }
  set unclassified $::primary_reject_count([format "%s|OTHER" $hardware_name])
  if {$invalid > 0} {
    set coverage [format "%d/%d (%.1f%%)" $primary_sum $invalid \
      [expr {100.0 * $primary_sum / double($invalid)}]]
  } else {
    set coverage "0/0 (100.0%)"
  }
  puts [format "STEP5_V3_REJECT_ATTRIBUTION_SUMMARY board=%s SAMPLES=%d VALID_FRAMES=%d INVALID_FRAMES=%d REJECT_ATTRIBUTION_COVERAGE=%s UNCLASSIFIED_INVALID_FRAMES=%d SUM_PRIMARY_REJECT_COUNTS=%d %s" \
    $hardware_name $::sample_count($hardware_name) $valid $invalid $coverage $unclassified $primary_sum \
    [join $primary_fields " "]]
}

  puts [format "STEP5_GUARDED_HELPER_DYNAMICS_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V3-INVALID-FRAME-REJECT-ATTRIBUTION-100SAMPLES-20260901 read_only=1 snapshot_transport=serialized_request_in_band_epoch_v3 bootstrap_steps=6176 code_per_physical_step=64 kp=-150 ki=-1 threshold=200 lock_samples=10000 fresh_reset_required=1" $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && $hardware_name ne $board_filter} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    initialize_board $hardware_name
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set elapsed_ms [expr {($sample - 1) * $gap_ms}]
      emit_sample $hardware_name $sample $elapsed_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
    emit_summary $hardware_name
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_PI_AUDIT_DONE"
