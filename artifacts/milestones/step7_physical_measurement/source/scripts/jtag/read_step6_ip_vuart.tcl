# Read the current WRPC IPv4 address through JTAG's existing virtual-UART
# Wishbone path. By default this sends only the firmware command `ip get` to
# the Slave board. An optional `calibration` mode sends the fixed read-only
# commands `delays` and `sfp show`; `sfp_params` reads cached SFP state, while
# `sfp_live` also performs a read-only local-buffer EEPROM header probe.
# It never runs `sfp match`, which can update
# live calibration state. No mode changes network configuration, resets
# hardware, or writes PTP control.
#
# The script drains and logs any pre-existing VUART output before sending the
# command, so bytes are preserved in the capture rather than silently lost.
# It then reads the firmware response from the host-side VUART RX FIFO.
#
# Usage:
#   quartus_stp -t read_step6_ip_vuart.tcl ?stable_ms? ?timeout_ms? ?mode? ?ram_addresses?
# ram_read accepts only aligned data-RAM addresses below 0x30000. Resolve them
# from the exact programmed firmware ELF, never a different build. It sends
# devmem with one address argument only, so the firmware executes its read path.
# ram_read additionally requires CONFIG_CMD_LL; a missing command is not data.
# pll_read uses only the existing statistics and phase-shift readback commands.
# fixed_read queries the current diagnostic latch and passive phase counters.
# pll_read_both uses the same fixed queries on the two named DE5 boards.
# pll_recover_master is only for the two owned partial characters left by the
# failed pll stat send: two shell backspaces, then the same read-only query.

package require ::quartus::insystem_source_probe

set stable_ms 1500
set timeout_ms 30000
set query_mode ip
set poll_ms 100
set poll_attempts 100
if {[llength $argv] >= 1} { set stable_ms [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set timeout_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set query_mode [lindex $argv 2] }
if {$stable_ms <= 0 || $timeout_ms <= 0} {
  error "stable_ms and timeout_ms must be positive"
}
switch -- $query_mode {
  ip { set read_only_queries [list "ip get"] }
  calibration { set read_only_queries [list "delays" "sfp show"] }
    sfp_params { set read_only_queries [list "sfp params"] }
    sfp_live { set read_only_queries [list "sfp params live"] }
    pll_read { set read_only_queries [list "pll stat" "pll gps 0"] }
    fixed_read { set read_only_queries [list "pll fixed"] }
    pll_read_both { set read_only_queries [list "pll stat" "pll gps 0"] }
    pll_recover_master { set read_only_queries [list "\x7f\x7fpll stat" "pll gps 0"] }
    ram_read {
      if {[llength $argv] != 4} { error "ram_read requires a Tcl list of RAM addresses" }
      set read_only_queries {}
      foreach address [lindex $argv 3] {
        if {![regexp {^[0-9a-fA-F]{1,8}$} $address]} { error "invalid RAM address" }
        scan $address %x numeric_address
        if {$numeric_address < 0 || $numeric_address >= 0x30000 || ($numeric_address & 3)} {
          error "RAM address must be aligned and below 0x30000"
        }
        lappend read_only_queries [format "devmem %08x" $numeric_address]
      }
      if {[llength $read_only_queries] == 0 || [llength $read_only_queries] > 16} {
        error "ram_read requires 1 to 16 addresses"
      }
    }
    default { error "query_mode must be ip, calibration, sfp_params, sfp_live, pll_read, pll_read_both, pll_recover_master, fixed_read, or ram_read" }
}

array set ::wb_toggle {}
array set ::gate_debug {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return INVALID }
  set word [expr 0x$value]
  return [expr {$word & 0xffffffff}]
}

proc word64 {value} {
  if {![is_hex $value]} { return INVALID }
  return [expr 0x$value]
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
  set word [word64 $value]
  set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
}

proc encode_wb_command {command} {
  # Avoid platform-dependent %X truncation of the 96-bit mailbox payload.
  return [format %08X%08X%08X [expr {($command >> 64) & 0xffffffff}] \
    [expr {($command >> 32) & 0xffffffff}] [expr {$command & 0xffffffff}]]
}

proc wb_transfer {hardware_name addr data write_enable} {
  global poll_attempts
  set prior_toggle $::wb_toggle($hardware_name)
  set payload [expr {($write_enable << 1) | (0xf << 2) |
                    (($addr & 0xffffffff) << 6) | (($data & 0xffffffff) << 38)}]
  # Settle the complete bundled payload before changing only the commit bit.
  set preload_cmd [expr {$payload | $prior_toggle}]
  if {[catch {
    write_source_data -instance_index 1 -value [encode_wb_command $preload_cmd] -value_in_hex
  }]} { return TIMEOUT }
  after 2
  set preload_probe [word64 [probe_word 1]]
  if {$preload_probe eq "INVALID" || (($preload_probe >> 35) & 1) != $prior_toggle ||
      (($preload_probe >> 36) & 1)} { return TIMEOUT }
  set toggle [expr {$prior_toggle ^ 1}]
  set ::wb_toggle($hardware_name) $toggle
  set cmd [expr {$payload | $toggle}]
  if {[catch {
    write_source_data -instance_index 1 -value [encode_wb_command $cmd] -value_in_hex
  }]} { return TIMEOUT }
  after 5
  for {set n 0} {$n < $poll_attempts} {incr n} {
    set p1 [word64 [probe_word 1]]
    after 1
    set p2 [word64 [probe_word 1]]
    after 1
    set p3 [word64 [probe_word 1]]
    if {$p1 ne "INVALID" && $p2 ne "INVALID" && $p3 ne "INVALID" &&
        $p1 == $p2 && $p2 == $p3 && (($p3 >> 35) & 1) == $toggle &&
        (($p3 >> 36) & 1) == 0 && (($p3 >> 16) & 0xffff) != 0xA5A5} {
      if {$write_enable} {
        return OK
      }
      return [format %08X [expr {$p3 & 0xffffffff}]]
    }
    after 1
  }
  return TIMEOUT
}

proc wb_read {hardware_name addr} {
  return [wb_transfer $hardware_name $addr 0 0]
}

proc wb_write {hardware_name addr data} {
  return [wb_transfer $hardware_name $addr $data 1]
}

proc stable_shell_ready {hardware_name} {
  set entry [word64 [probe_word 26]]
  set corr5 [word64 [probe_word 33]]
  set corr7 [word64 [probe_word 35]]
  set astat [word32 [wb_read $hardware_name 0x00100A14]]
  set main_bank_magic [word32 [wb_read $hardware_name 0x00100B5C]]
  set command_stage [word32 [wb_read $hardware_name 0x00100BA0]]
  set uart_status [word32 [wb_read $hardware_name 0x00100500]]
  set names [list entry corr5 corr7 astat main_bank_magic command_stage uart_status]
  set values [list $entry $corr5 $corr7 $astat $main_bank_magic $command_stage $uart_status]
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
  # F4L (magic at base+4, WDIAGS 0x158+4) owns 0x1a0 after Main startup.
  # In that bank, 0x1a0 is frame payload, NOT a persistent shell stage. Do not
  # invent an idle-stage value. Fixed read-only queries still require all live
  # shell/generation/reset markers and a quiet input FIFO for stable_ms.
  set command_stage_observable [expr {$main_bank_magic != 0x46344c31}]
  if {$command_stage_observable && $command_stage != 0} {
    lappend failures COMMAND_STAGE_NOT_IDLE
  }
  if {$input_pending} { lappend failures VUART_INPUT_PENDING }
  set failure_text [join $failures ,]
  if {$failure_text eq ""} { set failure_text NONE }
  set ::gate_debug($hardware_name) [format \
    "failed=%s armed=%d cpu_reset=%d marker_mask=0x%X boot_generation=%d astat_generation=%d command_stage=%d command_stage_observable=%d main_bank_magic=%08X uart_input_pending=%d entry=%s corr5=%s corr7=%s astat=%s uart_status=%s" \
    $failure_text \
    $post_startup_armed $cpu_reset $marker_mask $boot_generation $astat_generation \
    $command_stage $command_stage_observable $main_bank_magic $input_pending $entry $corr5 $corr7 $astat $uart_status]
  return [expr {[llength $failures] == 0}]
}

proc read_uart_available {hardware_name max_bytes} {
  set hex ""
  set text ""
  for {set n 0} {$n < $max_bytes} {incr n} {
    set raw [wb_read $hardware_name 0x00100514]
    if {$raw eq "TIMEOUT"} { return [list TIMEOUT $hex $text] }
    set word [word32 $raw]
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

proc send_vuart_command {hardware_name command_name} {
  global timeout_ms
  set command "${command_name}\n"
  set index 0
  foreach character [split $command ""] {
    scan $character %c byte
    set ready 0
    set wait_start [clock milliseconds]
    while {[clock milliseconds] - $wait_start < $timeout_ms} {
      set status [word32 [wb_read $hardware_name 0x00100500]]
      if {$status eq "INVALID" || $status eq "TIMEOUT"} { return TIMEOUT }
      if {(($status >> 1) & 1) == 0} { set ready 1; break }
      after 5
    }
    if {!$ready} { return INPUT_FIFO_BUSY }
    set result [wb_write $hardware_name 0x00100510 $byte]
    puts [format "STEP6_VUART_TX board=%s command=%s index=%02d byte=0x%02X result=%s" \
      $hardware_name $command_name $index $byte $result]
    if {$result ne "OK"} { return WRITE_FAILED }
    incr index
  }
  return OK
}

proc drain_preexisting_uart {hardware_name timeout_ms} {
  set start_ms [clock milliseconds]
  set all_hex ""
  set all_text ""
  while {[clock milliseconds] - $start_ms < $timeout_ms && [string length $all_hex] < 16384} {
    lassign [read_uart_available $hardware_name 256] status chunk_hex chunk_text
    append all_hex $chunk_hex
    append all_text $chunk_text
    if {$status eq "OK" || $status eq "TIMEOUT"} { return [list $status $all_hex $all_text] }
  }
  return [list LIMIT $all_hex $all_text]
}

proc capture_vuart_reply {hardware_name timeout_ms} {
  set start_ms [clock milliseconds]
  set last_data_ms -1
  set all_hex ""
  set all_text ""
  while {[clock milliseconds] - $start_ms < $timeout_ms && [string length $all_hex] < 4096} {
    lassign [read_uart_available $hardware_name 256] status chunk_hex chunk_text
    if {$chunk_hex ne ""} {
      append all_hex $chunk_hex
      append all_text $chunk_text
      set last_data_ms [clock milliseconds]
      if {[string first "wrc#" $all_text] >= 0} { break }
    }
    if {$status eq "TIMEOUT"} {
      return [list TIMEOUT $all_hex $all_text]
    }
    if {$status eq "LIMIT"} {
      if {$chunk_hex eq ""} { return [list LIMIT $all_hex $all_text] }
      after 1
      continue
    }
    if {$chunk_hex eq "" && $last_data_ms >= 0 &&
        [clock milliseconds] - $last_data_ms >= 500} {
      break
    }
    after 20
  }
  if {[string length $all_hex] >= 4096} {
    return [list LIMIT $all_hex $all_text]
  }
  if {[clock milliseconds] - $start_ms >= $timeout_ms} {
    return [list TIMEOUT $all_hex $all_text]
  }
  return [list OK $all_hex $all_text]
}

# Allow other passive observers to reuse the tested bundled-mailbox transport.
# This returns before enumeration, UART reads, or command injection.
if {[info exists ::step6_vuart_library_only] && $::step6_vuart_library_only} { return }

set board_scope SLAVE
if {$query_mode eq "pll_read_both"} { set board_scope MASTER_AND_SLAVE }
if {$query_mode eq "pll_recover_master"} { set board_scope MASTER_OWNED_PARTIAL_RECOVERY }
puts [format "STEP6_VUART_CONFIG stable_ms=%d timeout_ms=%d board_filter=%s query_mode=%s read_only_firmware_commands=1" \
  $stable_ms $timeout_ms $board_scope $query_mode]
set found 0
foreach hardware_name [get_hardware_names] {
  if {$query_mode eq "pll_recover_master"} {
    if {![string match "*1-11.1*" $hardware_name]} { continue }
  } else {
  if {![string match "*1-11.2*" $hardware_name] &&
      !($query_mode eq "pll_read_both" && [string match "*1-11.1*" $hardware_name])} { continue }
  }
  set found 1
  set devices [get_device_names -hardware_name $hardware_name]
  if {[llength $devices] == 0} {
    puts [format "STEP6_VUART_SKIP board=%s reason=no_device" $hardware_name]
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
      puts [format "STEP6_VUART_SKIP board=%s reason=shell_not_stably_ready elapsed_ms=%d gate_details={%s}" \
        $hardware_name [expr {[clock milliseconds] - $start_ms}] \
        $::gate_debug($hardware_name)]
    } else {
      puts [format "STEP6_VUART_GATE_PASS board=%s gate_details={%s}" \
        $hardware_name $::gate_debug($hardware_name)]
      set pre_entry [word64 [probe_word 26]]
      set pre_corr5 [word64 [probe_word 33]]
      if {$pre_entry eq "INVALID" || $pre_corr5 eq "INVALID"} {
        error "pre-command reset/generation sample invalid"
      }
      set pre_generation [expr {($pre_entry >> 32) & 0x7f}]
      set pre_cpu_reset [expr {($pre_corr5 >> 27) & 1}]
      puts [format "STEP6_VUART_PREFLIGHT board=%s boot_generation=%d cpu_reset=%d" \
        $hardware_name $pre_generation $pre_cpu_reset]

      lassign [drain_preexisting_uart $hardware_name $timeout_ms] pre_status pre_hex pre_text
      puts [format "STEP6_VUART_PREEXISTING board=%s status=%s bytes=%d hex=%s text=%s" \
        $hardware_name $pre_status [expr {[string length $pre_hex] / 2}] $pre_hex \
        [escaped_text $pre_text]]
      if {$pre_status ne "OK"} { error "VUART pre-drain failed: $pre_status" }

      foreach query $read_only_queries {
        set send_status [send_vuart_command $hardware_name $query]
        if {$send_status ne "OK"} { error "$query stimulus failed: $send_status" }
        lassign [capture_vuart_reply $hardware_name $timeout_ms] reply_status reply_hex reply_text
        if {$query eq "ip get"} {
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
          puts [format "STEP6_IP_GET_RESULT board=%s status=%s verdict=%s ip=%s ip_state=%s reply_bytes=%d reply_hex=%s reply_text=%s" \
            $hardware_name $reply_status $reply_verdict $ip_address $ip_state \
            [expr {[string length $reply_hex] / 2}] $reply_hex [escaped_text $reply_text]]
        } else {
          puts [format "STEP6_VUART_QUERY_RESULT board=%s command=%s status=%s reply_bytes=%d reply_hex=%s reply_text=%s" \
            $hardware_name $query $reply_status [expr {[string length $reply_hex] / 2}] \
            $reply_hex [escaped_text $reply_text]]
        }
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
      puts [format "STEP6_VUART_POSTFLIGHT board=%s boot_generation_before=%s boot_generation_after=%s cpu_reset_before=%s cpu_reset_after=%s reset_changed=%s" \
        $hardware_name \
        $pre_generation $post_generation $pre_cpu_reset $post_cpu_reset $reset_changed]
    }
  } error_message]} {
    puts [format "STEP6_VUART_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch {end_insystem_source_probe}
}
if {!$found} { puts "STEP6_VUART_SKIP reason=slave_cable_not_found" }
puts "STEP6_VUART_DONE"
