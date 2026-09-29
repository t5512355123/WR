from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


EXPERIMENT = Path(__file__).resolve().parents[1]
ANALYZER_PATH = EXPERIMENT / "analysis" / "analyze_phase_context.py"
OBSERVER_PATH = EXPERIMENT.parents[2] / "scripts" / "jtag" / "read_step6_servo_interleaved_offset.tcl"
SPEC = importlib.util.spec_from_file_location("phase_context", ANALYZER_PATH)
assert SPEC and SPEC.loader
ANALYZER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ANALYZER)


def row(sample: int, ucnt: int, dms: int, setp: int, cko: int,
        state: int = 5, frame: int = 1) -> str:
    return (
        "S6_INTERLEAVED_SAMPLE "
        f"board=DE5_1-11.2 sample={sample:04d} elapsed_ms={sample * 200} "
        "row_ms=190.0 READS_VALID=1 COHERENT=1 DIAG_FRAME_VALID="
        f"{frame} PHASE_CONTEXT=2 PHASE_CONTEXT_VALID=1 "
        f"PHASE_CONTEXT_FRAME_VALID={frame} PHASE_CONTEXT_MATCH=1 "
        f"PHASE_CONTEXT_UCNT=0x{ucnt:08X} "
        f"UCNT=0x{ucnt:08X} SERVO_STATE={state} CKO_PS={cko} "
        f"DMS_PS={dms} SETP_PS={setp} GLOBAL_TIME_VALID=1 "
        "HELPER_LOCK=1 MAIN_LOCK=1 MAIN_FREQ_LOCK=1 "
        "MAIN_PHASE_LOCK=1 PSTAT_LOCK=1"
    )


class PhaseContextTests(unittest.TestCase):
    def test_counts_state_groups_and_only_one_step_counter_pairs(self) -> None:
        lines = [
            "S6_INTERLEAVED_CONFIG duration_ms=300000 sample_ms=1 board_filter=1-11.2 phase_context=2",
            row(0, 1, 1000, 20, 80),
            row(1, 2, 1002, 30, 40, state=4),
            row(2, 2, 1002, 30, 40, state=4),
            row(3, 4, 1005, 35, -80, state=3),
            "S6_INTERLEAVED_BOARD_DONE board=DE5_1-11.2 samples=4 elapsed_ms=300000 reset_stop=0",
            "S6_INTERLEAVED_SUMMARY boards=1 rows=4 accepted=4 qualifying=0 reset_stop=0 timeout_count=0 invalid_count=0",
            "CAPTURE_PROCESS_EXIT=0",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "capture.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="capture", expected_duration_ms=300_000)
        self.assertEqual(result["verdict"], "CAPTURE_COMPLETE_DIAGNOSTIC")
        self.assertEqual(result["trusted_phase_context_rows"], 4)
        self.assertEqual(result["ucnt_one_step_pairs"], 1)
        self.assertEqual(result["ucnt_repeated_pairs"], 1)
        self.assertEqual(result["ucnt_skipped_pairs"], 1)
        self.assertEqual(result["one_step_pairs_with_setp_change"], 1)
        self.assertEqual(result["one_step_pairs_with_dms_change"], 1)
        self.assertEqual(result["servo_state_summary"]["TRACK_PHASE"]["rows"], 2)
        self.assertEqual(result["step6_gate"], "NOT_EVALUATED_BY_PHASE_CONTEXT_DIAGNOSTIC")

    def test_crossed_frame_is_excluded_from_correlations(self) -> None:
        lines = [
            "S6_INTERLEAVED_CONFIG duration_ms=300000 phase_context=2",
            row(0, 1, 1000, 20, 80),
            row(1, 2, 1200, 50, -20, frame=0),
            row(2, 3, 1001, 21, 40),
            "S6_INTERLEAVED_BOARD_DONE elapsed_ms=300000 reset_stop=0",
            "S6_INTERLEAVED_SUMMARY timeout_count=0 invalid_count=0 reset_stop=0",
            "CAPTURE_PROCESS_EXIT=0",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "crossed.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="capture", expected_duration_ms=300_000)
        self.assertEqual(result["trusted_phase_context_rows"], 2)
        self.assertEqual(result["ucnt_one_step_pairs"], 0)

    def test_context_ucnt_mismatch_excludes_joined_row(self) -> None:
        lines = [
            "S6_INTERLEAVED_CONFIG duration_ms=300000 phase_context=2",
            row(0, 1, 1000, 20, 80),
            row(1, 2, 1001, 21, 40).replace(
                "PHASE_CONTEXT_UCNT=0x00000002", "PHASE_CONTEXT_UCNT=0x00000003"
            ),
            "S6_INTERLEAVED_BOARD_DONE elapsed_ms=300000 reset_stop=0",
            "S6_INTERLEAVED_SUMMARY timeout_count=0 invalid_count=0 reset_stop=0",
            "CAPTURE_PROCESS_EXIT=0",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ucnt_mismatch.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="capture", expected_duration_ms=300_000)
        self.assertEqual(result["trusted_phase_context_rows"], 1)
        self.assertEqual(result["phase_context_update_match_rows"], 1)

    def test_smoke_gate_uses_planned_context_floor_latency_and_live_flags(self) -> None:
        samples = []
        for sample in range(20):
            line = row(sample, sample + 1, 1000 + sample, 20 + sample, 80)
            line = line.replace("row_ms=190.0", "row_ms=300.0")
            if sample >= 15:
                line = line.replace("PHASE_CONTEXT_MATCH=1", "PHASE_CONTEXT_MATCH=0")
            samples.append(line)
        lines = [
            "S6_INTERLEAVED_CONFIG duration_ms=15000 sample_ms=1 board_filter=1-11.2 phase_context=2",
            *samples,
            "S6_INTERLEAVED_BOARD_DONE board=DE5_1-11.2 samples=20 elapsed_ms=15000 reset_stop=0 invalid_streak=0",
            "S6_INTERLEAVED_SUMMARY boards=1 rows=20 accepted=15 qualifying=0 reset_stop=0 timeout_count=0 invalid_count=0",
            "CAPTURE_PROCESS_EXIT=0",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "smoke.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="smoke", expected_duration_ms=15_000)
        self.assertEqual(result["verdict"], "SMOKE_PASS")
        self.assertEqual(result["trusted_phase_context_rows"], 15)
        self.assertEqual(result["live_gate_rows_any_context_status"], 20)
        self.assertTrue(result["all_rows_live_gates"])
        self.assertEqual(result["median_row_duration_ms"], 300.0)

    def test_smoke_gate_fails_if_any_row_loses_a_live_lock(self) -> None:
        samples = [row(sample, sample + 1, 1000 + sample, 20 + sample, 80)
                   for sample in range(20)]
        samples[2] = samples[2].replace("PSTAT_LOCK=1", "PSTAT_LOCK=0")
        lines = [
            "S6_INTERLEAVED_CONFIG duration_ms=15000 sample_ms=1 board_filter=1-11.2 phase_context=2",
            *samples,
            "S6_INTERLEAVED_BOARD_DONE board=DE5_1-11.2 samples=20 elapsed_ms=15000 reset_stop=0 invalid_streak=0",
            "S6_INTERLEAVED_SUMMARY boards=1 rows=20 accepted=20 qualifying=0 reset_stop=0 timeout_count=0 invalid_count=0",
            "CAPTURE_PROCESS_EXIT=0",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "live_gate_failure.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="smoke", expected_duration_ms=15_000)
        self.assertEqual(result["verdict"], "SMOKE_FAIL")
        self.assertEqual(result["live_gate_rows_any_context_status"], 19)
        self.assertFalse(result["all_rows_live_gates"])

    def test_observer_reads_phase_context_inside_optional_epoch_guard(self) -> None:
        source = OBSERVER_PATH.read_text(encoding="utf-8")
        capture = source.split("proc s6_i_capture", maxsplit=1)[1].split(
            'puts [format "S6_INTERLEAVED_CONFIG', maxsplit=1
        )[0]
        ordered = [
            "set cko_raw [wb_read 0x00100A40]",
            "set sstat_raw [wb_read 0x00100A08]",
            "set ucnt_raw [wb_read 0x00100A48]",
            "set dms_hi_raw [wb_read 0x00100A34]",
            "set dms_lo_raw [wb_read 0x00100A38]",
            "set setp_raw [wb_read 0x00100A44]",
            "set diag_epoch_after_raw [wb_read 0x00100B34]",
        ]
        offsets = [capture.index(token) for token in ordered]
        self.assertEqual(offsets, sorted(offsets))
        self.assertIn("set phase_context 0", source)
        self.assertIn("if {$phase_context == 1}", capture)
        self.assertNotIn("wb_write ", source)

    def test_separate_context_frame_has_its_own_epoch_and_ucnt_join(self) -> None:
        source = OBSERVER_PATH.read_text(encoding="utf-8")
        context = source.split("proc s6_i_read_phase_context_frame", maxsplit=1)[1].split(
            "proc s6_i_snapshot", maxsplit=1
        )[0]
        ordered = [
            "set baseline_raw [wb_read 0x00100B34]",
            "set candidate_raw [wb_read 0x00100B34]",
            "set ctrl_before_raw [wb_read 0x00100A04]",
            "set inverse_before_raw [wb_read 0x00100B38]",
            "set context_ucnt_raw [wb_read 0x00100A48]",
            "set dms_hi_raw [wb_read 0x00100A34]",
            "set dms_lo_raw [wb_read 0x00100A38]",
            "set setp_raw [wb_read 0x00100A44]",
            "set epoch_after_raw [wb_read 0x00100B34]",
            "set ctrl_after_raw [wb_read 0x00100A04]",
        ]
        positions = [context.index(token) for token in ordered]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("$phase_context == 2", source)
        self.assertIn("$core_ucnt_word == $context_ucnt_word", source)
        self.assertNotIn("wb_write ", source)


if __name__ == "__main__":
    unittest.main()
