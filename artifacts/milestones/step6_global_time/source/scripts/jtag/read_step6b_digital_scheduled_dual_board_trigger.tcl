# Step6B-1: digital scheduled dual-board Global-Time trigger.
#
# The scheduler is programmed through altsource_probe instances 67/68 and is
# observed through probes 67..71.  This script is deliberately explicit about
# the arm/target protocol: target first with ARM=0, a >=100 ms settling
# interval, then one ARM rising edge on each board.  It never changes the PPS
# output or any WR/PTP/SoftPLL control register.

package require ::quartus::insystem_source_probe

set ::wf_library_only 1
source [file join [file dirname [info script]] \
  read_step6_wr_extension_fallback_terminal_liveness.tcl]

set ::s6b_mode "TRIGGER"
if {[llength $argv] >= 1 && [lindex $argv 0] eq "__S6A_LATE_TAIL__"} {
  set ::s6b_mode "LATE_TAIL"
  set argv [lrange $argv 1 end]
} elseif {[llength $argv] >= 1 && [lindex $argv 0] eq "__S6B_LIVE_SESSION__"} {
  set ::s6b_mode "LIVE_SESSION"
  set argv [lrange $argv 1 end]
}
set ::s6b_trial_id "EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-HARDWARE-RUN-V2-20260922"
set ::s6b_prearm_timeout_ms 60000
set ::s6b_prearm_gap_ms 350
set ::s6b_target_settle_ms 150
set ::s6b_arm_settle_ms 120
set ::s6b_capture_gap_ms 250
set ::s6b_observe_timeout_ms 25000
set ::s6b_target_cycles 62500000
set ::s6a_tail_window_ms 45000
set ::s6a_tail_gap_ms 300
set ::s6b_live_gate_timeout_ms 10000
set ::s6b_live_gate_gap_ms 300
set ::s6b_live_target_settle_ms 150
set ::s6b_live_arm_settle_ms 120
set ::s6b_live_capture_gap_ms 300
if {$::s6b_mode eq "LATE_TAIL"} {
  if {[llength $argv] >= 1} { set ::s6b_trial_id [lindex $argv 0] }
  if {[llength $argv] >= 2} { set ::s6a_tail_window_ms [expr {int([lindex $argv 1])}] }
  if {[llength $argv] >= 3} { set ::s6a_tail_gap_ms [expr {int([lindex $argv 2])}] }
} elseif {$::s6b_mode eq "LIVE_SESSION"} {
  if {[llength $argv] >= 1} { set ::s6b_trial_id [lindex $argv 0] }
  if {[llength $argv] >= 2} { set ::s6b_live_gate_timeout_ms [expr {int([lindex $argv 1])}] }
  if {[llength $argv] >= 3} { set ::s6b_live_gate_gap_ms [expr {int([lindex $argv 2])}] }
} else {
  if {[llength $argv] >= 1} { set ::s6b_trial_id [lindex $argv 0] }
  if {[llength $argv] >= 2} { set ::s6b_prearm_timeout_ms [expr {int([lindex $argv 1])}] }
  if {[llength $argv] >= 3} { set ::s6b_prearm_gap_ms [expr {int([lindex $argv 2])}] }
  if {[llength $argv] >= 4} { set ::s6b_capture_gap_ms [expr {int([lindex $argv 3])}] }
}
if {($::s6b_mode eq "LATE_TAIL" &&
     ($::s6a_tail_window_ms <= 0 || $::s6a_tail_gap_ms < 0)) ||
    ($::s6b_mode eq "LIVE_SESSION" &&
     ($::s6b_live_gate_timeout_ms <= 0 || $::s6b_live_gate_gap_ms < 0 ||
      $::s6b_live_target_settle_ms < 150 || $::s6b_live_arm_settle_ms < 120 ||
      $::s6b_live_capture_gap_ms < 200)) ||
    ($::s6b_mode ne "LATE_TAIL" &&
     $::s6b_mode ne "LIVE_SESSION" &&
     ($::s6b_prearm_timeout_ms <= 0 || $::s6b_prearm_gap_ms < 0 ||
      $::s6b_target_settle_ms < 100 || $::s6b_arm_settle_ms < 0 ||
      $::s6b_capture_gap_ms < 0))} {
  error "invalid Step6 observation timing arguments"
}
array set ::s6b_baseline_reset {}
set ::s6b_ptp_restart_used 0

proc s6b_u40 {value} {
  if {![wf_raw_valid $value]} { return -1 }
  set low [word32 $value]
  set high [probe_high32 $value]
  if {$low < 0 || $high < 0} { return -1 }
  return [expr {(($high & 0xff) << 32) | $low}]
}

proc s6b_field64_low {value low width} {
  if {![wf_raw_valid $value] || $low < 0 || $low + $width > 32} {
    return -1
  }
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $low) & ((1 << $width) - 1)}]
}

proc s6b_field64_high {value low width} {
  if {![wf_raw_valid $value] || $low < 0 || $low + $width > 32} {
    return -1
  }
  set word [probe_high32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $low) & ((1 << $width) - 1)}]
}

proc s6b_capture {hardware_name role sample elapsed_ms} {
  set activity_start [safe_probe_read 7]
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set live [safe_probe_read 64]
  set snapshot1_before [safe_probe_read 63]
  set snapshot0 [safe_probe_read 62]
  set snapshot1_after [safe_probe_read 63]
  set step6b_target_raw [safe_probe_read 67]
  set step6b_status_raw [safe_probe_read 68]
  set step6b_latched_raw [safe_probe_read 69]
  set step6b_actual_tai_raw [safe_probe_read 70]
  set step6b_actual_cycles_raw [safe_probe_read 71]
  set spll_state [wb_read 0x00100AA0]
  set pstat [wb_read 0x00100A0C]
  set main_state [wb_read 0x00100AC4]
  set ptp_meta [wb_read 0x00100A5C]
  set wr_state [wb_read 0x00100A4C]
  set activity_end [safe_probe_read 7]

  set read_valid 1
  foreach value [list $activity_start $status $entry $reset $live \
      $snapshot1_before $snapshot0 $snapshot1_after $step6b_target_raw \
      $step6b_status_raw $step6b_latched_raw $step6b_actual_tai_raw \
      $step6b_actual_cycles_raw $spll_state $pstat $main_state $ptp_meta \
      $wr_state $activity_end] {
    if {![wf_raw_valid $value]} { set read_valid 0 }
  }

  lassign [wf_reset_values $entry $reset] boot_generation cpu_reset_count \
    wr_core_reset_count si_config_drop_count
  foreach value [list $boot_generation $cpu_reset_count $wr_core_reset_count \
      $si_config_drop_count] {
    if {$value eq "INVALID"} { set read_valid 0 }
  }
  set reset_changed 0
  if {$read_valid} {
    set reset_changed [wf_reset_changed $hardware_name $boot_generation \
      $cpu_reset_count $wr_core_reset_count $si_config_drop_count]
  }

  lassign [wf_live_fields $live] live_tai live_cycles
  lassign [wf_snapshot_fields $snapshot0 $snapshot1_after] snapshot_tai \
    snapshot_cycles snapshot_time_valid snapshot_pps_valid snapshot_valid \
    snapshot_count
  set snapshot_stable [expr {$snapshot1_before eq $snapshot1_after ? 1 : 0}]
  set snapshot_accepted [expr {$read_valid && $snapshot_stable &&
      $snapshot_valid == 1 && $snapshot_time_valid == 1 &&
      $snapshot_pps_valid == 1 && $snapshot_cycles >= 0 &&
      $snapshot_cycles <= 124999999}]

  set status_si [wf_status_bit $status 0]
  set status_ready [wf_status_bit $status 1]
  set status_tm_link [wf_status_bit $status 2]
  set status_link_ok [wf_status_bit $status 3]
  set status_time_valid [wf_status_bit $status 4]
  set status_pps_valid [wf_status_bit $status 5]
  set status_rx_ready [wf_status_bit $status 6]
  set status_tx_ready [wf_status_bit $status 7]
  set status_tx_disable [wf_status_bit $status 10]
  set status_phy_reset [wf_status_bit $status 11]
  set status_cpu_reset_n [wf_status_bit $status 15]
  set rx_locked [wf_status_high_bit $status 0]
  set rx_pattern_ready [wf_status_high_bit $status 6]
  set activity_start_value [wf_activity_count $activity_start]
  set activity_end_value [wf_activity_count $activity_end]
  set activity_changed [expr {$activity_start_value >= 0 &&
      $activity_end_value >= 0 && $activity_start_value != $activity_end_value}]

  set spll_word [word32 $spll_state]
  set pstat_word [word32 $pstat]
  set main_word [word32 $main_state]
  set wr_state_word [word32 $wr_state]
  set spll_seq [expr {$spll_word < 0 ? -1 : ($spll_word & 0xff)}]
  set pstat_locked [expr {$pstat_word < 0 ? -1 : (($pstat_word >> 1) & 1)}]
  set main_locked [expr {$main_word < 0 ? -1 : (($main_word >> 1) & 1)}]
  set main_freq_locked [expr {$main_word < 0 ? -1 : (($main_word >> 2) & 1)}]
  set main_phase_locked [expr {$main_word < 0 ? -1 : (($main_word >> 3) & 1)}]
  lassign [wf_ptp_fields $ptp_meta] ptp_state pd_state ext_state wrc_mode
  set wr_state_value [expr {$wr_state_word < 0 ? -1 : (($wr_state_word >> 11) & 0xf)}]

  set target_tai_source [s6b_u40 $step6b_target_raw]
  set latched_tai [s6b_u40 $step6b_latched_raw]
  set actual_tai [s6b_u40 $step6b_actual_tai_raw]
  set step6b_arm_source [s6b_field64_low $step6b_status_raw 0 1]
  set step6b_arm_sync [s6b_field64_low $step6b_status_raw 1 1]
  set step6b_armed [s6b_field64_low $step6b_status_raw 2 1]
  set step6b_fired [s6b_field64_low $step6b_status_raw 3 1]
  set step6b_arm_time_valid [s6b_field64_low $step6b_status_raw 4 1]
  set step6b_arm_pps_valid [s6b_field64_low $step6b_status_raw 5 1]
  set step6b_arm_tm_link [s6b_field64_low $step6b_status_raw 6 1]
  set step6b_arm_link_ok [s6b_field64_low $step6b_status_raw 7 1]
  set step6b_arm_sync_prev [s6b_field64_low $step6b_status_raw 13 1]
  set fire_count [s6b_field64_low $step6b_status_raw 14 16]
  set actual_cycles [s6b_field64_low $step6b_actual_cycles_raw 0 28]
  set fixed_target_cycles [expr {([s6b_field64_high $step6b_actual_cycles_raw 0 24] << 4) |
      ([s6b_field64_low $step6b_actual_cycles_raw 28 4])}]
  set actual_fired [s6b_field64_high $step6b_actual_cycles_raw 24 1]
  set actual_armed [s6b_field64_high $step6b_actual_cycles_raw 25 1]

  set link_healthy [expr {$status_si == 1 && $status_ready == 1 &&
      $status_rx_ready == 1 && $status_tx_ready == 1 &&
      $status_cpu_reset_n == 1 && $status_phy_reset == 0 &&
      $status_tx_disable == 0 && $status_tm_link == 1 &&
      $status_link_ok == 1}]
  set capture_healthy [expr {$link_healthy &&
      ($role ne "SLAVE" || ($rx_locked == 1 && $rx_pattern_ready == 1))}]
  set pll_ready [expr {$role ne "SLAVE" || ($spll_seq == 8 &&
      $pstat_locked == 1 && $main_locked == 1)}]
  set prearm_healthy [expr {$read_valid && $reset_changed == 0 &&
      $capture_healthy && $pll_ready && $status_time_valid == 1 &&
      $status_pps_valid == 1 && $snapshot_accepted}]
  set terminal_fallback [expr {$role eq "SLAVE" && $read_valid &&
      $capture_healthy && $rx_pattern_ready == 1 && $spll_seq == 8 &&
      $pstat_locked == 1 && $main_locked == 1 &&
      $ptp_state == 9 && $pd_state == 4 && $ext_state == 2 &&
      $wr_state_value == 0 && $status_time_valid == 0}]

  return [list ROLE $role BOARD $role SAMPLE $sample ELAPSED_MS $elapsed_ms \
    READ_VALID $read_valid RESET_CHANGED $reset_changed \
    LINK_HEALTHY $link_healthy CAPTURE_HEALTHY $capture_healthy \
    PLL_READY $pll_ready PREARM_HEALTHY $prearm_healthy \
    TERMINAL_FALLBACK $terminal_fallback STATUS_SI_CONFIG $status_si \
    STATUS_WR_READY $status_ready STATUS_TM_LINK_UP $status_tm_link \
    STATUS_LINK_OK $status_link_ok STATUS_TIME_VALID $status_time_valid \
    STATUS_PPS_VALID $status_pps_valid STATUS_RX_READY $status_rx_ready \
    STATUS_TX_READY $status_tx_ready STATUS_CPU_RESET_N $status_cpu_reset_n \
    STATUS_PHY_RST $status_phy_reset STATUS_PHY_TX_DISABLE $status_tx_disable \
    RX_LOCKED_TO_DATA $rx_locked RX_PATTERN_READY $rx_pattern_ready \
    RX_ACTIVITY_CHANGED $activity_changed LIVE_TAI $live_tai \
    LIVE_CYCLES $live_cycles SNAPSHOT_STABLE $snapshot_stable \
    SNAPSHOT_ACCEPTED $snapshot_accepted SNAPSHOT_VALID $snapshot_valid \
    SNAPSHOT_TIME_VALID $snapshot_time_valid SNAPSHOT_PPS_VALID $snapshot_pps_valid \
    SNAPSHOT_COUNT $snapshot_count SNAPSHOT_TAI $snapshot_tai \
    SNAPSHOT_CYCLES $snapshot_cycles SPLL_SEQ_STATE $spll_seq \
    PSTAT_LOCKED $pstat_locked MAIN_FREQ_LOCKED $main_freq_locked \
    MAIN_PHASE_LOCKED $main_phase_locked MAIN_LOCKED $main_locked \
    PTP_STATE $ptp_state PD_STATE $pd_state EXT_STATE $ext_state \
    WRC_MODE $wrc_mode WR_STATE_VALUE $wr_state_value \
    TARGET_TAI_SOURCE $target_tai_source STEP6B_ARM_SOURCE $step6b_arm_source \
    STEP6B_ARM_SYNC $step6b_arm_sync STEP6B_ARMED $step6b_armed \
    STEP6B_FIRED $step6b_fired STEP6B_FIRE_COUNT $fire_count \
    STEP6B_ARM_TIME_VALID $step6b_arm_time_valid \
    STEP6B_ARM_PPS_VALID $step6b_arm_pps_valid \
    STEP6B_ARM_TM_LINK $step6b_arm_tm_link STEP6B_ARM_LINK_OK $step6b_arm_link_ok \
    STEP6B_ARM_SYNC_PREV $step6b_arm_sync_prev STEP6B_LATCHED_TAI $latched_tai \
    STEP6B_ACTUAL_TAI $actual_tai STEP6B_ACTUAL_CYCLES $actual_cycles \
    STEP6B_FIXED_TARGET_CYCLES $fixed_target_cycles \
    STEP6B_ACTUAL_FIRED $actual_fired STEP6B_ACTUAL_ARMED $actual_armed \
    BOOT_GENERATION $boot_generation CPU_RESET_COUNT $cpu_reset_count \
    WR_CORE_RESET_COUNT $wr_core_reset_count SI_CONFIG_DROP_COUNT $si_config_drop_count]
}

proc s6b_open_board {hardware_name} {
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { error "no device for $hardware_name" }
  catch {end_insystem_source_probe}
  start_insystem_source_probe -hardware_name $hardware_name \
    -device_name [lindex $devices 0]
  wb_sync_toggle
}

proc s6b_collect {hardware_name role sample elapsed_ms} {
  set snapshot {}
  if {[catch {
    s6b_open_board $hardware_name
    set snapshot [s6b_capture $hardware_name $role $sample $elapsed_ms]
  } error_message]} {
    set snapshot {}
  }
  catch {end_insystem_source_probe}
  return $snapshot
}

proc s6b_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc s6b_write_source {hardware_name role index value width} {
  set ok 1
  if {[catch {
    s6b_open_board $hardware_name
    if {$width == 40} {
      write_source_data -instance_index $index \
        -value [format %010X $value] -value_in_hex
    } else {
      write_source_data -instance_index $index \
        -value [format %01X $value] -value_in_hex
    }
  } error_message]} {
    set ok 0
  }
  catch {end_insystem_source_probe}
  puts [format "S6B_SOURCE_WRITE BOARD=%s ROLE=%s INDEX=%d VALUE=%s OK=%d" \
    $role $role $index [expr {$width == 40 ? [format %010X $value] : [format %01X $value]}] $ok]
  flush stdout
  return $ok
}

proc s6b_restart_slave_ptp {hardware_name} {
  if {$::s6b_ptp_restart_used} { return 0 }
  set stop_ok 0
  if {[catch {
    s6b_open_board $hardware_name
    set stop_ok [wf_send_vuart $hardware_name "ptp stop\n" STEP6B_STOP]
  }]} { set stop_ok 0 }
  catch {end_insystem_source_probe}

  set start_ok 0
  if {$stop_ok} {
    after 100
    if {[catch {
      s6b_open_board $hardware_name
      set start_ok [wf_send_vuart $hardware_name "ptp start\n" STEP6B_START]
    }]} { set start_ok 0 }
    catch {end_insystem_source_probe}
  }
  if {$stop_ok && $start_ok} {
    set ::s6b_ptp_restart_used 1
    puts "S6B_TERMINAL_FALLBACK_RECOVERY=PASS SLAVE_PTP_STOP_COUNT=1 SLAVE_PTP_START_COUNT=1 MASTER_PTP_RESTART_COUNT=0"
    flush stdout
    return 1
  }
  puts [format "S6B_TERMINAL_FALLBACK_RECOVERY=INCONCLUSIVE_COMMAND_TRANSPORT SLAVE_PTP_STOP_COUNT=%d SLAVE_PTP_START_COUNT=%d MASTER_PTP_RESTART_COUNT=0" \
    [expr {$stop_ok ? 1 : 0}] [expr {$start_ok ? 1 : 0}]]
  flush stdout
  return 0
}

proc s6b_snapshot_map_update {role snapshot} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  if {$row(SNAPSHOT_ACCEPTED) != 1} { return 0 }
  set tai $row(SNAPSHOT_TAI)
  set cycles $row(SNAPSHOT_CYCLES)
  if {$tai < 0 || $cycles < 0} { return 0 }
  if {$role eq "MASTER"} {
    if {[info exists ::s6b_master_by_tai($tai)] &&
        $::s6b_master_by_tai($tai) != $cycles} {
      set ::s6b_coherence_violation 1
    }
    set ::s6b_master_by_tai($tai) $cycles
  } else {
    if {[info exists ::s6b_slave_by_tai($tai)] &&
        $::s6b_slave_by_tai($tai) != $cycles} {
      set ::s6b_coherence_violation 1
    }
    set ::s6b_slave_by_tai($tai) $cycles
  }
  return 1
}

proc s6b_common_tais {} {
  set result {}
  foreach tai [array names ::s6b_master_by_tai] {
    if {[info exists ::s6b_slave_by_tai($tai)] &&
        $::s6b_master_by_tai($tai) == $::s6b_slave_by_tai($tai)} {
      lappend result $tai
    }
  }
  return [lsort -integer $result]
}

proc s6b_runtime_bad {master slave} {
  if {$master eq "" || $slave eq ""} { return 1 }
  array set m $master
  array set s $slave
  return [expr {$m(READ_VALID) != 1 || $s(READ_VALID) != 1 ||
      $m(RESET_CHANGED) != 0 || $s(RESET_CHANGED) != 0 ||
      $m(CAPTURE_HEALTHY) != 1 || $s(CAPTURE_HEALTHY) != 1 ||
      $m(STATUS_TIME_VALID) != 1 || $s(STATUS_TIME_VALID) != 1 ||
      $m(STATUS_TM_LINK_UP) != 1 || $s(STATUS_TM_LINK_UP) != 1 ||
      $m(STATUS_LINK_OK) != 1 || $s(STATUS_LINK_OK) != 1 ||
      $s(PLL_READY) != 1}]
}

proc s6b_emit_board_samples {master slave prefix} {
  if {$master ne ""} { s6b_emit $prefix $master }
  if {$slave ne ""} { s6b_emit $prefix $slave }
}

proc s6a_reset_ok {snapshot} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  foreach key {BOOT_GENERATION CPU_RESET_COUNT WR_CORE_RESET_COUNT \
      SI_CONFIG_DROP_COUNT RESET_CHANGED} {
    if {![info exists row($key)] ||
        ![string is integer -strict $row($key)]} { return 0 }
  }
  return [expr {$row(BOOT_GENERATION) == 1 &&
      $row(CPU_RESET_COUNT) == 1 && $row(WR_CORE_RESET_COUNT) == 1 &&
      $row(SI_CONFIG_DROP_COUNT) == 1 && $row(RESET_CHANGED) == 0}]
}

proc s6a_master_gate_ok {snapshot} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  return [expr {$row(READ_VALID) == 1 && [s6a_reset_ok $snapshot] &&
      $row(STATUS_LINK_OK) == 1 && $row(STATUS_TM_LINK_UP) == 1 &&
      $row(STATUS_TIME_VALID) == 1 && $row(SNAPSHOT_VALID) == 1}]
}

proc s6a_slave_active_gate_ok {snapshot} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  return [expr {$row(READ_VALID) == 1 && [s6a_reset_ok $snapshot] &&
      $row(STATUS_LINK_OK) == 1 && $row(STATUS_TM_LINK_UP) == 1 &&
      $row(RX_LOCKED_TO_DATA) == 1 && $row(RX_PATTERN_READY) == 1 &&
      $row(SPLL_SEQ_STATE) == 8 && $row(PSTAT_LOCKED) == 1 &&
      $row(MAIN_FREQ_LOCKED) == 1 && $row(MAIN_PHASE_LOCKED) == 1 &&
      $row(MAIN_LOCKED) == 1 && $row(PTP_STATE) == 9 &&
      $row(PD_STATE) == 3 && $row(EXT_STATE) == 1 && $row(WRC_MODE) == 3}]
}

proc s6a_slave_time_valid_ok {snapshot} {
  if {![s6a_slave_active_gate_ok $snapshot]} { return 0 }
  array set row $snapshot
  return [expr {$row(STATUS_TIME_VALID) == 1 && $row(STATUS_PPS_VALID) == 1 &&
      $row(SNAPSHOT_ACCEPTED) == 1 && $row(SNAPSHOT_VALID) == 1 &&
      $row(SNAPSHOT_TIME_VALID) == 1 && $row(SNAPSHOT_PPS_VALID) == 1}]
}

proc s6a_late_tail_run {} {
  set master_hardware ""
  set slave_hardware ""
  foreach hardware_name [get_hardware_names] {
    if {[string first "1-11.1" $hardware_name] >= 0} {
      set master_hardware $hardware_name
    } elseif {[string first "1-11.2" $hardware_name] >= 0} {
      set slave_hardware $hardware_name
    }
  }
  if {$master_hardware eq "" || $slave_hardware eq ""} {
    error "both DE5a targets are required"
  }

  puts [format "S6A_TAIL_CONFIG trial=%s window_ms=%d cadence_request_ms=%d MASTER_PROGRAM=0 SLAVE_PROGRAM=0 PTP_RESTART=0 POWER_CYCLE=0 TARGET_WRITE=0 ARM_WRITE=0" \
    $::s6b_trial_id $::s6a_tail_window_ms $::s6a_tail_gap_ms]
  flush stdout

  set gate_pairs 0
  set gate_start [clock milliseconds]
  for {set gate_sample 0} {$gate_sample < 3} {incr gate_sample} {
    set elapsed [expr {[clock milliseconds] - $gate_start}]
    set master [s6b_collect $master_hardware MASTER $gate_sample $elapsed]
    set slave [s6b_collect $slave_hardware SLAVE $gate_sample $elapsed]
    s6b_emit_board_samples $master $slave S6A_CURRENT_GATE_SAMPLE
    set master_gate [s6a_master_gate_ok $master]
    set slave_gate [s6a_slave_active_gate_ok $slave]
    if {$master_gate && $slave_gate} { incr gate_pairs }
    set reset_ok [expr {$master ne "" && $slave ne "" &&
        [s6a_reset_ok $master] && [s6a_reset_ok $slave]}]
    set master_time_valid 0
    if {$master ne ""} {
      array set master_row $master
      set master_time_valid $master_row(STATUS_TIME_VALID)
    }
    set slave_time_valid 0
    if {$slave ne ""} {
      array set slave_row $slave
      set slave_time_valid $slave_row(STATUS_TIME_VALID)
    }
    s6b_emit S6A_CURRENT_GATE_PAIR [list SAMPLE $gate_sample ELAPSED_MS $elapsed \
      MASTER_GATE $master_gate SLAVE_ACTIVE_GATE $slave_gate RESET_STABLE $reset_ok \
      MASTER_TIME_VALID $master_time_valid SLAVE_TIME_VALID $slave_time_valid]
    if {$gate_sample < 2} { after $::s6a_tail_gap_ms }
  }
  if {$gate_pairs < 3} {
    puts [format "S6A_TAIL_RESULT=INCONCLUSIVE_CURRENT_SESSION_PRECONDITION_CHANGED GATE_PAIRS=%d TAIL_SAMPLES=0 VALID_SAMPLES=0 MAX_VALID_STREAK=0 SNAPSHOT_DELTA=0 COMMON_TAI_COUNT=0 MAX_ABS_DELTA_TICKS=NA" $gate_pairs]
    puts "S6A_DONE result=INCONCLUSIVE_CURRENT_SESSION_PRECONDITION_CHANGED phase=gate"
    flush stdout
    return
  }

  array set ::s6b_master_by_tai {}
  array set ::s6b_slave_by_tai {}
  set ::s6b_coherence_violation 0
  set tail_start [clock milliseconds]
  set tail_deadline [expr {$tail_start + $::s6a_tail_window_ms}]
  set tail_sample 0
  set tail_samples 0
  set valid_samples 0
  set valid_streak 0
  set max_valid_streak 0
  set snapshot_first -1
  set snapshot_last -1
  set active_samples 0
  set active_seen 0
  set terminal_streak 0
  set softpll_bad_streak 0
  set state_changed 0
  set pass_candidate 0
  set time_valid_prev -1
  set time_valid_rising 0
  set time_valid_falling 0
  set first_valid_elapsed -1
  set last_valid_elapsed -1
  set result ""
  set final_master {}
  set final_slave {}

  while {[clock milliseconds] <= $tail_deadline} {
    set elapsed [expr {[clock milliseconds] - $tail_start}]
    set master [s6b_collect $master_hardware MASTER $tail_sample $elapsed]
    set slave [s6b_collect $slave_hardware SLAVE $tail_sample $elapsed]
    incr tail_samples
    set final_master $master
    set final_slave $slave
    s6b_emit_board_samples $master $slave S6A_TAIL_SAMPLE
    if {$master eq "" || $slave eq ""} {
      set state_changed 1
      set result "INCONCLUSIVE_CURRENT_SESSION_PRECONDITION_CHANGED"
      break
    }
    array set m $master
    array set s $slave
    set master_ok [s6a_master_gate_ok $master]
    set slave_active [s6a_slave_active_gate_ok $slave]
    set slave_valid [s6a_slave_time_valid_ok $slave]
    set reset_ok [expr {[s6a_reset_ok $master] && [s6a_reset_ok $slave]}]
    set terminal_now [expr {$s(PTP_STATE) == 9 && $s(PD_STATE) == 4 &&
        $s(EXT_STATE) == 2 && $s(WR_STATE_VALUE) == 0}]
    set softpll_bad [expr {$s(SPLL_SEQ_STATE) != 8 || $s(PSTAT_LOCKED) != 1 ||
        $s(MAIN_LOCKED) != 1}]
    if {!$reset_ok || !$master_ok} {
      set state_changed 1
      set result "INCONCLUSIVE_CURRENT_SESSION_PRECONDITION_CHANGED"
      break
    }
    if {!$slave_active && !$terminal_now && !$softpll_bad} {
      set state_changed 1
      set result "INCONCLUSIVE_CURRENT_SESSION_PRECONDITION_CHANGED"
      break
    }
    if {$slave_active} {
      set active_seen 1
      incr active_samples
    }
    if {$time_valid_prev >= 0} {
      if {!$time_valid_prev && $s(STATUS_TIME_VALID) == 1} { incr time_valid_rising }
      if {$time_valid_prev && $s(STATUS_TIME_VALID) == 0} { incr time_valid_falling }
    }
    set time_valid_prev $s(STATUS_TIME_VALID)
    if {$slave_valid} {
      incr valid_samples
      incr valid_streak
      if {$valid_streak > $max_valid_streak} { set max_valid_streak $valid_streak }
      if {$first_valid_elapsed < 0} { set first_valid_elapsed $elapsed }
      set last_valid_elapsed $elapsed
      if {$snapshot_first < 0} { set snapshot_first $s(SNAPSHOT_COUNT) }
      set snapshot_last $s(SNAPSHOT_COUNT)
      s6b_snapshot_map_update MASTER $master
      s6b_snapshot_map_update SLAVE $slave
    } else {
      set valid_streak 0
    }
    if {$terminal_now} { incr terminal_streak } else { set terminal_streak 0 }
    if {$softpll_bad} { incr softpll_bad_streak } else { set softpll_bad_streak 0 }
    set common [s6b_common_tais]
    s6b_emit S6A_TAIL_PAIR [list SAMPLE $tail_sample ELAPSED_MS $elapsed \
      MASTER_GATE $master_ok SLAVE_ACTIVE_GATE $slave_active SLAVE_TIME_VALID $slave_valid \
      SLAVE_SNAPSHOT_COUNT $s(SNAPSHOT_COUNT) VALID_STREAK $valid_streak \
      COMMON_TAI_COUNT [llength $common] RESET_STABLE $reset_ok \
      TERMINAL_STREAK $terminal_streak SOFTPLL_BAD_STREAK $softpll_bad_streak]
    if {$terminal_streak >= 3} {
      set result "FAIL_ACTIVE_EXTENSION_TRANSITIONED_TO_TERMINAL_FALLBACK"
      break
    }
    if {$softpll_bad_streak >= 3} {
      set result "FAIL_SOFTPLL_READY_STATE_LOST_DURING_ACTIVE_EXTENSION_TAIL"
      break
    }
    set snapshot_delta 0
    if {$snapshot_first >= 0 && $snapshot_last >= 0} {
      set snapshot_delta [expr {$snapshot_last - $snapshot_first}]
    }
    if {$valid_streak >= 5 && $snapshot_delta >= 2 && [llength $common] >= 3 &&
        !$::s6b_coherence_violation && !$state_changed} {
      set pass_candidate 1
    }
    incr tail_sample
    after $::s6a_tail_gap_ms
  }

  if {$result eq ""} {
    set snapshot_delta 0
    if {$snapshot_first >= 0 && $snapshot_last >= 0} {
      set snapshot_delta [expr {$snapshot_last - $snapshot_first}]
    }
    if {$state_changed} {
      set result "INCONCLUSIVE_CURRENT_SESSION_PRECONDITION_CHANGED"
    } elseif {$pass_candidate && $valid_streak >= 5 && $snapshot_delta >= 2 &&
        [llength $common] >= 3 && !$::s6b_coherence_violation} {
      set result "PASS_ACTIVE_EXTENSION_LATE_GLOBAL_TIME_RECOVERY"
    } elseif {$valid_samples > 0} {
      set result "FAIL_INTERMITTENT_GLOBAL_TIME_VALIDITY"
    } elseif {$active_seen && $active_samples == $tail_samples && $tail_samples > 0} {
      set result "FAIL_ACTIVE_EXTENSION_GLOBAL_TIME_STUCK"
    } else {
      set result "INCONCLUSIVE_ACTIVE_EXTENSION_NOT_MAINTAINED"
    }
  }
  set common [s6b_common_tais]
  set max_delta NA
  if {[llength $common] > 0} {
    set max_delta 0
    foreach tai $common {
      set delta [expr {abs($::s6b_master_by_tai($tai) - $::s6b_slave_by_tai($tai))}]
      if {$delta > $max_delta} { set max_delta $delta }
    }
  }
  puts [format "S6A_TAIL_RESULT=%s GATE_PAIRS=%d TAIL_SAMPLES=%d VALID_SAMPLES=%d MAX_VALID_STREAK=%d FIRST_VALID_MS=%d LAST_VALID_MS=%d SNAPSHOT_DELTA=%d COMMON_TAI_COUNT=%d MAX_ABS_DELTA_TICKS=%s TIME_VALID_RISING=%d TIME_VALID_FALLING=%d ACTIVE_SAMPLES=%d COHERENCE_VIOLATION=%d" \
    $result $gate_pairs $tail_samples $valid_samples $max_valid_streak \
    $first_valid_elapsed $last_valid_elapsed $snapshot_delta [llength $common] \
    $max_delta $time_valid_rising $time_valid_falling $active_samples \
    $::s6b_coherence_violation]
  puts [format "S6A_DONE result=%s phase=tail" $result]
  flush stdout
}

proc s6b_live_common_gate_ok {snapshot role} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  set common_ok [expr {$row(READ_VALID) == 1 && [s6a_reset_ok $snapshot] &&
      $row(STATUS_LINK_OK) == 1 && $row(STATUS_TM_LINK_UP) == 1 &&
      $row(STATUS_TIME_VALID) == 1 && $row(STATUS_PPS_VALID) == 1 &&
      $row(SNAPSHOT_ACCEPTED) == 1 && $row(SNAPSHOT_VALID) == 1 &&
      $row(SNAPSHOT_TIME_VALID) == 1 && $row(SNAPSHOT_PPS_VALID) == 1}]
  if {!$common_ok} { return 0 }
  if {$role eq "SLAVE"} {
    return [expr {$row(RX_LOCKED_TO_DATA) == 1 &&
        $row(RX_PATTERN_READY) == 1 && $row(SPLL_SEQ_STATE) == 8 &&
        $row(PSTAT_LOCKED) == 1 && $row(MAIN_LOCKED) == 1 &&
        $row(PD_STATE) == 3 && $row(EXT_STATE) == 1}]
  }
  return 1
}

proc s6b_live_initial_pristine {snapshot} {
  if {$snapshot eq ""} { return 0 }
  array set row $snapshot
  return [expr {[s6b_live_common_gate_ok $snapshot $row(ROLE)] &&
      $row(TARGET_TAI_SOURCE) == 0 && $row(STEP6B_ARM_SOURCE) == 0 &&
      $row(STEP6B_ARM_SYNC) == 0 && $row(STEP6B_ARMED) == 0 &&
      $row(STEP6B_FIRED) == 0 && $row(STEP6B_FIRE_COUNT) == 0 &&
      $row(STEP6B_ACTUAL_TAI) == 0 && $row(STEP6B_ACTUAL_CYCLES) == 0}]
}

proc s6b_live_now_ticks {snapshot} {
  if {$snapshot eq ""} { return -1 }
  array set row $snapshot
  if {$row(LIVE_TAI) < 0 || $row(LIVE_CYCLES) < 0} { return -1 }
  return [expr {$row(LIVE_TAI) * 125000000 + $row(LIVE_CYCLES)}]
}

proc s6b_live_target_delta_ticks {snapshot target_tai target_cycles} {
  set now [s6b_live_now_ticks $snapshot]
  if {$now < 0 || ![string is integer -strict $target_tai]} { return -1 }
  return [expr {$target_tai * 125000000 + $target_cycles - $now}]
}

proc s6b_live_emit_result {result phase} {
  set ::s6b_live_result $result
  puts [format "S6B_LIVE_RESULT=%s PHASE=%s TRIAL=%s T0=%s TARGET_TAI=%s TARGET_CYCLES=%s GATE_PAIRS=%s COMMON_TAI_COUNT=%s COHERENCE_VIOLATION=%s TARGET_WRITE_MASTER=%s TARGET_WRITE_SLAVE=%s ARM_WRITE_MASTER=%s ARM_WRITE_SLAVE=%s CAPTURE_SAMPLES=%s POST_FIRE_SAMPLES=%s MASTER_FIRED=%s SLAVE_FIRED=%s MASTER_FIRE_COUNT=%s SLAVE_FIRE_COUNT=%s MASTER_ACTUAL_TAI=%s MASTER_ACTUAL_CYCLES=%s SLAVE_ACTUAL_TAI=%s SLAVE_ACTUAL_CYCLES=%s DIGITAL_TRIGGER_DELTA_TICKS=%s DIGITAL_TRIGGER_DELTA_NS=%s" \
    $result $phase $::s6b_trial_id $::s6b_live_t0 $::s6b_live_target_tai \
    $::s6b_live_target_cycles $::s6b_live_gate_pairs $::s6b_live_common_tai_count \
    $::s6b_coherence_violation $::s6b_live_target_write_master \
    $::s6b_live_target_write_slave $::s6b_live_arm_write_master \
    $::s6b_live_arm_write_slave $::s6b_live_capture_samples \
    $::s6b_live_post_fire_samples $::s6b_live_master_fired \
    $::s6b_live_slave_fired $::s6b_live_master_count $::s6b_live_slave_count \
    $::s6b_live_master_actual_tai $::s6b_live_master_actual_cycles \
    $::s6b_live_slave_actual_tai $::s6b_live_slave_actual_cycles \
    $::s6b_live_delta_ticks $::s6b_live_delta_ns]
  puts [format "S6B_LIVE_DONE result=%s phase=%s" $result $phase]
  flush stdout
}

proc s6b_live_session_run {} {
  set master_hardware ""
  set slave_hardware ""
  foreach hardware_name [get_hardware_names] {
    if {[string first "1-11.1" $hardware_name] >= 0} {
      set master_hardware $hardware_name
    } elseif {[string first "1-11.2" $hardware_name] >= 0} {
      set slave_hardware $hardware_name
    }
  }
  if {$master_hardware eq "" || $slave_hardware eq ""} {
    error "both DE5a targets are required"
  }

  set ::s6b_live_t0 NA
  set ::s6b_live_target_tai NA
  set ::s6b_live_target_cycles $::s6b_target_cycles
  set ::s6b_live_gate_pairs 0
  set ::s6b_live_common_tai_count 0
  set ::s6b_live_target_write_master 0
  set ::s6b_live_target_write_slave 0
  set ::s6b_live_arm_write_master 0
  set ::s6b_live_arm_write_slave 0
  set ::s6b_live_capture_samples 0
  set ::s6b_live_post_fire_samples 0
  set ::s6b_live_master_fired 0
  set ::s6b_live_slave_fired 0
  set ::s6b_live_master_count 0
  set ::s6b_live_slave_count 0
  set ::s6b_live_master_actual_tai 0
  set ::s6b_live_master_actual_cycles 0
  set ::s6b_live_slave_actual_tai 0
  set ::s6b_live_slave_actual_cycles 0
  set ::s6b_live_delta_ticks NA
  set ::s6b_live_delta_ns NA

  puts [format "S6B_LIVE_CONFIG trial=%s gate_timeout_ms=%d gate_gap_ms=%d target_settle_ms=%d arm_settle_ms=%d capture_gap_ms=%d TARGET_SOURCE_INDEX=67 ARM_SOURCE_INDEX=68 TARGET_CYCLES=%d MASTER_PROGRAM=0 SLAVE_PROGRAM=0 MASTER_COMPILE=0 SLAVE_COMPILE=0 FIRMWARE_BUILD=0 PTP_RESTART=0 POWER_CYCLE=0" \
    $::s6b_trial_id $::s6b_live_gate_timeout_ms $::s6b_live_gate_gap_ms \
    $::s6b_live_target_settle_ms $::s6b_live_arm_settle_ms \
    $::s6b_live_capture_gap_ms $::s6b_target_cycles]
  flush stdout

  array set ::s6b_master_by_tai {}
  array set ::s6b_slave_by_tai {}
  set ::s6b_coherence_violation 0
  set gate_start [clock milliseconds]
  set sample 0
  set last_master {}
  set last_slave {}
  while {[clock milliseconds] - $gate_start <= $::s6b_live_gate_timeout_ms} {
    set elapsed [expr {[clock milliseconds] - $gate_start}]
    set master [s6b_collect $master_hardware MASTER $sample $elapsed]
    set slave [s6b_collect $slave_hardware SLAVE $sample $elapsed]
    set last_master $master
    set last_slave $slave
    s6b_emit_board_samples $master $slave S6B_LIVE_PREWRITE_SAMPLE
    set master_gate [s6b_live_common_gate_ok $master MASTER]
    set slave_gate [s6b_live_common_gate_ok $slave SLAVE]
    if {$master_gate && $slave_gate} {
      s6b_snapshot_map_update MASTER $master
      s6b_snapshot_map_update SLAVE $slave
      incr ::s6b_live_gate_pairs
    }
    set common [s6b_common_tais]
    set ::s6b_live_common_tai_count [llength $common]
    s6b_emit S6B_LIVE_PREWRITE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
      MASTER_GATE $master_gate SLAVE_GATE $slave_gate \
      GATE_PAIRS $::s6b_live_gate_pairs COMMON_TAI_COUNT $::s6b_live_common_tai_count \
      COHERENCE_VIOLATION $::s6b_coherence_violation]
    if {$::s6b_live_gate_pairs >= 3 &&
        $::s6b_live_common_tai_count >= 3 &&
        !$::s6b_coherence_violation} { break }
    incr sample
    after $::s6b_live_gate_gap_ms
  }

  set common [s6b_common_tais]
  set ::s6b_live_common_tai_count [llength $common]
  if {$::s6b_live_gate_pairs < 3 || $::s6b_live_common_tai_count < 3 ||
      $::s6b_coherence_violation} {
    s6b_live_emit_result INCONCLUSIVE_LIVE_SESSION_PREWRITE_GATE_FAILED prewrite_gate
    return
  }

  set ::s6b_live_t0 [lindex $common end]
  set ::s6b_live_target_tai [expr {$::s6b_live_t0 + 20}]
  puts [format "S6B_LIVE_PREWRITE_GATE_RESULT=PASS GATE_PAIRS=%d COMMON_TAI_COUNT=%d T0=%d" \
    $::s6b_live_gate_pairs $::s6b_live_common_tai_count $::s6b_live_t0]
  flush stdout

  set initial_master [s6b_collect $master_hardware MASTER 0 0]
  set initial_slave [s6b_collect $slave_hardware SLAVE 0 0]
  s6b_emit_board_samples $initial_master $initial_slave S6B_LIVE_INITIAL_SAMPLE
  set initial_ok [expr {[s6b_live_initial_pristine $initial_master] &&
      [s6b_live_initial_pristine $initial_slave]}]
  set initial_master_arm NA
  set initial_slave_arm NA
  set initial_master_target NA
  set initial_slave_target NA
  set initial_master_sync NA
  set initial_slave_sync NA
  set initial_master_armed NA
  set initial_slave_armed NA
  set initial_master_fired NA
  set initial_slave_fired NA
  set initial_master_count NA
  set initial_slave_count NA
  if {$initial_master ne ""} {
    array set initial_m $initial_master
    set initial_master_target $initial_m(TARGET_TAI_SOURCE)
    set initial_master_arm $initial_m(STEP6B_ARM_SOURCE)
    set initial_master_sync $initial_m(STEP6B_ARM_SYNC)
    set initial_master_armed $initial_m(STEP6B_ARMED)
    set initial_master_fired $initial_m(STEP6B_FIRED)
    set initial_master_count $initial_m(STEP6B_FIRE_COUNT)
  }
  if {$initial_slave ne ""} {
    array set initial_s $initial_slave
    set initial_slave_target $initial_s(TARGET_TAI_SOURCE)
    set initial_slave_arm $initial_s(STEP6B_ARM_SOURCE)
    set initial_slave_sync $initial_s(STEP6B_ARM_SYNC)
    set initial_slave_armed $initial_s(STEP6B_ARMED)
    set initial_slave_fired $initial_s(STEP6B_FIRED)
    set initial_slave_count $initial_s(STEP6B_FIRE_COUNT)
  }
  puts [format "S6B_LIVE_INITIAL_STATE_RESULT=%s MASTER_TARGET=%s SLAVE_TARGET=%s MASTER_ARM=%s SLAVE_ARM=%s MASTER_ARM_SYNC=%s SLAVE_ARM_SYNC=%s MASTER_ARMED=%s SLAVE_ARMED=%s MASTER_FIRED=%s SLAVE_FIRED=%s MASTER_FIRE_COUNT=%s SLAVE_FIRE_COUNT=%s" \
    [expr {$initial_ok ? "PASS" : "INCONCLUSIVE_STEP6B_INITIAL_STATE_NOT_PRISTINE"}] \
    $initial_master_target $initial_slave_target $initial_master_arm $initial_slave_arm \
    $initial_master_sync $initial_slave_sync $initial_master_armed $initial_slave_armed \
    $initial_master_fired $initial_slave_fired \
    $initial_master_count $initial_slave_count]
  flush stdout
  if {!$initial_ok} {
    s6b_live_emit_result INCONCLUSIVE_STEP6B_INITIAL_STATE_NOT_PRISTINE initial_state
    return
  }

  puts [format "S6B_LIVE_TARGET_SELECTED T0=%d TARGET_TAI=%d TARGET_CYCLES=%d" \
    $::s6b_live_t0 $::s6b_live_target_tai $::s6b_target_cycles]
  flush stdout

  if {[s6b_write_source $master_hardware MASTER 67 $::s6b_live_target_tai 40]} {
    set ::s6b_live_target_write_master 1
  } else {
    s6b_live_emit_result INCONCLUSIVE_SOURCE_WRITE_FAILURE target_write
    return
  }
  if {[s6b_write_source $slave_hardware SLAVE 67 $::s6b_live_target_tai 40]} {
    set ::s6b_live_target_write_slave 1
  } else {
    s6b_live_emit_result INCONCLUSIVE_SOURCE_WRITE_FAILURE target_write
    return
  }
  after $::s6b_live_target_settle_ms

  set target_master [s6b_collect $master_hardware MASTER 0 0]
  set target_slave [s6b_collect $slave_hardware SLAVE 0 0]
  s6b_emit_board_samples $target_master $target_slave S6B_LIVE_TARGET_VERIFY_SAMPLE
  set target_verify_ok [expr {[s6b_live_common_gate_ok $target_master MASTER] &&
      [s6b_live_common_gate_ok $target_slave SLAVE]}]
  foreach snapshot [list $target_master $target_slave] {
    if {$snapshot eq ""} { set target_verify_ok 0; continue }
    array set row $snapshot
    if {$row(TARGET_TAI_SOURCE) != $::s6b_live_target_tai ||
        $row(STEP6B_ARM_SOURCE) != 0 || $row(STEP6B_FIRED) != 0 ||
        $row(STEP6B_FIRE_COUNT) != 0} { set target_verify_ok 0 }
  }
  puts [format "S6B_LIVE_TARGET_VERIFY_RESULT=%s TARGET_TAI=%d" \
    [expr {$target_verify_ok ? "PASS" : "INCONCLUSIVE_TARGET_WRITE_OR_READBACK_MISMATCH"}] \
    $::s6b_live_target_tai]
  flush stdout
  if {!$target_verify_ok} {
    s6b_live_emit_result INCONCLUSIVE_TARGET_WRITE_OR_READBACK_MISMATCH target_verify
    return
  }

  set master_delta [s6b_live_target_delta_ticks $target_master \
    $::s6b_live_target_tai $::s6b_target_cycles]
  set slave_delta [s6b_live_target_delta_ticks $target_slave \
    $::s6b_live_target_tai $::s6b_target_cycles]
  set min_delta $master_delta
  if {$min_delta < 0 || ($slave_delta >= 0 && $slave_delta < $min_delta)} {
    set min_delta $slave_delta
  }
  puts [format "S6B_LIVE_PREARM_TIME_GATE MASTER_REMAINING_TICKS=%s SLAVE_REMAINING_TICKS=%s MIN_REMAINING_TICKS=%s REQUIRED_REMAINING_TICKS=%d" \
    $master_delta $slave_delta $min_delta [expr {12 * 125000000}]]
  flush stdout
  if {$master_delta < 12 * 125000000 || $slave_delta < 12 * 125000000} {
    s6b_live_emit_result INCONCLUSIVE_TARGET_WINDOW_TOO_CLOSE prearm_time_gate
    return
  }

  if {[s6b_write_source $master_hardware MASTER 68 1 1]} {
    set ::s6b_live_arm_write_master 1
  } else {
    s6b_live_emit_result INCONCLUSIVE_SOURCE_WRITE_FAILURE arm_write
    return
  }
  if {[s6b_write_source $slave_hardware SLAVE 68 1 1]} {
    set ::s6b_live_arm_write_slave 1
  } else {
    s6b_live_emit_result INCONCLUSIVE_SOURCE_WRITE_FAILURE arm_write
    return
  }
  after $::s6b_live_arm_settle_ms

  set arm_master [s6b_collect $master_hardware MASTER 0 0]
  set arm_slave [s6b_collect $slave_hardware SLAVE 0 0]
  s6b_emit_board_samples $arm_master $arm_slave S6B_LIVE_ARM_VERIFY_SAMPLE
  set arm_state_ok 1
  set arm_latch_ok 1
  set arm_remaining_ok 1
  foreach snapshot [list $arm_master $arm_slave] {
    if {$snapshot eq ""} {
      set arm_state_ok 0
      set arm_latch_ok 0
      set arm_remaining_ok 0
      continue
    }
    array set row $snapshot
    if {![s6b_live_common_gate_ok $snapshot $row(ROLE)] ||
        $row(TARGET_TAI_SOURCE) != $::s6b_live_target_tai ||
        $row(STEP6B_ARM_SOURCE) != 1 || $row(STEP6B_ARM_SYNC) != 1 ||
        $row(STEP6B_ARMED) != 1 || $row(STEP6B_FIRED) != 0 ||
        $row(STEP6B_FIRE_COUNT) != 0} { set arm_state_ok 0 }
    if {$row(STEP6B_LATCHED_TAI) != $::s6b_live_target_tai} {
      set arm_latch_ok 0
    }
    if {[s6b_live_target_delta_ticks $snapshot $::s6b_live_target_tai \
        $::s6b_target_cycles] < 10 * 125000000} { set arm_remaining_ok 0 }
  }
  puts [format "S6B_LIVE_ARM_VERIFY_RESULT=%s TARGET_LATCH=%s REMAINING_OK=%s" \
    [expr {$arm_state_ok && $arm_latch_ok && $arm_remaining_ok ? "PASS" : \
      ($arm_latch_ok ? "INCONCLUSIVE_DUAL_ARM_NOT_ESTABLISHED" : "INCONCLUSIVE_TARGET_LATCH_MISMATCH")}] \
    [expr {$arm_latch_ok ? "PASS" : "FAIL"}] \
    [expr {$arm_remaining_ok ? "PASS" : "FAIL"}]]
  flush stdout
  if {!$arm_latch_ok} {
    s6b_live_emit_result INCONCLUSIVE_TARGET_LATCH_MISMATCH arm_verify
    return
  }
  if {!$arm_state_ok || !$arm_remaining_ok} {
    s6b_live_emit_result INCONCLUSIVE_DUAL_ARM_NOT_ESTABLISHED arm_verify
    return
  }

  set target_ticks [expr {$::s6b_live_target_tai * 125000000 + $::s6b_target_cycles}]
  set target_plus_one [expr {$target_ticks + 125000000}]
  set target_plus_two [expr {$target_ticks + 2 * 125000000}]
  set hard_deadline [expr {[clock milliseconds] + 40000}]
  set capture_sample 0
  set trigger_seen 0
  set result ""
  set final_master $arm_master
  set final_slave $arm_slave
  while {[clock milliseconds] <= $hard_deadline} {
    set master [s6b_collect $master_hardware MASTER $capture_sample 0]
    set slave [s6b_collect $slave_hardware SLAVE $capture_sample 0]
    incr ::s6b_live_capture_samples
    set final_master $master
    set final_slave $slave
    s6b_emit_board_samples $master $slave S6B_LIVE_CAPTURE_SAMPLE
    if {$master eq "" || $slave eq ""} {
      set result INCONCLUSIVE_RUNTIME_STATE_CHANGED
      break
    }
    array set m $master
    array set s $slave
    set ::s6b_live_master_fired $m(STEP6B_FIRED)
    set ::s6b_live_slave_fired $s(STEP6B_FIRED)
    set ::s6b_live_master_count $m(STEP6B_FIRE_COUNT)
    set ::s6b_live_slave_count $s(STEP6B_FIRE_COUNT)
    set ::s6b_live_master_actual_tai $m(STEP6B_ACTUAL_TAI)
    set ::s6b_live_master_actual_cycles $m(STEP6B_ACTUAL_CYCLES)
    set ::s6b_live_slave_actual_tai $s(STEP6B_ACTUAL_TAI)
    set ::s6b_live_slave_actual_cycles $s(STEP6B_ACTUAL_CYCLES)
    set master_now [s6b_live_now_ticks $master]
    set slave_now [s6b_live_now_ticks $slave]
    set now_ticks $master_now
    if {$now_ticks < 0 || ($slave_now >= 0 && $slave_now > $now_ticks)} {
      set now_ticks $slave_now
    }
    set before_target [expr {$now_ticks >= 0 && $now_ticks < $target_ticks}]
    if {$m(STEP6B_FIRE_COUNT) > 1 || $s(STEP6B_FIRE_COUNT) > 1} {
      set result FAIL_TRIGGER_ONE_SHOT_VIOLATION
      break
    }
    if {$before_target && ($m(STEP6B_FIRED) == 1 || $s(STEP6B_FIRED) == 1 ||
        $m(STEP6B_FIRE_COUNT) > 0 || $s(STEP6B_FIRE_COUNT) > 0)} {
      set result FAIL_EARLY_SCHEDULED_TRIGGER
      break
    }
    set runtime_ok [expr {[s6b_live_common_gate_ok $master MASTER] &&
        [s6b_live_common_gate_ok $slave SLAVE]}]
    if {!$runtime_ok} {
      if {$before_target} {
        for {set post 0} {$post < 3} {incr post} {
          after $::s6b_live_capture_gap_ms
          set post_master [s6b_collect $master_hardware MASTER $post 0]
          set post_slave [s6b_collect $slave_hardware SLAVE $post 0]
          s6b_emit_board_samples $post_master $post_slave S6B_LIVE_POST_LOSS_SAMPLE
          incr ::s6b_live_capture_samples
        }
        set result INCONCLUSIVE_STEP6A_STABILITY_LOST_BEFORE_TARGET
      } else {
        set result INCONCLUSIVE_RUNTIME_STATE_CHANGED
      }
      break
    }
    if {$m(STEP6B_FIRED) == 1 && $s(STEP6B_FIRED) == 1} {
      if {!$trigger_seen} {
        set trigger_seen 1
        set ::s6b_live_post_fire_samples 0
        if {$m(STEP6B_ACTUAL_TAI) != $s(STEP6B_ACTUAL_TAI) ||
            $m(STEP6B_ACTUAL_CYCLES) != $s(STEP6B_ACTUAL_CYCLES)} {
          set result FAIL_SCHEDULED_TRIGGER_TIMESTAMP_MISMATCH
          if {$m(STEP6B_ACTUAL_TAI) >= 0 && $s(STEP6B_ACTUAL_TAI) >= 0 &&
              $m(STEP6B_ACTUAL_CYCLES) >= 0 && $s(STEP6B_ACTUAL_CYCLES) >= 0} {
            set ::s6b_live_delta_ticks [expr {($s(STEP6B_ACTUAL_TAI) - $m(STEP6B_ACTUAL_TAI)) * 125000000 +
                $s(STEP6B_ACTUAL_CYCLES) - $m(STEP6B_ACTUAL_CYCLES)}]
            set ::s6b_live_delta_ns [expr {$::s6b_live_delta_ticks * 8}]
          }
          break
        }
        if {$m(STEP6B_ACTUAL_TAI) != $::s6b_live_target_tai ||
            $s(STEP6B_ACTUAL_TAI) != $::s6b_live_target_tai ||
            $m(STEP6B_ACTUAL_CYCLES) != $::s6b_target_cycles ||
            $s(STEP6B_ACTUAL_CYCLES) != $::s6b_target_cycles} {
          set result FAIL_COMMON_TRIGGER_TARGET_MISS
          break
        }
        set ::s6b_live_delta_ticks 0
        set ::s6b_live_delta_ns 0
      } else {
        if {$m(STEP6B_FIRED) != 1 || $s(STEP6B_FIRED) != 1 ||
            $m(STEP6B_FIRE_COUNT) != 1 || $s(STEP6B_FIRE_COUNT) != 1 ||
            $m(STEP6B_ARMED) != 0 || $s(STEP6B_ARMED) != 0} {
          set result FAIL_TRIGGER_ONE_SHOT_VIOLATION
          break
        }
        incr ::s6b_live_post_fire_samples
        if {$::s6b_live_post_fire_samples >= 3} {
          set result PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER
          break
        }
      }
    } elseif {$trigger_seen && ($m(STEP6B_FIRED) != 1 ||
        $s(STEP6B_FIRED) != 1 || $m(STEP6B_FIRE_COUNT) != 1 ||
        $s(STEP6B_FIRE_COUNT) != 1)} {
      set result FAIL_TRIGGER_ONE_SHOT_VIOLATION
      break
    }
    if {!$trigger_seen && $now_ticks >= $target_plus_one} {
      if {$m(STEP6B_FIRE_COUNT) == 1 || $s(STEP6B_FIRE_COUNT) == 1} {
        set result FAIL_ONE_SIDED_SCHEDULED_TRIGGER
      } else {
        set result FAIL_BOTH_BOARDS_MISSED_SCHEDULED_TRIGGER
      }
      break
    }
    if {!$trigger_seen && $now_ticks >= $target_plus_two} {
      set result FAIL_BOTH_BOARDS_MISSED_SCHEDULED_TRIGGER
      break
    }
    incr capture_sample
    after $::s6b_live_capture_gap_ms
  }
  if {$result eq ""} { set result INCONCLUSIVE_RUNTIME_STATE_CHANGED }
  s6b_live_emit_result $result capture
}

proc s6b_run {} {
  set master_hardware ""
  set slave_hardware ""
  foreach hardware_name [get_hardware_names] {
    if {[string first "1-11.1" $hardware_name] >= 0} {
      set master_hardware $hardware_name
    } elseif {[string first "1-11.2" $hardware_name] >= 0} {
      set slave_hardware $hardware_name
    }
  }
  if {$master_hardware eq "" || $slave_hardware eq ""} {
    error "both DE5a targets are required"
  }

  puts [format "S6B_CONFIG trial=%s target_cycles=%d target_source_index=67 arm_source_index=68 latch_probe_index=69 actual_tai_probe_index=70 actual_cycles_probe_index=71 prearm_timeout_ms=%d prearm_gap_ms=%d target_settle_ms=%d arm_settle_ms=%d capture_gap_ms=%d observe_timeout_ms=%d MASTER_COMPILE=0 SLAVE_COMPILE=0 FIRMWARE_BUILD=0 MASTER_PROGRAM=1 SLAVE_PROGRAM=1 POWER_CYCLE=0 CPU_RESET=0 WR_CORE_RESET=0 PTP_RESTART=CONDITIONAL_SLAVE_ONLY SMA_CLKOUT_CHANGED=0" \
    $::s6b_trial_id $::s6b_target_cycles $::s6b_prearm_timeout_ms \
    $::s6b_prearm_gap_ms $::s6b_target_settle_ms $::s6b_arm_settle_ms \
    $::s6b_capture_gap_ms $::s6b_observe_timeout_ms]
  flush stdout

  array set ::s6b_master_by_tai {}
  array set ::s6b_slave_by_tai {}
  set ::s6b_coherence_violation 0
  set gate_pairs 0
  set gate_start [clock milliseconds]
  set sample 0
  set prearm_ok 0
  set terminal_fallback 0
  set prearm_attempt 0
  set last_master {}
  set last_slave {}
  while {$prearm_attempt < 2 && !$prearm_ok} {
    set gate_start [clock milliseconds]
    set sample 0
    set gate_pairs 0
    set terminal_fallback 0
    array unset ::s6b_master_by_tai *
    array unset ::s6b_slave_by_tai *
    set ::s6b_coherence_violation 0
    while {[clock milliseconds] - $gate_start <= $::s6b_prearm_timeout_ms} {
      set elapsed [expr {[clock milliseconds] - $gate_start}]
      set master [s6b_collect $master_hardware MASTER $sample $elapsed]
      set slave [s6b_collect $slave_hardware SLAVE $sample $elapsed]
      set last_master $master
      set last_slave $slave
      s6b_emit_board_samples $master $slave S6B_PREARM_SAMPLE
      if {$master ne "" && $slave ne ""} {
        array set m $master
        array set s $slave
        s6b_snapshot_map_update MASTER $master
        s6b_snapshot_map_update SLAVE $slave
        set master_good [expr {$m(PREARM_HEALTHY) == 1}]
        set slave_good [expr {$s(PREARM_HEALTHY) == 1}]
        if {$m(TERMINAL_FALLBACK) == 1 || $s(TERMINAL_FALLBACK) == 1} {
          set terminal_fallback 1
        }
        if {$master_good && $slave_good && !$m(RESET_CHANGED) &&
            !$s(RESET_CHANGED)} { incr gate_pairs }
        set common [s6b_common_tais]
        s6b_emit S6B_PREARM_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
          READ_VALID 1 MASTER_GATE $master_good SLAVE_GATE $slave_good \
          MASTER_TAI $m(SNAPSHOT_TAI) SLAVE_TAI $s(SNAPSHOT_TAI) \
          MASTER_CYCLES $m(SNAPSHOT_CYCLES) SLAVE_CYCLES $s(SNAPSHOT_CYCLES) \
          COMMON_TAI_COUNT [llength $common] COHERENCE_VIOLATION $::s6b_coherence_violation]
        if {$gate_pairs >= 5 && [llength $common] >= 3 &&
            !$::s6b_coherence_violation} {
          set prearm_ok 1
          break
        }
      } else {
        s6b_emit S6B_PREARM_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
          READ_VALID 0 MASTER_GATE 0 SLAVE_GATE 0 COMMON_TAI_COUNT 0]
      }
      incr sample
      after $::s6b_prearm_gap_ms
    }
    if {$prearm_ok} { break }
    if {$terminal_fallback && !$::s6b_ptp_restart_used} {
      puts "S6B_TERMINAL_FALLBACK_SIGNATURE=PASS"
      flush stdout
      if {![s6b_restart_slave_ptp $slave_hardware]} {
        puts "S6B_GATE_RESULT=INCONCLUSIVE_TERMINAL_FALLBACK_RECOVERY_COMMAND"
        puts "S6B_DONE result=INCONCLUSIVE_TERMINAL_FALLBACK_RECOVERY_COMMAND phase=prearm"
        flush stdout
        return
      }
      incr prearm_attempt
    } else {
      break
    }
  }

  if {!$prearm_ok} {
    set result INCONCLUSIVE_STEP6A_PRECONDITION_NOT_RECOVERED
    if {$terminal_fallback && !$::s6b_ptp_restart_used} {
      set result INCONCLUSIVE_TERMINAL_FALLBACK_RECOVERY_REQUIRED
    }
    if {$::s6b_coherence_violation} { set result INCONCLUSIVE_SNAPSHOT_COHERENCE_VIOLATION }
    puts [format "S6B_GATE_RESULT=%s PAIRED_HEALTHY=%d COMMON_TAI_COUNT=%d COHERENCE_VIOLATION=%d" \
      $result $gate_pairs [llength [s6b_common_tais]] $::s6b_coherence_violation]
    puts [format "S6B_DONE result=%s phase=prearm" $result]
    flush stdout
    return
  }

  set common [s6b_common_tais]
  set t0 [lindex $common end]
  set target_tai [expr {$t0 + 20}]
  puts [format "S6B_GATE_RESULT=PASS PAIRED_HEALTHY=%d COMMON_TAI_COUNT=%d T0=%d" \
    $gate_pairs [llength $common] $t0]
  flush stdout

  set initial_state_ok 1
  foreach snapshot [list $last_master $last_slave] {
    if {$snapshot eq ""} {
      set initial_state_ok 0
      continue
    }
    array set row $snapshot
    if {$row(STEP6B_ARM_SOURCE) != 0 || $row(STEP6B_FIRED) != 0 ||
        $row(STEP6B_FIRE_COUNT) != 0} {
      set initial_state_ok 0
    }
  }
  set initial_result [expr {$initial_state_ok ? "PASS" : "INCONCLUSIVE_STEP6B_INITIAL_STATE_INVALID"}]
  set initial_master_arm NA
  set initial_slave_arm NA
  set initial_master_fired NA
  set initial_slave_fired NA
  set initial_master_count NA
  set initial_slave_count NA
  if {$last_master ne ""} {
    array set initial_m $last_master
    set initial_master_arm $initial_m(STEP6B_ARM_SOURCE)
    set initial_master_fired $initial_m(STEP6B_FIRED)
    set initial_master_count $initial_m(STEP6B_FIRE_COUNT)
  }
  if {$last_slave ne ""} {
    array set initial_s $last_slave
    set initial_slave_arm $initial_s(STEP6B_ARM_SOURCE)
    set initial_slave_fired $initial_s(STEP6B_FIRED)
    set initial_slave_count $initial_s(STEP6B_FIRE_COUNT)
  }
  puts [format "S6B_INITIAL_STATE_RESULT=%s MASTER_ARM_SOURCE=%s SLAVE_ARM_SOURCE=%s MASTER_FIRED=%s SLAVE_FIRED=%s MASTER_FIRE_COUNT=%s SLAVE_FIRE_COUNT=%s" \
    $initial_result $initial_master_arm $initial_slave_arm $initial_master_fired \
    $initial_slave_fired $initial_master_count $initial_slave_count]
  flush stdout
  if {!$initial_state_ok} {
    puts "S6B_DONE result=INCONCLUSIVE_STEP6B_INITIAL_STATE_INVALID phase=initial_state"
    flush stdout
    return
  }

  foreach board [list [list $master_hardware MASTER] [list $slave_hardware SLAVE]] {
    lassign $board hardware role
    if {![s6b_write_source $hardware $role 67 $target_tai 40]} {
      puts "S6B_TARGET_SETUP_RESULT=INCONCLUSIVE_SOURCE_WRITE_FAILURE"
      puts "S6B_DONE result=INCONCLUSIVE_SOURCE_WRITE_FAILURE phase=target_setup"
      flush stdout
      return
    }
  }
  after $::s6b_target_settle_ms
  set target_master [s6b_collect $master_hardware MASTER 0 0]
  set target_slave [s6b_collect $slave_hardware SLAVE 0 0]
  s6b_emit_board_samples $target_master $target_slave S6B_TARGET_VERIFY
  set target_verify_ok 1
  foreach snapshot [list $target_master $target_slave] {
    if {$snapshot eq ""} { set target_verify_ok 0; continue }
    array set row $snapshot
    if {$row(TARGET_TAI_SOURCE) != $target_tai ||
        $row(STEP6B_ARM_SOURCE) != 0 || $row(STEP6B_FIRED) != 0 ||
        $row(STEP6B_FIRE_COUNT) != 0} { set target_verify_ok 0 }
  }
  puts [format "S6B_TARGET_SETUP_RESULT=%s TARGET_TAI=%d TARGET_CYCLES=%d SETTLE_MS=%d" \
    [expr {$target_verify_ok ? "PASS" : "INCONCLUSIVE_TARGET_READBACK_MISMATCH"}] \
    $target_tai $::s6b_target_cycles $::s6b_target_settle_ms]
  flush stdout
  if {!$target_verify_ok} {
    puts "S6B_DONE result=INCONCLUSIVE_TARGET_READBACK_MISMATCH phase=target_setup"
    flush stdout
    return
  }

  if {![s6b_write_source $master_hardware MASTER 68 1 1] ||
      ![s6b_write_source $slave_hardware SLAVE 68 1 1]} {
    puts "S6B_ARM_RESULT=INCONCLUSIVE_SOURCE_WRITE_FAILURE"
    puts "S6B_DONE result=INCONCLUSIVE_SOURCE_WRITE_FAILURE phase=arm"
    flush stdout
    return
  }
  after $::s6b_arm_settle_ms
  set arm_master [s6b_collect $master_hardware MASTER 0 0]
  set arm_slave [s6b_collect $slave_hardware SLAVE 0 0]
  s6b_emit_board_samples $arm_master $arm_slave S6B_ARM_VERIFY
  set arm_ok 1
  set remaining_ok 1
  foreach snapshot [list $arm_master $arm_slave] {
    if {$snapshot eq ""} { set arm_ok 0; set remaining_ok 0; continue }
    array set row $snapshot
    if {$row(TARGET_TAI_SOURCE) != $target_tai ||
        $row(STEP6B_LATCHED_TAI) != $target_tai ||
        $row(STEP6B_ARM_SOURCE) != 1 || $row(STEP6B_ARM_SYNC) != 1 ||
        $row(STEP6B_ARMED) != 1 || $row(STEP6B_FIRED) != 0 ||
        $row(STEP6B_FIRE_COUNT) != 0 ||
        $row(STEP6B_ARM_TIME_VALID) != 1 ||
        $row(STEP6B_ARM_PPS_VALID) != 1 ||
        $row(STEP6B_ARM_TM_LINK) != 1 ||
        $row(STEP6B_ARM_LINK_OK) != 1 ||
        $row(RESET_CHANGED) != 0 || $row(CAPTURE_HEALTHY) != 1 ||
        $row(PLL_READY) != 1} { set arm_ok 0 }
    if {$row(LIVE_TAI) < 0 || $target_tai - $row(LIVE_TAI) < 10} {
      set remaining_ok 0
    }
  }
  if {!$remaining_ok} { set arm_ok 0 }
  set arm_result [expr {$arm_ok ? "PASS" : \
      ($remaining_ok ? "INCONCLUSIVE_ARM_STATE_NOT_CONFIRMED" : \
       "INCONCLUSIVE_ARM_WINDOW_TOO_LATE")}]
  puts [format "S6B_ARM_RESULT=%s TARGET_TAI=%d TARGET_CYCLES=%d ARM_SETTLE_MS=%d" \
    $arm_result $target_tai $::s6b_target_cycles $::s6b_arm_settle_ms]
  flush stdout
  if {!$arm_ok} {
    puts [format "S6B_DONE result=%s phase=arm" $arm_result]
    flush stdout
    return
  }

  set capture_start [clock milliseconds]
  set capture_deadline [expr {$capture_start + $::s6b_observe_timeout_ms}]
  set sample 0
  set runtime_invalid 0
  set stability_loss 0
  set count_violation 0
  set master_fired 0
  set slave_fired 0
  set final_master {}
  set final_slave {}
  set stop_now 0
  set trigger_seen 0
  set post_fire_samples 0
  while {!$stop_now && [clock milliseconds] <= $capture_deadline} {
    set elapsed [expr {[clock milliseconds] - $capture_start}]
    set master [s6b_collect $master_hardware MASTER $sample $elapsed]
    set slave [s6b_collect $slave_hardware SLAVE $sample $elapsed]
    set final_master $master
    set final_slave $slave
    s6b_emit_board_samples $master $slave S6B_SAMPLE
    if {$master eq "" || $slave eq ""} {
      set runtime_invalid 1
      set stop_now 1
      break
    }
    array set m $master
    array set s $slave
    set master_fired [expr {$m(STEP6B_FIRED) == 1}]
    set slave_fired [expr {$s(STEP6B_FIRED) == 1}]
    set count_violation [expr {$m(STEP6B_FIRE_COUNT) > 1 ||
        $s(STEP6B_FIRE_COUNT) > 1}]
    set runtime_now [s6b_runtime_bad $master $slave]
    if {$runtime_now} {
      set runtime_invalid 1
      if {$m(STATUS_TIME_VALID) != 1 || $s(STATUS_TIME_VALID) != 1} {
        set stability_loss 1
      }
      set stop_now 1
    } elseif {$count_violation} {
      set stop_now 1
    } elseif {$master_fired && $slave_fired} {
      if {!$trigger_seen} {
        set trigger_seen 1
        set post_fire_samples 0
      } else {
        incr post_fire_samples
        if {$post_fire_samples >= 3} { set stop_now 1 }
      }
    } elseif {!$trigger_seen && ($m(LIVE_TAI) >= $target_tai + 2 ||
        $s(LIVE_TAI) >= $target_tai + 2)} {
      set stop_now 1
    }
    incr sample
    if {!$stop_now} { after $::s6b_capture_gap_ms }
  }

  if {$stability_loss} {
    for {set post 0} {$post < 3} {incr post} {
      after $::s6b_capture_gap_ms
      set post_master [s6b_collect $master_hardware MASTER $post 0]
      set post_slave [s6b_collect $slave_hardware SLAVE $post 0]
      s6b_emit_board_samples $post_master $post_slave S6B_POST_LOSS_SAMPLE
    }
  }

  set result FAIL_COMMON_TRIGGER_TARGET_MISS
  set target_match FAIL
  set delta_ticks NA
  set delta_ns NA
  set master_count NA
  set slave_count NA
  if {$final_master ne ""} {
    array set fm $final_master
    set master_count $fm(STEP6B_FIRE_COUNT)
  }
  if {$final_slave ne ""} {
    array set fs $final_slave
    set slave_count $fs(STEP6B_FIRE_COUNT)
  }
  if {$runtime_invalid} {
    if {$stability_loss} {
      set result INCONCLUSIVE_STEP6A_STABILITY_LOST_BEFORE_TARGET
    } else {
      set result INCONCLUSIVE_RUNTIME_STATE_CHANGED
    }
  } elseif {$count_violation} {
    set result FAIL_TRIGGER_ONE_SHOT_VIOLATION
  } elseif {$master_fired != $slave_fired} {
    set result FAIL_ONE_SIDED_SCHEDULED_TRIGGER
  } elseif {$master_fired && $slave_fired} {
    array set fm $final_master
    array set fs $final_slave
    if {$fm(STEP6B_ACTUAL_TAI) != $fs(STEP6B_ACTUAL_TAI) ||
        $fm(STEP6B_ACTUAL_CYCLES) != $fs(STEP6B_ACTUAL_CYCLES)} {
      set result FAIL_SCHEDULED_TRIGGER_TIMESTAMP_MISMATCH
      if {$fm(STEP6B_ACTUAL_TAI) >= 0 && $fs(STEP6B_ACTUAL_TAI) >= 0 &&
          $fm(STEP6B_ACTUAL_CYCLES) >= 0 && $fs(STEP6B_ACTUAL_CYCLES) >= 0} {
        set delta_ticks [expr {($fs(STEP6B_ACTUAL_TAI) - $fm(STEP6B_ACTUAL_TAI)) * 125000000 +
            $fs(STEP6B_ACTUAL_CYCLES) - $fm(STEP6B_ACTUAL_CYCLES)}]
        set delta_ns [expr {$delta_ticks * 8}]
      }
    } elseif {$fm(STEP6B_ACTUAL_TAI) != $target_tai ||
        $fs(STEP6B_ACTUAL_TAI) != $target_tai ||
        $fm(STEP6B_ACTUAL_CYCLES) != $::s6b_target_cycles ||
        $fs(STEP6B_ACTUAL_CYCLES) != $::s6b_target_cycles} {
      set result FAIL_COMMON_TRIGGER_TARGET_MISS
    } elseif {$master_count != 1 || $slave_count != 1} {
      set result FAIL_TRIGGER_ONE_SHOT_VIOLATION
    } else {
      set result PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER
      set target_match PASS
      set delta_ticks 0
      set delta_ns 0
    }
  }
  set capture_elapsed [expr {[clock milliseconds] - $capture_start}]
  puts [format "S6B_CAPTURE_RESULT=%s SAMPLES=%d POST_FIRE_SAMPLES=%d ELAPSED_MS=%d TARGET_TAI=%d TARGET_CYCLES=%d MASTER_FIRED=%d SLAVE_FIRED=%d MASTER_FIRE_COUNT=%s SLAVE_FIRE_COUNT=%s TARGET_MATCH=%s DIGITAL_TRIGGER_DELTA_TICKS=%s DIGITAL_TRIGGER_DELTA_NS=%s" \
    $result $sample $post_fire_samples $capture_elapsed $target_tai \
    $::s6b_target_cycles $master_fired $slave_fired $master_count $slave_count \
    $target_match $delta_ticks $delta_ns]
  puts [format "S6B_DONE result=%s phase=capture" $result]
  flush stdout
}

if {![info exists ::s6b_no_autorun] || !$::s6b_no_autorun} {
  if {$::s6b_mode eq "LATE_TAIL"} {
    s6a_late_tail_run
  } elseif {$::s6b_mode eq "LIVE_SESSION"} {
    s6b_live_session_run
  } else {
    s6b_run
  }
}
