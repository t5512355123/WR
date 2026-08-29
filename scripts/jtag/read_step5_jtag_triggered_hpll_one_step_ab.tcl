# Step5 JTAG-triggered exactly-one HPLL request A/B.
#
# Probe 8 remains the existing DCO state/debug word.  Probe 36 is the new
# combined Step5 probe: its 64-bit probe is read-only status and its 1-bit
# source is FORCE_HPLL_ONE_STEP.
#
# Probe 36 payload:
#   [7:0]   FORCE_TRIGGER_COUNT
#   [15:8]  FORCED_PENDING_COUNT
#   [23:16] RT_STATE_ENTER_COUNT
#   [31:24] RUNTIME_START_COUNT (rising events)
#   [39:32] BUS_DONE_COUNT (rising events)
#   [55:40] DCO_STEP_COUNT
#   [56]    FORCE_SEEN
#   [57]    FORCE_LEVEL_SYNC
#   [58]    FORCE_RISE (live)
#   [59]    HPLL_PENDING (live)
#   [60]    HPLL_PREV_VALID
#   [61]    STATIC_READY
#   [63:62] RT_STATE low two bits
#
# Usage:
#   quartus_stp -t read_step5_jtag_triggered_hpll_one_step_ab.tcl
#   quartus_stp -t read_step5_jtag_triggered_hpll_one_step_ab.tcl ?a_seconds? ?b_seconds?

package require ::quartus::insystem_source_probe

set a_seconds 10
set b_seconds 20
set poll_attempts 25
if {[llength $argv] >= 1} { set a_seconds [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set b_seconds [expr {int([lindex $argv 1])}] }
if {$a_seconds <= 0 || $b_seconds <= 0} {
  error "a_seconds and b_seconds must be > 0"
}

array set ::wb_toggle {}
array set ::snap_step {}
array set ::snap_helper_error {}
array set ::snap_force_trigger {}
array set ::snap_forced_pending {}
array set ::snap_rt_enter {}
array set ::snap_runtime_start {}
array set ::snap_bus_done {}

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

proc field_bit {word bit_index} {
  if {$word < 0} { return INVALID }
  return [expr {($word >> $bit_index) & 1}]
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
    error "FORCE_HPLL_ONE_STEP write failed: $error_message"
  }
  after 10
}

proc read_snapshot {hardware_name tag} {
  global snap_step snap_helper_error snap_force_trigger snap_forced_pending
  global snap_rt_enter snap_runtime_start snap_bus_done

  set dco_raw [probe_read 8]
  set event_raw [probe_read 36]
  set helper_raw [wb_read $hardware_name 0x00100AD8]
  set dco [word64 $dco_raw]
  set event [word64 $event_raw]
  set helper_error [signed32 $helper_raw]

  set snap_step($tag) [field_bits $dco 20 0xffff]
  set snap_helper_error($tag) $helper_error
  set snap_force_trigger($tag) [field_bits $event 0 0xff]
  set snap_forced_pending($tag) [field_bits $event 8 0xff]
  set snap_rt_enter($tag) [field_bits $event 16 0xff]
  set snap_runtime_start($tag) [field_bits $event 24 0xff]
  set snap_bus_done($tag) [field_bits $event 32 0xff]

  puts [format "STEP5_TRIGGERED_SAMPLE board=%s tag=%s DCO_RAW=%s EVENT_RAW=%s STEP=%s HELPER_ERROR=%s HELPER_ERROR_SIGNED=%s FORCE_TRIGGER_COUNT=%s FORCED_PENDING_COUNT=%s RT_STATE_ENTER_COUNT=%s RUNTIME_START_COUNT=%s BUS_DONE_COUNT=%s FORCE_SEEN=%s FORCE_LEVEL_SYNC=%s FORCE_RISE=%s HPLL_PENDING=%s HPLL_PREV_VALID=%s STATIC_READY=%s RT_STATE_LOW2=%s" \
    $hardware_name $tag [display64 $dco_raw] [display64 $event_raw] \
    [field_bits $dco 20 0xffff] $helper_raw $helper_error \
    [field_bits $event 0 0xff] [field_bits $event 8 0xff] \
    [field_bits $event 16 0xff] [field_bits $event 24 0xff] \
    [field_bits $event 32 0xff] [field_bit $event 56] \
    [field_bit $event 57] [field_bit $event 58] [field_bit $event 59] \
    [field_bit $event 60] [field_bit $event 61] [field_bits $event 62 0x3]]
  flush stdout
}

proc delta_line {hardware_name before_tag after_tag} {
  global snap_step snap_helper_error snap_force_trigger snap_forced_pending
  global snap_rt_enter snap_runtime_start snap_bus_done
  set step_delta [expr {($snap_step($after_tag) - $snap_step($before_tag)) & 0xffff}]
  puts [format "STEP5_TRIGGERED_DELTA board=%s before=%s after=%s STEP_BEFORE=%s STEP_AFTER=%s DELTA_STEP=%s HELPER_ERROR_BEFORE=%s HELPER_ERROR_AFTER=%s DELTA_HELPER_ERROR=%s DELTA_FORCE_TRIGGER_COUNT=%s DELTA_FORCED_PENDING_COUNT=%s DELTA_RT_STATE_ENTER_COUNT=%s DELTA_RUNTIME_START_COUNT=%s DELTA_BUS_DONE_COUNT=%s" \
    $hardware_name $before_tag $after_tag \
    $snap_step($before_tag) $snap_step($after_tag) $step_delta \
    $snap_helper_error($before_tag) $snap_helper_error($after_tag) \
    [expr {$snap_helper_error($after_tag) - $snap_helper_error($before_tag)}] \
    [expr {$snap_force_trigger($after_tag) - $snap_force_trigger($before_tag)}] \
    [expr {$snap_forced_pending($after_tag) - $snap_forced_pending($before_tag)}] \
    [expr {$snap_rt_enter($after_tag) - $snap_rt_enter($before_tag)}] \
    [expr {$snap_runtime_start($after_tag) - $snap_runtime_start($before_tag)}] \
    [expr {$snap_bus_done($after_tag) - $snap_bus_done($before_tag)}]]
  flush stdout
}

puts [format "STEP5_TRIGGERED_HPLL_ONE_STEP_AB_CONFIG a_seconds=%d b_seconds=%d experiment=EXP-WRPC-STEP5-JTAG-TRIGGERED-HPLL-ONE-STEP-AB fixed_sof=1" $a_seconds $b_seconds]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set event_probe [probe_read 36]
    if {[is_hex $event_probe]} {
      # A: hold the dedicated source low and prove no spontaneous step.
      force_source_write 0
      wb_sync_toggle $hardware_name
      read_snapshot $hardware_name A0
      for {set n 1} {$n <= $a_seconds} {incr n} {
        after 1000
        read_snapshot $hardware_name [format "A%02d" $n]
      }
      delta_line $hardware_name A0 [format "A%02d" $a_seconds]

      # B: capture the trigger baseline, then issue exactly one 0->1->0 pulse.
      read_snapshot $hardware_name B_BEFORE
      force_source_write 1
      force_source_write 0
      puts [format "STEP5_TRIGGERED_PULSE board=%s source=FORCE_HPLL_ONE_STEP transition=0->1->0" $hardware_name]
      flush stdout
      for {set n 1} {$n <= $b_seconds} {incr n} {
        after 1000
        read_snapshot $hardware_name [format "B%02d" $n]
      }
      read_snapshot $hardware_name B_AFTER
      delta_line $hardware_name B_BEFORE B_AFTER
      delta_line $hardware_name A0 B_BEFORE
      puts [format "STEP5_TRIGGERED_DONE board=%s" $hardware_name]
      flush stdout
    } else {
      puts [format "STEP5_TRIGGERED_SKIP board=%s reason=probe36_unavailable" $hardware_name]
      flush stdout
    }
  } error_message]} {
    puts [format "STEP5_TRIGGERED_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_TRIGGERED_HPLL_ONE_STEP_AB_DONE"
