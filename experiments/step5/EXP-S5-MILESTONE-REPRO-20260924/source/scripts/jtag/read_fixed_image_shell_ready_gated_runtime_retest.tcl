# Fixed-image, shell-ready-gated runtime retest.
#
# This reader is intentionally passive until all of the following are true:
#   - the post-startup hardware arm is asserted;
#   - boot-init has returned for the current CPU boot generation;
#   - the firmware has reached the main loop and shell polling task;
#   - the three generation tags match the current boot generation; and
#   - the combined gate remains true for the configured stable interval.
#
# Only the Master cable receives one VUART command: "mode master\n".
# The Slave is a no-stimulus control capture. No CPU hold/release or reset
# operation is performed by this reader.
#
# WDIAGS firmware shell-ready gate: ASTAT (0x14) high reserved bits:
#   bit 21 FIRMWARE_MAIN_LOOP_REACHED
#   bit 22 SHELL_POLL_LOOP_REACHED
#   bit 23 BOOT_INIT_SEQUENCE_DONE
#   bit 24 FIRMWARE_SHELL_READY
#   bits 25..31 current boot generation (7 bits)
#
# Usage:
#   quartus_stp -t read_fixed_image_shell_ready_gated_runtime_retest.tcl
#       ?ready_timeout_ms? ?stable_ms? ?passive_samples? ?gap_ms? ?poll_attempts?

set ready_timeout_ms 30000
set stable_ms 1500
set passive_samples 180
set gap_ms 200
set poll_attempts 25
set ::n1_audit_only 0
set ::n1_selftest 0
set ::n1_positional {}
foreach arg $argv {
  if {$arg eq "--audit-only"} {
    set ::n1_audit_only 1
  } elseif {$arg eq "--selftest"} {
    set ::n1_selftest 1
  } elseif {[string match "--*" $arg]} {
    error "unknown option: $arg"
  } else {
    lappend ::n1_positional $arg
  }
}
if {[llength $::n1_positional] >= 1} { set ready_timeout_ms [expr {int([lindex $::n1_positional 0])}] }
if {[llength $::n1_positional] >= 2} { set stable_ms [expr {int([lindex $::n1_positional 1])}] }
if {[llength $::n1_positional] >= 3} { set passive_samples [expr {int([lindex $::n1_positional 2])}] }
if {[llength $::n1_positional] >= 4} { set gap_ms [expr {int([lindex $::n1_positional 3])}] }
if {[llength $::n1_positional] >= 5} { set poll_attempts [expr {int([lindex $::n1_positional 4])}] }
if {$ready_timeout_ms <= 0 || $stable_ms <= 0 || $passive_samples <= 0 ||
    $gap_ms < 0 || $poll_attempts <= 0} {
  error "ready_timeout_ms > 0, stable_ms > 0, passive_samples > 0, gap_ms >= 0, poll_attempts > 0 required"
}

# N1 startup-contract helpers are defined before the Quartus package so the
# selftest can run on a normal Tcl interpreter.  They deliberately distinguish
# readiness from control eligibility and fail closed without an owner/version
# contract for the producer bank.
proc n1_decide_readiness {schema_valid owner_valid epoch_stable current_generation \
                           main_marker_gen shell_marker_gen boot_marker_gen \
                           main_reached shell_poll_reached boot_init_done shell_ready \
                           runtime_history_empty} {
  if {!$schema_valid || !$owner_valid || !$epoch_stable ||
      $current_generation < 0 || $main_marker_gen < 0 ||
      $shell_marker_gen < 0 || $boot_marker_gen < 0} {
    return [dict create status UNKNOWN reason BANK_SCHEMA_UNPROVEN control_eligible 0]
  }
  set generation_match [expr {$main_marker_gen == $current_generation &&
    $shell_marker_gen == $current_generation &&
    $boot_marker_gen == $current_generation}]
  set marker_ready [expr {$main_reached == 1 && $shell_poll_reached == 1 &&
    $boot_init_done == 1 && $shell_ready == 1}]
  if {!$generation_match} {
    return [dict create status NOT_READY reason GENERATION_MISMATCH control_eligible 0]
  }
  if {!$marker_ready} {
    return [dict create status NOT_READY reason MARKER_INCOMPLETE control_eligible 0]
  }
  if {!$runtime_history_empty} {
    return [dict create status READY reason NO_POST_ARM_RUNTIME_HISTORY control_eligible 0]
  }
  return [dict create status READY reason VERIFIED_SCHEMA control_eligible 1]
}

proc n1_classify_tail {words} {
  if {[llength $words] != 7} { return UNKNOWN }
  set first [lindex $words 0]
  if {$first eq "5752534C" || $first eq "5752534c"} {
    return SLOCK_TRACE
  }
  # This historical shape is only a candidate overlay/re-init explanation;
  # it must never be promoted to readiness based on values alone.
  if {$first eq "00000004" && [lindex $words 1] eq "00000002" &&
      [lindex $words 2] eq "00000001" && [lindex $words 3] eq "000004D9" &&
      [lindex $words 4] eq "00000000" && [lindex $words 5] eq "00000001" &&
      [lindex $words 6] eq "00000000"} {
    return SPLL_REINIT_OR_OVERLAY_CANDIDATE
  }
  return UNKNOWN
}

proc n1_selftest_expect {name condition} {
  if {!$condition} {
    puts "N1_SELFTEST_FAIL case=$name"
    incr ::n1_selftest_failures
  } else {
    puts "N1_SELFTEST_PASS case=$name"
  }
}

proc n1_run_selftest {} {
  set ::n1_selftest_failures 0
  set legacy_words {00000004 00000002 00000001 000004D9 00000000 00000001 00000000}
  set legacy_schema [n1_classify_tail $legacy_words]
  set legacy_decision [n1_decide_readiness 0 0 1 1 1 1 1 1 1 1 1 1]
  puts "N1_SELFTEST_CASE name=legacy-seven-word-fixture BANK_SCHEMA=$legacy_schema READINESS=[dict get $legacy_decision status] INJECTION_COUNT=0"
  n1_selftest_expect legacy-seven-word-fixture [expr {$legacy_schema eq "SPLL_REINIT_OR_OVERLAY_CANDIDATE" &&
    [dict get $legacy_decision status] eq "UNKNOWN"}]

  set ready_decision [n1_decide_readiness 1 1 1 1 1 1 1 1 1 1 1 1]
  puts "N1_SELFTEST_CASE name=verified-readiness STATUS=[dict get $ready_decision status] CONTROL_ELIGIBLE=[dict get $ready_decision control_eligible] INJECTION_COUNT=0"
  n1_selftest_expect verified-readiness [expr {[dict get $ready_decision status] eq "READY" &&
    [dict get $ready_decision control_eligible] == 1}]

  set mismatch_decision [n1_decide_readiness 1 1 1 1 0 1 1 1 1 1 1 1]
  puts "N1_SELFTEST_CASE name=generation-mismatch STATUS=[dict get $mismatch_decision status] REASON=[dict get $mismatch_decision reason] INJECTION_COUNT=0"
  n1_selftest_expect generation-mismatch [expr {[dict get $mismatch_decision status] eq "NOT_READY" &&
    [dict get $mismatch_decision reason] eq "GENERATION_MISMATCH"}]

  set unknown_decision [n1_decide_readiness 1 0 1 1 1 1 1 1 1 1 1 1]
  puts "N1_SELFTEST_CASE name=owner-unproven STATUS=[dict get $unknown_decision status] REASON=[dict get $unknown_decision reason] INJECTION_COUNT=0"
  n1_selftest_expect owner-unproven [expr {[dict get $unknown_decision status] eq "UNKNOWN"}]

  set slock_schema [n1_classify_tail {5752534C 00000002 00000001 000004D9 00000000 00000001 00000000}]
  puts "N1_SELFTEST_CASE name=slock-overlay BANK_SCHEMA=$slock_schema READINESS=UNKNOWN INJECTION_COUNT=0"
  n1_selftest_expect slock-overlay [expr {$slock_schema eq "SLOCK_TRACE"}]

  set history_decision [n1_decide_readiness 1 1 1 1 1 1 1 1 1 1 1 0]
  puts "N1_SELFTEST_CASE name=runtime-history-nonzero STATUS=[dict get $history_decision status] REASON=[dict get $history_decision reason] CONTROL_ELIGIBLE=[dict get $history_decision control_eligible]"
  n1_selftest_expect runtime-history-nonzero [expr {[dict get $history_decision status] eq "READY" &&
    [dict get $history_decision control_eligible] == 0}]

  if {$::n1_selftest_failures != 0} {
    puts "N1_SELFTEST_RESULT=FAIL failures=$::n1_selftest_failures"
    return 1
  }
  puts "N1_SELFTEST_RESULT=PASS cases=6 injection_calls=0"
  return 0
}

if {$::n1_selftest} {
  exit [n1_run_selftest]
}

package require ::quartus::insystem_source_probe

array set ::wb_toggle {}
array set ::post_armed_live {}
array set ::live_gate {}
array set ::live_command_stage {}
array set ::live_mode_stage {}
array set ::live_lock_wait {}
array set ::live_spll_stage {}
array set ::live_boot_generation {}
array set ::live_cpu_pc {}
array set ::live_runtime_idle {}
array set ::live_shell_ready {}
array set ::live_readiness_status {}
array set ::live_readiness_reason {}
array set ::live_bank_schema {}
set ::n1_injection_count 0

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word64 {value} {
  if {![is_hex $value]} { return INVALID }
  scan $value %x word
  return $word
}

proc display64 {value} {
  set word [word64 $value]
  if {$word eq "INVALID"} { return $value }
  return [format %016X $word]
}

proc display32_from_word {word shift} {
  if {$word eq "INVALID"} { return INVALID }
  return [format %08X [expr {($word >> $shift) & 0xffffffff}]]
}

proc numeric32_from_word {word shift} {
  if {$word eq "INVALID"} { return -1 }
  return [expr {($word >> $shift) & 0xffffffff}]
}

proc field_bit {word bit_index} {
  if {$word eq "INVALID"} { return INVALID }
  return [expr {($word >> $bit_index) & 1}]
}

proc field_byte {word bit_index} {
  if {$word eq "INVALID"} { return INVALID }
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
  if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
    set ::wb_toggle($hardware_name) 0
    return
  }
  if {[is_hex $value]} {
    scan $value %x word
    set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc inject_mode_master {hardware_name sample} {
  if {$::n1_audit_only} {
    puts [format "N1_CONTROL_WRITE_BLOCKED board=%s sample=%03d reason=AUDIT_ONLY" \
      $hardware_name $sample]
    return
  }
  incr ::n1_injection_count
  set command "mode master\n"
  set index 0
  foreach character [split $command ""] {
    scan $character %c byte
    set result [wb_write $hardware_name 0x00100510 $byte]
    puts [format "SHELL_READY_GATED_INJECT board=%s sample=%03d index=%02d BYTE=0x%02X WB_RESULT=%s" \
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

  set mode_stage_raw [wb_read $hardware_name 0x00100B74]
  set lock_wait_raw [wb_read $hardware_name 0x00100B78]
  set spll_stage_raw [wb_read $hardware_name 0x00100B90]
  set command_stage_raw [wb_read $hardware_name 0x00100BA0]
  set shell_ready_astat_raw [wb_read $hardware_name 0x00100A14]
  set slock_magic_raw [wb_read $hardware_name 0x00100BE0]
  set slock_stage_raw [wb_read $hardware_name 0x00100BE4]
  set slock_retry_raw [wb_read $hardware_name 0x00100BE8]
  set slock_entry_tics_raw [wb_read $hardware_name 0x00100BEC]
  set slock_remaining_ms_raw [wb_read $hardware_name 0x00100BF0]
  set slock_poll_ret_raw [wb_read $hardware_name 0x00100BF4]
  set slock_wr_state_raw [wb_read $hardware_name 0x00100BF8]

  set entry_word [word64 $entry_raw]
  set reset_word [word64 $reset_raw]
  set cpu_word [word64 $cpu_raw]
  set corr7_post_armed [field_bit $corr7_word 33]
  set ::post_armed_live($hardware_name) $corr7_post_armed

  set boot_generation [numeric32_from_word $entry_word 32]
  set shell_ready_astat_word [word64 $shell_ready_astat_raw]
  set firmware_main [expr {$shell_ready_astat_word eq "INVALID" ? -1 : ($shell_ready_astat_word >> 21) & 1}]
  set shell_poll [expr {$shell_ready_astat_word eq "INVALID" ? -1 : ($shell_ready_astat_word >> 22) & 1}]
  set boot_done [expr {$shell_ready_astat_word eq "INVALID" ? -1 : ($shell_ready_astat_word >> 23) & 1}]
  set shell_ready [expr {$shell_ready_astat_word eq "INVALID" ? -1 : ($shell_ready_astat_word >> 24) & 1}]
  set shell_generation [expr {$shell_ready_astat_word eq "INVALID" ? -1 : ($shell_ready_astat_word >> 25) & 0x7f}]
  # These are intentionally not aliases of ASTAT_GENERATION.  The current
  # image exposes only the compact ASTAT mirror through this reader; the
  # independent RAM marker generations still need a verified address path.
  set firmware_main_gen UNKNOWN
  set shell_poll_gen UNKNOWN
  set boot_gen UNKNOWN
  set cpu_pc [numeric32_from_word $cpu_word 0]
  set cpu_reset [field_bit $corr5_word 27]
  set command_stage [numeric32_from_word [word64 $command_stage_raw] 0]
  set mode_stage [numeric32_from_word [word64 $mode_stage_raw] 0]
  set lock_wait [numeric32_from_word [word64 $lock_wait_raw] 0]
  set spll_stage [numeric32_from_word [word64 $spll_stage_raw] 0]

  set slock_words [list [display32_from_word [word64 $slock_magic_raw] 0] \
    [display32_from_word [word64 $slock_stage_raw] 0] \
    [display32_from_word [word64 $slock_retry_raw] 0] \
    [display32_from_word [word64 $slock_entry_tics_raw] 0] \
    [display32_from_word [word64 $slock_remaining_ms_raw] 0] \
    [display32_from_word [word64 $slock_poll_ret_raw] 0] \
    [display32_from_word [word64 $slock_wr_state_raw] 0]]
  set bank_schema [n1_classify_tail $slock_words]

  # The ASTAT compact mirror is useful raw evidence, but the current reader
  # cannot prove that it is accompanied by three independent, same-epoch
  # marker generations through a verified RAM path.  Therefore the live
  # readiness decision is UNKNOWN and the control gate is always closed in
  # N1.  Do not copy one ASTAT generation into three fields.
  set generation_match -1
  set marker_ready -1
  set readiness_status UNKNOWN
  set readiness_reason BANK_SCHEMA_UNPROVEN
  set readiness_control_eligible 0
  set gate 0

  set runtime_idle [expr {$corr0_word == 0 && $corr1_word == 0 &&
    $corr2_word == 0 && $corr3_word == 0 && $corr4_word == 0}]
  set ::live_gate($hardware_name) $gate
  set ::live_command_stage($hardware_name) $command_stage
  set ::live_mode_stage($hardware_name) $mode_stage
  set ::live_lock_wait($hardware_name) $lock_wait
  set ::live_spll_stage($hardware_name) $spll_stage
  set ::live_boot_generation($hardware_name) $boot_generation
  set ::live_cpu_pc($hardware_name) $cpu_pc
  set ::live_runtime_idle($hardware_name) $runtime_idle
  set ::live_shell_ready($hardware_name) $shell_ready
  set ::live_readiness_status($hardware_name) $readiness_status
  set ::live_readiness_reason($hardware_name) $readiness_reason
  set ::live_bank_schema($hardware_name) $bank_schema

  puts [format "SHELL_READY_GATED_SAMPLE board=%s sample=%03d elapsed_ms=%d DCO_RAW=%s CORR0_RAW=%s T_DAC_LOAD=%s T_RUNTIME_START=%s CORR1_RAW=%s T_BUS_DONE=%s T_STATIC_DONE_PULSE=%s CORR2_RAW=%s T_STATIC_STATE_LEAVE_ZERO=%s T_STATIC_READY_DROP=%s CORR3_RAW=%s T_SI_CONFIG_DROP=%s T_WR_CORE_RESET_ASSERT=%s CORR4_RAW=%s T_CPU_RESET_ASSERT=%s T_SYSTEM_START=%s CORR5_RAW=%s STATIC_CURRENT=%s POST_STARTUP_ARMED=%s CPU_RESET=%s CORR6_RAW=%s T_POST_STARTUP_ARM=%s STARTUP_SYSTEM_START_SEEN=%s CORR7_RAW=%s STARTUP_STATIC_COMPLETE_SEEN=%s STARTUP_READY_FINAL=%s POST_ARMED=%s MODE_STAGE=%s LOCK_WAIT_SUBSTAGE=%s SPLL_CHECK_LOCK_STAGE=%s PERSIST_CMD_STAGE=%s BOOT_GENERATION=%s CPU_PC=%s FIRMWARE_MAIN_LOOP_REACHED=%s SHELL_POLL_LOOP_REACHED=%s BOOT_INIT_SEQUENCE_DONE=%s FIRMWARE_SHELL_READY=%s FIRMWARE_MAIN_LOOP_GENERATION=%s SHELL_POLL_GENERATION=%s BOOT_INIT_GENERATION=%s ASTAT_GENERATION=%s GENERATION_MATCH=%s MARKER_READY=%s READINESS=%s READINESS_REASON=%s CONTROL_ELIGIBLE=%s BANK_SCHEMA=%s SLOCK_MAGIC_RAW=%s SLOCK_STAGE_RAW=%s SLOCK_RETRY_RAW=%s SLOCK_ENTRY_TICS_RAW=%s SLOCK_REMAINING_MS_RAW=%s SLOCK_POLL_RET_RAW=%s SLOCK_WR_STATE_RAW=%s GATE=%s RUNTIME_IDLE=%s RESET_RAW=%s SYNC_RAW=%s ENTRY_RAW=%s" \
    $hardware_name $sample $elapsed_ms [display64 $dco_raw] \
    [display64 $corr0_raw] [display32_from_word $corr0_word 0] \
    [display32_from_word $corr0_word 32] [display64 $corr1_raw] \
    [display32_from_word $corr1_word 0] [display32_from_word $corr1_word 32] \
    [display64 $corr2_raw] [display32_from_word $corr2_word 0] \
    [display32_from_word $corr2_word 32] [display64 $corr3_raw] \
    [display32_from_word $corr3_word 0] [display32_from_word $corr3_word 32] \
    [display64 $corr4_raw] [display32_from_word $corr4_word 0] \
    [display32_from_word $corr4_word 32] [display64 $corr5_raw] \
    [field_byte $corr5_word 16] [field_bit $corr5_word 24] \
    [field_bit $corr5_word 27] [display64 $corr6_raw] \
    [display32_from_word $corr6_word 0] [display32_from_word $corr6_word 32] \
    [display64 $corr7_raw] [display32_from_word $corr7_word 0] \
    [field_bit $corr7_word 32] [field_bit $corr7_word 33] \
    [display32_from_word [word64 $mode_stage_raw] 0] \
    [display32_from_word [word64 $lock_wait_raw] 0] \
    [display32_from_word [word64 $spll_stage_raw] 0] \
    [display32_from_word [word64 $command_stage_raw] 0] \
    [display32_from_word $entry_word 32] [display32_from_word $cpu_word 0] \
    [format %08X $firmware_main] [format %08X $shell_poll] \
    [format %08X $boot_done] [format %08X $shell_ready] \
    $firmware_main_gen $shell_poll_gen $boot_gen [format %08X $shell_generation] \
    $generation_match $marker_ready \
    $readiness_status $readiness_reason $readiness_control_eligible $bank_schema \
    [display32_from_word [word64 $slock_magic_raw] 0] \
    [display32_from_word [word64 $slock_stage_raw] 0] \
    [display32_from_word [word64 $slock_retry_raw] 0] \
    [display32_from_word [word64 $slock_entry_tics_raw] 0] \
    [display32_from_word [word64 $slock_remaining_ms_raw] 0] \
    [display32_from_word [word64 $slock_poll_ret_raw] 0] \
    [display32_from_word [word64 $slock_wr_state_raw] 0] $gate $runtime_idle \
    [display64 $reset_raw] [display64 $sync_raw] [display64 $entry_raw]]
  flush stdout
}

puts [format "SHELL_READY_GATED_CONFIG ready_timeout_ms=%d stable_ms=%d passive_samples=%d gap_ms=%d poll_attempts=%d experiment=EXP-S5-STARTUP-CONTRACT-V3-20260914 audit_only=%d manual_command=disabled_in_n1 master_only=0 slave_stimulus=none passive_capture_ms=%d" \
  $ready_timeout_ms $stable_ms $passive_samples $gap_ms $poll_attempts \
  $::n1_audit_only \
  [expr {$passive_samples * $gap_ms}]]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== SHELL_READY_GATED_BOARD ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    set ::post_armed_live($hardware_name) 0
    set ::live_gate($hardware_name) 0
    set ::live_runtime_idle($hardware_name) 0
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    set gate_since -1
    set injected 0
    set dispatch_since -1
    set dispatch_success 0
    set passive_count 0
    set sample 0
    set is_master [expr {[string first "1-11.1" $hardware_name] >= 0}]

    while {1} {
      incr sample
      set elapsed [expr {[clock milliseconds] - $start_ms}]
      read_one $hardware_name $sample $elapsed
      set now [clock milliseconds]

      if {$::n1_audit_only} {
        # Audit-only is a bounded read-only capture for both boards.  It never
        # evaluates readiness as permission to write and never sends VUART or
        # Wishbone control data.
        incr passive_count
        if {$elapsed >= $ready_timeout_ms || $passive_count >= $passive_samples} {
          puts [format "N1_AUDIT_ONLY_DONE board=%s samples=%d elapsed_ms=%d READINESS=%s REASON=%s BANK_SCHEMA=%s CONTROL_WRITES=%d" \
            $hardware_name $passive_count $elapsed \
            $::live_readiness_status($hardware_name) \
            $::live_readiness_reason($hardware_name) \
            $::live_bank_schema($hardware_name) $::n1_injection_count]
          break
        }
        if {$gap_ms > 0} { after $gap_ms }
        continue
      }

      if {!$is_master} {
        if {$dispatch_success || $passive_count >= $passive_samples} {
          break
        }
        if {$::live_gate($hardware_name)} {
          if {$gate_since < 0} {
            set gate_since $now
            puts [format "SHELL_READY_GATE_CANDIDATE board=%s sample=%03d stable_ms=%d" \
              $hardware_name $sample $stable_ms]
          }
          if {$now - $gate_since >= $stable_ms} {
            if {$passive_count == 0} {
              puts [format "SHELL_READY_CONTROL_CAPTURE_START board=%s sample=%03d mode=slave stimulus=none" \
                $hardware_name $sample]
            }
            incr passive_count
          }
        } else {
          set gate_since -1
        }
        if {$passive_count >= $passive_samples} {
          break
        }
      } else {
        if {!$injected} {
          if {$::live_gate($hardware_name) && $::live_runtime_idle($hardware_name) &&
              $::live_command_stage($hardware_name) == 0} {
            if {$gate_since < 0} {
              set gate_since $now
              puts [format "SHELL_READY_GATE_CANDIDATE board=%s sample=%03d stable_ms=%d" \
                $hardware_name $sample $stable_ms]
            }
            if {$now - $gate_since >= $stable_ms} {
              inject_mode_master $hardware_name $sample
              set injected 1
              set dispatch_since $now
              puts [format "SHELL_READY_GATED_STIMULUS_SENT board=%s sample=%03d stable_ms=%d command=mode_master_once" \
                $hardware_name $sample $stable_ms]
            }
          } else {
            set gate_since -1
          }
          if {!$injected && $now - $start_ms >= $ready_timeout_ms} {
            puts [format "SHELL_READY_GATED_INJECT_SKIPPED board=%s reason=gate_timeout_or_nonidle" $hardware_name]
            break
          }
        } elseif {!$dispatch_success} {
          if {$::live_command_stage($hardware_name) >= 9} {
            set dispatch_success 1
            set passive_count 0
            puts [format "SHELL_READY_GATED_COMMAND_DISPATCH_SUCCESS board=%s sample=%03d command_stage=%d" \
              $hardware_name $sample $::live_command_stage($hardware_name)]
          } elseif {$now - $dispatch_since >= 5000} {
            puts [format "SHELL_READY_GATED_RUNTIME_RETEST_INVALID board=%s reason=command_stage_below_9_after_5s command_stage=%d" \
              $hardware_name $::live_command_stage($hardware_name)]
            break
          }
        } else {
          incr passive_count
          if {$passive_count >= $passive_samples} {
            puts [format "SHELL_READY_GATED_PASSIVE_CAPTURE_DONE board=%s samples=%d elapsed_ms=%d" \
              $hardware_name $passive_count $elapsed]
            break
          }
        }
      }
      if {$gap_ms > 0} { after $gap_ms }
    }

    if {!$is_master} {
      if {$passive_count >= $passive_samples} {
        puts [format "SHELL_READY_GATED_CONTROL_DONE board=%s samples=%d" \
          $hardware_name $passive_count]
      } else {
        puts [format "SHELL_READY_GATED_CONTROL_INCOMPLETE board=%s samples=%d reason=gate_timeout" \
          $hardware_name $passive_count]
      }
    }
    puts [format "N1_READINESS_SUMMARY board=%s READINESS=%s REASON=%s BANK_SCHEMA=%s CONTROL_WRITES=%d" \
      $hardware_name $::live_readiness_status($hardware_name) \
      $::live_readiness_reason($hardware_name) $::live_bank_schema($hardware_name) \
      $::n1_injection_count]
  } error_message]} {
    puts [format "SHELL_READY_GATED_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "SHELL_READY_GATED_DONE"
