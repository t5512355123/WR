from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "analysis" / "step6_time_valid_300s.py"
SPEC = importlib.util.spec_from_file_location("step6_time_valid_300s", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

BOARDS = ("1-11.1", "1-11.2")


def good_row(board_id: str, sample: int, elapsed_ms: int,
             **overrides: str) -> str:
    fields = {
        "sample": str(sample),
        "elapsed_ms": str(elapsed_ms),
        "STATUS_TIME_VALID": "1",
        "SNAPSHOT_TIME_VALID": "1",
        "GLOBAL_TIME_VALID": "1",
        "STATUS_PPS_VALID": "1",
        "SNAPSHOT_PPS_VALID": "1",
        "STABLE": "1",
        "SNAPSHOT_VALID": "1",
        "SNAPSHOT_STABLE": "1",
        "TAI": str(1000 + elapsed_ms // 1000),
        "CYCLES": "124999999",
        "LIVE_TAI_LO": str(1000 + elapsed_ms // 1000),
        "LIVE_CYCLES": str((elapsed_ms % 1000) * 125000),
        "STATUS_SI_CONFIG": "1",
        "STATUS_PHY_READY": "1",
        "STATUS_TM_LINK_UP": "1",
        "STATUS_LINK_OK": "1",
        "STATUS_RX_READY": "1",
        "STATUS_TX_READY": "1",
        "STATUS_CPU_RESET_N": "1",
    }
    fields.update(overrides)
    return f"GLOBAL_TIME_SAMPLE board=DE5 [{board_id}] " + " ".join(
        f"{key}={value}" for key, value in fields.items()
    )


def capture(*, bad_board: str | None = None, bad_sample: int | None = None,
            last_elapsed_ms: int = 300_000, gap_board: str | None = None,
            gap_sample: int | None = None, diagnostic_bad_sample: int | None = None,
            boards: tuple[str, ...] = BOARDS) -> str:
    lines = [
        "GLOBAL_TIME_CONFIG duration_ms=303000 sample_ms=250 board_filter= "
        "reference_clock_hz=125000000"
    ]
    for board_id in boards:
        for sample in range(301):
            elapsed = sample * 1000
            if sample == 300:
                elapsed = last_elapsed_ms
            if board_id == gap_board and gap_sample is not None and sample >= gap_sample:
                elapsed += 1001
            overrides: dict[str, str] = {}
            if board_id == bad_board and sample == bad_sample:
                overrides["STATUS_TIME_VALID"] = "0"
            if board_id == bad_board and sample == diagnostic_bad_sample:
                overrides.update({
                    "SNAPSHOT_TIME_VALID": "0",
                    "GLOBAL_TIME_VALID": "0",
                    "STATUS_PPS_VALID": "0",
                    "SNAPSHOT_PPS_VALID": "0",
                    "STABLE": "0",
                    "SNAPSHOT_VALID": "0",
                    "SNAPSHOT_STABLE": "0",
                    "TAI": "not-a-number",
                    "CYCLES": "invalid",
                    "STATUS_LINK_OK": "0",
                })
            lines.append(good_row(board_id, sample, elapsed, **overrides))
        elapsed_done = 300_001 if last_elapsed_ms == 300_000 else last_elapsed_ms + 1
        lines.append(
            f"GLOBAL_TIME_DONE board=DE5 [{board_id}] samples=301 "
            f"elapsed_ms={elapsed_done}"
        )
    return "\n".join(lines)


class Step6TimeValid300sTests(unittest.TestCase):
    def test_both_boards_pass_from_status_time_valid_alone(self) -> None:
        result = MODULE.analyze_text(capture())
        self.assertEqual(result["verdict"], "PASS_TIME_VALID_300S")
        self.assertEqual(result["required_boards"], list(BOARDS))
        for board in BOARDS:
            self.assertEqual(result["boards"][board]["time_valid_rows"], 301)
            self.assertEqual(result["boards"][board]["verdict"], "PASS_TIME_VALID_300S")

    def test_any_sampled_status_time_valid_drop_on_either_board_fails(self) -> None:
        result = MODULE.analyze_text(capture(bad_board="1-11.2", bad_sample=170))
        self.assertEqual(result["verdict"], "TIME_VALID_300S_NOT_ESTABLISHED")
        self.assertIn(170, result["boards"]["1-11.2"]["first_invalid_rows"])
        self.assertEqual(result["boards"]["1-11.2"]["invalid_row_count"], 1)
        self.assertEqual(result["boards"]["1-11.1"]["verdict"], "PASS_TIME_VALID_300S")

    def test_snapshot_pps_link_payload_and_lock_diagnostics_do_not_gate(self) -> None:
        result = MODULE.analyze_text(capture(
            bad_board="1-11.2", diagnostic_bad_sample=120
        ))
        self.assertEqual(result["verdict"], "PASS_TIME_VALID_300S")
        self.assertTrue(
            result["snapshot_pps_link_locks_tai_cycles_and_phase_are_diagnostic_only"]
        )

    def test_live_time_monotonicity_is_diagnostic_only(self) -> None:
        text = capture().replace(
            "LIVE_TAI_LO=1001 LIVE_CYCLES=0",
            "LIVE_TAI_LO=1 LIVE_CYCLES=1",
            1,
        )
        result = MODULE.analyze_text(text)
        self.assertEqual(result["verdict"], "PASS_TIME_VALID_300S")
        self.assertFalse(result["boards"]["1-11.1"]["live_time_monotonic"])

    def test_insufficient_observed_duration_fails(self) -> None:
        result = MODULE.analyze_text(capture(last_elapsed_ms=299_999))
        self.assertEqual(result["verdict"], "TIME_VALID_300S_NOT_ESTABLISHED")

    def test_sample_gap_over_limit_fails(self) -> None:
        result = MODULE.analyze_text(capture(gap_board="1-11.1", gap_sample=100))
        self.assertEqual(result["verdict"], "TIME_VALID_300S_NOT_ESTABLISHED")

    def test_missing_required_board_fails(self) -> None:
        result = MODULE.analyze_text(capture(boards=("1-11.2",)))
        self.assertEqual(result["verdict"], "TIME_VALID_300S_NOT_ESTABLISHED")


if __name__ == "__main__":
    unittest.main()
