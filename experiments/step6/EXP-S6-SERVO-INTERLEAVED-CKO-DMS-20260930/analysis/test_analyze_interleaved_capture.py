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
    def test_observer_frames_minimal_offset_state_update_payload(self) -> None:
        source = OBSERVER_PATH.read_text(encoding="utf-8")
        capture = source.split("proc s6_i_capture", maxsplit=1)[1].split("puts [format \"S6_INTERLEAVED_CONFIG", maxsplit=1)[0]
        ordered = [
            "set diag_ctrl_before_raw [wb_read 0x00100A04]",
            "set diag_epoch_before_raw [wb_read 0x00100B34]",
            "set diag_inverse_before_raw [wb_read 0x00100B38]",
            "set cko_raw [wb_read 0x00100A40]",
            "set sstat_raw [wb_read 0x00100A08]",
            "set ucnt_raw [wb_read 0x00100A48]",
            "set diag_epoch_after_raw [wb_read 0x00100B34]",
            "set diag_ctrl_after_raw [wb_read 0x00100A04]",
        ]
        offsets = [capture.index(item) for item in ordered]
        self.assertEqual(offsets, sorted(offsets))
        self.assertNotIn("wb_write ", source)
        self.assertIn("wb_register_writes=0 fpga_program=0 reset=0", source)
        self.assertIn("[normalize_probe64 $snapshot1_before]", source)
        self.assertIn("[normalize_probe64 $snapshot1_after]", source)
        self.assertIn("$reads_valid && $diag_frame_valid && $global_valid", source)

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
