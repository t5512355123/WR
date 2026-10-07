#!/usr/bin/env python3
"""Offline tests for clearing stale WAIT misses on successful TRACK entry."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT = ROOT / "experiments/step6/EXP-S6-WRH-SERVO-WAIT-COUNTER-RESET-ON-LOCK-20260930"
PATCH = EXPERIMENT / "candidate.patch"
RUNNER = EXPERIMENT / "scripts" / "build_program_candidate.sh"
SOURCE_PATH = "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"
PREVIOUS_PATCH = ROOT / "experiments" / "step6" / "EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-TWELFTH-20260930" / "candidate.patch"

def model_wait_transition(missed_iters: int, remaining_offset_ps: int, threshold_ps: int = 60):
    """Model only the documented WAIT transition and retry counter semantics."""
    if remaining_offset_ps < threshold_ps:
        return "TRACK_PHASE", 0
    missed_iters += 1
    if missed_iters >= 10:
        return "SYNC_PHASE", 0
    return "WAIT_OFFSET_STABLE", missed_iters

class WaitCounterResetTests(unittest.TestCase):
    @staticmethod
    def added_lines(patch: str):
        return {line[1:] for line in patch.splitlines() if line.startswith("+") and not line.startswith("+++")}

    @staticmethod
    def removed_lines(patch: str):
        return {line[1:] for line in patch.splitlines() if line.startswith("-") and not line.startswith("---")}

    def test_candidate_patch_preserves_known_servo_gains_and_adds_one_reset(self):
        patch = PATCH.read_text(encoding="utf-8")
        previous = PREVIOUS_PATCH.read_text(encoding="utf-8")
        self.assertIn(f"diff --git a/{SOURCE_PATH} b/{SOURCE_PATH}", patch)
        self.assertEqual(patch.count("+\t\ts->cur_setpoint_ps += (offset_ps / 2);"), 1)
        self.assertEqual(patch.count("+\t\t\ts->cur_setpoint_ps += (offset_ps / 12);"), 1)
        self.assertEqual(patch.count("+\t\t\ts->missed_iters = 0;"), 1)
        self.assertEqual(self.added_lines(patch) - self.added_lines(previous), {"\t\t\ts->missed_iters = 0;"})
        self.assertEqual(self.removed_lines(patch), self.removed_lines(previous))
        self.assertNotIn("4 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD", patch)
        self.assertNotIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD 60", patch)

    def test_successful_entry_clears_previous_wait_misses(self):
        self.assertEqual(model_wait_transition(9, 20), ("TRACK_PHASE", 0))
        self.assertEqual(model_wait_transition(4, 59), ("TRACK_PHASE", 0))

    def test_failed_wait_retries_remain_at_ten_and_strict_threshold(self):
        self.assertEqual(model_wait_transition(8, 60), ("WAIT_OFFSET_STABLE", 9))
        self.assertEqual(model_wait_transition(9, 60), ("SYNC_PHASE", 0))
        self.assertEqual(model_wait_transition(9, 61), ("SYNC_PHASE", 0))

    def test_runner_keeps_exact_commit_and_restoration_gates(self):
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

if __name__ == "__main__":
    unittest.main()
