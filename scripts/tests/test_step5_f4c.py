#!/usr/bin/env python3
"""Hardware-independent tests for the F4C Main phase/service audit."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts" / "analysis"))

import step5_f4c_replay  # noqa: E402


def f4c_sample(
    *,
    elapsed_ms: int,
    sample_n: int,
    phase_count: int = 10,
    phase_domain: str = "PHASE",
    phase_inband: int = 1,
    detector_valid: int = 1,
    trace_valid: int = 1,
    trace_unique: int = 1,
    main_advanced: int = 1,
    helper_locked: int = 1,
    helper_output: int = 30000,
    generation: int = 1,
    **extra: object,
) -> str:
    values = {
        "run_role": "long",
        "observer_sample_n": elapsed_ms // 100 + 1,
        "elapsed_ms": elapsed_ms,
        "MAIN_CORE_VALID": int(trace_valid and detector_valid),
        "MAIN_TRACE_VALID": trace_valid,
        "MAIN_TRACE_UNIQUE": trace_unique,
        "MAIN_TRACE_PUBLICATION_EPOCH_BEFORE_RAW": "00000002",
        "MAIN_TRACE_PUBLICATION_EPOCH_AFTER_RAW": "00000002",
        "MAIN_SAMPLE_N": sample_n,
        "MAIN_SAMPLE_N_DELTA": "INVALID",
        "MAIN_SAMPLE_N_ADVANCED": main_advanced,
        "MAIN_DETECTOR_VALID": detector_valid,
        "MAIN_DETECTOR_STABLE": detector_valid,
        "MAIN_DETECTOR_ENABLED": 1,
        "MAIN_DETECTOR_LOCKED": 0,
        "MAIN_DETECTOR_FREQ_LOCKED": int(phase_domain == "PHASE"),
        "MAIN_DETECTOR_PHASE_LOCKED": 0,
        "MAIN_FREQ_LOCK_COUNT": 50,
        "MAIN_PHASE_LOCK_COUNT": phase_count,
        "MAIN_FREQ_THRESHOLD": 50,
        "MAIN_FREQ_LOCK_SAMPLES": 50,
        "MAIN_PHASE_THRESHOLD": 1200,
        "MAIN_PHASE_LOCK_SAMPLES": 1000,
        "MAIN_PHASE_INPUT_DOMAIN": phase_domain,
        "MAIN_PHASE_INBAND": phase_inband,
        "MAIN_PI_X": 100 if phase_inband else 2000,
        "MAIN_PI_UNCLAMPED": 10,
        "MAIN_PI_OUTPUT": 10,
        "MAIN_PI_CLAMP_SIDE": 0,
        "MAIN_PI_KP": 300,
        "MAIN_PI_KI": 1,
        "MAIN_PI_SHIFT": 8,
        "MAIN_PI_BIAS": 0,
        "L2_VALID": 1,
        "L2_MAIN_PENDING": 0,
        "L2_HELPER_PENDING": 0,
        "L2_MAIN_PENDING_COUNT": 10,
        "L2_HELPER_PENDING_COUNT": 20,
        "L2_MAIN_START_COUNT": 10,
        "L2_HELPER_START_COUNT": 20,
        "L2_MAIN_COMPLETED_COUNT": 10,
        "L2_HELPER_COMPLETED_COUNT": 20,
        "L2_MAIN_FAILED": 0,
        "L2_HELPER_FAILED": 0,
        "HELPER_MEASUREMENT_OK": 1,
        "HELPER_LOCKED": helper_locked,
        "HELPER_ERROR": 2,
        "HELPER_OUTPUT": helper_output,
        "HELPER_RESIDUAL_PRESENT": 1,
        "HELPER_MEASUREMENT_RESIDUAL_PRESENT": 0,
        "BOOT_GENERATION": generation,
        "CPU_RESET": 0,
        "WR_CORE_RESET": 0,
        "SI_CONFIG_DROP": 0,
        "RESET_FIELDS_VALID": 1,
        "STOP_REASON": "NONE",
    }
    values.update(extra)
    return "STEP5_F4C_MAIN_PHASE_SAMPLE " + " ".join(
        f"{key}={value}" for key, value in values.items()
    )


class Step5F4CReplayTests(unittest.TestCase):
    def test_publication_can_advance_while_sample_n_is_stale(self) -> None:
        text = "\n".join([
            f4c_sample(elapsed_ms=0, sample_n=100, main_advanced=0),
            f4c_sample(elapsed_ms=100, sample_n=100, main_advanced=0),
            f4c_sample(elapsed_ms=200, sample_n=103),
            f4c_sample(elapsed_ms=300, sample_n=107),
            "STEP5_F4C_TRANSPORT_GATE VALID=1",
            "STEP5_F4C_SUMMARY STOP_REASON=NONE RUN_END_REASON=TARGET_REACHED",
        ])
        result = step5_f4c_replay.analyze_text(text)
        self.assertEqual(result["publication_new_producer_stale"], 1)
        self.assertEqual(result["main_sample_n_delta_sum"], 7)
        self.assertEqual(result["main_sample_n_positive_delta_samples"], 2)
        self.assertFalse(result["step5_pass"])

    def test_invalid_sample_breaks_counter_adjacency(self) -> None:
        text = "\n".join([
            f4c_sample(elapsed_ms=0, sample_n=100),
            f4c_sample(elapsed_ms=100, sample_n=101, detector_valid=0, trace_valid=0),
            f4c_sample(elapsed_ms=200, sample_n=150),
            f4c_sample(elapsed_ms=300, sample_n=151),
        ])
        result = step5_f4c_replay.analyze_text(text)
        self.assertEqual(result["main_sample_n_delta_sum"], 1)
        self.assertEqual(result["main_sample_n_delta_samples"], 1)

    def test_large_modulo_delta_is_ambiguous_and_not_progress(self) -> None:
        text = "\n".join([
            f4c_sample(elapsed_ms=0, sample_n=100),
            f4c_sample(elapsed_ms=100, sample_n=0),
            f4c_sample(elapsed_ms=200, sample_n=5),
        ])
        result = step5_f4c_replay.analyze_text(text)
        self.assertEqual(result["main_sample_n_delta_ambiguous"], 1)
        self.assertEqual(result["main_sample_n_delta_sum"], 5)
        self.assertEqual(result["main_sample_n_delta_samples"], 1)
        self.assertFalse(result["step5_pass"])

    def test_phase_count_does_not_bridge_invalid_frame(self) -> None:
        text = "\n".join([
            f4c_sample(elapsed_ms=0, sample_n=100, phase_count=10),
            f4c_sample(elapsed_ms=100, sample_n=101, phase_count=11, detector_valid=0, trace_valid=0),
            f4c_sample(elapsed_ms=200, sample_n=102, phase_count=20),
        ])
        result = step5_f4c_replay.analyze_text(text)
        self.assertEqual(result["main_phase_count"]["increase_events"], 0)

    def test_helper_unlock_and_rail_are_guardrails(self) -> None:
        text = "\n".join([
            f4c_sample(elapsed_ms=0, sample_n=100, helper_locked=0, helper_output=5),
            f4c_sample(elapsed_ms=100, sample_n=101, helper_locked=0, helper_output=5),
            f4c_sample(elapsed_ms=200, sample_n=102, helper_locked=0, helper_output=65531),
        ])
        result = step5_f4c_replay.analyze_text(text)
        self.assertEqual(result["helper_unlock_max_consecutive"], 3)
        self.assertEqual(result["helper_rail_max_consecutive"], 3)

    def test_config_and_target_are_not_step5_pass(self) -> None:
        text = "\n".join([
            "STEP5_F4C_CONFIG target_duration_ms=120000 hard_duration_ms=130000 run_role=smoke",
            f4c_sample(elapsed_ms=0, sample_n=100, main_advanced=0),
            f4c_sample(elapsed_ms=100, sample_n=101),
            f4c_sample(elapsed_ms=200, sample_n=102),
            f4c_sample(elapsed_ms=300, sample_n=103),
            f4c_sample(elapsed_ms=400, sample_n=104),
            "STEP5_F4C_TRANSPORT_GATE VALID=1",
            "STEP5_F4C_SUMMARY RUN_ROLE=smoke TARGET_DURATION_MS=120000 HARD_DURATION_MS=130000 RUN_END_REASON=TARGET_REACHED STOP_REASON=NONE F4C_DATA_QUALITY=PASS F4C_DIAGNOSTIC_RESULT=PASS",
        ])
        result = step5_f4c_replay.analyze_text(text)
        self.assertTrue(result["config_present"])
        self.assertEqual(result["f4c_diagnostic_result"], "PASS")
        self.assertFalse(result["step5_pass"])


if __name__ == "__main__":
    unittest.main()
