# Post-startup armed, runtime-only correlation capture.
#
# The hardware recorder preserves startup provenance, then clears only the
# diagnostic runtime timestamps after the required stable post-startup window.
# The only write made by this script is one explicit Master VUART stimulus:
# mode master\n.  The Slave is never stimulated.
#
# Probe 8: existing DCO debug layout.
# Probes 28..33: runtime-only timestamp/state correlation layout.
#   28: T_DAC_LOAD, T_RUNTIME_START
#   29: T_BUS_DONE, T_STATIC_DONE_PULSE
#   30: T_STATIC_STATE_LEAVE_ZERO, T_STATIC_READY_DROP
#   31: T_SI_CONFIG_DROP, T_WR_CORE_RESET_ASSERT
#   32: T_CPU_RESET_ASSERT, T_SYSTEM_START (post-arm)
#   33: static before/after/current and live runtime flags
# Probe 34: T_POST_STARTUP_ARM, STARTUP_SYSTEM_START_SEEN
# Probe 35: STARTUP_STATIC_COMPLETE_SEEN, STARTUP_READY_FINAL, POST_ARMED
#
# Usage:
#   quartus_stp -t read_post_startup_armed_runtime_correlation.tcl
#       ?samples? ?gap_ms? ?poll_attempts? ?minimum_inject_sample?

package require ::quartus::insystem_source_probe

set samples 200
set gap_ms 200
set poll_attempts 25
set minimum_inject_sample 20
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set poll_attempts [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set minimum_inject_sample [expr {int([lindex $argv 3])}] }
if {$samples <= 0 || $gap_ms < 0 || $poll_attempts <= 0 ||
    $minimum_inject_sample <= 0 || $minimum_inject_sample > $samples} {
  error "samples > 0, gap_ms >= 0, poll_attempts > 0, 0 < minimum_inject_sample <= samples required"
}

array set ::wb_toggle {}
array set ::post_armed_live {}
array set ::injected {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word64 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return $word
}

proc display64 {value} {
  set word [word64 $value]
  if {$word < 0} { return $value }
  return [format %016X $word]
}

proc display32_from_word {word shift} {
  if {$word < 0} { return INVALID }
  return [format %08X [expr {($word >> $shift) & 0xffffffff}]]
}

proc field_bit {word bit_index} {
  if {$word < 0} { return INVALID }
  return [expr {($word >> $bit_index) & 1}]
}

proc field_byte {word bit_index} {
  if {$word < 0} { return INVALID }
  return [format %02X [expr {($word >> $bit_index) & 0xff}]]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc wb_read {hardware_name addr} {
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 2
  for {set n 0} {$n < $::poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value TIMEOUT
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

proc wb_write {hardware_name addr data} {
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (1 << 1) | (0xf << 2) |
                (($addr & 0xffffffff) << 6) |
                (($data & 0xffffffff) << 38)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 2
  for {set n 0} {$n < $::poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value TIMEOUT
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

proc inject_mode_master {hardware_name sample} {
  set command "mode master\n"
  set index 0
  foreach character [split $command ""] {
    scan $character %c byte
    set result [wb_write $hardware_name 0x00100510 $byte]
    puts [format "POST_RUNTIME_VUART_INJECT board=%s sample=%03d index=%02d BYTE=0x%02X WB_RESULT=%s" \
      $hardware_name $sample $index $byte $result]
    incr index
  }
  flush stdout
}

proc read_one {hardware_name sample elapsed_ms} {
  set dco_raw [probe_read 8]
  set dco_word [word64 $dco_raw]
  set corr0_raw [probe_read 28]
  set corr0_word [word64 $corr0_raw]
  set corr1_raw [probe_read 29]
  set corr1_word [word64 $corr1_raw]
  set corr2_raw [probe_read 30]
  set corr2_word [word64 $corr2_raw]
  set corr3_raw [probe_read 31]
  set corr3_word [word64 $corr3_raw]
  set corr4_raw [probe_read 32]
  set corr4_word [word64 $corr4_raw]
  set corr5_raw [probe_read 33]
  set corr5_word [word64 $corr5_raw]
  set corr6_raw [probe_read 34]
  set corr6_word [word64 $corr6_raw]
  set corr7_raw [probe_read 35]
  set corr7_word [word64 $corr7_raw]
  set reset_raw [probe_read 27]
  set cpu_raw [probe_read 2]
  set sync_raw [probe_read 0]
  set entry_raw [probe_read 26]

  set mode_stage [wb_read $hardware_name 0x00100B74]
  set lock_wait [wb_read $hardware_name 0x00100B78]
  set spll_stage [wb_read $hardware_name 0x00100B90]
  set command_stage [wb_read $hardware_name 0x00100BA0]
  set entry_word [word64 $entry_raw]
  set reset_word [word64 $reset_raw]
  set corr7_post_armed [field_bit $corr7_word 33]
  set ::post_armed_live($hardware_name) $corr7_post_armed

  puts [format "POST_RUNTIME_SAMPLE board=%s sample=%03d elapsed_ms=%d DCO_RAW=%s RT_STATE=%s BUS_STATE=%s BUS_DONE=%s STATIC_READY=%s RUNTIME_START=%s BUS_ENABLE=%s DPLL_LOAD=%s HPLL_LOAD=%s CORR0_RAW=%s T_DAC_LOAD=%s T_RUNTIME_START=%s CORR1_RAW=%s T_BUS_DONE=%s T_STATIC_DONE_PULSE=%s CORR2_RAW=%s T_STATIC_STATE_LEAVE_ZERO=%s T_STATIC_READY_DROP=%s CORR3_RAW=%s T_SI_CONFIG_DROP=%s T_WR_CORE_RESET_ASSERT=%s CORR4_RAW=%s T_CPU_RESET_ASSERT=%s T_SYSTEM_START=%s CORR5_RAW=%s STATIC_BEFORE=%s STATIC_AFTER=%s STATIC_CURRENT=%s POST_STARTUP_ARMED=%s SI_CONFIG_DONE=%s WR_CORE_RESET_N=%s CPU_RESET=%s LIVE_RUNTIME_START=%s LIVE_BUS_DONE=%s LIVE_STATIC_DONE_PULSE=%s STATIC_ACCESS_START=%s RUNTIME_STATE_LIVE=%s BUS_STATE_LIVE=%s RUNTIME_BUS_ENABLE=%s SYSTEM_START_LIVE=%s CORR6_RAW=%s T_POST_STARTUP_ARM=%s STARTUP_SYSTEM_START_SEEN=%s CORR7_RAW=%s STARTUP_STATIC_COMPLETE_SEEN=%s STARTUP_READY_FINAL=%s POST_ARMED=%s RESET_RAW=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s BOOT_GENERATION=%s PERSIST_MODE_MASTER_STAGE=%s PERSIST_LOCK_WAIT_SUBSTAGE=%s PERSIST_SPLL_CHECK_LOCK_STAGE=%s PERSIST_CMD_STAGE=%s CPU_RAW=%s SYNC_RAW=%s ENTRY_RAW=%s" \
    $hardware_name $sample $elapsed_ms [display64 $dco_raw] \
    [field_byte $dco_word 0] [field_bit $dco_word 3] [field_bit $dco_word 4] \
    [field_bit $dco_word 5] [field_bit $dco_word 14] [field_bit $dco_word 15] \
    [field_bit $dco_word 16] [field_bit $dco_word 17] \
    [display64 $corr0_raw] [display32_from_word $corr0_word 0] \
    [display32_from_word $corr0_word 32] [display64 $corr1_raw] \
    [display32_from_word $corr1_word 0] [display32_from_word $corr1_word 32] \
    [display64 $corr2_raw] [display32_from_word $corr2_word 0] \
    [display32_from_word $corr2_word 32] [display64 $corr3_raw] \
    [display32_from_word $corr3_word 0] [display32_from_word $corr3_word 32] \
    [display64 $corr4_raw] [display32_from_word $corr4_word 0] \
    [display32_from_word $corr4_word 32] [display64 $corr5_raw] \
    [field_byte $corr5_word 0] [field_byte $corr5_word 8] \
    [field_byte $corr5_word 16] [field_bit $corr5_word 24] \
    [field_bit $corr5_word 25] [field_bit $corr5_word 26] \
    [field_bit $corr5_word 27] [field_bit $corr5_word 28] \
    [field_bit $corr5_word 29] [field_bit $corr5_word 30] \
    [field_bit $corr5_word 31] [field_byte $corr5_word 32] \
    [field_bit $corr5_word 35] [field_bit $corr5_word 36] \
    [field_bit $corr5_word 37] [display64 $corr6_raw] \
    [display32_from_word $corr6_word 0] [display32_from_word $corr6_word 32] \
    [display64 $corr7_raw] [display32_from_word $corr7_word 0] \
    [field_bit $corr7_word 32] [field_bit $corr7_word 33] \
    [display64 $reset_raw] [field_byte $reset_word 16] \
    [field_byte $reset_word 24] [field_byte $reset_word 40] \
    [display32_from_word $entry_word 32] [display32_from_word [word64 $mode_stage] 0] \
    [display32_from_word [word64 $lock_wait] 0] [display32_from_word [word64 $spll_stage] 0] \
    [display32_from_word [word64 $command_stage] 0] [display64 $cpu_raw] \
    [display64 $sync_raw] [display64 $entry_raw]]
  flush stdout
}

puts [format "POST_RUNTIME_CONFIG samples=%d gap_ms=%d poll_attempts=%d minimum_inject_sample=%d experiment=EXP-WRPC-STEP4-POST-STARTUP-ARMED-RUNTIME-CORRELATION-20260828 manual_command=mode_master_once master_only=1 passive_capture=1 stable_arm_ms=5" \
  $samples $gap_ms $poll_attempts $minimum_inject_sample]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== POST_RUNTIME_BOARD ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    set ::post_armed_live($hardware_name) 0
    set ::injected($hardware_name) 0
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set elapsed [expr {[clock milliseconds] - $start_ms}]
      read_one $hardware_name $sample $elapsed
      if {$::injected($hardware_name) == 0 && $sample >= $minimum_inject_sample &&
          [string first "1-11.1" $hardware_name] >= 0 &&
          $::post_armed_live($hardware_name) eq "1"} {
        inject_mode_master $hardware_name $sample
        set ::injected($hardware_name) 1
      }
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
    if {$::injected($hardware_name) == 0 &&
        [string first "1-11.1" $hardware_name] >= 0} {
      puts [format "POST_RUNTIME_INJECT_SKIPPED board=%s reason=post_startup_arm_not_observed" $hardware_name]
    }
    if {[string first "1-11.1" $hardware_name] < 0} {
      puts [format "POST_RUNTIME_INJECT_SKIPPED board=%s reason=not_master_cable" $hardware_name]
    }
  } error_message]} {
    puts [format "POST_RUNTIME_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "POST_RUNTIME_DONE"
