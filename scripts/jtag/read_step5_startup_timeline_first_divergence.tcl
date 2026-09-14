# Step 5 N2 startup timeline / first-divergence observer (read-only).
#
# The observer is intentionally diagnostic-only.  It does not write a
# Wishbone control register, issue a DATA_SNAPSHOT request, or send a shell
# command.  It samples both DE5a boards from the beginning of a startup run:
#   0..30 s   every 1 s
#   30..deadline every 2 s
#
# N2 additionally captures the producer-side first-loss/DCO telemetry (probe
# 52..61) and brackets the read frame with CTRL_FRAME_BEGIN/END.  This keeps
# acquisition (never fully locked) distinct from tracking (fully locked before
# any first-loss event) without making a readiness or Step5 claim.
#
# Usage:
#   quartus_stp -t read_step5_startup_timeline_first_divergence.tcl ?trial_id? ?board_filter? ?duration_ms? ?early_gap_ms? ?late_gap_ms?
#
# The caller must program Master, wait for Master readiness, program Slave,
# and invoke this script immediately after Slave programming completes.

package require ::quartus::insystem_source_probe

set ::trial_id "TRIAL"
if {[llength $argv] >= 1} { set ::trial_id [lindex $argv 0] }
set ::board_filter ""
if {[llength $argv] >= 2} { set ::board_filter [lindex $argv 1] }
set ::duration_ms 120000
set ::early_window_ms 30000
set ::early_gap_ms 1000
set ::late_gap_ms 2000
if {[llength $argv] >= 3} { set ::duration_ms [lindex $argv 2] }
if {[llength $argv] >= 4} { set ::early_gap_ms [lindex $argv 3] }
if {[llength $argv] >= 5} { set ::late_gap_ms [lindex $argv 4] }
set ::start_ms [clock milliseconds]
set ::sample_seq 0
array set ::wb_toggle {}
array set ::prev {}
array set ::first {}
array set ::first_failure_reason {}
array set ::first_failure_tics_low {}
array set ::sample_count {}
array set ::sample_error {}
array set ::frame_invalid_count {}
array set ::boot_generation_first {}
array set ::boot_generation_last {}
array set ::boot_generation_change_count {}
array set ::tracking_sample_count {}
set ::persistent_probe 0

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

proc display32 {value} {
  set word [word32 $value]
  if {$word < 0} { return $value }
  return [format %08X $word]
}

proc bit32 {value bit} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc field32 {value lsb width} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($word >> $lsb) & $mask}]
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

proc bit64_high {value bit} {
  set word [probe_high32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc bit64_low {value bit} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc probe_byte64 {value bit} {
  if {$bit < 32} { return [bit64_low $value $bit] }
  return [bit64_high $value [expr {$bit - 32}]]
}

proc safe_probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc probe_read {instance} {
  return [safe_probe_read $instance]
}

proc wb_read {hardware_name addr} {
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [safe_probe_read 1]
    set word [word32 $value]
    if {[is_hex $value]} {
      scan $value %x wide
      set done_toggle [expr {($wide >> 35) & 1}]
      set active [expr {($wide >> 36) & 1}]
      if {$word >= 0 && $done_toggle == $toggle && $active == 0} {
        return [format %08X $word]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc wb_sync_toggle {hardware_name} {
  set value [safe_probe_read 1]
  if {[is_hex $value]} {
    scan $value %x wide
    set ::wb_toggle($hardware_name) [expr {($wide >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc frame_valid {ctrl_begin ctrl_end} {
  set a [word32 $ctrl_begin]
  set b [word32 $ctrl_end]
  if {$a < 0 || $b < 0} { return 0 }
  return [expr {(($a & 1) != 0) && (($b & 1) != 0) && $a == $b}]
}

proc n2_phase_name {frame_ok spll_ready helper_locked main_enabled main_freq_locked main_phase_locked main_locked pstat_locked} {
  if {$frame_ok == 1 && $helper_locked == 1 && $main_enabled == 1 &&
      $main_freq_locked == 1 && $main_phase_locked == 1 &&
      $main_locked == 1 && $pstat_locked == 1 && $spll_ready == 1} {
    return TRACKING
  }
  return ACQUISITION
}

proc ptp_state_name {state} {
  switch -- $state {
    1 { return INITIALIZING }
    2 { return FAULTY }
    3 { return DISABLED }
    4 { return LISTENING }
    5 { return PRE_MASTER }
    6 { return MASTER }
    7 { return PASSIVE }
    8 { return UNCALIBRATED }
    9 { return SLAVE }
  }
  return UNKNOWN
}

proc pd_state_name {state} {
  switch -- $state {
    0 { return NONE }
    1 { return WAIT_MSG }
    2 { return PDETECTION }
    3 { return PDETECTED }
    4 { return FAILURE }
  }
  return UNKNOWN
}

proc ext_state_name {state} {
  switch -- $state {
    0 { return DISABLE }
    1 { return ACTIVE }
    2 { return PTP }
  }
  return UNKNOWN
}

proc mode_name {mode} {
  switch -- $mode {
    2 { return MASTER }
    3 { return SLAVE }
  }
  return UNKNOWN
}

proc spll_mode_name {mode} {
  switch -- $mode {
    0 { return DISABLED }
    1 { return GRAND_MASTER }
    2 { return FREE_RUNNING_MASTER }
    3 { return SLAVE }
  }
  return UNKNOWN
}

proc spll_state_name {state} {
  switch -- $state {
    0 { return SEQ_UNINITIALIZED }
    1 { return SEQ_START_EXT }
    2 { return SEQ_WAIT_EXT }
    3 { return SEQ_START_HELPER }
    4 { return SEQ_WAIT_HELPER }
    5 { return SEQ_START_MAIN }
    6 { return SEQ_WAIT_MAIN }
    7 { return SEQ_DISABLED }
    8 { return SEQ_READY }
    9 { return SEQ_CLEAR_DACS }
    10 { return SEQ_WAIT_CLEAR_DACS }
  }
  return UNKNOWN
}

proc signal_name {message_id} {
  switch -- $message_id {
    4096 { return SLAVE_PRESENT }
    4097 { return LOCK }
    4098 { return LOCKED }
    4099 { return CALIBRATE }
    4100 { return CALIBRATED }
    4101 { return WR_MODE_ON }
  }
  return UNKNOWN
}

proc wr_state_name {state} {
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

proc wr_fail_reason_name {reason} {
  switch -- $reason {
    0 { return UNKNOWN }
    1 { return WR_PRESENT_TIMEOUT }
    2 { return WR_M_LOCK_TIMEOUT }
    3 { return WR_S_LOCK_TIMEOUT }
    4 { return WR_LOCKED_TIMEOUT }
    5 { return WR_CALIBRATED_TIMEOUT }
    6 { return WR_RESP_CALIB_REQ_TIMEOUT }
    7 { return NO_WR_PARENT }
  }
  return UNKNOWN
}

proc wr_disable_cause_name {cause} {
  switch -- $cause {
    0 { return OTHER_CALLER }
    1 { return PROTOCOL_DETECTION_TIMEOUT }
    2 { return HANDSHAKE_FAILURE }
  }
  return UNKNOWN
}

proc slock_stage_name {stage} {
  switch -- $stage {
    1 { return ENTRY }
    2 { return POLL }
    3 { return RETRY }
    4 { return FAILURE }
  }
  return UNKNOWN
}

proc num_or_invalid {value} {
  set n [word32 $value]
  if {$n < 0} { return INVALID }
  return $n
}

proc first_value {role field} {
  if {[info exists ::first($role,$field)]} {
    return $::first($role,$field)
  }
  return NEVER
}

proc note_first {role field condition elapsed} {
  if {$condition && ![info exists ::first($role,$field)]} {
    set ::first($role,$field) $elapsed
  }
}

proc note_transition {role field value elapsed} {
  if {$value < 0} { return }
  if {[info exists ::prev($role,$field)] && $::prev($role,$field) != $value} {
    puts [format "STARTUP_TIMELINE_TRANSITION trial=%s role=%s elapsed_ms=%d signal=%s from=%s to=%s" \
      $::trial_id $role $elapsed $field $::prev($role,$field) $value]
    flush stdout
  }
  set ::prev($role,$field) $value
}

proc note_counter_activity {role field value elapsed} {
  set current [word32 $value]
  if {$current < 0} { return }
  if {![info exists ::prev($role,$field)]} {
    set ::prev($role,$field) $current
    if {$current > 0} { note_first $role $field 1 $elapsed }
    return
  }
  set previous $::prev($role,$field)
  if {$current > $previous} { note_first $role $field 1 $elapsed }
  set ::prev($role,$field) $current
}

proc collect_targets {} {
  set masters {}
  set slaves {}
  foreach hardware_name [get_hardware_names] {
    if {$::board_filter ne "" && [string first $::board_filter $hardware_name] < 0} {
      continue
    }
    set role ""
    if {[string first "1-11.1" $hardware_name] >= 0} { set role MASTER }
    if {[string first "1-11.2" $hardware_name] >= 0} { set role SLAVE }
    if {$role eq ""} { continue }
    set device_names [get_device_names -hardware_name $hardware_name]
    if {[llength $device_names] == 0} { continue }
    set target [list $role $hardware_name [lindex $device_names 0]]
    if {$role eq "MASTER"} { lappend masters $target } else { lappend slaves $target }
  }
  return [concat $masters $slaves]
}

proc read_board_sample {role hardware_name device_name sample elapsed} {
  if {[catch {
    if {!$::persistent_probe} {
      start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
      set ::wb_toggle($hardware_name) 0
      wb_sync_toggle $hardware_name
    }

    set ctrl_begin [wb_read $hardware_name 0x00100A04]
    set status [probe_read 0]
    set entry_probe [probe_read 26]
    set reset_probe [probe_read 27]

    set ptp [wb_read $hardware_name 0x00100A10]
    set sstat [wb_read $hardware_name 0x00100A08]
    set ptp_rx [wb_read $hardware_name 0x00100A54]
    set ptp_tx [wb_read $hardware_name 0x00100A58]
    set rxerr [wb_read $hardware_name 0x00100A60]
    set ptp_meta [wb_read $hardware_name 0x00100A5C]
    set foreign_meta [wb_read $hardware_name 0x00100A78]
    set parse_meta [wb_read $hardware_name 0x00100A80]
    set wr_rx_signal [wb_read $hardware_name 0x00100A64]
    set wr_tx_signal [wb_read $hardware_name 0x00100A68]
    set wr_failure [wb_read $hardware_name 0x00100A6C]
    set wr_state [wb_read $hardware_name 0x00100A4C]
    set wr_reject [wb_read $hardware_name 0x00100A50]
    set pstat [wb_read $hardware_name 0x00100A0C]
    set lock_result [wb_read $hardware_name 0x00100A8C]
    set lock_polls [wb_read $hardware_name 0x00100A90]
    set lock_enable [wb_read $hardware_name 0x00100A9C]
    set lock_calib_fail [wb_read $hardware_name 0x00100A98]
    set lock_unlocked [wb_read $hardware_name 0x00100A94]
    set spll_state [wb_read $hardware_name 0x00100AA0]
    set ocer [wb_read $hardware_name 0x00100AA4]
    set rcer [wb_read $hardware_name 0x00100AA8]
    set helper_state [wb_read $hardware_name 0x00100ABC]
    set helper_limits [wb_read $hardware_name 0x00100AC0]
    set main_state [wb_read $hardware_name 0x00100AC4]
    set main_limits [wb_read $hardware_name 0x00100AC8]
    set main_phase_limits [wb_read $hardware_name 0x00100ACC]
    set helper_error [wb_read $hardware_name 0x00100AD8]
    set helper_output [wb_read $hardware_name 0x00100ADC]
    set spll_init [wb_read $hardware_name 0x00100B44]
    set tag_valid [wb_read $hardware_name 0x00100284]
    set trr_write [wb_read $hardware_name 0x00100288]
    set trr_pop [wb_read $hardware_name 0x00100B54]
    set irq [wb_read $hardware_name 0x00100AEC]
    set helper_update [wb_read $hardware_name 0x00100B18]
    set dmtd_ref_accept [wb_read $hardware_name 0x0010022C]
    set dmtd_fb_accept [wb_read $hardware_name 0x00100230]
    # WDIAGS private base is 0x00100A00. The isolated S_LOCK audit owns
    # the tail bank at CPU addresses 0x00100BE0..0x00100BFC.
    set slock_magic [wb_read $hardware_name 0x00100BE0]
    set slock_stage [wb_read $hardware_name 0x00100BE4]
    set slock_retry [wb_read $hardware_name 0x00100BE8]
    set slock_entry_tics [wb_read $hardware_name 0x00100BEC]
    set slock_remaining_ms [wb_read $hardware_name 0x00100BF0]
    set slock_poll_ret [wb_read $hardware_name 0x00100BF4]
    set slock_wr_state [wb_read $hardware_name 0x00100BF8]
    set slock_seq [wb_read $hardware_name 0x00100BFC]
    # L2 producer-side DCO/arbiter telemetry.  These are read-only probes;
    # their sticky first-loss record is interpreted only in the same boot
    # generation captured above.
    set l2_status [probe_read 52]
    set l2_pending [probe_read 53]
    set l2_service_start [probe_read 54]
    set l2_completed [probe_read 55]
    set l2_failed [probe_read 56]
    set l2_max_wait [probe_read 57]
    set l2_current_wait [probe_read 58]
    set l2_latency [probe_read 59]
    set l2_failure [probe_read 60]
    set l2_first_loss [probe_read 61]
    set ctrl_end [wb_read $hardware_name 0x00100A04]
  } error_message]} {
    if {!$::persistent_probe} { catch {end_insystem_source_probe} }
    incr ::sample_error($role)
    puts [format "STARTUP_TIMELINE_SAMPLE_ERROR trial=%s role=%s board=%s sample=%03d elapsed_ms=%d message=%s" \
      $::trial_id $role $hardware_name $sample $elapsed $error_message]
    flush stdout
    return
  }
  if {!$::persistent_probe} { catch {end_insystem_source_probe} }
  incr ::sample_count($role)

  set si_config_done [bit32 $status 0]
  set wr_ready [bit32 $status 1]
  set core_tm_link_up [bit32 $status 2]
  set core_link_ok [bit32 $status 3]
  set wr_rx_ready [bit32 $status 6]
  set wr_tx_ready [bit32 $status 7]
  set wr_rx_enc_err [bit32 $status 13]
  set wr_tx_enc_err [bit32 $status 14]
  set cpu_reset_n [bit32 $status 15]
  set wr_rx_locked_to_data [bit64_high $status 0]
  set boot_generation [probe_high32 $entry_probe]
  set cpu_reset_count [probe_byte64 $reset_probe 16]
  set wr_core_reset_count [probe_byte64 $reset_probe 24]
  set si_config_reset_count [probe_byte64 $reset_probe 40]

  set mode [field32 $ptp_meta 24 8]
  set ptp_state [field32 $ptp_meta 0 8]
  set pd_state [field32 $ptp_meta 8 8]
  set ext_state [field32 $ptp_meta 16 8]
  # task-diags.c stores wrc_ptp_get_mode() in the metadata high byte;
  # it is the configured WRC mode, not ppi->protocol_extension.
  set wrc_mode_meta [field32 $ptp_meta 24 8]
  set ptp_state_raw [field32 $ptp 0 8]
  set foreign_count [field32 $foreign_meta 0 8]
  set foreign_best [field32 $foreign_meta 8 8]
  set foreign_detection [field32 $foreign_meta 16 8]
  set foreign_wr_config [field32 $foreign_meta 24 8]
  set parent_is_wrnode [bit32 $parse_meta 24]
  set parent_mode_on [bit32 $parse_meta 25]
  set parent_calibrated [bit32 $parse_meta 26]
  set rx_signal_id [field32 $wr_rx_signal 16 16]
  set rx_signal_count [field32 $wr_rx_signal 0 16]
  set tx_signal_id [field32 $wr_tx_signal 16 16]
  set tx_signal_count [field32 $wr_tx_signal 0 16]
  set wr_state_value [field32 $wr_state 11 4]
  set wr_next_state [field32 $wr_state 15 4]
  set spll_seq_state [field32 $spll_state 0 8]
  set spll_align_state [field32 $spll_state 8 8]
  set spll_mode [field32 $spll_state 16 8]
  set spll_delock_count [field32 $spll_state 24 8]
  set lock_result_code [field32 $lock_result 0 8]
  set spll_check_lock [bit32 $lock_result 8]
  # Diagnostic-only attribution carried in otherwise unused high bits of
  # WR_LOCK_RESULT: reason[15:9], last-failure timer low word[31:16].
  set wr_failure_reason [field32 $lock_result 9 7]
  set wr_failure_tics_low [field32 $lock_result 16 16]
  # First WR-extension disable record: cause/PTP state are carried in the
  # unused middle byte of WR_FAILURE_DEBUG; SSTAT carries the timer and the
  # pre-disable pd/ext states.  The valid bit makes cause=OTHER unambiguous.
  set wr_disable_cause [field32 $wr_failure 8 3]
  set wr_disable_valid [bit32 $wr_failure 11]
  set wr_disable_ptp_state [field32 $wr_failure 12 4]
  set wr_disable_tics_low [field32 $sstat 16 16]
  set wr_disable_pd_state [field32 $sstat 1 4]
  set wr_disable_ext_state [field32 $sstat 12 4]
  set helper_locked [bit32 $helper_state 0]
  set helper_lock_changed [bit32 $helper_state 1]
  set helper_lock_count [field32 $helper_state 16 16]
  set helper_threshold [field32 $helper_limits 0 16]
  set helper_lock_samples [field32 $helper_limits 16 16]
  # task-diags.c packing: enabled=bit0, Main locked=bit1,
  # frequency locked=bit2, phase locked=bit3.
  # Keep the named fields aligned with the firmware packing; the previous
  # reader shifted bits 1..3 and could report phase/Main lock incorrectly.
  set main_enabled [bit32 $main_state 0]
  set main_locked [bit32 $main_state 1]
  set main_freq_locked [bit32 $main_state 2]
  set main_phase_locked [bit32 $main_state 3]
  set main_freq_lock_count [field32 $main_state 8 12]
  set main_phase_lock_count [field32 $main_state 20 12]
  set main_freq_threshold [field32 $main_limits 0 16]
  set main_freq_lock_samples [field32 $main_limits 16 16]
  set main_phase_threshold [field32 $main_phase_limits 0 16]
  set main_phase_lock_samples [field32 $main_phase_limits 16 16]
  set pstat_locked [bit32 $pstat 1]

  set frame_ok [frame_valid $ctrl_begin $ctrl_end]
  set n2_phase [n2_phase_name $frame_ok [expr {$spll_seq_state == 8}] $helper_locked $main_enabled $main_freq_locked $main_phase_locked $main_locked $pstat_locked]
  if {!$frame_ok} { incr ::frame_invalid_count($role) }
  if {$n2_phase eq "TRACKING"} { incr ::tracking_sample_count($role) }
  set ::last_n2_phase($role) $n2_phase
  if {$boot_generation >= 0} {
    if {![info exists ::boot_generation_first($role)]} {
      set ::boot_generation_first($role) $boot_generation
    }
    if {[info exists ::boot_generation_last($role)] &&
        $::boot_generation_last($role) != $boot_generation} {
      incr ::boot_generation_change_count($role)
    }
    set ::boot_generation_last($role) $boot_generation
  }

  set l2_first_loss_valid [probe_byte64 $l2_status 6]
  set l2_main_pending [probe_byte64 $l2_status 0]
  set l2_helper_pending [probe_byte64 $l2_status 1]
  set l2_tx_active [probe_byte64 $l2_status 2]
  set l2_owner_main [probe_byte64 $l2_status 3]
  set l2_ack [probe_byte64 $l2_status 4]
  set l2_timeout [probe_byte64 $l2_status 5]
  set l2_dco_error [probe_byte64 $l2_status 7]
  set l2_reason [field32 [word32 $l2_status] 8 8]
  set l2_rt_state [field32 [word32 $l2_status] 16 3]
  set l2_status_time [probe_high32 $l2_status]
  set l2_main_pending_count [word32 $l2_pending]
  set l2_helper_pending_count [probe_high32 $l2_pending]
  set l2_main_start_count [word32 $l2_service_start]
  set l2_helper_start_count [probe_high32 $l2_service_start]
  set l2_main_completed_count [word32 $l2_completed]
  set l2_helper_completed_count [probe_high32 $l2_completed]
  set l2_main_failed_count [word32 $l2_failed]
  set l2_helper_failed_count [probe_high32 $l2_failed]
  set l2_main_max_wait [word32 $l2_max_wait]
  set l2_helper_max_wait [probe_high32 $l2_max_wait]
  set l2_main_current_wait [word32 $l2_current_wait]
  set l2_helper_current_wait [probe_high32 $l2_current_wait]
  set l2_main_max_latency [word32 $l2_latency]
  set l2_helper_max_latency [probe_high32 $l2_latency]
  set l2_ack_events [word32 $l2_failure]
  set l2_timeout_events [probe_high32 $l2_failure]
  set l2_first_loss_time [word32 $l2_first_loss]
  set l2_first_loss_owner [field32 [probe_high32 $l2_first_loss] 0 2]
  set l2_first_loss_reason [field32 [probe_high32 $l2_first_loss] 2 8]

  set elapsed_now [expr {[clock milliseconds] - $::start_ms}]
  if {$elapsed_now > $elapsed} { set elapsed $elapsed_now }

  foreach pair [list \
      [list si_config_done $si_config_done] \
      [list wr_ready $wr_ready] \
      [list wr_rx_ready $wr_rx_ready] \
      [list wr_tx_ready $wr_tx_ready] \
      [list wr_rx_locked_to_data $wr_rx_locked_to_data] \
      [list core_tm_link_up $core_tm_link_up] \
      [list core_link_ok $core_link_ok] \
      [list ptp_state $ptp_state] \
      [list pd_state $pd_state] \
      [list ext_state $ext_state] \
      [list wrc_mode_meta $wrc_mode_meta] \
      [list parent_is_wrnode $parent_is_wrnode] \
      [list parent_mode_on $parent_mode_on] \
      [list parent_calibrated $parent_calibrated] \
      [list spll_seq_state $spll_seq_state] \
      [list spll_mode $spll_mode] \
      [list helper_locked $helper_locked] \
      [list helper_lock_changed $helper_lock_changed] \
      [list spll_check_lock $spll_check_lock] \
      [list main_enabled $main_enabled] \
      [list main_freq_locked $main_freq_locked] \
      [list main_phase_locked $main_phase_locked] \
      [list main_locked $main_locked] \
      [list pstat_locked $pstat_locked] \
      [list rx_signal_id $rx_signal_id] \
      [list tx_signal_id $tx_signal_id]] {
    note_transition $role [lindex $pair 0] [lindex $pair 1] $elapsed
  }
  note_first $role first_core_tm_link_up [expr {$core_tm_link_up == 1}] $elapsed
  note_first $role first_core_link_ok [expr {$core_link_ok == 1}] $elapsed
  note_first $role first_ptp_slave [expr {$ptp_state == 9}] $elapsed
  note_first $role first_pdstate_pdetected [expr {$pd_state == 3}] $elapsed
  note_first $role first_extstate_active [expr {$ext_state == 1}] $elapsed
  note_first $role first_parent_wr_calibrated [expr {$parent_is_wrnode == 1 && $parent_calibrated == 1}] $elapsed
  note_first $role first_lock_enable [expr {[word32 $lock_enable] > 0}] $elapsed
  note_first $role first_spll_init [expr {[word32 $spll_init] > 0}] $elapsed
  note_first $role first_helper_locked [expr {$helper_locked == 1}] $elapsed
  note_first $role first_spll_ready [expr {$spll_seq_state == 8}] $elapsed
  note_first $role first_main_enabled [expr {$main_enabled == 1}] $elapsed
  note_first $role first_main_freq_locked [expr {$main_freq_locked == 1}] $elapsed
  note_first $role first_main_phase_locked [expr {$main_phase_locked == 1}] $elapsed
  note_first $role first_main_locked [expr {$main_locked == 1}] $elapsed
  note_first $role first_pdstate_failure [expr {$pd_state == 4}] $elapsed
  note_first $role first_extstate_ptp [expr {$ext_state == 2}] $elapsed
  note_first $role first_pstat_locked [expr {$pstat_locked == 1}] $elapsed
  note_transition $role n2_frame_valid $frame_ok $elapsed
  note_transition $role n2_phase [expr {$n2_phase eq "TRACKING" ? 1 : 0}] $elapsed
  note_first $role first_tracking [expr {$n2_phase eq "TRACKING"}] $elapsed
  note_first $role first_l2_loss [expr {$l2_first_loss_valid == 1}] $elapsed
  if {$l2_first_loss_valid == 1 && ![info exists ::first($role,l2_first_loss_time)]} {
    set ::first($role,l2_first_loss_time) $l2_first_loss_time
    set ::first($role,l2_first_loss_owner) $l2_first_loss_owner
    set ::first($role,l2_first_loss_reason) $l2_first_loss_reason
    set ::first($role,l2_first_loss_status_time) $l2_status_time
  }
  if {![info exists ::first_failure_reason($role)] &&
      [word32 $wr_failure] >= 0 && [field32 $wr_failure 0 16] > 0} {
    set ::first_failure_reason($role) $wr_failure_reason
    set ::first_failure_tics_low($role) $wr_failure_tics_low
  }
  if {$wr_disable_valid == 1 &&
      ![info exists ::first($role,wr_disable_cause)]} {
    set ::first($role,wr_disable_cause) $wr_disable_cause
    set ::first($role,wr_disable_cause_ms) $elapsed
    set ::first($role,wr_disable_tics_low) $wr_disable_tics_low
    set ::first($role,wr_disable_ptp_state) $wr_disable_ptp_state
    set ::first($role,wr_disable_pd_state) $wr_disable_pd_state
    set ::first($role,wr_disable_ext_state) $wr_disable_ext_state
  }
  note_counter_activity $role ptp_rx_activity $ptp_rx $elapsed
  note_counter_activity $role ptp_tx_activity $ptp_tx $elapsed
  note_counter_activity $role dmtd_ref_accept $dmtd_ref_accept $elapsed
  note_counter_activity $role dmtd_fb_accept $dmtd_fb_accept $elapsed
  note_counter_activity $role tag_valid $tag_valid $elapsed
  note_counter_activity $role trr_write $trr_write $elapsed
  note_counter_activity $role trr_pop $trr_pop $elapsed
  note_counter_activity $role irq $irq $elapsed
  note_counter_activity $role helper_update $helper_update $elapsed
  if {[info exists ::first($role,dmtd_ref_accept)] || [info exists ::first($role,dmtd_fb_accept)]} {
    note_first $role first_dmtd_accept 1 $elapsed
  }
  if {[info exists ::first($role,tag_valid)] && [info exists ::first($role,trr_write)] && \
      [info exists ::first($role,trr_pop)] && [info exists ::first($role,irq)] && \
      [info exists ::first($role,helper_update)]} {
    note_first $role first_step4b_event_chain 1 $elapsed
  }

  puts [format "STARTUP_TIMELINE_SAMPLE trial=%s role=%s board=%s sample=%03d timestamp_ms=%d si_config_done=%s wr_ready=%s wr_rx_ready=%s wr_tx_ready=%s wr_rx_locked_to_data=%s wr_rx_enc_err=%s wr_tx_enc_err=%s core_tm_link_up=%s core_link_ok=%s WRC_MODE=%s(%s) PTP_STATE=%s(%s) PPSI_PDSTATE=%s(%s) PPSI_EXTSTATE=%s(%s) WRC_MODE_META=%s(%s) PTP_RAW_STATE=%s PTP_RX_COUNT=%s PTP_TX_COUNT=%s RXERR_COUNT=%s BOOT_GENERATION=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_RESET_COUNT=%s CPU_RESET_N=%s FOREIGN_META=%s foreign_count=%s foreign_best=%s foreign_detection=%s foreign_wr_config=%s parentIsWRnode=%s parentModeOn=%s parentCalibrated=%s WR_RX_SIGNAL=%s(id=%s:%s,count=%s) WR_TX_SIGNAL=%s(id=%s:%s,count=%s) WR_STATE=%s(next=%s,name=%s) WR_FAILURE=%s WR_DISABLE=valid=%s,cause=%s,ptp=%s,pd=%s,ext=%s,tics_low16=%s WR_REJECT=%s WR_LOCK_RESULT=%s(code=%s,check_lock=%s,fail_reason=%s(%s),fail_tics_low16=%s) SLOCK_TRACE_MAGIC=%s SLOCK_TRACE_STAGE=%s(%s) SLOCK_TRACE_RETRY=%s SLOCK_TRACE_ENTRY_TICS=%s SLOCK_TRACE_REMAINING_MS=%s SLOCK_TRACE_POLL_RET=%s SLOCK_TRACE_WR_STATE=%s SLOCK_TRACE_SEQ=%s WR_LOCK_POLL_COUNT=%s LOCK_ENABLE_COUNT=%s LOCK_CALIB_FAIL_COUNT=%s LOCK_UNLOCKED_COUNT=%s SPLL_MODE=%s(%s) SPLL_SEQ_STATE=%s(%s) SPLL_ALIGN_STATE=%s SPLL_HELPER_STATE=%s(locked=%s,changed=%s,lock_count=%s) SPLL_HELPER_LIMITS=%s(threshold=%s,samples=%s) SPLL_MAIN_STATE=%s(enabled=%s,freq_locked=%s,phase_locked=%s,locked=%s,freq_count=%s,phase_count=%s) SPLL_MAIN_LIMITS=%s(freq_threshold=%s,freq_samples=%s) SPLL_MAIN_PHASE_LIMITS=%s(phase_threshold=%s,phase_samples=%s) SPLL_DELOCK_COUNT=%s RCER=%s OCER=%s DMTD_REF_ACCEPT=%s DMTD_FB_ACCEPT=%s TAG_VALID=%s TRR_WRITE=%s TRR_POP=%s IRQ_COUNT=%s HELPER_UPDATE_COUNT=%s PSTAT=%s PSTAT_LOCKED=%s FRAME_VALID=%s N2_PHASE=%s CTRL_FRAME_BEGIN=%s CTRL_FRAME_END=%s DCO_HELPER_ERROR=%s DCO_HELPER_OUTPUT=%s L2_STATUS=%s L2_FIRST_LOSS_VALID=%s L2_FIRST_LOSS_TIME=%s L2_FIRST_LOSS_OWNER=%s L2_FIRST_LOSS_REASON=%s L2_MAIN_PENDING=%s L2_HELPER_PENDING=%s L2_TX_ACTIVE=%s L2_TX_OWNER_MAIN=%s L2_ACK=%s L2_TIMEOUT=%s L2_DCO_ERROR=%s L2_RT_STATE=%s L2_STATUS_TIME=%s L2_MAIN_PENDING_COUNT=%s L2_HELPER_PENDING_COUNT=%s L2_MAIN_START_COUNT=%s L2_HELPER_START_COUNT=%s L2_MAIN_COMPLETED=%s L2_HELPER_COMPLETED=%s L2_MAIN_FAILED=%s L2_HELPER_FAILED=%s L2_MAIN_MAX_WAIT=%s L2_HELPER_MAX_WAIT=%s L2_MAIN_CURRENT_WAIT=%s L2_HELPER_CURRENT_WAIT=%s L2_MAIN_MAX_LATENCY=%s L2_HELPER_MAX_LATENCY=%s L2_ACK_EVENTS=%s L2_TIMEOUT_EVENTS=%s" \
    $::trial_id $role $hardware_name $sample $elapsed $si_config_done $wr_ready $wr_rx_ready $wr_tx_ready $wr_rx_locked_to_data $wr_rx_enc_err $wr_tx_enc_err $core_tm_link_up $core_link_ok \
    $mode [mode_name $mode] $ptp_state [ptp_state_name $ptp_state] $pd_state [pd_state_name $pd_state] $ext_state [ext_state_name $ext_state] $wrc_mode_meta [mode_name $wrc_mode_meta] $ptp_state_raw [display32 $ptp_rx] [display32 $ptp_tx] [display32 $rxerr] \
    [expr {$boot_generation < 0 ? "INVALID" : [format %08X $boot_generation]}] \
    [expr {$cpu_reset_count < 0 ? "INVALID" : $cpu_reset_count}] [expr {$wr_core_reset_count < 0 ? "INVALID" : $wr_core_reset_count}] [expr {$si_config_reset_count < 0 ? "INVALID" : $si_config_reset_count}] $cpu_reset_n \
    [display32 $foreign_meta] [num_or_invalid $foreign_count] [num_or_invalid $foreign_best] [num_or_invalid $foreign_detection] [num_or_invalid $foreign_wr_config] $parent_is_wrnode $parent_mode_on $parent_calibrated \
    [display32 $wr_rx_signal] $rx_signal_id [signal_name $rx_signal_id] $rx_signal_count [display32 $wr_tx_signal] $tx_signal_id [signal_name $tx_signal_id] $tx_signal_count \
    [display32 $wr_state] $wr_next_state [wr_state_name $wr_state_value] [display32 $wr_failure] $wr_disable_valid $wr_disable_cause $wr_disable_ptp_state $wr_disable_pd_state $wr_disable_ext_state $wr_disable_tics_low [display32 $wr_reject] [display32 $lock_result] $lock_result_code $spll_check_lock $wr_failure_reason [wr_fail_reason_name $wr_failure_reason] $wr_failure_tics_low [display32 $slock_magic] [display32 $slock_stage] [slock_stage_name [word32 $slock_stage]] [display32 $slock_retry] [display32 $slock_entry_tics] [display32 $slock_remaining_ms] [display32 $slock_poll_ret] [display32 $slock_wr_state] [display32 $slock_seq] [display32 $lock_polls] [display32 $lock_enable] [display32 $lock_calib_fail] [display32 $lock_unlocked] \
    $spll_mode [spll_mode_name $spll_mode] $spll_seq_state [spll_state_name $spll_seq_state] $spll_align_state [display32 $helper_state] $helper_locked $helper_lock_changed $helper_lock_count [display32 $helper_limits] $helper_threshold $helper_lock_samples [display32 $main_state] $main_enabled $main_freq_locked $main_phase_locked $main_locked $main_freq_lock_count $main_phase_lock_count [display32 $main_limits] $main_freq_threshold $main_freq_lock_samples [display32 $main_phase_limits] $main_phase_threshold $main_phase_lock_samples $spll_delock_count [display32 $rcer] [display32 $ocer] \
    [display32 $dmtd_ref_accept] [display32 $dmtd_fb_accept] [display32 $tag_valid] [display32 $trr_write] [display32 $trr_pop] [display32 $irq] [display32 $helper_update] [display32 $pstat] $pstat_locked \
    $frame_ok $n2_phase [display32 $ctrl_begin] [display32 $ctrl_end] [display32 $helper_error] [display32 $helper_output] [display32 $l2_status] $l2_first_loss_valid $l2_first_loss_time $l2_first_loss_owner $l2_first_loss_reason \
    $l2_main_pending $l2_helper_pending $l2_tx_active $l2_owner_main $l2_ack $l2_timeout $l2_dco_error $l2_rt_state [display32 $l2_status_time] \
    $l2_main_pending_count $l2_helper_pending_count $l2_main_start_count $l2_helper_start_count $l2_main_completed_count $l2_helper_completed_count \
    $l2_main_failed_count $l2_helper_failed_count $l2_main_max_wait $l2_helper_max_wait $l2_main_current_wait $l2_helper_current_wait \
    $l2_main_max_latency $l2_helper_max_latency $l2_ack_events $l2_timeout_events]
  flush stdout
}

proc print_board_summary {role} {
  set first_dmtd [first_value $role first_dmtd_accept]
  set first_tag [first_value $role tag_valid]
  set first_write [first_value $role trr_write]
  set first_pop [first_value $role trr_pop]
  set first_irq [first_value $role irq]
  set first_helper [first_value $role helper_update]
  set first_tracking [first_value $role first_tracking]
  set first_l2_loss [first_value $role first_l2_loss]
  set first_l2_loss_time NEVER
  set first_l2_loss_owner NEVER
  set first_l2_loss_reason NEVER
  set first_l2_loss_status_time NEVER
  if {[info exists ::first($role,l2_first_loss_time)]} {
    set first_l2_loss_time $::first($role,l2_first_loss_time)
    set first_l2_loss_owner $::first($role,l2_first_loss_owner)
    set first_l2_loss_reason $::first($role,l2_first_loss_reason)
    set first_l2_loss_status_time $::first($role,l2_first_loss_status_time)
  }
  set first_failure_reason NEVER
  set first_failure_tics_low NEVER
  if {[info exists ::first_failure_reason($role)]} {
    set first_failure_reason $::first_failure_reason($role)
    set first_failure_tics_low $::first_failure_tics_low($role)
  }
  set first_disable_cause NEVER
  set first_disable_ms NEVER
  set first_disable_tics_low NEVER
  set first_disable_ptp_state NEVER
  set first_disable_pd_state NEVER
  set first_disable_ext_state NEVER
  if {[info exists ::first($role,wr_disable_cause)]} {
    set first_disable_cause $::first($role,wr_disable_cause)
    set first_disable_ms $::first($role,wr_disable_cause_ms)
    set first_disable_tics_low $::first($role,wr_disable_tics_low)
    set first_disable_ptp_state $::first($role,wr_disable_ptp_state)
    set first_disable_pd_state $::first($role,wr_disable_pd_state)
    set first_disable_ext_state $::first($role,wr_disable_ext_state)
  }
  set boundary WR_CORE_LINK
  if {[first_value $role first_core_tm_link_up] ne "NEVER" && [first_value $role first_core_link_ok] ne "NEVER"} {
    set boundary PTP_RX
  }
  if {$boundary eq "PTP_RX" && $first_dmtd ne "NEVER"} {
    set boundary WR_PARENT_HANDSHAKE
  }
  if {$boundary eq "WR_PARENT_HANDSHAKE" && [first_value $role first_parent_wr_calibrated] ne "NEVER"} {
    set boundary LOCKING_ENABLE_DISPATCH
  }
  if {$boundary eq "LOCKING_ENABLE_DISPATCH" && [first_value $role first_lock_enable] ne "NEVER"} {
    if {$first_tag ne "NEVER" && $first_write ne "NEVER" && $first_pop ne "NEVER" && $first_irq ne "NEVER" && $first_helper ne "NEVER"} {
      set boundary STARTUP_GATE
    } else {
      set boundary SOFTPLL_EVENT_CHAIN
    }
  }
  if {[first_value $role first_pdstate_failure] ne "NEVER" ||
      [first_value $role first_extstate_ptp] ne "NEVER"} {
    set boundary WR_EXTENSION_FAILURE
  }
  if {$::sample_count($role) == 0} { set boundary OBSERVER_ERROR }
  set unclassified 0
  if {$boundary eq "OBSERVER_ERROR"} { set unclassified 1 }
  puts [format "STARTUP_TIMELINE_BOARD_SUMMARY trial=%s role=%s samples=%d sample_errors=%d N2_SESSION_DEADLINE_MS=%d N2_FIRST_TRACKING_MS=%s N2_TRACKING_SAMPLES=%d N2_LAST_PHASE=%s N2_FRAME_INVALID_SAMPLES=%d N2_BOOT_GENERATION_FIRST=%s N2_BOOT_GENERATION_LAST=%s N2_BOOT_GENERATION_CHANGES=%d N2_FIRST_L2_LOSS_MS=%s N2_L2_FIRST_LOSS_VALID=%s N2_L2_FIRST_LOSS_TIME=%s N2_L2_FIRST_LOSS_OWNER=%s N2_L2_FIRST_LOSS_REASON=%s N2_L2_FIRST_LOSS_STATUS_TIME=%s FIRST_CORE_TM_LINK_UP_MS=%s FIRST_CORE_LINK_OK_MS=%s FIRST_PTP_RX_ACTIVITY_MS=%s FIRST_PTP_TX_ACTIVITY_MS=%s FIRST_DMTD_ACCEPT_MS=%s FIRST_PTP_SLAVE_MS=%s FIRST_PDSTATE_PDETECTED_MS=%s FIRST_PDSTATE_FAILURE_MS=%s FIRST_EXTSTATE_ACTIVE_MS=%s FIRST_EXTSTATE_PTP_MS=%s FIRST_PARENT_WR_CALIBRATED_MS=%s FIRST_LOCK_ENABLE_MS=%s FIRST_HELPER_LOCKED_MS=%s FIRST_SPLL_READY_MS=%s FIRST_MAIN_ENABLED_MS=%s FIRST_MAIN_FREQ_LOCKED_MS=%s FIRST_MAIN_PHASE_LOCKED_MS=%s FIRST_MAIN_LOCKED_MS=%s FIRST_SPLL_INIT_MS=%s FIRST_TAG_VALID_MS=%s FIRST_TRR_WRITE_MS=%s FIRST_TRR_POP_MS=%s FIRST_IRQ_MS=%s FIRST_HELPER_UPDATE_MS=%s FIRST_PSTAT_LOCKED_MS=%s FIRST_WR_FAILURE_REASON=%s(%s) FIRST_WR_FAILURE_TICS_LOW16=%s FIRST_WR_DISABLE_MS=%s FIRST_WR_DISABLE_CAUSE=%s(%s) FIRST_WR_DISABLE_PTP_STATE=%s FIRST_WR_DISABLE_PDSTATE=%s FIRST_WR_DISABLE_EXTSTATE=%s FIRST_WR_DISABLE_TICS_LOW16=%s FIRST_INACTIVE_BOUNDARY=%s UNCLASSIFIED=%d" \
    $::trial_id $role $::sample_count($role) $::sample_error($role) $::duration_ms $first_tracking $::tracking_sample_count($role) $::last_n2_phase($role) $::frame_invalid_count($role) \
    [expr {[info exists ::boot_generation_first($role)] ? [format %08X $::boot_generation_first($role)] : "NEVER"}] \
    [expr {[info exists ::boot_generation_last($role)] ? [format %08X $::boot_generation_last($role)] : "NEVER"}] $::boot_generation_change_count($role) $first_l2_loss $first_l2_loss_time $first_l2_loss_owner $first_l2_loss_reason $first_l2_loss_status_time \
    [first_value $role first_core_tm_link_up] [first_value $role first_core_link_ok] [first_value $role ptp_rx_activity] [first_value $role ptp_tx_activity] $first_dmtd \
    [first_value $role first_ptp_slave] [first_value $role first_pdstate_pdetected] [first_value $role first_pdstate_failure] [first_value $role first_extstate_active] [first_value $role first_extstate_ptp] [first_value $role first_parent_wr_calibrated] [first_value $role first_lock_enable] [first_value $role first_helper_locked] [first_value $role first_spll_ready] [first_value $role first_main_enabled] [first_value $role first_main_freq_locked] [first_value $role first_main_phase_locked] [first_value $role first_main_locked] [first_value $role first_spll_init] $first_tag $first_write $first_pop $first_irq $first_helper \
    [first_value $role first_pstat_locked] $first_failure_reason [wr_fail_reason_name $first_failure_reason] $first_failure_tics_low $first_disable_ms $first_disable_cause [wr_disable_cause_name $first_disable_cause] $first_disable_ptp_state $first_disable_pd_state $first_disable_ext_state $first_disable_tics_low $boundary $unclassified]
  flush stdout
}

set ::targets [collect_targets]
if {[llength $::targets] == 0} {
  error "no DE5a targets matching 1-11.1 and 1-11.2 were found"
}
foreach role {MASTER SLAVE} {
  set ::sample_count($role) 0
  set ::sample_error($role) 0
  set ::frame_invalid_count($role) 0
  set ::boot_generation_change_count($role) 0
  set ::tracking_sample_count($role) 0
  set ::last_n2_phase($role) UNKNOWN
}

puts [format "STARTUP_TIMELINE_CONFIG trial=%s board_filter=%s duration_ms=%d N2_SESSION_DEADLINE_MS=%d early_window_ms=%d early_gap_ms=%d late_gap_ms=%d targets=%s read_only=1 ctrl_frame_bracket=1 l2_probes=52..61" \
  $::trial_id $::board_filter $::duration_ms $::duration_ms $::early_window_ms $::early_gap_ms $::late_gap_ms $::targets]
flush stdout

if {[llength $::targets] == 1} {
  # In the normal two-process invocation each process owns one cable.  Keep
  # that read-only probe session open so the requested 1 s / 2 s cadence is
  # not dominated by repeated SignalTap probe connection setup.
  set target [lindex $::targets 0]
  if {[catch {
    start_insystem_source_probe -hardware_name [lindex $target 1] -device_name [lindex $target 2]
    set ::wb_toggle([lindex $target 1]) 0
    wb_sync_toggle [lindex $target 1]
    set ::persistent_probe 1
    while {[expr {[clock milliseconds] - $::start_ms}] < $::duration_ms} {
      incr ::sample_seq
      set elapsed [expr {[clock milliseconds] - $::start_ms}]
      read_board_sample [lindex $target 0] [lindex $target 1] [lindex $target 2] $::sample_seq $elapsed
      set now_elapsed [expr {[clock milliseconds] - $::start_ms}]
      if {$now_elapsed < $::duration_ms} {
        if {$now_elapsed < $::early_window_ms} {
          set target_elapsed [expr {$now_elapsed + $::early_gap_ms}]
        } else {
          set target_elapsed [expr {$now_elapsed + $::late_gap_ms}]
        }
        set sleep_ms [expr {$target_elapsed - ([clock milliseconds] - $::start_ms)}]
        if {$sleep_ms > 0} { after $sleep_ms }
      }
    }
  } error_message]} {
    incr ::sample_error([lindex $target 0])
    puts [format "STARTUP_TIMELINE_SESSION_ERROR trial=%s role=%s board=%s message=%s" \
      $::trial_id [lindex $target 0] [lindex $target 1] $error_message]
  }
  catch {end_insystem_source_probe}
  set ::persistent_probe 0
} else {
  while {[expr {[clock milliseconds] - $::start_ms}] < $::duration_ms} {
    incr ::sample_seq
    set elapsed [expr {[clock milliseconds] - $::start_ms}]
    foreach target $::targets {
      read_board_sample [lindex $target 0] [lindex $target 1] [lindex $target 2] $::sample_seq $elapsed
    }
    set now_elapsed [expr {[clock milliseconds] - $::start_ms}]
    if {$now_elapsed < $::duration_ms} {
      if {$now_elapsed < $::early_window_ms} {
        set target_elapsed [expr {$now_elapsed + $::early_gap_ms}]
      } else {
        set target_elapsed [expr {$now_elapsed + $::late_gap_ms}]
      }
      set sleep_ms [expr {$target_elapsed - ([clock milliseconds] - $::start_ms)}]
      if {$sleep_ms > 0} { after $sleep_ms }
    }
  }
}

foreach role {MASTER SLAVE} {
  if {$::sample_count($role) > 0} { print_board_summary $role }
}
puts [format "STARTUP_TIMELINE_DEADLINE trial=%s deadline_ms=%d reached=%d" \
  $::trial_id $::duration_ms [expr {[clock milliseconds] - $::start_ms >= $::duration_ms}]]
puts [format "STARTUP_TIMELINE_DONE trial=%s elapsed_ms=%d" $::trial_id [expr {[clock milliseconds] - $::start_ms}]]
flush stdout
