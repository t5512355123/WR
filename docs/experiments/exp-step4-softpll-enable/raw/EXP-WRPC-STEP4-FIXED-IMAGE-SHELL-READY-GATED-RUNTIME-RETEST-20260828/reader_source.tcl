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
# WDIAGS firmware shell-ready words (private read-only map):
#   0x1e0 FIRMWARE_MAIN_LOOP_REACHED
#   0x1e4 SHELL_POLL_LOOP_REACHED
#   0x1e8 BOOT_INIT_SEQUENCE_DONE
#   0x1ec FIRMWARE_SHELL_READY
#   0x1f0 FIRMWARE_MAIN_LOOP_GENERATION
#   0x1f4 SHELL_POLL_GENERATION
#   0x1f8 BOOT_INIT_GENERATION
#
# Usage:
#   quartus_stp -t read_fixed_image_shell_ready_gated_runtime_retest.tcl
#       ?ready_timeout_ms? ?stable_ms? ?passive_samples? ?gap_ms? ?poll_attempts?

package require ::quartus::insystem_source_probe

set ready_timeout_ms 30000
set stable_ms 1500
set passive_samples 180
set gap_ms 200
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
  set firmware_main_raw [wb_read $hardware_name 0x00100BE0]
  set shell_poll_raw [wb_read $hardware_name 0x00100BE4]
  set boot_done_raw [wb_read $hardware_name 0x00100BE8]
  set shell_ready_raw [wb_read $hardware_name 0x00100BEC]
  set firmware_main_gen_raw [wb_read $hardware_name 0x00100BF0]
  set shell_poll_gen_raw [wb_read $hardware_name 0x00100BF4]
  set boot_gen_raw [wb_read $hardware_name 0x00100BF8]

  set entry_word [word64 $entry_raw]
  set reset_word [word64 $reset_raw]
  set cpu_word [word64 $cpu_raw]
  set corr7_post_armed [field_bit $corr7_word 33]
  set ::post_armed_live($hardware_name) $corr7_post_armed

  set boot_generation [numeric32_from_word $entry_word 32]
  set firmware_main [numeric32_from_word [word64 $firmware_main_raw] 0]
  set shell_poll [numeric32_from_word [word64 $shell_poll_raw] 0]
  set boot_done [numeric32_from_word [word64 $boot_done_raw] 0]
  set shell_ready [numeric32_from_word [word64 $shell_ready_raw] 0]
  set firmware_main_gen [numeric32_from_word [word64 $firmware_main_gen_raw] 0]
  set shell_poll_gen [numeric32_from_word [word64 $shell_poll_gen_raw] 0]
  set boot_gen [numeric32_from_word [word64 $boot_gen_raw] 0]
  set cpu_pc [numeric32_from_word $cpu_word 0]
  set cpu_reset [field_bit $corr5_word 27]
  set command_stage [numeric32_from_word [word64 $command_stage_raw] 0]
  set mode_stage [numeric32_from_word [word64 $mode_stage_raw] 0]
  set lock_wait [numeric32_from_word [word64 $lock_wait_raw] 0]
  set spll_stage [numeric32_from_word [word64 $spll_stage_raw] 0]

  set generation_match [expr {$boot_generation >= 0 &&
    $firmware_main_gen == $boot_generation &&
    $shell_poll_gen == $boot_generation &&
    $boot_gen == $boot_generation}]
  set marker_ready [expr {$firmware_main == 1 && $shell_poll == 1 &&
    $boot_done == 1 && $shell_ready == 1}]
  set gate [expr {$corr7_post_armed eq "1" && $marker_ready &&
    $generation_match && $cpu_reset eq "0"}]

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

  puts [format "SHELL_READY_GATED_SAMPLE board=%s sample=%03d elapsed_ms=%d DCO_RAW=%s CORR0_RAW=%s T_DAC_LOAD=%s T_RUNTIME_START=%s CORR1_RAW=%s T_BUS_DONE=%s T_STATIC_DONE_PULSE=%s CORR2_RAW=%s T_STATIC_STATE_LEAVE_ZERO=%s T_STATIC_READY_DROP=%s CORR3_RAW=%s T_SI_CONFIG_DROP=%s T_WR_CORE_RESET_ASSERT=%s CORR4_RAW=%s T_CPU_RESET_ASSERT=%s T_SYSTEM_START=%s CORR5_RAW=%s STATIC_CURRENT=%s POST_STARTUP_ARMED=%s CPU_RESET=%s CORR6_RAW=%s T_POST_STARTUP_ARM=%s STARTUP_SYSTEM_START_SEEN=%s CORR7_RAW=%s STARTUP_STATIC_COMPLETE_SEEN=%s STARTUP_READY_FINAL=%s POST_ARMED=%s MODE_STAGE=%s LOCK_WAIT_SUBSTAGE=%s SPLL_CHECK_LOCK_STAGE=%s PERSIST_CMD_STAGE=%s BOOT_GENERATION=%s CPU_PC=%s FIRMWARE_MAIN_LOOP_REACHED=%s SHELL_POLL_LOOP_REACHED=%s BOOT_INIT_SEQUENCE_DONE=%s FIRMWARE_SHELL_READY=%s FIRMWARE_MAIN_LOOP_GENERATION=%s SHELL_POLL_GENERATION=%s BOOT_INIT_GENERATION=%s GENERATION_MATCH=%s MARKER_READY=%s GATE=%s RUNTIME_IDLE=%s RESET_RAW=%s SYNC_RAW=%s ENTRY_RAW=%s" \
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
    [display32_from_word [word64 $firmware_main_raw] 0] \
    [display32_from_word [word64 $shell_poll_raw] 0] \
    [display32_from_word [word64 $boot_done_raw] 0] \
    [display32_from_word [word64 $shell_ready_raw] 0] \
    [display32_from_word [word64 $firmware_main_gen_raw] 0] \
    [display32_from_word [word64 $shell_poll_gen_raw] 0] \
    [display32_from_word [word64 $boot_gen_raw] 0] \
    $generation_match $marker_ready $gate $runtime_idle \
    [display64 $reset_raw] [display64 $sync_raw] [display64 $entry_raw]]
  flush stdout
}

puts [format "SHELL_READY_GATED_CONFIG ready_timeout_ms=%d stable_ms=%d passive_samples=%d gap_ms=%d poll_attempts=%d experiment=EXP-WRPC-STEP4-FIXED-IMAGE-SHELL-READY-GATED-RUNTIME-RETEST manual_command=mode_master_once master_only=1 slave_stimulus=none passive_capture_ms=%d" \
  $ready_timeout_ms $stable_ms $passive_samples $gap_ms $poll_attempts \
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
  } error_message]} {
    puts [format "SHELL_READY_GATED_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "SHELL_READY_GATED_DONE"
