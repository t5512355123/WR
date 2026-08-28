# Read-only WB probe walk for the VUART shell microtrace mirror.
# This script does not stimulate VUART and does not write any WR control
# register.  It prints the complete mailbox probe word so completion/status
# bits can be checked independently from the 32-bit WB result.

package require ::quartus::insystem_source_probe

array set ::wb_toggle {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc wb_sync_toggle {hardware_name} {
  if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
    set ::wb_toggle($hardware_name) 0
    return
  }
  if {[is_hex $value]} {
    scan $value %x word
    set ::wb_toggle($hardware_name) [expr {($word >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc wb_read_verbose {hardware_name addr} {
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 5
  for {set n 0} {$n < 100} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value TIMEOUT
    }
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} {
        return [format %016X $word]
      }
    }
    after 1
  }
  return TIMEOUT
}

set addresses {
  0x00100BA0
  0x00100BFC
  0x00100BE0
  0x00100BE4
  0x00100BE8
  0x00100BEC
  0x00100BF0
  0x00100BF4
  0x00100BF8
}

puts "VUART_MICROTRACE_WB_DEBUG_CONFIG reads_per_address=3 stimulus=none"
flush stdout

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    foreach addr $addresses {
      for {set attempt 1} {$attempt <= 3} {incr attempt} {
        set raw [wb_read_verbose $hardware_name $addr]
        if {$raw eq "TIMEOUT"} {
          puts [format "VUART_MICROTRACE_WB_DEBUG board=%s addr=%s attempt=%d raw=TIMEOUT" \
            $hardware_name $addr $attempt]
        } else {
          scan $raw %x word
          puts [format "VUART_MICROTRACE_WB_DEBUG board=%s addr=%s attempt=%d raw=%016X done=%d active=%d ack=%d err=%d stall=%d data=%08X" \
            $hardware_name $addr $attempt $word \
            [expr {($word >> 35) & 1}] [expr {($word >> 36) & 1}] \
            [expr {($word >> 34) & 1}] [expr {($word >> 33) & 1}] \
            [expr {($word >> 32) & 1}] [expr {$word & 0xffffffff}]]
        }
        flush stdout
      }
    }
  } error_message]} {
    puts [format "VUART_MICROTRACE_WB_DEBUG_ERROR board=%s message=%s" \
      $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "VUART_MICROTRACE_WB_DEBUG_DONE"
