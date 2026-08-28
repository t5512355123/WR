# M9 -> runtime DCO validation for the static-FSM one-line fix.
#
# This is a read-only capture except for one gated Master VUART command:
# "mode master\n". The Slave is observed passively. Existing persistent
# breadcrumbs are reused so this script does not alter firmware behavior.
#
# Usage:
#   quartus_stp -t read_m9_to_runtime_dco_fix_validation.tcl
#       ?ready_timeout_ms? ?stable_ms? ?passive_samples? ?gap_ms? ?poll_attempts?

package require ::quartus::insystem_source_probe

set ready_timeout_ms 30000
set stable_ms 1500
set passive_samples 100
set gap_ms 100
set poll_attempts 25
if {[llength $argv] >= 1} { set ready_timeout_ms [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set stable_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set passive_samples [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set gap_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set poll_attempts [expr {int([lindex $argv 4])}] }
if {$ready_timeout_ms <= 0 || $stable_ms <= 0 || $passive_samples <= 0 ||
    $gap_ms < 0 || $poll_attempts <= 0} {
  error "ready_timeout_ms > 0, stable_ms > 0, passive_samples > 0, gap_ms >= 0, poll_attempts > 0 required"
}

array set ::wb_toggle {}
array set ::live_gate {}
array set ::live_runtime_idle {}
array set ::live_command_stage {}
array set ::live_micro_stage {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word64 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return $word
}

proc word32 {value} {
  if {![is_hex $value]} { return INVALID }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc display64 {value} {
  set word [word64 $value]
  if {$word < 0} { return $value }
  return [format %016X $word]
}

proc display32 {value} {
  set word [word32 $value]
  if {$word eq "INVALID"} { return $value }
  return [format %08X $word]
}

proc field_bit {word bit_index} {
  if {$word < 0} { return INVALID }
  return [expr {($word >> $bit_index) & 1}]
}

proc field_byte {word bit_index} {
  if {$word < 0} { return INVALID }
  return [format %02X [expr {($word >> $bit_index) & 0xff}]]
}

proc field32 {word} {
  if {$word < 0} { return INVALID }
  return [format %08X [expr {$word & 0xffffffff}]]
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

proc micro_stage_name {stage} {
  switch -- $stage {
    0 { return IDLE }
    1 { return NEWLINE_DETECTED }
    2 { return LINE_READY_SCHEDULED }
    3 { return SHELL_POLL_LINE_READY }
    4 { return BUFFER_TERMINATED }
    5 { return SHELL_EXEC_ENTERED }
    6 { return TOKEN_PARSED }
    7 { return MODE_LOOKUP_MATCHED }
    8 { return MODE_HANDLER_ENTERED }
    9 { return MASTER_ARGUMENT_MATCHED }
    default { return UNKNOWN }
  }
}

proc inject_mode_master {hardware_name sample} {
  set command "mode master\n"
  set index 0
  foreach character [split $command ""] {
    scan $character %c byte
    set result [wb_write $hardware_name 0x00100510 $byte]
    puts [format "DCO_FIX_INJECT board=%s sample=%03d index=%02d BYTE=0x%02X WB_RESULT=%s" \
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
  set corr7_raw [probe_read 35]
  set corr7_word [word64 $corr7_raw]
  set reset_raw [probe_read 27]
  set reset_word [word64 $reset_raw]
  set cpu_raw [probe_read 2]
  set entry_raw [probe_read 26]

  set firmware_main [field32 [word64 [wb_read $hardware_name 0x00100BE0]]]
  set shell_poll [field32 [word64 [wb_read $hardware_name 0x00100BE4]]]
  set boot_done [field32 [word64 [wb_read $hardware_name 0x00100BE8]]]
  set shell_ready [field32 [word64 [wb_read $hardware_name 0x00100BEC]]]
  set firmware_main_gen [field32 [word64 [wb_read $hardware_name 0x00100BF0]]]
  set shell_poll_gen [field32 [word64 [wb_read $hardware_name 0x00100BF4]]]
  set boot_init_gen [field32 [word64 [wb_read $hardware_name 0x00100BF8]]]
  set micro_stage_word [word64 [wb_read $hardware_name 0x00100BFC]]
  set command_stage_word [word64 [wb_read $hardware_name 0x00100BA0]]
  set mode_stage_word [word64 [wb_read $hardware_name 0x00100B74]]
  set spll_stage_word [word64 [wb_read $hardware_name 0x00100B90]]
  set spll_init_word [word64 [wb_read $hardware_name 0x00100B44]]
  set clear_dacs_word [word64 [wb_read $hardware_name 0x00100B48]]
  set last_init_word [word64 [wb_read $hardware_name 0x00100B4C]]
  set last_clear_word [word64 [wb_read $hardware_name 0x00100B50]]
  set micro_stage [expr {[word64 $micro_stage_word] < 0 ? -1 : [word64 $micro_stage_word] & 0xffffffff}]
  set command_stage [expr {[word64 $command_stage_word] < 0 ? -1 : [word64 $command_stage_word] & 0xffffffff}]
  set entry_word [word64 $entry_raw]
  set corr5_post [field_bit $corr5_word 27]
  set post_armed [field_bit $corr7_word 33]
  set generation [expr {$entry_word < 0 ? -1 : ($entry_word >> 32) & 0xffffffff}]
  set generation_match [expr {$generation >= 0 && $firmware_main_gen ne "INVALID" &&
    $firmware_main_gen eq [format %08X $generation] &&
    $shell_poll_gen eq [format %08X $generation] &&
    $boot_init_gen eq [format %08X $generation]}]
  set marker_ready [expr {$firmware_main eq "00000001" && $shell_poll eq "00000001" &&
    $boot_done eq "00000001" && $shell_ready eq "00000001"}]
  set gate [expr {$post_armed eq "1" && $marker_ready && $generation_match &&
    $corr5_post eq "0"}]
  set runtime_idle [expr {$corr0_word == 0 && $corr1_word == 0 &&
    $corr2_word == 0 && $corr3_word == 0 && $corr4_word == 0}]

  set ::live_gate($hardware_name) $gate
  set ::live_runtime_idle($hardware_name) $runtime_idle
  set ::live_command_stage($hardware_name) $command_stage
  set ::live_micro_stage($hardware_name) $micro_stage

  puts [format "DCO_FIX_SAMPLE board=%s sample=%03d elapsed_ms=%d GATE=%s RUNTIME_IDLE=%s BOOT_GENERATION=%s CPU_RESET=%s M9=%s M9_NAME=%s CMD_STAGE=%s MODE_STAGE=%s SPLL_CHECK_LOCK_STAGE=%s SPLL_INIT_COUNT=%s CLEAR_DACS_COUNT=%s LAST_INIT_TICS=%s LAST_CLEAR_DACS_TICS=%s DCO_RAW=%s RT_STATE=%s BUS_STATE=%s BUS_DONE=%s STATIC_READY=%s RUNTIME_START=%s BUS_ENABLE=%s DPLL_LOAD=%s HPLL_LOAD=%s T_DAC_LOAD=%s T_RUNTIME_START=%s T_BUS_DONE=%s T_STATIC_DONE_PULSE=%s T_STATIC_STATE_LEAVE_ZERO=%s T_STATIC_READY_DROP=%s T_SI_CONFIG_DROP=%s T_WR_CORE_RESET_ASSERT=%s T_CPU_RESET_ASSERT=%s T_SYSTEM_START=%s STATIC_BEFORE=%s STATIC_AFTER=%s STATIC_CURRENT=%s POST_STARTUP_ARMED=%s SI_CONFIG_DONE=%s WR_CORE_RESET_N=%s CPU_RESET_LIVE=%s LIVE_RUNTIME_START=%s LIVE_BUS_DONE=%s LIVE_STATIC_DONE_PULSE=%s STATIC_ACCESS_START=%s RUNTIME_STATE_LIVE=%s BUS_STATE_LIVE=%s RUNTIME_BUS_ENABLE=%s SYSTEM_START_LIVE=%s RESET_STICKY_RAW=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s BOOT_GENERATION_EVIDENCE=%s GENERATION_MATCH=%s CORR0_RAW=%s CORR1_RAW=%s CORR2_RAW=%s CORR3_RAW=%s CORR4_RAW=%s CORR5_RAW=%s CORR7_RAW=%s" \
    $hardware_name $sample $elapsed_ms $gate $runtime_idle [format %08X $generation] \
    $corr5_post $micro_stage [micro_stage_name $micro_stage] $command_stage \
    [field32 $mode_stage_word] [field32 $spll_stage_word] [field32 $spll_init_word] \
    [field32 $clear_dacs_word] [field32 $last_init_word] [field32 $last_clear_word] \
    [display64 $dco_raw] [field_byte $dco_word 0] [field_bit $dco_word 3] \
    [field_bit $dco_word 4] [field_bit $dco_word 5] [field_bit $dco_word 14] \
    [field_bit $dco_word 15] [field_bit $dco_word 16] [field_bit $dco_word 17] \
    [display32 [expr {$corr0_word < 0 ? "INVALID" : $corr0_word & 0xffffffff}]] \
    [display32 [expr {$corr0_word < 0 ? "INVALID" : ($corr0_word >> 32) & 0xffffffff}]] \
    [display32 [expr {$corr1_word < 0 ? "INVALID" : $corr1_word & 0xffffffff}]] \
    [display32 [expr {$corr1_word < 0 ? "INVALID" : ($corr1_word >> 32) & 0xffffffff}]] \
    [display32 [expr {$corr2_word < 0 ? "INVALID" : $corr2_word & 0xffffffff}]] \
    [display32 [expr {$corr2_word < 0 ? "INVALID" : ($corr2_word >> 32) & 0xffffffff}]] \
    [display32 [expr {$corr3_word < 0 ? "INVALID" : $corr3_word & 0xffffffff}]] \
    [display32 [expr {$corr3_word < 0 ? "INVALID" : ($corr3_word >> 32) & 0xffffffff}]] \
    [display32 [expr {$corr4_word < 0 ? "INVALID" : $corr4_word & 0xffffffff}]] \
    [display32 [expr {$corr4_word < 0 ? "INVALID" : ($corr4_word >> 32) & 0xffffffff}]] \
    [field_byte $corr5_word 0] [field_byte $corr5_word 8] [field_byte $corr5_word 16] \
    [field_bit $corr5_word 24] [field_bit $corr5_word 25] [field_bit $corr5_word 26] \
    [field_bit $corr5_word 27] [field_bit $corr5_word 28] [field_bit $corr5_word 29] \
    [field_bit $corr5_word 30] [field_bit $corr5_word 31] [field_byte $corr5_word 32] \
    [field_bit $corr5_word 35] [field_bit $corr5_word 36] [field_bit $corr5_word 37] \
    [display64 $reset_raw] [field_byte $reset_word 16] [field_byte $reset_word 24] \
    [field_byte $reset_word 40] [display64 $entry_raw] $generation_match \
    [display64 $corr0_raw] [display64 $corr1_raw] [display64 $corr2_raw] \
    [display64 $corr3_raw] [display64 $corr4_raw] [display64 $corr5_raw] [display64 $corr7_raw]]
  flush stdout
}

puts [format "DCO_FIX_CONFIG ready_timeout_ms=%d stable_ms=%d passive_samples=%d gap_ms=%d poll_attempts=%d experiment=EXP-WRPC-STEP4-M9-TO-RUNTIME-DCO-FIX-VALIDATION-20260828 manual_command=mode_master_once master_only=1 slave_stimulus=none" \
  $ready_timeout_ms $stable_ms $passive_samples $gap_ms $poll_attempts]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== DCO_FIX_BOARD ${hardware_name} ==="
  flush stdout
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    set ::live_gate($hardware_name) 0
    set ::live_runtime_idle($hardware_name) 0
    set ::live_command_stage($hardware_name) -1
    set ::live_micro_stage($hardware_name) -1
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    set gate_since -1
    set injected 0
    set injection_ms -1
    set passive_count 0
    set sample 0
    set is_master [expr {[string first "1-11.1" $hardware_name] >= 0}]
    while {1} {
      incr sample
      set elapsed [expr {[clock milliseconds] - $start_ms}]
      read_one $hardware_name $sample $elapsed
      set now [clock milliseconds]
      if {$is_master && !$injected} {
        if {$::live_gate($hardware_name) && $::live_runtime_idle($hardware_name) &&
            $::live_command_stage($hardware_name) == 0} {
          if {$gate_since < 0} {
            set gate_since $now
            puts [format "DCO_FIX_GATE_CANDIDATE board=%s sample=%03d stable_ms=%d" \
              $hardware_name $sample $stable_ms]
          }
          if {$now - $gate_since >= $stable_ms} {
            inject_mode_master $hardware_name $sample
            set injected 1
            set injection_ms $now
            set passive_count 0
            puts [format "DCO_FIX_STIMULUS_SENT board=%s sample=%03d stable_ms=%d command=mode_master_once" \
              $hardware_name $sample $stable_ms]
          }
        } else {
          set gate_since -1
        }
        if {!$injected && $now - $start_ms >= $ready_timeout_ms} {
          puts [format "DCO_FIX_INJECT_SKIPPED board=%s reason=gate_timeout_or_nonidle" $hardware_name]
          break
        }
      } elseif {$is_master && $injected} {
        incr passive_count
        if {$passive_count >= $passive_samples} { break }
      } else {
        if {$::live_gate($hardware_name)} {
          if {$gate_since < 0} {
            set gate_since $now
            puts [format "DCO_FIX_SLAVE_GATE_CANDIDATE board=%s sample=%03d" $hardware_name $sample]
          }
          if {$now - $gate_since >= $stable_ms} {
            incr passive_count
            if {$passive_count == 1} {
              puts [format "DCO_FIX_SLAVE_CAPTURE_START board=%s sample=%03d stimulus=none" \
                $hardware_name $sample]
            }
          }
        } else {
          set gate_since -1
        }
        if {$passive_count >= $passive_samples} { break }
      }
      if {$gap_ms > 0} { after $gap_ms }
    }
    puts [format "DCO_FIX_BOARD_DONE board=%s injected=%d samples=%d injection_elapsed_ms=%d final_m9=%d final_command_stage=%d" \
      $hardware_name $injected $sample [expr {$injection_ms < 0 ? -1 : $injection_ms - $start_ms}] \
      $::live_micro_stage($hardware_name) $::live_command_stage($hardware_name)]
  } error_message]} {
    puts [format "DCO_FIX_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "DCO_FIX_DONE"
