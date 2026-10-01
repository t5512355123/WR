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

        build = (EXP / "scripts" / "build_candidate.sh").read_text(
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
        self.assertIn('OUTPUT_REL="experiments/step6/$(basename "$EXP_DIR")/output"', build)
        self.assertIn('cp -- "$BUILD_SOURCE_DIR/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof" "$SLAVE_SOF_OUTPUT"', build)
        self.assertIn('cp -- "$BUILD_SOURCE_DIR/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof" "$MASTER_SOF_OUTPUT"', build)
        self.assertIn('test -s "$SLAVE_SOF_OUTPUT"', build)
        self.assertIn('test -s "$MASTER_SOF_OUTPUT"', build)
        self.assertIn('SOF_OUTPUT_PERSISTENCE=PASS', build)
        self.assertIn('S6TV_BUILD_COMPLETE', build)
        self.assertNotIn('"$QUARTUS_BIN/quartus_pgm"', build)
        self.assertNotIn('program_slave.sh', build)
        self.assertNotIn('program_master.sh', build)
        self.assertNotIn('sudo ', build)
        self.assertNotIn("EXPECTED_SLAVE_SOF=", build)
        self.assertNotIn("EXPECTED_MASTER_SOF=", build)
        self.assertIn("SOURCE_MANIFEST_RESTORED=PASS", build)
        self.assertIn("ARTIFACT_MANIFEST_RESTORED=PASS", build)
        self.assertIn("EXTERNAL_UNTRACKED_PATHS_PRESERVED", build)
        self.assertIn('git -C "$ROOT" worktree remove --force "$BUILD_ROOT"', build)

    def test_program_phase_uses_only_retained_sofs_and_rechecks_their_hashes(self):
        program = (EXP / "scripts" / "program_candidate.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('Usage: bash program_candidate.sh EXPECTED_CURRENT_COMMIT BUILD_RUN_TAG', program)
        self.assertIn('OUTPUT_REL="$EXP_REL/output"', program)
        self.assertIn('test -s "$SLAVE_SOF"', program)
        self.assertIn('test -s "$MASTER_SOF"', program)
        self.assertIn('BUILD_HEAD_RECORD="$RAW_DIR/preflight/$BUILD_RUN_TAG-current-head.txt"', program)
        self.assertIn('PROGRAM_RUN_RECORD="$BUILD_DIR/$BUILD_RUN_TAG-program-run.txt"', program)
        self.assertIn('SOFs were built from a different checkout commit', program)
        self.assertIn('actual_hash=$(sha256sum "$ROOT/$sof_rel"', program)
        self.assertIn('CABLE=\'DE5 [1-11.2]\'', program)
        self.assertIn('CABLE=\'DE5 [1-11.1]\'', program)
        self.assertLess(program.index('bash scripts/program/program_slave.sh'), program.index('bash scripts/program/program_master.sh'))
        self.assertIn('S6TV_PROGRAM_COMPLETE', program)
        self.assertNotIn('bash scripts/build/', program)

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
        self.assertIn("grep -q '^FITTER_STATUS=Fitter Status : Successful'", capture)
        self.assertIn('grep -Fxc "$sof_hash  $sof_path"', capture)
        self.assertIn('EXP_REL="experiments/step6/$(basename "$EXP_DIR")"', capture)
        self.assertIn('OUTPUT_REL="$EXP_REL/output"', capture)
        self.assertIn('BUILD checkout identity record is missing', capture)
        self.assertIn('PROGRAM_RUN_RECORD="$BUILD_DIR/$BUILD_RUN_TAG-program-run.txt"', capture)
        self.assertIn('PROGRAM_RUN_TAG=$(sed -n \'s/^PROGRAM_RUN_TAG=//p\' "$PROGRAM_RUN_RECORD")', capture)
        self.assertIn('"$PROGRAM_DIR/$PROGRAM_RUN_TAG-slave-program.log"', capture)
        self.assertIn('"$PROGRAM_DIR/$PROGRAM_RUN_TAG-master-program.log"', capture)
        self.assertIn('test -s "$ROOT/$sof_path"', capture)
        self.assertIn('actual_sof_hash=$(sha256sum "$ROOT/$sof_path"', capture)
        self.assertIn('"$OUTPUT_REL/$BUILD_RUN_TAG/DE5a_wr_slave_jtag.sof"', capture)
        self.assertIn('"$OUTPUT_REL/$BUILD_RUN_TAG/DE5a_wr_master_jtag.sof"', capture)
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

    def test_current_status_records_two_passes_and_reproducibility(self):
        status = (ROOT / "STATUS.md").read_text(encoding="utf-8")
        plan = (EXP / "PLAN.md").read_text(encoding="utf-8")
        report = (EXP / "REPORT.md").read_text(encoding="utf-8")
        self.assertIn("**PASS — two independent fresh same-source build/program runs", status)
        self.assertIn("supports repeatability of the sampled-bit criterion", status)
        self.assertIn("REPEAT-ACQ2-TRACK12-20261001/PLAN.md", status)
        self.assertIn("959/959", plan)
        self.assertIn("299,998 ms", plan)
        self.assertIn("STEP6_TIME_VALID_300S_BOTH_BOARDS = PASS", report)
        self.assertIn("DUAL_BOARD_303S_CAPTURE           = PASS", report)
        self.assertIn("QUALIFYING_FRESH_RUNS              = 2", report)
        self.assertIn("REPRODUCIBILITY                    = PASS_ACROSS_TWO_FRESH_BUILDS", report)
        self.assertIn("20261001T112327Z", report)
        self.assertIn("20261001T114109Z", report)
        self.assertIn("302,887 ms", report)
        self.assertIn("302,880 ms", report)

    def test_operator_plan_has_three_separate_phases_and_retained_output(self):
        plan = (EXP / "PLAN.md").read_text(encoding="utf-8")
        build = (EXP / "scripts" / "build_candidate.sh").read_text(
            encoding="utf-8"
        )
        program = (EXP / "scripts" / "program_candidate.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("scripts/build_candidate.sh EXPECTED_CURRENT_COMMIT", plan)
        self.assertIn("scripts/program_candidate.sh EXPECTED_CURRENT_COMMIT BUILD_RUN_TAG", plan)
        self.assertIn("scripts/monitor/step1_6_dashboard.sh", plan)
        self.assertIn("output/BUILD_RUN_TAG/DE5a_wr_slave_jtag.sof", plan)
        self.assertIn("output/BUILD_RUN_TAG/DE5a_wr_master_jtag.sof", plan)
        self.assertIn("S6TV_BUILD_COMPLETE", build)
        self.assertIn("S6TV_PROGRAM_COMPLETE", program)


if __name__ == "__main__":
    unittest.main()
