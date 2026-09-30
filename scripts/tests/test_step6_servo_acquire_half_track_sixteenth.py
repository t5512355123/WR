#!/usr/bin/env python3
"""Offline patch-contract and damping-model checks for the /2 + /16 candidate."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT = (
    ROOT
    / "experiments"
    / "step6"
    / "EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-SIXTEENTH-20260930"
)
PATCH = EXPERIMENT / "candidate.patch"
RUNNER = EXPERIMENT / "scripts" / "build_program_candidate.sh"
SOURCE_PATH = (
    "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/"
    "proto-ext-common/wrh-servo.c"
)


class ServoAcquireHalfTrackSixteenthTests(unittest.TestCase):
    def test_patch_preserves_half_acquisition_and_changes_tracking_only(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn(f"diff --git a/{SOURCE_PATH} b/{SOURCE_PATH}", patch)
        self.assertEqual(patch.count("-		s->cur_setpoint_ps += offset_ps;"), 1)
        self.assertEqual(
            patch.count("+		s->cur_setpoint_ps += (offset_ps / 2);"), 1
        )
        self.assertEqual(
            patch.count("-			s->cur_setpoint_ps += (offset_ps / 4);"), 1
        )
        self.assertEqual(
            patch.count("+			s->cur_setpoint_ps += (offset_ps / 16);"), 1
        )
        self.assertNotIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD", patch)
        self.assertNotIn("timeout", patch.lower())
        self.assertNotIn("threshold", patch.lower())

    def test_remote_runner_guards_inputs_and_restores_frozen_source(self):
        runner = RUNNER.read_text(encoding="utf-8")
        self.assertIn("EXPECTED_BRANCH=feat/file_cleanup", runner)
        self.assertIn('git -C "$ROOT" apply --check "$PATCH"', runner)
        self.assertIn("trap finish EXIT", runner)
        self.assertIn('git -C "$ROOT" apply -R "$PATCH"', runner)
        self.assertIn("SOURCE_MANIFEST_RESTORED=PASS", runner)
        self.assertIn("ARTIFACT_MANIFEST_RESTORED=PASS", runner)

    def test_sixteenth_step_is_less_aggressive_without_claiming_a_pass(self):
        for measured_gain in (-2.008, -1.964):
            residual_fraction = 1 + measured_gain / 16
            eighth_residual_fraction = 1 + measured_gain / 8
            self.assertGreater(residual_fraction, 0)
            self.assertLess(residual_fraction, 1)
            self.assertGreater(residual_fraction, eighth_residual_fraction)
            self.assertLess(abs(measured_gain / 16), abs(measured_gain / 8))


if __name__ == "__main__":
    unittest.main()
