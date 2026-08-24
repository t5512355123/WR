# Step 4 deglitch FSM / accept boundary read-only diagnostic.
#
# 本腳本只讀取現有 SoftPLL diagnostics，並透過既有 Wishbone mailbox 發出
# read command；不寫任何 Wishbone control register、不讀 TRR_R0，也不改變
# FPGA、firmware 或 SoftPLL 行為。
#
# Source-backed fields:
#   0x001002DC  diag_dmtd_state
#                 ref state  [1:0], fb state [3:2]
#                 ref reset  [8],   fb reset [9]
#                 ref bucket [17:10], fb bucket [25:18]
#                 ref reached [26], fb reached [27]
#   0x00100234/238  sampled transition counters
#   0x0010022C/230  deglitch accept counters
#   0x00100298/29C  post-deglitch DMTD event counters
#   0x00100284/288  tag-valid / TRR-write counters
#   0x00100248      deglitch threshold
#   0x0010023C      maximum HIGH qualification depth
#   0x0010025C      maximum clk_i_d0 LOW run
#
# The state encoding is defined by dmtd_with_deglitcher.vhd:
#   0 = WAIT_STABLE_0, 1 = WAIT_EDGE, 2 = GOT_EDGE.
#
# Usage:
#   quartus_stp -t read_step4_deglitch_state.tcl ?samples? ?gap_ms? ?--raw?

package require ::quartus::insystem_source_probe

set samples 30
set gap_ms 500
set raw_mode 0
if {[llength $argv] >= 1 && ![string equal [lindex $argv 0] "--raw"]} {
  set samples [expr {int([lindex $argv 0])}]
}
if {[llength $argv] >= 2 && ![string equal [lindex $argv 1] "--raw"]} {
  set gap_ms [expr {int([lindex $argv 1])}]
}
if {[lsearch -exact $argv --raw] >= 0} { set raw_mode 1 }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

set ::wb_toggle 0
set ::max_read_attempts 5
array set ::stats {}

proc is_word32 {value} {
  return [regexp {^[0-9A-Fa-f]{1,8}$} [string trim $value]]
}

proc word32 {value} {
  if {![is_word32 $value]} { return -1 }
  if {[catch {scan [string trim $value] %x word}]} { return -1 }
  return [expr {$word & 0xffffffff}]
}

proc is_stale {value} {
  set word [word32 $value]
  if {$word < 0} { return 0 }
  return [expr {(($word >> 16) & 0xffff) == 0xA5A5}]
}

proc wb_sync_toggle {} {
  if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
    return 0
  }
  if {![regexp {^[0-9A-Fa-f]{1,16}$} [string trim $value]]} {
    return 0
  }
  if {[catch {scan [string trim $value] %x word}]} { return 0 }
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
  return 1
}

proc wb_read_once {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set command [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $command] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 5
  for {set n 0} {$n < 100} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      return TIMEOUT
    }
    set value [string trim $value]
    if {[regexp {^[0-9A-Fa-f]{1,16}$} $value] &&
        ![catch {scan $value %x word}]} {
      set done_toggle [expr {(($word >> 35) & 1)}]
      set active [expr {(($word >> 36) & 1)}]
      if {$done_toggle == $::wb_toggle && $active == 0} {
        return [format %08X [expr {$word & 0xffffffff}]]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc register_valid {addr value} {
  if {$value eq "TIMEOUT" || $value eq "INVALID" || ![is_word32 $value] || [is_stale $value]} {
    return 0
  }
  set word [word32 $value]
  if {$word < 0} { return 0 }
  if {[format "0x%08X" [expr {$addr & 0xffffffff}]] eq "0x001002DC"} {
    set ref_state [expr {$word & 0x3}]
    set fb_state [expr {($word >> 2) & 0x3}]
    return [expr {$ref_state <= 2 && $fb_state <= 2}]
  }
  return 1
}

proc wb_read_validated {addr} {
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set value [wb_read_once $addr]
    if {[register_valid $addr $value]} { return $value }
    if {$attempt < $::max_read_attempts} {
      wb_sync_toggle
      after 2
    }
  }
  return INVALID
}

proc delta32 {first last} {
  if {![is_word32 $first] || ![is_word32 $last]} { return INVALID }
  set a [word32 $first]
  set b [word32 $last]
  if {$a < 0 || $b < 0} { return INVALID }
  return [expr {($b - $a) & 0xffffffff}]
}

proc positive_delta {value} {
  if {![regexp {^[0-9]+$} $value]} { return 0 }
  if {[catch {expr {$value > 0}} result]} { return 0 }
  return $result
}

proc stats_init {board label} {
  set ::stats($board,$label,first) ""
  set ::stats($board,$label,last) ""
  set ::stats($board,$label,invalid) 0
}

proc stats_add {board label value} {
  if {![is_word32 $value]} {
    incr ::stats($board,$label,invalid)
    return
  }
  if {$::stats($board,$label,first) eq ""} {
    set ::stats($board,$label,first) $value
  }
  set ::stats($board,$label,last) $value
}

proc state_init {board side} {
  foreach state {0 1 2} { set ::stats($board,$side,state,$state) 0 }
  set ::stats($board,$side,state_invalid) 0
  set ::stats($board,$side,state_last) -1
  set ::stats($board,$side,state_transitions) 0
  set ::stats($board,$side,reached_samples) 0
}

proc state_add {board side state reached} {
  if {$state < 0 || $state > 2} {
    incr ::stats($board,$side,state_invalid)
    return
  }
  incr ::stats($board,$side,state,$state)
  if {$::stats($board,$side,state_last) >= 0 &&
      $::stats($board,$side,state_last) != $state} {
    incr ::stats($board,$side,state_transitions)
  }
  set ::stats($board,$side,state_last) $state
  if {$reached == 1} { incr ::stats($board,$side,reached_samples) }
}

proc state_name {state} {
  switch -- $state {
    0 { return WAIT_STABLE_0 }
    1 { return WAIT_EDGE }
    2 { return GOT_EDGE }
    default { return INVALID }
  }
}

proc read_snapshot {snapshot_name} {
  upvar 1 $snapshot_name snap
  array set snap {}
  set snap(state) [wb_read_validated 0x001002DC]
  set snap(sampled_ref) [wb_read_validated 0x00100234]
  set snap(sampled_fb) [wb_read_validated 0x00100238]
  set snap(accept_ref) [wb_read_validated 0x0010022C]
  set snap(accept_fb) [wb_read_validated 0x00100230]
  set snap(event_ref) [wb_read_validated 0x00100298]
  set snap(event_fb) [wb_read_validated 0x0010029C]
  set snap(tag_valid) [wb_read_validated 0x00100284]
  set snap(trr_write) [wb_read_validated 0x00100288]
  set snap(threshold) [wb_read_validated 0x00100248]
  set snap(high_qual_max) [wb_read_validated 0x0010023C]
  set snap(d0_low_run_max) [wb_read_validated 0x0010025C]
  set snap(lock_enable) [wb_read_validated 0x00100A9C]
  set snap(spll_state) [wb_read_validated 0x00100AA0]
  set snap(irq) [wb_read_validated 0x00100AEC]
  set snap(helper_update) [wb_read_validated 0x00100B18]
}

proc decode_state {state side field} {
  set word [word32 $state]
  if {$word < 0} { return -1 }
  if {$side eq "REF"} {
    if {$field eq "state"} { return [expr {$word & 0x3}] }
    if {$field eq "reset"} { return [expr {($word >> 8) & 1}] }
    if {$field eq "bucket"} { return [expr {($word >> 10) & 0xff}] }
    if {$field eq "reached"} { return [expr {($word >> 26) & 1}] }
  } else {
    if {$field eq "state"} { return [expr {($word >> 2) & 0x3}] }
    if {$field eq "reset"} { return [expr {($word >> 9) & 1}] }
    if {$field eq "bucket"} { return [expr {($word >> 18) & 0xff}] }
    if {$field eq "reached"} { return [expr {($word >> 27) & 1}] }
  }
  return -1
}

proc print_raw_snapshot {board sample snap_name} {
  upvar 1 $snap_name snap
  foreach label {state sampled_ref sampled_fb accept_ref accept_fb event_ref event_fb \
                 tag_valid trr_write threshold high_qual_max d0_low_run_max \
                 lock_enable spll_state irq helper_update} {
    puts [format "DEGLITCH_RAW board=%s sample=%03d register=%s value=%s" \
          $board $sample $label $snap($label)]
  }
}

proc print_sample {board sample snap_name} {
  upvar 1 $snap_name snap
  set state_word [word32 $snap(state)]
  set ref_state [decode_state $snap(state) REF state]
  set fb_state [decode_state $snap(state) FB state]
  set ref_reset [decode_state $snap(state) REF reset]
  set fb_reset [decode_state $snap(state) FB reset]
  set ref_bucket [decode_state $snap(state) REF bucket]
  set fb_bucket [decode_state $snap(state) FB bucket]
  set ref_reached [decode_state $snap(state) REF reached]
  set fb_reached [decode_state $snap(state) FB reached]
  puts [format "DEGLITCH_SAMPLE board=%s sample=%03d STATE=REF:%s(%d) FB:%s(%d) RESET=REF:%s FB:%s BUCKET=REF:%s FB:%s REACHED=REF:%s FB:%s SAMPLED=%s/%s ACCEPT=%s/%s EVENT=%s/%s TAG=%s TRR=%s" \
        $board $sample [state_name $ref_state] $ref_state [state_name $fb_state] $fb_state \
        $ref_reset $fb_reset $ref_bucket $fb_bucket $ref_reached $fb_reached \
        $snap(sampled_ref) $snap(sampled_fb) $snap(accept_ref) $snap(accept_fb) \
        $snap(event_ref) $snap(event_fb) $snap(tag_valid) $snap(trr_write)]
  if {$::raw_mode} { print_raw_snapshot $board $sample snap }
}

proc init_board {board} {
  foreach label {sampled_ref sampled_fb accept_ref accept_fb event_ref event_fb \
                 tag_valid trr_write threshold high_qual_max d0_low_run_max \
                 lock_enable spll_state irq helper_update} {
    stats_init $board $label
  }
  state_init $board REF
  state_init $board FB
}

proc add_snapshot {board snap_name} {
  upvar 1 $snap_name snap
  foreach label {sampled_ref sampled_fb accept_ref accept_fb event_ref event_fb \
                 tag_valid trr_write threshold high_qual_max d0_low_run_max \
                 lock_enable spll_state irq helper_update} {
    stats_add $board $label $snap($label)
  }
  set ref_state [decode_state $snap(state) REF state]
  set fb_state [decode_state $snap(state) FB state]
  state_add $board REF $ref_state [decode_state $snap(state) REF reached]
  state_add $board FB $fb_state [decode_state $snap(state) FB reached]
}

proc summary_delta {board label} {
  return [delta32 $::stats($board,$label,first) $::stats($board,$label,last)]
}

proc print_summary {board} {
  set sampled_ref [summary_delta $board sampled_ref]
  set sampled_fb [summary_delta $board sampled_fb]
  set accept_ref [summary_delta $board accept_ref]
  set accept_fb [summary_delta $board accept_fb]
  set event_ref [summary_delta $board event_ref]
  set event_fb [summary_delta $board event_fb]
  set tag_valid [summary_delta $board tag_valid]
  set trr_write [summary_delta $board trr_write]
  set irq [summary_delta $board irq]
  set helper_update [summary_delta $board helper_update]

  set boundary REF_SAMPLED_ONLY
  if {$sampled_ref eq "INVALID" || $sampled_fb eq "INVALID" ||
      $accept_ref eq "INVALID" || $accept_fb eq "INVALID" ||
      $event_ref eq "INVALID" || $event_fb eq "INVALID" ||
      $tag_valid eq "INVALID" || $trr_write eq "INVALID"} {
    set boundary MEASUREMENT_INVALID
  } elseif {[positive_delta $accept_ref] || [positive_delta $accept_fb]} {
    if {[positive_delta $event_ref] || [positive_delta $event_fb]} {
      if {[positive_delta $tag_valid] || [positive_delta $trr_write]} {
        set boundary ACCEPT_EVENT_TAG_ACTIVE
      } else {
        set boundary ACCEPT_TO_TAG_INACTIVE
      }
    } else {
      set boundary ACCEPT_TO_POST_CDC_INACTIVE
    }
  } elseif {[positive_delta $sampled_ref] || [positive_delta $sampled_fb]} {
    set boundary SAMPLED_TO_DEGLITCH_ACCEPT_INACTIVE
  } else {
    set boundary NO_SAMPLED_TRANSITION
  }

  puts [format "DEGLITCH_SUMMARY board=%s SAMPLED=%s/%s ACCEPT=%s/%s EVENT=%s/%s TAG=%s TRR=%s IRQ=%s HELPER_UPDATE=%s" \
        $board $sampled_ref $sampled_fb $accept_ref $accept_fb $event_ref $event_fb \
        $tag_valid $trr_write $irq $helper_update]
  puts [format "DEGLITCH_STATE_COUNTS board=%s REF=WAIT_STABLE_0:%d,WAIT_EDGE:%d,GOT_EDGE:%d INVALID:%d TRANSITIONS:%d REACHED_SAMPLES:%d" \
        $board $::stats($board,REF,state,0) $::stats($board,REF,state,1) \
        $::stats($board,REF,state,2) $::stats($board,REF,state_invalid) \
        $::stats($board,REF,state_transitions) $::stats($board,REF,reached_samples)]
  puts [format "DEGLITCH_STATE_COUNTS board=%s FB=WAIT_STABLE_0:%d,WAIT_EDGE:%d,GOT_EDGE:%d INVALID:%d TRANSITIONS:%d REACHED_SAMPLES:%d" \
        $board $::stats($board,FB,state,0) $::stats($board,FB,state,1) \
        $::stats($board,FB,state,2) $::stats($board,FB,state_invalid) \
        $::stats($board,FB,state_transitions) $::stats($board,FB,reached_samples)]
  puts [format "DEGLITCH_FIRST_INACTIVE_BOUNDARY board=%s result=%s" $board $boundary]
  foreach label {sampled_ref sampled_fb accept_ref accept_fb event_ref event_fb tag_valid trr_write irq helper_update} {
    if {$::stats($board,$label,invalid) > 0} {
      puts [format "DEGLITCH_INVALID_SAMPLES board=%s register=%s count=%d" \
            $board $label $::stats($board,$label,invalid)]
    }
  }
  flush stdout
}

puts [format "DEGLITCH_STATE_CONFIG samples=%d gap_ms=%d raw=%d trr_r0_read=disabled" \
      $samples $gap_ms $raw_mode]

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    init_board $hardware_name
    for {set sample 1} {$sample <= $samples} {incr sample} {
      array set snapshot {}
      read_snapshot snapshot
      add_snapshot $hardware_name snapshot
      print_sample $hardware_name $sample snapshot
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
    print_summary $hardware_name
  } error_message]} {
    puts [format "DEGLITCH_ERROR board=%s error=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "DEGLITCH_STATE_DONE"
