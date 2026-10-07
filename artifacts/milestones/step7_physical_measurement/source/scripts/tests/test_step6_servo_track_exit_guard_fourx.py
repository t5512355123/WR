#!/usr/bin/env python3
"""Offline contract checks for /2 + /12 with a four-times TRACK exit guard."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT = ROOT / "experiments" / "step6" / "EXP-S6-WRH-SERVO-TRACK-EXIT-GUARD-FOURX-20260930"
PATCH = EXPERIMENT / "candidate.patch"
RUNNER = EXPERIMENT / "scripts" / "build_program_candidate.sh"
SOURCE_PATH = "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"

class ServoTrackExitGuardFourXTests(unittest.TestCase):
    def test_candidate_patch_has_only_declared_control_changes(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn(f"diff --git a/{SOURCE_PATH} b/{SOURCE_PATH}", patch)
        self.assertEqual(patch.count("-\t\ts->cur_setpoint_ps += offset_ps;"), 1)
        self.assertEqual(patch.count("+\t\ts->cur_setpoint_ps += (offset_ps / 2);"), 1)
        self.assertEqual(patch.count("-\t\t\t    2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD) {"), 1)
        self.assertEqual(patch.count("+\t\t\t    4 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD) {"), 1)
        self.assertEqual(patch.count("-\t\t\ts->cur_setpoint_ps += (offset_ps / 4);"), 1)
        self.assertEqual(patch.count("+\t\t\ts->cur_setpoint_ps += (offset_ps / 12);"), 1)
        self.assertNotIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD 60", patch)
        self.assertNotIn("timeout", patch.lower())
        self.assertNotIn("retry", patch.lower())

    def test_runner_requires_expected_head_and_restores_manifests(self):
        runner = RUNNER.read_text(encoding="utf-8")
        self.assertIn("EXPECTED_BRANCH=feat/file_cleanup", runner)
        self.assertIn('git -C "$ROOT" apply --check "$PATCH"', runner)
        self.assertIn("trap finish EXIT", runner)
        self.assertIn('git -C "$ROOT" apply -R "$PATCH"', runner)
        self.assertIn("SOURCE_MANIFEST_RESTORED=PASS", runner)
        self.assertIn("ARTIFACT_MANIFEST_RESTORED=PASS", runner)
        self.assertIn("bash ./firmware/scripts/build_master_firmware.sh", runner)
        self.assertIn("bash ./scripts/program/program_slave.sh", runner)
        self.assertIn("bash ./scripts/program/program_master.sh", runner)

    def test_only_track_exit_guard_changes_from_previous_candidate(self):
        previous = ROOT / "experiments" / "step6" / "EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-TWELFTH-20260930" / "candidate.patch"
        before = previous.read_text(encoding="utf-8")
        current = PATCH.read_text(encoding="utf-8")
        for line in ("+\t\ts->cur_setpoint_ps += (offset_ps / 2);", "+\t\t\ts->cur_setpoint_ps += (offset_ps / 12);"):
            self.assertIn(line, before)
            self.assertIn(line, current)
        self.assertIn("+\t\t\t    4 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD)", current)
        self.assertNotIn("4 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD", before)
        self.assertEqual(4 * 60, 240)

if __name__ == "__main__":
    unittest.main()
