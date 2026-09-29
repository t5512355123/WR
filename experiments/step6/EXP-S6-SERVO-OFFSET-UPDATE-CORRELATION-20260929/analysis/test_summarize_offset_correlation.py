import unittest
from pathlib import Path
import subprocess
import sys
import tempfile

from summarize_offset_correlation import parse_log, summarize


class ReaderContractTest(unittest.TestCase):
    def test_slave_only_read_registers_and_no_target_writes(self):
        reader = Path(__file__).parents[1] / "scripts" / "read_slave_offset_update_correlation.tcl"
        source = reader.read_text(encoding="utf-8")
        self.assertEqual(source.count("write_source_data"), 1)
        for address in (
            "0x00100A04", "0x00100A08", "0x00100A34", "0x00100A38",
            "0x00100A40", "0x00100A44", "0x00100A48",
        ):
            self.assertIn(address, source)
        self.assertIn("{^DE5 \\[1-11\\.2\\]$}", source)
        self.assertNotIn("wb_write", source)
        self.assertNotIn("quartus_pgm", source)
        self.assertIn("set capture_duration_ms 300000", source)
        self.assertIn("setp_begin_raw=%s setp_end_raw=%s", source)


class CorrelationParserTest(unittest.TestCase):
    def test_offset_event_is_correlated_with_bracketed_fields(self):
        a = "2026-09-29T16:00:00.000000000Z"
        b = "2026-09-29T16:00:00.100000000Z"
        fields1 = (
            "row_valid=1 elapsed_us=80000 state_begin=5 state_end=4 "
            "offset_begin_ps=100 offset_end_ps=40 ucnt_begin=00000001 ucnt_end=00000001 "
            "setp_begin_ps=100 setp_end_ps=100 dms_hi_begin=00000000 dms_lo_begin=00001000 "
            "dms_hi_end=00000000 dms_lo_end=00001000"
        )
        fields2 = (
            "row_valid=1 elapsed_us=81000 state_begin=4 state_end=3 "
            "offset_begin_ps=40 offset_end_ps=-3650 ucnt_begin=00000001 ucnt_end=00000002 "
            "setp_begin_ps=100 setp_end_ps=120 dms_hi_begin=00000000 dms_lo_begin=00001000 "
            "dms_hi_end=00000000 dms_lo_end=00001100"
        )
        log = "\n".join([
            f"{a}\tCORR_SAMPLE board=DE5_1-11.2 sample=000001 attempt=0 {fields1}",
            f"{a}\tCORR_SAMPLE_RESULT board=DE5_1-11.2 sample=000001 accepted=1 retries=0 consecutive_invalid=0",
            f"{b}\tCORR_SAMPLE board=DE5_1-11.2 sample=000002 attempt=0 {fields2}",
            f"{b}\tCORR_SAMPLE_RESULT board=DE5_1-11.2 sample=000002 accepted=1 retries=0 consecutive_invalid=0",
            f"{b}\tCAPTURE_PROCESS_EXIT=0",
        ])
        rows, results, code, errors, stop, board_result = parse_log(log)
        summary = summarize(rows, results, code, errors, stop, board_result)
        self.assertEqual(summary["accepted_samples"], 2)
        self.assertEqual(summary["within_row_state_change_rows"], 2)
        self.assertEqual(summary["ucnt_delta_within_row"]["max"], 1)
        self.assertEqual(summary["setp_delta_within_row_ps"]["max"], 20)
        self.assertEqual(summary["dms_delta_within_row_ps"]["max"], 256)
        events = summary["offset_event_correlation"]
        self.assertEqual(events["events_at_or_above_120ps"], 1)
        self.assertEqual(events["events_with_ucnt_change_in_bracket"], 1)
        self.assertEqual(events["events_with_setp_change_in_bracket"], 1)
        self.assertEqual(events["events_with_dms_change_in_bracket"], 1)
        self.assertEqual(events["events_with_both_ucnt_and_dms_change"], 1)
        self.assertEqual(events["events_with_no_ucnt_setp_or_dms_change"], 0)

    def test_signed_64_bit_dms_and_capture_result_are_decoded(self):
        a = "2026-09-29T16:00:00.000000000Z"
        fields = (
            "row_valid=1 elapsed_us=80000 state_begin=5 state_end=5 "
            "offset_begin_ps=10 offset_end_ps=11 ucnt_begin=00000001 ucnt_end=00000001 "
            "setp_begin_ps=0 setp_end_ps=0 dms_hi_begin=FFFFFFFF dms_lo_begin=FFFFFF00 "
            "dms_hi_end=FFFFFFFF dms_lo_end=FFFFFF80"
        )
        log = "\n".join([
            f"{a}\tCORR_SAMPLE board=DE5_1-11.2 sample=000001 attempt=0 {fields}",
            f"{a}\tCORR_SAMPLE_RESULT board=DE5_1-11.2 sample=000001 accepted=1 retries=0 consecutive_invalid=0",
            f"{a}\tCORR_BOARD_RESULT board=DE5_1-11.2 samples=1 accepted=1 failed=0 elapsed_ms=300100",
            f"{a}\tCAPTURE_PROCESS_EXIT=0",
        ])
        rows, results, code, errors, stop, board_result = parse_log(log)
        summary = summarize(rows, results, code, errors, stop, board_result)
        self.assertEqual(summary["dms_delta_within_row_ps"]["max"], 128)
        self.assertEqual(summary["board_result"]["elapsed_ms"], 300100)

    def test_cli_writes_utf8_lf_summary_on_older_python(self):
        analyzer = Path(__file__).with_name("summarize_offset_correlation.py")
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "capture.log"
            output = Path(directory) / "summary.json"
            log.write_text(
                "2026-09-29T16:00:00.000000000Z\tCAPTURE_PROCESS_EXIT=0\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(analyzer), str(log), "--output", str(output)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            raw = output.read_bytes()
            self.assertIn(b'"capture_process_exit": 0', raw)
            self.assertNotIn(b"\r\n", raw)


if __name__ == "__main__":
    unittest.main()
