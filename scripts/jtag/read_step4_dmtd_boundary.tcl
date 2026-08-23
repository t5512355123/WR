# Step 4 DMTD -> tags_p 邊界唯讀診斷。
#
# 本腳本只讀取 SoftPLL Wishbone register，不寫入任何設定，也不讀取
# TRR_R0，避免消費 tag FIFO。目的在於把下列兩種情況分開：
#
#   A. DMTD/deglitcher 沒有新的 event
#   B. DMTD event 有活動，但沒有形成 tags_p / tags_req
#
# 讀取內容包括：DMTD state/reset、deglitch threshold、RCER/OCER、
# DMTD event counter、tag counter、tag last-tick 與 request/grant 結果。
# 用法：
#   quartus_stp -t read_step4_dmtd_boundary.tcl ?samples? ?gap_ms?

package require ::quartus::insystem_source_probe

set samples 20
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
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
}

proc read_boundary_sample {hardware_name sample} {
  set status [read_probe_data -instance_index 0 -value_in_hex]

  # SoftPLL core registers. DMTD_STAT_CR/VAL and DEGLITCH_THR are read-only
  # in this script; no control write or one-shot reset is issued.
  set csr [wb_read 0x00100200]
  set dmtd_stat_cr [wb_read 0x00100214]
  set dmtd_stat_val [wb_read 0x00100218]
  set rcer [wb_read 0x00100224]
  set ocer [wb_read 0x00100228]
  set dmtd_ref_accept [wb_read 0x0010022C]
  set dmtd_fb_accept [wb_read 0x00100230]
  set dmtd_ref_sampled [wb_read 0x00100234]
  set dmtd_fb_sampled [wb_read 0x00100238]
  set dmtd_high_qual_max_stab [wb_read 0x0010023C]
  set dmtd_input_high_run_max [wb_read 0x00100250]
  set dmtd_input_low_run_max [wb_read 0x00100254]
  set dmtd_d1_high_run_max [wb_read 0x00100258]
  set dmtd_d0_low_run_max [wb_read 0x0010025C]
  set deglitch_thr [wb_read 0x00100248]
  set eic_ier [wb_read 0x00100264]
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

  puts [format "DMTD_BOUNDARY_SAMPLE board=%s sample=%03d STATUS=%s" \
        $hardware_name $sample $status]
  set stab_word 0
  if {[scan $dmtd_high_qual_max_stab %x stab_word] == 1} {
    set stab_ref [format %04X [expr {$stab_word & 0xffff}]]
    set stab_fb [format %04X [expr {($stab_word >> 16) & 0xffff}]]
  } else {
    set stab_ref NA
    set stab_fb NA
  }
  set low_run_word 0
  if {[scan $dmtd_input_low_run_max %x low_run_word] == 1} {
    puts [format "DMTD_INPUT_LOW_RUN_MAX ref=%s fb=%s" \
          [format %04X [expr {$low_run_word & 0xffff}]] \
          [format %04X [expr {($low_run_word >> 16) & 0xffff}]]]
  } else {
    puts "DMTD_INPUT_LOW_RUN_MAX invalid"
  }
  set d1_high_run_word 0
  if {[scan $dmtd_d1_high_run_max %x d1_high_run_word] == 1} {
    puts [format "DMTD_D1_HIGH_RUN_MAX ref=%s fb=%s" \
          [format %04X [expr {$d1_high_run_word & 0xffff}]] \
          [format %04X [expr {($d1_high_run_word >> 16) & 0xffff}]]]
  } else {
    puts "DMTD_D1_HIGH_RUN_MAX invalid"
  }
  set d0_low_run_word 0
  if {[scan $dmtd_d0_low_run_max %x d0_low_run_word] == 1} {
    puts [format "DMTD_D0_LOW_RUN_MAX ref=%s fb=%s" \
          [format %04X [expr {$d0_low_run_word & 0xffff}]] \
          [format %04X [expr {($d0_low_run_word >> 16) & 0xffff}]]]
  } else {
    puts "DMTD_D0_LOW_RUN_MAX invalid"
  }
  set input_run_word 0
  if {[scan $dmtd_input_high_run_max %x input_run_word] == 1} {
    set input_run_ref [format %04X [expr {$input_run_word & 0xffff}]]
    set input_run_fb [format %04X [expr {($input_run_word >> 16) & 0xffff}]]
  } else {
    set input_run_ref NA
    set input_run_fb NA
  }
  puts [format "DMTD_BOUNDARY_CORE: CSR=%s STAT_CR=%s STAT_VAL=%s DEGLITCH_THR=%s SAMPLED_REF=%s SAMPLED_FB=%s ACCEPT_REF=%s ACCEPT_FB=%s MAX_HIGH_REF=%s MAX_HIGH_FB=%s" \
        $csr $dmtd_stat_cr $dmtd_stat_val $deglitch_thr $dmtd_ref_sampled $dmtd_fb_sampled \
        $dmtd_ref_accept $dmtd_fb_accept $stab_ref $stab_fb]
  puts [format "DMTD_BOUNDARY_INPUT_RUN: MAX_HIGH_REF=%s MAX_HIGH_FB=%s" \
        $input_run_ref $input_run_fb]
  puts [format "DMTD_BOUNDARY_ENABLE: RCER=%s OCER=%s EIC_IER=%s EIC_IMR=%s EIC_ISR=%s TRR_CSR=%s" \
        $rcer $ocer $eic_ier $eic_imr $eic_isr $trr_csr]
  puts [format "DMTD_BOUNDARY_EVENT: REF=%s FB=%s REF_SEEN=%s FB_SEEN=%s REF_LAST=%s FB_LAST=%s NOW=%s" \
        $dmtd_ref_events $dmtd_fb_events $dmtd_ref_seen $dmtd_fb_seen \
        $dmtd_ref_last_tics $dmtd_fb_last_tics $current_tics]
  puts [format "DMTD_BOUNDARY_QUAL_ABORT: REF_HIGH=%s FB_HIGH=%s" \
        $dmtd_ref_seen $dmtd_fb_seen]
  puts [format "DMTD_BOUNDARY_TAG: SOURCE=%s REF=%s FB=%s REF_LAST=%s FB_LAST=%s" \
        $tag_source $tag_ref $tag_feedback $tag_ref_last_tics $tag_feedback_last_tics]
  puts [format "DMTD_BOUNDARY_ARB: PENDING=%s GRANT=%s PENDING_LAST=%s GRANT_LAST=%s" \
        $tag_pending $tag_grant $tag_pending_last_tics $tag_grant_last_tics]
  puts [format "DMTD_BOUNDARY_OUTPUT: VALID=%s TRR_WRITE=%s VALID_LAST=%s TRR_LAST=%s" \
        $tag_valid $trr_write $tag_valid_last_tics $trr_write_last_tics]
  puts [format "DMTD_BOUNDARY_GATE: REF_ENABLED=%s FB_ENABLED=%s REF_REQ_SET=%s FB_REQ_SET=%s" \
        $tag_ref_enabled $tag_feedback_enabled $tag_req_ref_set $tag_req_feedback_set]
  puts [format "DMTD_BOUNDARY_GATE_LAST: REF_ENABLED=%s FB_ENABLED=%s REF_REQ=%s FB_REQ=%s" \
        $tag_ref_enabled_last_tics $tag_feedback_enabled_last_tics \
        $tag_req_ref_last_tics $tag_req_feedback_last_tics]
  set dmtd_state_word 0
  if {[scan $dmtd_state %x dmtd_state_word] == 1} {
    puts [format "DMTD_BOUNDARY_STATE: RAW=%s REF_STATE=%d FB_STATE=%d REF_RESET=%d FB_RESET=%d" \
          $dmtd_state \
          [expr {$dmtd_state_word & 0x3}] \
          [expr {($dmtd_state_word >> 2) & 0x3}] \
          [expr {($dmtd_state_word >> 8) & 0x1}] \
          [expr {($dmtd_state_word >> 9) & 0x1}]]
  } else {
    puts [format "DMTD_BOUNDARY_STATE: RAW=%s REF_STATE=NA FB_STATE=NA REF_RESET=NA FB_RESET=NA" \
          $dmtd_state]
  }
  flush stdout
}

puts [format "DMTD_BOUNDARY_CONFIG samples=%d gap_ms=%d trr_r0_read=disabled" $samples $gap_ms]

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
      read_boundary_sample $hardware_name $sample
      if {$sample < $samples && $gap_ms > 0} {
        after $gap_ms
      }
    }
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "DMTD_BOUNDARY_DONE"
