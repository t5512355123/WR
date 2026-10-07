# Step6 Master-last exact-image recovery attribution observer.
#
# This is a read-only paired observer.  It never writes Wishbone, changes a
# PHY setting, restarts PTP, or programs either board.  The host runner owns
# the single exact Master programming event; this script is used once before
# programming (preflight) and once immediately after programming (recovery).
#
# Usage:
#   quartus_stp -t read_step6_master_last_exact_image_recovery_attribution.tcl \
#       TRIAL_ID preflight 5 250
#   quartus_stp -t read_step6_master_last_exact_image_recovery_attribution.tcl \
#       TRIAL_ID recovery 480 250 120000

package require ::quartus::insystem_source_probe

set ::ml_trial_id "S6-MASTER-LAST-EXACT-IMAGE-RECOVERY-ATTRIBUTION"
set ::ml_mode "preflight"
set ::ml_sample_limit 5
set ::ml_gap_ms 250
set ::ml_recovery_window_ms 120000
if {[llength $argv] >= 1} { set ::ml_trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::ml_mode [lindex $argv 1] }
if {[llength $argv] >= 3} { set ::ml_sample_limit [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::ml_gap_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set ::ml_recovery_window_ms [expr {int([lindex $argv 4])}] }
if {$ml_mode ni {preflight recovery}} { error "mode must be preflight or recovery" }
if {$ml_sample_limit <= 0 || $ml_gap_ms < 0 || $ml_recovery_window_ms <= 0} {
  error "invalid sample, gap, or recovery window argument"
}

# Library mode prevents read_wb_runtime.tcl from running its dashboard loop.
set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

array set ::ml_previous_activity {}
array set ::ml_preflight_reset_baseline {}
array set ::ml_recovery_reset_baseline {}

proc ml_raw_valid {value} {
  return [expr {$value ne "TIMEOUT" && $value ne "INVALID" &&
                $value ne "DECREASED" && [is_hex $value]}]
}

proc ml_probe64 {value} {
  if {![ml_raw_valid $value]} { return $value }
  return [normalize_probe64 $value]
}

proc ml_activity_count {clock} {
  if {![ml_raw_valid $clock]} { return -1 }
  set high [probe_high32 $clock]
  if {$high < 0} { return -1 }
  return [expr {$high & 0xffff}]
}

proc ml_reset_signature {snapshot} {
  array set s $snapshot
  return [list $s(BOOT_GENERATION) $s(CPU_RESET_COUNT) \
    $s(WR_CORE_RESET_COUNT) $s(SI_CONFIG_DROP_COUNT)]
}

proc ml_reset_signature_changed {old new} {
  if {$old eq "" || $new eq ""} { return 0 }
  return [expr {$old ne $new}]
}

proc ml_basic_ready {snapshot} {
  if {$snapshot eq ""} { return 0 }
  array set s $snapshot
  return [expr {$s(READ_VALID) == 1 &&
    $s(SI_CONFIG_DONE) == 1 && $s(WR_READY) == 1 &&
    $s(RX_READY) == 1 && $s(TX_READY) == 1 &&
    $s(CPU_RESET_N) == 1 && $s(PHY_RST) == 0 &&
    $s(PHY_TX_DISABLE) == 0}]
}

proc ml_master_local_ready {snapshot} {
  if {![ml_basic_ready $snapshot]} { return 0 }
  array set s $snapshot
  return [expr {$s(PTP_STATE) == 6}]
}

proc ml_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc ml_snapshot {hardware_name role sample elapsed_ms} {
  set status [safe_probe_read 0]
  set clock [safe_probe_read 7]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set ptp [wb_read 0x00100A10]

  set read_valid 1
  foreach value [list $status $clock $entry $reset $ptp] {
    if {![ml_raw_valid $value]} { set read_valid 0 }
  }

  set reset_values [list INVALID INVALID INVALID INVALID]
  if {[ml_raw_valid $entry] && [ml_raw_valid $reset]} {
    set reset_values [list \
      [probe_high_counter_hex $entry] \
      [probe_byte_counter_hex $reset 16] \
      [probe_byte_counter_hex $reset 24] \
      [probe_byte_counter_hex $reset 40]]
  }
  lassign $reset_values boot_generation cpu_reset_count \
    wr_core_reset_count si_config_drop_count

  set si_config_done [bit32 $status 0]
  set wr_ready [bit32 $status 1]
  set core_tm_link_up [bit32 $status 2]
  set core_link_ok [bit32 $status 3]
  set rx_ready [bit32 $status 6]
  set tx_ready [bit32 $status 7]
  set phy_tx_disable [bit32 $status 10]
  set phy_rst [bit32 $status 11]
  set cpu_reset_n [bit32 $status 15]
  set rx_pattern_ready [bit64_high $status 6]
  set rx_syncstatus [bit64_high $status 4]
  set rx_locked_to_data [bit64_high $status 0]
  set rx_activity_count [ml_activity_count $clock]
  set ptp_state [field32 $ptp 0 8]

  set activity_changed 0
  if {[info exists ::ml_previous_activity($hardware_name)] &&
      $rx_activity_count >= 0 &&
      $::ml_previous_activity($hardware_name) >= 0 &&
      $rx_activity_count != $::ml_previous_activity($hardware_name)} {
    set activity_changed 1
  }
  set ::ml_previous_activity($hardware_name) $rx_activity_count

  return [list \
    ROLE $role BOARD $hardware_name SAMPLE $sample ELAPSED_MS $elapsed_ms \
    READ_VALID $read_valid STATUS_RAW [ml_probe64 $status] \
    CLOCK_ACTIVITY_RAW [ml_probe64 $clock] ENTRY_RAW [ml_probe64 $entry] \
    RESET_RAW [ml_probe64 $reset] PTP_RAW [format %08X [word32 $ptp]] \
    SI_CONFIG_DONE $si_config_done WR_READY $wr_ready \
    RX_READY $rx_ready TX_READY $tx_ready CPU_RESET_N $cpu_reset_n \
    PHY_RST $phy_rst PHY_TX_DISABLE $phy_tx_disable \
    CORE_TM_LINK_UP $core_tm_link_up CORE_LINK_OK $core_link_ok \
    RX_LOCKED_TO_DATA $rx_locked_to_data RX_SYNCSTATUS $rx_syncstatus \
    RX_PATTERN_READY $rx_pattern_ready RX_ACTIVITY_COUNT $rx_activity_count \
    RX_ACTIVITY_CHANGED $activity_changed PTP_STATE $ptp_state \
    BOOT_GENERATION $boot_generation CPU_RESET_COUNT $cpu_reset_count \
    WR_CORE_RESET_COUNT $wr_core_reset_count \
    SI_CONFIG_DROP_COUNT $si_config_drop_count]
}

proc ml_open_board {hardware_name} {
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { error "no device for $hardware_name" }
  catch {end_insystem_source_probe}
  start_insystem_source_probe -hardware_name $hardware_name \
    -device_name [lindex $devices 0]
  wb_sync_toggle
}

proc ml_close_board {} { catch {end_insystem_source_probe} }

proc ml_collect {hardware_name role sample elapsed_ms} {
  set snapshot {}
  set error_message ""
  if {[catch {
    ml_open_board $hardware_name
    set snapshot [ml_snapshot $hardware_name $role $sample $elapsed_ms]
  } error_message]} {
    set snapshot {}
  }
  ml_close_board
  return $snapshot
}

set ::ml_master_hardware ""
set ::ml_slave_hardware ""
foreach hardware_name [get_hardware_names] {
  if {[string first "1-11.1" $hardware_name] >= 0} {
    set ::ml_master_hardware $hardware_name
  } elseif {[string first "1-11.2" $hardware_name] >= 0} {
    set ::ml_slave_hardware $hardware_name
  }
}
if {$::ml_master_hardware eq "" || $::ml_slave_hardware eq ""} {
  error "both DE5a targets are required"
}

puts [format "MASTER_LAST_CONFIG trial=%s mode=%s samples=%d gap_ms=%d recovery_window_ms=%d read_only=1 compile=0 master_program_count=0 slave_program_count=0 power_cycle=0 phy_reset=0 ptp_restart=0 mode_command=0 mdio_write=0" \
  $::ml_trial_id $::ml_mode $::ml_sample_limit $::ml_gap_ms \
  $::ml_recovery_window_ms]
flush stdout

if {$::ml_mode eq "preflight"} {
  set begin_ms [clock milliseconds]
  set all_basic 1
  set all_valid 1
  set reset_changed 0
  set activity_seen 0
  set previous_master_reset ""
  set previous_slave_reset ""
  set last_master {}
  set last_slave {}

  for {set sample 0} {$sample < $::ml_sample_limit} {incr sample} {
    set elapsed [expr {[clock milliseconds] - $begin_ms}]
    set master [ml_collect $::ml_master_hardware MASTER $sample $elapsed]
    set slave [ml_collect $::ml_slave_hardware SLAVE $sample $elapsed]
    if {$master eq "" || $slave eq ""} {
      set all_valid 0
      ml_emit PREFLIGHT_SAMPLE [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 0 MASTER_BASIC_READY 0 SLAVE_BASIC_READY 0 \
        SLAVE_RX_LOCKED_TO_DATA 0 SLAVE_RX_ACTIVITY_CHANGED 0]
    } else {
      array set m $master
      array set s $slave
      set master_basic [ml_basic_ready $master]
      set slave_basic [ml_basic_ready $slave]
      set slave_rx_ok [expr {$s(RX_LOCKED_TO_DATA) == 1}]
      set all_basic [expr {$all_basic && $master_basic && $slave_basic && $slave_rx_ok}]
      set activity_seen [expr {$activity_seen || $s(RX_ACTIVITY_CHANGED) == 1}]
      set master_reset [ml_reset_signature $master]
      set slave_reset [ml_reset_signature $slave]
      if {$previous_master_reset ne "" &&
          [ml_reset_signature_changed $previous_master_reset $master_reset]} {
        set reset_changed 1
      }
      if {$previous_slave_reset ne "" &&
          [ml_reset_signature_changed $previous_slave_reset $slave_reset]} {
        set reset_changed 1
      }
      set previous_master_reset $master_reset
      set previous_slave_reset $slave_reset
      set last_master $master
      set last_slave $slave
      ml_emit PREFLIGHT_SAMPLE [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 1 MASTER_BASIC_READY $master_basic \
        SLAVE_BASIC_READY $slave_basic SLAVE_RX_LOCKED_TO_DATA $s(RX_LOCKED_TO_DATA) \
        SLAVE_RX_ACTIVITY_COUNT $s(RX_ACTIVITY_COUNT) \
        SLAVE_RX_ACTIVITY_CHANGED $s(RX_ACTIVITY_CHANGED) \
        MASTER_PTP_STATE $m(PTP_STATE) SLAVE_PTP_STATE $s(PTP_STATE) \
        MASTER_BOOT_GENERATION $m(BOOT_GENERATION) \
        SLAVE_BOOT_GENERATION $s(BOOT_GENERATION) RESET_CHANGED $reset_changed]
    }
    flush stdout
    if {$sample + 1 < $::ml_sample_limit} { after $::ml_gap_ms }
  }

  if {!$all_valid} {
    puts "PREFLIGHT_RESULT=INCONCLUSIVE_TRANSPORT"
  } elseif {$reset_changed} {
    puts "PREFLIGHT_RESULT=INCONCLUSIVE_RESET"
  } elseif {!$all_basic || !$activity_seen} {
    puts [format "PREFLIGHT_RESULT=FAIL_BASIC_GATE MASTER_BASIC_READY=%d SLAVE_BASIC_READY=%d SLAVE_RX_ACTIVITY_PRESENT=%d" \
      [expr {$last_master ne {} ? [ml_basic_ready $last_master] : 0}] \
      [expr {$last_slave ne {} ? [ml_basic_ready $last_slave] : 0}] $activity_seen]
  } else {
    puts "PREFLIGHT_RESULT=PASS"
  }
  puts [format "PREFLIGHT_DONE samples=%d elapsed_ms=%d" $::ml_sample_limit \
    [expr {[clock milliseconds] - $begin_ms}]]
  flush stdout
  return
}

# Recovery phase starts after the single host-side Master programming event.
set begin_ms [clock milliseconds]
set sample 0
set master_ready_streak 0
set recovery_streak 0
set max_recovery_streak 0
set recovery_seen 0
set previous_good 0
set first_recovery_ms -1
set master_local_ready_ms -1
set result NONE
set reset_changed 0
set master_reset_baseline ""
set slave_reset_baseline ""
set first_valid_ms -1

while {$sample < $::ml_sample_limit &&
       ([clock milliseconds] - $begin_ms) <= $::ml_recovery_window_ms &&
       $result eq "NONE"} {
  set elapsed [expr {[clock milliseconds] - $begin_ms}]
  set master [ml_collect $::ml_master_hardware MASTER $sample $elapsed]
  set slave [ml_collect $::ml_slave_hardware SLAVE $sample $elapsed]
  if {$master eq "" || $slave eq ""} {
    ml_emit RECOVERY_PAIR_SAMPLE [list SAMPLE $sample ELAPSED_MS $elapsed \
      READ_VALID 0 MASTER_READ_VALID 0 SLAVE_READ_VALID 0 \
      MASTER_LOCAL_READY 0 MASTER_READY_STREAK $master_ready_streak \
      SLAVE_RECOVERY_GOOD 0 SLAVE_RECOVERY_STREAK $recovery_streak \
      SLAVE_RECOVERY_SEEN $recovery_seen RESET_CHANGED 0]
    set result INCONCLUSIVE_TRANSPORT
    break
  }

  array set m $master
  array set s $slave
  if {$first_valid_ms < 0} { set first_valid_ms $elapsed }
  if {$master_reset_baseline eq ""} {
    set master_reset_baseline [ml_reset_signature $master]
    set slave_reset_baseline [ml_reset_signature $slave]
  } else {
    if {[ml_reset_signature_changed $master_reset_baseline [ml_reset_signature $master]] ||
        [ml_reset_signature_changed $slave_reset_baseline [ml_reset_signature $slave]]} {
      set reset_changed 1
    }
  }

  if {[ml_master_local_ready $master]} {
    incr master_ready_streak
  } else {
    set master_ready_streak 0
  }
  if {$master_ready_streak >= 3 && $master_local_ready_ms < 0} {
    set master_local_ready_ms $elapsed
  }

  set recovery_good [expr {$s(READ_VALID) == 1 &&
    $s(RX_LOCKED_TO_DATA) == 1 && $s(RX_ACTIVITY_CHANGED) == 1 &&
    $s(RX_PATTERN_READY) == 1 && $s(CORE_LINK_OK) == 1 &&
    $s(CORE_TM_LINK_UP) == 1}]
  set recovery_evidence [expr {$s(RX_PATTERN_READY) == 1 &&
    $s(CORE_LINK_OK) == 1}]
  if {$recovery_evidence} {
    set recovery_seen 1
    if {$first_recovery_ms < 0} { set first_recovery_ms $elapsed }
  }
  if {$recovery_good} {
    incr recovery_streak
    if {$recovery_streak > $max_recovery_streak} {
      set max_recovery_streak $recovery_streak
    }
  } else {
    set recovery_streak 0
  }

  ml_emit RECOVERY_PAIR_SAMPLE [list SAMPLE $sample ELAPSED_MS $elapsed \
    READ_VALID 1 MASTER_READ_VALID $m(READ_VALID) SLAVE_READ_VALID $s(READ_VALID) \
    MASTER_LOCAL_READY [ml_master_local_ready $master] \
    MASTER_READY_STREAK $master_ready_streak MASTER_PTP_STATE $m(PTP_STATE) \
    SLAVE_RX_LOCKED_TO_DATA $s(RX_LOCKED_TO_DATA) \
    SLAVE_RX_ACTIVITY_COUNT $s(RX_ACTIVITY_COUNT) \
    SLAVE_RX_ACTIVITY_CHANGED $s(RX_ACTIVITY_CHANGED) \
    SLAVE_RX_PATTERN_READY $s(RX_PATTERN_READY) \
    SLAVE_CORE_LINK_OK $s(CORE_LINK_OK) SLAVE_CORE_TM_LINK_UP $s(CORE_TM_LINK_UP) \
    SLAVE_RECOVERY_GOOD $recovery_good SLAVE_RECOVERY_STREAK $recovery_streak \
    SLAVE_RECOVERY_SEEN $recovery_seen MAX_RECOVERY_STREAK $max_recovery_streak \
    MASTER_BOOT_GENERATION $m(BOOT_GENERATION) SLAVE_BOOT_GENERATION $s(BOOT_GENERATION) \
    RESET_CHANGED $reset_changed]
  flush stdout

  if {$reset_changed} {
    set result INCONCLUSIVE_RESET
  } elseif {$master_ready_streak >= 3 && $recovery_streak >= 5} {
    set result PASS_EXACT_MASTER_LAST_RECOVERY
  } elseif {$recovery_seen && $previous_good && !$recovery_good} {
    set result FAIL_TRANSIENT_RECOVERY
  } elseif {$master_local_ready_ms < 0 && $elapsed >= 10000} {
    set result INCONCLUSIVE_MASTER_LOCAL_READY
  }
  set previous_good $recovery_good
  incr sample
  if {$result eq "NONE" && $sample < $::ml_sample_limit} { after $::ml_gap_ms }
}

if {$result eq "NONE"} {
  set result FAIL_EXACT_MASTER_LAST_RECOVERY_NOT_REPRODUCED
}
puts [format "RECOVERY_RESULT=%s FIRST_VALID_MS=%d MASTER_LOCAL_READY_MS=%d FIRST_RECOVERY_MS=%d MAX_RECOVERY_STREAK=%d SAMPLES=%d ELAPSED_MS=%d" \
  $result $first_valid_ms $master_local_ready_ms $first_recovery_ms \
  $max_recovery_streak $sample [expr {[clock milliseconds] - $begin_ms}]]
puts [format "RECOVERY_DONE result=%s" $result]
flush stdout
