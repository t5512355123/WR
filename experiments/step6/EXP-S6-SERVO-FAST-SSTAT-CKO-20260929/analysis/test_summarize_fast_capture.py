import unittest
from pathlib import Path

from summarize_fast_capture import parse_capture, summarize


class FastReaderContractTest(unittest.TestCase):
    def test_reader_is_read_only_and_rejects_mailbox_error_marker(self):
        reader = Path(__file__).parents[1] / "scripts" / "read_servo_fast.tcl"
        source = reader.read_text(encoding="utf-8")
        self.assertEqual(source.count("write_source_data"), 1)
        self.assertIn("0xa5a50000", source)
        self.assertIn("set pattern [format {^[0-9A-Fa-f]{1,%d}$} $max_digits]", source)
        self.assertNotIn('regexp "^[0-9A-Fa-f]', source)
        self.assertIn("set sstat_begin [wb_read 0x00100A08]", source)
        self.assertIn("set sstat_end [wb_read 0x00100A08]", source)
        self.assertIn("set cko_begin [wb_read 0x00100A40]", source)
        self.assertIn("set cko_end [wb_read 0x00100A40]", source)
        self.assertIn("$main_freq >= 0 && $main_phase >= 0}]", source)
        self.assertNotIn("$time_valid_end >= 0", source)
        self.assertNotIn("|| !$state_valid", source)
        self.assertNotIn("wb_write", source)
        self.assertNotIn("quartus_pgm", source)


class FastCaptureParserTest(unittest.TestCase):
    def test_preserves_within_row_state_edge_and_signed_offsets(self):
        a = "2026-09-29T13:00:00.000000000Z"
        b = "2026-09-29T13:00:00.100000000Z"
        fields = (
            "data_valid=1 sample_valid=1 elapsed_us=40000 ctrl_valid=1 "
            "sstat_valid_begin=1 sstat_valid_end=1 time_valid_begin=1 time_valid_end=1 "
            "pps_valid_begin=1 pps_valid_end=1 link_begin=1 link_end=1 pstat_link=1 "
            "spll_locked=1 helper_locked=1 main_enabled=1 main_locked=1 main_freq=1 main_phase=1 "
            "dms_h=00000000 dms_l=00000001 setp=FFFF0000 ucnt=00000001 "
        )
        log = "\n".join([
            f"{a}\tFAST_SAMPLE board=DE5 [1-11.2] sample=001 attempt=0 {fields}state_begin=5 state_end=3 state_begin_name=WAIT_OFFSET_STABLE state_end_name=SYNC_PHASE offset_begin_ps=55 offset_end_ps=130",
            f"{a}\tFAST_SAMPLE_RESULT board=DE5 [1-11.2] sample=001 accepted=1 retries=0",
            f"{b}\tFAST_SAMPLE board=DE5 [1-11.2] sample=002 attempt=0 {fields}state_begin=3 state_end=3 state_begin_name=SYNC_PHASE state_end_name=SYNC_PHASE offset_begin_ps=-50 offset_end_ps=-40",
            f"{b}\tFAST_SAMPLE_RESULT board=DE5 [1-11.2] sample=002 accepted=1 retries=0",
            f"{b}\tCAPTURE_PROCESS_EXIT=0",
        ])
        rows, exit_code, errors = parse_capture(log)
        result = summarize(rows, exit_code, errors)
        slave = result["boards"]["DE5 [1-11.2]"]
        self.assertEqual(exit_code, 0)
        self.assertEqual(errors, 0)
        self.assertEqual(slave["accepted_samples"], 2)
        self.assertEqual(slave["all_five_step5_lock_samples"], 2)
        self.assertEqual(slave["offset_begin_min_ps"], -50)
        self.assertEqual(slave["state_changes_within_row"][0]["begin_state"], "WAIT_OFFSET_STABLE")
        self.assertEqual(slave["state_changes_within_row"][0]["end_state"], "SYNC_PHASE")
        self.assertEqual(slave["both_offsets_strictly_under_60ps_samples"], 1)


if __name__ == "__main__":
    unittest.main()
