# Read-only strict WR offset/validity capture. No snapshot requests or controls.
# Separate live health and firmware frames are explicitly NOT cycle-atomic.
package require ::quartus::insystem_source_probe
set ::wb_library_mode 1
source [file join [file dirname [info script]] read_wb_runtime.tcl]
set duration_ms 330000
set sample_ms 250
set board_filter "1-11.2"
if {[llength $argv]>0} { set duration_ms [expr {int([lindex $argv 0])}] }
if {[llength $argv]>1} { set sample_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv]>2} { set board_filter [lindex $argv 2] }
if {$duration_ms<=0 || $sample_ms<=0} { error "Positive duration/sample required" }
proc strict_byte {raw shift} {
  if {![is_hex $raw]} { return INVALID }
  if {$shift<32} { set w [word32 $raw] } else {
    set w [probe_high32 $raw]; set shift [expr {$shift-32}]
  }
  return [format %08X [expr {($w>>$shift)&0xff}]]
}
proc strict_frame {} {
  # Counter is updated inside the WDIAGS invalid interval; CTRL before payload
  # and after the closing epoch are essential. Inverse mapping is checked in
  # the board preflight, outside this short seven-read frame (no invented raw).
  set result [list 0 INVALID INVALID INVALID INVALID INVALID]
  set deadline [expr {[clock milliseconds]+600}]
  while {[clock milliseconds]<$deadline} {
    set e0 [wb_read 0x00100B34]
    set c0 [wb_read 0x00100A04]
    if {[word32 $c0]<0 || !([word32 $c0]&1)} { continue }
    set u [wb_read 0x00100A48]
    set k [wb_read 0x00100A40]
    set s [wb_read 0x00100A08]
    set e1 [wb_read 0x00100B34]
    set c1 [wb_read 0x00100A04]
    set good [expr {[is_hex $e0] && [is_hex $e1] && [is_hex $u] &&
      [is_hex $k] && [is_hex $s] && [word32 $c1]>=0 &&
      ([word32 $c1]&1) && (([word32 $e0]^ [word32 $e1])&0xffff)==0}]
    set result [list $good $e0 $e1 $u $k $s]
    if {$good} { return $result }
  }
  return $result
}
puts "S6_STRICT_CONFIG duration_ms=$duration_ms sample_ms=$sample_ms read_only=1 wb_register_writes=0 health_cycle_atomic=0"
set boards 0
foreach hw [get_hardware_names] {
  if {[string first $board_filter $hw]<0} { continue }
  set devices [get_device_names -hardware_name $hw]
  if {![llength $devices]} { continue }
  incr boards
  catch {end_insystem_source_probe}
  start_insystem_source_probe -hardware_name $hw -device_name [lindex $devices 0]
  wb_sync_toggle
  set mapping_ok 0
  for {set n 0} {$n<10} {incr n} {
    set a [word32 [wb_read 0x00100B34]]
    set inv [word32 [wb_read 0x00100B38]]
    set b [word32 [wb_read 0x00100B34]]
    if {$a>=0 && $b>=0 && $inv>=0 && ($a&0xffff)==($b&0xffff) &&
        (($a^$inv)&0xffff)==0xffff} { set mapping_ok 1; break }
  }
  puts "S6_STRICT_MAPPING board={$hw} mapping_ok=$mapping_ok counter_raw=[format %08X $a] inverse_raw=[format %08X $inv]"
  if {!$mapping_ok} { error "Mapping preflight failed; no capture" }
  set begin [clock milliseconds]
  set sample 0
  set invalid_streak 0
  set baseline ""
  set prev_epoch -1
  set last_epoch_ms $begin
  while {[clock milliseconds]-$begin<=$duration_ms} {
    set row_begin [clock milliseconds]
    set status0 [safe_probe_read 0]
    set escr0 [wb_read 0x0010031C]
    lassign [strict_frame] frame_ok epoch0 epoch1 ucnt cko_raw sstat
    set helper [wb_read 0x00100ABC]
    set main [wb_read 0x00100AC4]
    set pstat [wb_read 0x00100A0C]
    set escr1 [wb_read 0x0010031C]
    set status1 [safe_probe_read 0]
    set entry [safe_probe_read 26]
    set reset [safe_probe_read 27]
    set row_end [clock milliseconds]
    # Source: reset_sticky_probe 23:16 CPU, 31:24 WR, 39:32 external,
    # 47:40 SI-config-drop. Read full bytes, not just their low parity bit.
    set reset_sig [list [probe_high_counter_hex $entry] [strict_byte $reset 16] \
      [strict_byte $reset 24] [strict_byte $reset 32] [strict_byte $reset 40]]
    set reads_ok $frame_ok
    foreach raw [list $status0 $status1 $escr0 $escr1 $helper $main $pstat $entry $reset] {
      if {![is_hex $raw]} { set reads_ok 0 }
    }
    set reset_changed 0
    if {$reads_ok} {
      if {$baseline eq ""} { set baseline $reset_sig }
      if {$baseline ne $reset_sig} { set reset_changed 1 }
    }
    set epoch [expr {[word32 $epoch1]&0xffff}]
    if {$frame_ok && $epoch!=$prev_epoch} { set last_epoch_ms $row_end; set prev_epoch $epoch }
    set epoch_age [expr {$row_end-$last_epoch_ms}]
    set k [word32 $cko_raw]
    if {$k>=0x80000000} { set k [expr {$k-0x100000000}] }
    set state [expr {([word32 $sstat]>>8)&0xf}]
    set step1 1
    foreach st [list $status0 $status1] {
      foreach bit {0 1 2 3 6 7 15} {
        if {[bit64_low $st $bit]!=1} { set step1 0 }
      }
      if {[bit64_high $st 0]!=1} { set step1 0 }
    }
    set lock_ok [expr {([word32 $helper]&1)==1 && ([word32 $main]&0xe)==0xe && ([word32 $pstat]&2)==2}]
    set time_ok [expr {[bit64_low $status0 4]==1 && [bit64_low $status1 4]==1 &&
      ([word32 $escr0]&0xc)==0xc && ([word32 $escr1]&0xc)==0xc}]
    set trustworthy [expr {$reads_ok && $epoch_age<=1000 && !$reset_changed}]
    puts "S6_STRICT_SAMPLE board={$hw} sample=$sample elapsed_ms=[expr {$row_end-$begin}] row_start_ms=[expr {$row_begin-$begin}] row_end_ms=[expr {$row_end-$begin}] READS_VALID=$reads_ok FRAME_VALID=$frame_ok TRUSTWORTHY=$trustworthy EPOCH_BEFORE=$epoch0 EPOCH_AFTER=$epoch1 EPOCH_AGE_MS=$epoch_age UCNT=$ucnt CKO_RAW=$cko_raw CKO_PS=$k SSTAT=$sstat SERVO_STATE=$state STATUS_BEFORE=$status0 STATUS_AFTER=$status1 ESCR_BEFORE=$escr0 ESCR_AFTER=$escr1 TIME_VALID=$time_ok STEP1_GATE=$step1 LOCK_GATE=$lock_ok RESET_SIGNATURE={$reset_sig} RESET_CHANGED=$reset_changed"
    flush stdout
    if {$trustworthy} { set invalid_streak 0 } else { incr invalid_streak }
    if {$reset_changed || $invalid_streak>=5} {
      puts "S6_STRICT_STOP board={$hw} reason=reset_or_untrusted_data invalid_streak=$invalid_streak"
      break
    }
    incr sample
    set delay [expr {$sample_ms-([clock milliseconds]-$row_begin)}]
    if {$delay>0} { after $delay }
  }
  end_insystem_source_probe
  puts "S6_STRICT_BOARD_DONE board={$hw} samples=$sample elapsed_ms=[expr {[clock milliseconds]-$begin}] invalid_streak=$invalid_streak"
}
if {$boards!=1} { error "Expected exactly one Slave board; saw $boards" }
puts "S6_STRICT_DONE timeout_count=$::wb_timeout_count invalid_count=$::wb_invalid_count"
