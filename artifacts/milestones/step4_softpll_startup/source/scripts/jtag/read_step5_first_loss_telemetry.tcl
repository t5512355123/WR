# Step5 L2 first-loss telemetry observer.
#
# This reader only performs Wishbone reads and source-probe reads. It does not
# write WR configuration, VUART, DATA_SNAPSHOT, or Step5 controls. Probe 52..61
# are the diagnostic-only liveness payloads emitted by si5340a_controller_dco.
#
# Usage:
#   quartus_stp -t read_step5_first_loss_telemetry.tcl ?samples? ?gap_ms? ?board_filter? ?experiment?

package require ::quartus::insystem_source_probe

set samples 600
set gap_ms 1000
set board_filter ""
set experiment_name "EXP-S5-FIRST-LOSS-20260912"
set poll_attempts 100
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {[llength $argv] >= 4} { set experiment_name [lindex $argv 3] }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

array set ::wb_toggle {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc pad64 {value} {
  if {![is_hex $value]} { return INVALID }
  set text [string toupper $value]
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  return [string repeat 0 [expr {16 - [string length $text]}]]$text
}

proc low32 {value} {
  set text [pad64 $value]
  if {$text eq "INVALID"} { return INVALID }
  scan [string range $text 8 15] %x word
  return [expr {$word & 0xffffffff}]
}

proc high32 {value} {
  set text [pad64 $value]
  if {$text eq "INVALID"} { return INVALID }
  scan [string range $text 0 7] %x word
  return [expr {$word & 0xffffffff}]
}

proc field32 {value low width} {
  if {![string is integer -strict $value]} { return INVALID }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($value >> $low) & $mask}]
}

proc field64 {value low width} {
  if {$low < 32} {
    return [field32 [low32 $value] $low $width]
  }
  return [field32 [high32 $value] [expr {$low - 32}] $width]
}

proc word32 {value} {
  set word [low32 $value]
  if {$word eq "INVALID"} { return -1 }
  return $word
}

proc display_value {value} {
  if {![is_hex $value]} { return $value }
  return [string toupper [pad64 $value]]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
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
    return TIMEOUT
  }
  after 5
  for {set n 0} {$n < $poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value INVALID
    }
    if {[is_hex $value]} {
      set word [low32 $value]
      set done_toggle [field32 [high32 $value] 3 1]
      set active [field32 [high32 $value] 4 1]
      if {$done_toggle == $toggle && $active == 0} {
        return [format %08X $word]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc frame_valid {ctrl_begin ctrl_end} {
  set a [word32 $ctrl_begin]
  set b [word32 $ctrl_end]
  if {$a < 0 || $b < 0} { return 0 }
  return [expr {(($a & 1) != 0) && (($b & 1) != 0) && $a == $b}]
}

proc emit_sample {hardware_name sample elapsed_ms} {
  set ctrl_begin [wb_read $hardware_name 0x00100A04]
  set helper_state [wb_read $hardware_name 0x00100ABC]
  set helper_limits [wb_read $hardware_name 0x00100AC0]
  set main_state [wb_read $hardware_name 0x00100AC4]
  set pstat [wb_read $hardware_name 0x00100A0C]
  set spll_state [wb_read $hardware_name 0x00100AA0]
  set helper_error [wb_read $hardware_name 0x00100AD8]
  set helper_output [wb_read $hardware_name 0x00100ADC]
  set reset_probe [probe_read 27]
  set sync_probe [probe_read 0]
  set status [probe_read 52]
  set pending [probe_read 53]
  set service_start [probe_read 54]
  set completed [probe_read 55]
  set failed [probe_read 56]
  set max_wait [probe_read 57]
  set current_wait [probe_read 58]
  set latency [probe_read 59]
  set failure [probe_read 60]
  set first_loss [probe_read 61]
  set ctrl_end [wb_read $hardware_name 0x00100A04]

  set valid [frame_valid $ctrl_begin $ctrl_end]
  set helper_locked [field32 [low32 $helper_state] 0 1]
  set helper_lock_count [field32 [low32 $helper_state] 16 16]
  set helper_threshold [field32 [low32 $helper_limits] 0 16]
  set helper_lock_samples [field32 [low32 $helper_limits] 16 16]
  set main_enabled [field32 [low32 $main_state] 0 1]
  set main_locked [field32 [low32 $main_state] 1 1]
  set main_freq_locked [field32 [low32 $main_state] 2 1]
  set main_phase_locked [field32 [low32 $main_state] 3 1]
  set pstat_locked [field32 [low32 $pstat] 1 1]
  set spll_delock [field32 [low32 $spll_state] 24 8]
  set helper_error_signed [field32 [low32 $helper_error] 0 32]
  if {$helper_error_signed ne "INVALID" && $helper_error_signed >= 0x80000000} {
    set helper_error_signed [expr {$helper_error_signed - 0x100000000}]
  }
  set status_first_loss [field64 $status 6 1]
  set status_main_pending [field64 $status 0 1]
  set status_helper_pending [field64 $status 1 1]
  set status_tx_active [field64 $status 2 1]
  set status_owner_main [field64 $status 3 1]
  set status_ack [field64 $status 4 1]
  set status_timeout [field64 $status 5 1]
  set status_dco_error [field64 $status 7 1]
  set status_reason [field64 $status 8 8]
  set status_rt_state [field64 $status 16 3]
  set status_time [high32 $status]
  set main_pending_count [low32 $pending]
  set helper_pending_count [high32 $pending]
  set main_start_count [low32 $service_start]
  set helper_start_count [high32 $service_start]
  set main_completed_count [low32 $completed]
  set helper_completed_count [high32 $completed]
  set main_failed_count [low32 $failed]
  set helper_failed_count [high32 $failed]
  set main_max_wait [low32 $max_wait]
  set helper_max_wait [high32 $max_wait]
  set main_current_wait [low32 $current_wait]
  set helper_current_wait [high32 $current_wait]
  set main_max_latency [low32 $latency]
  set helper_max_latency [high32 $latency]
  set ack_events [low32 $failure]
  set timeout_events [high32 $failure]
  set first_loss_time [low32 $first_loss]
  set first_loss_owner [field64 $first_loss 32 2]
  set first_loss_reason [field64 $first_loss 34 8]
  puts [format "L2_FIRST_LOSS_SAMPLE board=%s sample=%d elapsed_ms=%d FRAME_VALID=%d STATUS=%s FIRST_LOSS_VALID=%s FIRST_LOSS_TIME=%s FIRST_LOSS_OWNER=%s FIRST_LOSS_REASON=%s MAIN_PENDING=%s HELPER_PENDING=%s TX_ACTIVE=%s TX_OWNER_MAIN=%s ACK=%s TIMEOUT=%s DCO_ERROR=%s RT_STATE=%s STATUS_TIME=%s MAIN_PENDING_COUNT=%s HELPER_PENDING_COUNT=%s MAIN_START_COUNT=%s HELPER_START_COUNT=%s MAIN_COMPLETED=%s HELPER_COMPLETED=%s MAIN_FAILED=%s HELPER_FAILED=%s MAIN_MAX_WAIT=%s HELPER_MAX_WAIT=%s MAIN_CURRENT_WAIT=%s HELPER_CURRENT_WAIT=%s MAIN_MAX_LATENCY=%s HELPER_MAX_LATENCY=%s ACK_EVENTS=%s TIMEOUT_EVENTS=%s HELPER_LOCKED=%s HELPER_LOCK_COUNT=%s HELPER_THRESHOLD=%s HELPER_LOCK_SAMPLES=%s HELPER_ERROR=%s MAIN_ENABLED=%s MAIN_LOCKED=%s MAIN_FREQ_LOCKED=%s MAIN_PHASE_LOCKED=%s PSTAT_LOCKED=%s SPLL_DELOCK=%s SYNC=%s RESET=%s" \
    $hardware_name $sample $elapsed_ms $valid [display_value $status] $status_first_loss $first_loss_time $first_loss_owner $first_loss_reason \
    $status_main_pending $status_helper_pending $status_tx_active $status_owner_main $status_ack $status_timeout $status_dco_error $status_rt_state [display_value $status_time] \
    $main_pending_count $helper_pending_count $main_start_count $helper_start_count $main_completed_count $helper_completed_count \
    $main_failed_count $helper_failed_count $main_max_wait $helper_max_wait $main_current_wait $helper_current_wait \
    $main_max_latency $helper_max_latency $ack_events $timeout_events $helper_locked $helper_lock_count $helper_threshold $helper_lock_samples \
    $helper_error_signed $main_enabled $main_locked $main_freq_locked $main_phase_locked $pstat_locked $spll_delock [display_value $sync_probe] [display_value $reset_probe]]
  flush stdout
}

puts [format "L2_FIRST_LOSS_CONFIG samples=%d gap_ms=%d board_filter=%s experiment=%s read_only=1 probes=52..61 cadence_ms=%d timeout_cycles=5000000" $samples $gap_ms $board_filter $experiment_name $gap_ms]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  puts [format "=== L2_FIRST_LOSS_BOARD %s ===" $hardware_name]
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    start_insystem_source_probe -hardware_name $hardware_name -device_name [lindex $device_names 0]
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set deadline [expr {$start_ms + (($sample - 1) * $gap_ms)}]
      set now [clock milliseconds]
      if {$now < $deadline} { after [expr {$deadline - $now}] }
      emit_sample $hardware_name $sample [expr {[clock milliseconds] - $start_ms}]
    }
  } error_message]} {
    puts [format "L2_FIRST_LOSS_ERROR board=%s message=%s error_info=%s" $hardware_name $error_message [string map [list "\n" " | "] $::errorInfo]]
  }
  catch { end_insystem_source_probe }
}

puts "L2_FIRST_LOSS_DONE"

