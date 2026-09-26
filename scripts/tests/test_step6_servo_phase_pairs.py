from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
ANALYZER_PATH = (
    REPO_ROOT
    / "experiments"
    / "step6"
    / "EXP-S6-MILESTONE-REPRO-20260926"
    / "analysis"
    / "analyze_servo_phase_pairs.py"
)
OBSERVER_PATH = REPO_ROOT / "scripts" / "jtag" / "read_step6_servo_phase_coherent_pair.tcl"
SPEC = importlib.util.spec_from_file_location("servo_pair_analyzer", ANALYZER_PATH)
assert SPEC and SPEC.loader
ANALYZER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ANALYZER)


class ServoPhasePairAnalysisTests(unittest.TestCase):
    def test_observer_brackets_the_source_mapped_fields_with_update_counter(self) -> None:
        source = OBSERVER_PATH.read_text(encoding="utf-8")
        reads = [
            "set ucnt_before [wb_read 0x00100A48]",
            "set sstat [wb_read 0x00100A08]",
            "set cko [wb_read 0x00100A40]",
            "set setp [wb_read 0x00100A44]",
            "set ucnt_after [wb_read 0x00100A48]",
        ]
        positions = [source.index(read) for read in reads]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("read_only=1 wb_register_writes=0 fpga_program=0 reset=0", source)
        self.assertNotIn("wb_write ", source)

    def test_counts_only_counter_stable_rows_and_pairs(self) -> None:
        lines = [
            "S6_SERVO_PAIR_SAMPLE board=slave sample=0 READS_VALID=1 UCNT_BRACKET_STABLE=1 PAIR_VALID=0 UPDATE_DELTA=-1 SERVO_STATE=5 CKO_PS=120 SETP_PS=30 SETP_DELTA_PS=NA CKO_DELTA_PS=NA SETPOINT_CKO_MATCH=-1 POST_ACTION_RESPONSE=0 STATUS_TIME_VALID=0 RESET_CHANGED=0",
            "S6_SERVO_PAIR_SAMPLE board=slave sample=1 READS_VALID=1 UCNT_BRACKET_STABLE=1 PAIR_VALID=1 UPDATE_DELTA=1 SERVO_STATE=5 CKO_PS=120 SETP_PS=150 SETP_DELTA_PS=120 CKO_DELTA_PS=0 SETPOINT_CKO_MATCH=1 POST_ACTION_RESPONSE=0 STATUS_TIME_VALID=0 RESET_CHANGED=0",
            "S6_SERVO_PAIR_SAMPLE board=slave sample=2 READS_VALID=1 UCNT_BRACKET_STABLE=0 PAIR_VALID=0 UPDATE_DELTA=-1 SERVO_STATE=5 CKO_PS=80 SETP_PS=150 SETP_DELTA_PS=NA CKO_DELTA_PS=NA SETPOINT_CKO_MATCH=-1 POST_ACTION_RESPONSE=0 STATUS_TIME_VALID=0 RESET_CHANGED=0",
            "S6_SERVO_PAIR_SAMPLE board=slave sample=3 READS_VALID=1 UCNT_BRACKET_STABLE=1 PAIR_VALID=1 UPDATE_DELTA=1 SERVO_STATE=5 CKO_PS=80 SETP_PS=150 SETP_DELTA_PS=0 CKO_DELTA_PS=-40 SETPOINT_CKO_MATCH=0 POST_ACTION_RESPONSE=1 STATUS_TIME_VALID=0 RESET_CHANGED=0",
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trace.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path)

        self.assertEqual(result["sample_rows"], 4)
        self.assertEqual(result["counter_stable_rows"], 3)
        self.assertEqual(result["adjacent_update_pairs"], 2)
        self.assertEqual(result["setpoint_offset_match_tests"], 2)
        self.assertEqual(result["setpoint_offset_matches"], 1)
        self.assertEqual(result["post_action_offset_delta_ps"], [-40])
        self.assertEqual(result["cko_abs_lt_60ps_rows"], 0)
        self.assertIn("NO_STEP6_PASS_CLAIM", result["verdict"])

    def test_no_pair_remains_inconclusive(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trace.log"
            path.write_text(
                "\n".join(
                    f"S6_SERVO_PAIR_SAMPLE board=slave sample={index} READS_VALID=1 UCNT_BRACKET_STABLE=1 PAIR_VALID=0 CKO_PS=100 STATUS_TIME_VALID=0 RESET_CHANGED=0"
                    for index in range(3)
                )
                + "\n",
                encoding="utf-8",
            )
            result = ANALYZER.summarize(path)

        self.assertEqual(result["counter_stable_rows"], 3)
        self.assertEqual(result["adjacent_update_pairs"], 0)
        self.assertEqual(result["verdict"], "INCONCLUSIVE_NO_ADJACENT_UPDATE_PAIRS")


if __name__ == "__main__":
    unittest.main()
