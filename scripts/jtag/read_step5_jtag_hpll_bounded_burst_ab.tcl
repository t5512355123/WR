# Step5 JTAG-triggered bounded HPLL burst A/B.
#
# One 0->1->0 transition on source instance 36 arms the Slave controller's
# internal eight-request serializer.  This script does not manually pulse
# eight times.  Probe 37 carries burst-specific counters; probe 8 carries the
# existing DCO step counter.  The WB reads are read-only diagnostic shadows.
#
# Probe 37 payload:
#   [7:0]   BURST_TRIGGER_COUNT
#   [15:8]  FORCED_HPLL_PENDING_COUNT
#   [23:16] FORCED_HPLL_COMPLETED_COUNT
#   [31:24] RT_STATE_ENTER_COUNT (total)
#   [39:32] RUNTIME_START_COUNT (total rising events)
#   [47:40] BUS_DONE_COUNT (total rising events)
#   [63:48] DCO_STEP_COUNT
#
# Usage:
#   quartus_stp -t read_step5_jtag_hpll_bounded_burst_ab.tcl
#   quartus_stp -t read_step5_jtag_hpll_bounded_burst_ab.tcl ?a_seconds? ?poll_ms? ?max_polls? ?helper_poll_ms? ?max_helper_polls? ?polarity_reverse?

package require ::quartus::insystem_source_probe

set a_seconds 5
set poll_ms 500
set max_polls 80
set poll_attempts 25
set helper_poll_ms 0
set max_helper_polls 0
set polarity_reverse 0
if {[llength $argv] >= 1} { set a_seconds [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set poll_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set max_polls [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set helper_poll_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set max_helper_polls [expr {int([lindex $argv 4])}] }
if {[llength $argv] >= 6} { set polarity_reverse [expr {int([lindex $argv 5])}] }
if {$a_seconds <= 0 || $poll_ms <= 0 || $max_polls <= 0 ||
    $helper_poll_ms < 0 || $max_helper_polls < 0 ||
    ($helper_poll_ms > 0 && $max_helper_polls <= 0) ||
    ($polarity_reverse != 0 && $polarity_reverse != 1)} {
  error "a_seconds, poll_ms, and max_polls must be > 0; helper wait is optional but requires both helper_poll_ms and max_helper_polls"
}

array set ::wb_toggle {}
array set ::snap_step {}
array set ::snap_burst_trigger {}
array set ::snap_forced_pending {}
array set ::snap_forced_completed {}
array set ::snap_rt_enter {}
array set ::snap_runtime_start {}
array set ::snap_bus_done {}
array set ::snap_preclamp {}
array set ::snap_raw_tag {}
array set ::snap_expected_tag {}
array set ::snap_tag_delta {}
array set ::snap_expected_delta {}
array set ::snap_helper_update {}

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
    error "HPLL burst trigger write failed: $error_message"
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
  global snap_step snap_burst_trigger snap_forced_pending snap_forced_completed
  global snap_rt_enter snap_runtime_start snap_bus_done snap_preclamp
  global snap_raw_tag snap_expected_tag snap_tag_delta snap_expected_delta
  global snap_helper_update

  set key [snapshot_key $hardware_name $tag]
  set dco_raw [probe_read 8]
  set burst_raw [probe_read 37]
  set polarity_raw [probe_read 38]
  set preclamp_raw [wb_read $hardware_name 0x00100B08]
  set raw_tag [wb_read $hardware_name 0x00100B00]
  set expected_tag [wb_read $hardware_name 0x00100B04]
  set tag_delta [wb_read $hardware_name 0x00100B0C]
  set expected_delta [wb_read $hardware_name 0x00100B14]
  set helper_update [wb_read $hardware_name 0x00100B18]
  set helper_error [wb_read $hardware_name 0x00100AD8]
  set helper_output [wb_read $hardware_name 0x00100ADC]

  set dco [word64 $dco_raw]
  set burst [word64 $burst_raw]
  set polarity [word64 $polarity_raw]
  set step [field_bits $dco 20 0xffff]
  set preclamp_signed [signed32 $preclamp_raw]
  set raw_tag_signed [signed32 $raw_tag]
  set expected_tag_signed [signed32 $expected_tag]
  set tag_delta_signed [signed32 $tag_delta]
  set expected_delta_signed [signed32 $expected_delta]
  set helper_update_unsigned [expr {[word64 $helper_update] & 0xffffffff}]

  set snap_step($key) $step
  set snap_burst_trigger($key) [field_bits $burst 0 0xff]
  set snap_forced_pending($key) [field_bits $burst 8 0xff]
  set snap_forced_completed($key) [field_bits $burst 16 0xff]
  set snap_rt_enter($key) [field_bits $burst 24 0xff]
  set snap_runtime_start($key) [field_bits $burst 32 0xff]
  set snap_bus_done($key) [field_bits $burst 40 0xff]
  set snap_preclamp($key) $preclamp_signed
  set snap_raw_tag($key) $raw_tag_signed
  set snap_expected_tag($key) $expected_tag_signed
  set snap_tag_delta($key) $tag_delta_signed
  set snap_expected_delta($key) $expected_delta_signed
  set snap_helper_update($key) $helper_update_unsigned

  puts [format "STEP5_BURST_SAMPLE board=%s tag=%s DCO_RAW=%s BURST_RAW=%s POLARITY_RAW=%s POLARITY_SOURCE=%s POLARITY_ACTIVE=%s STEP=%s BURST_TRIGGER_COUNT=%s FORCED_HPLL_PENDING_COUNT=%s FORCED_HPLL_COMPLETED_COUNT=%s RT_STATE_ENTER_COUNT=%s RUNTIME_START_COUNT=%s BUS_DONE_COUNT=%s PRECLAMP_ERROR=%s PRECLAMP_ERROR_SIGNED=%s RAW_TAG=%s RAW_TAG_SIGNED=%s EXPECTED_TAG=%s EXPECTED_TAG_SIGNED=%s TAG_DELTA=%s TAG_DELTA_SIGNED=%s EXPECTED_DELTA=%s EXPECTED_DELTA_SIGNED=%s HELPER_UPDATE_COUNT=%s HELPER_ERROR=%s HELPER_OUTPUT=%s" \
    $hardware_name $tag [display64 $dco_raw] [display64 $burst_raw] [display64 $polarity_raw] \
    [field_bits $polarity 0 1] [field_bits $polarity 1 1] $step \
    [field_bits $burst 0 0xff] [field_bits $burst 8 0xff] \
    [field_bits $burst 16 0xff] [field_bits $burst 24 0xff] \
    [field_bits $burst 32 0xff] [field_bits $burst 40 0xff] \
    $preclamp_raw $preclamp_signed $raw_tag $raw_tag_signed \
    $expected_tag $expected_tag_signed $tag_delta $tag_delta_signed \
    $expected_delta $expected_delta_signed $helper_update \
    $helper_error $helper_output]
  flush stdout
}

proc delta_line {hardware_name before_tag after_tag} {
  global snap_step snap_burst_trigger snap_forced_pending snap_forced_completed
  global snap_rt_enter snap_runtime_start snap_bus_done snap_preclamp
  global snap_raw_tag snap_expected_tag snap_tag_delta snap_expected_delta
  global snap_helper_update

  set before [snapshot_key $hardware_name $before_tag]
  set after [snapshot_key $hardware_name $after_tag]
  set step_delta [expr {($snap_step($after) - $snap_step($before)) & 0xffff}]
  set preclamp_delta [expr {$snap_preclamp($after) - $snap_preclamp($before)}]
  set raw_tag_delta [expr {$snap_raw_tag($after) - $snap_raw_tag($before)}]
  set expected_tag_delta [expr {$snap_expected_tag($after) - $snap_expected_tag($before)}]
  set tag_delta_delta [expr {$snap_tag_delta($after) - $snap_tag_delta($before)}]
  set expected_delta_delta [expr {$snap_expected_delta($after) - $snap_expected_delta($before)}]
  set helper_update_delta [expr {($snap_helper_update($after) - $snap_helper_update($before)) & 0xffffffff}]

  puts [format "STEP5_BURST_DELTA board=%s before=%s after=%s STEP_BEFORE=%s STEP_AFTER=%s DELTA_STEP=%s DELTA_BURST_TRIGGER_COUNT=%s DELTA_FORCED_HPLL_PENDING_COUNT=%s DELTA_FORCED_HPLL_COMPLETED_COUNT=%s DELTA_RT_STATE_ENTER_COUNT=%s DELTA_RUNTIME_START_COUNT=%s DELTA_BUS_DONE_COUNT=%s PRECLAMP_ERROR_BEFORE=%s PRECLAMP_ERROR_AFTER=%s DELTA_PRECLAMP_ERROR=%s RAW_TAG_BEFORE=%s RAW_TAG_AFTER=%s DELTA_RAW_TAG=%s EXPECTED_TAG_BEFORE=%s EXPECTED_TAG_AFTER=%s DELTA_EXPECTED_TAG=%s TAG_DELTA_BEFORE=%s TAG_DELTA_AFTER=%s DELTA_TAG_DELTA=%s EXPECTED_DELTA_BEFORE=%s EXPECTED_DELTA_AFTER=%s DELTA_EXPECTED_DELTA=%s DELTA_HELPER_UPDATE_COUNT=%s" \
    $hardware_name $before_tag $after_tag $snap_step($before) $snap_step($after) $step_delta \
    [expr {($snap_burst_trigger($after) - $snap_burst_trigger($before)) & 0xff}] \
    [expr {($snap_forced_pending($after) - $snap_forced_pending($before)) & 0xff}] \
    [expr {($snap_forced_completed($after) - $snap_forced_completed($before)) & 0xff}] \
    [expr {($snap_rt_enter($after) - $snap_rt_enter($before)) & 0xff}] \
    [expr {($snap_runtime_start($after) - $snap_runtime_start($before)) & 0xff}] \
    [expr {($snap_bus_done($after) - $snap_bus_done($before)) & 0xff}] \
    $snap_preclamp($before) $snap_preclamp($after) $preclamp_delta \
    $snap_raw_tag($before) $snap_raw_tag($after) $raw_tag_delta \
    $snap_expected_tag($before) $snap_expected_tag($after) $expected_tag_delta \
    $snap_tag_delta($before) $snap_tag_delta($after) $tag_delta_delta \
    $snap_expected_delta($before) $snap_expected_delta($after) $expected_delta_delta \
    $helper_update_delta]
  flush stdout
}

puts [format "STEP5_JTAG_HPLL_BOUNDED_BURST_AB_CONFIG a_seconds=%d poll_ms=%d max_polls=%d helper_poll_ms=%d max_helper_polls=%d polarity_reverse=%d experiment=EXP-WRPC-STEP5-JTAG-HPLL-BOUNDED-BURST-AB-20260830 fixed_sof=1 burst_size=8" $a_seconds $poll_ms $max_polls $helper_poll_ms $max_helper_polls $polarity_reverse]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set burst_probe [probe_read 37]
    if {[is_hex $burst_probe]} {
      # A: keep the trigger source low and establish the background window.
      force_source_write 0
      polarity_source_write $polarity_reverse
      wb_sync_toggle $hardware_name
      read_snapshot $hardware_name A0
      for {set n 1} {$n <= $a_seconds} {incr n} {
        after 1000
        read_snapshot $hardware_name [format "A%02d" $n]
      }
      delta_line $hardware_name A0 [format "A%02d" $a_seconds]

      # B: one source pulse; the FPGA controller, not this script, serializes
      # the eight requests.
      read_snapshot $hardware_name B_BEFORE
      force_source_write 1
      force_source_write 0
      puts [format "STEP5_BURST_TRIGGER board=%s source=FORCE_HPLL_ONE_STEP transition=0->1->0 controller_burst_size=8" $hardware_name]
      flush stdout

      set last_tag B_BEFORE
      set completed_delta 0
      set burst_done 0
      for {set n 1} {$n <= $max_polls} {incr n} {
        after $poll_ms
        set poll_tag [format "B%03d" $n]
        read_snapshot $hardware_name $poll_tag
        set before_key [snapshot_key $hardware_name B_BEFORE]
        set poll_key [snapshot_key $hardware_name $poll_tag]
        set completed_delta [expr {($snap_forced_completed($poll_key) - $snap_forced_completed($before_key)) & 0xff}]
        set last_tag $poll_tag
        if {$completed_delta >= 8} {
          set burst_done 1
          break
        }
      }

      delta_line $hardware_name B_BEFORE $last_tag

      # The burst itself may finish between helper updates.  In correlation
      # mode, keep the same image and trigger, then wait for the first later
      # sample where the firmware helper update count advances.
      set completion_tag $last_tag
      set helper_tag $completion_tag
      set helper_update_seen 0
      set helper_update_delta 0
      if {$burst_done && $helper_poll_ms > 0} {
        set completion_key [snapshot_key $hardware_name $completion_tag]
        set completion_update_count $snap_helper_update($completion_key)
        for {set n 1} {$n <= $max_helper_polls} {incr n} {
          after $helper_poll_ms
          set candidate_tag [format "H%03d" $n]
          read_snapshot $hardware_name $candidate_tag
          set candidate_key [snapshot_key $hardware_name $candidate_tag]
          set helper_update_delta [expr {($snap_helper_update($candidate_key) - $completion_update_count) & 0xffffffff}]
          set helper_tag $candidate_tag
          if {$helper_update_delta >= 1} {
            set helper_update_seen 1
            break
          }
        }
        delta_line $hardware_name $completion_tag $helper_tag
        puts [format "STEP5_HELPER_CORRELATION board=%s COMPLETION_TAG=%s FIRST_HELPER_TAG=%s HELPER_UPDATE_SEEN=%d DELTA_HELPER_UPDATE_COUNT=%s" $hardware_name $completion_tag $helper_tag $helper_update_seen $helper_update_delta]
        flush stdout
      }
      puts [format "STEP5_BURST_RESULT board=%s BURST_COMPLETED=%d POLL_TAG=%s" $hardware_name $burst_done $last_tag]
      puts [format "STEP5_BURST_EXPECTED board=%s DELTA_BURST_TRIGGER_COUNT=1 DELTA_FORCED_HPLL_PENDING_COUNT=8 DELTA_FORCED_HPLL_COMPLETED_COUNT=8 DELTA_STEP>=8" $hardware_name]
      puts [format "STEP5_BURST_DONE board=%s" $hardware_name]
      flush stdout
    } else {
      puts [format "STEP5_BURST_SKIP board=%s reason=probe37_unavailable" $hardware_name]
      flush stdout
    }
  } error_message]} {
    puts [format "STEP5_BURST_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_JTAG_HPLL_BOUNDED_BURST_AB_DONE"
