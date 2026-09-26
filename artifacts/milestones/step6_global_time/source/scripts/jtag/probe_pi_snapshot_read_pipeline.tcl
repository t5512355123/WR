# Read-only probe for the atomic PI snapshot bank.
#
# This intentionally reads the same fixed WDIAGS addresses twice after one
# request/ack cycle.  It separates a firmware snapshot corruption from a
# Wishbone/JTAG read-pipeline problem without touching any control register.

package require ::quartus::insystem_source_probe

set ::wb_toggle 0
set ::poll_attempts 100
set ::snapshot_poll_attempts 1000
set ::board_filter ""
if {[llength $argv] >= 1} { set ::board_filter [lindex $argv 0] }

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]{1,16}$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return INVALID
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc wb_command_hex {toggle write addr data} {
  set data32 [expr {$data & 0xffffffff}]
  set addr32 [expr {$addr & 0xffffffff}]
  set high32 [expr {($data32 >> 26) & 0x3f}]
  set low64 [expr {(($data32 & 0x03ffffff) << 38) |
                   (($addr32 & 0xffffffff) << 6) |
                   (($write & 1) << 1) |
                   (($toggle & 1) | (0xf << 2))}]
  return [format %08X%016X $high32 $low64]
}

proc wb_sync_toggle {} {
  set value [probe_read 1]
  if {[is_hex $value]} {
    scan $value %x word
    set ::wb_toggle [expr {($word >> 35) & 1}]
  } else {
    set ::wb_toggle 0
  }
}

proc wb_read {addr} {
  global poll_attempts
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set toggle $::wb_toggle
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return INVALID
  }
  after 5
  for {set n 0} {$n < $poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value INVALID
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
  return INVALID
}

proc wb_write {addr data} {
  global poll_attempts
  set ::wb_toggle [expr {$::wb_toggle ^ 1}]
  set toggle $::wb_toggle
  set cmd [wb_command_hex $toggle 1 $addr $data]
  if {[catch {
    write_source_data -instance_index 1 -value $cmd -value_in_hex
  }]} {
    return 0
  }
  after 5
  for {set n 0} {$n < $poll_attempts} {incr n} {
    if {[catch {set value [read_probe_data -instance_index 1 -value_in_hex]}]} {
      set value INVALID
    }
    if {[is_hex $value]} {
      scan $value %x word
      set done_toggle [expr {($word >> 35) & 1}]
      set active [expr {($word >> 36) & 1}]
      if {$done_toggle == $toggle && $active == 0} {
        return 1
      }
    }
    after 1
  }
  return 0
}

proc read_twice {label addr} {
  set first [wb_read $addr]
  set second [wb_read $addr]
  puts [format "READ_TWICE %-24s addr=0x%08X first=%s second=%s equal=%d" \
    $label $addr $first $second [expr {[string equal -nocase $first $second]}]]
  return $second
}

proc request_snapshot {seq} {
  global snapshot_poll_attempts
  if {![wb_write 0x0010042C $seq]} { return 0 }
  if {![wb_write 0x00100428 0x80000000]} { return 0 }
  for {set n 0} {$n < $snapshot_poll_attempts} {incr n} {
    set ack [word32 [wb_read 0x00100B28]]
    if {$ack == $seq} { return 1 }
    after 1
  }
  return 0
}

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  if {$::board_filter ne "" && $hardware_name ne $::board_filter} { continue }
  set device_name [lindex $device_names 0]
  catch { end_insystem_source_probe }
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    wb_sync_toggle
    set old_ack [word32 [wb_read 0x00100B28]]
    set seq 0x1001
    if {$old_ack == $seq} { set seq 0x1002 }
    puts [format "PI_PIPELINE_PROBE board=%s old_ack=%s request_seq=%d" \
      $hardware_name $old_ack $seq]
    for {set round 1} {$round <= 3} {incr round} {
      if {![request_snapshot $seq]} {
        puts [format "SNAPSHOT_REQUEST_FAIL board=%s round=%d seq=%d" \
          $hardware_name $round $seq]
        incr seq
        continue
      }
      puts [format "SNAPSHOT_ACKED board=%s round=%d seq=%d" \
        $hardware_name $round $seq]
      read_twice ACK_SEQ 0x00100B28
      read_twice TRACE_EPOCH 0x00100B58
      read_twice I_NEW_LO 0x00100B7C
      read_twice I_NEW_HI 0x00100B80
      read_twice INTEGRATOR_AFTER_LO 0x00100B84
      read_twice INTEGRATOR_AFTER_HI 0x00100B88
      read_twice PROP_TERM_LO 0x00100B8C
      read_twice PROP_TERM_HI 0x00100B90
      read_twice X 0x00100BB0
      read_twice KP 0x00100BB4
      read_twice KI 0x00100BB8
      read_twice BIAS 0x00100BC0
      read_twice FREQ_ERROR 0x00100BCC
      read_twice MAGIC 0x00100BDC
      read_twice ACK_COUNT 0x00100B30
      incr seq
      after 20
    }
    end_insystem_source_probe
  } error_message]} {
    puts [format "PI_PIPELINE_PROBE_ERROR board=%s error=%s" $hardware_name $error_message]
    catch { end_insystem_source_probe }
  }
}
