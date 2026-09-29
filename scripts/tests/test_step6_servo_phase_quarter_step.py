#!/usr/bin/env python3
"""Offline model/source checks for the damped Step 6 WR phase acquisition."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT = (
    ROOT
    / "experiments"
    / "step6"
    / "EXP-S6-WRH-SERVO-PHASE-QUARTER-STEP-20260930"
)
PATCH = EXPERIMENT / "candidate.patch"
SOURCE_PATH = (
    "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/"
    "proto-ext-common/wrh-servo.c"
)


class ServoQuarterStepTests(unittest.TestCase):
    OBSERVED_PAIRS = (
        (-2757, 2654, -2757),
        (2617, -2639, 2617),
    )

    def test_patch_changes_only_sync_phase_acquisition_line(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn(f"diff --git a/{SOURCE_PATH} b/{SOURCE_PATH}", patch)
        self.assertEqual(patch.count("-\t\ts->cur_setpoint_ps += offset_ps;"), 1)
        self.assertEqual(
            patch.count("+\t\ts->cur_setpoint_ps += (offset_ps / 4);"), 1
        )
        self.assertNotIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD", patch)
        self.assertNotIn("offset_ps / 2", patch)

    def test_measured_gain_pairs_reject_full_step_oscillation(self):
        for before, after, setpoint_delta in self.OBSERVED_PAIRS:
            measured_gain = (after - before) / setpoint_delta
            self.assertLess(measured_gain, -1.9)
            self.assertGreater(measured_gain, -2.1)

    def test_quarter_step_contracts_each_measured_error_inside_gate(self):
        for before, after, setpoint_delta in self.OBSERVED_PAIRS:
            measured_gain = (after - before) / setpoint_delta
            error = before
            prior_magnitude = abs(error)

            for _ in range(12):
                # C signed integer division truncates toward zero.
                step = int(error / 4)
                error = round(error + measured_gain * step)
                self.assertLess(abs(error), prior_magnitude)
                prior_magnitude = abs(error)
                if abs(error) < 60:
                    break

            self.assertLess(abs(error), 60)


if __name__ == "__main__":
    unittest.main()
