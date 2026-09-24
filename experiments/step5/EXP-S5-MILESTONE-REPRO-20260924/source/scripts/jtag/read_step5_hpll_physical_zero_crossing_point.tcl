# Step5 physical HPLL zero-crossing calibration point.
#
# The caller fresh-programs the same Slave image before every invocation.  The
# script then applies one exact A-polarity physical burst, waits for a fixed
# helper-update window, and reports the signed frequency-error slope together
# with the transaction-accounting evidence.
#
# Probe 41 payload:
#   [15:0]  accepted burst trigger count
#   [31:16] forced HPLL requests admitted
#   [47:32] forced HPLL transactions completed
#   [63:48] total DCO transactions completed
#
# Usage:
#   quartus_stp -t read_step5_hpll_physical_zero_crossing_point.tcl \
#     ?baseline_seconds? ?poll_ms? ?max_completion_polls? ?settle_updates? \
#     ?window_updates? ?helper_poll_ms? ?polarity_reverse? ?burst_size? \
#     ?board_filter?

package require ::quartus::insystem_source_probe

set baseline_seconds 5
set poll_ms 500
set max_completion_polls 160
set settle_updates 2
set window_updates 10
set helper_poll_ms 100
set polarity_reverse 0
set burst_size 0
set board_filter ""
if {[llength $argv] >= 1} { set baseline_seconds [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set poll_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set max_completion_polls [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set settle_updates [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set window_updates [expr {int([lindex $argv 4])}] }
if {[llength $argv] >= 6} { set helper_poll_ms [expr {int([lindex $argv 5])}] }
if {[llength $argv] >= 7} { set polarity_reverse [expr {int([lindex $argv 6])}] }
if {[llength $argv] >= 8} { set burst_size [expr {int([lindex $argv 7])}] }
if {[llength $argv] >= 9} { set board_filter [lindex $argv 8] }
if {$baseline_seconds <= 0 || $poll_ms <= 0 || $max_completion_polls <= 0 ||
    $settle_updates < 0 || $window_updates <= 0 || $helper_poll_ms <= 0 ||
    ($polarity_reverse != 0 && $polarity_reverse != 1) ||
    $burst_size < 0 || $burst_size > 65535} {
  error "invalid zero-crossing point arguments"
}

array set ::wb_toggle {}
array set ::snap_step {}
array set ::snap_trigger {}
array set ::snap_admitted {}
array set ::snap_completed {}
array set ::snap_total_step {}
array set ::snap_normal_req {}
array set ::snap_normal_done {}
array set ::snap_preclamp {}
array set ::snap_tag_delta {}
array set ::snap_expected_delta {}
array set ::snap_helper_update {}
array set ::snap_tag_minus_expected {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word64 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  if {$word < 0} {
    set word [expr {$word + 0x10000000000000000}]
  }
  return $word
}

proc display64 {value} {
  if {![is_hex $value]} { return $value }
  return [string toupper $value]
}

proc field_bits {word shift mask} {
  if {$word < 0} { return INVALID }
  return [expr {($word >> $shift) & $mask}]
}

proc signed32 {value} {
  if {![is_hex $value]} { return INVALID }
  scan $value %x word
  set word [expr {$word & 0xffffffff}]
  if {$word >= 0x80000000} {
    return [expr {$word - 0x100000000}]
  }
  return $word
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
  after 2
  for {set n 0} {$n < $poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value INVALID
    }
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} {
        return [format %08X [expr {$word & 0xffffffff}]]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc wb_sync_toggle {hardware_name} {
  set value [probe_read 1]
  if {[is_hex $value]} {
    scan $value %x word
    set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc force_source_write {value} {
  if {[catch {
    write_source_data -instance_index 36 -value [format %016X $value] -value_in_hex
  } error_message]} {
    error "HPLL trigger source write failed: $error_message"
  }
  after 10
}

proc burst_size_source_write {value} {
  if {[catch {
    write_source_data -instance_index 40 -value [format %016X $value] -value_in_hex
  } error_message]} {
    error "HPLL burst-size source write failed: $error_message"
  }
  after 10
}

proc polarity_source_write {value} {
  if {[catch {
    write_source_data -instance_index 38 -value [format %016X $value] -value_in_hex
  } error_message]} {
    error "HPLL polarity source write failed: $error_message"
  }
  after 10
}

proc snapshot_key {hardware_name tag} {
  return "${hardware_name}|${tag}"
}

proc read_snapshot {hardware_name tag} {
  global snap_step snap_trigger snap_admitted snap_completed snap_total_step
  global snap_normal_req snap_normal_done snap_preclamp snap_tag_delta
  global snap_expected_delta snap_helper_update snap_tag_minus_expected

  set key [snapshot_key $hardware_name $tag]
  set wide_raw [probe_read 41]
  set tracker_raw [probe_read 39]
  set preclamp_raw [wb_read $hardware_name 0x00100B08]
  if {[is_hex $preclamp_raw] && [word64 $preclamp_raw] == 0} {
    after 100
    set retry [wb_read $hardware_name 0x00100B08]
    if {[is_hex $retry] && [word64 $retry] != 0} { set preclamp_raw $retry }
  }
  set tag_delta_raw [wb_read $hardware_name 0x00100B0C]
  set expected_delta_raw [wb_read $hardware_name 0x00100B14]
  set helper_update_raw [wb_read $hardware_name 0x00100B18]

  set wide [word64 $wide_raw]
  set tracker [word64 $tracker_raw]
  set preclamp [signed32 $preclamp_raw]
  set tag_delta [signed32 $tag_delta_raw]
  set expected_delta [signed32 $expected_delta_raw]
  # WDIAGS_HELPER_UPDATE_COUNT is a 16-bit monotonic counter in the
  # diagnostic register map; compare it modulo 2^16 so a window crossing
  # 0xffff remains valid.
  set helper_update [expr {[word64 $helper_update_raw] & 0xffff}]
  set tag_minus_expected INVALID
  if {$tag_delta ne "INVALID" && $expected_delta ne "INVALID"} {
    set tag_minus_expected [expr {$tag_delta - $expected_delta}]
  }

  set snap_step($key) [field_bits $wide 48 0xffff]
  set snap_trigger($key) [field_bits $wide 0 0xffff]
  set snap_admitted($key) [field_bits $wide 16 0xffff]
  set snap_completed($key) [field_bits $wide 32 0xffff]
  set snap_total_step($key) [field_bits $wide 48 0xffff]
  set snap_normal_req($key) [field_bits $tracker 32 0xffff]
  set snap_normal_done($key) [field_bits $tracker 48 0xffff]
  set snap_preclamp($key) $preclamp
  set snap_tag_delta($key) $tag_delta
  set snap_expected_delta($key) $expected_delta
  set snap_helper_update($key) $helper_update
  set snap_tag_minus_expected($key) $tag_minus_expected

  puts [format "STEP5_ZERO_SAMPLE board=%s tag=%s BURST_WIDE_RAW=%s TRIGGER_COUNT=%s FORCED_HPLL_ADMITTED=%s FORCED_HPLL_COMPLETED=%s DCO_STEP_COUNT=%s TRACKER_RAW=%s NORMAL_HPLL_REQUEST_COUNT=%s NORMAL_HPLL_COMPLETED_COUNT=%s PRECLAMP_ERROR_SIGNED=%s TAG_DELTA_SIGNED=%s EXPECTED_DELTA_SIGNED=%s TAG_MINUS_EXPECTED=%s HELPER_UPDATE_COUNT=%s" \
    $hardware_name $tag [display64 $wide_raw] $snap_trigger($key) $snap_admitted($key) \
    $snap_completed($key) $snap_total_step($key) [display64 $tracker_raw] \
    $snap_normal_req($key) $snap_normal_done($key) $preclamp $tag_delta $expected_delta \
    $tag_minus_expected $helper_update]
  flush stdout
}

set ::poll_attempts 25
puts [format "STEP5_ZERO_CROSSING_CONFIG experiment=EXP-WRPC-STEP5-HPLL-PHYSICAL-ZERO-CROSSING-SWEEP baseline_seconds=%d poll_ms=%d max_completion_polls=%d settle_updates=%d window_updates=%d helper_poll_ms=%d polarity_reverse=%d burst_size=%d fixed_sof=1 normal_hpll_tracker=0 board_filter=%s" \
  $baseline_seconds $poll_ms $max_completion_polls $settle_updates $window_updates \
  $helper_poll_ms $polarity_reverse $burst_size $board_filter]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && $hardware_name ne $board_filter} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set wide_probe [probe_read 41]
    if {![is_hex $wide_probe]} {
      error "probe41_unavailable"
    }

    force_source_write 0
    polarity_source_write $polarity_reverse
    burst_size_source_write $burst_size
    wb_sync_toggle $hardware_name

    # Establish a same-image, no-force background window before the point.
    read_snapshot $hardware_name A0
    for {set n 1} {$n <= $baseline_seconds} {incr n} {
      after 1000
      read_snapshot $hardware_name [format "A%02d" $n]
    }
    set a0 [snapshot_key $hardware_name A0]
    set a_last [snapshot_key $hardware_name [format "A%02d" $baseline_seconds]]
    puts [format "STEP5_ZERO_BACKGROUND board=%s DELTA_HELPER_UPDATE_COUNT=%s DELTA_PRECLAMP_ERROR=%s" \
      $hardware_name \
      [expr {($snap_helper_update($a_last) - $snap_helper_update($a0)) & 0xffff}] \
      [expr {$snap_preclamp($a_last) - $snap_preclamp($a0)}]]

    read_snapshot $hardware_name B_BEFORE
    set before_key [snapshot_key $hardware_name B_BEFORE]
    if {$burst_size > 0} {
      force_source_write 1
      force_source_write 0
      puts [format "STEP5_ZERO_TRIGGER board=%s source=FORCE_HPLL_ONE_STEP transition=0->1->0 controller_burst_size=%d" $hardware_name $burst_size]
      flush stdout
    } else {
      puts [format "STEP5_ZERO_TRIGGER board=%s source=NONE controller_burst_size=0" $hardware_name]
      flush stdout
    }

    set last_tag B_BEFORE
    set burst_done [expr {$burst_size == 0}]
    set completion_delta 0
    if {$burst_size > 0} {
      for {set n 1} {$n <= $max_completion_polls} {incr n} {
        after $poll_ms
        set tag [format "B%03d" $n]
        read_snapshot $hardware_name $tag
        set key [snapshot_key $hardware_name $tag]
        set completion_delta [expr {($snap_completed($key) - $snap_completed($before_key)) & 0xffff}]
        set last_tag $tag
        if {$completion_delta >= $burst_size} {
          set burst_done 1
          break
        }
      }
    }
    set completion_key [snapshot_key $hardware_name $last_tag]
    puts [format "STEP5_ZERO_COMPLETION board=%s BURST_SIZE=%d BURST_COMPLETED=%d LAST_TAG=%s DELTA_FORCED_HPLL_COMPLETED=%s DELTA_DCO_STEP=%s" \
      $hardware_name $burst_size $burst_done $last_tag $completion_delta \
      [expr {($snap_total_step($completion_key) - $snap_total_step($before_key)) & 0xffff}]]
    flush stdout

    # Remove the completion-to-helper latency, then measure exactly the same
    # helper-update window for every N point.
    set settled 0
    set settle_tag $last_tag
    set settle_start $snap_helper_update($completion_key)
    if {$settle_updates > 0} {
      for {set n 1} {$n <= 200} {incr n} {
        after $helper_poll_ms
        set tag [format "S%03d" $n]
        read_snapshot $hardware_name $tag
        set key [snapshot_key $hardware_name $tag]
        set settle_tag $tag
        if {[expr {($snap_helper_update($key) - $settle_start) & 0xffff}] >= $settle_updates} {
          set settled 1
          set completion_key $key
          break
        }
      }
    } else {
      set settled 1
    }

    set window_start_tag [format "W0"]
    read_snapshot $hardware_name $window_start_tag
    set window_start [snapshot_key $hardware_name $window_start_tag]
    set start_update $snap_helper_update($window_start)
    set window_last $window_start
    set window_seen 0
    set tag_sum 0
    set tag_samples 0
    if {$snap_tag_minus_expected($window_start) ne "INVALID"} {
      set tag_sum $snap_tag_minus_expected($window_start)
      set tag_samples 1
    }
    for {set n 1} {$n <= 300} {incr n} {
      if {$window_seen >= $window_updates} { break }
      after $helper_poll_ms
      set tag [format "W%03d" $n]
      read_snapshot $hardware_name $tag
      set key [snapshot_key $hardware_name $tag]
      set window_last $key
      set window_seen [expr {($snap_helper_update($key) - $start_update) & 0xffff}]
      if {$snap_tag_minus_expected($key) ne "INVALID"} {
        set tag_sum [expr {$tag_sum + $snap_tag_minus_expected($key)}]
        incr tag_samples
      }
    }

    set window_end $window_last
    set helper_delta [expr {($snap_helper_update($window_end) - $snap_helper_update($window_start)) & 0xffff}]
    set preclamp_delta [expr {$snap_preclamp($window_end) - $snap_preclamp($window_start)}]
    set freq_error INVALID
    if {$helper_delta > 0} { set freq_error [expr {$preclamp_delta / $helper_delta}] }
    set mean_tag_minus_expected INVALID
    if {$tag_samples > 0} { set mean_tag_minus_expected [expr {$tag_sum / $tag_samples}] }
    set admitted_delta [expr {($snap_admitted($window_end) - $snap_admitted($before_key)) & 0xffff}]
    set completed_window_delta [expr {($snap_completed($window_end) - $snap_completed($before_key)) & 0xffff}]
    set total_step_delta [expr {($snap_total_step($window_end) - $snap_total_step($before_key)) & 0xffff}]
    set normal_req_delta [expr {($snap_normal_req($window_end) - $snap_normal_req($before_key)) & 0xffff}]
    set normal_done_delta [expr {($snap_normal_done($window_end) - $snap_normal_done($before_key)) & 0xffff}]
    puts [format "STEP5_ZERO_RESULT board=%s N=%d BURST_DONE=%d SETTLED=%d WINDOW_START=%s WINDOW_END=%s DELTA_HELPER_UPDATE_COUNT=%s DELTA_PRECLAMP_ERROR=%s FREQ_ERROR=%s FREQ_ERROR_NUM=%s FREQ_ERROR_DEN=%s MEAN_TAG_MINUS_EXPECTED=%s TAG_SAMPLE_COUNT=%s DELTA_BURST_TRIGGER_COUNT=%s DELTA_FORCED_HPLL_ADMITTED=%s DELTA_FORCED_HPLL_COMPLETED=%s DELTA_DCO_STEP=%s DELTA_NORMAL_HPLL_REQUEST_COUNT=%s DELTA_NORMAL_HPLL_COMPLETED_COUNT=%s" \
      $hardware_name $burst_size $burst_done $settled $window_start_tag $window_last \
      $helper_delta $preclamp_delta $freq_error $preclamp_delta $helper_delta \
      $mean_tag_minus_expected $tag_samples \
      [expr {($snap_trigger($window_end) - $snap_trigger($before_key)) & 0xffff}] \
      $admitted_delta $completed_window_delta $total_step_delta $normal_req_delta $normal_done_delta]
    flush stdout
  } error_message]} {
    puts [format "STEP5_ZERO_ERROR board=%s message=%s" $hardware_name $error_message]
    flush stdout
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_ZERO_CROSSING_POINT_DONE"
