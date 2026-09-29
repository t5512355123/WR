# Narrow, read-only servo/phase-offset time series through the existing
# in-system source-probe diagnostic mailbox. No target or ARM writes occur.
# Usage: quartus_stp -t read_servo_fast.tcl ?samples_per_board? ?max_retries?

package require ::quartus::insystem_source_probe

set samples 400
set max_retries 2
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set max_retries [expr {int([lindex $argv 1])}] }
if {$samples <= 0 || $max_retries < 0} {
  error "samples_per_board must be > 0 and max_retries must be >= 0"
}

set ::wb_toggle 0

proc valid_hex {value max_digits} {
  set pattern [format {^[0-9A-Fa-f]{1,%d}$} $max_digits]
  return [regexp $pattern $value]
}

proc source_probe_word {index} {
  set raw [read_probe_data -instance_index $index -value_in_hex]
  if {![valid_hex $raw 16]} { return "TIMEOUT" }
  scan $raw %x word
  return [format %016X $word]
}

proc wb_read {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set cmd [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [read_probe_data -instance_index 1 -value_in_hex]
    if {![valid_hex $value 16]} { after 1; continue }
    scan $value %x word
    set done_toggle [expr {(($word >> 35) & 1)}]
    set active [expr {(($word >> 36) & 1)}]
    if {$done_toggle == $::wb_toggle && $active == 0} {
      return [format %08X [expr {$word & 0xffffffff}]]
    }
    after 1
  }
  return "TIMEOUT"
}

proc wb_sync_toggle {} {
  set value [read_probe_data -instance_index 1 -value_in_hex]
  if {![valid_hex $value 16]} { error "cannot synchronize diagnostic mailbox toggle" }
  scan $value %x word
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
}

proc raw32 {value} {
  if {![valid_hex $value 8]} { return -1 }
  scan $value %x word
  # Match the frozen reader's mailbox error-marker rejection.
  if {(($word & 0xffff0000) == 0xa5a50000)} { return -1 }
  return [expr {$word & 0xffffffff}]
}

proc bit32 {value bit} {
  set word [raw32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc state32 {value} {
  set word [raw32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> 8) & 0xf}]
}

proc signed32 {value} {
  set word [raw32 $value]
  if {$word < 0} { return -2147483649 }
  if {$word >= 2147483648} { return [expr {$word - 4294967296}] }
  return $word
}

proc state_name {value} {
  switch -- $value {
    0 { return UNINITIALIZED }
    1 { return SYNC_TAI }
    2 { return SYNC_NSEC }
    3 { return SYNC_PHASE }
    4 { return TRACK_PHASE }
    5 { return WAIT_OFFSET_STABLE }
  }
  return INVALID
}

proc read_fast_row {board sample attempt} {
  set start_us [clock microseconds]
  set status_begin [source_probe_word 0]
  set clock_begin [source_probe_word 7]
  set ctrl_begin [wb_read 0x00100A04]
  set sstat_begin [wb_read 0x00100A08]
  set cko_begin [wb_read 0x00100A40]
  set pstat [wb_read 0x00100A0C]
  set helper_state [wb_read 0x00100ABC]
  set main_state [wb_read 0x00100AC4]
  set dms_h [wb_read 0x00100A34]
  set dms_l [wb_read 0x00100A38]
  set setp [wb_read 0x00100A44]
  set ucnt [wb_read 0x00100A48]
  set cko_end [wb_read 0x00100A40]
  set sstat_end [wb_read 0x00100A08]
  set ctrl_end [wb_read 0x00100A04]
  set status_end [source_probe_word 0]
  set clock_end [source_probe_word 7]
  set elapsed_us [expr {[clock microseconds] - $start_us}]

  set ctrl_begin_word [raw32 $ctrl_begin]
  set ctrl_end_word [raw32 $ctrl_end]
  set ctrl_valid [expr {$ctrl_begin_word >= 0 && $ctrl_end_word >= 0 &&
                        (($ctrl_begin_word & 1) == 1) &&
                        ($ctrl_begin_word == $ctrl_end_word)}]
  set sstat_begin_word [raw32 $sstat_begin]
  set sstat_end_word [raw32 $sstat_end]
  set sstat_valid_begin [bit32 $sstat_begin 0]
  set sstat_valid_end [bit32 $sstat_end 0]
  set state_begin [state32 $sstat_begin]
  set state_end [state32 $sstat_end]
  set state_valid [expr {$sstat_valid_begin == 1 && $sstat_valid_end == 1 &&
                         $state_begin >= 0 && $state_end >= 0}]
  set status_begin_word -1
  set status_end_word -1
  if {[valid_hex $status_begin 16]} { scan $status_begin %x status_begin_word }
  if {[valid_hex $status_end 16]} { scan $status_end %x status_end_word }
  set time_valid_begin [expr {$status_begin_word < 0 ? -1 : (($status_begin_word >> 4) & 1)}]
  set time_valid_end [expr {$status_end_word < 0 ? -1 : (($status_end_word >> 4) & 1)}]
  set pps_valid_begin [expr {$status_begin_word < 0 ? -1 : (($status_begin_word >> 5) & 1)}]
  set pps_valid_end [expr {$status_end_word < 0 ? -1 : (($status_end_word >> 5) & 1)}]
  set link_begin [expr {$status_begin_word < 0 ? -1 : (($status_begin_word >> 3) & 1)}]
  set link_end [expr {$status_end_word < 0 ? -1 : (($status_end_word >> 3) & 1)}]
  set pstat_link [bit32 $pstat 0]
  set spll_locked [bit32 $pstat 1]
  set helper_locked [bit32 $helper_state 0]
  set main_enabled [bit32 $main_state 0]
  set main_locked [bit32 $main_state 1]
  set main_freq [bit32 $main_state 2]
  set main_phase [bit32 $main_state 3]
  set offset_begin [signed32 $cko_begin]
  set offset_end [signed32 $cko_end]

  set words [list $ctrl_begin $sstat_begin $cko_begin $pstat $helper_state \
      $main_state $dms_h $dms_l $setp $ucnt $cko_end $sstat_end $ctrl_end]
  set data_valid 1
  foreach value $words {
    if {[raw32 $value] < 0} { set data_valid 0 }
  }
  if {![valid_hex $status_begin 16] || ![valid_hex $status_end 16] ||
      ![valid_hex $clock_begin 16] || ![valid_hex $clock_end 16] ||
      !$ctrl_valid || !$state_valid} {
    set data_valid 0
  }
  set sample_valid [expr {$data_valid && $spll_locked >= 0 &&
      $helper_locked >= 0 && $main_enabled >= 0 && $main_locked >= 0 &&
      $main_freq >= 0 && $main_phase >= 0 && $time_valid_begin >= 0 &&
      $time_valid_end >= 0 && $pps_valid_begin >= 0 && $pps_valid_end >= 0}]

  puts [format {FAST_SAMPLE board=%s sample=%03d attempt=%d data_valid=%d sample_valid=%d elapsed_us=%d ctrl_valid=%d sstat_valid_begin=%d sstat_valid_end=%d state_begin=%d state_end=%d state_begin_name=%s state_end_name=%s offset_begin_ps=%d offset_end_ps=%d time_valid_begin=%d time_valid_end=%d pps_valid_begin=%d pps_valid_end=%d link_begin=%d link_end=%d pstat_link=%d spll_locked=%d helper_locked=%d main_enabled=%d main_locked=%d main_freq=%d main_phase=%d dms_h=%s dms_l=%s setp=%s ucnt=%s clock_begin=%s clock_end=%s} \
      $board $sample $attempt $data_valid $sample_valid $elapsed_us $ctrl_valid \
      $sstat_valid_begin $sstat_valid_end $state_begin $state_end \
      [state_name $state_begin] [state_name $state_end] $offset_begin $offset_end \
      $time_valid_begin $time_valid_end $pps_valid_begin $pps_valid_end \
      $link_begin $link_end $pstat_link $spll_locked $helper_locked \
      $main_enabled $main_locked $main_freq $main_phase $dms_h $dms_l $setp $ucnt \
      $clock_begin $clock_end]
  flush stdout
  return $sample_valid
}

puts [format "FAST_CONFIG samples_per_board=%d max_retries=%d gap_ms=0 read_only=1" \
      $samples $max_retries]
flush stdout

foreach hardware_name [get_hardware_names] {
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} {
    puts "FAST_BOARD_SKIP hardware=$hardware_name reason=no_device"
    continue
  }
  set device_name [lindex $devices 0]
  puts "FAST_BOARD_BEGIN hardware=$hardware_name"
  flush stdout
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    set accepted_count 0
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set accepted 0
      for {set attempt 0} {$attempt <= $max_retries} {incr attempt} {
        set accepted [read_fast_row $hardware_name $sample $attempt]
        if {$accepted} { break }
        if {$attempt < $max_retries} { after 5 }
      }
      incr accepted_count $accepted
      set retries_used [expr {$attempt > $max_retries ? $max_retries : $attempt}]
      puts [format "FAST_SAMPLE_RESULT board=%s sample=%03d accepted=%d retries=%d" \
            $hardware_name $sample $accepted $retries_used]
      flush stdout
    }
    puts [format "FAST_BOARD_RESULT hardware=%s samples=%d accepted=%d" \
          $hardware_name $samples $accepted_count]
  } error_message]} {
    puts "FAST_READER_ERROR hardware=$hardware_name message=$error_message"
  }
  catch { end_insystem_source_probe }
}

puts "FAST_SESSION_DONE"
flush stdout
