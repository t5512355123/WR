#!/usr/bin/env python3
"""Offline patch-contract and damping-model checks for the /2 + /12 candidate."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT = (
    ROOT
    / "experiments"
    / "step6"
    / "EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-TWELFTH-20260930"
)
PATCH = EXPERIMENT / "candidate.patch"
RUNNER = EXPERIMENT / "scripts" / "build_program_candidate.sh"
SOURCE_PATH = (
    "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/"
    "proto-ext-common/wrh-servo.c"
)


class ServoAcquireHalfTrackTwelfthTests(unittest.TestCase):
    def test_patch_preserves_half_acquisition_and_changes_tracking_only(self):
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
            patch.count("+\t\t\ts->cur_setpoint_ps += (offset_ps / 12);"), 1
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
        self.assertIn("bash ./firmware/scripts/build_master_firmware.sh", runner)
        self.assertIn("bash ./scripts/program/program_slave.sh", runner)

    def test_twelfth_step_interpolates_between_eighth_and_sixteenth(self):
        for measured_gain in (-2.008, -1.964):
            eighth = 1 + measured_gain / 8
            twelfth = 1 + measured_gain / 12
            sixteenth = 1 + measured_gain / 16
            self.assertGreater(eighth, 0)
            self.assertLess(eighth, twelfth)
            self.assertLess(twelfth, sixteenth)
            self.assertLess(sixteenth, 1)
            self.assertGreater(abs(measured_gain / 8), abs(measured_gain / 12))
            self.assertGreater(abs(measured_gain / 12), abs(measured_gain / 16))


if __name__ == "__main__":
    unittest.main()
