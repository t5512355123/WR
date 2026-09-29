# Read-only Slave WR servo/offset update correlation through the diagnostic mailbox.
# Usage: quartus_stp -t read_slave_offset_update_correlation.tcl smoke|capture ?max_retries?

package require ::quartus::insystem_source_probe

if {[llength $argv] < 1 || [llength $argv] > 2} {
  error "usage: read_slave_offset_update_correlation.tcl smoke|capture ?max_retries?"
}
set mode [lindex $argv 0]
if {$mode ni {smoke capture}} { error "mode must be smoke or capture" }
set max_retries 2
if {[llength $argv] == 2} { set max_retries [expr {int([lindex $argv 1])}] }
if {$max_retries < 0 || $max_retries > 2} { error "max_retries must be 0..2" }
set smoke_samples 20
set capture_duration_ms 300000
set ::wb_toggle 0

proc valid_hex {value max_digits} {
  set pattern [format {^[0-9A-Fa-f]{1,%d}$} $max_digits]
  return [regexp $pattern $value]
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
  return TIMEOUT
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
  if {(($word & 0xffff0000) == 0xa5a50000)} { return -1 }
  return [expr {$word & 0xffffffff}]
}

proc signed32 {value} {
  set word [raw32 $value]
  if {$word < 0} { return -2147483649 }
  if {$word >= 2147483648} { return [expr {$word - 4294967296}] }
  return $word
}

proc servo_state {value} {
  set word [raw32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> 8) & 0xf}]
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

proc read_row {sample attempt} {
  set start_us [clock microseconds]
  set ctrl_begin [wb_read 0x00100A04]
  set ucnt_begin [wb_read 0x00100A48]
  set dms_hi_begin [wb_read 0x00100A34]
  set dms_lo_begin [wb_read 0x00100A38]
  set setp_begin [wb_read 0x00100A44]
  set sstat_begin [wb_read 0x00100A08]
  set cko_begin [wb_read 0x00100A40]
  set cko_end [wb_read 0x00100A40]
  set sstat_end [wb_read 0x00100A08]
  set setp_end [wb_read 0x00100A44]
  set dms_hi_end [wb_read 0x00100A34]
  set dms_lo_end [wb_read 0x00100A38]
  set ucnt_end [wb_read 0x00100A48]
  set ctrl_end [wb_read 0x00100A04]
  set elapsed_us [expr {[clock microseconds] - $start_us}]

  set cb [raw32 $ctrl_begin]
  set ce [raw32 $ctrl_end]
  set sb [raw32 $sstat_begin]
  set se [raw32 $sstat_end]
  set sstat_valid_begin [expr {$sb >= 0 ? ($sb & 1) : -1}]
  set sstat_valid_end [expr {$se >= 0 ? ($se & 1) : -1}]
  set state_begin [servo_state $sstat_begin]
  set state_end [servo_state $sstat_end]
  set offset_begin [signed32 $cko_begin]
  set offset_end [signed32 $cko_end]
  set setpoint_begin [signed32 $setp_begin]
  set setpoint_end [signed32 $setp_end]
  set raw_values [list $ucnt_begin $dms_hi_begin $dms_lo_begin $setp_begin \
      $sstat_begin $cko_begin $cko_end $sstat_end $setp_end $dms_hi_end \
      $dms_lo_end $ucnt_end]
  set all_valid [expr {$cb >= 0 && $ce >= 0 && $cb == $ce && ($cb & 1) == 1 &&
      $sstat_valid_begin == 1 && $sstat_valid_end == 1 && $state_begin >= 0 &&
      $state_begin <= 5 && $state_end >= 0 && $state_end <= 5 &&
      $offset_begin != -2147483649 &&
      $offset_end != -2147483649 && $setpoint_begin != -2147483649 &&
      $setpoint_end != -2147483649}]
  foreach value $raw_values {
    if {[raw32 $value] < 0} { set all_valid 0 }
  }
  if {$offset_begin == -2147483649 || $offset_end == -2147483649} {
    set offset_delta 0
  } else {
    set offset_delta [expr {$offset_end - $offset_begin}]
  }
  puts [format {CORR_SAMPLE board=DE5_1-11.2 sample=%06d attempt=%d row_valid=%d elapsed_us=%d ctrl_valid=%d ctrl_begin=%s ctrl_end=%s state_begin=%d state_end=%d state_begin_name=%s state_end_name=%s sstat_begin=%s sstat_end=%s cko_begin=%s cko_end=%s offset_begin_ps=%d offset_end_ps=%d offset_delta_ps=%d ucnt_begin=%s ucnt_end=%s setp_begin_raw=%s setp_end_raw=%s setp_begin_ps=%d setp_end_ps=%d dms_hi_begin=%s dms_lo_begin=%s dms_hi_end=%s dms_lo_end=%s} \
      $sample $attempt $all_valid $elapsed_us \
      [expr {$cb >= 0 && $ce >= 0 && $cb == $ce && ($cb & 1) == 1}] \
      $ctrl_begin $ctrl_end $state_begin $state_end \
      [state_name $state_begin] [state_name $state_end] \
      $sstat_begin $sstat_end $cko_begin $cko_end \
      $offset_begin $offset_end $offset_delta \
      $ucnt_begin $ucnt_end $setp_begin $setp_end $setpoint_begin $setpoint_end \
      $dms_hi_begin $dms_lo_begin $dms_hi_end $dms_lo_end]
  flush stdout
  return $all_valid
}

if {$mode eq "smoke"} {
  puts "CORR_CONFIG mode=smoke target_samples=$smoke_samples max_retries=$max_retries read_only=1 target_board=DE5_1-11.2 wb_reads_per_row=14"
} else {
  puts "CORR_CONFIG mode=capture duration_seconds=300 max_retries=$max_retries read_only=1 target_board=DE5_1-11.2 wb_reads_per_row=14"
}
flush stdout

set targets {}
foreach hardware_name [get_hardware_names] {
  if {[regexp {^DE5 \[1-11\.2\]$} $hardware_name]} { lappend targets $hardware_name }
}
if {[llength $targets] != 1} {
  error [format {expected exactly one Slave cable DE5 [1-11.2], found %d} [llength $targets]]
}
set hardware_name [lindex $targets 0]
set devices [get_device_names -hardware_name $hardware_name]
if {[llength $devices] == 0} { error "no JTAG device found on the Slave cable" }
set device_name [lindex $devices 0]
puts [format {CORR_BOARD_BEGIN hardware=DE5_1-11.2 device_count=%d selected_device=%s} [llength $devices] $device_name]
flush stdout

catch {end_insystem_source_probe}
if {[catch {
  start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
  wb_sync_toggle
  set start_ms [clock milliseconds]
  set sample 0
  set accepted_count 0
  set failed_count 0
  set consecutive_invalid 0
  while {1} {
    if {$mode eq "smoke" && $sample >= $smoke_samples} { break }
    if {$mode eq "capture" && ([clock milliseconds] - $start_ms) >= $capture_duration_ms} { break }
    incr sample
    set accepted 0
    set used_attempt 0
    for {set attempt 0} {$attempt <= $max_retries} {incr attempt} {
      set used_attempt $attempt
      set accepted [read_row $sample $attempt]
      if {$accepted} { break }
      if {$attempt < $max_retries} { after 2 }
    }
    if {$accepted} {
      incr accepted_count
      set consecutive_invalid 0
    } else {
      incr failed_count
      incr consecutive_invalid
    }
    puts [format "CORR_SAMPLE_RESULT board=DE5_1-11.2 sample=%06d accepted=%d retries=%d consecutive_invalid=%d" \
        $sample $accepted $used_attempt $consecutive_invalid]
    flush stdout
    if {$consecutive_invalid >= 5} {
      puts "CORR_STOP reason=five_consecutive_invalid_samples"
      flush stdout
      break
    }
  }
  set elapsed_ms [expr {[clock milliseconds] - $start_ms}]
  puts [format "CORR_BOARD_RESULT board=DE5_1-11.2 samples=%d accepted=%d failed=%d elapsed_ms=%d" \
      $sample $accepted_count $failed_count $elapsed_ms]
} error_message]} {
  puts "CORR_READER_ERROR board=DE5_1-11.2 message=$error_message"
  catch {end_insystem_source_probe}
  error $error_message
}
catch {end_insystem_source_probe}
puts "CORR_SESSION_DONE"
flush stdout
