# Step 4 DMTD event 極簡唯讀 confirmation。
#
# 只讀取少量 register，降低 JTAG mailbox 多欄位讀取造成的 snapshot 干擾。
# 不寫入設定、不讀取 TRR_R0、不改變 SoftPLL/WR 控制行為。
#
# 用法：
#   quartus_stp -t read_step4_dmtd_minimal.tcl ?samples? ?gap_ms?

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
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
}

proc read_minimal_sample {hardware_name sample} {
  set status [read_probe_data -instance_index 0 -value_in_hex]
  set current_tics [wb_read 0x001002B0]
  set dmtd_ref_events [wb_read 0x00100298]
  set dmtd_fb_events [wb_read 0x0010029C]
  set dmtd_ref_last_tics [wb_read 0x001002B4]
  set dmtd_fb_last_tics [wb_read 0x001002B8]
  set dmtd_state [wb_read 0x001002DC]
  set rcer [wb_read 0x00100224]
  set ocer [wb_read 0x00100228]
  set tag_ref [wb_read 0x00100290]
  set tag_feedback [wb_read 0x00100294]

  set dmtd_state_word 0
  if {[scan $dmtd_state %x dmtd_state_word] == 1} {
    set ref_state [expr {$dmtd_state_word & 0x3}]
    set fb_state [expr {($dmtd_state_word >> 2) & 0x3}]
    set ref_reset [expr {($dmtd_state_word >> 8) & 0x1}]
    set fb_reset [expr {($dmtd_state_word >> 9) & 0x1}]
  } else {
    set ref_state NA
    set fb_state NA
    set ref_reset NA
    set fb_reset NA
  }

  puts [format "DMTD_MIN_SAMPLE board=%s sample=%03d STATUS=%s NOW=%s REF_EVENTS=%s FB_EVENTS=%s REF_LAST=%s FB_LAST=%s STATE=%s REF_STATE=%s FB_STATE=%s REF_RESET=%s FB_RESET=%s RCER=%s OCER=%s TAG_REF=%s TAG_FB=%s" \
        $hardware_name $sample $status $current_tics $dmtd_ref_events \
        $dmtd_fb_events $dmtd_ref_last_tics $dmtd_fb_last_tics $dmtd_state \
        $ref_state $fb_state $ref_reset $fb_reset $rcer $ocer $tag_ref \
        $tag_feedback]
  flush stdout
}

puts [format "DMTD_MIN_CONFIG samples=%d gap_ms=%d trr_r0_read=disabled" $samples $gap_ms]

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
      read_minimal_sample $hardware_name $sample
      if {$sample < $samples && $gap_ms > 0} {
        after $gap_ms
      }
    }
  } error_message]} {
    puts "error: ${error_message}"
  }
  catch { end_insystem_source_probe }
}

puts "DMTD_MIN_DONE"
