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
    def test_reuses_the_historical_source_patch_and_build_identity(self):
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
        self.assertIn("EXPECTED_BUILD_COMMIT=4c1adf73ab762506939163d467fb8c6b35bca9b4", build)
        self.assertIn("EXPECTED_PATCH_SHA256=a3a69d1734ab67801bd45dd212e31879e640992ff3a0cc20fcbad3dcf0e477f4", build)
        self.assertIn('git -C "$ROOT" worktree add --detach "$BUILD_ROOT" "$EXPECTED_BUILD_COMMIT"', build)
        self.assertIn('git -C "$BUILD_ROOT" apply --check "$PATCH"', build)
        self.assertIn('git -C "$BUILD_ROOT" apply -R "$PATCH"', build)
        self.assertIn("EXPECTED_SLAVE_MIF=d6165e93f0a43bc6b2a41db8d568ab696916c1a32c1733b47d7df36b5a692916", build)
        self.assertIn("EXPECTED_MASTER_MIF=07511e0a1148dd120898b1fc53f644f265b098d52912340314dace2a8b1526f6", build)
        self.assertLess(build.index('fail "rebuilt Slave MIF hash differs'), build.index('bash scripts/build/build_master.sh'))
        self.assertIn('grep -Fx "QSF_SHA256=$EXPECTED_MASTER_QSF"', build)
        self.assertIn('grep -Fx "SDC_SHA256=$EXPECTED_SDC"', build)
        self.assertIn('grep -Fx "QUARTUS_VERSION=$EXPECTED_QUARTUS_VERSION"', build)
        self.assertIn('grep -Fx "MIF_SHA256=$EXPECTED_MASTER_MIF"', build)
        self.assertIn('grep -Fq "$MASTER_SOF_HASH  quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof"', build)
        self.assertLess(build.index('grep -Fq "$MASTER_SOF_HASH'), build.index('bash scripts/program/program_slave.sh'))
        self.assertNotIn("EXPECTED_SLAVE_SOF=", build)
        self.assertNotIn("EXPECTED_MASTER_SOF=", build)
        self.assertIn("SOURCE_MANIFEST_RESTORED=PASS", build)
        self.assertIn("ARTIFACT_MANIFEST_RESTORED=PASS", build)
        self.assertIn("CABLE='DE5 [1-11.2]'", build)
        self.assertIn("CABLE='DE5 [1-11.1]'", build)
        self.assertIn("EXTERNAL_UNTRACKED_PATHS_PRESERVED", build)
        self.assertIn('git -C "$ROOT" worktree remove --force "$BUILD_ROOT"', build)

    def test_capture_revalidates_build_metadata_and_actual_sof_records(self):
        capture = (EXP / "scripts" / "capture_300s.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("EXPECTED_BUILD_COMMIT=4c1adf73ab762506939163d467fb8c6b35bca9b4", capture)
        self.assertIn("EXPECTED_SOURCE_ORIGIN=74dc28862653d306e0450cf437ba6d3a230d979d", capture)
        self.assertIn('BUILD_DIR="$RAW_DIR/build"', capture)
        self.assertNotIn('BUILD_DIR="$RAW_DIR/build/$BUILD_RUN_TAG"', capture)
        self.assertIn("verify_build_info()", capture)
        self.assertIn('grep -Fx "QSF_SHA256=$project_qsf"', capture)
        self.assertIn('grep -Fx "MIF_SHA256=$mif_hash"', capture)
        self.assertIn('grep -Fxc "$sof_hash  $sof_path"', capture)
        self.assertNotIn("EXPECTED_SLAVE=", capture)
        self.assertNotIn("EXPECTED_MASTER=", capture)

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
        self.assertIn("ABORTED_BEFORE_PROGRAM", report)
        self.assertIn("DUAL_BOARD_303S_CAPTURE", report)


if __name__ == "__main__":
    unittest.main()
