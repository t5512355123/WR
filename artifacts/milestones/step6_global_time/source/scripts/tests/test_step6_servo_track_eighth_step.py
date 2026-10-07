#!/usr/bin/env python3
"""Offline checks for the isolated Step 6 eighth-step tracking candidate."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT = (
    ROOT
    / "experiments"
    / "step6"
    / "EXP-S6-WRH-SERVO-TRACKING-EIGHTH-STEP-20260930"
)
PATCH = EXPERIMENT / "candidate.patch"
SOURCE_PATH = (
    "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/"
    "proto-ext-common/wrh-servo.c"
)


class ServoTrackingEighthStepTests(unittest.TestCase):
    OBSERVED_PAIRS = (
        (-2757, 2654, -2757),
        (2617, -2639, 2617),
    )

    def test_patch_keeps_quarter_acquisition_and_changes_only_tracking_step(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn(f"diff --git a/{SOURCE_PATH} b/{SOURCE_PATH}", patch)
        self.assertEqual(patch.count("-\t\ts->cur_setpoint_ps += offset_ps;"), 1)
        self.assertEqual(
            patch.count("+\t\ts->cur_setpoint_ps += (offset_ps / 4);"), 1
        )
        self.assertEqual(
            patch.count("-\t\t\ts->cur_setpoint_ps += (offset_ps / 4);"), 1
        )
        self.assertEqual(
            patch.count("+\t\t\ts->cur_setpoint_ps += (offset_ps / 8);"), 1
        )
        self.assertNotIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD", patch)
        self.assertNotIn("offset_ps / 16", patch)

    def test_eighth_step_contracts_measured_local_gain_model_without_reversal(self):
        for before, after, setpoint_delta in self.OBSERVED_PAIRS:
            measured_gain = (after - before) / setpoint_delta
            self.assertLess(measured_gain, -1.9)
            self.assertGreater(measured_gain, -2.1)

            error = before
            prior_sign = 1 if error > 0 else -1
            for _ in range(24):
                # Match C's signed integer division: truncation toward zero.
                step = int(error / 8)
                error = round(error + measured_gain * step)
                if abs(error) <= 8:
                    break
                self.assertGreater(error * prior_sign, 0)
                prior_sign = 1 if error > 0 else -1

            self.assertLess(abs(error), 60)


if __name__ == "__main__":
    unittest.main()
