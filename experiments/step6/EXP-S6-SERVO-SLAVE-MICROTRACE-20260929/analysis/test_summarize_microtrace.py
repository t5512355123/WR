import unittest
from pathlib import Path

from summarize_microtrace import parse_log, summarize


class ReaderContractTest(unittest.TestCase):
    def test_exact_slave_only_six_read_contract(self):
        reader = Path(__file__).parents[1] / "scripts" / "read_slave_servo_microtrace.tcl"
        source = reader.read_text(encoding="utf-8")
        self.assertEqual(source.count("write_source_data"), 1)
        for address in ("0x00100A04", "0x00100A08", "0x00100A40"):
            self.assertIn(address, source)
        self.assertIn("{^DE5 \\[1-11\\.2\\]$}", source)
        self.assertNotIn("wb_write", source)
        self.assertNotIn("quartus_pgm", source)
        self.assertIn("set capture_duration_ms 300000", source)
        self.assertIn("consecutive_invalid >= 5", source)


class MicrotraceParserTest(unittest.TestCase):
    def test_retry_and_signed_offset_transition_are_preserved(self):
        a = "2026-09-29T15:00:00.000000000Z"
        b = "2026-09-29T15:00:00.030000000Z"
        log = "\n".join([
            f"{a}\tMICRO_SAMPLE board=DE5_1-11.2 sample=000001 attempt=0 row_valid=0 elapsed_us=31000 ctrl_valid=0 sstat_valid_begin=0 sstat_valid_end=0 state_begin=5 state_end=3 offset_begin_ps=62 offset_end_ps=-10",
            f"{b}\tMICRO_SAMPLE board=DE5_1-11.2 sample=000001 attempt=1 row_valid=1 elapsed_us=32000 ctrl_valid=1 sstat_valid_begin=1 sstat_valid_end=1 state_begin=5 state_end=4 state_begin_name=WAIT_OFFSET_STABLE state_end_name=TRACK_PHASE offset_begin_ps=55 offset_end_ps=-10",
            f"{b}\tMICRO_SAMPLE_RESULT board=DE5_1-11.2 sample=000001 accepted=1 retries=1 consecutive_invalid=0",
            f"{b}\tMICRO_SAMPLE board=DE5_1-11.2 sample=000002 attempt=0 row_valid=1 elapsed_us=33000 ctrl_valid=1 sstat_valid_begin=1 sstat_valid_end=1 state_begin=4 state_end=4 state_begin_name=TRACK_PHASE state_end_name=TRACK_PHASE offset_begin_ps=-50 offset_end_ps=-40 offset_delta_ps=10",
            f"{b}\tMICRO_SAMPLE_RESULT board=DE5_1-11.2 sample=000002 accepted=1 retries=0 consecutive_invalid=0",
            f"{b}\tCAPTURE_PROCESS_EXIT=0",
        ])
        rows, results, code, errors, stop = parse_log(log)
        result = summarize(rows, results, code, errors, stop)
        self.assertEqual(result["accepted_samples"], 2)
        self.assertEqual(result["failed_attempt_rows"], 1)
        self.assertEqual(result["accepted_samples_with_retries"], 1)
        self.assertEqual(result["track_phase_observed_at_boundary"], True)
        self.assertEqual(result["either_boundary_strictly_under_60ps_samples"], 2)
        self.assertEqual(result["within_row_offset_delta_ps"]["median"], -27.5)
        self.assertEqual(result["within_row_state_change_rows"], 1)
        self.assertEqual(result["longest_consecutive_both_boundaries_under_60ps_samples"], 2)
        self.assertEqual(result["both_boundaries_under_60ps_and_track_phase_samples"], 1)

    def test_unaccepted_sample_is_not_counted_as_valid(self):
        a = "2026-09-29T15:00:00.000000000Z"
        log = "\n".join([
            f"{a}\tMICRO_SAMPLE board=DE5_1-11.2 sample=000001 attempt=0 row_valid=0 elapsed_us=40000 ctrl_valid=0 sstat_valid_begin=0 sstat_valid_end=0 state_begin=-1 state_end=-1 offset_begin_ps=-2147483649 offset_end_ps=-2147483649",
            f"{a}\tMICRO_SAMPLE_RESULT board=DE5_1-11.2 sample=000001 accepted=0 retries=2 consecutive_invalid=1",
        ])
        rows, results, code, errors, stop = parse_log(log)
        result = summarize(rows, results, code, errors, stop)
        self.assertEqual(result["sample_results"], 1)
        self.assertEqual(result["accepted_samples"], 0)
        self.assertEqual(result["failed_attempt_rows"], 1)
        self.assertEqual(result["reader_error_lines"], 0)


if __name__ == "__main__":
    unittest.main()
