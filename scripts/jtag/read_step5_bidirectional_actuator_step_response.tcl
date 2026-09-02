# Step5 lane 2: bidirectional SI5340 actuator step-response identification.
#
# This is a read/drive experiment for the dedicated plant-identification
# image.  The Slave image disables the normal HPLL tracker and bootstrap;
# source 36 asks the FPGA controller for one bounded burst, source 38 selects
# the direction (0=FDEC, 1=FINC), and source 40 selects the number of physical
# transactions.  The FPGA serializes the burst; this script never bit-bangs
# individual SI5340 transactions.
#
# Usage:
#   quartus_stp -t read_step5_bidirectional_actuator_step_response.tcl
#   quartus_stp -t read_step5_bidirectional_actuator_step_response.tcl \
#     ?baseline_seconds? ?burst_size? ?settle_updates? ?window_updates? \
#     ?sample_gap_ms? ?completion_poll_ms? ?max_completion_polls? ?board_filter?

package require ::quartus::insystem_source_probe

set baseline_seconds 5
set burst_size 128
set settle_updates 5
set window_updates 10
set sample_gap_ms 100
set completion_poll_ms 100
set max_completion_polls 2000
set board_filter ""
if {[llength $argv] >= 1} { set baseline_seconds [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set burst_size [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set settle_updates [expr {int([lindex $argv 2])}] }
if {[llength $argv] >= 4} { set window_updates [expr {int([lindex $argv 3])}] }
if {[llength $argv] >= 5} { set sample_gap_ms [expr {int([lindex $argv 4])}] }
if {[llength $argv] >= 6} { set completion_poll_ms [expr {int([lindex $argv 5])}] }
if {[llength $argv] >= 7} { set max_completion_polls [expr {int([lindex $argv 6])}] }
if {[llength $argv] >= 8} { set board_filter [lindex $argv 7] }
if {$baseline_seconds <= 0 || $burst_size <= 0 || $burst_size > 65535 ||
    $settle_updates < 0 || $window_updates <= 0 || $sample_gap_ms <= 0 ||
    $completion_poll_ms <= 0 || $max_completion_polls <= 0} {
  error "invalid experiment arguments"
}

array set ::wb_toggle {}
array set ::snap {}
set ::wb_debug_count 0

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]+$} $value]
}

proc numeric {value} {
  return [string is integer -strict $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 8} {
    set text [string range $text end-7 end]
  }
  scan $text %x word
  return [expr {$word & 0xffffffff}]
}

proc word64 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  scan $text %x word
  if {$word < 0} {
    set word [expr {$word + 0x10000000000000000}]
  }
  return $word
}

proc signed32 {value} {
  set word [word32 $value]
  if {$word < 0} { return INVALID }
  if {$word >= 0x80000000} {
    return [expr {$word - 0x100000000}]
  }
  return $word
}

proc field64 {word low width} {
  if {$word < 0} { return INVALID }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($word >> $low) & $mask}]
}

proc display_value {value} {
  if {![is_hex $value]} { return $value }
  return [string toupper $value]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

# The WB mailbox uses a preload followed by a toggle-only commit.  The
# completion toggle and active bit are checked before returning the payload.
proc wb_read {hardware_name addr} {
  if {![info exists ::wb_toggle($hardware_name)]} {
    set ::wb_toggle($hardware_name) 0
  }
  set preload_toggle $::wb_toggle($hardware_name)
  set preload_cmd [expr {$preload_toggle | (0xf << 2) |
                          (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 \
      -value [format %024X $preload_cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 2

  set expected_toggle [expr {$preload_toggle ^ 1}]
  set ::wb_toggle($hardware_name) $expected_toggle
  set cmd [expr {$expected_toggle | (0xf << 2) |
                  (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 \
      -value [format %024X $cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 5

  for {set poll 0} {$poll < 120} {incr poll} {
    if {[catch {set raw [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set raw INVALID
    }
    set word [word64 $raw]
    if {$addr == 0x00100B00 && $::wb_debug_count < 8} {
      set debug_done INVALID
      set debug_active INVALID
      if {$word >= 0} {
        set debug_done [field64 $word 35 1]
        set debug_active [field64 $word 36 1]
      }
      puts [format "BIDIR_WB_DEBUG raw=%s word=%s done=%s active=%s expected=%s" \
        $raw $word $debug_done $debug_active $expected_toggle]
      incr ::wb_debug_count
      flush stdout
    }
    if {$word >= 0} {
      set done_toggle [field64 $word 35 1]
      set active [field64 $word 36 1]
      if {$done_toggle == $expected_toggle && $active == 0} {
        return [format %08X [expr {$word & 0xffffffff}]]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc wb_sync_toggle {hardware_name} {
  set raw [probe_read 1]
  set word [word64 $raw]
  if {$word < 0} {
    set ::wb_toggle($hardware_name) 0
  } else {
    set ::wb_toggle($hardware_name) [field64 $word 35 1]
  }
}

proc source_write {instance value} {
  if {[catch {
    write_source_data -instance_index $instance \
      -value [format %016X $value] -value_in_hex
  } error_message]} {
    error [format "source %d write failed: %s" $instance $error_message]
  }
  after 10
}

proc force_pulse {} {
  source_write 36 1
  source_write 36 0
  puts "BIDIR_TRIGGER_PULSE source=36 transition=0->1->0"
  flush stdout
}

proc snap_key {hardware_name tag} {
  return "${hardware_name}|${tag}"
}

proc snap_get {hardware_name tag field} {
  set key [snap_key $hardware_name $tag]
  if {[info exists ::snap($key,$field)]} {
    return $::snap($key,$field)
  }
  return INVALID
}

proc counter_delta {first last width} {
  if {![numeric $first] || ![numeric $last]} { return INVALID }
  set modulus [expr {1 << $width}]
  if {$last >= $first} { return [expr {$last - $first}] }
  return [expr {$last + $modulus - $first}]
}

proc value_delta {first last} {
  if {![numeric $first] || ![numeric $last]} { return INVALID }
  return [expr {$last - $first}]
}

proc response_sign {value} {
  if {![numeric $value]} { return INVALID }
  if {$value > 0} { return POSITIVE }
  if {$value < 0} { return NEGATIVE }
  return ZERO
}

proc response_magnitude {value} {
  if {![numeric $value]} { return INVALID }
  return [expr {abs($value)}]
}

# Return: per-address mailbox readings.  The WDIAGS fields are read one by one;
# the epoch is retained as a diagnostic value, but this experiment does not
# claim an atomic multi-register snapshot.
proc read_coherent_measurement {hardware_name} {
  set epoch_raw [wb_read $hardware_name 0x00100B00]
  set epoch [word32 $epoch_raw]
  set tag_raw [wb_read $hardware_name 0x00100B04]
  set expected_raw [wb_read $hardware_name 0x00100B08]
  set freq_raw [wb_read $hardware_name 0x00100B0C]
  set preclamp_raw [wb_read $hardware_name 0x00100B10]
  set helper_error_raw [wb_read $hardware_name 0x00100B14]
  set update_raw [wb_read $hardware_name 0x00100B18]
  set helper_output_raw [wb_read $hardware_name 0x00100B1C]
  set ref_accept_raw [wb_read $hardware_name 0x00100B20]
  set fb_accept_raw [wb_read $hardware_name 0x00100B24]
  set dmtd_ref_raw [wb_read $hardware_name 0x00100298]
  set dmtd_fb_raw [wb_read $hardware_name 0x0010029C]
  set rxerr_raw [wb_read $hardware_name 0x00100A60]
  set pstat_raw [wb_read $hardware_name 0x00100A0C]
  set helper_state_raw [wb_read $hardware_name 0x00100ABC]
  return [list 1 $epoch [signed32 $tag_raw] \
    [signed32 $expected_raw] [signed32 $freq_raw] \
    [signed32 $preclamp_raw] [signed32 $helper_error_raw] \
    [word32 $update_raw] [signed32 $helper_output_raw] \
    [word32 $ref_accept_raw] [word32 $fb_accept_raw] \
    [word32 $dmtd_ref_raw] [word32 $dmtd_fb_raw] \
    [word32 $rxerr_raw] [word32 $pstat_raw] [word32 $helper_state_raw]]
}

proc read_snapshot {hardware_name tag} {
  set measurement [read_coherent_measurement $hardware_name]
  foreach {accepted epoch tag_delta expected_delta freq_error preclamp \
           helper_error update_count helper_output ref_accept fb_accept \
           dmtd_ref_raw dmtd_fb_raw rxerr pstat helper_state} $measurement break

  set burst_raw [probe_read 41]
  set actuator_raw [probe_read 49]
  set polarity_raw [probe_read 38]
  set tracker_raw [probe_read 39]
  set reset_raw [probe_read 27]
  set generation_raw [probe_read 26]
  set burst [word64 $burst_raw]
  set actuator [word64 $actuator_raw]
  set polarity [word64 $polarity_raw]
  set tracker [word64 $tracker_raw]
  set reset [word64 $reset_raw]
  set generation [word64 $generation_raw]
  set key [snap_key $hardware_name $tag]

  set ::snap($key,accepted) $accepted
  set ::snap($key,epoch) $epoch
  set ::snap($key,tag_delta) $tag_delta
  set ::snap($key,expected_delta) $expected_delta
  set ::snap($key,freq_error) $freq_error
  set ::snap($key,preclamp) $preclamp
  set ::snap($key,helper_error) $helper_error
  set ::snap($key,update_count) $update_count
  set ::snap($key,helper_output) $helper_output
  set ::snap($key,ref_accept) $ref_accept
  set ::snap($key,fb_accept) $fb_accept
  set ::snap($key,dmtd_ref_raw) $dmtd_ref_raw
  set ::snap($key,dmtd_fb_raw) $dmtd_fb_raw
  set ::snap($key,rxerr) $rxerr
  set ::snap($key,pstat) $pstat
  set ::snap($key,helper_state) $helper_state
  set ::snap($key,burst_trigger) [field64 $burst 0 16]
  set ::snap($key,forced_admitted) [field64 $burst 16 16]
  set ::snap($key,forced_completed) [field64 $burst 32 16]
  set ::snap($key,total_dco) [field64 $burst 48 16]
  set ::snap($key,finc_completed) [field64 $actuator 0 16]
  set ::snap($key,fdec_completed) [field64 $actuator 16 16]
  set ::snap($key,forced_total) [field64 $actuator 32 16]
  set ::snap($key,active_direction) [field64 $actuator 48 1]
  set ::snap($key,direction_sync) [field64 $actuator 49 1]
  set ::snap($key,force_seen) [field64 $actuator 50 1]
  set ::snap($key,remaining) [field64 $actuator 51 13]
  set ::snap($key,direction_source) [field64 $polarity 0 1]
  set ::snap($key,tracker_target) [field64 $tracker 0 16]
  set ::snap($key,tracker_applied) [field64 $tracker 16 16]
  set ::snap($key,normal_requested) [field64 $tracker 32 16]
  set ::snap($key,normal_completed) [field64 $tracker 48 16]
  set ::snap($key,boot_generation) [field64 $generation 32 32]
  set ::snap($key,cpu_reset) [field64 $reset 16 8]
  set ::snap($key,wr_reset) [field64 $reset 24 8]
  set ::snap($key,si_drop) [field64 $reset 40 8]

  puts [format "BIDIR_SNAPSHOT board=%s tag=%s ACCEPTED=%s EPOCH=%s TAG_DELTA=%s EXPECTED_DELTA=%s FREQ_ERROR=%s PRECLAMP_ERROR=%s HELPER_ERROR=%s HELPER_OUTPUT=%s UPDATE_COUNT=%s DMTD_REF_ACCEPT_COUNT=%s DMTD_FB_ACCEPT_COUNT=%s DMTD_REF_RAW=%s DMTD_FB_RAW=%s RXERR=%s PSTAT=%s HELPER_STATE=%s FINC_COMPLETED=%s FDEC_COMPLETED=%s FORCED_COMPLETED=%s FORCED_REMAINING=%s DIRECTION_SOURCE=%s DIRECTION_ACTIVE=%s NORMAL_REQUESTED=%s NORMAL_COMPLETED=%s TOTAL_DCO=%s BOOT_GENERATION=%s CPU_RESET=%s WR_CORE_RESET=%s SI_CONFIG_DROP=%s" \
    $hardware_name $tag $accepted $epoch $tag_delta $expected_delta \
    $freq_error $preclamp $helper_error $helper_output $update_count \
    $ref_accept $fb_accept $dmtd_ref_raw $dmtd_fb_raw $rxerr $pstat \
    $helper_state [snap_get $hardware_name $tag finc_completed] \
    [snap_get $hardware_name $tag fdec_completed] \
    [snap_get $hardware_name $tag forced_total] \
    [snap_get $hardware_name $tag remaining] \
    [snap_get $hardware_name $tag direction_source] \
    [snap_get $hardware_name $tag active_direction] \
    [snap_get $hardware_name $tag normal_requested] \
    [snap_get $hardware_name $tag normal_completed] \
    [snap_get $hardware_name $tag total_dco] \
    [snap_get $hardware_name $tag boot_generation] \
    [snap_get $hardware_name $tag cpu_reset] \
    [snap_get $hardware_name $tag wr_reset] \
    [snap_get $hardware_name $tag si_drop]
  ]
  flush stdout
}

proc write_direction {value} {
  if {$value != 0 && $value != 1} { error "direction must be 0 or 1" }
  source_write 38 $value
  puts [format "BIDIR_DIRECTION source=38 value=%d meaning=%s" $value \
    [expr {$value ? "FINC" : "FDEC"}]]
  flush stdout
}

proc wait_for_completion {hardware_name before_tag direction burst_size \
                          poll_ms max_polls trigger_ms} {
  set field [expr {$direction ? "finc_completed" : "fdec_completed"}]
  set base [snap_get $hardware_name $before_tag $field]
  if {![numeric $base]} {
    return [list 0 INVALID 0 INVALID]
  }
  for {set poll 1} {$poll <= $max_polls} {incr poll} {
    after $poll_ms
    set raw [probe_read 49]
    set word [word64 $raw]
    set current [field64 $word [expr {$direction ? 0 : 16}] 16]
    set forced_total [field64 $word 32 16]
    set remaining [field64 $word 51 13]
    set delta [counter_delta $base $current 16]
    puts [format "BIDIR_COMPLETION_POLL board=%s direction=%s poll=%d FINC_OR_FDEC_COMPLETED=%s DELTA=%s FORCED_COMPLETED=%s REMAINING=%s" \
      $hardware_name [expr {$direction ? "FINC" : "FDEC"}] $poll \
      $current $delta $forced_total $remaining]
    flush stdout
    if {[numeric $delta] && $delta >= $burst_size} {
      return [list 1 $delta [expr {[clock milliseconds] - $trigger_ms}] $poll]
    }
  }
  return [list 0 $delta [expr {[clock milliseconds] - $trigger_ms}] $max_polls]
}

# Take fixed-gap samples until the helper-update counter has advanced by the
# requested settle and window amounts from the post-completion snapshot.
proc collect_settled_window {hardware_name phase base_tag settle_updates \
                              window_updates gap_ms trigger_ms} {
  set base_update [snap_get $hardware_name $base_tag update_count]
  set settle_tag ""
  set first_tag ""
  set last_tag ""
  set settle_ms INVALID
  set target [expr {$settle_updates + $window_updates}]
  set max_samples 300
  for {set sample 1} {$sample <= $max_samples} {incr sample} {
    after $gap_ms
    set tag [format "%s_%03d" $phase $sample]
    read_snapshot $hardware_name $tag
    set update_now [snap_get $hardware_name $tag update_count]
    set update_delta [counter_delta $base_update $update_now 32]
    puts [format "BIDIR_WINDOW_SAMPLE board=%s phase=%s tag=%s UPDATE_DELTA_FROM_COMPLETION=%s" \
      $hardware_name $phase $tag $update_delta]
    flush stdout
    if {$settle_tag eq "" && [numeric $update_delta] &&
        $update_delta >= $settle_updates} {
      set settle_tag $tag
      set first_tag $tag
      set settle_ms [expr {[clock milliseconds] - $trigger_ms}]
    }
    if {$first_tag ne "" && [numeric $update_delta] &&
        $update_delta >= $target} {
      set last_tag $tag
      break
    }
  }
  if {$first_tag eq ""} { set first_tag INVALID }
  if {$last_tag eq ""} { set last_tag $first_tag }
  return [list $first_tag $last_tag $settle_ms $sample]
}

proc emit_phase_result {hardware_name phase before_tag after_tag first_tag \
                        last_tag settle_ms} {
  set freq_immediate [value_delta \
    [snap_get $hardware_name $before_tag freq_error] \
    [snap_get $hardware_name $after_tag freq_error]]
  set freq_settled [value_delta \
    [snap_get $hardware_name $first_tag freq_error] \
    [snap_get $hardware_name $last_tag freq_error]]
  set helper_immediate [value_delta \
    [snap_get $hardware_name $before_tag helper_error] \
    [snap_get $hardware_name $after_tag helper_error]]
  set ref_delta [counter_delta \
    [snap_get $hardware_name $before_tag dmtd_ref_raw] \
    [snap_get $hardware_name $after_tag dmtd_ref_raw] 32]
  set fb_delta [counter_delta \
    [snap_get $hardware_name $before_tag dmtd_fb_raw] \
    [snap_get $hardware_name $after_tag dmtd_fb_raw] 32]
  puts [format "BIDIR_PHASE_RESULT board=%s phase=%s BEFORE=%s AFTER=%s SETTLED_FIRST=%s SETTLED_LAST=%s FINC_COUNT=%s FDEC_COUNT=%s FREQ_ERROR_BEFORE=%s FREQ_ERROR_AFTER=%s FREQ_ERROR_IMMEDIATE_DELTA=%s FREQ_ERROR_IMMEDIATE_SIGN=%s FREQ_ERROR_IMMEDIATE_MAGNITUDE=%s FREQ_ERROR_SETTLED_DELTA=%s FREQ_ERROR_SETTLED_SIGN=%s FREQ_ERROR_SETTLED_MAGNITUDE=%s HELPER_ERROR_IMMEDIATE_DELTA=%s DMTD_REF_DELTA=%s DMTD_FB_DELTA=%s SETTLING_TIME_MS=%s" \
    $hardware_name $phase $before_tag $after_tag $first_tag $last_tag \
    [counter_delta [snap_get $hardware_name $before_tag finc_completed] \
      [snap_get $hardware_name $after_tag finc_completed] 16] \
    [counter_delta [snap_get $hardware_name $before_tag fdec_completed] \
      [snap_get $hardware_name $after_tag fdec_completed] 16] \
    [snap_get $hardware_name $before_tag freq_error] \
    [snap_get $hardware_name $after_tag freq_error] $freq_immediate \
    [response_sign $freq_immediate] [response_magnitude $freq_immediate] \
    $freq_settled [response_sign $freq_settled] \
    [response_magnitude $freq_settled] $helper_immediate $ref_delta $fb_delta \
    $settle_ms]
  flush stdout
}

proc emit_final_summary {hardware_name burst_size finc_before finc_after \
                         fdec_before fdec_after return_final finc_first \
                         finc_last fdec_first fdec_last} {
  set finc_count [counter_delta \
    [snap_get $hardware_name $finc_before finc_completed] \
    [snap_get $hardware_name $finc_after finc_completed] 16]
  set fdec_count [counter_delta \
    [snap_get $hardware_name $fdec_before fdec_completed] \
    [snap_get $hardware_name $fdec_after fdec_completed] 16]
  set finc_freq [value_delta \
    [snap_get $hardware_name $finc_first freq_error] \
    [snap_get $hardware_name $finc_last freq_error]]
  set fdec_freq [value_delta \
    [snap_get $hardware_name $fdec_first freq_error] \
    [snap_get $hardware_name $fdec_last freq_error]]
  set normal_req [counter_delta \
    [snap_get $hardware_name BASELINE_BEFORE normal_requested] \
    [snap_get $hardware_name $return_final normal_requested] 16]
  set normal_done [counter_delta \
    [snap_get $hardware_name BASELINE_BEFORE normal_completed] \
    [snap_get $hardware_name $return_final normal_completed] 16]
  set rxerr_delta [counter_delta \
    [snap_get $hardware_name BASELINE_BEFORE rxerr] \
    [snap_get $hardware_name $return_final rxerr] 32]
  set boot_delta [counter_delta \
    [snap_get $hardware_name BASELINE_BEFORE boot_generation] \
    [snap_get $hardware_name $return_final boot_generation] 32]
  set cpu_delta [counter_delta \
    [snap_get $hardware_name BASELINE_BEFORE cpu_reset] \
    [snap_get $hardware_name $return_final cpu_reset] 8]
  set wr_delta [counter_delta \
    [snap_get $hardware_name BASELINE_BEFORE wr_reset] \
    [snap_get $hardware_name $return_final wr_reset] 8]
  set si_delta [counter_delta \
    [snap_get $hardware_name BASELINE_BEFORE si_drop] \
    [snap_get $hardware_name $return_final si_drop] 8]
  set opposite INCONCLUSIVE
  if {[numeric $finc_freq] && [numeric $fdec_freq] &&
      $finc_freq != 0 && $fdec_freq != 0} {
    set opposite [expr {$finc_freq * $fdec_freq < 0 ? "OPPOSITE" : "SAME_SIGN"}]
  }
  set accounting_pass 0
  if {[numeric $finc_count] && [numeric $fdec_count] &&
      [numeric $normal_req] && [numeric $normal_done] &&
      [numeric $rxerr_delta] && [numeric $boot_delta] &&
      [numeric $cpu_delta] && [numeric $wr_delta] &&
      [numeric $si_delta] && $finc_count == $burst_size &&
      $fdec_count == $burst_size && $normal_req == 0 &&
      $normal_done == 0 && $rxerr_delta == 0 && $boot_delta == 0 &&
      $cpu_delta == 0 && $wr_delta == 0 && $si_delta == 0} {
    set accounting_pass 1
  }
  puts [format "BIDIR_SUMMARY board=%s FINC_COUNT=%s FDEC_COUNT=%s EXPECTED_COUNT=%d FINC_SETTLED_FREQ_DELTA=%s FINC_SETTLED_FREQ_SIGN=%s FINC_SETTLED_FREQ_MAGNITUDE=%s FDEC_SETTLED_FREQ_DELTA=%s FDEC_SETTLED_FREQ_SIGN=%s FDEC_SETTLED_FREQ_MAGNITUDE=%s DIRECTION_RESPONSE=%s NORMAL_REQUEST_DELTA=%s NORMAL_COMPLETED_DELTA=%s RXERR_DELTA=%s RESET_BOOT_GENERATION_DELTA=%s RESET_CPU_DELTA=%s RESET_WR_CORE_DELTA=%s RESET_SI_CONFIG_DELTA=%s ACTUATOR_ACCOUNTING=%s STEP5_COMPLETE=NO MERGE_APPROVED=NO" \
    $hardware_name $finc_count $fdec_count $burst_size $finc_freq \
    [response_sign $finc_freq] [response_magnitude $finc_freq] $fdec_freq \
    [response_sign $fdec_freq] [response_magnitude $fdec_freq] $opposite \
    $normal_req $normal_done $rxerr_delta $boot_delta $cpu_delta $wr_delta \
    $si_delta [expr {$accounting_pass ? "PASS" : "FAIL"}]]
  flush stdout
}

puts [format "BIDIR_CONFIG experiment=EXP-WRPC-STEP5-HPLL-SI5340-BIDIRECTIONAL-ACTUATOR-STEP-RESPONSE-IDENTIFICATION-LANE2-20260902 baseline_seconds=%d burst_size=%d settle_updates=%d window_updates=%d sample_gap_ms=%d completion_poll_ms=%d normal_hpll_tracker=0 bootstrap=0 direction_encoding=0:FDEC,1:FINC read_only_measurement=1" \
  $baseline_seconds $burst_size $settle_updates $window_updates \
  $sample_gap_ms $completion_poll_ms]

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && $hardware_name ne $board_filter} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== BIDIR_BOARD %s ===" $hardware_name]
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name \
      -device_name $device_name
    wb_sync_toggle $hardware_name
    set actuator_probe [probe_read 49]
    if {![is_hex $actuator_probe]} {
      puts [format "BIDIR_SKIP board=%s reason=probe49_unavailable" $hardware_name]
    } else {
      source_write 36 0
      source_write 40 $burst_size
      write_direction 0
      read_snapshot $hardware_name BASELINE_BEFORE
      after [expr {$baseline_seconds * 1000}]
      read_snapshot $hardware_name BASELINE_AFTER

      # FINC burst.
      read_snapshot $hardware_name FINC_BEFORE
      write_direction 1
      set finc_trigger_ms [clock milliseconds]
      force_pulse
      set finc_wait [wait_for_completion $hardware_name FINC_BEFORE 1 \
        $burst_size $completion_poll_ms $max_completion_polls $finc_trigger_ms]
      foreach {finc_ok finc_completed finc_completion_ms finc_polls} $finc_wait break
      read_snapshot $hardware_name FINC_AFTER
      set finc_window [collect_settled_window $hardware_name FINC FINC_AFTER \
        $settle_updates $window_updates $sample_gap_ms $finc_trigger_ms]
      foreach {finc_first finc_last finc_settle_ms finc_samples} $finc_window break
      emit_phase_result $hardware_name FINC FINC_BEFORE FINC_AFTER \
        $finc_first $finc_last $finc_settle_ms

      # Equal-size FDEC burst after the FINC fixed window.
      read_snapshot $hardware_name FDEC_BEFORE
      write_direction 0
      set fdec_trigger_ms [clock milliseconds]
      force_pulse
      set fdec_wait [wait_for_completion $hardware_name FDEC_BEFORE 0 \
        $burst_size $completion_poll_ms $max_completion_polls $fdec_trigger_ms]
      foreach {fdec_ok fdec_completed fdec_completion_ms fdec_polls} $fdec_wait break
      read_snapshot $hardware_name FDEC_AFTER
      set fdec_window [collect_settled_window $hardware_name FDEC FDEC_AFTER \
        $settle_updates $window_updates $sample_gap_ms $fdec_trigger_ms]
      foreach {fdec_first fdec_last fdec_settle_ms fdec_samples} $fdec_window break
      emit_phase_result $hardware_name FDEC FDEC_BEFORE FDEC_AFTER \
        $fdec_first $fdec_last $fdec_settle_ms

      read_snapshot $hardware_name RETURN_FINAL
      puts [format "BIDIR_COMMAND_RESULT board=%s FINC_TRIGGER_ACCEPTED=%d FINC_COMPLETION_DELTA=%s FINC_COMPLETION_TIME_MS=%s FINC_POLL_COUNT=%s FDEC_TRIGGER_ACCEPTED=%d FDEC_COMPLETION_DELTA=%s FDEC_COMPLETION_TIME_MS=%s FDEC_POLL_COUNT=%s" \
        $hardware_name $finc_ok $finc_completed $finc_completion_ms $finc_polls \
        $fdec_ok $fdec_completed $fdec_completion_ms $fdec_polls]
      flush stdout
      emit_final_summary $hardware_name $burst_size FINC_BEFORE FINC_AFTER \
        FDEC_BEFORE FDEC_AFTER RETURN_FINAL $finc_first $finc_last \
        $fdec_first $fdec_last
      puts [format "BIDIR_DONE board=%s" $hardware_name]
      flush stdout
    }
  } error_message]} {
    puts [format "BIDIR_ERROR board=%s message=%s error_info=%s" \
      $hardware_name $error_message [string map {\n " | "} $::errorInfo]]
    flush stdout
  }
  catch { end_insystem_source_probe }
}

puts "BIDIR_ACTUATOR_STEP_RESPONSE_DONE"
