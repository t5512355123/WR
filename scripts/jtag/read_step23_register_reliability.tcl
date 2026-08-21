# Step 2 / Step 3 JTAG mailbox reliability test。
#
# 用法：
#   quartus_stp -t read_step23_register_reliability.tcl ?samples? ?gap_ms? ?group?
#
# group：
#   temp   只重複讀 WDIAGS_TEMP
#   step2  逐一讀 Endpoint / PTP / MiniNIC registers
#   step3  逐一讀 parent / WR signaling / LOCK_ENABLE / WDIAGS_TEMP
#   all    依序執行 temp、step2、step3
#
# 本腳本只讀取既有 JTAG probe 與 Wishbone mailbox，不寫入 control register，
# 不寫 DATA_SNAPSHOT，也不修改任何 FPGA/firmware 功能。每一組 register
# 先連續讀取同一個 address，再換下一個 address，避免把非 atomic mailbox
# 欄位誤拼成同一個時間點的 snapshot。

package require ::quartus::insystem_source_probe

set samples 30
set gap_ms 250
set group all
set raw_mode 0
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set group [lindex $argv 2] }
if {[lsearch -exact $argv --raw] >= 0} { set raw_mode 1 }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}
if {[lsearch -exact {temp step2 step3 all} $group] < 0} {
  error "group must be temp, step2, step3, or all"
}

set ::wb_toggle 0
set ::max_read_attempts 5
array set ::series {}

proc u64 {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc u32 {value} {
  return [regexp {^[0-9A-Fa-f]{1,8}$} $value]
}

proc word32 {value} {
  if {![u32 $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc stale_jtag_word {value} {
  set word [word32 $value]
  if {$word < 0} { return 0 }
  return [expr {(($word >> 16) & 0xffff) == 0xA5A5}]
}

proc wb_sync_toggle {} {
  set value [read_probe_data -instance_index 1 -value_in_hex]
  if {![u64 $value]} {
    set ::wb_toggle 0
    return
  }
  scan $value %x word
  set ::wb_toggle [expr {(($word >> 35) & 1)}]
}

proc wb_read {addr} {
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set command [expr {$::wb_toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  write_source_data -instance_index 1 -value [format %024X $command] -value_in_hex
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [read_probe_data -instance_index 1 -value_in_hex]
    if {![u64 $value]} {
      after 1
      continue
    }
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

proc register_valid {addr value} {
  set word [word32 $value]
  if {$word < 0 || [stale_jtag_word $value]} { return 0 }
  set key [format "0x%08X" [expr {$addr & 0xffffffff}]]
  switch -- $key {
    0x00100124 { return [expr {$word == 0x02000200}] }
    0x00100128 { return [expr {$word == 0x22334401 || $word == 0x22334402}] }
    0x00100A10 { return [expr {$word >= 1 && $word <= 9}] }
    0x00100A5C {
      set ptp_state [expr {$word & 0xff}]
      set mode [expr {($word >> 24) & 0xff}]
      return [expr {$ptp_state >= 1 && $ptp_state <= 9 &&
                    ($mode == 2 || $mode == 3)}]
    }
    0x00100A78 {
      set count [expr {$word & 0xff}]
      set best [expr {($word >> 8) & 0xff}]
      set detection [expr {($word >> 16) & 0xff}]
      set config [expr {($word >> 24) & 0xff}]
      return [expr {(($count == 0 && $best == 0xff) ||
                    ($count > 0 && $best < $count)) &&
                    $detection <= 7 && $config <= 7}]
    }
    0x00100A80 { return [expr {(($word >> 24) & 0xff) <= 7}] }
    0x00100A4C {
      set tag [expr {($word >> 28) & 0xf}]
      set state [expr {($word >> 11) & 0xf}]
      set next_state [expr {($word >> 15) & 0xf}]
      set mode [expr {($word >> 21) & 0x7}]
      return [expr {$tag == 0xA && $state <= 8 && $next_state <= 8 &&
                    $mode <= 7}]
    }
    0x00100A9C { return 1 }
  }
  return 1
}

proc wb_read_validated {addr} {
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set value [wb_read $addr]
    if {[register_valid $addr $value]} { return $value }
    after 2
  }
  return "INVALID"
}

proc add_hist {hist_name key} {
  upvar 1 $hist_name hist
  if {[info exists hist($key)]} {
    incr hist($key)
  } else {
    set hist($key) 1
  }
}

proc hist_text {hist_name} {
  upvar 1 $hist_name hist
  set parts {}
  foreach key [lsort -dictionary [array names hist]] {
    lappend parts [format "%s:%d" $key $hist($key)]
  }
  if {[llength $parts] == 0} { return "none" }
  return [join $parts ","]
}

proc series_read {board label addr samples gap_ms} {
  array set hist {}
  set valid 0
  set invalid 0
  set decrease 0
  set expected 0
  set first ""
  set last ""
  set previous -1
  for {set sample 1} {$sample <= $samples} {incr sample} {
    set value [wb_read_validated $addr]
    if {$value eq "INVALID" || $value eq "TIMEOUT"} {
      incr invalid
    } else {
      set word [word32 $value]
      incr valid
      if {$first eq ""} { set first $value }
      set last $value
      add_hist hist $value
      if {$previous >= 0 && $word < $previous} { set decrease 1 }
      set previous $word

      switch -- $label {
        EP_MAC_H { if {$word == 0x02000200} { incr expected } }
        EP_MAC_L { if {$word == 0x22334401 || $word == 0x22334402} { incr expected } }
        MODE {
          set mode [expr {($word >> 24) & 0xff}]
          if {$mode == 2 || $mode == 3} { incr expected }
        }
        PTP { if {$word >= 1 && $word <= 9} { incr expected } }
        FOREIGN_META {
          set count [expr {$word & 0xff}]
          set best [expr {($word >> 8) & 0xff}]
          if {$count == 1 && $best == 0} { incr expected }
        }
        PARSE_META {
          set parent_wr [expr {($word >> 24) & 1}]
          set parent_cal [expr {($word >> 26) & 1}]
          if {$parent_wr == 1 && $parent_cal == 1} { incr expected }
        }
        WR_RX_SIGNAL {
          set message [expr {($word >> 16) & 0xffff}]
          set count [expr {$word & 0xffff}]
          if {$message == 0x1001 && $count > 0} { incr expected }
        }
        WR_TX_SIGNAL {
          set message [expr {($word >> 16) & 0xffff}]
          set count [expr {$word & 0xffff}]
          if {$message == 0x1000 && $count > 0} { incr expected }
        }
        LOCK_ENABLE { if {$word > 0} { incr expected } }
        WDIAGS_TEMP {
          set state [expr {($word >> 11) & 0xf}]
          set next_state [expr {($word >> 15) & 0xf}]
          add_hist state_hist $state
          if {$state == 2} { incr expected }
          if {$state == 0} { incr ::series($board,$label,state_idle) }
          if {$state >= 1 && $state <= 8} { incr ::series($board,$label,state_non_idle) }
          if {$next_state != $state} { incr ::series($board,$label,state_transition) }
        }
      }
      if {$::raw_mode} {
        puts [format "REG_SAMPLE board=%s register=%s sample=%03d value=%s" \
          $board $label $sample $value]
      }
    }
    if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
  }
  set ::series($board,$label,valid) $valid
  set ::series($board,$label,invalid) $invalid
  set ::series($board,$label,decrease) $decrease
  set ::series($board,$label,expected) $expected
  set ::series($board,$label,first) $first
  set ::series($board,$label,last) $last
  set ::series($board,$label,distinct) [llength [array names hist]]
  set ::series($board,$label,hist) [hist_text hist]
  if {$label eq "WDIAGS_TEMP"} {
    set ::series($board,$label,states) [hist_text state_hist]
  }
  puts [format "REG_SERIES board=%s register=%s samples=%d valid=%d invalid=%d distinct=%d decrease=%d expected=%d first=%s last=%s%s%s" \
    $board $label $samples $valid $invalid [llength [array names hist]] $decrease \
    $expected $first $last \
    [expr {$label eq "WDIAGS_TEMP" ? " states=" : " values="}] \
    [expr {$label eq "WDIAGS_TEMP" ? $::series($board,$label,states) : $::series($board,$label,hist)}]]
}

proc read_group {board group samples gap_ms} {
  if {$group eq "temp"} {
    series_read $board WDIAGS_TEMP 0x00100A4C $samples $gap_ms
    return
  }
  if {$group eq "step2"} {
    foreach item {
      {EP_MAC_H 0x00100124}
      {EP_MAC_L 0x00100128}
      {MODE 0x00100A5C}
      {PTP 0x00100A10}
      {PTP_RX 0x00100A54}
      {PTP_TX 0x00100A58}
      {MINIC_TX 0x00100A18}
      {MINIC_RX 0x00100A1C}
      {RXERR 0x00100A60}
    } {
      series_read $board [lindex $item 0] [lindex $item 1] $samples $gap_ms
    }
    return
  }
  if {$group eq "step3"} {
    foreach item {
      {FOREIGN_META 0x00100A78}
      {PARSE_META 0x00100A80}
      {WR_RX_SIGNAL 0x00100A64}
      {WR_TX_SIGNAL 0x00100A68}
      {LOCK_ENABLE 0x00100A9C}
      {WDIAGS_TEMP 0x00100A4C}
    } {
      series_read $board [lindex $item 0] [lindex $item 1] $samples $gap_ms
    }
  }
}

proc get_series {board label field} {
  if {[info exists ::series($board,$label,$field)]} {
    return $::series($board,$label,$field)
  }
  return 0
}

proc step2_result {board} {
  set master [string match "*1.1*" $board]
  set expected_mac [expr {$master ? "01" : "02"}]
  set expected_ptp [expr {$master ? 6 : 9}]
  set invalid 0
  set wrong 0
  foreach label {EP_MAC_H EP_MAC_L MODE PTP PTP_RX PTP_TX MINIC_TX MINIC_RX RXERR} {
    if {[get_series $board $label invalid] > 0} { set invalid 1 }
  }
  if {[get_series $board EP_MAC_H expected] != [get_series $board EP_MAC_H valid]} { set wrong 1 }
  if {[get_series $board EP_MAC_L expected] != [get_series $board EP_MAC_L valid]} { set wrong 1 }
  if {[get_series $board MODE expected] != [get_series $board MODE valid]} { set wrong 1 }
  if {[get_series $board PTP expected] != [get_series $board PTP valid]} { set wrong 1 }
  foreach label {PTP_RX PTP_TX MINIC_TX MINIC_RX RXERR} {
    if {[get_series $board $label decrease]} { set invalid 1 }
  }
  if {$wrong} { return FAIL }
  if {$invalid} { return INVALID }
  return PASS
}

proc step3_result {board} {
  set invalid 0
  foreach label {FOREIGN_META PARSE_META WR_RX_SIGNAL WR_TX_SIGNAL LOCK_ENABLE WDIAGS_TEMP} {
    if {[get_series $board $label invalid] > 0 || [get_series $board $label decrease]} {
      set invalid 1
    }
  }
  set valid [get_series $board WDIAGS_TEMP valid]
  set idle [get_series $board WDIAGS_TEMP state_idle]
  set non_idle [get_series $board WDIAGS_TEMP state_non_idle]
  foreach label {FOREIGN_META PARSE_META WR_RX_SIGNAL WR_TX_SIGNAL LOCK_ENABLE} {
    if {[get_series $board $label expected] == 0} { set invalid 1 }
  }
  if {$invalid} { return INVALID }
  if {$valid > 0 && $idle == $valid} { return FAIL }
  if {$non_idle > 0 && [get_series $board WDIAGS_TEMP expected] > 0} { return PASS }
  return INVALID
}

proc run_board {hardware_name device_name} {
  puts "=== RELIABILITY_BOARD $hardware_name ==="
  start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
  wb_sync_toggle
  if {$::group eq "all"} {
    read_group $hardware_name temp $::samples $::gap_ms
    read_group $hardware_name step2 $::samples $::gap_ms
    read_group $hardware_name step3 $::samples $::gap_ms
  } else {
    read_group $hardware_name $::group $::samples $::gap_ms
  }
  if {$::group eq "step2" || $::group eq "all"} {
    puts [format "STEP2_INDEPENDENT board=%s result=%s" $hardware_name [step2_result $hardware_name]]
  }
  if {$::group eq "step3" || $::group eq "all"} {
    puts [format "STEP3_INDEPENDENT board=%s result=%s" $hardware_name [step3_result $hardware_name]]
  }
  catch { end_insystem_source_probe }
}

puts [format "RELIABILITY_CONFIG samples=%d gap_ms=%d group=%s raw=%d" \
  $samples $gap_ms $group $raw_mode]
foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  if {[catch {run_board $hardware_name [lindex $device_names 0]} message]} {
    puts [format "RELIABILITY_ERROR board=%s message=%s" $hardware_name $message]
    catch { end_insystem_source_probe }
  }
}
puts "RELIABILITY_DONE"
