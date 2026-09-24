# Firmware-only VLAN/pfilter progress diagnostic (read-only).
#
# Usage:
#   quartus_stp -t read_vlan_pfilter_progress_diag.tcl ?samples? ?gap_ms? ?filter?
#
# The existing WDIAGS mapping counter/inverse words retain their low 16 bits.
# Their high 16 bits expose the following progress bitmap/index:
#   bit  0  VLAN_CMD_ENTER
#   bit  1  PFILTER_ENTER
#   bit  2  PFILTER_BEFORE_DISABLE
#   bits 3..8 PFILTER_RULE_INDEX (6-bit current/last rule index)
#   bit  9  PFILTER_AFTER_RULE_WRITE
#   bit 10  PFILTER_BEFORE_ENABLE
#   bit 11  PFILTER_RETURN
#   bit 12  VLAN_CMD_RETURN
#
# This script only reads the existing source probe and Wishbone diagnostics
# area. It does not write a Wishbone register, request a snapshot, or alter
# packet-filter, WR, or SoftPLL control.

package require ::quartus::insystem_source_probe

set samples 5
set gap_ms 100
set board_filter ""
if {[llength $argv] >= 1} { set samples [expr {int([lindex $argv 0])}] }
if {[llength $argv] >= 2} { set gap_ms [expr {int([lindex $argv 1])}] }
if {[llength $argv] >= 3} { set board_filter [lindex $argv 2] }
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

array set ::wb_toggle {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]+$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  scan $value %x word
  return [expr {$word & 0xffffffff}]
}

proc display32 {value} {
  set word [word32 $value]
  if {$word < 0} { return $value }
  return [format %08X $word]
}

proc probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc wb_read {hardware_name addr} {
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
        return [format %08X [expr {$word & 0xffffffff}]]
      }
    }
    after 1
  }
  return TIMEOUT
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

proc selected_board {hardware_name} {
  if {$::board_filter eq ""} { return 1 }
  return [expr {[string first $::board_filter $hardware_name] >= 0}]
}

proc read_progress_sample {hardware_name sample start_ms} {
  set counter_raw [wb_read $hardware_name 0x00100B34]
  set inverse_raw [wb_read $hardware_name 0x00100B38]
  set counter [word32 $counter_raw]
  set inverse [word32 $inverse_raw]
  set elapsed [expr {[clock milliseconds] - $start_ms}]
  if {$counter < 0 || $inverse < 0} {
    puts [format "VLAN_PFILTER_DIAG_SAMPLE board=%s sample=%03d elapsed_ms=%d COUNTER=%s INVERSE=%s PROGRESS=INVALID" \
      $hardware_name $sample $elapsed [display32 $counter_raw] [display32 $inverse_raw]]
  } else {
    set progress [expr {($counter >> 16) & 0xffff}]
    set inverse_progress [expr {($inverse >> 16) & 0xffff}]
    set counter_low [expr {$counter & 0xffff}]
    set inverse_low [expr {$inverse & 0xffff}]
    set mapping_valid [expr {$inverse_low == ((~$counter_low) & 0xffff) &&
                             $inverse_progress == ((~$progress) & 0xffff)}]
    set rule_index [expr {($progress >> 3) & 0x3f}]
    puts [format "VLAN_PFILTER_DIAG_SAMPLE board=%s sample=%03d elapsed_ms=%d COUNTER=%s INVERSE=%s MAPPING_LOW16_VALID=%d VLAN_CMD_ENTER=%d PFILTER_ENTER=%d PFILTER_BEFORE_DISABLE=%d PFILTER_RULE_INDEX=%d PFILTER_AFTER_RULE_WRITE=%d PFILTER_BEFORE_ENABLE=%d PFILTER_RETURN=%d VLAN_CMD_RETURN=%d" \
      $hardware_name $sample $elapsed [display32 $counter_raw] [display32 $inverse_raw] \
      $mapping_valid [expr {$progress & 1}] [expr {($progress >> 1) & 1}] \
      [expr {($progress >> 2) & 1}] $rule_index \
      [expr {($progress >> 9) & 1}] [expr {($progress >> 10) & 1}] \
      [expr {($progress >> 11) & 1}] [expr {($progress >> 12) & 1}]]
  }
  flush stdout
}

puts [format "VLAN_PFILTER_DIAG_CONFIG samples=%d gap_ms=%d filter=%s" \
  $samples $gap_ms $board_filter]

foreach hardware_name [get_hardware_names] {
  if {![selected_board $hardware_name]} { continue }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} { continue }
  set device_name [lindex $device_names 0]
  puts [format "=== VLAN_PFILTER_DIAG_BOARD %s ===" $hardware_name]
  flush stdout
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name
    set start_ms [clock milliseconds]
    for {set sample 1} {$sample <= $samples} {incr sample} {
      read_progress_sample $hardware_name $sample $start_ms
      if {$sample < $samples && $gap_ms > 0} { after $gap_ms }
    }
  } error_message]} {
    puts [format "VLAN_PFILTER_DIAG_ERROR board=%s message=%s" $hardware_name $error_message]
  }
  catch { end_insystem_source_probe }
}

puts "VLAN_PFILTER_DIAG_DONE"
