# Compact read-only Step 1..6 dashboard for the two DE5a JTAG targets.
#
# This script deliberately reuses read_wb_runtime.tcl for the existing
# Step 1..5 semantics, then reads the fitted-design Global-Time probes 62..64
# in the same JTAG session.  It performs no Wishbone writes and no target/ARM
# writes.  The shell wrapper filters the DASHBOARD_* lines from Quartus' own
# verbose banner.
#
# Usage:
#   quartus_stp -t read_step1_6_dashboard.tcl ?observation_gap_ms?
#
# A 1--2 s observation gap is enough for a compact watch dashboard.  The
# existing runtime reader still decides whether an activity-based Step 2/3
# window has enough evidence; INVALID/NA there is never converted to FAIL.

set ::wb_library_mode 1
set ::dashboard_script_dir [file dirname [info script]]
set ::runtime_reader [file normalize [file join $::dashboard_script_dir read_wb_runtime.tcl]]
source $::runtime_reader

set ::dashboard_gap_ms 2000
if {[llength $argv] >= 1} {
  set ::dashboard_gap_ms [expr {int([lindex $argv 0])}]
}
if {$::dashboard_gap_ms < 0} {
  error "observation_gap_ms must be >= 0"
}

set ::dashboard_tai_mask 1099511627775
set ::dashboard_tai36_mask 68719476735
set ::dashboard_cycles24_mask 16777215
set ::dashboard_cycles28_mask 268435455

proc dashboard_read_word {instance_index} {
  set raw [read_probe_data -instance_index $instance_index -value_in_hex]
  if {[scan $raw %x word] != 1} {
    error "cannot decode probe ${instance_index}: ${raw}"
  }
  return $word
}

proc dashboard_global_sample {} {
  # Probe 63 is a sequence/upper-cycle word.  Read it on both sides of probe
  # 62 so a PPS-boundary snapshot is accepted only when the sequence is
  # stable.  Probe 62 is the authoritative full-width TAI/cycle snapshot.
  if {[catch {
    set live [dashboard_read_word 64]
    set word1_before [dashboard_read_word 63]
    set word0 [dashboard_read_word 62]
    set word1_after [dashboard_read_word 63]
  } error_message]} {
    return [dict create valid 0 reason "${error_message}"]
  }
  set stable [expr {$word1_before == $word1_after ? 1 : 0}]
  set tai [expr {$word0 & $::dashboard_tai_mask}]
  set cycles [expr {(($word0 >> 40) & $::dashboard_cycles24_mask) |
                    (($word1_after & 15) << 24)}]
  set time_valid [expr {($word1_after >> 4) & 1}]
  set pps_valid [expr {($word1_after >> 5) & 1}]
  set snapshot_valid [expr {($word1_after >> 6) & 1}]
  set sequence [expr {($word1_after >> 7) & 65535}]
  set live_tai_lo [expr {$live & $::dashboard_tai36_mask}]
  set live_cycles [expr {($live >> 36) & $::dashboard_cycles28_mask}]
  return [dict create valid 1 stable $stable tai $tai cycles $cycles \
      time_valid $time_valid pps_valid $pps_valid \
      snapshot_valid $snapshot_valid sequence $sequence \
      live_tai_lo $live_tai_lo live_cycles $live_cycles]
}

proc dashboard_board_label {hardware_name} {
  return [string map {" " "_" "[" "" "]" ""} $hardware_name]
}

proc dashboard_lock_value {board label field low width} {
  set value [field32 [get_snap $board $label $field] $low $width]
  if {$value < 0} { return "INVALID" }
  return $value
}

proc dashboard_emit_board {board hardware_name global_sample} {
  set status_raw [get_snap $board after status]
  set role [expr {[string match "*1-11.1*" $hardware_name] ? "MASTER" : \
                 ([string match "*1-11.2*" $hardware_name] ? "SLAVE" : "UNKNOWN")}]

  set step1 $::step_status($board,1)
  set step2 $::step_status($board,2)
  set step3 $::step_status($board,3)
  set step4 $::step_status($board,4)
  set step5 $::step_status($board,5)
  set step5_result "NOT_APPLICABLE"
  if {[info exists ::step5_result($board)]} {
    set step5_result $::step5_result($board)
  }

  set helper_lock "NA"
  set main_enabled "NA"
  set main_locked "NA"
  set main_freq "NA"
  set main_phase "NA"
  set pstat_lock "NA"
  if {$role eq "SLAVE"} {
    set helper_lock [dashboard_lock_value $board after spll_helper_state 0 1]
    set main_enabled [dashboard_lock_value $board after spll_main_state 0 1]
    set main_locked [dashboard_lock_value $board after spll_main_state 1 1]
    set main_freq [dashboard_lock_value $board after spll_main_state 2 1]
    set main_phase [dashboard_lock_value $board after spll_main_state 3 1]
    set pstat_lock [bit32 [get_snap $board after pstat] 1]
  }

  set status_time_valid [bit64_low $status_raw 4]
  set status_pps_valid [bit64_low $status_raw 5]
  set status_link_ok [bit64_low $status_raw 3]
  set status_tm_link [bit64_low $status_raw 2]
  set status_rx_ready [bit64_low $status_raw 6]
  set status_tx_ready [bit64_low $status_raw 7]

  # These existing WR PPS registers explain why Global Time may be unavailable
  # even when the timing link itself is already up.  Keep them read-only and
  # expose the source-level validity bits in the dashboard output.
  set pps_cr_raw [get_snap $board after pps_cr]
  set pps_escr_raw [get_snap $board after pps_escr]
  set pps_cr_word [word32 $pps_cr_raw]
  set pps_escr_word [word32 $pps_escr_raw]
  set pps_cr_enable [expr {$pps_cr_word < 0 ? -1 : ($pps_cr_word & 1)}]
  set escr_pps_valid [expr {$pps_escr_word < 0 ? -1 : (($pps_escr_word >> 2) & 1)}]
  set escr_tm_valid [expr {$pps_escr_word < 0 ? -1 : (($pps_escr_word >> 3) & 1)}]
  set pps_cr_display [expr {$pps_cr_word < 0 ? [display_value $pps_cr_raw] : [format "0x%08X" $pps_cr_word]}]
  set pps_escr_display [expr {$pps_escr_word < 0 ? [display_value $pps_escr_raw] : [format "0x%08X" $pps_escr_word]}]

  set global_valid [dict get $global_sample valid]
  set global_stable 0
  set global_time_valid 0
  set global_pps_valid 0
  set global_snapshot_valid 0
  set global_snapshot_count 0
  set tai "INVALID"
  set cycles "INVALID"
  if {$global_valid} {
    set global_stable [dict get $global_sample stable]
    set global_time_valid [dict get $global_sample time_valid]
    set global_pps_valid [dict get $global_sample pps_valid]
    set global_snapshot_valid [dict get $global_sample snapshot_valid]
    set global_snapshot_count [dict get $global_sample sequence]
    set tai [dict get $global_sample tai]
    set cycles [dict get $global_sample cycles]
  }
  set step6 [expr {$global_valid && $global_stable == 1 &&
                   $global_time_valid == 1 && $global_pps_valid == 1 &&
                   $global_snapshot_valid == 1 && $status_link_ok == 1 &&
                   $status_tm_link == 1 && $status_time_valid == 1 &&
                   $status_pps_valid == 1 ? "PASS" : "INFO"}]

  set board_label [dashboard_board_label $hardware_name]
  puts [format "DASHBOARD_BOARD board=%s role=%s | Step1=%s Step2=%s Step3=%s Step4=%s Step5=%s Step6=%s | HelperLock=%s MainFreq=%s MainPhase=%s MainLock=%s PSTAT=%s | Link=%s TM=%s RX=%s TX=%s STATUS_TIME_VALID=%s STATUS_PPS_VALID=%s TIME_VALID=%s PPS_VALID=%s SNAPSHOT_VALID=%s SNAPSHOT_STABLE=%s SNAPSHOT_COUNT=%s | TAI=%s CYCLES=%s | PPS_CR=%s PPS_CR_ENABLE=%s PPS_ESCR=%s ESCR_TM_VALID=%s ESCR_PPS_VALID=%s | Step5Result=%s" \
      $board_label $role $step1 $step2 $step3 $step4 $step5 $step6 \
      $helper_lock $main_freq $main_phase $main_locked $pstat_lock \
      $status_link_ok $status_tm_link $status_rx_ready $status_tx_ready \
      $status_time_valid $status_pps_valid $global_time_valid $global_pps_valid \
      $global_snapshot_valid $global_stable $global_snapshot_count \
      $tai $cycles $pps_cr_display $pps_cr_enable $pps_escr_display \
      $escr_tm_valid $escr_pps_valid $step5_result]
}

puts [format "DASHBOARD_CONFIG observation_gap_ms=%d reference_clock_hz=125000000 read_only=1" \
      $::dashboard_gap_ms]
flush stdout

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} {
    puts [format "DASHBOARD_SKIP board=%s reason=no_device" \
        [dashboard_board_label $hardware_name]]
    continue
  }
  set device_name [lindex $device_names 0]
  set board [format "b%02d" $::board_count]
  incr ::board_count
  set ::board_name($board) $hardware_name
  set ::first_anomaly($board) ""
  set ::wb_last_static_addr ""
  set ::wb_last_static_value ""
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe \
      -hardware_name $hardware_name \
      -device_name $device_name
    wb_sync_toggle
    collect_snapshot $board before
    after $::dashboard_gap_ms
    collect_snapshot $board after
    analyze_board $board
    set global_sample [dashboard_global_sample]
    dashboard_emit_board $board $hardware_name $global_sample
    flush stdout
  } error_message]} {
    puts [format "DASHBOARD_ERROR board=%s message=%s" \
        [dashboard_board_label $hardware_name] $error_message]
    flush stdout
  }
  catch { end_insystem_source_probe }
}

puts "DASHBOARD_DONE"
flush stdout
