from __future__ import annotations

import importlib.util
import re
import tempfile
import unittest
from pathlib import Path


EXPERIMENT = Path(__file__).resolve().parents[1]
ANALYZER_PATH = EXPERIMENT / "analysis" / "analyze_interleaved_capture.py"
OBSERVER_PATH = EXPERIMENT.parents[2] / "scripts" / "jtag" / "read_step6_servo_interleaved_offset.tcl"
SPEC = importlib.util.spec_from_file_location("interleaved_capture", ANALYZER_PATH)
assert SPEC and SPEC.loader
ANALYZER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ANALYZER)


def row(sample: int, offset: int, qualifies: int = 1, elapsed: int | None = None) -> str:
    elapsed = sample * 500 if elapsed is None else elapsed
    return (
        "2026-09-30T00:00:00Z\tS6_INTERLEAVED_SAMPLE "
        f"board=DE5_1-11.2 sample={sample:04d} elapsed_ms={elapsed} row_ms=100.0 "
        f"READS_VALID=1 COHERENT=1 QUALIFYING_SAMPLE={qualifies} "
        "DIAG_VALID_BEFORE=1 DIAG_VALID_AFTER=1 DIAG_EPOCH_BEFORE=9 "
        "DIAG_EPOCH_AFTER=9 DIAG_EPOCH_STABLE=1 DIAG_FRAME_VALID=1 "
        f"GLOBAL_TIME_VALID=1 HELPER_LOCK=1 MAIN_LOCK=1 MAIN_FREQ_LOCK=1 "
        f"MAIN_PHASE_LOCK=1 PSTAT_LOCK=1 CKO_PS={offset}"
    )


class InterleavedCaptureTests(unittest.TestCase):
    def test_observer_aligns_minimal_payload_to_new_valid_diagnostics_epoch(self) -> None:
        source = OBSERVER_PATH.read_text(encoding="utf-8")
        capture = source.split("proc s6_i_capture", maxsplit=1)[1].split("puts [format \"S6_INTERLEAVED_CONFIG", maxsplit=1)[0]
        ordered = [
            "set diag_epoch_wait_baseline_raw [wb_read 0x00100B34]",
            "set candidate_raw [wb_read 0x00100B34]",
            "set ctrl_candidate_raw [wb_read 0x00100A04]",
            "set inverse_candidate_raw [wb_read 0x00100B38]",
            "set cko_raw [wb_read 0x00100A40]",
            "set sstat_raw [wb_read 0x00100A08]",
            "set ucnt_raw [wb_read 0x00100A48]",
            "set dms_hi_raw [wb_read 0x00100A34]",
            "set dms_lo_raw [wb_read 0x00100A38]",
            "set setp_raw [wb_read 0x00100A44]",
            "set diag_epoch_after_raw [wb_read 0x00100B34]",
            "set diag_ctrl_after_raw [wb_read 0x00100A04]",
        ]
        offsets = [capture.index(item) for item in ordered]
        self.assertEqual(offsets, sorted(offsets))
        self.assertIn("set phase_context 0", source)
        self.assertIn("if {$phase_context == 1}", capture)
        self.assertIn("phase_context=%d", source)
        self.assertIn("MATCHED_UCNT_SEPARATE_FRAMES", source)
        self.assertIn("S6_INTERLEAVED_CONTEXT_CONFIG", source)
        self.assertNotIn("wb_write ", source)
        self.assertIn("wb_register_writes=0 fpga_program=0 reset=0", source)
        self.assertIn("[normalize_probe64 $snapshot1_before]", source)
        self.assertIn("[normalize_probe64 $snapshot1_after]", source)
        self.assertIn("$reads_valid && $diagnostic_frame_match && $global_valid", source)
        self.assertIn("$candidate_epoch != $diag_epoch_wait_baseline", capture)
        self.assertIn("DIAG_EPOCH_WAIT_BASELINE=%d", source)
        self.assertNotIn("last_diag_epoch", source)

    def test_step6_qualification_includes_the_full_dashboard_step1_gate(self) -> None:
        source = OBSERVER_PATH.read_text(encoding="utf-8")
        capture = source.split("proc s6_i_capture", maxsplit=1)[1].split("puts [format \"S6_INTERLEAVED_CONFIG", maxsplit=1)[0]
        required_status = [
            "set status_si_config_done [bit64_low $status 0]",
            "set status_wr_ready [bit64_low $status 1]",
            "set status_tm_link [bit64_low $status 2]",
            "set status_link_ok [bit64_low $status 3]",
            "set status_rx_ready [bit64_low $status 6]",
            "set status_tx_ready [bit64_low $status 7]",
            "set status_cpu_reset_n [bit64_low $status 15]",
            "set status_rx_locked_to_data [bit64_high $status 0]",
        ]
        for expression in required_status:
            self.assertIn(expression, capture)
        self.assertIn("$step1_gate == 1", capture)
        self.assertIn("STEP1_GATE=%d", source)

    def test_timing_format_has_one_argument_for_each_conversion(self) -> None:
        source = OBSERVER_PATH.read_text(encoding="utf-8")
        timing = source.split('puts [format "S6_INTERLEAVED_TIMING ', maxsplit=1)[1]
        format_string, argument_text = timing.split('" \\\n', maxsplit=1)
        argument_text = argument_text.split("]\n  puts [format \"S6_INTERLEAVED_CONTEXT_TIMING", maxsplit=1)[0]
        conversions = re.findall(r"%[-+0-9.]*[a-zA-Z]", format_string)
        arguments = re.findall(r"\$[A-Za-z_][A-Za-z0-9_]*", argument_text)
        self.assertEqual(len(arguments), len(conversions))

    def test_sample_format_has_one_argument_for_each_conversion(self) -> None:
        source = OBSERVER_PATH.read_text(encoding="utf-8")
        sample = source.split('puts [format "S6_INTERLEAVED_SAMPLE ', maxsplit=1)[1]
        format_string, argument_text = sample.split('" \\\n', maxsplit=1)
        argument_text = argument_text.split("]\n  flush stdout", maxsplit=1)[0]
        conversions = re.findall(r"%[-+0-9.]*[a-zA-Z]", format_string)
        arguments = re.findall(r"\$[A-Za-z_][A-Za-z0-9_]*", argument_text)
        self.assertEqual(len(arguments), len(conversions))

    def test_strict_threshold_excludes_exactly_sixty_ps(self) -> None:
        lines = [row(0, 59), row(1, -59), row(2, 60, 0), row(3, -60, 0)]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "capture.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="smoke")
        self.assertEqual(result["qualifying_rows"], 2)
        self.assertEqual(result["offset_abs_lt_60_count"], 2)
        self.assertEqual(result["verdict"], "SMOKE_FAIL")

    def test_smoke_allows_updates_crossing_within_the_documented_coherence_floor(self) -> None:
        lines = [row(i, 120, qualifies=0) for i in range(22)]
        for index in (2, 7, 12, 19):
            lines[index] = lines[index].replace("COHERENT=1", "COHERENT=0")
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "smoke.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="smoke")
        self.assertEqual(result["trusted_rows"], 18)
        self.assertEqual(result["individual_reads_valid_rows"], 22)
        self.assertEqual(result["verdict"], "SMOKE_PASS")

    def test_smoke_uses_documented_450ms_median_row_limit(self) -> None:
        lines = [
            row(i, 120, qualifies=0, elapsed=i * 300).replace("row_ms=100.0", "row_ms=300.0")
            for i in range(22)
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "smoke_300ms_rows.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="smoke")
        self.assertEqual(result["median_row_duration_ms"], 300.0)
        self.assertEqual(result["verdict"], "SMOKE_PASS")

    def test_capture_does_not_pass_when_a_sample_loses_global_time_or_lock(self) -> None:
        lines = [row(i, 10, qualifies=0 if i == 9 else 1) for i in range(600)]
        lines += [
            "S6_INTERLEAVED_BOARD_DONE board=DE5_1-11.2 samples=600 elapsed_ms=300010 reset_stop=0 invalid_streak=0",
            "S6_INTERLEAVED_SUMMARY boards=1 rows=600 accepted=600 qualifying=599 reset_stop=0 timeout_count=0 invalid_count=0",
            "CAPTURE_PROCESS_EXIT=0",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "capture.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path)
        self.assertEqual(result["verdict"], "STEP6_EXPANDED_GATE_NOT_ESTABLISHED")
        self.assertFalse(result["all_rows_step6_qualifying"])

    def test_capture_uses_observed_reader_cadence_not_requested_sleep(self) -> None:
        lines = ["S6_INTERLEAVED_CONFIG duration_ms=300000 sample_ms=1 board_filter=1-11.2"]
        lines.extend(row(i, -17, elapsed=i * 375) for i in range(800))
        lines += [
            "S6_INTERLEAVED_BOARD_DONE board=DE5_1-11.2 samples=800 elapsed_ms=300100 reset_stop=0 invalid_streak=0",
            "S6_INTERLEAVED_SUMMARY boards=1 rows=800 accepted=800 qualifying=800 reset_stop=0 timeout_count=0 invalid_count=0",
            "CAPTURE_PROCESS_EXIT=0",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "high_rate.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path)
        self.assertEqual(result["estimated_expected_rows_at_observed_cadence"], 800)
        self.assertEqual(result["capture_tail_gap_ms"], 475)
        self.assertEqual(result["verdict"], "STEP6_EXPANDED_SAMPLE_GATE_PASS")

    def test_capture_summarizes_servo_state_offsets_and_hex_update_count(self) -> None:
        lines = [
            row(0, 120).replace("CKO_PS=", "UCNT=00000010 SERVO_STATE=5 CKO_PS="),
            row(1, 20).replace("CKO_PS=", "UCNT=00000011 SERVO_STATE=5 CKO_PS="),
            row(2, -10).replace("CKO_PS=", "UCNT=00000011 SERVO_STATE=3 CKO_PS="),
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "servo_state.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="smoke")
        self.assertEqual(result["servo_state_offset_summary"]["5"]["rows"], 2)
        self.assertEqual(result["servo_state_offset_summary"]["5"]["offset_abs_lt_60_count"], 1)
        self.assertEqual(result["servo_state_offset_summary"]["3"]["offset_min_ps"], -10)
        self.assertEqual(result["ucnt_valid_rows"], 3)
        self.assertEqual(result["ucnt_changed_pairs"], 1)
        self.assertEqual(result["ucnt_unchanged_pairs"], 1)

    def test_invalid_or_crossed_diagnostics_frame_is_not_counted_as_offset_data(self) -> None:
        line = row(0, 15).replace("DIAG_FRAME_VALID=1", "DIAG_FRAME_VALID=0")
        line = line.replace("COHERENT=1", "COHERENT=0")
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "capture.log"
            path.write_text(line + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path, mode="smoke")
        self.assertEqual(result["diagnostic_frame_checked_rows"], 1)
        self.assertEqual(result["diagnostic_frame_valid_rows"], 0)
        self.assertEqual(result["offset_valid_rows"], 0)
        self.assertEqual(result["trusted_rows"], 0)

    def test_complete_qualified_samples_pass_only_the_sampled_gate(self) -> None:
        lines = [row(i, -17) for i in range(601)]
        lines[27] = lines[27].replace("COHERENT=1", "COHERENT=0")
        lines += [
            "S6_INTERLEAVED_BOARD_DONE board=DE5_1-11.2 samples=601 elapsed_ms=300400 reset_stop=0 invalid_streak=0",
            "S6_INTERLEAVED_SUMMARY boards=1 rows=601 accepted=600 qualifying=601 reset_stop=0 timeout_count=0 invalid_count=0",
            "CAPTURE_PROCESS_EXIT=0",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "capture.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path)
        self.assertEqual(result["verdict"], "STEP6_EXPANDED_SAMPLE_GATE_PASS")
        self.assertEqual(result["offset_min_ps"], -17)
        self.assertEqual(result["offset_max_ps"], -17)
        self.assertEqual(result["offset_abs_lt_60_count"], 601)
        self.assertEqual(result["trusted_rows"], 600)
        self.assertEqual(result["global_time_valid_rows"], 601)
        self.assertEqual(result["all_five_step5_locks_rows"], 601)


if __name__ == "__main__":
    unittest.main()
