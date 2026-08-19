# Step 4 runtime-context discriminator。
#
# 只讀取 SoftPLL state、timer/timeout、init/SEQ_CLEAR_DACS 計數器與
# raw event counters，不讀 TRR_R0，不寫入任何設定。
# 用法：quartus_stp -t read_step4_runtime_context.tcl ?samples? ?gap_ms?

package require ::quartus::insystem_source_probe

set samples 10
set gap_ms 1000
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
  set current_done [expr {(($word >> 35) & 1)}]
  set ::wb_toggle $current_done
}

proc read_context_sample {hardware_name sample} {
  set status [read_probe_data -instance_index 0 -value_in_hex]
  set ptp [wb_read 0x00100A10]
  set ptp_meta [wb_read 0x00100A5C]
  set foreign_meta [wb_read 0x00100A78]
  set lock_enable [wb_read 0x00100A9C]
  set spll_state [wb_read 0x00100AA0]
  set spll_ocer [wb_read 0x00100AA4]
  set spll_rcer [wb_read 0x00100AA8]
  set spll_trr_csr [wb_read 0x00100AB0]
  set eic_imr [wb_read 0x00100AF0]
  set eic_isr [wb_read 0x00100AF4]
  set tag_valid [wb_read 0x00100AF8]
  set trr_write [wb_read 0x00100AFC]
  set ref_count [wb_read 0x00100AD0]
  set tag_count [wb_read 0x00100AD4]
  set irq_count [wb_read 0x00100AEC]
  set helper_updates [wb_read 0x00100B18]
  set current_tics [wb_read 0x00100B3C]
  set dac_timeout [wb_read 0x00100B40]
  set init_count [wb_read 0x00100B44]
  set clear_count [wb_read 0x00100B48]
  set last_init_tics [wb_read 0x00100B4C]
  set last_clear_tics [wb_read 0x00100B50]

  puts [format "STEP4_CONTEXT_SAMPLE board=%s sample=%03d STATUS=%s PTP=%s PTP_META=%s FOREIGN_META=%s LOCK_ENABLE=%s SPLL_STATE=%s OCER=%s RCER=%s TRR_CSR=%s EIC_IMR=%s EIC_ISR=%s TAG_VALID=%s TRR_WRITE=%s REF=%s TAG=%s IRQ=%s HELPER_UPDATE=%s CURRENT_TICS=%s DAC_TIMEOUT=%s INIT_COUNT=%s CLEAR_DACS_COUNT=%s LAST_INIT_TICS=%s LAST_CLEAR_TICS=%s" \
        $hardware_name $sample $status $ptp $ptp_meta $foreign_meta \
        $lock_enable $spll_state $spll_ocer $spll_rcer $spll_trr_csr \
        $eic_imr $eic_isr $tag_valid $trr_write $ref_count $tag_count \
        $irq_count $helper_updates $current_tics $dac_timeout $init_count \
        $clear_count $last_init_tics $last_clear_tics]
  flush stdout
}

puts [format "STEP4_CONTEXT_CONFIG samples=%d gap_ms=%d" $samples $gap_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_context_sample $hardware_name $sample
      if {$sample < $samples && $gap_ms > 0} {
        after $gap_ms
      }
    }
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "STEP4_CONTEXT_DONE"
