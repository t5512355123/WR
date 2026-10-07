#!/usr/bin/env python3
"""Offline contract/model checks for the half-acquisition/eighth-tracking candidate."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT = (
    ROOT
    / "experiments"
    / "step6"
    / "EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-EIGHTH-20260930"
)
PATCH = EXPERIMENT / "candidate.patch"
SOURCE_PATH = (
    "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/"
    "proto-ext-common/wrh-servo.c"
)
OBSERVED_GAIN_PAIRS = (
    (-2757, -2757, 2654),
    (2617, 2617, -2639),
)


class ServoAcquireHalfTrackEighthTests(unittest.TestCase):
    def test_candidate_changes_only_the_two_declared_phase_steps(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn(f"diff --git a/{SOURCE_PATH} b/{SOURCE_PATH}", patch)
        self.assertEqual(patch.count("-\t\ts->cur_setpoint_ps += offset_ps;"), 1)
        self.assertEqual(
            patch.count("+\t\ts->cur_setpoint_ps += (offset_ps / 2);"), 1
        )
        self.assertEqual(
            patch.count("-\t\t\ts->cur_setpoint_ps += (offset_ps / 4);"), 1
        )
        self.assertEqual(
            patch.count("+\t\t\ts->cur_setpoint_ps += (offset_ps / 8);"), 1
        )
        self.assertNotIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD", patch)
        self.assertNotIn("timeout", patch.lower())
        self.assertNotIn("threshold", patch.lower())

    def test_half_acquisition_step_enters_60ps_band_in_measured_local_model(self):
        for before, setpoint_delta, after in OBSERVED_GAIN_PAIRS:
            measured_gain = (after - before) / setpoint_delta
            self.assertGreater(measured_gain, -2.1)
            self.assertLess(measured_gain, -1.9)
            # C signed integer division truncates toward zero.
            half_step = int(before / 2)
            predicted = round(before + measured_gain * half_step)
            self.assertLess(abs(predicted), 60)


if __name__ == "__main__":
    unittest.main()
