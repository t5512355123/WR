# Step 2 / Step 3 JTAG mailbox reliability test。
#
# 用法：
#   quartus_stp -t read_step23_register_reliability.tcl ?samples? ?gap_ms? ?group? ?poll_attempts?
#
# group：
#   temp   只重複讀 WDIAGS_TEMP
#   step2  逐一讀 Endpoint / PTP / MiniNIC registers
#   step3  逐一讀 parent / WR signaling / LOCK_ENABLE / failure shadow /
#          WDIAGS_TEMP
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
set poll_attempts 25
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set group [lindex $argv 2] }
if {[llength $argv] >= 4} { set poll_attempts [expr {int([lindex $argv 3])}] }
if {[lsearch -exact $argv --raw] >= 0} { set raw_mode 1 }
if {$samples <= 0 || $gap_ms < 0 || $poll_attempts <= 0} {
  error "samples must be > 0, gap_ms must be >= 0, and poll_attempts must be > 0"
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
  if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
    set ::wb_toggle 0
    return
  }
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
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $command] -value_in_hex
  }]} {
    return "TIMEOUT"
  }
  after 5
  # Bound one mailbox transaction.  The caller still gets INVALID/TIMEOUT
  # after the validation retries instead of leaving quartus_stp alive for
  # several minutes when a JTAG response is missing.
  for {set n 0} {$n < $::poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      after 1
      continue
    }
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
    0x00100A64 - 0x00100A68 {
      set message [expr {($word >> 16) & 0xffff}]
      return [expr {$message == 0 ||
                    ($message >= 0x1000 && $message <= 0x1005)}]
    }
    0x00100A50 {
      set reject_reason [expr {$word & 0xff}]
      return [expr {$reject_reason <= 4}]
    }
    0x00100A6C {
      set fail_role [expr {($word >> 24) & 0xff}]
      set fail_state [expr {($word >> 16) & 0xff}]
      return [expr {$fail_role <= 3 && $fail_state <= 8}]
    }
    0x00100A4C {
      set tag [expr {($word >> 28) & 0xf}]
      set state [expr {($word >> 11) & 0xf}]
      set next_state [expr {($word >> 15) & 0xf}]
      set mode [expr {($word >> 21) & 0x7}]
      return [expr {$tag == 0xA && $state <= 8 && $next_state <= 8 &&
                    $mode <= 7}]
    }
    0x00100A9C { return 1 }
    0x00100AA0 {
      set sequence [expr {$word & 0xff}]
      set alignment [expr {($word >> 8) & 0xff}]
      set mode [expr {($word >> 16) & 0xff}]
      return [expr {$sequence <= 10 &&
                    $alignment <= 10 && $mode <= 3}]
    }
    0x00100AA4 - 0x00100AA8 { return [expr {$word <= 0xff}] }
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

proc wb_read_critical {addr} {
  # Enum/status fields must be source-valid and stable across two accepted
  # mailbox reads.  A changing counter must use wb_read_validated instead;
  # requiring equality there would turn normal activity into a false invalid.
  set previous ""
  for {set attempt 1} {$attempt <= $::max_read_attempts} {incr attempt} {
    set value [wb_read $addr]
    if {[register_valid $addr $value]} {
      if {$previous ne "" && [word32 $previous] == [word32 $value]} {
        return $value
      }
      set previous $value
    } else {
      set previous ""
    }
    after 2
  }
  return "INVALID"
}

proc critical_series_label {label} {
  switch -- $label {
    EP_MAC_H - EP_MAC_L - MODE - PTP - FOREIGN_META - PARSE_META -
    WR_FAILURE_DEBUG - WDIAGS_TEMP - LOCK_ENABLE - RCER - OCER - SPLL_STATE {
      return 1
    }
  }
  return 0
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
  array set state_hist {}
  array set failure_state_hist {}
  set valid 0
  set invalid 0
  set decrease 0
  set expected 0
  set first ""
  set last ""
  set previous -1
  set failure_s_lock 0
  set failure_count_max 0
  set state_idle 0
  set state_non_idle 0
  set state_transition 0
  for {set sample 1} {$sample <= $samples} {incr sample} {
    if {[critical_series_label $label]} {
      set value [wb_read_critical $addr]
    } else {
      set value [wb_read_validated $addr]
    }
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
        WR_SIGNAL_REJECT {
          set reject_count [expr {($word >> 8) & 0x00ffffff}]
          if {$reject_count == 0} { incr expected }
        }
        WR_FAILURE_DEBUG {
          set fail_state [expr {($word >> 16) & 0xff}]
          set fail_count [expr {$word & 0xffff}]
          add_hist failure_state_hist $fail_state
          if {$fail_state == 2 && $fail_count > 0} { incr expected; incr failure_s_lock }
          if {$fail_count > $failure_count_max} { set failure_count_max $fail_count }
        }
        WDIAGS_TEMP {
          set state [expr {($word >> 11) & 0xf}]
          set next_state [expr {($word >> 15) & 0xf}]
          add_hist state_hist $state
          if {$state == 2} { incr expected }
          if {$state == 0} { incr state_idle }
          if {$state >= 1 && $state <= 8} { incr state_non_idle }
          if {$next_state != $state} { incr state_transition }
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
    set ::series($board,$label,state_idle) $state_idle
    set ::series($board,$label,state_non_idle) $state_non_idle
    set ::series($board,$label,state_transition) $state_transition
  }
  if {$label eq "WR_FAILURE_DEBUG"} {
    set ::series($board,$label,failure_states) [hist_text failure_state_hist]
    set ::series($board,$label,failure_s_lock) $failure_s_lock
    set ::series($board,$label,failure_count_max) $failure_count_max
  }
  set suffix " values="
  set series_text $::series($board,$label,hist)
  if {$label eq "WDIAGS_TEMP"} {
    set suffix " states="
    set series_text $::series($board,$label,states)
  }
  if {$label eq "WR_FAILURE_DEBUG"} {
    append suffix [format "failure_states=%s s_lock_evidence=%d fail_count_max=%d values=" \
      $::series($board,$label,failure_states) $failure_s_lock $failure_count_max]
  }
  puts [format "REG_SERIES board=%s register=%s samples=%d valid=%d invalid=%d distinct=%d decrease=%d expected=%d first=%s last=%s%s%s" \
    $board $label $samples $valid $invalid [llength [array names hist]] $decrease \
    $expected $first $last \
    $suffix \
    $series_text]
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
      {WR_SIGNAL_REJECT 0x00100A50}
      {WR_FAILURE_DEBUG 0x00100A6C}
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
  set expected_macl [expr {$master ? 0x22334401 : 0x22334402}]
  set expected_mode [expr {$master ? 2 : 3}]
  set expected_ptp [expr {$master ? 6 : 9}]
  set invalid 0
  set wrong 0
  foreach label {EP_MAC_H EP_MAC_L MODE PTP PTP_RX PTP_TX MINIC_TX MINIC_RX RXERR} {
    if {[get_series $board $label invalid] > 0} { set invalid 1 }
  }
  if {[word32 [get_series $board EP_MAC_H first]] != 0x02000200 ||
      [word32 [get_series $board EP_MAC_H last]] != 0x02000200} { set wrong 1 }
  if {[word32 [get_series $board EP_MAC_L first]] != $expected_macl ||
      [word32 [get_series $board EP_MAC_L last]] != $expected_macl} { set wrong 1 }
  set mode_first [word32 [get_series $board MODE first]]
  set mode_last [word32 [get_series $board MODE last]]
  if {$mode_first < 0 || $mode_last < 0 ||
      (($mode_first >> 24) & 0xff) != $expected_mode ||
      (($mode_last >> 24) & 0xff) != $expected_mode} { set wrong 1 }
  if {[word32 [get_series $board PTP last]] != $expected_ptp} { set wrong 1 }
  foreach label {PTP_RX PTP_TX MINIC_TX MINIC_RX RXERR} {
    if {[get_series $board $label decrease]} {
      puts [format "STEP2_COUNTER_RETEST board=%s register=%s result=DECREASED_OR_RESET" \
        $board $label]
      set invalid 1
    }
  }
  # PTP_TX may be quiet in a finite observation window.  Step 2 still needs
  # sustained inbound PTP plus MiniNIC TX/RX activity.
  foreach label {PTP_RX MINIC_TX MINIC_RX} {
    set first [word32 [get_series $board $label first]]
    set last [word32 [get_series $board $label last]]
    if {$first < 0 || $last <= $first} { set invalid 1 }
  }
  set rxerr_first [word32 [get_series $board RXERR first]]
  set rxerr_last [word32 [get_series $board RXERR last]]
  if {$rxerr_first < 0 || $rxerr_last < 0} {
    set invalid 1
  } elseif {$rxerr_last > $rxerr_first} {
    set wrong 1
  }
  if {$invalid} { return INVALID }
  if {$wrong} { return FAIL }
  return PASS
}

proc step3_result {board} {
  if {[string match "*1.1*" $board]} { return NA }
  set invalid 0
  set wrong 0
  foreach label {FOREIGN_META PARSE_META WR_RX_SIGNAL WR_TX_SIGNAL LOCK_ENABLE \
                 WR_SIGNAL_REJECT WR_FAILURE_DEBUG WDIAGS_TEMP} {
    if {[get_series $board $label invalid] > 0} {
      set invalid 1
    }
  }
  # A counter reset/decrease is a retest condition, not a hardware failure.
  # The failure shadow also contains role/state fields, so its packed word can
  # decrease when those fields change even if the failure evidence is valid.
  foreach label {FOREIGN_META PARSE_META WR_RX_SIGNAL WR_TX_SIGNAL LOCK_ENABLE WDIAGS_TEMP} {
    if {[get_series $board $label decrease]} {
      puts [format "STEP3_COUNTER_RETEST board=%s register=%s result=DECREASED_OR_RESET" \
        $board $label]
    }
  }
  set valid [get_series $board WDIAGS_TEMP valid]
  set idle [get_series $board WDIAGS_TEMP state_idle]
  set non_idle [get_series $board WDIAGS_TEMP state_non_idle]
  foreach label {FOREIGN_META PARSE_META WR_RX_SIGNAL WR_TX_SIGNAL LOCK_ENABLE} {
    if {[get_series $board $label expected] == 0} { set wrong 1 }
  }
  if {$invalid} { return INVALID }
  if {$wrong} { return FAIL }
  set failure_s_lock [get_series $board WR_FAILURE_DEBUG failure_s_lock]
  if {$valid > 0 && $idle == $valid} {
    if {$failure_s_lock > 0 && [get_series $board LOCK_ENABLE expected] > 0} {
      # Step 3 ends when the WR signaling handshake reaches WRS_S_LOCK and
      # locking_enable() is entered.  A later wr_handshake_fail() can reset
      # the live state to WRS_IDLE; keep that post-Step-3 timeout separate
      # from the Step 3 milestone result.
      puts [format "POST_STEP3_LOCK_STAGE board=%s result=TIMEOUT last_fail_state=WRS_S_LOCK current_state=WRS_IDLE failure_samples=%d failure_count_max=%d" \
        $board $failure_s_lock [get_series $board WR_FAILURE_DEBUG failure_count_max]]
      return PASS
    }
    puts [format "STEP3_STATE_EVIDENCE board=%s result=READ_INCONSISTENT current_state=WRS_IDLE signaling_and_lock_enable=ESTABLISHED" $board]
    return INVALID
  }
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
