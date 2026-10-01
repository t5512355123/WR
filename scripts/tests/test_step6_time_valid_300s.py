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


def good_row(sample: int, elapsed_ms: int, **overrides: str) -> str:
    fields = {
        "sample": str(sample),
        "elapsed_ms": str(elapsed_ms),
        "STABLE": "1",
        "SNAPSHOT_VALID": "1",
        "SNAPSHOT_TIME_VALID": "1",
        "SNAPSHOT_PPS_VALID": "1",
        "SNAPSHOT_COUNT": str(sample),
        "TAI": str(1000 + elapsed_ms // 1000),
        "CYCLES": "124999999",
        "LIVE_TAI_LO": str(1000 + elapsed_ms // 1000),
        "LIVE_CYCLES": str((elapsed_ms % 1000) * 125000),
        "STATUS_SI_CONFIG": "1",
        "STATUS_PHY_READY": "1",
        "STATUS_TM_LINK_UP": "1",
        "STATUS_LINK_OK": "1",
        "STATUS_TIME_VALID": "1",
        "STATUS_PPS_VALID": "1",
        "STATUS_RX_READY": "1",
        "STATUS_TX_READY": "1",
        "STATUS_CPU_RESET_N": "1",
    }
    fields.update(overrides)
    return "GLOBAL_TIME_SAMPLE board=DE5 [1-11.2] " + " ".join(
        f"{key}={value}" for key, value in fields.items()
    )


def capture(*, bad_sample: int | None = None, last_elapsed_ms: int = 300_000,
            gap_sample: int | None = None, invalid_pps_sample: int | None = None,
            bad_link_sample: int | None = None) -> str:
    rows: list[str] = []
    for sample in range(301):
        elapsed = sample * 1000
        if sample == 300:
            elapsed = last_elapsed_ms
        if gap_sample is not None and sample >= gap_sample:
            elapsed += 1001
        overrides: dict[str, str] = {}
        if sample == bad_sample:
            overrides.update(
                {"STATUS_TIME_VALID": "0", "SNAPSHOT_TIME_VALID": "0"}
            )
        if sample == invalid_pps_sample:
            overrides.update(
                {"STATUS_PPS_VALID": "0", "SNAPSHOT_PPS_VALID": "0"}
            )
        if sample == bad_link_sample:
            overrides["STATUS_LINK_OK"] = "0"
        rows.append(good_row(sample, elapsed, **overrides))
    return "\n".join(
        [
            "GLOBAL_TIME_CONFIG duration_ms=302000 sample_ms=250 board_filter=1-11.2 reference_clock_hz=125000000",
            *rows,
            "GLOBAL_TIME_DONE board=DE5 [1-11.2] samples=301 elapsed_ms=302003",
        ]
    )


class Step6TimeValid300sTests(unittest.TestCase):
    def test_pass_requires_300s_and_time_valid(self) -> None:
        result = MODULE.analyze_text(capture())
        self.assertEqual(result["verdict"], "PASS_TIME_VALID_300S")
        self.assertEqual(result["valid_rows"], 301)
        self.assertEqual(result["time_valid_rows"], 301)
        self.assertEqual(result["pps_valid_rows"], 301)
        self.assertTrue(result["live_time_monotonic"])

    def test_any_sampled_time_valid_drop_fails(self) -> None:
        result = MODULE.analyze_text(capture(bad_sample=170))
        self.assertEqual(result["verdict"], "TIME_VALID_300S_NOT_ESTABLISHED")
        self.assertIn(170, result["invalid_rows"])

    def test_pps_and_link_are_diagnostic_not_acceptance_gates(self) -> None:
        result = MODULE.analyze_text(
            capture(invalid_pps_sample=120, bad_link_sample=220)
        )
        self.assertEqual(result["verdict"], "PASS_TIME_VALID_300S")
        self.assertEqual(result["pps_valid_rows"], 300)
        self.assertEqual(result["step1_link_ready_rows"], 300)

    def test_insufficient_duration_fails_even_when_all_rows_are_valid(self) -> None:
        result = MODULE.analyze_text(capture(last_elapsed_ms=299_999))
        self.assertEqual(result["verdict"], "TIME_VALID_300S_NOT_ESTABLISHED")

    def test_sample_gap_over_limit_fails(self) -> None:
        result = MODULE.analyze_text(capture(gap_sample=100))
        self.assertEqual(result["verdict"], "TIME_VALID_300S_NOT_ESTABLISHED")

    def test_phase_offset_does_not_appear_in_the_acceptance_contract(self) -> None:
        result = MODULE.analyze_text(capture())
        self.assertTrue(result["phase_offset_is_not_a_gate"])


if __name__ == "__main__":
    unittest.main()
