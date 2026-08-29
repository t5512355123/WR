# Read-only Step 5 boundary correlation.
#
# This decoder reuses the fixed-SOF observability already present in the
# diagnostic image.  It does not write the VUART, PHY, SoftPLL, DCO, or
# SI5340 control paths.  The only source write below is a Wishbone mailbox
# read request, matching the existing diagnostic readers.
#
# DCO probe 8 (si5340a_controller_dco.v):
#   [2:0]   rt_state
#   [3]     bus_state
#   [4]     bus_done
#   [5]     static_controller_ready
#   [6]     dpll_pending
#   [7]     hpll_pending
#   [8]     dpll_prev_valid
#   [9]     hpll_prev_valid
#   [10]    rt_select_dpll
#   [11]    rt_dir
#   [12]    dpll_dir
#   [13]    hpll_dir
#   [14]    runtime_start
#   [15]    bus_enable
#   [16]    iDPLL_LOAD
#   [17]    iHPLL_LOAD
#   [18]    dco_error
#   [19]    DCO_BUSY
#   [35:20] dco_step_count
#   [51:36] dpll_prev_data
#   [52]    reserved
#   [63:53] hpll_prev_data[10:0]
#
# Correlation probes 28..33:
#   28: T_DAC_LOAD, T_RUNTIME_START
#   29: T_BUS_DONE, T_STATIC_DONE_PULSE
#   30: T_STATIC_STATE_LEAVE_ZERO, T_STATIC_READY_DROP
#   31: T_SI_CONFIG_DROP, T_WR_CORE_RESET_ASSERT
#   32: T_CPU_RESET_ASSERT, T_SYSTEM_START_SEEN
#   33: static transition/live state flags
# Reset sticky probe 27 is included as a reset/drop cross-check.
#
# Usage:
#   quartus_stp -t read_step5_hpll_pending_correlation.tcl ?samples? ?gap_ms?

package require ::quartus::insystem_source_probe

set samples 120
set gap_ms 1000
set poll_attempts 25
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

array set ::wb_toggle {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word64 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  # Quartus Tcl may return a 64-bit probe word as a signed wide integer.
  # Normalize valid words with bit 63 set to a positive Tcl bignum so the
  # field decoders do not confuse them with the INVALID sentinel.
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

proc field32 {word shift} {
  if {$word < 0} { return INVALID }
  return [format %08X [expr {($word >> $shift) & 0xffffffff}]]
}

proc field_byte {word shift} {
  if {$word < 0} { return INVALID }
  return [format %02X [expr {($word >> $shift) & 0xff}]]
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

proc emit_sample {hardware_name sample elapsed_ms} {
  set sync_raw [probe_read 0]
  set dco_raw [probe_read 8]
  set corr0_raw [probe_read 28]
  set corr1_raw [probe_read 29]
  set corr2_raw [probe_read 30]
  set corr3_raw [probe_read 31]
  set corr4_raw [probe_read 32]
  set corr5_raw [probe_read 33]
  set reset_raw [probe_read 27]
  set helper_error [wb_read $hardware_name 0x00100AD8]
  set helper_output [wb_read $hardware_name 0x00100ADC]
  set dco_word [word64 $dco_raw]
  set corr0_word [word64 $corr0_raw]
  set corr1_word [word64 $corr1_raw]
  set corr2_word [word64 $corr2_raw]
  set corr3_word [word64 $corr3_raw]
  set corr4_word [word64 $corr4_raw]
  set corr5_word [word64 $corr5_raw]

  set fields [list \
    STEP5_HPLL_PENDING_SAMPLE \
    [format "board=%s" $hardware_name] \
    [format "sample=%03d" $sample] \
    [format "elapsed_ms=%d" $elapsed_ms] \
    [format "DCO_RAW=%s" [display64 $dco_raw]] \
    [format "RT_STATE=%s" [field_bits $dco_word 0 0x7]] \
    [format "BUS_STATE=%s" [field_bit $dco_word 3]] \
    [format "BUS_DONE=%s" [field_bit $dco_word 4]] \
    [format "STATIC_READY=%s" [field_bit $dco_word 5]] \
    [format "DPLL_PENDING=%s" [field_bit $dco_word 6]] \
    [format "HPLL_PENDING=%s" [field_bit $dco_word 7]] \
    [format "DPLL_PREV_VALID=%s" [field_bit $dco_word 8]] \
    [format "HPLL_PREV_VALID=%s" [field_bit $dco_word 9]] \
    [format "RT_SELECT_DPLL=%s" [field_bit $dco_word 10]] \
    [format "RT_DIR=%s" [field_bit $dco_word 11]] \
    [format "DPLL_DIR=%s" [field_bit $dco_word 12]] \
    [format "HPLL_DIR=%s" [field_bit $dco_word 13]] \
    [format "RUNTIME_START=%s" [field_bit $dco_word 14]] \
    [format "BUS_ENABLE=%s" [field_bit $dco_word 15]] \
    [format "DPLL_LOAD=%s" [field_bit $dco_word 16]] \
    [format "HPLL_LOAD=%s" [field_bit $dco_word 17]] \
    [format "DCO_ERROR=%s" [field_bit $dco_word 18]] \
    [format "DCO_BUSY=%s" [field_bit $dco_word 19]] \
    [format "STEP=%s" [field_bits $dco_word 20 0xffff]] \
    [format "DPLL_PREV_DATA=%s" [field_bits $dco_word 36 0xffff]] \
    [format "HPLL_PREV_DATA_LOW11=%s" [field_bits $dco_word 53 0x7ff]] \
    [format "T_DAC_LOAD=%s" [field32 $corr0_word 0]] \
    [format "T_RUNTIME_START=%s" [field32 $corr0_word 32]] \
    [format "T_BUS_DONE=%s" [field32 $corr1_word 0]] \
    [format "T_STATIC_DONE=%s" [field32 $corr1_word 32]] \
    [format "T_STATE_LEAVE_ZERO=%s" [field32 $corr2_word 0]] \
    [format "T_READY_DROP=%s" [field32 $corr2_word 32]] \
    [format "T_SI_CONFIG_DROP=%s" [field32 $corr3_word 0]] \
    [format "T_WR_CORE_RESET=%s" [field32 $corr3_word 32]] \
    [format "T_CPU_RESET=%s" [field32 $corr4_word 0]] \
    [format "T_SYSTEM_START=%s" [field32 $corr4_word 32]] \
    [format "STATIC_BEFORE=%s" [field_byte $corr5_word 0]] \
    [format "STATIC_AFTER=%s" [field_byte $corr5_word 8]] \
    [format "STATIC_CURRENT=%s" [field_byte $corr5_word 16]] \
    [format "POST_ARMED=%s" [field_bit $corr5_word 24]] \
    [format "SI_CONFIG_DONE=%s" [field_bit $corr5_word 25]] \
    [format "WR_CORE_RESET_N=%s" [field_bit $corr5_word 26]] \
    [format "CPU_RESET=%s" [field_bit $corr5_word 27]] \
    [format "LIVE_RUNTIME_START=%s" [field_bit $corr5_word 28]] \
    [format "LIVE_BUS_DONE=%s" [field_bit $corr5_word 29]] \
    [format "LIVE_STATIC_DONE=%s" [field_bit $corr5_word 30]] \
    [format "STATIC_ACCESS_START=%s" [field_bit $corr5_word 31]] \
    [format "RUNTIME_STATE_LIVE=%s" [field_bits $corr5_word 32 0x7]] \
    [format "BUS_STATE_LIVE=%s" [field_bit $corr5_word 35]] \
    [format "RUNTIME_BUS_ENABLE=%s" [field_bit $corr5_word 36]] \
    [format "SYSTEM_START_LIVE=%s" [field_bit $corr5_word 37]] \
    [format "RESET_STICKY_RAW=%s" [display64 $reset_raw]] \
    [format "SYNC_RAW=%s" [display64 $sync_raw]] \
    [format "HELPER_ERROR=%s" $helper_error] \
    [format "HELPER_ERROR_SIGNED=%s" [signed32 $helper_error]] \
    [format "HELPER_OUTPUT=%s" $helper_output]]
  puts [join $fields " "]
  flush stdout
}

puts [format "STEP5_HPLL_PENDING_CORRELATION_CONFIG samples=%d gap_ms=%d experiment=EXP-WRPC-STEP5-HPLL-PENDING-CORRELATION-20260829 fixed_sof=1 read_only=1" $samples $gap_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== STEP5_HPLL_PENDING_BOARD %s ===" $hardware_name]
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      emit_sample $hardware_name $sample [expr {[clock milliseconds] - $start_ms}]
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
  } error_message]} {
    puts [format "STEP5_HPLL_PENDING_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "STEP5_HPLL_PENDING_CORRELATION_DONE"
