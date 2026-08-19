# Slave HPLL/DCO step 與 SoftPLL helper error 的唯讀關聯觀測。
#
# 用法：
#   quartus_stp -t read_hpll_helper_correlation.tcl ?samples? ?gap_ms?
#
# 本腳本只讀取既有 altsource_probe 與 Wishbone mailbox register：
# 不寫入 WDIAGS 設定、不寫入 DATA_SNAPSHOT、不改變 PHY、servo、
# SoftPLL 或 FINC/FDEC 控制方向。
#
# 目的：把每次 DCO completed step 與 helper error 的前後變化放在同一份
# 時間序列中，區分「FPGA transaction 完成」與「feedback measurement 有變化」。

package require ::quartus::insystem_source_probe

set samples 60
set gap_ms 500
if {[llength $argv] >= 1} {
  set samples [expr {int([lindex $argv 0])}]
}
if {[llength $argv] >= 2} {
  set gap_ms [expr {int([lindex $argv 1])}]
}
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

set ::wb_toggle 0

proc wb_read {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set cmd [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [read_probe_data -instance_index 1 -value_in_hex]
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
  scan $value %x word
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
}

proc read_probe_word {instance_index} {
  set value [read_probe_data -instance_index $instance_index -value_in_hex]
  scan $value %x word
  return [format %016X $word]
}

proc u16_delta {after before} {
  return [expr {(($after - $before) & 0xffff)}]
}

proc signed32 {value} {
  set value [expr {$value & 0xffffffff}]
  if {$value >= 0x80000000} {
    return [expr {$value - 0x100000000}]
  }
  return $value
}

proc read_correlation_sample {hardware_name sample} {
  variable previous_step
  variable previous_helper_error

  set status [read_probe_word 0]
  # The Slave diagnostic image exposes one 64-bit DCO debug probe at
  # instance 8.  There is no separate instance 9/10 DCO probe.
  set dco_debug [read_probe_word 8]
  set spll_state [wb_read 0x00100AA0]
  set helper_state [wb_read 0x00100ABC]
  set helper_error [wb_read 0x00100AD8]
  set helper_output [wb_read 0x00100ADC]
  set pstat [wb_read 0x00100A0C]
  set sstat [wb_read 0x00100A08]
  set lock_polls [wb_read 0x00100A90]
  set lock_enable [wb_read 0x00100A9C]
  set spll_state [wb_read 0x00100AA0]
  set spll_rcer [wb_read 0x00100AA8]
  set spll_trr_csr [wb_read 0x00100AB0]
  set spll_ref_count [wb_read 0x00100AD0]
  set spll_tag_count [wb_read 0x00100AD4]
  set spll_irq_count [wb_read 0x00100AEC]
  set spll_tag_valid_count [wb_read 0x00100AF8]
  set spll_trr_write_count [wb_read 0x00100AFC]
  set spll_tag_source_count [wb_read 0x0010028C]
  set spll_dac_hpll [wb_read 0x00100AB4]
  set spll_dac_main [wb_read 0x00100AB8]
  set helper_last_tag [wb_read 0x00100B00]
  set helper_expected_tag [wb_read 0x00100B04]
  set helper_preclamp_error [wb_read 0x00100B08]
  set helper_tag_delta [wb_read 0x00100B0C]
  set helper_tag_source [wb_read 0x00100B10]
  set helper_expected_delta [wb_read 0x00100B14]
  set helper_update_count [wb_read 0x00100B18]
  set helper_p_adder [wb_read 0x00100B1C]
  set helper_tag_d0 [wb_read 0x00100B20]
  set helper_p_setpoint [wb_read 0x00100B24]
  set helper_ref_src [wb_read 0x00100B28]
  set ucnt [wb_read 0x00100A48]

  scan $status %x status_word
  scan $dco_debug %x dco_word
  scan $helper_error %x helper_word
  scan $helper_output %x output_word
  scan $helper_preclamp_error %x helper_preclamp_word
  scan $pstat %x pstat_word
  scan $sstat %x sstat_word

  # Keep these positions aligned with si5340a_controller_dco.v:
  # step_count=[35:20], HPLL_LOAD=17, error=18, busy=19.
  set step [expr {(($dco_word >> 20) & 0xffff)}]
  set hpll_load [expr {(($dco_word >> 17) & 1)}]
  set dco_error [expr {(($dco_word >> 18) & 1)}]
  set dco_busy [expr {(($dco_word >> 19) & 1)}]
  set helper_signed [signed32 $helper_word]
  set helper_preclamp_signed [signed32 $helper_preclamp_word]
  set step_delta 0
  set error_delta 0
  set step_event 0
  if {$previous_step >= 0} {
    set step_delta [u16_delta $step $previous_step]
    if {$step_delta != 0} {
      set step_event 1
      set error_delta [expr {$helper_signed - $previous_helper_error}]
    }
  }

  puts [format "HPLL_HELPER_SAMPLE board=%s sample=%03d status=%016s PSTAT=%s SSTAT=%s UCNT=%s LOCK_POLLS=%s LOCK_ENABLE=%s SPLL_STATE=%s RCER=%s TRR_CSR=%s REF=%s TAG=%s IRQ=%s TAG_VALID=%s TRR_WRITE=%s TAG_SOURCE=%s DAC_HPLL=%s DAC_MAIN=%s RAW_TAG=%s EXPECTED_TAG=%s PRECLAMP_ERROR=%s PRECLAMP_ERROR_SIGNED=%d TAG_DELTA=%s TAG_SOURCE_RAW=%s EXPECTED_DELTA=%s HELPER_UPDATE_COUNT=%s P_ADDER=%s TAG_D0=%s P_SETPOINT=%s REF_SRC=%s DCO_DEBUG=%s STEP=%d STEP_DELTA=%d STEP_EVENT=%d HPLL_LOAD=%d BUSY=%d ERROR=%d HELPER_STATE=%s HELPER_ERROR=%s HELPER_ERROR_SIGNED=%d HELPER_ERROR_DELTA=%d HELPER_OUTPUT=%s" \
        $hardware_name $sample $status $pstat $sstat $ucnt $lock_polls $lock_enable \
        $spll_state $spll_rcer $spll_trr_csr $spll_ref_count $spll_tag_count \
        $spll_irq_count $spll_tag_valid_count $spll_trr_write_count $spll_tag_source_count \
        $spll_dac_hpll $spll_dac_main $helper_last_tag $helper_expected_tag \
        $helper_preclamp_error $helper_preclamp_signed $helper_tag_delta $helper_tag_source \
        $helper_expected_delta $helper_update_count $helper_p_adder $helper_tag_d0 \
        $helper_p_setpoint $helper_ref_src $dco_debug \
        $step $step_delta $step_event $hpll_load $dco_busy \
        $dco_error $helper_state $helper_error $helper_signed $error_delta \
        [format %08X [expr {$output_word & 0xffffffff}]]]
  flush stdout

  set previous_step $step
  set previous_helper_error $helper_signed
}

puts [format "HPLL_HELPER_CORRELATION_CONFIG samples=%d gap_ms=%d" $samples $gap_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    set previous_step -1
    set previous_helper_error 0
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_correlation_sample $hardware_name $sample
      if {$sample < $samples && $gap_ms > 0} {
        after $gap_ms
      }
    }
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "HPLL_HELPER_CORRELATION_DONE"
