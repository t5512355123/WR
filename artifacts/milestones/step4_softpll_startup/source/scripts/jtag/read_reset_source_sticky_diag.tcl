# Read-only hardware reset/drop sticky evidence from instance 27.
#
# The observer domain is the external 50 MHz CLK_50_B2J domain.  It is not
# reset by wr_core_reset_n or by the uRV CPU reset.  The sticky bits are
# asynchronously set after a post-configuration arm window; counters are
# synchronized-edge auxiliaries and are not width-independent evidence.
#
# Instance 27 layout:
#   bit 0       diagnostic arm
#   bits 1..8   CPU reset, WR core reset, external reset, SI config drop,
#               SYS PLL lock drop, software reset, PHY reset, WR ready drop
#   bits 23..16 CPU reset assertion count
#   bits 31..24 WR core reset assertion count
#   bits 39..32 external reset assertion count
#   bits 47..40 SI config-done drop count
#   bits 55..48 SYS PLL lock-drop count
#   bits 63..56 software reset assertion count
#
# Instance 2 remains the read-only live CPU/reset probe.  Existing WDIAGS
# breadcrumbs are read through the diagnostic mailbox for correlation; those
# are read transactions only and do not hold/reset the CPU or write WR/PHY.
#
# Usage:
#   quartus_stp -t read_reset_source_sticky_diag.tcl ?samples? ?gap_ms?

package require ::quartus::insystem_source_probe

set samples 5
set gap_ms 100
set poll_attempts 25
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples > 0 and gap_ms >= 0 required"
}

array set ::wb_toggle {}

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

proc display32 {value} {
  set word [word64 $value]
  if {$word < 0} { return $value }
  return [format %08X [expr {$word & 0xffffffff}]]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc field_bit {word bit_index} {
  if {$word < 0} { return INVALID }
  return [expr {($word >> $bit_index) & 1}]
}

proc field_byte {word bit_index} {
  if {$word < 0} { return INVALID }
  return [format %02X [expr {($word >> $bit_index) & 0xff}]]
}

proc live_not {word bit_index} {
  set value [field_bit $word $bit_index]
  if {$value eq "INVALID"} { return INVALID }
  return [expr {1 - $value}]
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

proc read_one {hardware_name sample elapsed_ms} {
  set reset_raw [probe_read 27]
  set reset_word [word64 $reset_raw]
  set cpu_debug_raw [probe_read 2]
  set cpu_debug_word [word64 $cpu_debug_raw]
  set sync_raw [probe_read 0]
  set sync_word [word64 $sync_raw]
  set entry_raw [probe_read 26]
  set entry_word [word64 $entry_raw]

  if {$entry_word < 0} {
    set boot_generation INVALID
  } else {
    set boot_generation [format %08X [expr {($entry_word >> 32) & 0xffffffff}]]
  }

  set persistent_mode_stage [wb_read $hardware_name 0x00100B74]
  set persistent_lock_wait [wb_read $hardware_name 0x00100B78]
  set persistent_spll_stage [wb_read $hardware_name 0x00100B90]
  set persistent_command_stage [wb_read $hardware_name 0x00100BA0]
  set persistent_command_generation [wb_read $hardware_name 0x00100BB4]
  set cpu_reset_live [field_bit $cpu_debug_word 32]
  set wr_core_reset_live [live_not $cpu_debug_word 36]
  set external_reset_live [live_not $cpu_debug_word 35]
  set si_config_done_live [field_bit $cpu_debug_word 37]
  set sys_pll_lock_live [field_bit $cpu_debug_word 38]
  if {$cpu_reset_live eq "INVALID" || $wr_core_reset_live eq "INVALID"} {
    set software_reset_live INVALID
  } else {
    set software_reset_live [expr {$cpu_reset_live && !$wr_core_reset_live}]
  }

  puts [format "RESET_STICKY_SAMPLE board=%s sample=%03d elapsed_ms=%d RESET_RAW=%s ARMED=%s CPU_RESET_SEEN=%s WR_CORE_RESET_SEEN=%s EXTERNAL_RESET_SEEN=%s SI_CONFIG_DONE_DROP_SEEN=%s SYS_PLL_LOCK_DROP_SEEN=%s SOFTWARE_RESET_SEEN=%s PHY_RESET_SEEN=%s WR_READY_DROP_SEEN=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s EXTERNAL_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s SYS_PLL_DROP_COUNT=%s SOFTWARE_RESET_COUNT=%s CPU_RESET_LIVE=%s WR_CORE_RESET_LIVE=%s EXTERNAL_RESET_LIVE=%s SI_CONFIG_DONE_LIVE=%s SYS_PLL_LOCK_LIVE=%s SOFTWARE_RESET_LIVE=%s CPU_PC=%s PERSIST_BOOT_GENERATION=%s PERSIST_MODE_MASTER_STAGE=%s PERSIST_LOCK_WAIT_SUBSTAGE=%s PERSIST_SPLL_CHECK_LOCK_STAGE=%s PERSIST_CMD_STAGE=%s PERSIST_CMD_BOOT_GENERATION=%s SYNC_RAW=%s" \
    $hardware_name $sample $elapsed_ms [display64 $reset_raw] \
    [field_bit $reset_word 0] [field_bit $reset_word 1] [field_bit $reset_word 2] \
    [field_bit $reset_word 3] [field_bit $reset_word 4] [field_bit $reset_word 5] \
    [field_bit $reset_word 6] [field_bit $reset_word 7] [field_bit $reset_word 8] \
    [field_byte $reset_word 16] [field_byte $reset_word 24] \
    [field_byte $reset_word 32] [field_byte $reset_word 40] \
    [field_byte $reset_word 48] [field_byte $reset_word 56] \
    $cpu_reset_live $wr_core_reset_live $external_reset_live \
    $si_config_done_live $sys_pll_lock_live $software_reset_live \
    [display32 $cpu_debug_raw] \
    $boot_generation [display32 $persistent_mode_stage] \
    [display32 $persistent_lock_wait] [display32 $persistent_spll_stage] \
    [display32 $persistent_command_stage] \
    [display32 $persistent_command_generation] [display64 $sync_raw]]
  flush stdout
}

puts [format "RESET_STICKY_CONFIG samples=%d gap_ms=%d probe=27 read_only=1 cpu_hold=0 cpu_release=0 cpu_reset_write=0" $samples $gap_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== RESET_STICKY_BOARD ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_one $hardware_name $sample [expr {[clock milliseconds] - $start_ms}]
      if {$sample < $samples} { after $gap_ms }
    }
  } error_message]} {
    puts "RESET_STICKY_ERROR board=${hardware_name} message=${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "RESET_STICKY_DONE"
