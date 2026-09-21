# Step6 Master TX K28.5 comma attribution observer.
#
# This script is strictly read-only.  It assumes that the caller has already
# compiled and programmed the Master diagnostic image exactly once, while the
# existing Slave image is left untouched.  It does not write Wishbone, reset
# either board, restart PTP, issue a mode command, or change any PHY setting.
#
# Probe contract added by the Master diagnostic image:
#   instance 0  -> existing WR status probe
#   instance 26 -> existing CPU entry/generation probe
#   instance 27 -> existing sticky reset counters
#   instance 65 -> TX_CYCLE_COUNT[31:0], TX_K28P5_COUNT[63:32]
#   instance 66 -> TX boundary/status context
#
# Usage:
#   quartus_stp -t read_step6_master_tx_comma_attribution.tcl \
#       ?trial_id? ?board_filter? ?local_ready_samples? ?gap_ms?

package require ::quartus::insystem_source_probe

set ::trial_id "S6-MASTER-TX-K28P5-COMMA-EMISSION-ATTRIBUTION"
set ::board_filter ""
set ::local_ready_sample_limit 30
set ::gap_ms 100
set ::required_ready_streak 3
set ::formal_sample_limit 5
set ::formal_window_ms 2000
set ::local_ready_window_ms 5000
if {[llength $argv] >= 1} { set ::trial_id [lindex $argv 0] }
if {[llength $argv] >= 2} { set ::board_filter [lindex $argv 1] }
if {[llength $argv] >= 3} {
  set ::local_ready_sample_limit [expr {int([lindex $argv 2])}]
}
if {[llength $argv] >= 4} { set ::gap_ms [expr {int([lindex $argv 3])}] }
if {$::local_ready_sample_limit <= 0 || $::gap_ms < 0} {
  error "local_ready_sample_limit must be > 0 and gap_ms must be >= 0"
}

# Reuse only the validated read-only probe transport helpers.  Library mode
# prevents read_wb_runtime.tcl from running its dashboard or any observation
# loop while it is sourced.
set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]

proc comma_raw_valid {value} {
  return [expr {$value ne "TIMEOUT" && $value ne "INVALID" &&
                $value ne "NA" && [is_hex $value]}]
}

proc comma_probe64 {value} {
  if {![comma_raw_valid $value]} { return $value }
  return [normalize_probe64 $value]
}

proc comma_counter_part {raw high} {
  if {![comma_raw_valid $raw]} { return -1 }
  if {$high} { return [probe_high32 $raw] }
  return [probe_low32 $raw]
}

proc comma_delta32_numeric {before after} {
  if {$before < 0 || $after < 0} { return INVALID }
  if {$after < $before} { return DECREASED }
  return [expr {$after - $before}]
}

proc comma_reset_fields {entry reset} {
  return [list \
    [probe_high_counter_hex $entry] \
    [probe_byte_counter_hex $reset 16] \
    [probe_byte_counter_hex $reset 24] \
    [probe_byte_counter_hex $reset 40]]
}

proc comma_emit {prefix pairs} {
  set tokens [list $prefix]
  foreach {key value} $pairs {
    lappend tokens [format "%s=%s" $key $value]
  }
  puts [join $tokens " "]
  flush stdout
}

proc comma_master_snapshot {hardware_name sample elapsed_ms} {
  set status [safe_probe_read 0]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]
  set counters [safe_probe_read 65]
  set tx_context [safe_probe_read 66]

  set read_valid 1
  foreach value [list $status $entry $reset $counters $tx_context] {
    if {![comma_raw_valid $value]} { set read_valid 0 }
  }

  set si_config_done [bit32 $status 0]
  set wr_ready [bit32 $status 1]
  set cpu_reset_n [bit32 $status 15]
  set cycle_count [comma_counter_part $counters 0]
  set k28p5_count [comma_counter_part $counters 1]

  set tx_data [field32 $tx_context 0 8]
  set tx_k [bit32 $tx_context 8]
  set tx_ready [bit32 $tx_context 9]
  set tx_enc_err [bit32 $tx_context 10]
  set phy_rst [bit32 $tx_context 11]
  set phy_tx_disable [bit32 $tx_context 12]

  set reset_fields [comma_reset_fields $entry $reset]
  lassign $reset_fields boot_generation cpu_reset_count wr_core_reset_count \
    si_config_drop_count

  set local_ready [expr {$read_valid &&
                         $si_config_done == 1 &&
                         $wr_ready == 1 &&
                         $tx_ready == 1 &&
                         $cpu_reset_n == 1 &&
                         $phy_rst == 0 &&
                         $phy_tx_disable == 0}]

  return [list \
    ROLE MASTER BOARD $hardware_name SAMPLE $sample ELAPSED_MS $elapsed_ms \
    READ_VALID $read_valid STATUS_RAW [comma_probe64 $status] \
    COUNTER_RAW [comma_probe64 $counters] TX_CONTEXT_RAW [comma_probe64 $tx_context] \
    ENTRY_RAW [comma_probe64 $entry] RESET_RAW [comma_probe64 $reset] \
    SI_CONFIG_DONE $si_config_done WR_READY $wr_ready TX_READY $tx_ready \
    CPU_RESET_N $cpu_reset_n PHY_RST $phy_rst PHY_TX_DISABLE $phy_tx_disable \
    TX_DATA $tx_data TX_K $tx_k TX_ENC_ERR $tx_enc_err \
    TX_CYCLE_COUNT $cycle_count TX_K28P5_COUNT $k28p5_count \
    BOOT_GENERATION $boot_generation CPU_RESET_COUNT $cpu_reset_count \
    WR_CORE_RESET_COUNT $wr_core_reset_count SI_CONFIG_DROP_COUNT $si_config_drop_count \
    LOCAL_READY $local_ready]
}

proc comma_slave_snapshot {hardware_name sample elapsed_ms} {
  set status [safe_probe_read 0]
  set clock [safe_probe_read 7]
  set entry [safe_probe_read 26]
  set reset [safe_probe_read 27]

  set read_valid 1
  foreach value [list $status $clock $entry $reset] {
    if {![comma_raw_valid $value]} { set read_valid 0 }
  }

  set core_tm_link_up [bit32 $status 2]
  set core_link_ok [bit32 $status 3]
  set rx_locked_to_data [bit64_high $status 0]
  set rx_pattern_ready [bit64_high $status 6]
  set rx_syncstatus [bit64_high $status 4]
  set rx_activity [field32 $clock 0 1]
  set rx_activity_count [expr {[comma_raw_valid $clock] ?
                                [expr {([probe_high32 $clock] >> 0) & 0xffff}] : -1}]
  set reset_fields [comma_reset_fields $entry $reset]
  lassign $reset_fields boot_generation cpu_reset_count wr_core_reset_count \
    si_config_drop_count

  set recovery [expr {$read_valid &&
                      ($rx_pattern_ready == 1 ||
                       $rx_syncstatus == 1 ||
                       $core_link_ok == 1)}]

  return [list \
    ROLE SLAVE BOARD $hardware_name SAMPLE $sample ELAPSED_MS $elapsed_ms \
    READ_VALID $read_valid STATUS_RAW [comma_probe64 $status] \
    CLOCK_ACTIVITY_RAW [comma_probe64 $clock] \
    ENTRY_RAW [comma_probe64 $entry] RESET_RAW [comma_probe64 $reset] \
    CORE_TM_LINK_UP $core_tm_link_up CORE_LINK_OK $core_link_ok \
    RX_LOCKED_TO_DATA $rx_locked_to_data RX_SYNCSTATUS $rx_syncstatus \
    RX_PATTERN_READY $rx_pattern_ready RX_ACTIVITY_COUNT $rx_activity_count \
    BOOT_GENERATION $boot_generation CPU_RESET_COUNT $cpu_reset_count \
    WR_CORE_RESET_COUNT $wr_core_reset_count SI_CONFIG_DROP_COUNT $si_config_drop_count \
    POST_MASTER_REPROGRAM_RECOVERY $recovery]
}

proc comma_open_board {hardware_name} {
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} { error "no device for $hardware_name" }
  catch {end_insystem_source_probe}
  start_insystem_source_probe -hardware_name $hardware_name \
    -device_name [lindex $devices 0]
}

proc comma_close_board {} {
  catch {end_insystem_source_probe}
}

puts [format "COMMA_CONFIG trial=%s board_filter=%s local_ready_samples=%d required_ready_streak=%d formal_samples=%d formal_window_ms=%d gap_ms=%d read_only=1 master_compile=external master_program_count=1 slave_program_count=0 power_cycle=0 phy_reset=0 ptp_restart=0 mode_command=0" \
  $::trial_id $::board_filter $::local_ready_sample_limit \
  $::required_ready_streak $::formal_sample_limit $::formal_window_ms $::gap_ms]
flush stdout

set ::master_hardware ""
set ::slave_hardware ""
foreach hardware_name [get_hardware_names] {
  if {$::board_filter ne "" && [string first $::board_filter $hardware_name] < 0} {
    continue
  }
  if {[string first "1-11.1" $hardware_name] >= 0} {
    set ::master_hardware $hardware_name
  } elseif {[string first "1-11.2" $hardware_name] >= 0} {
    set ::slave_hardware $hardware_name
  }
}

if {$::master_hardware eq ""} {
  puts "COMMA_RESULT=INCONCLUSIVE_NO_MASTER_TARGET"
  error "no matching Master DE5a target"
}

set local_ready_pass 0
set ready_streak 0
set local_sample_count 0
set local_error ""
set baseline_cycle -1
set baseline_k28p5 -1
set baseline_boot ""
set baseline_cpu_reset ""
set baseline_wr_reset ""
set baseline_si_drop ""
set baseline_ms 0
set local_begin_ms [clock milliseconds]

for {set sample 0} {$sample < $::local_ready_sample_limit} {incr sample} {
  set elapsed [expr {[clock milliseconds] - $local_begin_ms}]
  if {$elapsed > $::local_ready_window_ms} { break }
  set snap {}
  set board_error ""
  if {[catch {
    comma_open_board $::master_hardware
    set snap [comma_master_snapshot $::master_hardware $sample $elapsed]
  } board_error]} {
    set local_error $board_error
  }
  comma_close_board

  if {$snap eq ""} {
    comma_emit COMMA_LOCAL_SAMPLE [list BOARD $::master_hardware SAMPLE $sample \
      ELAPSED_MS $elapsed READ_VALID 0 LOCAL_READY 0 ERROR $local_error]
    set ready_streak 0
  } else {
    array set s $snap
    if {$s(LOCAL_READY) == 1} {
      incr ready_streak
    } else {
      set ready_streak 0
    }
    set s(READY_STREAK) $ready_streak
    comma_emit COMMA_LOCAL_SAMPLE [list \
      BOARD $s(BOARD) SAMPLE $s(SAMPLE) ELAPSED_MS $s(ELAPSED_MS) \
      READ_VALID $s(READ_VALID) STATUS_RAW $s(STATUS_RAW) \
      COUNTER_RAW $s(COUNTER_RAW) TX_CONTEXT_RAW $s(TX_CONTEXT_RAW) \
      SI_CONFIG_DONE $s(SI_CONFIG_DONE) WR_READY $s(WR_READY) \
      TX_READY $s(TX_READY) CPU_RESET_N $s(CPU_RESET_N) \
      PHY_RST $s(PHY_RST) PHY_TX_DISABLE $s(PHY_TX_DISABLE) \
      TX_DATA $s(TX_DATA) TX_K $s(TX_K) TX_ENC_ERR $s(TX_ENC_ERR) \
      TX_CYCLE_COUNT $s(TX_CYCLE_COUNT) TX_K28P5_COUNT $s(TX_K28P5_COUNT) \
      BOOT_GENERATION $s(BOOT_GENERATION) CPU_RESET_COUNT $s(CPU_RESET_COUNT) \
      WR_CORE_RESET_COUNT $s(WR_CORE_RESET_COUNT) \
      SI_CONFIG_DROP_COUNT $s(SI_CONFIG_DROP_COUNT) LOCAL_READY $s(LOCAL_READY) \
      READY_STREAK $ready_streak]
    if {$s(READ_VALID) == 0} { set local_error "INVALID_MASTER_SAMPLE" }
    if {$ready_streak >= $::required_ready_streak} {
      set local_ready_pass 1
      set baseline_cycle $s(TX_CYCLE_COUNT)
      set baseline_k28p5 $s(TX_K28P5_COUNT)
      set baseline_boot $s(BOOT_GENERATION)
      set baseline_cpu_reset $s(CPU_RESET_COUNT)
      set baseline_wr_reset $s(WR_CORE_RESET_COUNT)
      set baseline_si_drop $s(SI_CONFIG_DROP_COUNT)
      set baseline_ms [clock milliseconds]
      set local_sample_count [expr {$sample + 1}]
      break
    }
  }
  set local_sample_count [expr {$sample + 1}]
  if {$sample + 1 < $::local_ready_sample_limit} { after $::gap_ms }
}

if {!$local_ready_pass} {
  puts [format "COMMA_STOP MASTER_DIAG_LOCAL_READY=FAIL EXP_RESULT=INCONCLUSIVE_DIAG_IMAGE_STARTUP samples=%d elapsed_ms=%d" \
    $local_sample_count [expr {[clock milliseconds] - $local_begin_ms}]]
  puts "COMMA_DONE"
  flush stdout
  return
}

puts [format "COMMA_LOCAL_READY_PASS BOARD=%s READY_STREAK=%d BASELINE_TX_CYCLE_COUNT=%d BASELINE_TX_K28P5_COUNT=%d BASELINE_BOOT_GENERATION=%s BASELINE_CPU_RESET_COUNT=%s BASELINE_WR_CORE_RESET_COUNT=%s BASELINE_SI_CONFIG_DROP_COUNT=%s" \
  $::master_hardware $::required_ready_streak $baseline_cycle $baseline_k28p5 \
  $baseline_boot $baseline_cpu_reset $baseline_wr_reset $baseline_si_drop]
flush stdout

# The Slave is sampled only for the predeclared recovery exception.  It is
# never programmed or used as a control input.
set formal_start_ms [clock milliseconds]
set formal_count 0
set formal_error ""
set reset_changed 0
set exception_recovery 0
set formal_invalid 0
set formal_window_exceeded 0
set last_cycle_delta INVALID
set last_k28p5_delta INVALID
set formal_sample 0

for {set sample 0} {$sample < $::formal_sample_limit} {incr sample} {
  set elapsed [expr {[clock milliseconds] - $formal_start_ms}]
  if {$elapsed > $::formal_window_ms} { break }

  set master_snap {}
  set board_error ""
  if {[catch {
    comma_open_board $::master_hardware
    set master_snap [comma_master_snapshot $::master_hardware $sample $elapsed]
  } board_error]} {
    set formal_error $board_error
  }
  comma_close_board

  if {$master_snap eq ""} {
    comma_emit COMMA_FORMAL_SAMPLE [list BOARD $::master_hardware SAMPLE $sample \
      ELAPSED_MS $elapsed READ_VALID 0 TX_CYCLE_DELTA INVALID \
      TX_K28P5_DELTA INVALID ERROR $formal_error]
    break
  }
  array set m $master_snap
  if {$m(READ_VALID) != 1} { set formal_invalid 1 }
  set cycle_delta [comma_delta32_numeric $baseline_cycle $m(TX_CYCLE_COUNT)]
  set k_delta [comma_delta32_numeric $baseline_k28p5 $m(TX_K28P5_COUNT)]
  set last_cycle_delta $cycle_delta
  set last_k28p5_delta $k_delta
  set changed [expr {$m(BOOT_GENERATION) ne $baseline_boot ||
                     $m(CPU_RESET_COUNT) ne $baseline_cpu_reset ||
                     $m(WR_CORE_RESET_COUNT) ne $baseline_wr_reset ||
                     $m(SI_CONFIG_DROP_COUNT) ne $baseline_si_drop}]
  if {$changed} { set reset_changed 1 }

  comma_emit COMMA_FORMAL_SAMPLE [list \
    BOARD $m(BOARD) SAMPLE $m(SAMPLE) ELAPSED_MS $m(ELAPSED_MS) \
    READ_VALID $m(READ_VALID) STATUS_RAW $m(STATUS_RAW) \
    COUNTER_RAW $m(COUNTER_RAW) TX_CONTEXT_RAW $m(TX_CONTEXT_RAW) \
    SI_CONFIG_DONE $m(SI_CONFIG_DONE) WR_READY $m(WR_READY) \
    TX_READY $m(TX_READY) CPU_RESET_N $m(CPU_RESET_N) \
    PHY_RST $m(PHY_RST) PHY_TX_DISABLE $m(PHY_TX_DISABLE) \
    TX_DATA $m(TX_DATA) TX_K $m(TX_K) TX_ENC_ERR $m(TX_ENC_ERR) \
    TX_CYCLE_COUNT $m(TX_CYCLE_COUNT) TX_K28P5_COUNT $m(TX_K28P5_COUNT) \
    TX_CYCLE_DELTA $cycle_delta TX_K28P5_DELTA $k_delta \
    BOOT_GENERATION $m(BOOT_GENERATION) CPU_RESET_COUNT $m(CPU_RESET_COUNT) \
    WR_CORE_RESET_COUNT $m(WR_CORE_RESET_COUNT) \
    SI_CONFIG_DROP_COUNT $m(SI_CONFIG_DROP_COUNT) RESET_CHANGED $changed]
  incr formal_count

  if {$::slave_hardware ne ""} {
    set slave_snap {}
    set slave_error ""
    if {[catch {
      comma_open_board $::slave_hardware
      set slave_snap [comma_slave_snapshot $::slave_hardware $sample $elapsed]
    } slave_error]} {
      set formal_error $slave_error
    }
    comma_close_board
    if {$slave_snap eq ""} {
      set formal_invalid 1
      comma_emit COMMA_SLAVE_SAMPLE [list BOARD $::slave_hardware SAMPLE $sample \
        ELAPSED_MS $elapsed READ_VALID 0 \
        POST_MASTER_REPROGRAM_RECOVERY 0 ERROR $slave_error]
    } else {
      array set q $slave_snap
      if {$q(READ_VALID) != 1} { set formal_invalid 1 }
      comma_emit COMMA_SLAVE_SAMPLE [list \
        BOARD $q(BOARD) SAMPLE $q(SAMPLE) ELAPSED_MS $q(ELAPSED_MS) \
        READ_VALID $q(READ_VALID) STATUS_RAW $q(STATUS_RAW) \
        CLOCK_ACTIVITY_RAW $q(CLOCK_ACTIVITY_RAW) CORE_TM_LINK_UP $q(CORE_TM_LINK_UP) \
        CORE_LINK_OK $q(CORE_LINK_OK) RX_LOCKED_TO_DATA $q(RX_LOCKED_TO_DATA) \
        RX_SYNCSTATUS $q(RX_SYNCSTATUS) RX_PATTERN_READY $q(RX_PATTERN_READY) \
        RX_ACTIVITY_COUNT $q(RX_ACTIVITY_COUNT) \
        BOOT_GENERATION $q(BOOT_GENERATION) CPU_RESET_COUNT $q(CPU_RESET_COUNT) \
        WR_CORE_RESET_COUNT $q(WR_CORE_RESET_COUNT) \
        SI_CONFIG_DROP_COUNT $q(SI_CONFIG_DROP_COUNT) \
        POST_MASTER_REPROGRAM_RECOVERY $q(POST_MASTER_REPROGRAM_RECOVERY)]
      if {$q(POST_MASTER_REPROGRAM_RECOVERY) == 1} {
        set exception_recovery 1
        break
      }
    }
  }

  set formal_sample [expr {$sample + 1}]
  if {[expr {[clock milliseconds] - $formal_start_ms}] > $::formal_window_ms} {
    set formal_window_exceeded 1
  }
  if {$sample + 1 < $::formal_sample_limit} { after $::gap_ms }
}

if {$exception_recovery} {
  puts "COMMA_RESULT=POST_MASTER_REPROGRAM_RECOVERY_OBSERVED"
  puts "POST_MASTER_REPROGRAM_RECOVERY=OBSERVED"
  puts "FAILURE_CLASS=STARTUP_ORDER_SENSITIVE_LINK_ACQUISITION"
} elseif {$reset_changed} {
  puts "COMMA_RESULT=INCONCLUSIVE_RESET"
} elseif {$formal_invalid} {
  puts "COMMA_RESULT=INCONCLUSIVE_TRANSPORT"
} elseif {$formal_count < $::formal_sample_limit || $formal_window_exceeded} {
  puts [format "COMMA_RESULT=INCONCLUSIVE_OBSERVATION_WINDOW formal_samples=%d required=%d elapsed_ms=%d" \
    $formal_count $::formal_sample_limit [expr {[clock milliseconds] - $formal_start_ms}]]
} elseif {$last_cycle_delta eq "INVALID" || $last_cycle_delta eq "DECREASED" ||
          $last_k28p5_delta eq "INVALID" || $last_k28p5_delta eq "DECREASED"} {
  puts [format "COMMA_RESULT=INCONCLUSIVE_COUNTER_BASELINE TX_CYCLE_DELTA=%s TX_K28P5_DELTA=%s" \
    $last_cycle_delta $last_k28p5_delta]
} elseif {$last_cycle_delta > 0 && $last_k28p5_delta > 0} {
  puts [format "COMMA_RESULT=MASTER_TX_K28P5_EMISSION_PASS MASTER_TX_K28P5_EMISSION=PASS TX_CYCLE_DELTA=%d TX_K28P5_DELTA=%d" \
    $last_cycle_delta $last_k28p5_delta]
  puts "MASTER_TX_COMMA_SOURCE=PRESENT"
  puts "SLAVE_WORD_ALIGN=NOT_REACHED_BY_THIS_OBSERVER"
  puts "STEP6A_GLOBAL_TIME=NOT_PASS"
  puts "STEP6B=NOT_RUN"
} elseif {$last_cycle_delta > 0 && $last_k28p5_delta == 0} {
  puts [format "COMMA_RESULT=FAIL_MASTER_TX_PCS_COMMA_GENERATION MASTER_TX_K28P5_EMISSION=FAIL TX_CYCLE_DELTA=%d TX_K28P5_DELTA=0" \
    $last_cycle_delta]
  puts "FAILURE_CLASS=FAIL_MASTER_TX_PCS_COMMA_GENERATION"
  puts "STEP6A_GLOBAL_TIME=NOT_PASS"
  puts "STEP6B=NOT_RUN"
} else {
  puts [format "COMMA_RESULT=INCONCLUSIVE_TX_CLOCK_NO_ACTIVITY TX_CYCLE_DELTA=%s TX_K28P5_DELTA=%s" \
    $last_cycle_delta $last_k28p5_delta]
}

puts [format "COMMA_DONE formal_samples=%d elapsed_ms=%d" $formal_count \
  [expr {[clock milliseconds] - $formal_start_ms}]]
flush stdout
