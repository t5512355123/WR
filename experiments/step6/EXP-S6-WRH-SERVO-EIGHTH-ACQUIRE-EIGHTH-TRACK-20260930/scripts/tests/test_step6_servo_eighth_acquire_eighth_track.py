from __future__ import annotations

from pathlib import Path
import unittest


EXPERIMENT = Path(__file__).resolve().parents[2]
ROOT = EXPERIMENT.parents[2]
PATCH = EXPERIMENT / "candidate.patch"
SOURCE_PATH = (
    "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/"
    "proto-ext-common/wrh-servo.c"
)


class EighthAcquireEighthTrackTests(unittest.TestCase):
    def test_patch_changes_acquire_and_track_to_eighth_step(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn(f"diff --git a/{SOURCE_PATH} b/{SOURCE_PATH}", patch)
        self.assertEqual(patch.count("-\t\ts->cur_setpoint_ps += offset_ps;"), 1)
        self.assertEqual(
            patch.count("+\t\ts->cur_setpoint_ps += (offset_ps / 8);"), 1
        )
        self.assertEqual(
            patch.count("-\t\t\ts->cur_setpoint_ps += (offset_ps / 4);"), 1
        )
        self.assertEqual(
            patch.count("+\t\t\ts->cur_setpoint_ps += (offset_ps / 8);"), 1
        )
        self.assertNotIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD", patch)

    def test_eighth_step_damps_against_source_audited_actuator_model(self):
        for initial_error in range(-20000, 20001):
            if abs(initial_error) < 60:
                continue
            error = initial_error
            for _ in range(128):
                step = int(error / 8)  # C integer division truncates toward zero.
                next_error = error - 2 * step  # Measured response is ~ -2:1.
                self.assertLess(abs(next_error), abs(error))
                self.assertTrue(next_error == 0 or (next_error > 0) == (error > 0))
                error = next_error
                if abs(error) < 60:
                    break
            self.assertLess(abs(error), 60)

    def test_only_acquisition_changes_relative_to_previous_candidate(self):
        previous = (
            ROOT
            / "experiments"
            / "step6"
            / "EXP-S6-WRH-SERVO-QUARTER-ACQUIRE-EIGHTH-TRACK-20260930"
            / "candidate.patch"
        ).read_text(encoding="utf-8")
        self.assertIn("s->cur_setpoint_ps += (offset_ps / 4);", previous)
        self.assertIn("s->cur_setpoint_ps += (offset_ps / 8);", previous)
        source = (ROOT / Path(SOURCE_PATH)).read_text(encoding="utf-8")
        self.assertIn("s->cur_setpoint_ps += offset_ps;", source)
        self.assertIn("2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD", source)


if __name__ == "__main__":
    unittest.main()
