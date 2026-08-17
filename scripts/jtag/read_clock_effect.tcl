# 讀取 Slave 的 QSFPA_REFCLK / QSFPB_REFCLK clock-effect counters。
# 每個來源時脈每 256 個 rising edge 讓分頻 toggle 一次，
# observer 每偵測到一次 toggle 就累加一個 32-bit count。
# 因此來源頻率估計為 delta_count * 256 / window_seconds。

package require ::quartus::insystem_source_probe

set gap_ms 5000
if {[llength $argv] >= 1} {
  set gap_ms [expr {int([lindex $argv 0])}]
}
if {$gap_ms < 0} {
  error "gap_ms must be >= 0"
}

proc read_effect_word {} {
  set value [read_probe_data -instance_index 11 -value_in_hex]
  scan $value %x word
  return [format %016X $word]
}

proc u32_delta {after before} {
  return [expr {($after - $before) & 0xffffffff}]
}

puts [format "CLOCK_EFFECT_CONFIG gap_ms=%d" $gap_ms]
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set first [read_effect_word]
    after $gap_ms
    set second [read_effect_word]
    scan $first %x first_word
    scan $second %x second_word
    set ref_before [expr {$first_word & 0xffffffff}]
    set dmtd_before [expr {($first_word >> 32) & 0xffffffff}]
    set ref_after [expr {$second_word & 0xffffffff}]
    set dmtd_after [expr {($second_word >> 32) & 0xffffffff}]
    set ref_delta [u32_delta $ref_after $ref_before]
    set dmtd_delta [u32_delta $dmtd_after $dmtd_before]
    set window_s [expr {$gap_ms / 1000.0}]
    if {$window_s > 0.0} {
      set ref_hz [expr {$ref_delta * 256.0 / $window_s}]
      set dmtd_hz [expr {$dmtd_delta * 256.0 / $window_s}]
    } else {
      set ref_hz 0.0
      set dmtd_hz 0.0
    }
    puts [format "CLOCK_EFFECT A=%s B=%s REF_DELTA=%u DMTD_DELTA=%u REF_EST_HZ=%.3f DMTD_EST_HZ=%.3f" \
          $first $second $ref_delta $dmtd_delta $ref_hz $dmtd_hz]
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
