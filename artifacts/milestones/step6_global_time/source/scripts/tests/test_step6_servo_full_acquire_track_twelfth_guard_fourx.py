#!/usr/bin/env python3
"""Offline contract tests for full acquisition + /12 tracking + 4x guard."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
EXP = ROOT / "experiments/step6/EXP-S6-WRH-SERVO-FULL-ACQUIRE-TRACK-TWELFTH-GUARD-FOURX-20260930"
PREVIOUS = ROOT / "experiments/step6/EXP-S6-WRH-SERVO-ACQUIRE-FULL-TRACK-TWELFTH-20260930/candidate.patch"
SOURCE = ROOT / "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"
PATCH = EXP / "candidate.patch"
RUNNER = EXP / "scripts/build_program_candidate.sh"


class FullAcquireTrackTwelfthGuardFourXTests(unittest.TestCase):
    @staticmethod
    def changed_lines(patch: str):
        return [line for line in patch.splitlines() if line.startswith(("+", "-")) and not line.startswith(("+++", "---"))]

    def test_candidate_keeps_full_acquire_and_twelfth_tracking(self):
        source = SOURCE.read_text(encoding="utf-8")
        sync = source.split("case WRH_SYNC_PHASE:", 1)[1].split("case WRH_WAIT_OFFSET_STABLE:", 1)[0]
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("s->cur_setpoint_ps += offset_ps;", sync)
        self.assertNotIn("offset_ps / 2", sync)
        self.assertIn("s->cur_setpoint_ps += (offset_ps / 12);", patch)
        self.assertNotIn("missed_iters", patch)

    def test_only_new_functional_delta_vs_previous_candidate_is_guard_2x_to_4x(self):
        previous = PREVIOUS.read_text(encoding="utf-8")
        current = PATCH.read_text(encoding="utf-8")
        old_added = {line[1:] for line in previous.splitlines() if line.startswith("+") and not line.startswith("+++")}
        new_added = {line[1:] for line in current.splitlines() if line.startswith("+") and not line.startswith("+++")}
        old_removed = {line[1:] for line in previous.splitlines() if line.startswith("-") and not line.startswith("---")}
        new_removed = {line[1:] for line in current.splitlines() if line.startswith("-") and not line.startswith("---")}
        self.assertEqual(new_added - old_added, {"\t\t\t    4 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD) {"})
        self.assertEqual(new_removed - old_removed, {"\t\t\t    2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD) {"})
        self.assertEqual(self.changed_lines(previous)[-2:], [
            "-\t\t\ts->cur_setpoint_ps += (offset_ps / 4);",
            "+\t\t\ts->cur_setpoint_ps += (offset_ps / 12);",
        ])

    def test_candidate_keeps_the_60ps_threshold(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertNotIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD 240", patch)
        self.assertIn("2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD", patch)
        self.assertIn("4 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD", patch)

    def test_runner_enforces_exact_commit_and_restoration(self):
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
