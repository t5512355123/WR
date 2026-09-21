# Step6A-1: revalidate Global Time after the already-observed link recovery.
#
# This observer is read-only.  It does not program, reset, restart PTP, write
# MDIO/SI5340, change a mode, or change any FPGA/PHY control state.
#
# Usage:
#   quartus_stp -t read_step6_global_time_recovered_link_revalidation.tcl \
#     EXP-ID ?preflight_samples? ?gap_ms? ?duration_ms?

package require ::quartus::insystem_source_probe

set ::gt_trial_id "EXP-S6-GLOBAL-TIME-RECOVERED-LINK-REVALIDATION-20260922"
set ::gt_preflight_samples 5
set ::gt_gap_ms 250
set ::gt_duration_ms 8000
if {[llength $argv] >= 1} { set ::gt_trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::gt_preflight_samples [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set ::gt_gap_ms [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::gt_duration_ms [expr {int([lindex $argv 3])}] }
if {$::gt_preflight_samples <= 0 || $::gt_gap_ms < 0 ||
    $::gt_duration_ms <= 0} {
  error "invalid preflight sample, gap, or duration argument"
}

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

array set ::gt_previous_activity {}
array set ::gt_previous_reset {}

proc gt_raw_valid {value} {
  return [expr {$value ne "TIMEOUT" && $value ne "INVALID" &&
                [is_hex $value]}]
}

proc gt_probe64 {value} {
  if {![gt_raw_valid $value]} { return $value }
  return [normalize_probe64 $value]
}

proc gt_status_bit {value bit} {
  if {![gt_raw_valid $value]} { return -1 }
  return [bit64_low $value $bit]
}

proc gt_status_high_bit {value bit} {
  if {![gt_raw_valid $value]} { return -1 }
  return [bit64_high $value $bit]
}

proc gt_activity_count {value} {
  if {![gt_raw_valid $value]} { return -1 }
  set high [probe_high32 $value]
  if {$high < 0} { return -1 }
  return [expr {$high & 0xffff}]
}

proc gt_live_fields {live} {
  if {![gt_raw_valid $live]} { return [list -1 -1] }
  set normalized [normalize_probe64 $live]
  scan [string range $normalized 0 7] %x high
  scan [string range $normalized 8 15] %x low
  set tai_lo [expr {(($high & 0x0000000F) << 32) | $low}]
  set cycles [expr {($high >> 4) & 0x0FFFFFFF}]
  return [list $tai_lo $cycles]
}

proc gt_snapshot_fields {word0 word1} {
  if {![gt_raw_valid $word0] || ![gt_raw_valid $word1]} {
    return [list -1 -1 -1 -1 -1 -1]
  }
  set low0 [word32 $word0]
  set high0 [probe_high32 $word0]
  set low1 [word32 $word1]
  if {$low0 < 0 || $high0 < 0 || $low1 < 0} {
    return [list -1 -1 -1 -1 -1 -1]
  }
  set tai [expr {(($high0 & 0xff) << 32) | $low0}]
  set cycles [expr {($high0 & 0x00ffffff) | (($low1 & 0xf) << 24)}]
  set time_valid [expr {($low1 >> 4) & 1}]
  set pps_valid [expr {($low1 >> 5) & 1}]
  set snapshot_valid [expr {($low1 >> 6) & 1}]
  set count [expr {($low1 >> 7) & 0xffff}]
  return [list $tai $cycles $time_valid $pps_valid $snapshot_valid $count]
}

proc gt_reset_values {entry reset} {
  if {![gt_raw_valid $entry] || ![gt_raw_valid $reset]} {
    return [list INVALID INVALID INVALID INVALID]
  }
  return [list \
    [probe_high_counter_hex $entry] \
    [probe_byte_counter_hex $reset 16] \
    [probe_byte_counter_hex $reset 24] \
    [probe_byte_counter_hex $reset 40]]
}

proc gt_reset_signature {snapshot} {
  array set s $snapshot
  return [list $s(BOOT_GENERATION) $s(CPU_RESET_COUNT) \
    $s(WR_CORE_RESET_COUNT) $s(SI_CONFIG_DROP_COUNT)]
}

proc gt_ptp_fields {ptp_meta} {
  set word [word32 $ptp_meta]
  if {$word < 0} { return [list -1 -1 -1 -1] }
  return [list [expr {$word & 0xff}] \
    [expr {($word >> 8) & 0xff}] \
    [expr {($word >> 16) & 0xff}] \
    [expr {($word >> 24) & 0xff}]]
}

proc gt_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc gt_capture {hardware_name role sample elapsed_ms} {
  set clock_start [safe_probe_read 7]
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set live [safe_probe_read 64]
  set word1_before [safe_probe_read 63]
  set word0 [safe_probe_read 62]
  set word1_after [safe_probe_read 63]
  set clock_end [safe_probe_read 7]
  set ptp [wb_read 0x00100A10]
  set ptp_meta [wb_read 0x00100A5C]

  set read_valid 1
  foreach value [list $clock_start $status $entry $reset $live \
      $word1_before $word0 $word1_after $clock_end $ptp $ptp_meta] {
    if {![gt_raw_valid $value]} { set read_valid 0 }
  }

  lassign [gt_reset_values $entry $reset] boot_generation cpu_reset_count \
    wr_core_reset_count si_config_drop_count
  lassign [gt_live_fields $live] live_tai_lo live_cycles
  lassign [gt_snapshot_fields $word0 $word1_after] snapshot_tai snapshot_cycles \
    snapshot_time_valid snapshot_pps_valid snapshot_valid snapshot_count
  lassign [gt_ptp_fields $ptp_meta] ptp_state pd_state ext_state wrc_mode

  set status_si_config [gt_status_bit $status 0]
  set status_wr_ready [gt_status_bit $status 1]
  set status_tm_link_up [gt_status_bit $status 2]
  set status_link_ok [gt_status_bit $status 3]
  set status_time_valid [gt_status_bit $status 4]
  set status_pps_valid [gt_status_bit $status 5]
  set status_rx_ready [gt_status_bit $status 6]
  set status_tx_ready [gt_status_bit $status 7]
  set status_phy_tx_disable [gt_status_bit $status 10]
  set status_phy_rst [gt_status_bit $status 11]
  set status_cpu_reset_n [gt_status_bit $status 15]
  set rx_locked_to_data [gt_status_high_bit $status 0]
  set rx_pattern_ready [gt_status_high_bit $status 6]
  set activity_start [gt_activity_count $clock_start]
  set activity_count [gt_activity_count $clock_end]

  set activity_changed 0
  if {$activity_start >= 0 && $activity_count >= 0 &&
      $activity_start != $activity_count} {
    set activity_changed 1
  }
  if {[info exists ::gt_previous_activity($hardware_name)] &&
      $activity_count >= 0 &&
      $::gt_previous_activity($hardware_name) >= 0 &&
      $activity_count != $::gt_previous_activity($hardware_name)} {
    set activity_changed 1
  }
  set ::gt_previous_activity($hardware_name) $activity_count

  set reset_changed 0
  set reset_signature [gt_reset_signature [list \
    BOOT_GENERATION $boot_generation CPU_RESET_COUNT $cpu_reset_count \
    WR_CORE_RESET_COUNT $wr_core_reset_count \
    SI_CONFIG_DROP_COUNT $si_config_drop_count]]
  if {[info exists ::gt_previous_reset($hardware_name)] &&
      $::gt_previous_reset($hardware_name) ne $reset_signature} {
    set reset_changed 1
  }
  set ::gt_previous_reset($hardware_name) $reset_signature

  set stable [expr {$word1_before eq $word1_after ? 1 : 0}]
  set link_healthy [expr {$status_si_config == 1 &&
      $status_wr_ready == 1 && $status_rx_ready == 1 &&
      $status_tx_ready == 1 && $status_cpu_reset_n == 1 &&
      $status_phy_rst == 0 && $status_phy_tx_disable == 0 &&
      $status_link_ok == 1 && $status_tm_link_up == 1}]

  return [list \
    ROLE $role BOARD $role SAMPLE $sample ELAPSED_MS $elapsed_ms \
    READ_VALID $read_valid STABLE $stable \
    STATUS_RAW [gt_probe64 $status] \
    STATUS_SI_CONFIG $status_si_config STATUS_WR_READY $status_wr_ready \
    STATUS_TM_LINK_UP $status_tm_link_up STATUS_LINK_OK $status_link_ok \
    STATUS_TIME_VALID $status_time_valid STATUS_PPS_VALID $status_pps_valid \
    STATUS_RX_READY $status_rx_ready STATUS_TX_READY $status_tx_ready \
    STATUS_CPU_RESET_N $status_cpu_reset_n STATUS_PHY_RST $status_phy_rst \
    STATUS_PHY_TX_DISABLE $status_phy_tx_disable \
    RX_LOCKED_TO_DATA $rx_locked_to_data RX_PATTERN_READY $rx_pattern_ready \
    RX_ACTIVITY_COUNT $activity_count RX_ACTIVITY_CHANGED $activity_changed \
    RAW_LIVE [gt_probe64 $live] RAW0 [gt_probe64 $word0] \
    RAW1_BEFORE [gt_probe64 $word1_before] \
    RAW1_AFTER [gt_probe64 $word1_after] \
    SNAPSHOT_VALID $snapshot_valid SNAPSHOT_TIME_VALID $snapshot_time_valid \
    SNAPSHOT_PPS_VALID $snapshot_pps_valid SNAPSHOT_COUNT $snapshot_count \
    TAI $snapshot_tai CYCLES $snapshot_cycles \
    LIVE_TAI_LO $live_tai_lo LIVE_CYCLES $live_cycles \
    PTP_RAW [gt_probe64 $ptp] PTP_META_RAW [gt_probe64 $ptp_meta] \
    PTP_STATE $ptp_state PD_STATE $pd_state EXT_STATE $ext_state WRC_MODE $wrc_mode \
    BOOT_GENERATION $boot_generation CPU_RESET_COUNT $cpu_reset_count \
    WR_CORE_RESET_COUNT $wr_core_reset_count \
    SI_CONFIG_DROP_COUNT $si_config_drop_count \
    RESET_CHANGED $reset_changed LINK_HEALTHY $link_healthy]
}

proc gt_open_board {hardware_name} {
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { error "no device for $hardware_name" }
  catch {end_insystem_source_probe}
  start_insystem_source_probe -hardware_name $hardware_name \
    -device_name [lindex $devices 0]
  wb_sync_toggle
}

proc gt_close_board {} { catch {end_insystem_source_probe} }

proc gt_collect {hardware_name role sample elapsed_ms} {
  set snapshot {}
  if {[catch {
    gt_open_board $hardware_name
    set snapshot [gt_capture $hardware_name $role $sample $elapsed_ms]
  } error_message]} {
    set snapshot {}
  }
  gt_close_board
  return $snapshot
}

proc gt_precondition {snapshot role} {
  if {$snapshot eq ""} { return 0 }
  array set s $snapshot
  if {$s(READ_VALID) != 1 || $s(RESET_CHANGED) != 0 ||
      $s(LINK_HEALTHY) != 1} {
    return 0
  }
  if {$role eq "SLAVE" && ($s(RX_LOCKED_TO_DATA) != 1 ||
                           $s(RX_PATTERN_READY) != 1 ||
                           $s(RX_ACTIVITY_CHANGED) != 1)} {
    return 0
  }
  return 1
}

set ::gt_master_hardware ""
set ::gt_slave_hardware ""
foreach hardware_name [get_hardware_names] {
  if {[string first "1-11.1" $hardware_name] >= 0} {
    set ::gt_master_hardware $hardware_name
  } elseif {[string first "1-11.2" $hardware_name] >= 0} {
    set ::gt_slave_hardware $hardware_name
  }
}
if {$::gt_master_hardware eq "" || $::gt_slave_hardware eq ""} {
  error "both DE5a targets are required"
}

puts [format "GLOBAL_TIME_REVALIDATION_CONFIG trial=%s preflight_samples=%d gap_ms=%d duration_ms=%d read_only=1 compile=0 program=0 reset=0 power_cycle=0 mdio_write=0" \
  $::gt_trial_id $::gt_preflight_samples $::gt_gap_ms $::gt_duration_ms]
flush stdout

set gate_all 1
set gate_transport 0
set gate_reset_changed 0
set gate_begin_ms [clock milliseconds]
for {set sample 0} {$sample < $::gt_preflight_samples} {incr sample} {
  set elapsed [expr {[clock milliseconds] - $gate_begin_ms}]
  set master [gt_collect $::gt_master_hardware MASTER $sample $elapsed]
  set slave [gt_collect $::gt_slave_hardware SLAVE $sample $elapsed]
  if {$master eq "" || $slave eq ""} {
    set gate_transport 1
    set gate_all 0
    gt_emit GLOBAL_TIME_REVALIDATION_GATE_PAIR [list SAMPLE $sample \
      ELAPSED_MS $elapsed READ_VALID 0 MASTER_PRECONDITION 0 \
      SLAVE_PRECONDITION 0 MASTER_RESET_CHANGED 0 SLAVE_RESET_CHANGED 0]
  } else {
    array set m $master
    array set s $slave
    set master_good [gt_precondition $master MASTER]
    set slave_good [gt_precondition $slave SLAVE]
    set pair_reset [expr {$m(RESET_CHANGED) || $s(RESET_CHANGED)}]
    if {$m(READ_VALID) != 1 || $s(READ_VALID) != 1} { set gate_transport 1 }
    if {$pair_reset} { set gate_reset_changed 1 }
    set gate_all [expr {$gate_all && $master_good && $slave_good && !$pair_reset}]
    gt_emit GLOBAL_TIME_REVALIDATION_GATE_PAIR [list SAMPLE $sample \
      ELAPSED_MS $elapsed READ_VALID 1 MASTER_PRECONDITION $master_good \
      SLAVE_PRECONDITION $slave_good MASTER_RESET_CHANGED $m(RESET_CHANGED) \
      SLAVE_RESET_CHANGED $s(RESET_CHANGED) \
      MASTER_ACTIVITY_CHANGED $m(RX_ACTIVITY_CHANGED) \
      SLAVE_ACTIVITY_CHANGED $s(RX_ACTIVITY_CHANGED) \
      MASTER_LINK_HEALTHY $m(LINK_HEALTHY) SLAVE_LINK_HEALTHY $s(LINK_HEALTHY)]
  }
  flush stdout
  if {$sample + 1 < $::gt_preflight_samples} { after $::gt_gap_ms }
}

if {$gate_transport || $gate_reset_changed} {
  puts [format "GLOBAL_TIME_GATE_RESULT=INCONCLUSIVE_RUNTIME_STATE_CHANGED SAMPLES=%d" \
    $::gt_preflight_samples]
  puts "GLOBAL_TIME_REVALIDATION_DONE result=INCONCLUSIVE_RUNTIME_STATE_CHANGED phase=gate"
  flush stdout
  return
}
if {!$gate_all} {
  puts [format "GLOBAL_TIME_GATE_RESULT=INCONCLUSIVE_LINK_PRECONDITION SAMPLES=%d" \
    $::gt_preflight_samples]
  puts "GLOBAL_TIME_REVALIDATION_DONE result=INCONCLUSIVE_LINK_PRECONDITION phase=gate"
  flush stdout
  return
}
puts [format "GLOBAL_TIME_GATE_RESULT=PASS SAMPLES=%d" $::gt_preflight_samples]
flush stdout

set phase_begin_ms [clock milliseconds]
set phase_deadline_ms [expr {$phase_begin_ms + $::gt_duration_ms}]
set phase_sample 0
set phase_transport 0
set phase_reset_changed 0
set phase_link_changed 0
while {[clock milliseconds] <= $phase_deadline_ms} {
  set elapsed [expr {[clock milliseconds] - $phase_begin_ms}]
  set master [gt_collect $::gt_master_hardware MASTER $phase_sample $elapsed]
  set slave [gt_collect $::gt_slave_hardware SLAVE $phase_sample $elapsed]
  if {$master eq "" || $slave eq ""} {
    set phase_transport 1
    gt_emit GLOBAL_TIME_REVALIDATION_SAMPLE [list SAMPLE $phase_sample \
      ELAPSED_MS $elapsed BOARD_PAIR_READ_VALID 0]
    break
  }
  array set m $master
  array set s $slave
  if {$m(READ_VALID) != 1 || $s(READ_VALID) != 1} { set phase_transport 1 }
  if {$m(RESET_CHANGED) || $s(RESET_CHANGED)} { set phase_reset_changed 1 }
  if {!$m(LINK_HEALTHY) || !$s(LINK_HEALTHY)} { set phase_link_changed 1 }
  puts [format "GLOBAL_TIME_REVALIDATION_SAMPLE_PAIR SAMPLE=%d ELAPSED_MS=%d" \
    $phase_sample $elapsed]
  gt_emit GLOBAL_TIME_REVALIDATION_SAMPLE [concat [list BOARD MASTER] $master]
  gt_emit GLOBAL_TIME_REVALIDATION_SAMPLE [concat [list BOARD SLAVE] $slave]
  flush stdout
  incr phase_sample
  if {$phase_transport || $phase_reset_changed || $phase_link_changed} { break }
  if {[clock milliseconds] <= $phase_deadline_ms} { after $::gt_gap_ms }
}

set phase_result PASS_CAPTURE
if {$phase_transport || $phase_reset_changed || $phase_link_changed} {
  set phase_result INCONCLUSIVE_RUNTIME_STATE_CHANGED
}
puts [format "GLOBAL_TIME_CAPTURE_RESULT=%s SAMPLES=%d ELAPSED_MS=%d" \
  $phase_result $phase_sample [expr {[clock milliseconds] - $phase_begin_ms}]]
puts [format "GLOBAL_TIME_REVALIDATION_DONE result=%s phase=observation" $phase_result]
flush stdout
