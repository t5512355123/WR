# Step 4 SoftPLL startup focused read-only diagnostic.
#
# This script deliberately reads one address repeatedly before moving to the
# next address.  It does not write WDIAGS_CTRL/DATA_SNAPSHOT, read TRR_R0, or
# write any SoftPLL/WR control register.
#
# Usage:
#   quartus_stp -t read_step4_startup_focused.tcl ?samples? ?gap_ms? ?group?
#
# group: lock, events, or all (default).  The default is 30 samples at 100 ms.
# All addresses below are already used by the repository's Step 4 scripts and
# jtag_register_map.md; this file does not introduce a new functional map.

package require ::quartus::insystem_source_probe

set samples 30
set gap_ms 100
set group all
set raw_mode 0
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set group [lindex $argv 2] }
if {[lsearch -exact $argv --raw] >= 0} { set raw_mode 1 }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}
if {[lsearch -exact {lock events all} $group] < 0} {
  error "group must be lock, events, or all"
}

set ::wb_toggle 0
set ::max_read_attempts 5
array set ::series {}

proc is_u32 {value} {
  return [regexp {^[0-9A-Fa-f]{1,8}$} $value]
}

proc word32 {value} {
  if {![is_u32 $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc stale_word {value} {
  set word [word32 $value]
  if {$word < 0} { return 0 }
  return [expr {(($word >> 16) & 0xffff) == 0xA5A5}]
}

proc wb_sync_toggle {} {
  set value [read_probe_data -instance_index 1 -value_in_hex]
  if {![regexp {^[0-9A-Fa-f]{1,16}$} $value]} {
    set ::wb_toggle 0
    return
  }
  scan $value %x word
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
}

proc wb_read_once {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set command [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  write_source_data -instance_index 1 -value [format %024X $command] -value_in_hex
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [read_probe_data -instance_index 1 -value_in_hex]
    if {[regexp {^[0-9A-Fa-f]{1,16}$} $value]} {
      scan $value %x word
      set done_toggle [expr {(($word >> 35) & 1)}]
      set active [expr {(($word >> 36) & 1)}]
      if {$done_toggle == $::wb_toggle && $active == 0} {
        return [format %08X [expr {$word & 0xffffffff}]]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc register_valid {addr value} {
  set word [word32 $value]
  if {$word < 0 || [stale_word $value]} { return 0 }

  # These are the source-defined packed fields that can be validated without
  # assuming a transient runtime state.
  switch -- [format "0x%08X" [expr {$addr & 0xffffffff}]] {
    0x00100A8C {
      # wrpc_wr_lock_last_result: 0=locked, 1=unlocked, 2=T24P failure;
      # bit 8 is spll_check_lock(0).
      set result [expr {$word & 0xff}]
      set spll_locked [expr {($word >> 8) & 1}]
      return [expr {$result <= 2 && $spll_locked <= 1}]
    }
    0x00100AA0 {
      # low byte sequence, next byte align state, high byte SoftPLL mode,
      # top byte de-lock count.  The accepted enum ranges come from
      # softpll_export.h.
      set sequence [expr {$word & 0xff}]
      set align [expr {($word >> 8) & 0xff}]
      set mode [expr {($word >> 16) & 0xff}]
      return [expr {$sequence <= 10 && $align <= 10 && $mode <= 3}]
    }
    0x00100A0C {
      # WDIAGS_PSTAT: bit 0 link and bit 1 spll_check_lock(0).
      return [expr {($word & 0xfffffffc) == 0}]
    }
    0x00100A10 {
      return [expr {$word >= 1 && $word <= 9}]
    }
    0x00100A5C {
      set ptp_state [expr {$word & 0xff}]
      set mode [expr {($word >> 24) & 0xff}]
      return [expr {$ptp_state >= 1 && $ptp_state <= 9 &&
                    ($mode == 2 || $mode == 3)}]
    }
  }
  # Hardware control/status and all monotonic counters are accepted as any
  # non-stale 32-bit word. Their semantic activity is decided from a series.
  return 1
}

proc wb_read_validated {addr} {
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set value [wb_read_once $addr]
    if {[register_valid $addr $value]} { return $value }
    after 2
  }
  return INVALID
}

proc add_hist {hist_name key} {
  upvar 1 $hist_name hist
  if {[info exists hist($key)]} { incr hist($key) } else { set hist($key) 1 }
}

proc hist_text {hist_name} {
  upvar 1 $hist_name hist
  set parts {}
  foreach key [lsort -dictionary [array names hist]] {
    lappend parts [format "%s:%d" $key $hist($key)]
  }
  if {[llength $parts] == 0} { return none }
  return [join $parts ","]
}

proc series_delta {first last invalid} {
  if {$invalid > 0 || $first eq "" || $last eq ""} { return INVALID }
  set a [word32 $first]
  set b [word32 $last]
  if {$a < 0 || $b < 0} { return INVALID }
  if {$b < $a} { return DECREASED_OR_RESET }
  return [expr {$b - $a}]
}

proc read_series {board label addr} {
  array set hist {}
  set valid 0
  set invalid 0
  set decrease 0
  set first ""
  set last ""
  set previous -1

  for {set sample 1} {$sample <= $::samples} {incr sample} {
    set value [wb_read_validated $addr]
    if {$value eq "INVALID" || $value eq "TIMEOUT"} {
      incr invalid
    } else {
      set word [word32 $value]
      incr valid
      if {$first eq ""} { set first $value }
      set last $value
      add_hist hist $value
      if {$previous >= 0 && $word < $previous} { set decrease 1 }
      set previous $word
      if {$::raw_mode} {
        puts [format "STEP4_RAW board=%s register=%s sample=%03d value=%s" \
              $board $label $sample $value]
      }
    }
    if {$sample < $::samples && $::gap_ms > 0} { after $::gap_ms }
  }

  set delta [series_delta $first $last $invalid]
  set ::series($board,$label,valid) $valid
  set ::series($board,$label,invalid) $invalid
  set ::series($board,$label,decrease) $decrease
  set ::series($board,$label,first) $first
  set ::series($board,$label,last) $last
  set ::series($board,$label,delta) $delta
  set ::series($board,$label,hist) [hist_text hist]

  puts [format "STEP4_SERIES board=%s register=%s samples=%d valid=%d invalid=%d decrease=%d first=%s last=%s delta=%s" \
        $board $label $::samples $valid $invalid $decrease $first $last $delta]
}

proc series_value {board label field} {
  if {[info exists ::series($board,$label,$field)]} {
    return $::series($board,$label,$field)
  }
  return ""
}

proc delta_positive {board label} {
  set delta [series_value $board $label delta]
  if {[string is integer -strict $delta]} { return [expr {$delta > 0}] }
  return 0
}

proc has_invalid {board labels} {
  foreach label $labels {
    if {[series_value $board $label invalid] > 0} { return 1 }
  }
  return 0
}

proc print_lock_classification {board} {
  if {[has_invalid $board {WR_LOCK_RESULT WR_LOCK_POLL_COUNT \
                           WR_LOCK_UNLOCKED_COUNT WR_LOCK_CALIB_FAIL_COUNT \
                           WR_LOCK_ENABLE_COUNT SPLL_STATE PSTAT_LOCKED}]} {
    puts [format "STEP4_LOCK_CLASS board=%s result=MEASUREMENT_INVALID_RETEST" $board]
    return
  }

  set result_word [word32 [series_value $board WR_LOCK_RESULT last]]
  set result_code [expr {$result_word & 0xff}]
  set unlocked_delta [series_value $board WR_LOCK_UNLOCKED_COUNT delta]
  set calib_delta [series_value $board WR_LOCK_CALIB_FAIL_COUNT delta]
  set pstat_last [word32 [series_value $board PSTAT_LOCKED last]]
  set pstat_locked [expr {($pstat_last >> 1) & 1}]

  if {$result_code == 2 || [string is integer -strict $calib_delta] && $calib_delta > 0} {
    puts [format "STEP4_LOCK_CLASS board=%s result=T24P_CALIBRATION_FAIL result_code=%d calib_fail_delta=%s" \
          $board $result_code $calib_delta]
  } elseif {$result_code == 1} {
    puts [format "STEP4_LOCK_CLASS board=%s result=SPLL_UNLOCKED result_code=%d unlocked_delta=%s pstat_locked=%d" \
          $board $result_code $unlocked_delta $pstat_locked]
  } elseif {$result_code == 0 && $pstat_locked == 1} {
    puts [format "STEP4_LOCK_CLASS board=%s result=LOCKED result_code=%d pstat_locked=%d" \
          $board $result_code $pstat_locked]
  } else {
    puts [format "STEP4_LOCK_CLASS board=%s result=TRANSITIONAL_OR_INCONSISTENT result_code=%d pstat_locked=%d" \
          $board $result_code $pstat_locked]
  }
}

proc print_event_boundary {board} {
  set labels {DMTD_REF_EVENTS DMTD_FB_EVENTS TAG_PENDING_COUNT \
              TAG_PENDING_REF_COUNT TAG_PENDING_FB_COUNT TAG_GRANT_COUNT \
              TAG_VALID_COUNT TRR_WRITE_COUNT IRQ_COUNT HELPER_UPDATE_COUNT \
              STATE_TRANSITION_COUNT}
  if {[has_invalid $board $labels]} {
    puts [format "STEP4_EVENT_BOUNDARY board=%s result=MEASUREMENT_INVALID_RETEST" $board]
    return
  }

  set dmtd_active [expr {[delta_positive $board DMTD_REF_EVENTS] || \
                          [delta_positive $board DMTD_FB_EVENTS]}]
  set pending_active [expr {[delta_positive $board TAG_PENDING_COUNT] || \
                             [delta_positive $board TAG_PENDING_REF_COUNT] || \
                             [delta_positive $board TAG_PENDING_FB_COUNT]}]
  set grant_active [delta_positive $board TAG_GRANT_COUNT]
  set tag_active [delta_positive $board TAG_VALID_COUNT]
  set trr_active [delta_positive $board TRR_WRITE_COUNT]
  set irq_active [delta_positive $board IRQ_COUNT]
  set state_active [delta_positive $board STATE_TRANSITION_COUNT]
  set helper_active [delta_positive $board HELPER_UPDATE_COUNT]

  if {!$dmtd_active} {
    set boundary "DMTD_EVENT_GENERATION"
  } elseif {!$pending_active} {
    set boundary "DMTD_TO_TAG_REQUEST"
  } elseif {!$grant_active} {
    set boundary "TAG_ARBITRATION_GRANT"
  } elseif {!$tag_active && !$trr_active} {
    set boundary "TAG_GRANT_TO_TAG_VALID_TRR"
  } elseif {$trr_active && !$irq_active} {
    set boundary "TRR_TO_IRQ"
  } elseif {$irq_active && !$state_active} {
    set boundary "IRQ_TO_SEQUENCER"
  } elseif {$state_active && !$helper_active} {
    set boundary "SEQUENCER_TO_HELPER_UPDATE"
  } else {
    set boundary "HELPER_UPDATE_ACTIVE"
  }

  puts [format "STEP4_EVENT_ACTIVITY board=%s dmtd=%d pending=%d grant=%d tag_valid=%d trr_write=%d irq=%d state_transition=%d helper_update=%d" \
        $board $dmtd_active $pending_active $grant_active $tag_active \
        $trr_active $irq_active $state_active $helper_active]
  puts [format "STEP4_EVENT_BOUNDARY board=%s result=%s" $board $boundary]
}

proc read_lock_group {board} {
  foreach item {
    {WR_FAILURE_DEBUG 0x00100A6C}
    {WR_LOCK_RESULT 0x00100A8C}
    {WR_LOCK_POLL_COUNT 0x00100A90}
    {WR_LOCK_UNLOCKED_COUNT 0x00100A94}
    {WR_LOCK_CALIB_FAIL_COUNT 0x00100A98}
    {WR_LOCK_ENABLE_COUNT 0x00100A9C}
    {SPLL_STATE 0x00100AA0}
    {PSTAT_LOCKED 0x00100A0C}
  } {
    read_series $board [lindex $item 0] [lindex $item 1]
  }
  print_lock_classification $board
}

proc read_event_group {board} {
  foreach item {
    {SPLL_MODE_SEQUENCE 0x00100AA0}
    {RCER 0x00100224}
    {OCER 0x00100228}
    {DMTD_REF_EVENTS 0x00100298}
    {DMTD_FB_EVENTS 0x0010029C}
    {DMTD_REF_SEEN 0x001002A0}
    {DMTD_FB_SEEN 0x001002A4}
    {TAG_PENDING_COUNT 0x001002A8}
    {TAG_PENDING_REF_COUNT 0x001002C4}
    {TAG_PENDING_FB_COUNT 0x001002C8}
    {TAG_GRANT_COUNT 0x001002AC}
    {TAG_VALID_COUNT 0x00100284}
    {TRR_WRITE_COUNT 0x00100288}
    {IRQ_COUNT 0x00100AEC}
    {HELPER_UPDATE_COUNT 0x00100B18}
    {STATE_TRANSITION_COUNT 0x00100AE4}
    {CURRENT_TICS 0x001002B0}
    {DMTD_REF_LAST_TICS 0x001002B4}
    {DMTD_FB_LAST_TICS 0x001002B8}
    {TAG_REF_LAST_TICS 0x001002BC}
    {TAG_FB_LAST_TICS 0x001002C0}
    {TAG_PENDING_LAST_TICS 0x001002CC}
    {TAG_GRANT_LAST_TICS 0x001002D0}
    {TAG_VALID_LAST_TICS 0x001002D4}
    {TRR_WRITE_LAST_TICS 0x001002D8}
    {SPLL_DMTD_STATE 0x001002DC}
  } {
    read_series $board [lindex $item 0] [lindex $item 1]
  }
  print_event_boundary $board
}

proc run_board {hardware_name device_name} {
  puts [format "=== STEP4_FOCUSED_BOARD %s ===" $hardware_name]
  start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
  wb_sync_toggle
  if {$::group eq "lock" || $::group eq "all"} { read_lock_group $hardware_name }
  if {$::group eq "events" || $::group eq "all"} { read_event_group $hardware_name }
  catch { end_insystem_source_probe }
}

puts [format "STEP4_FOCUSED_CONFIG samples=%d gap_ms=%d group=%s retries=%d trr_r0_read=disabled" \
      $samples $gap_ms $group $::max_read_attempts]
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  if {[catch {run_board $hardware_name [lindex $device_names 0]} message]} {
    puts [format "STEP4_FOCUSED_ERROR board=%s message=%s" $hardware_name $message]
    catch { end_insystem_source_probe }
  }
}
puts STEP4_FOCUSED_DONE
