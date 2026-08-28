# Read-only Step 4 closure validation.
#
# The reader waits for the existing post-startup/firmware-ready gate, records
# a 10 s pre-command baseline, injects exactly one `mode master\n` through the
# normal JTAG VUART path on the Master, waits for command-stage 9 and
# PERSIST_MODE_MASTER_STAGE 5, then records a 30 s measurement window and a
# 10 s post window. The Slave is always passive.
#
# Primary accepted-event evidence is the existing WR SoftPLL diagnostic count:
#   0x00100298 / 0x0010029C = diag_dmtd_ref/fb_event_count
#   wr_softpll_ng.vhd p_diag_tag_events increments these on dmtd_event_sys.
# dmtd_event_sys is the synchronized deglitcher accepted pulse and is the
# event that enters the tag strobe path. The lower-level deglitch accept
# counters at 0x0010022C / 0x00100230 are also sampled for cross-checking.
# No diagnostic or functional register is written except the 12 normal VUART
# HOST_TDR bytes used as the single Master stimulus.
#
# Usage:
#   quartus_stp -t read_step4_dmtd_accept_to_helper_closure.tcl
#       ?ready_timeout_ms? ?stable_ms? ?baseline_ms? ?measurement_ms?
#       ?post_ms? ?gap_ms? ?poll_attempts?

package require ::quartus::insystem_source_probe

set ready_timeout_ms 30000
set stable_ms 1500
set baseline_ms 10000
set measurement_ms 30000
set post_ms 10000
set gap_ms 100
set poll_attempts 25
if {[llength $argv] >= 1} { set ready_timeout_ms [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set stable_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set baseline_ms [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set measurement_ms [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set post_ms [expr {int([lindex $argv 4])}] }
if {[llength $argv] >= 6} { set gap_ms [expr {int([lindex $argv 5])}] }
if {[llength $argv] >= 7} { set poll_attempts [expr {int([lindex $argv 6])}] }
if {$ready_timeout_ms <= 0 || $stable_ms <= 0 || $baseline_ms <= 0 ||
    $measurement_ms <= 0 || $post_ms <= 0 || $gap_ms < 0 ||
    $poll_attempts <= 0} {
  error "ready_timeout_ms/stable_ms/baseline_ms/measurement_ms/post_ms/poll_attempts must be > 0 and gap_ms >= 0"
}

array set ::wb_toggle {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc word64 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return $word
}

proc fmt32 {value} {
  if {![string is integer -strict $value] || $value < 0} { return INVALID }
  return [format %08X [expr {$value & 0xffffffff}]]
}

proc fmt64 {value} {
  if {![string is integer -strict $value] || $value < 0} { return INVALID }
  return [format %016X $value]
}

proc probe_bit {word bit_index} {
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit_index) & 1}]
}

proc probe_byte {word bit_index} {
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit_index) & 0xff}]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return INVALID
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
    return INVALID
  }
  after 2
  for {set n 0} {$n < $::poll_attempts} {incr n} {
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
  return INVALID
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
    return INVALID
  }
  after 2
  for {set n 0} {$n < $::poll_attempts} {incr n} {
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
  return INVALID
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
    puts [format "CLOSURE_INJECT board=%s sample=%03d index=%02d BYTE=0x%02X WB_RESULT=%s" \
      $hardware_name $sample $index $byte $result]
    incr index
  }
  flush stdout
}

proc read_ready {hardware_name} {
  array set r {}
  set corr5 [word64 [probe_read 33]]
  set corr7 [word64 [probe_read 35]]
  set entry [word64 [probe_read 26]]
  set r(post_armed) [probe_bit $corr7 33]
  set r(cpu_reset) [probe_bit $corr5 27]
  set r(boot_generation) -1
  if {$entry >= 0} { set r(boot_generation) [expr {($entry >> 32) & 0xffffffff}] }

  set r(firmware_main) [word32 [wb_read $hardware_name 0x00100BE0]]
  set r(shell_poll) [word32 [wb_read $hardware_name 0x00100BE4]]
  set r(boot_done) [word32 [wb_read $hardware_name 0x00100BE8]]
  set r(shell_ready) [word32 [wb_read $hardware_name 0x00100BEC]]
  set r(firmware_main_generation) [word32 [wb_read $hardware_name 0x00100BF0]]
  set r(shell_poll_generation) [word32 [wb_read $hardware_name 0x00100BF4]]
  set r(boot_init_generation) [word32 [wb_read $hardware_name 0x00100BF8]]

  set c0 [word64 [probe_read 28]]
  set c1 [word64 [probe_read 29]]
  set c2 [word64 [probe_read 30]]
  set c3 [word64 [probe_read 31]]
  set c4 [word64 [probe_read 32]]
  set r(runtime_idle) [expr {$c0 == 0 && $c1 == 0 && $c2 == 0 &&
    $c3 == 0 && $c4 == 0}]
  set marker_ready [expr {$r(firmware_main) == 1 && $r(shell_poll) == 1 &&
    $r(boot_done) == 1 && $r(shell_ready) == 1}]
  set generation_match [expr {$r(boot_generation) >= 0 &&
    $r(firmware_main_generation) == $r(boot_generation) &&
    $r(shell_poll_generation) == $r(boot_generation) &&
    $r(boot_init_generation) == $r(boot_generation)}]
  set r(generation_match) $generation_match
  set r(marker_ready) $marker_ready
  set r(gate) [expr {$r(post_armed) == 1 && $marker_ready &&
    $generation_match && $r(cpu_reset) == 0 && $r(runtime_idle)}]
  return [array get r]
}

proc print_ready {hardware_name sample elapsed data} {
  array set r $data
  puts [format "CLOSURE_READY board=%s sample=%03d elapsed_ms=%d POST_STARTUP_ARMED=%s FIRMWARE_MAIN_LOOP_REACHED=%s SHELL_POLL_LOOP_REACHED=%s BOOT_INIT_SEQUENCE_DONE=%s FIRMWARE_SHELL_READY=%s GENERATION_MATCH=%s CPU_RESET=%s RUNTIME_IDLE=%s GATE=%s" \
    $hardware_name $sample $elapsed $r(post_armed) $r(firmware_main) \
    $r(shell_poll) $r(boot_done) $r(shell_ready) $r(generation_match) \
    $r(cpu_reset) $r(runtime_idle) $r(gate)]
  flush stdout
}

proc wait_ready_gate {hardware_name start_ms} {
  set gate_since -1
  set sample 0
  while {[clock milliseconds] - $start_ms < $::ready_timeout_ms} {
    incr sample
    set elapsed [expr {[clock milliseconds] - $start_ms}]
    set data [read_ready $hardware_name]
    print_ready $hardware_name $sample $elapsed $data
    array set r $data
    set now [clock milliseconds]
    if {$r(gate)} {
      if {$gate_since < 0} {
        set gate_since $now
        puts [format "CLOSURE_GATE_CANDIDATE board=%s sample=%03d stable_ms=%d" \
          $hardware_name $sample $::stable_ms]
      }
      if {$now - $gate_since >= $::stable_ms} {
        puts [format "CLOSURE_GATE_READY board=%s sample=%03d stable_ms=%d" \
          $hardware_name $sample $::stable_ms]
        return 1
      }
    } else {
      set gate_since -1
    }
    if {$::gap_ms > 0} { after $::gap_ms }
  }
  puts [format "CLOSURE_GATE_TIMEOUT board=%s timeout_ms=%d" \
    $hardware_name $::ready_timeout_ms]
  return 0
}

proc read_chain {hardware_name} {
  array set s {}
  set entry [word64 [probe_read 26]]
  set reset_sticky [word64 [probe_read 27]]
  set cpu_debug [word64 [probe_read 2]]
  set s(boot_generation) -1
  if {$entry >= 0} { set s(boot_generation) [expr {($entry >> 32) & 0xffffffff}] }
  set s(cpu_reset_count) [probe_byte $reset_sticky 16]
  set s(wr_core_reset_count) [probe_byte $reset_sticky 24]
  set s(si_config_drop_count) [probe_byte $reset_sticky 40]
  set s(reset_sticky) $reset_sticky
  set s(cpu_reset_live) [probe_bit $cpu_debug 32]
  set wr_core_reset_n [probe_bit $cpu_debug 36]
  set s(wr_core_reset_live) [expr {$wr_core_reset_n < 0 ? -1 : 1 - $wr_core_reset_n}]
  set external_reset_n [probe_bit $cpu_debug 35]
  set s(external_reset_live) [expr {$external_reset_n < 0 ? -1 : 1 - $external_reset_n}]
  set s(si_config_done) [probe_bit $cpu_debug 37]
  set s(sys_pll_lock) [probe_bit $cpu_debug 38]

  set s(command_stage) [word32 [wb_read $hardware_name 0x00100BA0]]
  set s(mode_master_stage) [word32 [wb_read $hardware_name 0x00100B74]]
  set s(spll_state) [word32 [wb_read $hardware_name 0x00100AA0]]

  # Primary accepted-event counters: these are incremented by
  # dmtd_event_sys in wr_softpll_ng.vhd immediately before the tag path.
  set s(dmtd_ref_event) [word32 [wb_read $hardware_name 0x00100298]]
  set s(dmtd_fb_event) [word32 [wb_read $hardware_name 0x0010029C]]
  # Lower-level DMTD deglitch accept counters, for semantic cross-check.
  set s(dmtd_ref_qualified) [word32 [wb_read $hardware_name 0x0010022C]]
  set s(dmtd_fb_qualified) [word32 [wb_read $hardware_name 0x00100230]]
  set s(tag_valid) [word32 [wb_read $hardware_name 0x00100284]]
  set s(trr_write) [word32 [wb_read $hardware_name 0x00100288]]
  set s(trr_pop) [word32 [wb_read $hardware_name 0x00100B54]]
  set s(irq) [word32 [wb_read $hardware_name 0x00100AEC]]
  set s(helper) [word32 [wb_read $hardware_name 0x00100B18]]
  set s(tag_pending) [word32 [wb_read $hardware_name 0x001002A8]]
  return [array get s]
}

proc print_chain_sample {hardware_name phase sample elapsed data} {
  array set s $data
  puts [format "CLOSURE_SAMPLE board=%s phase=%s sample=%03d elapsed_ms=%d COMMAND_STAGE=%s PERSIST_MODE_MASTER_STAGE=%s BOOT_GENERATION=%s DMTD_REF_ACCEPT_EVENT=%s DMTD_FB_ACCEPT_EVENT=%s DMTD_REF_QUALIFIED=%s DMTD_FB_QUALIFIED=%s TAG_VALID=%s TRR_WRITE=%s TRR_POP=%s IRQ=%s HELPER_UPDATE=%s TAG_PENDING=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_DROP_COUNT=%s CPU_RESET_LIVE=%s WR_CORE_RESET_LIVE=%s SI_CONFIG_DONE=%s SYS_PLL_LOCK=%s" \
    $hardware_name $phase $sample $elapsed [fmt32 $s(command_stage)] \
    [fmt32 $s(mode_master_stage)] [fmt32 $s(boot_generation)] \
    [fmt32 $s(dmtd_ref_event)] [fmt32 $s(dmtd_fb_event)] \
    [fmt32 $s(dmtd_ref_qualified)] [fmt32 $s(dmtd_fb_qualified)] \
    [fmt32 $s(tag_valid)] [fmt32 $s(trr_write)] [fmt32 $s(trr_pop)] \
    [fmt32 $s(irq)] [fmt32 $s(helper)] [fmt32 $s(tag_pending)] \
    [fmt32 $s(cpu_reset_count)] [fmt32 $s(wr_core_reset_count)] \
    [fmt32 $s(si_config_drop_count)] $s(cpu_reset_live) \
    $s(wr_core_reset_live) $s(si_config_done) $s(sys_pll_lock)]
  flush stdout
}

proc capture_phase {hardware_name phase duration_ms start_ms sample_var} {
  upvar 1 $sample_var sample
  set have_first 0
  array set first {}
  array set last {}
  set phase_start [clock milliseconds]
  set count 0
  while {[clock milliseconds] - $phase_start < $duration_ms} {
    incr sample
    incr count
    set elapsed [expr {[clock milliseconds] - $start_ms}]
    set data [read_chain $hardware_name]
    print_chain_sample $hardware_name $phase $sample $elapsed $data
    if {!$have_first} {
      array set first $data
      set have_first 1
    }
    array set last $data
    if {$::gap_ms > 0} { after $::gap_ms }
  }
  if {!$have_first} { return [list 0 {} {}] }
  return [list $count [array get first] [array get last]]
}

proc wait_dispatch {hardware_name start_ms sample_var} {
  upvar 1 $sample_var sample
  set wait_start [clock milliseconds]
  set ok 0
  while {[clock milliseconds] - $wait_start < 10000} {
    incr sample
    set elapsed [expr {[clock milliseconds] - $start_ms}]
    set data [read_chain $hardware_name]
    print_chain_sample $hardware_name DISPATCH_WAIT $sample $elapsed $data
    array set s $data
    if {$s(command_stage) >= 9 && $s(mode_master_stage) >= 5} {
      set ok 1
      puts [format "CLOSURE_DISPATCH_CONFIRMED board=%s sample=%03d COMMAND_STAGE=%s PERSIST_MODE_MASTER_STAGE=%s" \
        $hardware_name $sample [fmt32 $s(command_stage)] [fmt32 $s(mode_master_stage)]]
      break
    }
    if {$::gap_ms > 0} { after $::gap_ms }
  }
  if {!$ok} {
    puts [format "CLOSURE_DISPATCH_TIMEOUT board=%s timeout_ms=10000" $hardware_name]
  }
  return $ok
}

proc delta32 {first last} {
  if {$first < 0 || $last < 0} { return INVALID }
  return [expr {(($last & 0xffffffff) - ($first & 0xffffffff)) & 0xffffffff}]
}

proc ratio {num den} {
  if {![string is integer -strict $num] || ![string is integer -strict $den] ||
      $num < 0 || $den <= 0} { return NA }
  return [format %.6f [expr {double($num) / double($den)}]]
}

proc phase_delta {hardware_name phase first_data last_data} {
  array set first $first_data
  array set last $last_data
  set ref_delta [delta32 $first(dmtd_ref_event) $last(dmtd_ref_event)]
  set fb_delta [delta32 $first(dmtd_fb_event) $last(dmtd_fb_event)]
  set accepted_delta INVALID
  if {[string is integer -strict $ref_delta] && [string is integer -strict $fb_delta]} {
    set accepted_delta [expr {$ref_delta + $fb_delta}]
  }
  set qualified_ref_delta [delta32 $first(dmtd_ref_qualified) $last(dmtd_ref_qualified)]
  set qualified_fb_delta [delta32 $first(dmtd_fb_qualified) $last(dmtd_fb_qualified)]
  set tag_delta [delta32 $first(tag_valid) $last(tag_valid)]
  set trr_write_delta [delta32 $first(trr_write) $last(trr_write)]
  set trr_pop_delta [delta32 $first(trr_pop) $last(trr_pop)]
  set irq_delta [delta32 $first(irq) $last(irq)]
  set helper_delta [delta32 $first(helper) $last(helper)]
  set boot_delta [delta32 $first(boot_generation) $last(boot_generation)]
  set cpu_reset_delta [delta32 $first(cpu_reset_count) $last(cpu_reset_count)]
  set wr_core_reset_delta [delta32 $first(wr_core_reset_count) $last(wr_core_reset_count)]
  set si_config_drop_delta [delta32 $first(si_config_drop_count) $last(si_config_drop_count)]
  puts [format "CLOSURE_WINDOW_DELTA board=%s phase=%s DMTD_ACCEPT_DELTA=%s DMTD_REF_EVENT_DELTA=%s DMTD_FB_EVENT_DELTA=%s DMTD_REF_QUALIFIED_DELTA=%s DMTD_FB_QUALIFIED_DELTA=%s TAG_VALID_DELTA=%s TRR_WRITE_DELTA=%s TRR_POP_DELTA=%s IRQ_DELTA=%s HELPER_UPDATE_DELTA=%s BOOT_GENERATION_DELTA=%s CPU_RESET_COUNT_DELTA=%s WR_CORE_RESET_COUNT_DELTA=%s SI_CONFIG_DROP_COUNT_DELTA=%s" \
    $hardware_name $phase $accepted_delta $ref_delta $fb_delta \
    $qualified_ref_delta $qualified_fb_delta $tag_delta $trr_write_delta \
    $trr_pop_delta $irq_delta $helper_delta $boot_delta $cpu_reset_delta \
    $wr_core_reset_delta $si_config_drop_delta]
  puts [format "CLOSURE_WINDOW_RATIOS board=%s phase=%s TAG_PER_DMTD=%s TRR_WRITE_PER_TAG=%s TRR_POP_PER_TRR_WRITE=%s IRQ_PER_TRR_POP=%s HELPER_PER_IRQ=%s" \
    $hardware_name $phase [ratio $tag_delta $accepted_delta] \
    [ratio $trr_write_delta $tag_delta] [ratio $trr_pop_delta $trr_write_delta] \
    [ratio $irq_delta $trr_pop_delta] [ratio $helper_delta $irq_delta]]
  return [list $accepted_delta $tag_delta $trr_write_delta $trr_pop_delta \
    $irq_delta $helper_delta $boot_delta $cpu_reset_delta \
    $wr_core_reset_delta $si_config_drop_delta]
}

proc classify_measurement {hardware_name is_master dispatch_ok deltas} {
  lassign $deltas accepted tag trr_write trr_pop irq helper boot cpu_reset wr_core_reset si_drop
  if {!$is_master} {
    puts [format "CLOSURE_CLASSIFICATION board=%s result=PASSIVE_CONTROL DMTD_ACCEPT_DELTA=%s TAG_VALID_DELTA=%s TRR_WRITE_DELTA=%s TRR_POP_DELTA=%s IRQ_DELTA=%s HELPER_UPDATE_DELTA=%s BOOT_GENERATION_DELTA=%s CPU_RESET_COUNT_DELTA=%s WR_CORE_RESET_COUNT_DELTA=%s SI_CONFIG_DROP_COUNT_DELTA=%s" \
      $hardware_name $accepted $tag $trr_write $trr_pop $irq $helper \
      $boot $cpu_reset $wr_core_reset $si_drop]
    return PASSIVE_CONTROL
  }
  set positive 1
  foreach value [list $accepted $tag $trr_write $trr_pop $irq $helper] {
    if {![string is integer -strict $value] || $value <= 0} { set positive 0 }
  }
  set no_reset 1
  foreach value [list $boot $cpu_reset $wr_core_reset $si_drop] {
    if {![string is integer -strict $value] || $value != 0} { set no_reset 0 }
  }
  set result NOT_PASS
  if {$dispatch_ok && $positive && $no_reset} {
    set result STEP4_EVENT_CHAIN_PASS
  } elseif {!$dispatch_ok} {
    set result INVALID_NO_VALID_MODE_MASTER_DISPATCH
  } elseif {!$positive} {
    set result NEXT_BOUNDARY_IS_FIRST_ZERO_COUNTER
  } elseif {!$no_reset} {
    set result RESET_OR_REENTRY_OBSERVED
  }
  puts [format "CLOSURE_CLASSIFICATION board=%s result=%s DMTD_ACCEPT_DELTA=%s TAG_VALID_DELTA=%s TRR_WRITE_DELTA=%s TRR_POP_DELTA=%s IRQ_DELTA=%s HELPER_UPDATE_DELTA=%s BOOT_GENERATION_DELTA=%s CPU_RESET_COUNT_DELTA=%s WR_CORE_RESET_COUNT_DELTA=%s SI_CONFIG_DROP_COUNT_DELTA=%s" \
    $hardware_name $result $accepted $tag $trr_write $trr_pop $irq $helper \
    $boot $cpu_reset $wr_core_reset $si_drop]
  return $result
}

proc run_board {hardware_name device_name} {
  puts [format "=== CLOSURE_BOARD %s ===" $hardware_name]
  start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
  wb_sync_toggle $hardware_name
  set start_ms [clock milliseconds]
  set sample 0
  set dispatch_ok 0
  if {![wait_ready_gate $hardware_name $start_ms]} {
    puts [format "CLOSURE_BOARD_RESULT board=%s result=GATE_TIMEOUT" $hardware_name]
    return
  }

  set baseline [capture_phase $hardware_name BASELINE $::baseline_ms $start_ms sample]
  set baseline_count [lindex $baseline 0]
  set baseline_first [lindex $baseline 1]
  set baseline_last [lindex $baseline 2]
  puts [format "CLOSURE_PHASE_DONE board=%s phase=BASELINE samples=%d" $hardware_name $baseline_count]
  if {[string first "1-11.1" $hardware_name] >= 0} {
    inject_mode_master $hardware_name $sample
    puts [format "CLOSURE_STIMULUS_SENT board=%s sample=%03d command=mode_master_once bytes=12" \
      $hardware_name $sample]
    set dispatch_ok [wait_dispatch $hardware_name $start_ms sample]
  } else {
    puts [format "CLOSURE_SLAVE_PASSIVE board=%s sample=%03d stimulus=none" \
      $hardware_name $sample]
    set dispatch_ok 1
  }

  set measurement [capture_phase $hardware_name MEASUREMENT $::measurement_ms $start_ms sample]
  set measurement_count [lindex $measurement 0]
  set measurement_first [lindex $measurement 1]
  set measurement_last [lindex $measurement 2]
  array set measurement_last_data $measurement_last
  puts [format "CLOSURE_PHASE_DONE board=%s phase=MEASUREMENT samples=%d" \
    $hardware_name $measurement_count]
  set deltas [phase_delta $hardware_name MEASUREMENT $measurement_first $measurement_last]

  set post [capture_phase $hardware_name POST $::post_ms $start_ms sample]
  set post_count [lindex $post 0]
  set post_first [lindex $post 1]
  set post_last [lindex $post 2]
  array set post_last_data $post_last
  puts [format "CLOSURE_PHASE_DONE board=%s phase=POST samples=%d" $hardware_name $post_count]
  phase_delta $hardware_name POST $post_first $post_last

  set is_master [expr {[string first "1-11.1" $hardware_name] >= 0}]
  set result [classify_measurement $hardware_name $is_master $dispatch_ok $deltas]
  puts [format "CLOSURE_BOARD_RESULT board=%s result=%s dispatch_ok=%d baseline_samples=%d measurement_samples=%d post_samples=%d final_command_stage=%s final_mode_master_stage=%s" \
    $hardware_name $result $dispatch_ok $baseline_count $measurement_count \
    $post_count [fmt32 $post_last_data(command_stage)] [fmt32 $post_last_data(mode_master_stage)]]
}

puts [format "CLOSURE_CONFIG experiment=EXP-WRPC-STEP4-DMTD-ACCEPT-TO-HELPER-CLOSURE-20260828 ready_timeout_ms=%d stable_ms=%d baseline_ms=%d measurement_ms=%d post_ms=%d gap_ms=%d poll_attempts=%d master_command=mode_master_once slave_stimulus=none" \
  $ready_timeout_ms $stable_ms $baseline_ms $measurement_ms $post_ms $gap_ms $poll_attempts]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  catch { end_insystem_source_probe }
  if {[catch {
    set ::wb_toggle($hardware_name) 0
    run_board $hardware_name [lindex $device_names 0]
  } error_message]} {
    puts [format "CLOSURE_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts CLOSURE_DONE
