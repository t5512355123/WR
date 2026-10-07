# Passive Helper measurements and independently sampled L2 service counters.
# No UART command, snapshot request, reset, or production register write.
# Usage: quartus_stp -t this_file.tcl ?samples? ?gap_ms?
set helper_argv $argv
set argv {}
set ::step6_vuart_library_only 1
source [file join [file dirname [info script]] read_step6_ip_vuart.tcl]
unset ::step6_vuart_library_only
set argv $helper_argv
set samples 10
set gap_ms 250
if {[llength $argv] > 0} { set samples [lindex $argv 0] }
if {[llength $argv] > 1} { set gap_ms [lindex $argv 1] }
if {![string is integer -strict $samples] || $samples < 1 || $samples > 100 ||
    ![string is integer -strict $gap_ms] || $gap_ms < 0 || $gap_ms > 1000} {
  error "samples must be 1..100 and gap_ms 0..1000"
}
proc helper_signed32 {raw} {
  set value [word32 $raw]
  if {$value eq "INVALID"} { return INVALID }
  if {$value & 0x80000000} { return [expr {$value - 0x100000000}] }
  return $value
}
proc passive_helper_frame {board} {
  set payload {}
  for {set attempt 0} {$attempt < 8} {incr attempt} {
    set start [clock milliseconds]
    set before [word32 [wb_read $board 0x00100B00]]
    if {$before eq "INVALID" || $before == 0xffffffff || ($before & 1)} { continue }
    set payload {}
    for {set addr 0x00100B04} {$addr <= 0x00100B24} {incr addr 4} {
      lappend payload [wb_read $board $addr]
    }
    set after_epoch [word32 [wb_read $board 0x00100B00]]
    set valid [expr {$after_epoch ne "INVALID" && $before == $after_epoch}]
    foreach raw $payload { if {[word32 $raw] eq "INVALID"} { set valid 0 } }
    if {$valid} {
      lassign $payload tag expected freq preclamp error count output ref fb
      set freq [helper_signed32 $freq]
      set output [word32 $output]
      if {$freq != [helper_signed32 $tag] - [helper_signed32 $expected] ||
          $output < 5 || $output > 65531} { continue }
      return [list 1 $start [clock milliseconds] $before $payload $freq $output]
    }
  }
  return [list 0 $start [clock milliseconds] INVALID $payload INVALID INVALID]
}
set boards 0
foreach board [get_hardware_names] {
  if {![string match "*1-11.1*" $board] && ![string match "*1-11.2*" $board]} { continue }
  incr boards
  set device [lindex [get_device_names -hardware_name $board] 0]
  start_insystem_source_probe -hardware_name $board -device_name $device
  wb_sync_toggle $board
  set generation_before [probe_word 26]
  for {set n 1} {$n <= $samples} {incr n} {
    lassign [passive_helper_frame $board] valid start end epoch raw freq output
    puts "HELPER_PASSIVE board={$board} sample=$n valid=$valid start_ms=$start end_ms=$end epoch=$epoch raw={$raw} freq_error=$freq output=$output"
    # A rapidly republished bank may prevent a coherent multiword capture.
    # Preserve single-word evidence separately; never label it a joined frame.
    foreach {field addr} {freq_error 0x00100B0C output 0x00100B1C update_count 0x00100B18} {
      set scalar_start [clock milliseconds]
      set scalar_raw [wb_read $board $addr]
      set scalar_valid [expr {[word32 $scalar_raw] ne "INVALID"}]
      puts "HELPER_SCALAR board={$board} sample=$n field=$field start_ms=$scalar_start end_ms=[clock milliseconds] raw=$scalar_raw transport_valid=$scalar_valid cross_field_coherent=0"
    }
    # L2 counters are NOT atomic with the Helper payload or with each other.
    set l2_start [clock milliseconds]
    set l2 {}
    foreach index {52 53 54 55 56 57 58 59 60 61} {
      lappend l2 $index [probe_word $index]
    }
    puts "HELPER_L2 board={$board} sample=$n start_ms=$l2_start end_ms=[clock milliseconds] raw={$l2}"
    set generation_after [probe_word 26]
    if {$generation_before ne $generation_after} {
      # Probe 26 includes evolving breadcrumbs: report changes, never assume
      # the entire word is a generation-only counter.
      set old [word64 $generation_before]
      set new [word64 $generation_after]
      if {$old eq "INVALID" || $new eq "INVALID" || (($old >> 32) & 0x7f) != (($new >> 32) & 0x7f)} {
        error "boot generation changed or became invalid"
      }
    }
    after $gap_ms
  }
  end_insystem_source_probe
}
if {$boards != 2} { error "expected exactly two named DE5 boards, observed $boards" }
puts "HELPER_PASSIVE_DONE boards=$boards samples=$samples production_writes=0"
