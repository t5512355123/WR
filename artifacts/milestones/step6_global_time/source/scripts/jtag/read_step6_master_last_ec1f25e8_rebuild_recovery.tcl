# Step6 ec1f25e8-source-rebuild Master-last recovery observer.
#
# This reader is passive.  It never writes Wishbone, changes PHY/PTP state,
# programs either board, or performs a reset.  The host runner performs one
# Master programming event between the baseline and recovery modes.
#
# Modes:
#   baseline  EXP-ID baseline 5 250
#   recovery  EXP-ID recovery 480 250 120000 BASELINE_LOG
#   postmortem EXP-ID postmortem 10 250 10000 BASELINE_LOG
#
# The baseline is paired and records the Slave sticky drop counters.  If the
# Slave is already linked before Master programming, recovery requires a
# fresh sticky drop followed by five good samples; a persistent sticky
# PATTERN_READY bit alone is not treated as reacquisition.

package require ::quartus::insystem_source_probe

set ::rb_trial_id "S6-MASTER-LAST-EC1F25E8-REBUILD-RECOVERY-ATTRIBUTION"
set ::rb_mode "baseline"
set ::rb_sample_limit 5
set ::rb_gap_ms 250
set ::rb_recovery_window_ms 120000
set ::rb_baseline_log ""
if {[llength $argv] >= 1} { set ::rb_trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::rb_mode [lindex $argv 1] }
if {[llength $argv] >= 3} { set ::rb_sample_limit [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set ::rb_gap_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set ::rb_recovery_window_ms [expr {int([lindex $argv 4])}] }
if {[llength $argv] >= 6} { set ::rb_baseline_log [lindex $argv 5] }
if {$rb_mode ni {baseline recovery postmortem}} {
  error "mode must be baseline, recovery, or postmortem"
}
if {$rb_sample_limit <= 0 || $rb_gap_ms < 0 || $rb_recovery_window_ms <= 0} {
  error "invalid sample, gap, or recovery window argument"
}
if {$rb_mode eq "recovery" && $rb_baseline_log eq ""} {
  error "recovery mode requires baseline log path"
}
if {$rb_mode eq "postmortem" && $rb_baseline_log eq ""} {
  error "postmortem mode requires baseline log path"
}

set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

array set ::rb_previous_activity {}

proc rb_raw_valid {value} {
  return [expr {$value ne "TIMEOUT" && $value ne "INVALID" &&
                $value ne "DECREASED" && [is_hex $value]}]
}

proc rb_hex32 {value} {
  set number [word32 $value]
  if {$number < 0} { return INVALID }
  return [format %08X $number]
}

proc rb_probe64 {value} {
  if {![rb_raw_valid $value]} { return $value }
  return [normalize_probe64 $value]
}

proc rb_activity_count {clock} {
  if {![rb_raw_valid $clock]} { return -1 }
  set high [probe_high32 $clock]
  if {$high < 0} { return -1 }
  return [expr {$high & 0xffff}]
}

proc rb_counter32 {raw high_word} {
  if {![rb_raw_valid $raw]} { return -1 }
  if {$high_word} { return [probe_high32 $raw] }
  return [word32 $raw]
}

proc rb_counter_delta {before after} {
  if {$before < 0 || $after < 0} { return INVALID }
  if {$after < $before} { return DECREASED }
  return [expr {$after - $before}]
}

proc rb_reset_signature {snapshot} {
  array set s $snapshot
  return [list $s(BOOT_GENERATION) $s(CPU_RESET_COUNT) \
    $s(WR_CORE_RESET_COUNT) $s(SI_CONFIG_DROP_COUNT)]
}

proc rb_reset_changed {old new} {
  if {$old eq "" || $new eq ""} { return 0 }
  return [expr {$old ne $new}]
}

proc rb_basic_ready {snapshot} {
  if {$snapshot eq ""} { return 0 }
  array set s $snapshot
  return [expr {$s(READ_VALID) == 1 &&
    $s(SI_CONFIG_DONE) == 1 && $s(WR_READY) == 1 &&
    $s(RX_READY) == 1 && $s(TX_READY) == 1 &&
    $s(CPU_RESET_N) == 1 && $s(PHY_RST) == 0 &&
    $s(PHY_TX_DISABLE) == 0}]
}

proc rb_master_local_ready {snapshot} {
  if {![rb_basic_ready $snapshot]} { return 0 }
  array set s $snapshot
  return [expr {$s(PTP_STATE) == 6}]
}

proc rb_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc rb_snapshot {hardware_name role sample elapsed_ms} {
  set status [safe_probe_read 0]
  set clock [safe_probe_read 7]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set ecr [wb_read 0x00100100]
  set dsr [wb_read 0x00100138]
  set ptp [wb_read 0x00100A10]

  set sticky45 "NA"
  set sticky46 "NA"
  set sticky47 "NA"
  set sticky48 "NA"
  if {$role eq "SLAVE"} {
    set sticky45 [safe_probe_read 45]
    set sticky46 [safe_probe_read 46]
    set sticky47 [safe_probe_read 47]
    set sticky48 [safe_probe_read 48]
  }

  set reset_values [list INVALID INVALID INVALID INVALID]
  if {[rb_raw_valid $entry] && [rb_raw_valid $reset]} {
    set reset_values [list \
      [probe_high_counter_hex $entry] \
      [probe_byte_counter_hex $reset 16] \
      [probe_byte_counter_hex $reset 24] \
      [probe_byte_counter_hex $reset 40]]
  }
  lassign $reset_values boot_generation cpu_reset_count \
    wr_core_reset_count si_config_drop_count

  set read_valid 1
  foreach value [list $status $clock $entry $reset $ecr $dsr $ptp] {
    if {![rb_raw_valid $value]} { set read_valid 0 }
  }
  if {$role eq "SLAVE"} {
    foreach value [list $sticky45 $sticky46 $sticky47 $sticky48] {
      if {![rb_raw_valid $value]} { set read_valid 0 }
    }
  }
  foreach value [list $boot_generation $cpu_reset_count \
      $wr_core_reset_count $si_config_drop_count] {
    if {$value eq "INVALID"} { set read_valid 0 }
  }

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
  set rx_activity_count [rb_activity_count $clock]
  set ecr_tx_en [bit32 $ecr 6]
  set ecr_rx_en [bit32 $ecr 7]
  set dsr_link [bit32 $dsr 0]
  set dsr_activity [bit32 $dsr 1]
  set ptp_state [field32 $ptp 0 8]

  set sticky45_enc [rb_counter32 $sticky45 0]
  set sticky45_disperr [rb_counter32 $sticky45 1]
  set sticky46_errdetect [rb_counter32 $sticky46 0]
  set sticky46_sync_loss [rb_counter32 $sticky46 1]
  set sticky47_lock_loss [rb_counter32 $sticky47 0]
  set sticky47_link_drop [rb_counter32 $sticky47 1]
  set sticky48_tm_link_drop [rb_counter32 $sticky48 0]

  set activity_changed 0
  if {[info exists ::rb_previous_activity($hardware_name)] &&
      $rx_activity_count >= 0 &&
      $::rb_previous_activity($hardware_name) >= 0 &&
      $rx_activity_count != $::rb_previous_activity($hardware_name)} {
    set activity_changed 1
  }
  set ::rb_previous_activity($hardware_name) $rx_activity_count

  return [list \
    ROLE $role BOARD $role SAMPLE $sample ELAPSED_MS $elapsed_ms \
    READ_VALID $read_valid STATUS_RAW [rb_probe64 $status] \
    CLOCK_ACTIVITY_RAW [rb_probe64 $clock] ENTRY_RAW [rb_probe64 $entry] \
    RESET_RAW [rb_probe64 $reset] ECR_RAW [rb_hex32 $ecr] \
    DSR_RAW [rb_hex32 $dsr] PTP_RAW [rb_hex32 $ptp] \
    SI_CONFIG_DONE $si_config_done WR_READY $wr_ready \
    RX_READY $rx_ready TX_READY $tx_ready CPU_RESET_N $cpu_reset_n \
    PHY_RST $phy_rst PHY_TX_DISABLE $phy_tx_disable \
    CORE_TM_LINK_UP $core_tm_link_up CORE_LINK_OK $core_link_ok \
    RX_LOCKED_TO_DATA $rx_locked_to_data RX_SYNCSTATUS $rx_syncstatus \
    RX_PATTERN_READY $rx_pattern_ready RX_ACTIVITY_COUNT $rx_activity_count \
    RX_ACTIVITY_CHANGED $activity_changed ECR_TX_EN $ecr_tx_en \
    ECR_RX_EN $ecr_rx_en DSR_LINK $dsr_link DSR_ACTIVITY $dsr_activity \
    PTP_STATE $ptp_state BOOT_GENERATION $boot_generation \
    CPU_RESET_COUNT $cpu_reset_count WR_CORE_RESET_COUNT $wr_core_reset_count \
    SI_CONFIG_DROP_COUNT $si_config_drop_count \
    STICKY45_ENC $sticky45_enc STICKY45_DISPERR $sticky45_disperr \
    STICKY46_ERRDETECT $sticky46_errdetect \
    STICKY46_SYNC_LOSS $sticky46_sync_loss \
    STICKY47_LOCK_LOSS $sticky47_lock_loss \
    STICKY47_LINK_DROP $sticky47_link_drop \
    STICKY48_TM_LINK_DROP $sticky48_tm_link_drop]
}

proc rb_open_board {hardware_name} {
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { error "no device for $hardware_name" }
  catch {end_insystem_source_probe}
  start_insystem_source_probe -hardware_name $hardware_name \
    -device_name [lindex $devices 0]
  wb_sync_toggle
}

proc rb_close_board {} { catch {end_insystem_source_probe} }

proc rb_collect {hardware_name role sample elapsed_ms} {
  set snapshot {}
  if {[catch {
    rb_open_board $hardware_name
    set snapshot [rb_snapshot $hardware_name $role $sample $elapsed_ms]
  } error_message]} {
    set snapshot {}
  }
  rb_close_board
  return $snapshot
}

proc rb_baseline_last_field {path role key} {
  if {![file exists $path]} { return "" }
  set handle [open $path r]
  set value ""
  while {[gets $handle line] >= 0} {
    if {[string first "REBUILD_BASELINE_PAIR" $line] != 0} { continue }
    set pattern [format {(^| )%s=([^ ]+)} $key]
    if {[regexp $pattern $line -> prefix candidate]} {
      set value $candidate
    }
  }
  close $handle
  return $value
}

proc rb_baseline_scalar {path key} {
  if {![file exists $path]} { return "" }
  set handle [open $path r]
  set value ""
  while {[gets $handle line] >= 0} {
    set pattern [format {^%s=([^ ]+)} $key]
    if {[regexp $pattern $line -> candidate]} {
      set value $candidate
    }
  }
  close $handle
  return $value
}

set ::rb_master_hardware ""
set ::rb_slave_hardware ""
foreach hardware_name [get_hardware_names] {
  if {[string first "1-11.1" $hardware_name] >= 0} {
    set ::rb_master_hardware $hardware_name
  } elseif {[string first "1-11.2" $hardware_name] >= 0} {
    set ::rb_slave_hardware $hardware_name
  }
}
if {$::rb_master_hardware eq "" || $::rb_slave_hardware eq ""} {
  error "both DE5a targets are required"
}

puts [format "REBUILD_CONFIG trial=%s mode=%s samples=%d gap_ms=%d recovery_window_ms=%d read_only=1 master_compile_external=1 master_program_external=1 slave_program=0 power_cycle=0 mdio_write=0" \
  $::rb_trial_id $::rb_mode $::rb_sample_limit $::rb_gap_ms \
  $::rb_recovery_window_ms]
flush stdout

if {$::rb_mode eq "baseline"} {
  set begin_ms [clock milliseconds]
  set all_valid 1
  set all_basic 1
  set activity_seen 0
  set reset_changed 0
  set previous_master_reset ""
  set previous_slave_reset ""
  set last_master {}
  set last_slave {}
  set slave_link_up_count 0

  for {set sample 0} {$sample < $::rb_sample_limit} {incr sample} {
    set elapsed [expr {[clock milliseconds] - $begin_ms}]
    set master [rb_collect $::rb_master_hardware MASTER $sample $elapsed]
    set slave [rb_collect $::rb_slave_hardware SLAVE $sample $elapsed]
    if {$master eq "" || $slave eq ""} {
      set all_valid 0
      rb_emit REBUILD_BASELINE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 0 MASTER_BASIC_READY 0 SLAVE_BASIC_READY 0 \
        SLAVE_RX_LOCKED_TO_DATA 0 SLAVE_RX_ACTIVITY_CHANGED 0]
    } else {
      array set m $master
      array set s $slave
      set master_basic [rb_basic_ready $master]
      set slave_basic [rb_basic_ready $slave]
      set slave_rx_ok [expr {$s(RX_LOCKED_TO_DATA) == 1}]
      set all_basic [expr {$all_basic && $master_basic && $slave_basic}]
      set all_basic [expr {$all_basic && $slave_rx_ok}]
      set activity_seen [expr {$activity_seen || $s(RX_ACTIVITY_CHANGED) == 1}]
      if {$s(CORE_LINK_OK) == 1 && $s(CORE_TM_LINK_UP) == 1} {
        incr slave_link_up_count
      }
      set master_reset [rb_reset_signature $master]
      set slave_reset [rb_reset_signature $slave]
      if {$previous_master_reset ne "" &&
          [rb_reset_changed $previous_master_reset $master_reset]} {
        set reset_changed 1
      }
      if {$previous_slave_reset ne "" &&
          [rb_reset_changed $previous_slave_reset $slave_reset]} {
        set reset_changed 1
      }
      set previous_master_reset $master_reset
      set previous_slave_reset $slave_reset
      set last_master $master
      set last_slave $slave
      rb_emit REBUILD_BASELINE_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 1 MASTER_BASIC_READY $master_basic \
        SLAVE_BASIC_READY $slave_basic SLAVE_RX_LOCKED_TO_DATA $s(RX_LOCKED_TO_DATA) \
        SLAVE_RX_ACTIVITY_COUNT $s(RX_ACTIVITY_COUNT) \
        SLAVE_RX_ACTIVITY_CHANGED $s(RX_ACTIVITY_CHANGED) \
        MASTER_PTP_STATE $m(PTP_STATE) SLAVE_PTP_STATE $s(PTP_STATE) \
        MASTER_CORE_LINK_OK $m(CORE_LINK_OK) MASTER_CORE_TM_LINK_UP $m(CORE_TM_LINK_UP) \
        SLAVE_CORE_LINK_OK $s(CORE_LINK_OK) SLAVE_CORE_TM_LINK_UP $s(CORE_TM_LINK_UP) \
        SLAVE_STICKY45_ENC $s(STICKY45_ENC) \
        SLAVE_STICKY45_DISPERR $s(STICKY45_DISPERR) \
        SLAVE_STICKY46_ERRDETECT $s(STICKY46_ERRDETECT) \
        SLAVE_STICKY46_SYNC_LOSS $s(STICKY46_SYNC_LOSS) \
        SLAVE_STICKY47_LOCK_LOSS $s(STICKY47_LOCK_LOSS) \
        SLAVE_STICKY47_LINK_DROP $s(STICKY47_LINK_DROP) \
        SLAVE_STICKY48_TM_LINK_DROP $s(STICKY48_TM_LINK_DROP) \
        MASTER_BOOT_GENERATION $m(BOOT_GENERATION) \
        SLAVE_BOOT_GENERATION $s(BOOT_GENERATION) RESET_CHANGED $reset_changed]
    }
    flush stdout
    if {$sample + 1 < $::rb_sample_limit} { after $::rb_gap_ms }
  }

  if {!$all_valid} {
    puts "BASELINE_RESULT=INCONCLUSIVE_TRANSPORT"
  } elseif {$reset_changed} {
    puts "BASELINE_RESULT=INCONCLUSIVE_RESET"
  } elseif {!$all_basic || !$activity_seen} {
    puts [format "BASELINE_RESULT=INCONCLUSIVE_PREPROGRAM_SLAVE_HEALTH MASTER_BASIC_READY=%d SLAVE_BASIC_READY=%d SLAVE_RX_ACTIVITY_PRESENT=%d" \
      [expr {$last_master ne {} ? [rb_basic_ready $last_master] : 0}] \
      [expr {$last_slave ne {} ? [rb_basic_ready $last_slave] : 0}] $activity_seen]
  } else {
    puts "BASELINE_RESULT=PASS"
  }
  puts "BASELINE_SAMPLE_COUNT=$::rb_sample_limit"
  puts "BASELINE_SLAVE_LINK_UP_COUNT=$slave_link_up_count"
  puts [format "BASELINE_SLAVE_LINK_MODE=%s" \
    [expr {$slave_link_up_count == 0 ? "DOWN" : \
          ($slave_link_up_count == $::rb_sample_limit ? "UP" : "MIXED")}]]
  puts [format "BASELINE_DONE samples=%d elapsed_ms=%d" $::rb_sample_limit \
    [expr {[clock milliseconds] - $begin_ms}]]
  flush stdout
  return
}

if {$::rb_mode eq "postmortem"} {
  # This is a read-only postmortem of the already-completed Master rebuild.
  # It deliberately does not program, reset, or otherwise perturb either board.
  set baseline_result [rb_baseline_scalar $::rb_baseline_log BASELINE_RESULT]
  set baseline_samples [rb_baseline_scalar $::rb_baseline_log BASELINE_SAMPLE_COUNT]
  set baseline_link_count [rb_baseline_scalar $::rb_baseline_log BASELINE_SLAVE_LINK_UP_COUNT]
  set baseline_link_mode [rb_baseline_scalar $::rb_baseline_log BASELINE_SLAVE_LINK_MODE]
  if {$baseline_result ne "PASS" || $baseline_samples eq "" ||
      $baseline_link_count eq "" || $baseline_link_mode ni {UP DOWN}} {
    error "baseline log is not a completed PASS capture"
  }

  set baseline_sticky46_sync_loss [rb_baseline_last_field \
    $::rb_baseline_log SLAVE SLAVE_STICKY46_SYNC_LOSS]
  set baseline_sticky47_lock_loss [rb_baseline_last_field \
    $::rb_baseline_log SLAVE SLAVE_STICKY47_LOCK_LOSS]
  set baseline_sticky47_link_drop [rb_baseline_last_field \
    $::rb_baseline_log SLAVE SLAVE_STICKY47_LINK_DROP]
  set baseline_sticky48_tm_link_drop [rb_baseline_last_field \
    $::rb_baseline_log SLAVE SLAVE_STICKY48_TM_LINK_DROP]
  set baseline_slave_boot [rb_baseline_last_field \
    $::rb_baseline_log SLAVE SLAVE_BOOT_GENERATION]
  foreach value [list $baseline_sticky46_sync_loss \
      $baseline_sticky47_lock_loss $baseline_sticky47_link_drop \
      $baseline_sticky48_tm_link_drop] {
    if {![string is integer -strict $value]} {
      error "baseline sticky counter unavailable"
    }
  }
  if {$baseline_slave_boot eq ""} {
    error "baseline Slave boot generation unavailable"
  }

  set begin_ms [clock milliseconds]
  set sample 0
  set transport_error 0
  set reset_changed 0
  set link_drop_seen 0
  set tm_link_drop_seen 0
  set sync_loss_seen 0
  set lock_loss_seen 0
  set stable_streak 0
  set max_stable_streak 0
  set previous_master_reset ""
  set previous_slave_reset ""
  set last_slave_boot ""
  set result NONE

  while {$sample < $::rb_sample_limit &&
         ([clock milliseconds] - $begin_ms) <= $::rb_recovery_window_ms &&
         $result eq "NONE"} {
    set elapsed [expr {[clock milliseconds] - $begin_ms}]
    set master [rb_collect $::rb_master_hardware MASTER $sample $elapsed]
    set slave [rb_collect $::rb_slave_hardware SLAVE $sample $elapsed]
    if {$master eq "" || $slave eq ""} {
      set transport_error 1
      rb_emit POSTMORTEM_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 0 MASTER_LOCAL_READY 0 STABLE_GOOD 0 \
        STABLE_STREAK $stable_streak MAX_STABLE_STREAK $max_stable_streak \
        LINK_DROP_SEEN $link_drop_seen TM_LINK_DROP_SEEN $tm_link_drop_seen \
        RESET_CHANGED 0]
      set result INCONCLUSIVE_TRANSPORT
      break
    }

    array set m $master
    array set s $slave
    set read_valid [expr {$m(READ_VALID) == 1 && $s(READ_VALID) == 1}]
    if {!$read_valid} {
      set transport_error 1
      rb_emit POSTMORTEM_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
        READ_VALID 0 MASTER_LOCAL_READY 0 STABLE_GOOD 0 \
        STABLE_STREAK $stable_streak MAX_STABLE_STREAK $max_stable_streak \
        LINK_DROP_SEEN $link_drop_seen TM_LINK_DROP_SEEN $tm_link_drop_seen \
        RESET_CHANGED 0]
      set result INCONCLUSIVE_TRANSPORT
      break
    }

    set master_reset [rb_reset_signature $master]
    set slave_reset [rb_reset_signature $slave]
    set pair_reset_changed 0
    if {$previous_master_reset ne "" &&
        [rb_reset_changed $previous_master_reset $master_reset]} {
      set pair_reset_changed 1
    }
    if {$previous_slave_reset ne "" &&
        [rb_reset_changed $previous_slave_reset $slave_reset]} {
      set pair_reset_changed 1
    }
    if {$last_slave_boot ne "" && $s(BOOT_GENERATION) ne $last_slave_boot} {
      set pair_reset_changed 1
    }
    if {$s(BOOT_GENERATION) ne $baseline_slave_boot} {
      set pair_reset_changed 1
    }
    if {$pair_reset_changed} { set reset_changed 1 }
    set previous_master_reset $master_reset
    set previous_slave_reset $slave_reset
    set last_slave_boot $s(BOOT_GENERATION)

    set link_drop_delta [rb_counter_delta $baseline_sticky47_link_drop \
      $s(STICKY47_LINK_DROP)]
    set tm_link_drop_delta [rb_counter_delta $baseline_sticky48_tm_link_drop \
      $s(STICKY48_TM_LINK_DROP)]
    set sync_loss_delta [rb_counter_delta $baseline_sticky46_sync_loss \
      $s(STICKY46_SYNC_LOSS)]
    set lock_loss_delta [rb_counter_delta $baseline_sticky47_lock_loss \
      $s(STICKY47_LOCK_LOSS)]
    if {$link_drop_delta ne "INVALID" && $link_drop_delta ne "DECREASED" &&
        $link_drop_delta > 0} { set link_drop_seen 1 }
    if {$tm_link_drop_delta ne "INVALID" &&
        $tm_link_drop_delta ne "DECREASED" && $tm_link_drop_delta > 0} {
      set tm_link_drop_seen 1
    }
    if {$sync_loss_delta ne "INVALID" &&
        $sync_loss_delta ne "DECREASED" && $sync_loss_delta > 0} {
      set sync_loss_seen 1
    }
    if {$lock_loss_delta ne "INVALID" &&
        $lock_loss_delta ne "DECREASED" && $lock_loss_delta > 0} {
      set lock_loss_seen 1
    }

    set master_local_ready [rb_master_local_ready $master]
    set stable_good [expr {$master_local_ready &&
      $s(RX_LOCKED_TO_DATA) == 1 &&
      $s(RX_ACTIVITY_CHANGED) == 1 &&
      $s(RX_PATTERN_READY) == 1 &&
      $s(CORE_LINK_OK) == 1 &&
      $s(CORE_TM_LINK_UP) == 1 &&
      !$pair_reset_changed}]
    if {$stable_good} {
      incr stable_streak
      if {$stable_streak > $max_stable_streak} {
        set max_stable_streak $stable_streak
      }
    } else {
      set stable_streak 0
    }

    rb_emit POSTMORTEM_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
      READ_VALID 1 MASTER_LOCAL_READY $master_local_ready \
      MASTER_SI_CONFIG_DONE $m(SI_CONFIG_DONE) MASTER_WR_READY $m(WR_READY) \
      MASTER_RX_READY $m(RX_READY) MASTER_TX_READY $m(TX_READY) \
      MASTER_CPU_RESET_N $m(CPU_RESET_N) MASTER_PHY_RST $m(PHY_RST) \
      MASTER_PHY_TX_DISABLE $m(PHY_TX_DISABLE) MASTER_PTP_STATE $m(PTP_STATE) \
      SLAVE_RX_LOCKED_TO_DATA $s(RX_LOCKED_TO_DATA) \
      SLAVE_RX_ACTIVITY_COUNT $s(RX_ACTIVITY_COUNT) \
      SLAVE_RX_ACTIVITY_CHANGED $s(RX_ACTIVITY_CHANGED) \
      SLAVE_RX_PATTERN_READY $s(RX_PATTERN_READY) \
      SLAVE_CORE_LINK_OK $s(CORE_LINK_OK) \
      SLAVE_CORE_TM_LINK_UP $s(CORE_TM_LINK_UP) \
      LINK_DROP_DELTA $link_drop_delta TM_LINK_DROP_DELTA $tm_link_drop_delta \
      SYNC_LOSS_DELTA $sync_loss_delta LOCK_LOSS_DELTA $lock_loss_delta \
      LINK_DROP_SEEN $link_drop_seen TM_LINK_DROP_SEEN $tm_link_drop_seen \
      LINK_DROP_EVIDENCE [expr {$link_drop_seen || $tm_link_drop_seen}] \
      STABLE_GOOD $stable_good STABLE_STREAK $stable_streak \
      MAX_STABLE_STREAK $max_stable_streak \
      MASTER_BOOT_GENERATION $m(BOOT_GENERATION) \
      SLAVE_BOOT_GENERATION $s(BOOT_GENERATION) \
      MASTER_CPU_RESET_COUNT $m(CPU_RESET_COUNT) \
      SLAVE_CPU_RESET_COUNT $s(CPU_RESET_COUNT) \
      MASTER_WR_CORE_RESET_COUNT $m(WR_CORE_RESET_COUNT) \
      SLAVE_WR_CORE_RESET_COUNT $s(WR_CORE_RESET_COUNT) \
      MASTER_SI_CONFIG_DROP_COUNT $m(SI_CONFIG_DROP_COUNT) \
      SLAVE_SI_CONFIG_DROP_COUNT $s(SI_CONFIG_DROP_COUNT) \
      RESET_CHANGED $pair_reset_changed]
    flush stdout

    if {$pair_reset_changed} {
      set result INCONCLUSIVE_RESET
    }
    incr sample
    if {$result eq "NONE" && $sample < $::rb_sample_limit} {
      after $::rb_gap_ms
    }
  }

  if {$result eq "NONE"} {
    if {$transport_error} {
      set result INCONCLUSIVE_TRANSPORT
    } elseif {$reset_changed} {
      set result INCONCLUSIVE_RESET
    } elseif {($link_drop_seen || $tm_link_drop_seen) &&
              $max_stable_streak >= 5} {
      set result PASS_POSTMORTEM_DROP_AND_REACQUISITION
    } elseif {$link_drop_seen || $tm_link_drop_seen} {
      set result FAIL_STABLE_REACQUISITION_NOT_PRESENT_POSTMORTEM
    } elseif {$sync_loss_seen || $lock_loss_seen} {
      set result INCONCLUSIVE_ONLY_PHY_LOSS_EVIDENCE
    } else {
      set result INCONCLUSIVE_POSTMORTEM_NO_LINK_DROP_EVIDENCE
    }
  }
  puts [format "POSTMORTEM_RESULT=%s LINK_DROP_SEEN=%d TM_LINK_DROP_SEEN=%d SYNC_LOSS_SEEN=%d LOCK_LOSS_SEEN=%d MAX_STABLE_STREAK=%d SAMPLES=%d ELAPSED_MS=%d" \
    $result $link_drop_seen $tm_link_drop_seen $sync_loss_seen $lock_loss_seen \
    $max_stable_streak $sample [expr {[clock milliseconds] - $begin_ms}]]
  puts [format "POSTMORTEM_DONE result=%s" $result]
  flush stdout
  return
}

set baseline_result [rb_baseline_scalar $::rb_baseline_log BASELINE_RESULT]
set baseline_samples [rb_baseline_scalar $::rb_baseline_log BASELINE_SAMPLE_COUNT]
set baseline_link_count [rb_baseline_scalar $::rb_baseline_log BASELINE_SLAVE_LINK_UP_COUNT]
if {$baseline_result ne "PASS" || $baseline_samples eq "" ||
    $baseline_link_count eq ""} {
  error "baseline log is not a completed PASS capture"
}
set baseline_link_mode [rb_baseline_scalar $::rb_baseline_log BASELINE_SLAVE_LINK_MODE]
if {$baseline_link_mode ni {UP DOWN}} {
  error "baseline link state is mixed"
}

set baseline_sticky45_enc [rb_baseline_last_field $::rb_baseline_log SLAVE SLAVE_STICKY45_ENC]
set baseline_sticky45_disperr [rb_baseline_last_field $::rb_baseline_log SLAVE SLAVE_STICKY45_DISPERR]
set baseline_sticky46_errdetect [rb_baseline_last_field $::rb_baseline_log SLAVE SLAVE_STICKY46_ERRDETECT]
set baseline_sticky46_sync_loss [rb_baseline_last_field $::rb_baseline_log SLAVE SLAVE_STICKY46_SYNC_LOSS]
set baseline_sticky47_lock_loss [rb_baseline_last_field $::rb_baseline_log SLAVE SLAVE_STICKY47_LOCK_LOSS]
set baseline_sticky47_link_drop [rb_baseline_last_field $::rb_baseline_log SLAVE SLAVE_STICKY47_LINK_DROP]
set baseline_sticky48_tm_link_drop [rb_baseline_last_field $::rb_baseline_log SLAVE SLAVE_STICKY48_TM_LINK_DROP]
foreach value [list $baseline_sticky45_enc $baseline_sticky45_disperr \
    $baseline_sticky46_errdetect $baseline_sticky46_sync_loss \
    $baseline_sticky47_lock_loss $baseline_sticky47_link_drop \
    $baseline_sticky48_tm_link_drop] {
  if {![string is integer -strict $value] || $value < 0} {
    error "baseline sticky counter unavailable"
  }
}

set begin_ms [clock milliseconds]
set sample 0
set first_valid_ms -1
set master_ready_streak 0
set master_local_ready_ms -1
set recovery_streak 0
set max_recovery_streak 0
set recovery_seen 0
set eligible_recovery_seen 0
set previous_eligible_good 0
set first_recovery_ms -1
set first_eligible_recovery_ms -1
set sticky_drop_observed 0
set max_sticky_delta 0
set reset_changed 0
set result NONE
set master_reset_baseline ""
set slave_reset_baseline ""

while {$sample < $::rb_sample_limit &&
       ([clock milliseconds] - $begin_ms) <= $::rb_recovery_window_ms &&
       $result eq "NONE"} {
  set elapsed [expr {[clock milliseconds] - $begin_ms}]
  set master [rb_collect $::rb_master_hardware MASTER $sample $elapsed]
  set slave [rb_collect $::rb_slave_hardware SLAVE $sample $elapsed]
  if {$master eq "" || $slave eq ""} {
    rb_emit REBUILD_RECOVERY_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
      READ_VALID 0 MASTER_LOCAL_READY 0 MASTER_READY_STREAK $master_ready_streak \
      SLAVE_RECOVERY_GOOD 0 SLAVE_RECOVERY_ELIGIBLE 0 \
      SLAVE_RECOVERY_STREAK $recovery_streak STICKY_DROP_OBSERVED $sticky_drop_observed \
      RESET_CHANGED 0]
    set result INCONCLUSIVE_TRANSPORT
    break
  }

  array set m $master
  array set s $slave
  if {$first_valid_ms < 0} { set first_valid_ms $elapsed }
  if {$master_reset_baseline eq ""} {
    set master_reset_baseline [rb_reset_signature $master]
    set slave_reset_baseline [rb_reset_signature $slave]
  } else {
    if {[rb_reset_changed $master_reset_baseline [rb_reset_signature $master]] ||
        [rb_reset_changed $slave_reset_baseline [rb_reset_signature $slave]]} {
      set reset_changed 1
    }
  }

  if {[rb_master_local_ready $master]} {
    incr master_ready_streak
  } else {
    set master_ready_streak 0
  }
  if {$master_ready_streak >= 3 && $master_local_ready_ms < 0} {
    set master_local_ready_ms $elapsed
  }

  set sticky_deltas [list \
    [rb_counter_delta $baseline_sticky45_enc $s(STICKY45_ENC)] \
    [rb_counter_delta $baseline_sticky45_disperr $s(STICKY45_DISPERR)] \
    [rb_counter_delta $baseline_sticky46_errdetect $s(STICKY46_ERRDETECT)] \
    [rb_counter_delta $baseline_sticky46_sync_loss $s(STICKY46_SYNC_LOSS)] \
    [rb_counter_delta $baseline_sticky47_lock_loss $s(STICKY47_LOCK_LOSS)] \
    [rb_counter_delta $baseline_sticky47_link_drop $s(STICKY47_LINK_DROP)] \
    [rb_counter_delta $baseline_sticky48_tm_link_drop $s(STICKY48_TM_LINK_DROP)]]
  set sticky_delta_valid 1
  set sticky_delta_seen 0
  foreach delta $sticky_deltas {
    if {$delta eq "INVALID" || $delta eq "DECREASED"} {
      set sticky_delta_valid 0
    } elseif {$delta > 0} {
      set sticky_delta_seen 1
      if {$delta > $max_sticky_delta} { set max_sticky_delta $delta }
    }
  }
  if {$sticky_delta_seen} { set sticky_drop_observed 1 }

  set recovery_good [expr {$s(READ_VALID) == 1 &&
    $s(RX_LOCKED_TO_DATA) == 1 && $s(RX_ACTIVITY_CHANGED) == 1 &&
    $s(RX_PATTERN_READY) == 1 && $s(CORE_LINK_OK) == 1 &&
    $s(CORE_TM_LINK_UP) == 1}]
  set recovery_evidence [expr {$s(RX_PATTERN_READY) == 1 &&
    $s(CORE_LINK_OK) == 1 && $s(CORE_TM_LINK_UP) == 1}]
  if {$recovery_evidence && $first_recovery_ms < 0} {
    set first_recovery_ms $elapsed
  }
  if {$recovery_evidence} { set recovery_seen 1 }

  set eligible 1
  if {$baseline_link_mode eq "UP"} {
    set eligible [expr {$sticky_drop_observed && $sticky_delta_valid}]
  }
  set eligible_good [expr {$eligible && $recovery_good}]
  if {$eligible_good} {
    set eligible_recovery_seen 1
    if {$first_eligible_recovery_ms < 0} { set first_eligible_recovery_ms $elapsed }
    incr recovery_streak
    if {$recovery_streak > $max_recovery_streak} {
      set max_recovery_streak $recovery_streak
    }
  } else {
    set recovery_streak 0
  }

  rb_emit REBUILD_RECOVERY_PAIR [list SAMPLE $sample ELAPSED_MS $elapsed \
    READ_VALID 1 MASTER_LOCAL_READY [rb_master_local_ready $master] \
    MASTER_READY_STREAK $master_ready_streak MASTER_PTP_STATE $m(PTP_STATE) \
    SLAVE_RX_LOCKED_TO_DATA $s(RX_LOCKED_TO_DATA) \
    SLAVE_RX_ACTIVITY_COUNT $s(RX_ACTIVITY_COUNT) \
    SLAVE_RX_ACTIVITY_CHANGED $s(RX_ACTIVITY_CHANGED) \
    SLAVE_RX_PATTERN_READY $s(RX_PATTERN_READY) \
    SLAVE_CORE_LINK_OK $s(CORE_LINK_OK) SLAVE_CORE_TM_LINK_UP $s(CORE_TM_LINK_UP) \
    SLAVE_STICKY45_ENC $s(STICKY45_ENC) \
    SLAVE_STICKY45_DISPERR $s(STICKY45_DISPERR) \
    SLAVE_STICKY46_ERRDETECT $s(STICKY46_ERRDETECT) \
    SLAVE_STICKY46_SYNC_LOSS $s(STICKY46_SYNC_LOSS) \
    SLAVE_STICKY47_LOCK_LOSS $s(STICKY47_LOCK_LOSS) \
    SLAVE_STICKY47_LINK_DROP $s(STICKY47_LINK_DROP) \
    SLAVE_STICKY48_TM_LINK_DROP $s(STICKY48_TM_LINK_DROP) \
    STICKY_DELTA_VALID $sticky_delta_valid STICKY_DELTA_SEEN $sticky_delta_seen \
    STICKY_DROP_OBSERVED $sticky_drop_observed \
    BASELINE_LINK_MODE $baseline_link_mode SLAVE_RECOVERY_GOOD $recovery_good \
    SLAVE_RECOVERY_ELIGIBLE $eligible_good SLAVE_RECOVERY_SEEN $recovery_seen \
    SLAVE_RECOVERY_STREAK $recovery_streak MAX_RECOVERY_STREAK $max_recovery_streak \
    MASTER_BOOT_GENERATION $m(BOOT_GENERATION) SLAVE_BOOT_GENERATION $s(BOOT_GENERATION) \
    RESET_CHANGED $reset_changed]
  flush stdout

  if {$reset_changed} {
    set result INCONCLUSIVE_RESET
  } elseif {$master_ready_streak >= 3 && $recovery_streak >= 5} {
    set result PASS_REBUILT_MASTER_LAST_RECOVERY
  } elseif {$eligible_recovery_seen && $previous_eligible_good && !$eligible_good} {
    set result FAIL_TRANSIENT_RECOVERY
  } elseif {$master_local_ready_ms < 0 && $elapsed >= 10000} {
    set result INCONCLUSIVE_MASTER_LOCAL_READY
  }
  set previous_eligible_good $eligible_good
  incr sample
  if {$result eq "NONE" && $sample < $::rb_sample_limit} { after $::rb_gap_ms }
}

if {$result eq "NONE"} {
  set result FAIL_REBUILT_MASTER_LAST_RECOVERY_NOT_REPRODUCED
}
puts [format "REBUILD_RECOVERY_RESULT=%s BASELINE_LINK_MODE=%s STICKY_DROP_OBSERVED=%d FIRST_VALID_MS=%d MASTER_LOCAL_READY_MS=%d FIRST_RECOVERY_MS=%d FIRST_ELIGIBLE_RECOVERY_MS=%d MAX_RECOVERY_STREAK=%d MAX_STICKY_DELTA=%d SAMPLES=%d ELAPSED_MS=%d" \
  $result $baseline_link_mode $sticky_drop_observed $first_valid_ms \
  $master_local_ready_ms $first_recovery_ms $first_eligible_recovery_ms \
  $max_recovery_streak $max_sticky_delta $sample \
  [expr {[clock milliseconds] - $begin_ms}]]
puts [format "REBUILD_RECOVERY_DONE result=%s" $result]
flush stdout
