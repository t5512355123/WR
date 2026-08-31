# Diagnostic-only probe for the SYSCON User-Diag R/W transport.
# It compares a firmware-side `diag w 0 1` with a JTAG-side readback.
# No WR/PHY/SoftPLL/DCO/control register is written.

package require ::quartus::insystem_source_probe

set board_filter ""
set poll_attempts 100
if {[llength $argv] >= 1} { set board_filter [lindex $argv 0] }

array set ::wb_toggle {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return INVALID
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc wb_sync_toggle {hardware_name} {
  set value [probe_read 1]
  if {[is_hex $value]} {
    scan $value %x word
    set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc wb_read {hardware_name addr} {
  global poll_attempts
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} { return INVALID }
  after 5
  for {set n 0} {$n < $poll_attempts} {incr n} {
    set value [probe_read 1]
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
  return INVALID
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
  }]} { return 0 }
  after 5
  for {set n 0} {$n < $poll_attempts} {incr n} {
    set value [probe_read 1]
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} { return 1 }
    }
    after 1
  }
  return 0
}

proc send_vuart {hardware_name command} {
  set index 0
  foreach character [split $command ""] {
    scan $character %c byte
    set result [wb_write $hardware_name 0x00100510 $byte]
    puts [format "DIAG_RW_VUART board=%s index=%02d BYTE=0x%02X WB_RESULT=%d" \
      $hardware_name $index $byte $result]
    incr index
  }
}

puts [format "DIAG_RW_TRANSPORT_CONFIG board_filter=%s command=diag_w_0_1" $board_filter]
foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && $hardware_name ne $board_filter} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle $hardware_name
    set nw_before [wb_read $hardware_name 0x00100424]
    set cr_before [wb_read $hardware_name 0x00100428]
    set dat_before [wb_read $hardware_name 0x0010042C]
    puts [format "DIAG_RW_BEFORE board=%s DIAG_NW=%s DIAG_CR=%s DIAG_DAT=%s" \
      $hardware_name $nw_before $cr_before $dat_before]
    send_vuart $hardware_name "diag w 0 1\n"
    after 500
    set cr_after_fw [wb_write $hardware_name 0x00100428 0]
    set dat_after_fw [wb_read $hardware_name 0x0010042C]
    set cpu_store [probe_read 4]
    set cpu_store_count [probe_read 5]
    puts [format "DIAG_RW_AFTER_FIRMWARE board=%s CR_WRITE_DONE=%d DIAG_DAT=%s CPU_STORE=%s CPU_STORE_COUNT=%s" \
      $hardware_name $cr_after_fw $dat_after_fw $cpu_store $cpu_store_count]
    send_vuart $hardware_name "diag rw 0\n"
    after 200
    set nw_final [wb_read $hardware_name 0x00100424]
    set cr_final [wb_read $hardware_name 0x00100428]
    set dat_final [wb_read $hardware_name 0x0010042C]
    puts [format "DIAG_RW_TRANSPORT_RESULT board=%s DIAG_NW=%s DIAG_CR=%s DIAG_DAT=%s" \
      $hardware_name $nw_final $cr_final $dat_final]
  } error_message]} {
    puts [format "DIAG_RW_TRANSPORT_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}
puts "DIAG_RW_TRANSPORT_DONE"
