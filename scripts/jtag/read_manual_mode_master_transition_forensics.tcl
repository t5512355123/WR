# Read-only capture for a single manual `mode master` transition.
#
# The script is intended to run while the command is sent once through the
# virtual UART. It never writes a WR/PHY/SoftPLL/reset register and never
# holds or releases the CPU. Wishbone mailbox transactions below are reads.
#
# Probe 26: [63:32] BOOT_GENERATION, [31:0] P_AT_ENTRY_LATEST.
# Private WDIAGS 0x158 (CPU address 0x00100B58): sticky mode-master stage.
#   0 not entered, 1 entered, 2 before spll_init, 3 after spll_init,
#   4 before lock wait, 5 after lock-wait return.
# Private WDIAGS 0x15c..0x16c (CPU addresses 0x00100B5C..0x00100B6C):
#   lock-wait substage, iteration count, start tics, current tics,
#   last spll_check_lock result.
# Persistent .debug_precrt words are republished in dedicated read-only
# WDIAGS offsets 0x170..0x18c (CPU addresses 0x00100B70..0x00100B8C):
#   magic, mode-master stage, lock-wait substage, boot generation at stage,
#   and the four-entry stage history. These reads do not hold the CPU.
# Persistent spll_check_lock(0) markers are at offsets 0x190..0x19c
# (CPU addresses 0x00100B90..0x00100B9C).
# Persistent VUART-to-shell command breadcrumbs are at offsets 0x1a0..0x1b4
# (CPU addresses 0x00100BA0..0x00100BB4): stage, RX byte count, last byte,
# command length, FNV-1a hash and boot generation at the last stage.
# Persistent trap/fault breadcrumbs are at offsets 0x1b8..0x1dc (CPU addresses
# 0x00100BB8..0x00100BDC): validity magic, count, mcause, mepc, mbadaddr,
# interrupted RA/SP, boot generation and last mode/SPLL stages.
#
# Optional fourth argument injects the single command through the JTAG
# Wishbone virtual-UART HOST_TDR at the selected Master sample. This is a
# test stimulus, not a WR/PHY/SoftPLL/reset write; the capture remains passive
# before and after the one command injection.
#
# Usage:
#   quartus_stp -t read_manual_mode_master_transition_forensics.tcl
#       ?samples? ?gap_ms? ?poll_attempts? ?inject_sample?

package require ::quartus::insystem_source_probe

set samples 60
set gap_ms 250
set poll_attempts 25
set inject_sample 0
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set poll_attempts [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set inject_sample [expr {int([lindex $argv 3])}] }
if {$samples <= 0 || $gap_ms < 0 || $poll_attempts <= 0 || $inject_sample < 0} {
  error "samples > 0, gap_ms >= 0, poll_attempts > 0, inject_sample >= 0 required"
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

proc word32 {value} {
  set word [word64 $value]
  if {$word < 0} { return -1 }
  return [expr {$word & 0xffffffff}]
}

proc display64 {value} {
  set word [word64 $value]
  if {$word < 0} { return $value }
  return [format %016X $word]
}

proc display32 {value} {
  set word [word32 $value]
  if {$word < 0} { return $value }
  return [format %08X $word]
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

proc inject_mode_master {hardware_name sample} {
  set command "mode master\n"
  set index 0
  foreach character [split $command ""] {
    scan $character %c byte
    set result [wb_write $hardware_name 0x00100510 $byte]
    puts [format "VUART_INJECT board=%s sample=%03d index=%02d BYTE=0x%02X WB_RESULT=%s" \
      $hardware_name $sample $index $byte $result]
    incr index
  }
  flush stdout
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

proc read_sample {hardware_name sample elapsed_ms} {
  set status [probe_read 0]
  set entry [probe_read 26]
  set entry_word [word64 $entry]
  if {$entry_word < 0} {
    set boot_generation INVALID
    set p_at_entry INVALID
  } else {
    set boot_generation [format %08X [expr {($entry_word >> 32) & 0xffffffff}]]
    set p_at_entry [format %08X [expr {$entry_word & 0xffffffff}]]
  }
  set stage [wb_read $hardware_name 0x00100B58]
  set ptp [wb_read $hardware_name 0x00100A10]
  set ptp_meta [wb_read $hardware_name 0x00100A5C]
  set spll_state [wb_read $hardware_name 0x00100AA0]
  set lock_enable [wb_read $hardware_name 0x00100A9C]
  set eic_isr [wb_read $hardware_name 0x0010026C]
  set tag_valid [wb_read $hardware_name 0x00100284]
  set trr_write [wb_read $hardware_name 0x00100288]
  set trr_pop [wb_read $hardware_name 0x00100B54]
  set irq_count [wb_read $hardware_name 0x00100AEC]
  set helper_update [wb_read $hardware_name 0x00100B18]
  set ptp_rx [wb_read $hardware_name 0x00100A54]
  set ptp_tx [wb_read $hardware_name 0x00100A58]
  set lock_wait_substage [wb_read $hardware_name 0x00100B5C]
  set lock_wait_iteration [wb_read $hardware_name 0x00100B60]
  set lock_wait_start_tics [wb_read $hardware_name 0x00100B64]
  set lock_wait_current_tics [wb_read $hardware_name 0x00100B68]
  set lock_wait_last_result [wb_read $hardware_name 0x00100B6C]
  set persistent_magic [wb_read $hardware_name 0x00100B70]
  set persistent_stage [wb_read $hardware_name 0x00100B74]
  set persistent_lock_wait_substage [wb_read $hardware_name 0x00100B78]
  set persistent_generation [wb_read $hardware_name 0x00100B7C]
  set persistent_history0 [wb_read $hardware_name 0x00100B80]
  set persistent_history1 [wb_read $hardware_name 0x00100B84]
  set persistent_history2 [wb_read $hardware_name 0x00100B88]
  set persistent_history3 [wb_read $hardware_name 0x00100B8C]
  set persistent_spll_check_lock_stage [wb_read $hardware_name 0x00100B90]
  set persistent_spll_check_lock_channel [wb_read $hardware_name 0x00100B94]
  set persistent_spll_check_lock_state [wb_read $hardware_name 0x00100B98]
  set persistent_spll_check_lock_generation [wb_read $hardware_name 0x00100B9C]
  set persistent_command_stage [wb_read $hardware_name 0x00100BA0]
  set persistent_command_rx_byte_count [wb_read $hardware_name 0x00100BA4]
  set persistent_command_last_byte [wb_read $hardware_name 0x00100BA8]
  set persistent_command_length [wb_read $hardware_name 0x00100BAC]
  set persistent_command_hash [wb_read $hardware_name 0x00100BB0]
  set persistent_command_generation [wb_read $hardware_name 0x00100BB4]
  set persistent_fault_magic [wb_read $hardware_name 0x00100BB8]
  set persistent_fault_count [wb_read $hardware_name 0x00100BBC]
  set persistent_fault_mcause [wb_read $hardware_name 0x00100BC0]
  set persistent_fault_mepc [wb_read $hardware_name 0x00100BC4]
  set persistent_fault_mtval [wb_read $hardware_name 0x00100BC8]
  set persistent_fault_ra [wb_read $hardware_name 0x00100BCC]
  set persistent_fault_sp [wb_read $hardware_name 0x00100BD0]
  set persistent_fault_generation [wb_read $hardware_name 0x00100BD4]
  set persistent_fault_mode_stage [wb_read $hardware_name 0x00100BD8]
  set persistent_fault_spll_stage [wb_read $hardware_name 0x00100BDC]

  puts [format "FORENSICS_SAMPLE board=%s sample=%03d elapsed_ms=%d STATUS=%s ENTRY_RAW=%s BOOT_GENERATION=%s P_AT_ENTRY_LATEST=%s MODE_MASTER_STAGE=%s LOCK_WAIT_SUBSTAGE=%s LOCK_WAIT_ITERATION=%s LOCK_WAIT_START_TICS=%s LOCK_WAIT_CURRENT_TICS=%s LOCK_WAIT_LAST_LOCK_RESULT=%s PERSIST_MAGIC=%s PERSIST_MODE_MASTER_STAGE=%s PERSIST_LOCK_WAIT_SUBSTAGE=%s PERSIST_BOOT_GENERATION_AT_STAGE=%s PERSIST_STAGE_HISTORY0=%s PERSIST_STAGE_HISTORY1=%s PERSIST_STAGE_HISTORY2=%s PERSIST_STAGE_HISTORY3=%s PERSIST_SPLL_CHECK_LOCK_STAGE=%s PERSIST_SPLL_CHECK_LOCK_CHANNEL=%s PERSIST_SPLL_CHECK_LOCK_STATE=%s PERSIST_SPLL_CHECK_LOCK_BOOT_GENERATION=%s PERSIST_CMD_STAGE=%s PERSIST_CMD_RX_BYTE_COUNT=%s PERSIST_CMD_LAST_BYTE=%s PERSIST_CMD_LENGTH=%s PERSIST_CMD_HASH=%s PERSIST_CMD_BOOT_GENERATION=%s PERSIST_FAULT_MAGIC=%s PERSIST_FAULT_COUNT=%s PERSIST_FAULT_MCAUSE=%s PERSIST_FAULT_MEPC=%s PERSIST_FAULT_MTVAL=%s PERSIST_FAULT_RA=%s PERSIST_FAULT_SP=%s PERSIST_FAULT_BOOT_GENERATION=%s PERSIST_FAULT_LAST_MODE_MASTER_STAGE=%s PERSIST_FAULT_LAST_SPLL_CHECK_LOCK_STAGE=%s PTP=%s PTP_META=%s SPLL_STATE=%s LOCK_ENABLE=%s EIC_ISR=%s TAG_VALID=%s TRR_WRITE=%s TRR_POP=%s IRQ_COUNT=%s HELPER_UPDATE=%s PTP_RX=%s PTP_TX=%s" \
    $hardware_name $sample $elapsed_ms [display32 $status] [display64 $entry] \
    $boot_generation $p_at_entry \
    [display32 $stage] [display32 $lock_wait_substage] [display32 $lock_wait_iteration] \
    [display32 $lock_wait_start_tics] [display32 $lock_wait_current_tics] \
    [display32 $lock_wait_last_result] [display32 $persistent_magic] \
    [display32 $persistent_stage] [display32 $persistent_lock_wait_substage] \
    [display32 $persistent_generation] [display32 $persistent_history0] \
    [display32 $persistent_history1] [display32 $persistent_history2] \
    [display32 $persistent_history3] [display32 $persistent_spll_check_lock_stage] \
    [display32 $persistent_spll_check_lock_channel] \
    [display32 $persistent_spll_check_lock_state] \
    [display32 $persistent_spll_check_lock_generation] \
    [display32 $persistent_command_stage] \
    [display32 $persistent_command_rx_byte_count] \
    [display32 $persistent_command_last_byte] \
    [display32 $persistent_command_length] \
    [display32 $persistent_command_hash] \
    [display32 $persistent_command_generation] \
    [display32 $persistent_fault_magic] [display32 $persistent_fault_count] \
    [display32 $persistent_fault_mcause] [display32 $persistent_fault_mepc] \
    [display32 $persistent_fault_mtval] [display32 $persistent_fault_ra] \
    [display32 $persistent_fault_sp] [display32 $persistent_fault_generation] \
    [display32 $persistent_fault_mode_stage] [display32 $persistent_fault_spll_stage] \
    [display32 $ptp] \
    [display32 $ptp_meta] \
    [display32 $spll_state] [display32 $lock_enable] [display32 $eic_isr] \
    [display32 $tag_valid] [display32 $trr_write] [display32 $trr_pop] \
    [display32 $irq_count] [display32 $helper_update] [display32 $ptp_rx] \
    [display32 $ptp_tx]]
  flush stdout
}

puts [format "FORENSICS_CONFIG samples=%d gap_ms=%d poll_attempts=%d manual_command=mode_master_once inject_sample=%d inject_via_jtag_vuart=%d read_only_before_after=1 cpu_hold_release=0 cpu_reset_write=0" \
  $samples $gap_ms $poll_attempts $inject_sample [expr {$inject_sample > 0}]]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== FORENSICS_BOARD ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set elapsed [expr {[clock milliseconds] - $start_ms}]
      read_sample $hardware_name $sample $elapsed
      if {$inject_sample > 0 && $sample == $inject_sample &&
          [string first "1-11.1" $hardware_name] >= 0} {
        inject_mode_master $hardware_name $sample
      }
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
  } error_message]} {
    puts [format "FORENSICS_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "FORENSICS_DONE"
