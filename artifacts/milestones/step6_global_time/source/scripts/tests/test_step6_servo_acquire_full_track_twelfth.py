#!/usr/bin/env python3
"""Offline contract tests for source-default full acquisition + /12 tracking."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
EXP = ROOT / "experiments/step6/EXP-S6-WRH-SERVO-ACQUIRE-FULL-TRACK-TWELFTH-20260930"
SOURCE = ROOT / "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"
PATCH = EXP / "candidate.patch"
RUNNER = EXP / "scripts/build_program_candidate.sh"


class FullAcquireTrackTwelfthTests(unittest.TestCase):
    def test_patch_changes_only_track_correction_from_fourth_to_twelfth(self):
        patch = PATCH.read_text(encoding="utf-8")
        changed = [line for line in patch.splitlines() if line.startswith(("+", "-")) and not line.startswith(("+++", "---"))]
        self.assertEqual(changed, [
            "-\t\t\ts->cur_setpoint_ps += (offset_ps / 4);",
            "+\t\t\ts->cur_setpoint_ps += (offset_ps / 12);",
        ])
        self.assertNotIn("missed_iters", patch)
        self.assertNotIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD", patch)

    def test_frozen_source_retains_full_sync_phase_correction(self):
        source = SOURCE.read_text(encoding="utf-8")
        sync = source.split("case WRH_SYNC_PHASE:", 1)[1].split("case WRH_WAIT_OFFSET_STABLE:", 1)[0]
        self.assertIn("s->cur_setpoint_ps += offset_ps;", sync)
        self.assertNotIn("offset_ps / 2", sync)

    def test_patch_uses_exact_tracking_divisor(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("s->cur_setpoint_ps += (offset_ps / 12);", patch)
        self.assertIn("s->cur_setpoint_ps += (offset_ps / 4);", patch)

    def test_runner_enforces_exact_commit_and_source_restoration(self):
        runner = RUNNER.read_text(encoding="utf-8")
        for contract in (
            "EXPECTED_BRANCH=feat/file_cleanup",
            'git -C "$ROOT" apply --check "$PATCH"',
            "trap finish EXIT",
            'git -C "$ROOT" apply -R "$PATCH"',
            "SOURCE_MANIFEST_RESTORED=PASS",
            "ARTIFACT_MANIFEST_RESTORED=PASS",
            "bash ./scripts/program/program_slave.sh",
            "bash ./scripts/program/program_master.sh",
        ):
            self.assertIn(contract, runner)


if __name__ == "__main__":
    unittest.main()
