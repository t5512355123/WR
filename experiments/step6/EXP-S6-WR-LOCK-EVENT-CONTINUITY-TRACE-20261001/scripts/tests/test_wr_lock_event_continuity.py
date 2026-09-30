from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from analyze_wr_lock_event_continuity import analyze_text, non_atomic_counter_summary, parse_fields


REPO_ROOT = Path(__file__).resolve().parents[5]
PRIOR_RAW = REPO_ROOT / "experiments/step6/EXP-S6-WR-LOCK-SUCCESS-CONTINUITY-TRACE-20261001/raw/observe/20260930T185351Z-wr-lock-success-continuity.log"


def event_row(
    *, sample=1, elapsed=100, row_kind="NONE", triggered=0, event_kind="NONE",
    event_elapsed=-1, post_elapsed=-1, read_valid=1, event_valid=1,
    context_valid=1, required_valid=None, tx_valid=1,
    step1=1, state=0, next_state=0, tx_id=0, tx_count=0,
    boot="1", cpu="1", wr_reset="1", si="1",
):
    fields = {
        "sample": sample,
        "elapsed_ms": elapsed,
        "row_start_ms": elapsed,
        "row_end_ms": elapsed + 20,
        "row_spacing_ms": 400,
        "READ_VALID": read_valid,
        "EVENT_EVIDENCE_VALID": event_valid,
        "REQUIRED_ROW_VALID": read_valid and event_valid if required_valid is None else required_valid,
        "CONTEXT_READ_VALID": context_valid,
        "COUNTER_READ_VALID": 1,
        "STEP1_GATE": step1,
        "boot_generation": boot,
        "cpu_reset_count": cpu,
        "wr_core_reset_count": wr_reset,
        "si_config_drop_count": si,
        "WR_STATE": state,
        "WR_NEXT_STATE": next_state,
        "WR_TX_ID": tx_id,
        "WR_TX_COUNT": tx_count,
        "TX_READ_VALID": tx_valid,
        "ROW_EVENT_KIND": row_kind,
        "EVENT_READ_BEGIN_MS": elapsed + 10,
        "EVENT_READ_END_MS": elapsed + 20,
        "EVENT_TRIGGERED": triggered,
        "EVENT_KIND": event_kind,
        "EVENT_ELAPSED_MS": event_elapsed,
        "POST_EVENT_ELAPSED_MS": post_elapsed,
        "COUNTER_NONATOMIC": 1,
        "TAIL_CONTEXT_ONLY": 1,
    }
    return "S6E_SAMPLE " + " ".join(f"{key}={value}" for key, value in fields.items())


class WrLockEventContinuityTests(unittest.TestCase):
    def test_source_handoff_event_triggers_complete_five_second_window(self):
        text = "\n".join([
            event_row(sample=1, elapsed=100, row_kind="SLOCK_HANDOFF_NEXT_LOCKED",
                      triggered=1, event_kind="SLOCK_HANDOFF_NEXT_LOCKED",
                      event_elapsed=120, post_elapsed=0, state=2, next_state=4),
            event_row(sample=2, elapsed=5100, triggered=1,
                      event_kind="SLOCK_HANDOFF_NEXT_LOCKED",
                      event_elapsed=120, post_elapsed=5000, state=4),
            "S6E_STOP elapsed_ms=5200 reason=POST_EVENT_WINDOW_COMPLETE",
        ])
        result = analyze_text(text)
        self.assertEqual(result["result"], "SOURCE_EVENT_WITH_5S_CONTINUITY_CAPTURE")
        self.assertEqual(result["first_event_kind"], "SLOCK_HANDOFF_NEXT_LOCKED")
        self.assertEqual(result["live_event_trigger_edges"], 1)

    def test_tx_locked_send_event_is_distinguished(self):
        text = "\n".join([
            event_row(row_kind="TX_LOCKED_SEND_SUCCESS", triggered=1,
                      event_kind="TX_LOCKED_SEND_SUCCESS", event_elapsed=120,
                      tx_id=0x1002, tx_count=3),
            event_row(sample=2, elapsed=5200, triggered=1,
                      event_kind="TX_LOCKED_SEND_SUCCESS", event_elapsed=120,
                      post_elapsed=5000, tx_id=0x1002, tx_count=3),
            "S6E_STOP elapsed_ms=5300 reason=POST_EVENT_WINDOW_COMPLETE",
        ])
        result = analyze_text(text)
        self.assertEqual(result["first_event_kind"], "TX_LOCKED_SEND_SUCCESS")

    def test_matched_state_event_is_not_blocked_by_unrelated_invalid_context(self):
        text = "\n".join([
            event_row(row_kind="SLOCK_HANDOFF_NEXT_LOCKED", triggered=1,
                      event_kind="SLOCK_HANDOFF_NEXT_LOCKED", event_elapsed=120,
                      context_valid=0, tx_valid=0, state=2, next_state=4),
            event_row(sample=2, elapsed=5100, triggered=1,
                      event_kind="SLOCK_HANDOFF_NEXT_LOCKED", event_elapsed=120,
                      post_elapsed=5000, context_valid=0, tx_valid=0, state=4),
            "S6E_STOP elapsed_ms=5200 reason=POST_EVENT_WINDOW_COMPLETE",
        ])
        result = analyze_text(text)
        self.assertEqual(result["result"], "SOURCE_EVENT_WITH_5S_CONTINUITY_CAPTURE")
        self.assertEqual(result["context_valid_rows"], 0)

    def test_invalid_or_step1_unready_event_does_not_count(self):
        text = "\n".join([
            event_row(read_valid=0, row_kind="SLOCK_HANDOFF_NEXT_LOCKED", state=2, next_state=4),
            event_row(sample=2, elapsed=500, step1=0,
                      row_kind="WRS_LOCKED_STATE", state=4),
            "S6E_STOP elapsed_ms=600 reason=FIVE_CONSECUTIVE_INVALID_REQUIRED_RAW_ROWS",
        ])
        result = analyze_text(text)
        self.assertEqual(result["source_event_row_count"], 0)
        self.assertEqual(result["first_event_kind"], "NONE")

    def test_reset_change_stops_post_event_capture_classification(self):
        text = "\n".join([
            event_row(row_kind="WRS_LOCKED_STATE", triggered=1,
                      event_kind="WRS_LOCKED_STATE", event_elapsed=120, state=4),
            event_row(sample=2, elapsed=5100, triggered=1,
                      event_kind="WRS_LOCKED_STATE", event_elapsed=120,
                      post_elapsed=5000, state=4, boot="2"),
            "S6E_STOP elapsed_ms=5200 reason=RESET_OR_BOOT_SIGNATURE_CHANGED",
        ])
        self.assertEqual(analyze_text(text)["result"], "POST_EVENT_CAPTURE_STOPPED_EARLY")

    def test_no_event_timeout_is_not_a_step6_verdict(self):
        text = event_row() + "\nS6E_STOP elapsed_ms=300000 reason=NO_SUCCESS_EVIDENCE_OBSERVED_300S\n"
        result = analyze_text(text)
        self.assertEqual(result["result"], "NO_SUCCESS_EVIDENCE_OBSERVED_300S")
        self.assertEqual(result["step6_stable_offset"], "NOT_EVALUATED")

    def test_zero_post_event_elapsed_is_retained_as_valid_context(self):
        text = "\n".join([
            event_row(row_kind="WRS_LOCKED_STATE", triggered=1,
                      event_kind="WRS_LOCKED_STATE", event_elapsed=120,
                      post_elapsed=0, state=4),
            "S6E_STOP elapsed_ms=300 reason=FATAL_JTAG_OR_TCL_ERROR",
        ])
        result = analyze_text(text)
        self.assertEqual(result["post_event_max_ms"], 0)
        self.assertEqual(result["result"], "POST_EVENT_CAPTURE_STOPPED_EARLY")

    def test_case_normalization_and_case_conflict_detection(self):
        parsed = parse_fields("S6E_SAMPLE row_valid=1 READ_VALID=1")
        self.assertEqual(parsed["ROW_VALID"], "1")
        with self.assertRaisesRegex(ValueError, "FIELD_CASE_CONFLICT"):
            parse_fields("S6E_SAMPLE state=2 STATE=4")

    def test_real_previous_run_pairs_are_context_only_not_success_events(self):
        text = PRIOR_RAW.read_text(encoding="utf-8", errors="replace")
        legacy_rows = [
            parse_fields(line) for line in text.splitlines()
            if line.startswith("S6W_SAMPLE ")
        ]
        summary = non_atomic_counter_summary(legacy_rows)
        self.assertEqual(summary, {
            "intervals": 88,
            "nonnegative": 85,
            "positive": 2,
            "zero": 83,
            "negative_or_invalid": 3,
        })
        result = analyze_text(text)
        self.assertEqual(result["source_event_row_count"], 0)
        self.assertEqual(result["legacy_counter_intervals"]["positive"], 2)


if __name__ == "__main__":
    unittest.main()
