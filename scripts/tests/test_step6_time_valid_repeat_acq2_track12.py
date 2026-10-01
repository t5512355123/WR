#!/usr/bin/env python3
"""Offline contract checks for the Step 6 303-second /2+/12 reproduction."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
EXP = ROOT / "experiments" / "step6" / (
    "EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001"
)
HISTORICAL = ROOT / "experiments" / "step6" / (
    "EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-TWELFTH-20260930"
)


class TimeValidRepeatTests(unittest.TestCase):
    def test_reuses_the_historically_exercised_patch_and_sof_hashes(self):
        patch = (HISTORICAL / "candidate.patch").read_text(encoding="utf-8")
        source_path = (
            "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/"
            "ppsi/proto-ext-common/wrh-servo.c"
        )
        self.assertIn(f"diff --git a/{source_path} b/{source_path}", patch)
        self.assertIn("+\t\ts->cur_setpoint_ps += (offset_ps / 2);", patch)
        self.assertIn("+\t\t\ts->cur_setpoint_ps += (offset_ps / 12);", patch)

        build = (EXP / "scripts" / "build_program_candidate.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("dd5d2e72d6fcde92ace62cf51cfd7fc333c5af1d8d8dd4ebfdc8437b3bba701b", build)
        self.assertIn("2beddef2b481c96d6b94bf195fc3ea3cd87513bc776b6884cc775ee8d08f763b", build)
        self.assertIn('git -C "$ROOT" apply --check "$PATCH"', build)
        self.assertIn('git -C "$ROOT" apply -R "$PATCH"', build)
        self.assertIn("SOURCE_MANIFEST_RESTORED=PASS", build)
        self.assertIn("ARTIFACT_MANIFEST_RESTORED=PASS", build)
        self.assertIn("CABLE='DE5 [1-11.2]'", build)
        self.assertIn("CABLE='DE5 [1-11.1]'", build)
        self.assertIn("EXTERNAL_UNTRACKED_PATHS_PRESERVED", build)

    def test_capture_uses_status_time_valid_and_a_longer_read_window(self):
        capture = (EXP / "scripts" / "capture_300s.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("CAPTURE_DURATION_MS=303000", capture)
        self.assertIn("SAMPLE_MS=250", capture)
        self.assertIn("READY_LIMIT_SECONDS=1800", capture)
        self.assertIn("CAPTURE_LIMIT_SECONDS=900", capture)
        self.assertIn("STATUS_TIME_VALID=1", capture)
        self.assertIn('scripts/jtag/read_step6_global_time_observability.tcl', capture)
        self.assertIn("--boards 1-11.1,1-11.2", capture)
        self.assertNotIn("phase_context", capture)
        self.assertNotIn("PST", capture)
        self.assertNotIn("04_WR_archive_step6_pass", capture)

    def test_current_status_points_to_this_repeat_and_keeps_pass_pending(self):
        status = (ROOT / "STATUS.md").read_text(encoding="utf-8")
        plan = (EXP / "PLAN.md").read_text(encoding="utf-8")
        report = (EXP / "REPORT.md").read_text(encoding="utf-8")
        self.assertIn("NOT YET REPRODUCED", status)
        self.assertIn("REPEAT-ACQ2-TRACK12-20261001/PLAN.md", status)
        self.assertIn("959/959", plan)
        self.assertIn("299,998 ms", plan)
        self.assertIn("NOT_ESTABLISHED", report)
        self.assertIn("DUAL_BOARD_303S_CAPTURE", report)


if __name__ == "__main__":
    unittest.main()
