# Step5 Main-DAC direction/authority identification.
#
# This experiment uses the already-programmed image.  It waits for the
# settled Step4B/Helper/Main gate, freezes only Main VCO control through the
# normal shell command, applies one low-rail DAC code and one +1024-code DAC
# step, and measures the coherent Main frequency trace in both phases.
# The final command releases the VCO freeze so the board is not left frozen.

package require ::quartus::insystem_source_probe

set board_filter "DE5 [1-11.2]"
set gate_timeout_s 120
set phase_samples 20
set phase_gap_ms 500
if {[llength $argv] >= 1} { set board_filter [lindex $argv 0] }
if {[llength $argv] >= 2} { set gate_timeout_s [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set phase_samples [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set phase_gap_ms [expr {int([lindex $argv 3])}] }
if {$gate_timeout_s <= 0 || $phase_samples <= 0 || $phase_gap_ms < 0} {
  error "gate_timeout_s and phase_samples must be > 0; phase_gap_ms must be >= 0"
}

array set ::wb_toggle {}
set ::poll_attempts 100

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc signed32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  if {$word >= 0x80000000} { return [expr {$word - 0x100000000}] }
  return $word
}

proc field32 {value low width} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($word >> $low) & $mask}]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
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

proc wb_command_hex {toggle write addr data} {
  set data32 [expr {$data & 0xffffffff}]
  set addr32 [expr {$addr & 0xffffffff}]
  set high32 [expr {($data32 >> 26) & 0x3f}]
  set low64 [expr {(($data32 & 0x03ffffff) << 38) |
                   (($addr32 & 0xffffffff) << 6) |
                   (($write & 1) << 1) |
                   (($toggle & 1) | (0xf << 2))}]
  return [format %08X%016X $high32 $low64]
}

proc wb_read {hardware_name addr} {
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} { return INVALID }
  after 5
  for {set n 0} {$n < $::poll_attempts} {incr n} {
    set value [probe_read 1]
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
  set cmd [wb_command_hex $toggle 1 $addr $data]
  if {[catch {
    write_source_data -instance_index 1 -value $cmd -value_in_hex
  }]} { return 0 }
  after 5
  for {set n 0} {$n < $::poll_attempts} {incr n} {
    set value [probe_read 1]
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} { return 1 }
    }
    after 1
  }
  return 0
}

proc send_vuart {hardware_name command} {
  set index 0
  set ok 1
  foreach character [split $command ""] {
    scan $character %c byte
    set result [wb_write $hardware_name 0x00100510 $byte]
    puts [format "DAC_ID_VUART board=%s index=%02d BYTE=0x%02X WB_RESULT=%d" \
      $hardware_name $index $byte $result]
    if {!$result} { set ok 0 }
    incr index
  }
  return $ok
}

proc read_main_trace {hardware_name} {
  for {set attempt 0} {$attempt < 8} {incr attempt} {
    set epoch_before [word32 [wb_read $hardware_name 0x00100B58]]
    if {$epoch_before < 0 || ($epoch_before & 1)} { after 1; continue }
    set dref [signed32 [wb_read $hardware_name 0x00100B5C]]
    set dout [signed32 [wb_read $hardware_name 0x00100B60]]
    set freq_error [signed32 [wb_read $hardware_name 0x00100B64]]
    set pi_output [signed32 [wb_read $hardware_name 0x00100B70]]
    set clamp_side [signed32 [wb_read $hardware_name 0x00100B74]]
    set lock_count [word32 [wb_read $hardware_name 0x00100B78]]
    set update_count [word32 [wb_read $hardware_name 0x00100B90]]
    set state [word32 [wb_read $hardware_name 0x00100B9C]]
    set y_min [signed32 [wb_read $hardware_name 0x00100BA0]]
    set y_max [signed32 [wb_read $hardware_name 0x00100BA4]]
    set magic [word32 [wb_read $hardware_name 0x00100BDC]]
    set epoch_after [word32 [wb_read $hardware_name 0x00100B58]]
    if {$epoch_before == $epoch_after && $epoch_after >= 0 &&
        !($epoch_after & 1) && $magic == 1 &&
        $dref ne "INVALID" && $dout ne "INVALID" &&
        $freq_error ne "INVALID" && $pi_output ne "INVALID" &&
        $clamp_side ne "INVALID" && $lock_count >= 0 &&
        $update_count >= 0 && $state >= 0 && $y_min ne "INVALID" &&
        $y_max ne "INVALID"} {
      return [list 1 $epoch_after $dref $dout $freq_error $pi_output \
        $clamp_side $lock_count $update_count $state $y_min $y_max $magic]
    }
    after 1
  }
  return [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID \
    INVALID INVALID INVALID INVALID INVALID INVALID]
}

proc gate_status {hardware_name} {
  set trace [read_main_trace $hardware_name]
  foreach {trace_ok epoch dref dout freq_error pi_output clamp_side lock_count \
      update_count state y_min y_max magic} $trace break
  set helper_state [wb_read $hardware_name 0x00100ABC]
  set helper_locked [field32 $helper_state 0 1]
  set main_enabled INVALID
  if {$trace_ok} { set main_enabled [expr {$state & 1}] }
  return [list $trace_ok $helper_locked $main_enabled $y_min $y_max \
    $freq_error $pi_output $epoch $update_count]
}

proc run_phase {hardware_name phase code samples gap_ms} {
  set unique_count 0
  set invalid_count 0
  set sum 0.0
  set first INVALID
  set last INVALID
  set last_key ""
  set start_ms [clock milliseconds]
  for {set sample 1} {$sample <= $samples} {incr sample} {
    set deadline [expr {$start_ms + (($sample - 1) * $gap_ms)}]
    set now [clock milliseconds]
    if {$now < $deadline} { after [expr {$deadline - $now}] }
    set trace [read_main_trace $hardware_name]
    foreach {trace_ok epoch dref dout freq_error pi_output clamp_side lock_count \
        update_count state y_min y_max magic} $trace break
    set helper_state [wb_read $hardware_name 0x00100ABC]
    set helper_locked [field32 $helper_state 0 1]
    set unique 0
    if {$trace_ok} {
      set key [format "%s|%s" $epoch $update_count]
      if {$key ne $last_key} {
        set last_key $key
        set unique 1
        incr unique_count
        set sum [expr {$sum + double($freq_error)}]
        if {$first eq "INVALID"} { set first $freq_error }
        set last $freq_error
      }
    } else {
      incr invalid_count
    }
    puts [format "DAC_ID_SAMPLE phase=%s sample=%d elapsed_ms=%d TRACE_VALID=%d TRACE_UNIQUE=%d DAC_CODE=%d EPOCH=%s UPDATE_COUNT=%s DREF=%s DOUT=%s FREQ_ERROR=%s PI_OUTPUT=%s CLAMP_SIDE=%s MAIN_ENABLED=%s MAIN_FREQ_LOCKED=%s MAIN_PHASE_LOCKED=%s MAIN_LOCKED=%s HELPER_LOCKED=%s" \
      $phase $sample [expr {[clock milliseconds] - $start_ms}] $trace_ok $unique \
      $code $epoch $update_count $dref $dout $freq_error $pi_output $clamp_side \
      [expr {$trace_ok ? ($state & 1) : "INVALID"}] \
      [expr {$trace_ok ? (($state >> 1) & 1) : "INVALID"}] \
      [expr {$trace_ok ? (($state >> 2) & 1) : "INVALID"}] \
      [expr {$trace_ok ? (($state >> 3) & 1) : "INVALID"}] \
      $helper_locked]
    flush stdout
  }
  set mean INVALID
  if {$unique_count > 0} { set mean [expr {$sum / double($unique_count)}] }
  return [list $unique_count $invalid_count $mean $first $last \
    [expr {[clock milliseconds] - $start_ms}]]
}

puts [format "DAC_ID_CONFIG board_filter=%s gate_timeout_s=%d phase_samples=%d phase_gap_ms=%d experiment=EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MAIN-DAC-DIRECTION-AUTHORITY-IDENTIFICATION-20260902 existing_image=88604a5+7585a06 frozen_fit=1 no_reprogram=1" \
  $board_filter $gate_timeout_s $phase_samples $phase_gap_ms]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && $hardware_name ne $board_filter} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  set frozen 0
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name

    set gate_start [clock seconds]
    set gate_ok 0
    set gate_last [list 0 INVALID INVALID INVALID INVALID INVALID INVALID INVALID INVALID]
    while {[expr {[clock seconds] - $gate_start}] < $gate_timeout_s} {
      set gate_last [gate_status $hardware_name]
      foreach {trace_ok helper_locked main_enabled y_min y_max freq_error pi_output epoch update_count} $gate_last break
      puts [format "DAC_ID_GATE elapsed_s=%d TRACE_VALID=%s HELPER_LOCKED=%s MAIN_ENABLED=%s FREQ_ERROR=%s PI_OUTPUT=%s EPOCH=%s UPDATE_COUNT=%s" \
        [expr {[clock seconds] - $gate_start}] $trace_ok $helper_locked $main_enabled \
        $freq_error $pi_output $epoch $update_count]
      flush stdout
      if {$trace_ok && $helper_locked == 1 && $main_enabled == 1 &&
          $y_min ne "INVALID" && $y_max ne "INVALID"} {
        set gate_ok 1
        break
      }
      after 500
    }
    if {!$gate_ok} {
      error "DAC_ID_GATE_TIMEOUT helper_locked/main_enabled gate not reached"
    }
    set dac_a $y_min
    set dac_b [expr {$dac_a + 1024}]
    if {$dac_a < 0 || $dac_b > $y_max} {
      error "DAC_ID_CODE_RANGE_INVALID y_min=$y_min y_max=$y_max dac_a=$dac_a dac_b=$dac_b"
    }
    puts [format "DAC_ID_GATE_PASS DAC_CODE_A=%d DAC_CODE_B=%d Y_MIN=%d Y_MAX=%d" $dac_a $dac_b $y_min $y_max]
    flush stdout

    if {![send_vuart $hardware_name "ptrack vco-freeze\n"]} {
      error "DAC_ID_FREEZE_COMMAND_FAILED"
    }
    set frozen 1
    after 500
    if {![send_vuart $hardware_name [format "pll sdac 0 %d\n" $dac_a]]} {
      error "DAC_ID_PHASE_A_COMMAND_FAILED"
    }
    after 500
    set phase_a [run_phase $hardware_name A $dac_a $phase_samples $phase_gap_ms]
    foreach {a_unique a_invalid a_mean a_first a_last a_elapsed} $phase_a break
    puts [format "DAC_ID_PHASE_SUMMARY phase=A DAC_CODE=%d TRACE_UNIQUE=%d INVALID=%d FREQ_ERROR_MEAN=%s FREQ_ERROR_FIRST=%s FREQ_ERROR_FINAL=%s ELAPSED_MS=%d" \
      $dac_a $a_unique $a_invalid $a_mean $a_first $a_last $a_elapsed]
    flush stdout

    if {![send_vuart $hardware_name [format "pll sdac 0 %d\n" $dac_b]]} {
      error "DAC_ID_PHASE_B_COMMAND_FAILED"
    }
    after 500
    set phase_b [run_phase $hardware_name B $dac_b $phase_samples $phase_gap_ms]
    foreach {b_unique b_invalid b_mean b_first b_last b_elapsed} $phase_b break
    puts [format "DAC_ID_PHASE_SUMMARY phase=B DAC_CODE=%d TRACE_UNIQUE=%d INVALID=%d FREQ_ERROR_MEAN=%s FREQ_ERROR_FIRST=%s FREQ_ERROR_FINAL=%s ELAPSED_MS=%d" \
      $dac_b $b_unique $b_invalid $b_mean $b_first $b_last $b_elapsed]
    flush stdout

    if {$a_unique > 0 && $b_unique > 0} {
      set delta_dac [expr {$dac_b - $dac_a}]
      set delta_freq [expr {$b_mean - $a_mean}]
      set plant_sign INCONCLUSIVE
      if {$delta_freq > 0} { set plant_sign POSITIVE }
      if {$delta_freq < 0} { set plant_sign NEGATIVE }
      set approx_gain [expr {$delta_freq / double($delta_dac)}]
      puts [format "DAC_ID_RESULT DAC_CODE_A=%d DAC_CODE_B=%d DELTA_DAC=%d FREQ_ERROR_A_MEAN=%s FREQ_ERROR_B_MEAN=%s DELTA_FREQ_ERROR=%s PLANT_SIGN=%s APPROX_MAIN_DAC_GAIN=%s" \
        $dac_a $dac_b $delta_dac $a_mean $b_mean $delta_freq $plant_sign $approx_gain]
    } else {
      puts "DAC_ID_RESULT PLANT_SIGN=INCONCLUSIVE APPROX_MAIN_DAC_GAIN=INVALID"
    }
    flush stdout
    if {$frozen} {
      send_vuart $hardware_name "ptrack unfreeze\n"
      set frozen 0
      after 500
    }
  } error_message]} {
    puts [format "DAC_ID_ERROR board=%s message=%s" $hardware_name $error_message]
    if {$frozen} { catch {send_vuart $hardware_name "ptrack unfreeze\n"} }
  }
  catch { end_insystem_source_probe }
}

puts "DAC_ID_DONE"
