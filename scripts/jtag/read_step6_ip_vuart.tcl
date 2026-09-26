# Read the current WRPC IPv4 address through JTAG's existing virtual-UART
# Wishbone path. This sends exactly one firmware command, `ip get`, to the
# Slave board. The command's `get` branch only reads and prints the address;
# this script does not set network configuration, reset hardware, or touch PTP.
#
# The script drains and logs any pre-existing VUART output before sending the
# command, so bytes are preserved in the capture rather than silently lost.
# It then reads the firmware response from the host-side VUART RX FIFO.
#
# Usage:
#   quartus_stp -t read_step6_ip_vuart.tcl ?stable_ms? ?timeout_ms?

package require ::quartus::insystem_source_probe

set stable_ms 1500
set timeout_ms 30000
set poll_ms 100
set poll_attempts 100
if {[llength $argv] >= 1} { set stable_ms [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set timeout_ms [expr {int([lindex $argv 1])}] }
if {$stable_ms <= 0 || $timeout_ms <= 0} {
  error "stable_ms and timeout_ms must be positive"
}

array set ::wb_toggle {}
array set ::gate_debug {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return INVALID }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc word64 {value} {
  if {![is_hex $value]} { return INVALID }
  scan $value %x word
  return $word
}

proc probe_word {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return INVALID
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc wb_sync_toggle {hardware_name} {
  set value [probe_word 1]
  if {![is_hex $value]} {
    error "cannot synchronize Wishbone mailbox toggle"
  }
  scan $value %x word
  set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
}

proc wb_read {hardware_name addr} {
  global poll_attempts
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} { return TIMEOUT }
  after 2
  for {set n 0} {$n < $poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value TIMEOUT
    }
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} {
        return [format %08X [expr {$word & 0xffffffff}]]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc wb_write {hardware_name addr data} {
  global poll_attempts
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (1 << 1) | (0xf << 2) |
                (($addr & 0xffffffff) << 6) |
                (($data & 0xffffffff) << 38)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} { return TIMEOUT }
  after 2
  for {set n 0} {$n < $poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value TIMEOUT
    }
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} {
        return OK
      }
    }
    after 1
  }
  return TIMEOUT
}

proc stable_shell_ready {hardware_name} {
  set entry [word64 [probe_word 26]]
  set corr5 [word64 [probe_word 33]]
  set corr7 [word64 [probe_word 35]]
  set astat [word32 [wb_read $hardware_name 0x00100A14]]
  set command_stage [word32 [wb_read $hardware_name 0x00100BA0]]
  set uart_status [word32 [wb_read $hardware_name 0x00100500]]
  set names [list entry corr5 corr7 astat command_stage uart_status]
  set values [list $entry $corr5 $corr7 $astat $command_stage $uart_status]
  set invalid_fields {}
  foreach name $names value $values {
    if {$value eq "INVALID" || $value eq "TIMEOUT"} { lappend invalid_fields $name }
  }
  if {[llength $invalid_fields] > 0} {
    set ::gate_debug($hardware_name) [format \
      "invalid=%s entry=%s corr5=%s corr7=%s astat=%s command_stage=%s uart_status=%s" \
      [join $invalid_fields ,] $entry $corr5 $corr7 $astat $command_stage $uart_status]
    return 0
  }
  set boot_generation [expr {($entry >> 32) & 0x7f}]
  set astat_generation [expr {($astat >> 25) & 0x7f}]
  set marker_mask [expr {($astat >> 21) & 0x0f}]
  # corr0..corr4 are persistent event-correlation breadcrumbs (DAC load,
  # runtime start, bus/static completion and reset events), not live busy
  # flags. A healthy running Step5 board naturally leaves them nonzero; they
  # must not block this read-only `ip get` query.
  set post_startup_armed [expr {($corr7 >> 33) & 1}]
  set cpu_reset [expr {($corr5 >> 27) & 1}]
  set input_pending [expr {($uart_status >> 1) & 1}]
  set failures {}
  if {$post_startup_armed != 1} { lappend failures POST_STARTUP_NOT_ARMED }
  if {$cpu_reset != 0} { lappend failures CPU_RESET_ASSERTED }
  if {$marker_mask != 0x0f} { lappend failures SHELL_MARKERS_INCOMPLETE }
  if {$boot_generation != $astat_generation} { lappend failures GENERATION_MISMATCH }
  if {$command_stage != 0} { lappend failures COMMAND_STAGE_NOT_IDLE }
  if {$input_pending} { lappend failures VUART_INPUT_PENDING }
  set failure_text [join $failures ,]
  if {$failure_text eq ""} { set failure_text NONE }
  set ::gate_debug($hardware_name) [format \
    "failed=%s armed=%d cpu_reset=%d marker_mask=0x%X boot_generation=%d astat_generation=%d command_stage=%d uart_input_pending=%d entry=%s corr5=%s corr7=%s astat=%s uart_status=%s" \
    $failure_text \
    $post_startup_armed $cpu_reset $marker_mask $boot_generation $astat_generation \
    $command_stage $input_pending $entry $corr5 $corr7 $astat $uart_status]
  return [expr {[llength $failures] == 0}]
}

proc read_uart_available {hardware_name max_bytes} {
  set hex ""
  set text ""
  for {set n 0} {$n < $max_bytes} {incr n} {
    set raw [wb_read $hardware_name 0x00100514]
    if {$raw eq "TIMEOUT"} { return [list TIMEOUT $hex $text] }
    scan $raw %x word
    if {(($word >> 8) & 1) == 0} { return [list OK $hex $text] }
    set byte [expr {$word & 0xff}]
    append hex [format %02X $byte]
    append text [format %c $byte]
  }
  return [list LIMIT $hex $text]
}

proc escaped_text {text} {
  set escaped ""
  foreach character [split $text ""] {
    scan $character %c code
    if {$code == 0x5c} {
      append escaped "\\\\"
    } elseif {$code >= 0x20 && $code <= 0x7e} {
      append escaped $character
    } else {
      append escaped [format "\\x%02X" $code]
    }
  }
  return $escaped
}

proc send_ip_get {hardware_name} {
  set command "ip get\n"
  set index 0
  foreach character [split $command ""] {
    scan $character %c byte
    set ready 0
    for {set n 0} {$n < 100} {incr n} {
      set status [word32 [wb_read $hardware_name 0x00100500]]
      if {$status eq "INVALID" || $status eq "TIMEOUT"} { return TIMEOUT }
      if {(($status >> 1) & 1) == 0} { set ready 1; break }
      after 5
    }
    if {!$ready} { return INPUT_FIFO_BUSY }
    set result [wb_write $hardware_name 0x00100510 $byte]
    puts [format "STEP6_IP_GET_TX board=%s index=%02d byte=0x%02X result=%s" \
      $hardware_name $index $byte $result]
    if {$result ne "OK"} { return WRITE_FAILED }
    incr index
  }
  return OK
}

proc capture_ip_reply {hardware_name timeout_ms} {
  set start_ms [clock milliseconds]
  set last_data_ms -1
  set all_hex ""
  set all_text ""
  while {[clock milliseconds] - $start_ms < $timeout_ms && [string length $all_hex] < 4096} {
    lassign [read_uart_available $hardware_name 256] status chunk_hex chunk_text
    if {$status eq "TIMEOUT" || $status eq "LIMIT"} {
      return [list $status $all_hex $all_text]
    }
    if {$chunk_hex ne ""} {
      append all_hex $chunk_hex
      append all_text $chunk_text
      set last_data_ms [clock milliseconds]
      if {[string first "wrc#" $all_text] >= 0} { break }
    } elseif {$last_data_ms >= 0 && [clock milliseconds] - $last_data_ms >= 500} {
      break
    }
    after 20
  }
  return [list OK $all_hex $all_text]
}

puts [format "STEP6_IP_GET_CONFIG stable_ms=%d timeout_ms=%d board_filter=SLAVE command=ip_get read_only_firmware_branch=1" \
  $stable_ms $timeout_ms]
set found 0
foreach hardware_name [get_hardware_names] {
  if {![string match "*1-11.2*" $hardware_name]} { continue }
  set found 1
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} {
    puts [format "STEP6_IP_GET_SKIP board=%s reason=no_device" $hardware_name]
    continue
  }
  set device_name [lindex $devices 0]
  catch {end_insystem_source_probe}
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name

    set stable_since -1
    set start_ms [clock milliseconds]
    set ready 0
    while {[clock milliseconds] - $start_ms < $timeout_ms} {
      set now [clock milliseconds]
      if {[stable_shell_ready $hardware_name]} {
        if {$stable_since < 0} { set stable_since $now }
        if {$now - $stable_since >= $stable_ms} { set ready 1; break }
      } else {
        set stable_since -1
      }
      after $poll_ms
    }
    if {!$ready} {
      puts [format "STEP6_IP_GET_SKIP board=%s reason=shell_not_stably_ready elapsed_ms=%d gate_details={%s}" \
        $hardware_name [expr {[clock milliseconds] - $start_ms}] \
        $::gate_debug($hardware_name)]
    } else {
      puts [format "STEP6_IP_GET_GATE_PASS board=%s gate_details={%s}" \
        $hardware_name $::gate_debug($hardware_name)]
      set pre_entry [word64 [probe_word 26]]
      set pre_corr5 [word64 [probe_word 33]]
      if {$pre_entry eq "INVALID" || $pre_corr5 eq "INVALID"} {
        error "pre-command reset/generation sample invalid"
      }
      set pre_generation [expr {($pre_entry >> 32) & 0x7f}]
      set pre_cpu_reset [expr {($pre_corr5 >> 27) & 1}]
      puts [format "STEP6_IP_GET_PREFLIGHT board=%s boot_generation=%d cpu_reset=%d" \
        $hardware_name $pre_generation $pre_cpu_reset]

      lassign [read_uart_available $hardware_name 1024] pre_status pre_hex pre_text
      puts [format "STEP6_IP_GET_PREEXISTING board=%s status=%s bytes=%d hex=%s text=%s" \
        $hardware_name $pre_status [expr {[string length $pre_hex] / 2}] $pre_hex \
        [escaped_text $pre_text]]
      if {$pre_status ne "OK"} { error "VUART pre-drain failed: $pre_status" }

      set send_status [send_ip_get $hardware_name]
      if {$send_status ne "OK"} { error "ip get stimulus failed: $send_status" }
      lassign [capture_ip_reply $hardware_name $timeout_ms] reply_status reply_hex reply_text
      set ip_address UNKNOWN
      set ip_state UNKNOWN
      if {[regexp -nocase {IP-address:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*\(([^)]*)\)} \
            $reply_text -> ip_address ip_state]} {
        set reply_verdict PASS
      } elseif {[string first "IP-address: in training" $reply_text] >= 0} {
        set reply_verdict NO_ADDRESS
      } else {
        set reply_verdict INCONCLUSIVE
      }
      set post_entry [word64 [probe_word 26]]
      set post_corr5 [word64 [probe_word 33]]
      if {$post_entry eq "INVALID" || $post_corr5 eq "INVALID"} {
        set reset_changed UNKNOWN
        set post_generation UNKNOWN
        set post_cpu_reset UNKNOWN
      } else {
        set post_generation [expr {($post_entry >> 32) & 0x7f}]
        set post_cpu_reset [expr {($post_corr5 >> 27) & 1}]
        set reset_changed [expr {$post_generation != $pre_generation ||
                                 $post_cpu_reset != $pre_cpu_reset}]
      }
      puts [format "STEP6_IP_GET_RESULT board=%s status=%s verdict=%s ip=%s ip_state=%s reply_bytes=%d reply_hex=%s reply_text=%s boot_generation_before=%s boot_generation_after=%s cpu_reset_before=%s cpu_reset_after=%s reset_changed=%s" \
        $hardware_name $reply_status $reply_verdict $ip_address $ip_state \
        [expr {[string length $reply_hex] / 2}] $reply_hex [escaped_text $reply_text] \
        $pre_generation $post_generation $pre_cpu_reset $post_cpu_reset $reset_changed]
    }
  } error_message]} {
    puts [format "STEP6_IP_GET_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch {end_insystem_source_probe}
}
if {!$found} { puts "STEP6_IP_GET_SKIP reason=slave_cable_not_found" }
puts "STEP6_IP_GET_DONE"
