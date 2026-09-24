# Read-only Step1 capture from the historical 64-bit instance-0 probe.
# Usage: quartus_stp -t read_step1_phy_link.tcl ?samples? ?gap_ms?

package require ::quartus::insystem_source_probe

set samples 360
set gap_ms 100
if {[llength $argv] >= 1} {
  set samples [expr {int([lindex $argv 0])}]
}
if {[llength $argv] >= 2} {
  set gap_ms [expr {int([lindex $argv 1])}]
}
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

puts [format "STEP1_CAPTURE_CONFIG samples=%d gap_ms=%d probe_instance=0 read_only=1" \
      $samples $gap_ms]
flush stdout

set sampled_boards 0
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} {
    continue
  }
  set device_name [lindex $device_names 0]
  incr sampled_boards
  catch {end_insystem_source_probe}
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set start_ms [clock milliseconds]
    puts [format {STEP1_BOARD_BEGIN board="%s" device="%s"} $hardware_name $device_name]
    flush stdout
    for {set sample 1} {$sample <= $samples} {incr sample} {
      set raw [string trim [read_probe_data -instance_index 0 -value_in_hex]]
      set elapsed_ms [expr {[clock milliseconds] - $start_ms}]
      if {[regexp {^[0-9A-Fa-f]{1,16}$} $raw]} {
        set read_ok 1
        set raw [string toupper $raw]
      } else {
        set read_ok 0
        set raw INVALID
      }
      puts [format {STEP1_SAMPLE board="%s" n=%04d elapsed_ms=%d read_ok=%d raw=%s} \
            $hardware_name $sample $elapsed_ms $read_ok $raw]
      flush stdout
      if {$sample < $samples && $gap_ms > 0} {
        after $gap_ms
      }
    }
    puts [format {STEP1_BOARD_DONE board="%s" samples=%d elapsed_ms=%d} \
          $hardware_name $samples [expr {[clock milliseconds] - $start_ms}]]
    flush stdout
  } error_message]} {
    puts [format {STEP1_BOARD_ERROR board="%s" error="%s"} $hardware_name $error_message]
    flush stdout
  }
  catch {end_insystem_source_probe}
}

puts [format "STEP1_CAPTURE_DONE boards_sampled=%d" $sampled_boards]
flush stdout
