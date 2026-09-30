source [file join [file dirname [info script]] .. rearm_stable_policy.tcl]

proc assert_equal {actual expected label} {
  incr ::assertion_count
  if {$actual ne $expected} {
    error "ASSERT_FAIL $label expected=<$expected> actual=<$actual>"
  }
}

set ::assertion_count 0

proc sample {overrides} {
  set row [dict create ROW_END_MS 100 ROW_RAW_VALID 1 RESET_CHANGED 0 \
    RESET_SIGNATURE_VALID 1 STEP1_GATE 1 DISABLE_VALID 0 \
    FAILURE_COUNT_U8 1 FAILURE_REASON_VALID 1 FAILURE_REASON 3 \
    WR_STATE 2 NEXT_STATE 0 EVENT_EVIDENCE_VALID 1 ROW_EVENT_KIND NONE \
    EVENT_ELAPSED_MS -1 DIAG_FRAME_VALID 1 GLOBAL_FRAME_VALID 1 \
    GLOBAL_TIME_OK 1 UCNT 10 CKO_PS 20 SSTAT_RAW 1024 SETP_PS 0 \
    SERVO_STATE 4 HELPER_LOCK 1 MAIN_ENABLED 1 MAIN_FREQ_LOCK 1 \
    MAIN_PHASE_LOCK 1 MAIN_LOCK 1 PSTAT_LOCK 1]
  dict for {key value} $overrides { dict set row $key $value }
  return $row
}

proc apply_sample {state row} {
  return [::s6r::step $state $row]
}

set decoded [::s6r::decode_failure_words 02020001 B9190601]
assert_equal [dict get $decoded VALID] 1 A6C_A8C_valid
assert_equal [dict get $decoded FAILURE_COUNT_U8] 1 failure_count_low8
assert_equal [dict get $decoded FAILED_ROLE] 2 failure_role
assert_equal [dict get $decoded FAILED_STATE] 2 failure_state
assert_equal [dict get $decoded DISABLE_VALID] 0 disable_not_observed
assert_equal [dict get $decoded DISABLE_CAUSE] NA invalid_disable_cause_is_na
assert_equal [dict get $decoded A8C_RESULT] 1 a8c_result
assert_equal [dict get $decoded A8C_CHECK_LOCK] 0 a8c_check_lock
assert_equal [dict get $decoded FAILURE_REASON] 3 a8c_reason_three
assert_equal [dict get $decoded FAILURE_TICS_LOW16] 47385 a8c_tics_low16
set decoded_zero_padded [::s6r::decode_failure_words 00000001 00000000]
assert_equal [dict get $decoded_zero_padded VALID] 1 leading_zero_raw_words_are_valid
assert_equal [dict get $decoded_zero_padded FAILURE_COUNT_U8] 1 leading_zero_count_decodes

# A reason-3 timeout followed by WRS_PRESENT is a recovery boundary, not stop.
set state [::s6r::new_state]
set result [apply_sample $state [sample [dict create ROW_END_MS 100 FAILURE_COUNT_U8 0 FAILURE_REASON 3]]]
set state [dict get $result STATE]
assert_equal [dict get $result STOP_REASON] NONE baseline_row_continues
assert_equal [dict get $state INITIAL_S_LOCK_SEEN] 1 initial_s_lock_is_recorded
set result [apply_sample $state [sample [dict create ROW_END_MS 200 FAILURE_COUNT_U8 1 FAILURE_REASON 3 WR_STATE 1]]]
set state [dict get $result STATE]
assert_equal [dict get $result STOP_REASON] NONE timeout_to_present_does_not_stop
assert_equal [dict get $state RECOVERY_PRESENT_SEEN] 1 present_marks_boundary
set result [apply_sample $state [sample [dict create ROW_END_MS 300 FAILURE_COUNT_U8 1 FAILURE_REASON 3 WR_STATE 2]]]
set state [dict get $result STATE]
assert_equal [dict get $result STOP_REASON] NONE present_to_s_lock_does_not_stop
assert_equal [dict get $state RECOVERY_S_LOCK_SEEN] 1 recovery_s_lock_seen
assert_equal [dict get $state RECOVERY_ADMISSION] 0 admission_waits_for_success_event
set result [apply_sample $state [sample [dict create ROW_END_MS 400 UCNT 11 \
  FAILURE_COUNT_U8 1 FAILURE_REASON 3 ROW_EVENT_KIND SLOCK_HANDOFF_NEXT_LOCKED \
  EVENT_ELAPSED_MS 395 WR_STATE 2 NEXT_STATE 4]]]
set state [dict get $result STATE]
assert_equal [dict get $state RECOVERY_ADMISSION] 1 source_event_completes_recovery_admission

# A sticky disable record is a genuine immediate stop.
set result [apply_sample [::s6r::new_state] [sample [dict create DISABLE_VALID 1]]]
assert_equal [dict get $result STOP_REASON] STICKY_EXTENSION_DISABLE_OBSERVED sticky_disable_stops
set result [apply_sample [::s6r::new_state] [sample [dict create DISABLE_VALID 1 DIAG_FRAME_VALID 0 ROW_RAW_VALID 0]]]
assert_equal [dict get $result STOP_REASON] NONE untrusted_disable_word_does_not_stop

# Missing reset-signature words count as invalid required rows; one miss is not fatal.
set state [::s6r::new_state]
for {set i 1} {$i <= 4} {incr i} {
  set result [apply_sample $state [sample [dict create ROW_END_MS [expr {$i * 100}] \
    RESET_SIGNATURE_VALID 0 ROW_RAW_VALID 0]]]
  set state [dict get $result STATE]
  assert_equal [dict get $result STOP_REASON] NONE reset_signature_miss_is_invalid_frame
}
set result [apply_sample $state [sample [dict create ROW_END_MS 500 \
  RESET_SIGNATURE_VALID 0 ROW_RAW_VALID 0]]]
assert_equal [dict get $result STOP_REASON] FIVE_CONSECUTIVE_INVALID_REQUIRED_FRAMES five_invalid_rows_stop

set result [apply_sample [::s6r::new_state] [sample [dict create ROW_END_MS 600000]]]
assert_equal [dict get $result STOP_REASON] NO_ADMISSION_EVIDENCE_600S no_admission_deadline

# Qualification cannot begin until failure -> PRESENT -> S_LOCK -> source event.
set state [::s6r::new_state]
set result [apply_sample $state [sample [dict create ROW_END_MS 100 UCNT 10 WR_STATE 2 FAILURE_COUNT_U8 0]]]
set state [dict get $result STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 200 UCNT 11 FAILURE_COUNT_U8 1 \
  FAILURE_REASON 3 WR_STATE 1]]]
set state [dict get $result STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 300 UCNT 12 FAILURE_COUNT_U8 1 \
  FAILURE_REASON 3 WR_STATE 2]]]
set state [dict get $result STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 400 UCNT 13 FAILURE_COUNT_U8 1 \
  FAILURE_REASON 3 ROW_EVENT_KIND SLOCK_HANDOFF_NEXT_LOCKED EVENT_ELAPSED_MS 395 WR_STATE 2 NEXT_STATE 4]]]
set state [dict get $result STATE]
assert_equal [dict get $state SUCCESS_EVENT_SEEN] 1 source_event_recorded
assert_equal [dict get $state RECOVERY_ADMISSION] 1 recovery_admission_recorded
assert_equal [dict get $state STABLE_WINDOW_STARTED] 0 event_row_not_reused_for_offset
set result [apply_sample $state [sample [dict create ROW_END_MS 500 UCNT 14]]]
set state [dict get $result STATE]
assert_equal [dict get $state STABLE_WINDOW_STARTED] 1 later_fresh_frame_starts_window
assert_equal [dict get $state STABLE_WINDOW_ROWS] 1 first_unique_qualification
set result [apply_sample $state [sample [dict create ROW_END_MS 1501 UCNT 15]]]
assert_equal [dict get $result STOP_REASON] STABLE_WINDOW_OBSERVATION_GAP_GT_1S late_fresh_frame_stops

# Re-reading the same cached publication cannot add qualifying time or rows.
set result [apply_sample $state [sample [dict create ROW_END_MS 1000 UCNT 14]]]
set state [dict get $result STATE]
assert_equal [dict get $result STOP_REASON] NONE duplicate_before_one_second_is_ignored
assert_equal [dict get $state STABLE_WINDOW_ROWS] 1 cached_frame_not_counted
set result [apply_sample $state [sample [dict create ROW_END_MS 1501 UCNT 14]]]
assert_equal [dict get $result STOP_REASON] STABLE_WINDOW_OBSERVATION_GAP_GT_1S duplicate_cannot_sustain_window

# Same UCNT with changed phase payload and implausible jumps stop immediately.
set state [dict get [apply_sample [::s6r::new_state] [sample [dict create ROW_END_MS 100 UCNT 7]]] STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 200 UCNT 7 CKO_PS 21]]]
assert_equal [dict get $result STOP_REASON] SAME_UCNT_PHASE_PAYLOAD_CONFLICT same_ucnt_conflict
set state [dict get [apply_sample [::s6r::new_state] [sample [dict create ROW_END_MS 100 UCNT 7]]] STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 200 UCNT 7 CKO_PS 21 \
  ROW_RAW_VALID 0 GLOBAL_FRAME_VALID 0]]]
assert_equal [dict get $result STOP_REASON] SAME_UCNT_PHASE_PAYLOAD_CONFLICT conflict_stops_even_if_global_group_invalid
set state [dict get [apply_sample [::s6r::new_state] [sample [dict create ROW_END_MS 100 UCNT 1]]] STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 200 UCNT 200]]]
assert_equal [dict get $result STOP_REASON] UCNT_IMPLAUSIBLE_JUMP large_ucnt_jump

# End-to-end policy mock: only fresh, in-band, fully-qualified updates reach 300 s.
set state [::s6r::new_state]
set result [apply_sample $state [sample [dict create ROW_END_MS 100 UCNT 100 FAILURE_COUNT_U8 0]]]
set state [dict get $result STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 200 UCNT 101 FAILURE_COUNT_U8 1 \
  FAILURE_REASON 3 WR_STATE 1]]]
set state [dict get $result STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 300 UCNT 102 FAILURE_COUNT_U8 1 \
  FAILURE_REASON 3 WR_STATE 2]]]
set state [dict get $result STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 400 UCNT 103 FAILURE_COUNT_U8 1 \
  FAILURE_REASON 3 ROW_EVENT_KIND SLOCK_HANDOFF_NEXT_LOCKED EVENT_ELAPSED_MS 395 WR_STATE 2 NEXT_STATE 4]]]
set state [dict get $result STATE]
set result [apply_sample $state [sample [dict create ROW_END_MS 500 UCNT 104]]]
set state [dict get $result STATE]
for {set i 1} {$i <= 300} {incr i} {
  set t [expr {500 + $i * 1000}]
  set result [apply_sample $state [sample [dict create ROW_END_MS $t UCNT [expr {104 + $i}]]]]
  set state [dict get $result STATE]
  if {$i < 300} {
    assert_equal [dict get $result STOP_REASON] NONE window_not_early
  }
}
assert_equal [dict get $result STOP_REASON] PASS_300S_SAMPLED_STABLE_OFFSET 300s_pass_requires_unique_fresh_frames
assert_equal [dict get $state STABLE_WINDOW_ROWS] 301 window_counts_unique_qualifications

puts [format "REARM_STABLE_POLICY_TESTS=PASS checks=%d" $::assertion_count]
