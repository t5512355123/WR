# Read-only microtrace for the interactive VUART newline-to-shell path.
#
# The reader waits for the existing shell-ready gate, then sends exactly one
# "mode master\n" to the Master.  The Slave is passive.  The only hardware
# writes are the normal JTAG VUART stimulus bytes on the Master; all other
# accesses are readback mailbox transactions.
#
# The 0x1e0..0x1f8 gate words are overlaid after the trace is armed:
#   0x1e0..0x1ec MICRO_BUFFER_WORD0..3
#   0x1f0 MICRO_META0: length[7:0], pos[15:8], line_ready[16],
#       shell_state[31:24]
#   0x1f4 MICRO_META1: boot generation
#   0x1f8 MICRO_META2: buffer capture stage
#   0x1fc MICRO_STAGE
#
# Usage:
#   quartus_stp -t read_vuart_newline_to_shell_dispatch_microtrace.tcl
#       ?ready_timeout_ms? ?stable_ms? ?passive_samples? ?gap_ms? ?poll_attempts?

package require ::quartus::insystem_source_probe

set ready_timeout_ms 30000
set stable_ms 1500
set passive_samples 80
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

proc word32 {value} {
  if {![is_hex $value]} { return INVALID }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
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

proc display32 {value} {
  set word [word32 $value]
  if {$word eq "INVALID"} { return $value }
  return [format %08X $word]
}

proc field_bit {word bit_index} {
  if {$word eq "INVALID"} { return INVALID }
  return [expr {($word >> $bit_index) & 1}]
}

proc word_field {word shift} {
  if {$word eq "INVALID"} { return -1 }
  return [expr {($word >> $shift) & 0xffffffff}]
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

proc format_buffer_hex {words} {
  set result ""
  foreach word $words {
    if {$word eq "INVALID"} { return INVALID }
    for {set shift 0} {$shift < 32} {incr shift 8} {
      append result [format %02X [expr {($word >> $shift) & 0xff}]]
    }
  }
  return $result
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
    puts [format "VUART_MICROTRACE_INJECT board=%s sample=%03d index=%02d BYTE=0x%02X WB_RESULT=%s" \
      $hardware_name $sample $index $byte $result]
    incr index
  }
  flush stdout
}

proc read_one {hardware_name sample elapsed_ms} {
  set corr0_word [word64 [probe_read 28]]
  set corr1_word [word64 [probe_read 29]]
  set corr2_word [word64 [probe_read 30]]
  set corr3_word [word64 [probe_read 31]]
  set corr4_word [word64 [probe_read 32]]
  set corr5_word [word64 [probe_read 33]]
  set corr7_word [word64 [probe_read 35]]
  set entry_word [word64 [probe_read 26]]
  set cpu_word [word64 [probe_read 2]]

  set command_stage_word [word32 [wb_read $hardware_name 0x00100BA0]]
  set boot_generation [word_field $entry_word 32]
  set command_stage [word_field $command_stage_word 0]
  set post_armed [field_bit $corr7_word 33]
  set cpu_reset [field_bit $corr5_word 27]

  set firmware_main [word_field [word32 [wb_read $hardware_name 0x00100BE0]] 0]
  set shell_poll [word_field [word32 [wb_read $hardware_name 0x00100BE4]] 0]
  set boot_done [word_field [word32 [wb_read $hardware_name 0x00100BE8]] 0]
  set shell_ready [word_field [word32 [wb_read $hardware_name 0x00100BEC]] 0]
  set firmware_main_gen [word_field [word32 [wb_read $hardware_name 0x00100BF0]] 0]
  set shell_poll_gen [word_field [word32 [wb_read $hardware_name 0x00100BF4]] 0]
  set boot_init_gen [word_field [word32 [wb_read $hardware_name 0x00100BF8]] 0]

  set micro_stage_word [word32 [wb_read $hardware_name 0x00100BFC]]
  set micro_b0 [word32 [wb_read $hardware_name 0x00100BE0]]
  set micro_b1 [word32 [wb_read $hardware_name 0x00100BE4]]
  set micro_b2 [word32 [wb_read $hardware_name 0x00100BE8]]
  set micro_b3 [word32 [wb_read $hardware_name 0x00100BEC]]
  set micro_meta0_word [word32 [wb_read $hardware_name 0x00100BF0]]
  set micro_boot_gen_word [word32 [wb_read $hardware_name 0x00100BF4]]
  set micro_capture_word [word32 [wb_read $hardware_name 0x00100BF8]]

  set micro_stage [word_field $micro_stage_word 0]
  if {$micro_stage > 0 && $micro_meta0_word ne "INVALID"} {
    set micro_boot_gen [word_field $micro_boot_gen_word 0]
    set micro_length [expr {$micro_meta0_word & 0xff}]
    set micro_pos [expr {($micro_meta0_word >> 8) & 0xff}]
    set micro_line_ready [expr {($micro_meta0_word >> 16) & 1}]
    set micro_shell_state [expr {($micro_meta0_word >> 24) & 0xff}]
    set micro_capture [word_field $micro_capture_word 0]
    set micro_buffer [format_buffer_hex [list $micro_b0 $micro_b1 $micro_b2 $micro_b3]]
  } else {
    set micro_boot_gen 0
    set micro_length 0
    set micro_pos 0
    set micro_line_ready 0
    set micro_shell_state 0
    set micro_capture 0
    set micro_buffer 00000000000000000000000000000000
  }

  set generation_match [expr {$boot_generation >= 0 &&
    $firmware_main_gen == $boot_generation &&
    $shell_poll_gen == $boot_generation &&
    $boot_init_gen == $boot_generation}]
  set marker_ready [expr {$firmware_main == 1 && $shell_poll == 1 &&
    $boot_done == 1 && $shell_ready == 1}]
  set gate [expr {$post_armed eq "1" && $marker_ready &&
    $generation_match && $cpu_reset eq "0"}]
  set runtime_idle [expr {$corr0_word eq "0" && $corr1_word eq "0" &&
    $corr2_word eq "0" && $corr3_word eq "0" && $corr4_word eq "0"}]

  set ::live_gate($hardware_name) $gate
  set ::live_runtime_idle($hardware_name) $runtime_idle
  set ::live_command_stage($hardware_name) $command_stage
  set ::live_micro_stage($hardware_name) $micro_stage

  puts [format "VUART_MICROTRACE_SAMPLE board=%s sample=%03d elapsed_ms=%d POST_STARTUP_ARMED=%s CPU_RESET=%s GATE=%s RUNTIME_IDLE=%s COMMAND_STAGE=%s BOOT_GENERATION=%s CPU_PC=%s FIRMWARE_MAIN_LOOP_REACHED=%s SHELL_POLL_LOOP_REACHED=%s BOOT_INIT_SEQUENCE_DONE=%s FIRMWARE_SHELL_READY=%s FIRMWARE_MAIN_LOOP_GENERATION=%s SHELL_POLL_GENERATION=%s BOOT_INIT_GENERATION=%s GENERATION_MATCH=%s MICRO_STAGE=%s MICRO_STAGE_NAME=%s MICRO_BOOT_GENERATION=%s MICRO_LENGTH=%s MICRO_POS=%s MICRO_LINE_READY=%s MICRO_SHELL_STATE=%s MICRO_BUFFER_CAPTURE_STAGE=%s MICRO_BUFFER_HEX=%s CORR0_RAW=%s CORR1_RAW=%s CORR2_RAW=%s CORR3_RAW=%s CORR4_RAW=%s CORR5_RAW=%s CORR7_RAW=%s" \
    $hardware_name $sample $elapsed_ms $post_armed $cpu_reset $gate $runtime_idle \
    $command_stage $boot_generation [word_field $cpu_word 0] \
    $firmware_main $shell_poll $boot_done $shell_ready $firmware_main_gen \
    $shell_poll_gen $boot_init_gen $generation_match $micro_stage \
    [micro_stage_name $micro_stage] $micro_boot_gen $micro_length $micro_pos \
    $micro_line_ready $micro_shell_state $micro_capture $micro_buffer \
    [display64 $corr0_word] [display64 $corr1_word] [display64 $corr2_word] \
    [display64 $corr3_word] [display64 $corr4_word] [display64 $corr5_word] \
    [display64 $corr7_word]]
  flush stdout
}

puts [format "VUART_MICROTRACE_CONFIG ready_timeout_ms=%d stable_ms=%d passive_samples=%d gap_ms=%d poll_attempts=%d experiment=EXP-WRPC-STEP4-VUART-NEWLINE-TO-SHELL-DISPATCH-MICROTRACE-20260828 manual_command=mode_master_once master_only=1 slave_stimulus=none" \
  $ready_timeout_ms $stable_ms $passive_samples $gap_ms $poll_attempts]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== VUART_MICROTRACE_BOARD ${hardware_name} ==="
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
            puts [format "VUART_MICROTRACE_GATE_CANDIDATE board=%s sample=%03d stable_ms=%d" \
              $hardware_name $sample $stable_ms]
          }
          if {$now - $gate_since >= $stable_ms} {
            inject_mode_master $hardware_name $sample
            set injected 1
            set injection_ms $now
            set passive_count 0
            puts [format "VUART_MICROTRACE_STIMULUS_SENT board=%s sample=%03d stable_ms=%d command=mode_master_once" \
              $hardware_name $sample $stable_ms]
          }
        } else {
          set gate_since -1
        }
        if {!$injected && $now - $start_ms >= $ready_timeout_ms} {
          puts [format "VUART_MICROTRACE_INJECT_SKIPPED board=%s reason=gate_timeout_or_nonidle" $hardware_name]
          break
        }
      } elseif {$is_master && $injected} {
        incr passive_count
        if {$passive_count >= $passive_samples} { break }
      } else {
        if {$::live_gate($hardware_name)} {
          if {$gate_since < 0} {
            set gate_since $now
            puts [format "VUART_MICROTRACE_CONTROL_GATE_CANDIDATE board=%s sample=%03d stable_ms=%d" \
              $hardware_name $sample $stable_ms]
          }
          if {$now - $gate_since >= $stable_ms} {
            incr passive_count
            if {$passive_count == 1} {
              puts [format "VUART_MICROTRACE_CONTROL_CAPTURE_START board=%s sample=%03d mode=slave stimulus=none" \
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
    puts [format "VUART_MICROTRACE_BOARD_DONE board=%s injected=%d samples=%d injection_elapsed_ms=%d final_micro_stage=%d final_command_stage=%d" \
      $hardware_name $injected $sample [expr {$injection_ms < 0 ? -1 : $injection_ms - $start_ms}] \
      $::live_micro_stage($hardware_name) $::live_command_stage($hardware_name)]
  } error_message]} {
    puts [format "VUART_MICROTRACE_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "VUART_MICROTRACE_DONE"
