# 讀取 SI5340 DCO pipeline 的唯讀 counters。
# probe 8/9 欄位：source、destination input、controller accept、I2C done。
# probe 10/11：DPLL/HPLL data、pending 與 runtime I2C FSM 的唯讀 snapshot。
# probe 12：I2C ACK/NACK sticky telemetry。
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

proc read_request_state {instance label} {
  set value [read_probe_data -instance_index $instance -value_in_hex]
  scan $value %x word
  set prev_data [expr {$word & 0xffff}]
  set input_data [expr {($word >> 16) & 0xffff}]
  set rt_state [expr {($word >> 32) & 0xf}]
  set dpll_pending [expr {($word >> 36) & 0x1}]
  set hpll_pending [expr {($word >> 37) & 0x1}]
  set select_dpll [expr {($word >> 38) & 0x1}]
  set direction [expr {($word >> 39) & 0x1}]
  set bus_state [expr {($word >> 40) & 0x1}]
  set static_ready [expr {($word >> 41) & 0x1}]
  set bus_done [expr {($word >> 42) & 0x1}]
  set prev_valid [expr {($word >> 43) & 0x1}]
  set done_once [expr {($word >> 44) & 0x1}]
  puts [format "DCO_%s_STATE prev_data=%04X input_data=%04X rt_state=%X dpll_pending=%d hpll_pending=%d select_dpll=%d direction=%d bus_state=%d static_ready=%d bus_done=%d prev_valid=%d done_once=%d raw=%016X" \
        $label $prev_data $input_data $rt_state $dpll_pending $hpll_pending $select_dpll \
        $direction $bus_state $static_ready $bus_done $prev_valid $done_once $word]
}

proc read_ack_diag {} {
  set value [read_probe_data -instance_index 12 -value_in_hex]
  scan $value %x word
  set transactions [expr {$word & 0xffff}]
  set errors [expr {($word >> 16) & 0xffff}]
  set ack_bits [expr {($word >> 32) & 0xf}]
  set word_addr [expr {($word >> 36) & 0xff}]
  set wr_data [expr {($word >> 44) & 0xff}]
  set slave_addr [expr {($word >> 52) & 0x7f}]
  set state [expr {($word >> 59) & 0x1f}]
  puts [format "DCO_I2C_ACK transactions=%04X errors=%04X ack_bits=%X word_addr=%02X wr_data=%02X slave_addr=%02X state=%02X raw=%016X" \
        $transactions $errors $ack_bits $word_addr $wr_data $slave_addr $state $word]
}

proc read_i2c_readback {} {
  set value [read_probe_data -instance_index 13 -value_in_hex]
  scan $value %x word
  set state [expr {$word & 0xf}]
  set done [expr {($word >> 4) & 0x1}]
  set page3 [expr {($word >> 5) & 0xff}]
  set finc [expr {($word >> 13) & 0xff}]
  set current_page [expr {($word >> 21) & 0xff}]
  puts [format "DCO_I2C_READBACK state=%X done=%d page3_0039=%02X page0_001D=%02X current_page=%02X raw=%016X" \
        $state $done $page3 $finc $current_page $word]
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
    read_request_state 10 DPLL
    read_request_state 11 HPLL
    read_ack_diag
    read_i2c_readback
    after $gap_ms
    read_dco_probe 8 END_HPLL
    read_dco_probe 9 END_DPLL
    read_request_state 10 DPLL
    read_request_state 11 HPLL
    read_ack_diag
    read_i2c_readback
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}
