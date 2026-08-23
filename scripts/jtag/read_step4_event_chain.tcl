# Step 4 SoftPLL raw event-chain 唯讀診斷。
#
# 只透過既有 Wishbone mailbox 讀取：
#   reference/tag counters -> TRR status -> tag IRQ registers -> helper state
# 不寫入任何設定，不寫 WDIAGS snapshot，也不讀 TRR_R0。
# TRR_R0 是 FIFO data output，讀取它可能消費 tag，因此刻意不碰。
#
# 用法：
#   quartus_stp -t read_step4_event_chain.tcl ?gap_ms?

package require ::quartus::insystem_source_probe

set gap_ms 1000
if {[llength $argv] >= 1} {
  set gap_ms [expr {int([lindex $argv 0])}]
}
if {$gap_ms < 0} {
  error "gap_ms must be >= 0"
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

proc read_sample {hardware_name label} {
  set status [read_probe_data -instance_index 0 -value_in_hex]

  set csr [wb_read 0x00100200]
  set eccr [wb_read 0x00100204]
  set occr [wb_read 0x00100210]
  set rcer [wb_read 0x00100224]
  set ocer [wb_read 0x00100228]
  set d1_pipeline_mismatch_ref [wb_read 0x00100260]
  set d1_pipeline_mismatch_fb [wb_read 0x00100264]
  set eic_imr [wb_read 0x00100268]
  set eic_isr [wb_read 0x0010026C]
  set trr_csr [wb_read 0x00100280]
  set tag_valid [wb_read 0x00100284]
  set trr_write [wb_read 0x00100288]
  set tag_source [wb_read 0x0010028C]
  set tag_ref [wb_read 0x00100290]
  set tag_feedback [wb_read 0x00100294]
  set dmtd_ref_events [wb_read 0x00100298]
  set dmtd_fb_events [wb_read 0x0010029C]
  set dmtd_ref_seen [wb_read 0x001002A0]
  set dmtd_fb_seen [wb_read 0x001002A4]
  set tag_pending [wb_read 0x001002A8]
  set tag_grant [wb_read 0x001002AC]
  set current_tics [wb_read 0x001002B0]
  set dmtd_ref_last_tics [wb_read 0x001002B4]
  set dmtd_fb_last_tics [wb_read 0x001002B8]
  set tag_ref_last_tics [wb_read 0x001002BC]
  set tag_feedback_last_tics [wb_read 0x001002C0]
  set tag_pending_ref_count [wb_read 0x001002C4]
  set tag_pending_fb_count [wb_read 0x001002C8]
  set tag_pending_last_tics [wb_read 0x001002CC]
  set tag_grant_last_tics [wb_read 0x001002D0]
  set tag_valid_last_tics [wb_read 0x001002D4]
  set trr_write_last_tics [wb_read 0x001002D8]
  set dmtd_state [wb_read 0x001002DC]
  set tag_ref_enabled [wb_read 0x001002E0]
  set tag_feedback_enabled [wb_read 0x001002E4]
  set tag_req_ref_set [wb_read 0x001002E8]
  set tag_req_feedback_set [wb_read 0x001002EC]
  set tag_ref_enabled_last_tics [wb_read 0x001002F0]
  set tag_feedback_enabled_last_tics [wb_read 0x001002F4]
  set tag_req_ref_last_tics [wb_read 0x001002F8]
  set tag_req_feedback_last_tics [wb_read 0x001002FC]

  set sstat [wb_read 0x00100A08]
  set pstat [wb_read 0x00100A0C]
  set lock_enable [wb_read 0x00100A9C]
  set spll_state [wb_read 0x00100AA0]
  set helper_state [wb_read 0x00100ABC]
  set helper_error [wb_read 0x00100AD8]
  set helper_output [wb_read 0x00100ADC]
  set ref_count [wb_read 0x00100AD0]
  set tag_count [wb_read 0x00100AD4]
  set irq_count [wb_read 0x00100AEC]
  set helper_update_count [wb_read 0x00100B18]

  puts [format "EVENT_CHAIN_SAMPLE board=%s label=%s status=%s" \
        $hardware_name $label $status]
  puts [format "EVENT_CHAIN_HW: CSR=%s ECCR=%s OCCR=%s RCER=%s OCER=%s" \
        $csr $eccr $occr $rcer $ocer]
  puts [format "EVENT_CHAIN_EIC: IMR=%s ISR=%s" $eic_imr $eic_isr]
  puts [format "EVENT_CHAIN_D1_PIPELINE_MISMATCH: REF=%s FB=%s" \
        $d1_pipeline_mismatch_ref $d1_pipeline_mismatch_fb]
  puts [format "EVENT_CHAIN_TRR: CSR=%s TAG_VALID=%s TRR_WRITE=%s TAG_SOURCE=%s REF=%s FEEDBACK=%s" \
        $trr_csr $tag_valid $trr_write $tag_source $tag_ref $tag_feedback]
  puts [format "EVENT_CHAIN_DMTD: REF_EVENTS=%s FB_EVENTS=%s REF_SEEN=%s FB_SEEN=%s" \
        $dmtd_ref_events $dmtd_fb_events $dmtd_ref_seen $dmtd_fb_seen]
  puts [format "EVENT_CHAIN_ARB: PENDING=%s GRANT=%s" $tag_pending $tag_grant]
  puts [format "EVENT_CHAIN_TICS: NOW=%s DMTD_REF_LAST=%s DMTD_FB_LAST=%s TAG_REF_LAST=%s TAG_FB_LAST=%s" \
        $current_tics $dmtd_ref_last_tics $dmtd_fb_last_tics $tag_ref_last_tics $tag_feedback_last_tics]
  puts [format "EVENT_CHAIN_REQ: REF_COUNT=%s FB_COUNT=%s LAST=%s" \
        $tag_pending_ref_count $tag_pending_fb_count $tag_pending_last_tics]
  puts [format "EVENT_CHAIN_GATE: REF_P_ENABLED=%s FB_P_ENABLED=%s REF_REQ_SET=%s FB_REQ_SET=%s" \
        $tag_ref_enabled $tag_feedback_enabled $tag_req_ref_set $tag_req_feedback_set]
  puts [format "EVENT_CHAIN_GATE_LAST: REF_P=%s FB_P=%s REF_REQ=%s FB_REQ=%s" \
        $tag_ref_enabled_last_tics $tag_feedback_enabled_last_tics \
        $tag_req_ref_last_tics $tag_req_feedback_last_tics]
  puts [format "EVENT_CHAIN_LAST: GRANT=%s VALID=%s TRR=%s" \
        $tag_grant_last_tics $tag_valid_last_tics $trr_write_last_tics]
  set dmtd_state_word 0
  if {[scan $dmtd_state %x dmtd_state_word] == 1} {
    puts [format "EVENT_CHAIN_DMTD_STATE: VALUE=%s REF_STATE=%d FB_STATE=%d REF_RESET=%d FB_RESET=%d" \
          $dmtd_state [expr {($dmtd_state_word & 0x3)}] \
          [expr {(($dmtd_state_word >> 2) & 0x3)}] \
          [expr {(($dmtd_state_word >> 8) & 0x1)}] \
          [expr {(($dmtd_state_word >> 9) & 0x1)}]]
  } else {
    puts [format "EVENT_CHAIN_DMTD_STATE: VALUE=%s REF_STATE=NA FB_STATE=NA REF_RESET=NA FB_RESET=NA" \
          $dmtd_state]
  }
  puts [format "EVENT_CHAIN_WR: SSTAT=%s PSTAT=%s LOCK_ENABLE=%s SPLL_STATE=%s" \
        $sstat $pstat $lock_enable $spll_state]
  puts [format "EVENT_CHAIN_HELPER: STATE=%s ERROR=%s OUTPUT=%s REF_COUNT=%s TAG_COUNT=%s IRQ_COUNT=%s UPDATE_COUNT=%s" \
        $helper_state $helper_error $helper_output $ref_count $tag_count \
        $irq_count $helper_update_count]
  flush stdout
}

puts [format "EVENT_CHAIN_CONFIG gap_ms=%d trr_r0_read=disabled" $gap_ms]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    read_sample $hardware_name BEGIN
    after $gap_ms
    read_sample $hardware_name END
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "EVENT_CHAIN_DONE"
