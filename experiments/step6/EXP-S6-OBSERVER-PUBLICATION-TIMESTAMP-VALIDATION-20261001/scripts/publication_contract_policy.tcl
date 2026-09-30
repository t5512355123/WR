namespace eval ::s6pub {
  variable group_fields [dict create \
    EVENT {A8C RX STATE TX} \
    PHASE {CKO SETP UCNT}]
}

proc ::s6pub::u32 {value} {
  if {[string is entier -strict $value]} {
    if {$value < 0 || $value > 0xffffffff} { return -1 }
    return $value
  }
  if {![regexp -nocase {^(0x)?[0-9a-f]{1,8}$} $value]} { return -1 }
  regsub -nocase {^0x} $value {} digits
  scan $digits %x parsed
  return [expr {$parsed & 0xffffffff}]
}

proc ::s6pub::time_value {value} {
  if {![regexp {^(0|[1-9][0-9]*)$} $value]} { return -1 }
  if {$value > 0x7fffffffffffffff} { return -1 }
  return $value
}

proc ::s6pub::normalize_timed_read {raw_field start end} {
  set fields [dict create WR_STATE_RAW STATE WR_RX_RAW RX WR_TX_RAW TX]
  if {![dict exists $fields $raw_field]} { error "unrecognized timed-read field: $raw_field" }
  set field [dict get $fields $raw_field]
  return [dict create ${field}_READ_BEGIN_MS $start ${field}_READ_END_MS $end]
}

proc ::s6pub::strict_offset_in_band {cko_ps} {
  if {![string is entier -strict $cko_ps]} { return 0 }
  return [expr {$cko_ps > -60 && $cko_ps < 60}]
}

proc ::s6pub::validate_payload {record frame_start frame_end previous_end} {
  if {[catch {dict size $record}]} { return [list 0 PAYLOAD_RECORD_MISSING -1 -1] }
  if {![dict exists $record valid] || [dict get $record valid] ne "1" ||
      ![dict exists $record transport_valid] || [dict get $record transport_valid] ne "1"} {
    return [list 0 PAYLOAD_NOT_VALID -1 -1]
  }
  if {![dict exists $record raw] || [u32 [dict get $record raw]] < 0} {
    return [list 0 PAYLOAD_RAW_INVALID -1 -1]
  }
  if {![dict exists $record read_start_ms] || ![dict exists $record read_end_ms]} {
    return [list 0 PAYLOAD_TIMESTAMP_INVALID -1 -1]
  }
  set start [time_value [dict get $record read_start_ms]]
  set end [time_value [dict get $record read_end_ms]]
  if {$start < 0 || $end < 0 || $start > $end} {
    return [list 0 PAYLOAD_TIMESTAMP_INVALID $start $end]
  }
  if {$start < $frame_start || $end > $frame_end || $start < $previous_end} {
    return [list 0 PAYLOAD_TIMESTAMP_OUTSIDE_OR_NONMONOTONIC $start $end]
  }
  return [list 1 NONE $start $end]
}

proc ::s6pub::validate_frame {frame} {
  if {[catch {dict size $frame}]} { return FRAME_RECORD_MISSING }
  if {![dict exists $frame kind]} { return FRAME_KIND_INVALID }
  set kind [dict get $frame kind]
  variable group_fields
  if {![dict exists $group_fields $kind]} { return FRAME_KIND_INVALID }

  foreach key {frame_start_ms frame_end_ms} {
    if {![dict exists $frame $key]} { return FRAME_TIMESTAMP_INVALID }
  }
  set frame_start [time_value [dict get $frame frame_start_ms]]
  set frame_end [time_value [dict get $frame frame_end_ms]]
  if {$frame_start < 0 || $frame_end < 0 || $frame_start > $frame_end} {
    return FRAME_TIMESTAMP_INVALID
  }

  foreach key {data_valid_before data_valid_after} {
    if {![dict exists $frame $key] || [dict get $frame $key] ne "1"} {
      return DATA_VALID_GUARD_REJECTED
    }
  }
  foreach key {snapshot_before snapshot_after} {
    if {![dict exists $frame $key] || [dict get $frame $key] ne "0"} {
      return DATA_SNAPSHOT_GUARD_REJECTED
    }
  }

  foreach key {generation_before generation_after generation_inverse_before generation_inverse_after} {
    if {![dict exists $frame $key] || [u32 [dict get $frame $key]] < 0} {
      return PUBLICATION_SEQUENCE_RAW_INVALID
    }
  }
  set before [u32 [dict get $frame generation_before]]
  set after [u32 [dict get $frame generation_after]]
  set inverse_before [u32 [dict get $frame generation_inverse_before]]
  set inverse_after [u32 [dict get $frame generation_inverse_after]]
  if {(($before ^ $inverse_before) & 0xffffffff) != 0xffffffff ||
      (($after ^ $inverse_after) & 0xffffffff) != 0xffffffff} {
    return PUBLICATION_SEQUENCE_INVERSE_MISMATCH
  }
  if {$before != $after || $inverse_before != $inverse_after} {
    return PUBLICATION_SEQUENCE_CHANGED
  }
  if {$before & 1} { return PUBLICATION_SEQUENCE_UNCOMMITTED }

  foreach key {owner_before owner_after overlay_active_before overlay_active_after} {
    if {![dict exists $frame $key]} { return PUBLICATION_OWNER_OR_OVERLAY_REJECTED }
  }
  if {[dict get $frame owner_before] ne "DIAG_PUBLISHER" ||
      [dict get $frame owner_after] ne "DIAG_PUBLISHER" ||
      [dict get $frame overlay_active_before] ne "0" ||
      [dict get $frame overlay_active_after] ne "0"} {
    return PUBLICATION_OWNER_OR_OVERLAY_REJECTED
  }

  if {![dict exists $frame payload] || [catch {dict size [dict get $frame payload]}]} {
    return PAYLOAD_GROUP_MEMBERSHIP_INVALID
  }
  set payload [dict get $frame payload]
  set expected [lsort [dict get $group_fields $kind]]
  if {[lsort [dict keys $payload]] ne $expected} { return PAYLOAD_GROUP_MEMBERSHIP_INVALID }

  set ordered {}
  foreach field [dict keys $payload] {
    set record [dict get $payload $field]
    if {[catch {dict get $record read_start_ms} start]} {
      set sort_start 0x7fffffffffffffff
    } else {
      set sort_start [time_value $start]
      if {$sort_start < 0} { set sort_start 0x7fffffffffffffff }
    }
    lappend ordered [list $sort_start $field]
  }
  set ordered [lsort -integer -index 0 $ordered]
  set previous_end $frame_start
  foreach entry $ordered {
    set field [lindex $entry 1]
    lassign [validate_payload [dict get $payload $field] $frame_start $frame_end $previous_end] \
      ok reason start end
    if {!$ok} { return $reason }
    set previous_end $end
  }
  return NONE
}
