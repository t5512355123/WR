# Step 4 SoftPLL startup focused read-only diagnostic.
#
# This script samples bounded register groups. It does not write
# WDIAGS_CTRL/DATA_SNAPSHOT, read TRR_R0, or write any SoftPLL/WR control
# register. A mailbox timeout is recorded for the affected field/group and
# does not abort the remaining read-only groups.
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

proc is_u64 {value} {
  return [regexp {^[0-9A-Fa-f]{16}$} $value]
}

proc word64 {value} {
  if {![is_u64 $value]} { return -1 }
  set result 0
  foreach digit [split [string toupper $value] ""] {
    scan $digit %x nibble
    set result [expr {$result * 16 + $nibble}]
  }
  return $result
}

proc stale_word {value} {
  set word [word32 $value]
  if {$word < 0} { return 0 }
  return [expr {(($word >> 16) & 0xffff) == 0xA5A5}]
}

proc wb_sync_toggle {} {
  if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
    set ::wb_toggle 0
    return 0
  }
  if {![regexp {^[0-9A-Fa-f]{1,16}$} $value]} {
    set ::wb_toggle 0
    return 0
  }
  scan $value %x word
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
  return 1
}

proc wb_read_once {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set command [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $command] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 5
  for {set n 0} {$n < 100} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      return TIMEOUT
    }
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
    if {$attempt < $::max_read_attempts} {
      catch {wb_sync_toggle}
      after 2
    }
  }
  return INVALID
}

proc wb_read_u64_consistent {lo_addr hi_addr} {
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set hi1 [wb_read_validated $hi_addr]
    set lo [wb_read_validated $lo_addr]
    set hi2 [wb_read_validated $hi_addr]
    if {[is_u32 $hi1] && [is_u32 $lo] && [is_u32 $hi2] && $hi1 eq $hi2} {
      return [string toupper "$hi2$lo"]
    }
    if {$attempt < $::max_read_attempts} {
      catch {wb_sync_toggle}
      after 2
    }
  }
  return INVALID
}

proc wb_read_u64_non_decreasing {lo_addr hi_addr previous} {
  # Stable-hit counters are free-running 64-bit diagnostics. During the short
  # observation window they cannot legitimately wrap or decrease. Reject a
  # lower snapshot so a mailbox tear such as an all-zero read is retried rather
  # than being accepted as a real counter value.
  set previous_word -1
  if {[is_u64 $previous]} {
    set previous_word [word64 $previous]
  }
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set value [wb_read_u64_consistent $lo_addr $hi_addr]
    if {[is_u64 $value]} {
      set current_word [word64 $value]
      if {$previous_word < 0 || $current_word >= $previous_word} {
        return $value
      }
    }
    if {$attempt < $::max_read_attempts} {
      catch {wb_sync_toggle}
      after 2
    }
  }
  return INVALID
}

proc series_delta {first last invalid} {
  if {$invalid > 0 || $first eq "" || $last eq ""} { return INVALID }
  set a [word32 $first]
  set b [word32 $last]
  if {$a < 0 || $b < 0} { return INVALID }
  if {$b < $a} { return DECREASED_OR_RESET }
  return [expr {$b - $a}]
}

proc series_delta_mod32 {first last invalid} {
  if {$invalid > 0 || $first eq "" || $last eq ""} { return INVALID }
  set a [word32 $first]
  set b [word32 $last]
  if {$a < 0 || $b < 0} { return INVALID }
  return [expr {($b - $a) & 0xffffffff}]
}

proc series_delta_mod64 {first last invalid} {
  if {$invalid > 0 || $first eq "" || $last eq ""} { return INVALID }
  set a [word64 $first]
  set b [word64 $last]
  if {$a < 0 || $b < 0} { return INVALID }
  set modulus 18446744073709551616
  return [expr {($b - $a + $modulus) % $modulus}]
}

proc init_series {board label} {
  foreach field {valid invalid timeout decrease first last previous delta hist first_ms last_ms} {
    set ::series($board,$label,$field) 0
  }
  set ::series($board,$label,first) ""
  set ::series($board,$label,last) ""
  set ::series($board,$label,previous) -1
  set ::series($board,$label,first_ms) ""
  set ::series($board,$label,last_ms) ""
}

proc add_series_sample {board label sample value} {
  if {$value eq "TIMEOUT"} {
    incr ::series($board,$label,timeout)
    incr ::series($board,$label,invalid)
    return
  }
  if {$value eq "INVALID"} {
    incr ::series($board,$label,invalid)
    return
  }

  set word [word32 $value]
  if {$word < 0} {
    incr ::series($board,$label,invalid)
    return
  }
  incr ::series($board,$label,valid)
  if {$::series($board,$label,first) eq ""} {
    set ::series($board,$label,first) $value
  }
  set ::series($board,$label,last) $value
  if {$::series($board,$label,previous) >= 0 &&
      $word < $::series($board,$label,previous)} {
    set ::series($board,$label,decrease) 1
  }
  set ::series($board,$label,previous) $word
  if {$::raw_mode} {
    puts [format "STEP4_RAW board=%s register=%s sample=%03d value=%s" \
          $board $label $sample $value]
  }
}

proc add_series_sample64 {board label sample value} {
  if {$value eq "TIMEOUT"} {
    incr ::series($board,$label,timeout)
    incr ::series($board,$label,invalid)
    return
  }
  if {$value eq "INVALID"} {
    incr ::series($board,$label,invalid)
    return
  }

  set word [word64 $value]
  if {$word < 0} {
    incr ::series($board,$label,invalid)
    return
  }
  incr ::series($board,$label,valid)
  if {$::series($board,$label,first) eq ""} {
    set ::series($board,$label,first) $value
  }
  set ::series($board,$label,last) $value
  if {$::series($board,$label,previous) >= 0 &&
      $word < $::series($board,$label,previous)} {
    set ::series($board,$label,decrease) 1
  }
  set ::series($board,$label,previous) $word
  if {$::raw_mode} {
    puts [format "STEP4_RAW board=%s register=%s sample=%03d value=%s" \
          $board $label $sample $value]
  }
}

proc add_timed_series_sample {board label sample value timestamp_ms} {
  set valid_before $::series($board,$label,valid)
  add_series_sample $board $label $sample $value
  if {$::series($board,$label,valid) > $valid_before} {
    if {$::series($board,$label,first_ms) eq ""} {
      set ::series($board,$label,first_ms) $timestamp_ms
    }
    set ::series($board,$label,last_ms) $timestamp_ms
  }
}

proc add_timed_series_sample64 {board label sample value timestamp_ms} {
  set valid_before $::series($board,$label,valid)
  add_series_sample64 $board $label $sample $value
  if {$::series($board,$label,valid) > $valid_before} {
    if {$::series($board,$label,first_ms) eq ""} {
      set ::series($board,$label,first_ms) $timestamp_ms
    }
    set ::series($board,$label,last_ms) $timestamp_ms
  }
}

proc finish_series {board label} {
  set valid $::series($board,$label,valid)
  set invalid $::series($board,$label,invalid)
  set first $::series($board,$label,first)
  set last $::series($board,$label,last)
  if {$label eq "DMTD_REF_WAIT_EDGE_ENTRY" || $label eq "DMTD_FB_WAIT_EDGE_ENTRY" ||
      $label eq "NATIVE_REF_SAMPLED" || $label eq "NATIVE_FB_SAMPLED" ||
      $label eq "NATIVE_REF_ACCEPT" || $label eq "NATIVE_FB_ACCEPT"} {
    # These source-defined 32-bit diagnostics are free-running counters.
    # A decrease is an expected wrap, not a functional reset.
    set delta [series_delta_mod32 $first $last $invalid]
  } else {
    set delta [series_delta $first $last $invalid]
  }
  set ::series($board,$label,delta) $delta
  set ::series($board,$label,hist) none

  puts [format "STEP4_SERIES board=%s register=%s samples=%d valid=%d timeout=%d invalid=%d decrease=%d first=%s last=%s delta=%s" \
        $board $label $::samples $valid \
        $::series($board,$label,timeout) $invalid \
        $::series($board,$label,decrease) $first $last $delta]
}

proc finish_series64 {board label} {
  set valid $::series($board,$label,valid)
  set invalid $::series($board,$label,invalid)
  set first $::series($board,$label,first)
  set last $::series($board,$label,last)
  set delta [series_delta_mod64 $first $last $invalid]
  set ::series($board,$label,delta) $delta
  set ::series($board,$label,hist) none

  puts [format "STEP4_SERIES64 board=%s register=%s samples=%d valid=%d timeout=%d invalid=%d decrease=%d first=%s last=%s delta=%s delta_mode=MODULO64" \
        $board $label $::samples $valid \
        $::series($board,$label,timeout) $invalid \
        $::series($board,$label,decrease) $first $last $delta]
}

proc read_group {board group_name items} {
  foreach item $items {
    init_series $board [lindex $item 0]
  }

  for {set sample 1} {$sample <= $::samples} {incr sample} {
    foreach item $items {
      set label [lindex $item 0]
      set addr [lindex $item 1]
      if {[catch {set value [wb_read_validated $addr]}]} {
        set value TIMEOUT
        puts [format "STEP4_READ_EXCEPTION board=%s group=%s register=%s sample=%03d" \
              $board $group_name $label $sample]
      }
      add_series_sample $board $label $sample $value
    }
    if {$sample < $::samples && $::gap_ms > 0} { after $::gap_ms }
  }

  set group_result VALID
  foreach item $items {
    set label [lindex $item 0]
    finish_series $board $label
    if {$::series($board,$label,timeout) > 0} {
      if {$::series($board,$label,valid) > 0} {
        set group_result PARTIAL
      } else {
        set group_result TIMEOUT
      }
    } elseif {$::series($board,$label,invalid) > 0} {
      set group_result PARTIAL
      if {$::series($board,$label,valid) == 0} { set group_result INVALID }
    }
  }
  puts [format "STEP4_GROUP board=%s group=%s result=%s" \
        $board $group_name $group_result]
}

proc read_d0_stable_group {board} {
  foreach label {DMTD_NATIVE_EDGE_COUNT64 \
                 DEGLITCH_THRESHOLD \
                 REF_D0_STABLE_HIT_COUNT64 REF_D0_TRANSITION_COUNT64 \
                 DMTD_REF_WAIT_EDGE_ENTRY \
                 NATIVE_REF_SAMPLED NATIVE_REF_ACCEPT \
                 FB_D0_STABLE_HIT_COUNT64 FB_D0_TRANSITION_COUNT64 \
                 DMTD_FB_WAIT_EDGE_ENTRY \
                 NATIVE_FB_SAMPLED NATIVE_FB_ACCEPT} {
    init_series $board $label
  }

  for {set sample 1} {$sample <= $::samples} {incr sample} {
    set value [wb_read_u64_consistent 0x001002F8 0x001002FC]
    add_timed_series_sample64 $board DMTD_NATIVE_EDGE_COUNT64 $sample $value \
      [clock milliseconds]

    set value [wb_read_validated 0x00100248]
    add_timed_series_sample $board DEGLITCH_THRESHOLD $sample $value \
      [clock milliseconds]
    set previous [series_value $board REF_D0_STABLE_HIT_COUNT64 last]
    set value [wb_read_u64_non_decreasing 0x00100240 0x00100244 $previous]
    add_timed_series_sample64 $board REF_D0_STABLE_HIT_COUNT64 $sample $value \
      [clock milliseconds]
    set value [wb_read_u64_consistent 0x00100250 0x00100254]
    add_timed_series_sample64 $board REF_D0_TRANSITION_COUNT64 $sample $value \
      [clock milliseconds]
    set value [wb_read_validated 0x00100234]
    add_timed_series_sample $board NATIVE_REF_SAMPLED $sample $value \
      [clock milliseconds]
    set value [wb_read_validated 0x0010022C]
    add_timed_series_sample $board NATIVE_REF_ACCEPT $sample $value \
      [clock milliseconds]
    set value [wb_read_validated 0x001002A0]
    add_timed_series_sample $board DMTD_REF_WAIT_EDGE_ENTRY $sample $value \
      [clock milliseconds]

    set previous [series_value $board FB_D0_STABLE_HIT_COUNT64 last]
    set value [wb_read_u64_non_decreasing 0x0010024C 0x00100258 $previous]
    add_timed_series_sample64 $board FB_D0_STABLE_HIT_COUNT64 $sample $value \
      [clock milliseconds]
    set value [wb_read_u64_consistent 0x00100260 0x00100264]
    add_timed_series_sample64 $board FB_D0_TRANSITION_COUNT64 $sample $value \
      [clock milliseconds]
    set value [wb_read_validated 0x00100238]
    add_timed_series_sample $board NATIVE_FB_SAMPLED $sample $value \
      [clock milliseconds]
    set value [wb_read_validated 0x00100230]
    add_timed_series_sample $board NATIVE_FB_ACCEPT $sample $value \
      [clock milliseconds]
    set value [wb_read_validated 0x001002A4]
    add_timed_series_sample $board DMTD_FB_WAIT_EDGE_ENTRY $sample $value \
      [clock milliseconds]
    if {$sample < $::samples && $::gap_ms > 0} { after $::gap_ms }
  }

  finish_series64 $board DMTD_NATIVE_EDGE_COUNT64
  finish_series $board DEGLITCH_THRESHOLD
  finish_series64 $board REF_D0_STABLE_HIT_COUNT64
  finish_series64 $board REF_D0_TRANSITION_COUNT64
  finish_series $board DMTD_REF_WAIT_EDGE_ENTRY
  finish_series $board NATIVE_REF_SAMPLED
  finish_series $board NATIVE_REF_ACCEPT
  finish_series64 $board FB_D0_STABLE_HIT_COUNT64
  finish_series64 $board FB_D0_TRANSITION_COUNT64
  finish_series $board DMTD_FB_WAIT_EDGE_ENTRY
  finish_series $board NATIVE_FB_SAMPLED
  finish_series $board NATIVE_FB_ACCEPT

  set result VALID
  set fields {}
  set dmtd_delta [series_value $board DMTD_NATIVE_EDGE_COUNT64 delta]
  set dmtd_first_ms [series_value $board DMTD_NATIVE_EDGE_COUNT64 first_ms]
  set dmtd_last_ms [series_value $board DMTD_NATIVE_EDGE_COUNT64 last_ms]
  set dmtd_elapsed_ms NA
  set dmtd_frequency_hz NA
  if {[string is wideinteger -strict $dmtd_delta] &&
      [string is wideinteger -strict $dmtd_first_ms] &&
      [string is wideinteger -strict $dmtd_last_ms] &&
      $dmtd_last_ms > $dmtd_first_ms && $dmtd_delta > 0} {
    set dmtd_elapsed_ms [expr {$dmtd_last_ms - $dmtd_first_ms}]
    set dmtd_frequency_hz [format "%.3f" \
      [expr {double($dmtd_delta) * 1000.0 / double($dmtd_elapsed_ms)}]]
  } else {
    set result INVALID
  }

  set threshold_word [word32 [series_value $board DEGLITCH_THRESHOLD last]]
  set threshold_delta [series_value $board DEGLITCH_THRESHOLD delta]
  set threshold NA
  set hit_length NA
  if {$threshold_word >= 0 &&
      [string is wideinteger -strict $threshold_delta] &&
      $threshold_delta == 0} {
    set threshold [expr {$threshold_word & 0xffff}]
    set hit_length [expr {$threshold + 1}]
  } else {
    set result INVALID
  }

  foreach side {REF FB} {
    set hit_label ${side}_D0_STABLE_HIT_COUNT64
    set d0_label ${side}_D0_TRANSITION_COUNT64
    set sampled_label NATIVE_${side}_SAMPLED
    set accept_label NATIVE_${side}_ACCEPT
    set hit_delta [series_value $board $hit_label delta]
    set d0_delta [series_value $board $d0_label delta]
    set sampled_delta [series_value $board $sampled_label delta]
    set accept_delta [series_value $board $accept_label delta]
    set sampled_to_dmtd_ratio NA
    set d0_to_dmtd_ratio NA
    set sampled_to_d0_ratio NA
    set hit_per_million_d0 NA
    if {[string is wideinteger -strict $hit_delta] &&
        [string is wideinteger -strict $d0_delta] &&
        [string is wideinteger -strict $sampled_delta] &&
        [string is wideinteger -strict $accept_delta] &&
        [string is wideinteger -strict $dmtd_delta] && $dmtd_delta > 0} {
        set sampled_to_dmtd_ratio [format "%.9f" \
          [expr {double($sampled_delta) / double($dmtd_delta)}]]
        set d0_to_dmtd_ratio [format "%.9f" \
          [expr {double($d0_delta) / double($dmtd_delta)}]]
        if {$d0_delta > 0} {
          set sampled_to_d0_ratio [format "%.9f" \
            [expr {double($sampled_delta) / double($d0_delta)}]]
          set hit_per_million_d0 [format "%.6f" \
            [expr {double($hit_delta) * 1000000.0 / double($d0_delta)}]]
        }
    } else {
      set result INVALID
    }
    lappend fields [format "%s_hit_delta=%s %s_hit_per_million_d0=%s %s_d0_delta=%s %s_d0_to_dmtd_ratio=%s %s_sampled_delta=%s %s_sampled_to_dmtd_ratio=%s %s_sampled_to_d0_ratio=%s %s_accept_delta=%s" \
      [string tolower $side] $hit_delta \
      [string tolower $side] $hit_per_million_d0 \
      [string tolower $side] $d0_delta \
      [string tolower $side] $d0_to_dmtd_ratio \
      [string tolower $side] $sampled_delta \
      [string tolower $side] $sampled_to_dmtd_ratio \
      [string tolower $side] $sampled_to_d0_ratio \
      [string tolower $side] $accept_delta]
  }
  puts [format "STEP4_DMTD_CLOCK board=%s dmtd_native_delta=%s dmtd_elapsed_ms=%s dmtd_frequency_hz=%s result=%s" \
        $board $dmtd_delta $dmtd_elapsed_ms $dmtd_frequency_hz $result]
  puts [format "STEP4_D0_STABLE_THRESHOLD board=%s threshold=%s threshold_delta=%s hit_length=%s %s %s result=%s counter_cdc=GRAY2_HI_LO_HI" \
        $board $threshold $threshold_delta $hit_length \
        [lindex $fields 0] [lindex $fields 1] $result]
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
              TAG_VALID_COUNT TRR_WRITE_COUNT TRR_POP_COUNT IRQ_COUNT HELPER_UPDATE_COUNT \
              STATE_TRANSITION_COUNT DMTD_REF_SAMPLED DMTD_FB_SAMPLED \
              DMTD_REF_ACCEPT DMTD_FB_ACCEPT \
               DMTD_HIGH_QUAL_MAX_STAB DMTD_D0_LOW_RUN_MAX \
               DMTD_REF_WAIT_EDGE_ENTRY DMTD_FB_WAIT_EDGE_ENTRY \
               DMTD_REF_QUAL_REACHED_8 DMTD_FB_QUAL_REACHED_8}
  if {[has_invalid $board $labels]} {
    puts [format "STEP4_EVENT_BOUNDARY board=%s result=MEASUREMENT_INVALID_RETEST" $board]
    return
  }

  set max_stab_word [word32 [series_value $board DMTD_HIGH_QUAL_MAX_STAB last]]
  set dmtd_active [expr {[delta_positive $board DMTD_REF_EVENTS] || \
                          [delta_positive $board DMTD_FB_EVENTS]}]
  # Full sampled/accept counters remain the authoritative boundary evidence.
  set sampled_active [expr {[delta_positive $board DMTD_REF_SAMPLED] || \
                            [delta_positive $board DMTD_FB_SAMPLED]}]
  set accept_active [expr {[delta_positive $board DMTD_REF_ACCEPT] || \
                           [delta_positive $board DMTD_FB_ACCEPT]}]
  set qualification_entry_active [expr {[delta_positive $board DMTD_REF_WAIT_EDGE_ENTRY] || \
                                        [delta_positive $board DMTD_FB_WAIT_EDGE_ENTRY]}]
  set qualification_progress_active [expr {[delta_positive $board DMTD_REF_QUAL_REACHED_8] || \
                                           [delta_positive $board DMTD_FB_QUAL_REACHED_8]}]
  set pending_active [expr {[delta_positive $board TAG_PENDING_COUNT] || \
                             [delta_positive $board TAG_PENDING_REF_COUNT] || \
                             [delta_positive $board TAG_PENDING_FB_COUNT]}]
  set grant_active [delta_positive $board TAG_GRANT_COUNT]
  set tag_active [delta_positive $board TAG_VALID_COUNT]
  set trr_active [delta_positive $board TRR_WRITE_COUNT]
  set trr_pop_active [delta_positive $board TRR_POP_COUNT]
  set irq_active [delta_positive $board IRQ_COUNT]
  set state_active [delta_positive $board STATE_TRANSITION_COUNT]
   set helper_active [delta_positive $board HELPER_UPDATE_COUNT]

   if {$max_stab_word >= 0} {
     puts [format "STEP4_HIGH_QUAL_MAX_STAB board=%s ref_max_before_abort=%d fb_max_before_abort=%d" \
           $board [expr {$max_stab_word & 0xffff}] [expr {($max_stab_word >> 16) & 0xffff}]]
   } else {
     puts [format "STEP4_HIGH_QUAL_MAX_STAB board=%s result=MEASUREMENT_INVALID_RETEST" $board]
   }

   set d0_low_run_word [word32 [series_value $board DMTD_D0_LOW_RUN_MAX last]]
   if {$d0_low_run_word >= 0} {
     puts [format "STEP4_INPUT_D0_LOW_RUN_MAX board=%s ref_max_d0_low_run=%d fb_max_d0_low_run=%d" \
           $board [expr {$d0_low_run_word & 0xffff}] [expr {($d0_low_run_word >> 16) & 0xffff}]]
   } else {
     puts [format "STEP4_INPUT_D0_LOW_RUN_MAX board=%s result=MEASUREMENT_INVALID_RETEST" $board]
   }

  set dmtd_state_value [series_value $board SPLL_DMTD_STATE last]
  set dmtd_state_word [word32 $dmtd_state_value]
  set got_edge_active 0
  set high_abort_seen_active 0
  if {$dmtd_state_word >= 0} {
    set ref_state [expr {$dmtd_state_word & 0x3}]
    set fb_state [expr {($dmtd_state_word >> 2) & 0x3}]
    set ref_bucket [expr {($dmtd_state_word >> 10) & 0xff}]
    set fb_bucket [expr {($dmtd_state_word >> 18) & 0xff}]
    set ref_reached [expr {($dmtd_state_word >> 26) & 1}]
    set fb_reached [expr {($dmtd_state_word >> 27) & 1}]
    set ref_high_abort_seen [expr {($dmtd_state_word >> 31) & 1}]
    set fb_high_abort_seen [expr {($dmtd_state_word >> 30) & 1}]
    set ref_got_edge [expr {($dmtd_state_word >> 28) & 1}]
    set fb_got_edge [expr {($dmtd_state_word >> 29) & 1}]
    set got_edge_active [expr {$ref_got_edge || $fb_got_edge}]
    set high_abort_seen_active [expr {$ref_high_abort_seen || $fb_high_abort_seen}]
    puts [format "STEP4_DEGLITCH_STATE board=%s ref_state=%d fb_state=%d ref_stab_bucket=%d fb_stab_bucket=%d ref_threshold_reached=%d fb_threshold_reached=%d ref_high_abort_seen=%d fb_high_abort_seen=%d ref_got_edge_seen=%d fb_got_edge_seen=%d" \
          $board $ref_state $fb_state $ref_bucket $fb_bucket $ref_reached $fb_reached $ref_high_abort_seen $fb_high_abort_seen $ref_got_edge $fb_got_edge]
  } else {
    set ref_state NA
    set fb_state NA
    set ref_bucket NA
    set fb_bucket NA
    set ref_reached NA
    set fb_reached NA
    puts [format "STEP4_DEGLITCH_STATE board=%s ref_state=NA fb_state=NA ref_stab_bucket=NA fb_stab_bucket=NA ref_threshold_reached=NA fb_threshold_reached=NA ref_high_abort_seen=NA fb_high_abort_seen=NA ref_got_edge_seen=NA fb_got_edge_seen=NA" $board]
  }

  if {$high_abort_seen_active && !$qualification_progress_active && !$accept_active} {
    set boundary "QUALIFICATION_ABORT_AFTER_GOT_EDGE"
  } elseif {$got_edge_active && !$qualification_progress_active && !$accept_active} {
    set boundary "GOT_EDGE_TO_QUALIFICATION_PROGRESS"
  } elseif {$qualification_progress_active && !$accept_active} {
    set boundary "QUALIFICATION_PROGRESS_TO_DEGLITCH_ACCEPT"
  } elseif {!$dmtd_active && !$sampled_active && !$accept_active && !$qualification_entry_active} {
    set boundary "DMTD_SAMPLED_OR_DEGLITCH"
  } elseif {!$sampled_active} {
    set boundary "DMTD_SAMPLED_TRANSITION"
  } elseif {!$qualification_entry_active} {
    set boundary "DMTD_SAMPLED_TRANSITION_TO_QUALIFICATION_ENTRY"
  } elseif {!$accept_active} {
    set boundary "DMTD_QUALIFICATION_ENTRY_TO_DEGLITCH_ACCEPT"
  } elseif {!$dmtd_active} {
    set boundary "DMTD_ACCEPT_TO_SYS_EVENT"
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

  puts [format "STEP4_DMTD_BOUNDARY board=%s sampled_ref=%s pre_accept_ref=%s accept_ref=%s sampled_fb=%s pre_accept_fb=%s accept_fb=%s" \
        $board [series_value $board DMTD_REF_SAMPLED delta] \
        [series_value $board DMTD_REF_WAIT_EDGE_ENTRY delta] \
        [series_value $board DMTD_REF_ACCEPT delta] \
        [series_value $board DMTD_FB_SAMPLED delta] \
        [series_value $board DMTD_FB_WAIT_EDGE_ENTRY delta] \
        [series_value $board DMTD_FB_ACCEPT delta]]
  puts [format "STEP4_QUALIFICATION_ENTRY board=%s ref=%s fb=%s" \
        $board [series_value $board DMTD_REF_WAIT_EDGE_ENTRY delta] \
        [series_value $board DMTD_FB_WAIT_EDGE_ENTRY delta]]
  puts [format "STEP4_QUALIFICATION_PROGRESS board=%s ref=%s fb=%s" \
        $board [series_value $board DMTD_REF_QUAL_REACHED_8 delta] \
        [series_value $board DMTD_FB_QUAL_REACHED_8 delta]]
  puts [format "STEP4_EVENT_ACTIVITY board=%s dmtd=%d pending=%d grant=%d tag_valid=%d trr_write=%d trr_pop=%d irq=%d state_transition=%d helper_update=%d" \
        $board $dmtd_active $pending_active $grant_active $tag_active \
        $trr_active $trr_pop_active $irq_active $state_active $helper_active]
  puts [format "STEP4_EVENT_BOUNDARY board=%s result=%s" $board $boundary]
}

proc read_lock_group {board} {
  set items {
    {WR_FAILURE_DEBUG 0x00100A6C}
    {WR_LOCK_RESULT 0x00100A8C}
    {WR_LOCK_POLL_COUNT 0x00100A90}
    {WR_LOCK_UNLOCKED_COUNT 0x00100A94}
    {WR_LOCK_CALIB_FAIL_COUNT 0x00100A98}
    {WR_LOCK_ENABLE_COUNT 0x00100A9C}
    {SPLL_STATE 0x00100AA0}
    {PSTAT_LOCKED 0x00100A0C}
  }
  read_group $board LOCK $items
  print_lock_classification $board
}

proc read_event_group {board} {
  set boundary_items {
    {SPLL_MODE_SEQUENCE 0x00100AA0}
    {RCER 0x00100224}
    {OCER 0x00100228}
    {DMTD_REF_EVENTS 0x00100298}
    {DMTD_FB_EVENTS 0x0010029C}
    {DMTD_REF_ACCEPT 0x0010022C}
    {DMTD_FB_ACCEPT 0x00100230}
    {DMTD_REF_SAMPLED 0x00100234}
    {DMTD_FB_SAMPLED 0x00100238}
    {DMTD_HIGH_QUAL_MAX_STAB 0x0010023C}
    {DMTD_D0_LOW_RUN_MAX 0x0010025C}
    {DMTD_REF_WAIT_EDGE_ENTRY 0x001002A0}
    {DMTD_FB_WAIT_EDGE_ENTRY 0x001002A4}
    {DMTD_REF_QUAL_REACHED_8 0x00100268}
    {DMTD_FB_QUAL_REACHED_8 0x0010026C}
    {SPLL_DMTD_STATE 0x001002DC}
  }
  set arbitration_items {
    {TAG_PENDING_COUNT 0x001002A8}
    {TAG_PENDING_REF_COUNT 0x001002C4}
    {TAG_PENDING_FB_COUNT 0x001002C8}
    {TAG_GRANT_COUNT 0x001002AC}
    {TAG_VALID_COUNT 0x00100284}
    {TRR_WRITE_COUNT 0x00100288}
  }
  set downstream_items {
    {IRQ_COUNT 0x00100AEC}
    {HELPER_UPDATE_COUNT 0x00100B18}
    {TRR_POP_COUNT 0x00100B54}
    {STATE_TRANSITION_COUNT 0x00100AE4}
  }
  set timing_items {
    {CURRENT_TICS 0x001002B0}
    {DMTD_REF_LAST_TICS 0x001002B4}
    {DMTD_FB_LAST_TICS 0x001002B8}
    {TAG_REF_LAST_TICS 0x001002BC}
    {TAG_FB_LAST_TICS 0x001002C0}
    {TAG_PENDING_LAST_TICS 0x001002CC}
    {TAG_GRANT_LAST_TICS 0x001002D0}
    {TAG_VALID_LAST_TICS 0x001002D4}
    {TRR_WRITE_LAST_TICS 0x001002D8}
  }
  read_group $board DMTD_BOUNDARY $boundary_items
  read_d0_stable_group $board
  read_group $board TAG_ARBITRATION $arbitration_items
  read_group $board DOWNSTREAM $downstream_items
  read_group $board EVENT_TIMING $timing_items
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
