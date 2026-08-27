# Passive boot-generation monitor for EXP-WRPC-STEP4-PASSIVE-BOOT-GENERATION-NO-CPU-HOLD.
#
# This script only calls read_probe_data.  It does not issue write_source_data,
# does not access the Wishbone mailbox, and never asserts CPU_RESET through the
# CPU CSR.  Probe 26 is the fixed pre-CRT entry snapshot:
#   [31:0]  P_AT_ENTRY_LATEST
#   [63:32] BOOT_GENERATION
# Probe 2 carries the CPU/top-level reset and clock status:
#   [32] CPU_RESET, [35] CPU_RESET_n, [36] wr_core_reset_n,
#   [37] si_config_done, [38] clk_sys_625_locked
# Probe 0 independently carries CPU_RESET_n at bit 15 and si_config_done at
# bit 0.  Those duplicate fields are printed to make the passive evidence
# self-checking.
#
# Usage: quartus_stp -t read_passive_boot_generation_no_cpu_hold.tcl
#        ?gap_ms?

package require ::quartus::insystem_source_probe

set gap_ms 5000
if {[llength $argv] >= 1} {
  set gap_ms [expr {int([lindex $argv 0])}]
}
if {$gap_ms < 0} {
  error "gap_ms must be >= 0"
}

proc read_word {instance_index} {
  if {[catch {set value [read_probe_data -instance_index $instance_index -value_in_hex]} error_message]} {
    return "ERROR:$error_message"
  }
  if {![regexp {^[0-9A-Fa-f]{1,16}$} $value]} {
    return "INVALID:$value"
  }
  scan $value %x word
  return [format %016X $word]
}

proc sample {sample_index elapsed_ms} {
  set status_raw [read_word 0]
  set cpu_raw [read_word 2]
  set entry_raw [read_word 26]

  if {[string match {ERROR:*} $status_raw] ||
      [string match {INVALID:*} $status_raw] ||
      [string match {ERROR:*} $cpu_raw] ||
      [string match {INVALID:*} $cpu_raw] ||
      [string match {ERROR:*} $entry_raw] ||
      [string match {INVALID:*} $entry_raw]} {
    puts [format "PASSIVE_SAMPLE index=%02d elapsed_ms=%d valid=0 STATUS=%s CPU=%s ENTRY=%s" \
      $sample_index $elapsed_ms $status_raw $cpu_raw $entry_raw]
    flush stdout
    return
  }

  scan $status_raw %x status_word
  scan $cpu_raw %x cpu_word
  scan $entry_raw %x entry_word

  set cpu_reset_n_status [expr {($status_word >> 15) & 1}]
  set si_config_done_status [expr {$status_word & 1}]
  set cpu_reset [expr {($cpu_word >> 32) & 1}]
  set cpu_reset_n [expr {($cpu_word >> 35) & 1}]
  set wr_core_reset_n [expr {($cpu_word >> 36) & 1}]
  set si_config_done [expr {($cpu_word >> 37) & 1}]
  set clk_sys_625_locked [expr {($cpu_word >> 38) & 1}]
  set p_at_entry_latest [expr {$entry_word & 0xffffffff}]
  set boot_generation [expr {($entry_word >> 32) & 0xffffffff}]

  puts [format "PASSIVE_SAMPLE index=%02d elapsed_ms=%d valid=1 BOOT_GENERATION=%08X P_AT_ENTRY_LATEST=%08X CPU_RESET=%d CPU_RESET_n=%d/%d wr_core_reset_n=%d si_config_done=%d/%d clk_sys_625_locked=%d STATUS_RAW=%016X CPU_RAW=%016X ENTRY_RAW=%016X" \
    $sample_index $elapsed_ms $boot_generation $p_at_entry_latest $cpu_reset \
    $cpu_reset_n $cpu_reset_n_status $wr_core_reset_n $si_config_done \
    $si_config_done_status $clk_sys_625_locked $status_word $cpu_word $entry_word]
  flush stdout
}

puts [format "PASSIVE_CONFIG gap_ms=%d samples=0,%d,%d,%d,%d read_only=1 cpu_hold_release=0 cpu_reset_write=0" \
  $gap_ms $gap_ms [expr {2 * $gap_ms}] [expr {4 * $gap_ms}] [expr {6 * $gap_ms}]]
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} {
    puts "${hardware_name}: no device"
    continue
  }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  puts "device: ${device_name}"
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe \
      -hardware_name $hardware_name \
      -device_name $device_name
    sample 0 0
    after $gap_ms
    sample 1 $gap_ms
    after $gap_ms
    sample 2 [expr {2 * $gap_ms}]
    after [expr {2 * $gap_ms}]
    sample 3 [expr {4 * $gap_ms}]
    after [expr {2 * $gap_ms}]
    sample 4 [expr {6 * $gap_ms}]
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
