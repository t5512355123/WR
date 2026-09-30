namespace eval ::s6r {
  variable max_ucnt_delta 128
  variable max_window_gap_ms 1000
  variable stable_window_ms 300000
  variable admission_timeout_ms 600000
  variable total_timeout_ms 900000

  proc raw_u32 {value} {
    if {![regexp -nocase {^(0x)?[0-9a-f]{1,8}$} $value]} { return -1 }
    regsub -nocase {^0x} $value {} digits
    scan $digits %x parsed
    return [expr {$parsed & 0xffffffff}]
  }

  proc decode_failure_words {a6c_raw a8c_raw} {
    set a6c [raw_u32 $a6c_raw]
    set a8c [raw_u32 $a8c_raw]
    if {$a6c < 0 || $a8c < 0} {
      return [dict create VALID 0 FAILURE_COUNT_U8 -1 FAILED_ROLE -1 FAILED_STATE -1 \
        DISABLE_VALID -1 DISABLE_CAUSE NA DISABLE_PTP_STATE NA A8C_RESULT -1 \
        A8C_CHECK_LOCK -1 FAILURE_REASON -1 FAILURE_TICS_LOW16 -1]
    }
    set disable_valid [expr {($a6c >> 11) & 1}]
    set disable_cause NA
    set disable_ptp_state NA
    if {$disable_valid} {
      set disable_cause [expr {($a6c >> 8) & 0x7}]
      set disable_ptp_state [expr {($a6c >> 12) & 0xf}]
    }
    return [dict create VALID 1 \
      FAILURE_COUNT_U8 [expr {$a6c & 0xff}] \
      FAILED_ROLE [expr {($a6c >> 24) & 0xff}] \
      FAILED_STATE [expr {($a6c >> 16) & 0xff}] \
      DISABLE_VALID $disable_valid DISABLE_CAUSE $disable_cause \
      DISABLE_PTP_STATE $disable_ptp_state \
      A8C_RESULT [expr {$a8c & 0xff}] \
      A8C_CHECK_LOCK [expr {($a8c >> 8) & 1}] \
      FAILURE_REASON [expr {($a8c >> 9) & 0x7f}] \
      FAILURE_TICS_LOW16 [expr {($a8c >> 16) & 0xffff}]]
  }

  proc new_state {} {
    return [dict create STOP_REASON NONE INVALID_STREAK 0 STEP1_ESTABLISHED 0 \
      RESET_SIGNATURE {} PREVIOUS_FAILURE_COUNT -1 INITIAL_S_LOCK_SEEN 0 TIMEOUT_FAILURE_SEEN 0 \
      RECOVERY_PRESENT_SEEN 0 RECOVERY_S_LOCK_SEEN 0 RECOVERY_ADMISSION 0 \
      SUCCESS_EVENT_SEEN 0 FIRST_EVENT_KIND NONE FIRST_EVENT_ELAPSED_MS -1 \
      PREVIOUS_UCNT -1 PREVIOUS_PHASE_PAYLOAD {} PUB_STATUS NONE UCNT_DELTA -1 \
      STABLE_WINDOW_STARTED 0 STABLE_WINDOW_START_MS -1 STABLE_WINDOW_LAST_MS -1 \
      STABLE_WINDOW_ROWS 0]
  }

  proc _result {state row stop} {
    dict set state STOP_REASON $stop
    return [dict create STATE $state ROW $row STOP_REASON $stop]
  }

  proc _set_stop {state row reason} {
    dict set row STOP_CANDIDATE $reason
    return [_result $state $row $reason]
  }

  proc _payload {row} {
    return [list [dict get $row CKO_PS] [dict get $row SSTAT_RAW] \
      [dict get $row SETP_PS]]
  }

  proc _publication {state row} {
    dict set row PUB_STATUS INVALID
    dict set row UCNT_DELTA -1
    if {[dict get $row DIAG_FRAME_VALID] != 1} {
      return [dict create STATE $state ROW $row STOP_REASON NONE]
    }
    set ucnt [dict get $row UCNT]
    set previous_ucnt [dict get $state PREVIOUS_UCNT]
    set payload [_payload $row]
    if {$ucnt < 0} {
      dict set row PUB_STATUS INVALID_UCNT
    } elseif {$previous_ucnt < 0} {
      dict set row PUB_STATUS FIRST
      dict set row UCNT_DELTA FIRST
      dict set state PREVIOUS_UCNT $ucnt
      dict set state PREVIOUS_PHASE_PAYLOAD $payload
    } else {
      set delta [expr {($ucnt - $previous_ucnt) & 0xffffffff}]
      dict set row UCNT_DELTA $delta
      if {$delta == 0} {
        if {$payload ne [dict get $state PREVIOUS_PHASE_PAYLOAD]} {
          return [dict create STATE $state ROW $row STOP_REASON SAME_UCNT_PHASE_PAYLOAD_CONFLICT]
        }
        dict set row PUB_STATUS REPEAT_CACHED
      } elseif {$delta <= $::s6r::max_ucnt_delta} {
        dict set row PUB_STATUS ADVANCE
        dict set state PREVIOUS_UCNT $ucnt
        dict set state PREVIOUS_PHASE_PAYLOAD $payload
      } elseif {$delta >= 0x80000000} {
        return [dict create STATE $state ROW $row STOP_REASON UCNT_ROLLBACK_OR_RESET]
      } else {
        return [dict create STATE $state ROW $row STOP_REASON UCNT_IMPLAUSIBLE_JUMP]
      }
    }
    return [dict create STATE $state ROW $row STOP_REASON NONE]
  }

  proc step {state row} {
    if {[dict get $state STOP_REASON] ne "NONE"} {
      return [_result $state $row [dict get $state STOP_REASON]]
    }
    set now [dict get $row ROW_END_MS]
    set was_admission_seen [dict get $state RECOVERY_ADMISSION]
    set stop NONE
    dict set row STOP_CANDIDATE NONE
    dict set row FAILURE_DELTA_U8 0
    dict set row NEW_FAILURE_RECORD 0
    dict set row PUB_STATUS INVALID
    dict set row UCNT_DELTA -1

    if {[dict get $row RESET_CHANGED]} {
      return [_set_stop $state $row RESET_OR_BOOT_SIGNATURE_CHANGED]
    }
    if {[dict get $row DIAG_FRAME_VALID] == 1 &&
        [dict get $row DISABLE_VALID] == 1} {
      return [_set_stop $state $row STICKY_EXTENSION_DISABLE_OBSERVED]
    }

    set publication [_publication $state $row]
    set state [dict get $publication STATE]
    set row [dict get $publication ROW]
    if {[dict get $publication STOP_REASON] ne "NONE"} {
      return [_set_stop $state $row [dict get $publication STOP_REASON]]
    }

    if {[dict get $row ROW_RAW_VALID] != 1} {
      set streak [expr {[dict get $state INVALID_STREAK] + 1}]
      dict set state INVALID_STREAK $streak
      if {[dict get $state STABLE_WINDOW_STARTED] &&
          $now - [dict get $state STABLE_WINDOW_LAST_MS] > $::s6r::max_window_gap_ms} {
        return [_set_stop $state $row STABLE_WINDOW_OBSERVATION_GAP_GT_1S]
      }
      if {$streak >= 5} {
        return [_set_stop $state $row FIVE_CONSECUTIVE_INVALID_REQUIRED_FRAMES]
      }
    } else {
      dict set state INVALID_STREAK 0
      set step1 [dict get $row STEP1_GATE]
      if {$step1 == 1} {
        dict set state STEP1_ESTABLISHED 1
      } elseif {$step1 == 0 && [dict get $state STEP1_ESTABLISHED]} {
        return [_set_stop $state $row STEP1_LOST_AFTER_ESTABLISHED]
      }

      set failure_count [dict get $row FAILURE_COUNT_U8]
      if {$step1 == 1 && [dict get $row WR_STATE] == 2 &&
          ![dict get $state TIMEOUT_FAILURE_SEEN]} {
        dict set state INITIAL_S_LOCK_SEEN 1
      }
      if {$failure_count >= 0} {
        set previous [dict get $state PREVIOUS_FAILURE_COUNT]
        if {$previous >= 0} {
          set delta [expr {($failure_count - $previous) & 0xff}]
          dict set row FAILURE_DELTA_U8 $delta
          if {$delta >= 128} {
            return [_set_stop $state $row FAILURE_COUNTER_DISCONTINUITY]
          }
          if {$delta > 0} {
            dict set row NEW_FAILURE_RECORD 1
            if {[dict get $state INITIAL_S_LOCK_SEEN] &&
                [dict get $row FAILURE_REASON_VALID] == 1 &&
                [dict get $row FAILURE_REASON] == 3} {
              dict set state TIMEOUT_FAILURE_SEEN 1
            }
            if {[dict get $state STABLE_WINDOW_STARTED]} {
              return [_set_stop $state $row NEW_FAILURE_DURING_STABLE_WINDOW]
            }
          }
        }
        dict set state PREVIOUS_FAILURE_COUNT $failure_count
      }

      set wr_state [dict get $row WR_STATE]
      if {[dict get $state TIMEOUT_FAILURE_SEEN] && $wr_state == 1} {
        dict set state RECOVERY_PRESENT_SEEN 1
      }
      if {[dict get $state RECOVERY_PRESENT_SEEN] && $wr_state == 2} {
        dict set state RECOVERY_S_LOCK_SEEN 1
      }

      set event_kind [dict get $row ROW_EVENT_KIND]
      if {[dict get $row EVENT_EVIDENCE_VALID] == 1 && $step1 == 1 &&
          $event_kind in {SLOCK_HANDOFF_NEXT_LOCKED WRS_LOCKED_STATE TX_LOCKED_SEND_SUCCESS}} {
        if {![dict get $state SUCCESS_EVENT_SEEN]} {
          dict set state SUCCESS_EVENT_SEEN 1
          dict set state FIRST_EVENT_KIND $event_kind
          dict set state FIRST_EVENT_ELAPSED_MS [dict get $row EVENT_ELAPSED_MS]
        }
        if {[dict get $state INITIAL_S_LOCK_SEEN] &&
            [dict get $state TIMEOUT_FAILURE_SEEN] &&
            [dict get $state RECOVERY_PRESENT_SEEN] &&
            [dict get $state RECOVERY_S_LOCK_SEEN]} {
          dict set state RECOVERY_ADMISSION 1
        }
      }

      set gates_ok [expr {
        [dict get $row STEP1_GATE] == 1 &&
        [dict get $row HELPER_LOCK] == 1 &&
        [dict get $row MAIN_ENABLED] == 1 &&
        [dict get $row MAIN_FREQ_LOCK] == 1 &&
        [dict get $row MAIN_PHASE_LOCK] == 1 &&
        [dict get $row MAIN_LOCK] == 1 &&
        [dict get $row PSTAT_LOCK] == 1 &&
        [dict get $row GLOBAL_TIME_OK] == 1 &&
        [dict get $row SERVO_STATE] == 4 &&
        abs([dict get $row CKO_PS]) < 60 &&
        [dict get $row FAILURE_DELTA_U8] == 0}]
      set fresh_publication [expr {[dict get $row PUB_STATUS] in {FIRST ADVANCE}}]
      set trusted_observation [expr {
        [dict get $row ROW_RAW_VALID] == 1 &&
        [dict get $row DIAG_FRAME_VALID] == 1 &&
        [dict get $row GLOBAL_FRAME_VALID] == 1}]

      if {[dict get $state STABLE_WINDOW_STARTED]} {
        if {$now - [dict get $state STABLE_WINDOW_LAST_MS] > $::s6r::max_window_gap_ms} {
          return [_set_stop $state $row STABLE_WINDOW_OBSERVATION_GAP_GT_1S]
        }
        if {$trusted_observation && !$gates_ok} {
          return [_set_stop $state $row STABLE_WINDOW_QUALIFICATION_LOST]
        }
        if {$gates_ok && $fresh_publication} {
          dict set state STABLE_WINDOW_LAST_MS $now
          dict incr state STABLE_WINDOW_ROWS
          if {$now - [dict get $state STABLE_WINDOW_START_MS] >= $::s6r::stable_window_ms} {
            dict set row STABLE_WINDOW_ELAPSED_MS [expr {$now - [dict get $state STABLE_WINDOW_START_MS]}]
            return [_set_stop $state $row PASS_300S_SAMPLED_STABLE_OFFSET]
          }
        }
      } elseif {$was_admission_seen && $trusted_observation && $gates_ok && $fresh_publication} {
        dict set state STABLE_WINDOW_STARTED 1
        dict set state STABLE_WINDOW_START_MS $now
        dict set state STABLE_WINDOW_LAST_MS $now
        dict incr state STABLE_WINDOW_ROWS
      }
    }

    if {![dict get $state RECOVERY_ADMISSION] && $now >= $::s6r::admission_timeout_ms} {
      return [_set_stop $state $row NO_ADMISSION_EVIDENCE_600S]
    }
    if {$now >= $::s6r::total_timeout_ms} {
      return [_set_stop $state $row STABLE_WINDOW_NOT_ESTABLISHED_900S]
    }
    dict set row STABLE_WINDOW_STARTED [dict get $state STABLE_WINDOW_STARTED]
    dict set row STABLE_WINDOW_ROWS [dict get $state STABLE_WINDOW_ROWS]
    dict set row RECOVERY_ADMISSION_SUPPORTED [dict get $state RECOVERY_ADMISSION]
    dict set row SUCCESS_EVENT_SEEN [dict get $state SUCCESS_EVENT_SEEN]
    dict set row STABLE_WINDOW_START_MS [dict get $state STABLE_WINDOW_START_MS]
    dict set row STABLE_WINDOW_LAST_MS [dict get $state STABLE_WINDOW_LAST_MS]
    return [_result $state $row NONE]
  }
}
