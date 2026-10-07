#!/usr/bin/env python3
"""Hardware-independent regression tests for the Step5 evidence replay."""

from __future__ import annotations

import math
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts" / "analysis"))

import step5_replay  # noqa: E402


def sample(**fields: object) -> str:
    common = {
        "FRAME_VALID": 1,
        "COHERENT": 1,
        "HELPER_ERROR": 3,
        "HELPER_UPDATE_COUNT": 1,
        "POSITION_VALID": 1,
        "POSITION_EPOCH": 1,
        "TARGET_CODE": 10,
        "APPLIED_CODE": 10,
        "DCO_STEP": 0,
        "NORMAL_REQ": 0,
        "NORMAL_COMPLETED": 0,
        "FINC_COMPLETED": 0,
        "FDEC_COMPLETED": 0,
        "EPOCH": 1,
        "ELAPSED_MS": 0,
        "BOOT_GENERATION": 1,
        "HELPER_LOCKED": 1,
        "HELPER_LOCK_COUNT": 999,
        "MAIN_ENABLED": 1,
        "MAIN_FREQ_LOCKED": 1,
        "MAIN_PHASE_LOCKED": 1,
        "MAIN_LOCKED": 1,
        "PSTAT_LOCKED": 1,
    }
    common.update(fields)
    return "STEP5_CLOSED_LOOP_SAMPLE " + " ".join(f"{key}={value}" for key, value in common.items())


class Step5ReplayTests(unittest.TestCase):
    def test_rms_is_root_mean_square_and_bounded_by_max_abs(self) -> None:
        result = step5_replay.analyze_text(
            sample(HELPER_ERROR=3, HELPER_UPDATE_COUNT=1, EPOCH=1)
            + "\n"
            + sample(HELPER_ERROR=4, HELPER_UPDATE_COUNT=2, EPOCH=2, ELAPSED_MS=100)
        )
        self.assertAlmostEqual(result["helper_error_rms"], math.sqrt(12.5))
        self.assertEqual(result["helper_error_max_abs"], 4)
        self.assertLessEqual(result["helper_error_rms"], result["helper_error_max_abs"])

    def test_locked_count_999_is_valid_with_hysteresis(self) -> None:
        result = step5_replay.analyze_text(sample(HELPER_LOCKED=1, HELPER_LOCK_COUNT=999))
        self.assertEqual(result["measurement_valid_samples"], 1)

    def test_invalid_frame_splits_full_chain(self) -> None:
        text = "\n".join([
            sample(EPOCH=1, HELPER_UPDATE_COUNT=1, ELAPSED_MS=0),
            sample(EPOCH=2, HELPER_UPDATE_COUNT=2, ELAPSED_MS=100),
            sample(FRAME_VALID=0, COHERENT=0, HELPER_LOCKED=0, EPOCH=3,
                   HELPER_UPDATE_COUNT=3, ELAPSED_MS=200),
            sample(EPOCH=4, HELPER_UPDATE_COUNT=4, ELAPSED_MS=300),
            sample(EPOCH=5, HELPER_UPDATE_COUNT=5, ELAPSED_MS=400),
        ])
        result = step5_replay.analyze_text(text)
        self.assertEqual(len(result["full_chain_segments"]), 2)
        self.assertEqual([segment["duration_ms"] for segment in result["full_chain_segments"]], [100, 100])

    def test_stale_main_producer_does_not_extend_chain(self) -> None:
        text = "\n".join([
            sample(EPOCH=1, HELPER_UPDATE_COUNT=1, MAIN_UPDATE_SEQ=10, ELAPSED_MS=0),
            sample(EPOCH=2, HELPER_UPDATE_COUNT=2, MAIN_UPDATE_SEQ=10, ELAPSED_MS=100),
        ])
        result = step5_replay.analyze_text(text)
        self.assertEqual(result["stale_full_chain_samples"], 1)
        self.assertEqual(result["max_continuous_full_chain_ms"], 0)
        self.assertFalse(result["full_chain_freshness_unknown"])

    def test_modulo_wrap_is_small_delta(self) -> None:
        self.assertEqual(step5_replay.modulo_delta(254, 2, 8), 4)
        text = "\n".join([
            sample(COUNTER8=254, ELAPSED_MS=0),
            sample(COUNTER8=2, EPOCH=2, HELPER_UPDATE_COUNT=2, ELAPSED_MS=100),
        ])
        result = step5_replay.analyze_text(text)
        self.assertEqual(result["counter_accounting"]["COUNTER8"]["delta_sum"], 4)
        self.assertEqual(result["counter_accounting"]["COUNTER8"]["ambiguous"], 0)

    def test_long_counter_gap_is_ambiguous(self) -> None:
        text = "\n".join([
            sample(COUNTER8=1, ELAPSED_MS=0),
            sample(COUNTER8=4, EPOCH=2, HELPER_UPDATE_COUNT=2, ELAPSED_MS=1000),
        ])
        result = step5_replay.analyze_text(text, max_gap_ms=250)
        self.assertEqual(result["counter_accounting"]["COUNTER8"]["ambiguous"], 1)

    def test_invalid_value_is_unknown_not_zero(self) -> None:
        record = step5_replay.parse_key_values(
            "STEP5_CLOSED_LOOP_SAMPLE FRAME_VALID=1 HELPER_ERROR=INVALID"
        )
        self.assertIsNone(record["HELPER_ERROR"])


if __name__ == "__main__":
    unittest.main()
