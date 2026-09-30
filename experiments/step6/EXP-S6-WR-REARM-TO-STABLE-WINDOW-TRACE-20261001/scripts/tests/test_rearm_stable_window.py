from __future__ import annotations

import sys
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_DIR))
from analyze_rearm_stable_window import analyze_text  # noqa: E402


def make_log(*, offset: int = 20, duplicate: bool = False, gap_ms: int = 1000,
             lose_gate_at: int | None = None) -> str:
    lines = [
        "S6R_CONFIG trial=test",
        "S6R_STOP reason=PASS_300S_SAMPLED_STABLE_OFFSET",
    ]
    start = 1000
    count = 301
    previous_ucnt = 10
    for i in range(count):
        t = start + i * gap_ms
        ucnt = previous_ucnt if duplicate and i > 0 else 10 + i
        gate = 0 if lose_gate_at == i else 1
        fields = {
            "ELAPSED_MS": t,
            "ROW_RAW_VALID": 1,
            "RESET_SIGNATURE_VALID": 1,
            "RESET_CHANGED": 0,
            "STEP1_GATE": 1,
            "DIAG_FRAME_VALID": 1,
            "GLOBAL_FRAME_VALID": 1,
            "GLOBAL_TIME_OK": 1,
            "HELPER_LOCK": 1,
            "MAIN_ENABLED": 1,
            "MAIN_FREQ_LOCK": 1,
            "MAIN_PHASE_LOCK": gate,
            "MAIN_LOCK": 1,
            "PSTAT_LOCK": 1,
            "SERVO_STATE": 4,
            "CKO_PS": offset,
            "FAILURE_DELTA_U8": 0,
            "WR_DISABLE_VALID": 0,
            "STABLE_WINDOW_STARTED": 1,
            "STABLE_WINDOW_START_MS": start,
            "PUB_STATUS": "ADVANCE" if not duplicate or i == 0 else "REPEAT_CACHED",
            "UCNT": ucnt,
            "RECOVERY_ADMISSION_SUPPORTED": 1,
        }
        lines.append("S6R_SAMPLE " + " ".join(f"{k}={v}" for k, v in fields.items()))
    lines.append(
        "S6R_SUMMARY recovery_admission_supported=1 stable_window_started=1 "
        f"stable_window_rows={count} stable_window_elapsed_ms={(count - 1) * gap_ms} stop_reason={PASS_REASON}"
    )
    return "\n".join(lines) + "\n"


PASS_REASON = "PASS_300S_SAMPLED_STABLE_OFFSET"


class StableWindowAnalyzerTests(unittest.TestCase):
    def test_complete_strict_300_second_window_passes(self) -> None:
        result = analyze_text(make_log(offset=59))
        self.assertEqual(result["verdict"], PASS_REASON)
        self.assertEqual(result["stable_elapsed_ms"], 300_000)
        self.assertEqual(result["stable_unique_rows"], 301)
        self.assertEqual(result["offset_max_ps"], 59)

    def test_exactly_sixty_ps_is_not_in_band(self) -> None:
        result = analyze_text(make_log(offset=60))
        self.assertEqual(result["verdict"], "REJECTED_QUALIFICATION_LOSS_IN_PASS_WINDOW")

    def test_qualification_loss_rejects_pass(self) -> None:
        result = analyze_text(make_log(lose_gate_at=120))
        self.assertEqual(result["verdict"], "REJECTED_QUALIFICATION_LOSS_IN_PASS_WINDOW")

    def test_duplicate_cached_rows_do_not_count_toward_duration(self) -> None:
        result = analyze_text(make_log(duplicate=True))
        self.assertEqual(result["verdict"], "REJECTED_TOO_FEW_FRESH_PUBLICATIONS")

    def test_gap_over_one_second_rejects_pass(self) -> None:
        result = analyze_text(make_log(gap_ms=1001))
        self.assertEqual(result["verdict"], "REJECTED_UNIQUE_PUBLICATION_GAP_GT_1S")

    def test_no_admission_is_not_a_pass(self) -> None:
        text = "S6R_SAMPLE ELAPSED_MS=10\nS6R_SUMMARY recovery_admission_supported=0 stop_reason=NO_ADMISSION_EVIDENCE_600S\n"
        result = analyze_text(text)
        self.assertEqual(result["verdict"], "NOT_ESTABLISHED")
        self.assertFalse(result["recovery_admission_supported"])


if __name__ == "__main__":
    unittest.main()
