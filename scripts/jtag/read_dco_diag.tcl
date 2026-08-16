# 讀取 SI5340 DCO pipeline 的唯讀 counters。
# probe 8/9 欄位：source、destination input、controller accept、I2C done。
# 用法：quartus_stp -t read_dco_diag.tcl ?gap_ms?

package require ::quartus::insystem_source_probe

set gap_ms 1000
if {[llength $argv] >= 1} {
  set gap_ms [expr {int([lindex $argv 0])}]
}
if {$gap_ms < 0} {
  error "gap_ms must be >= 0"
}

proc read_dco_probe {instance label} {
  set value [read_probe_data -instance_index $instance -value_in_hex]
  scan $value %x word
  set source [expr {$word & 0xffff}]
  set destination [expr {($word >> 16) & 0xffff}]
  set accepted [expr {($word >> 32) & 0xffff}]
  set done [expr {($word >> 48) & 0xffff}]
  puts [format "DCO_DIAG label=%s source=%04X destination=%04X accepted=%04X done=%04X raw=%016X" \
        $label $source $destination $accepted $done $word]
}

puts [format "DCO_DIAG_CONFIG gap_ms=%d" $gap_ms]
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    read_dco_probe 8 BEGIN_HPLL
    read_dco_probe 9 BEGIN_DPLL
    after $gap_ms
    read_dco_probe 8 END_HPLL
    read_dco_probe 9 END_DPLL
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
