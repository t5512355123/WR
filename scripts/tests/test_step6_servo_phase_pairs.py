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

    def test_sparse_f4l_current_read_has_publication_and_servo_guards(self) -> None:
        source = OBSERVER_PATH.read_text(encoding="utf-8")
        f4l_source = source.split(
            "proc s6_f4l_phase_current_read", maxsplit=1
        )[1].split("proc s6_servo_reset_signature", maxsplit=1)[0]
        reads = [
            "wb_read 0x00100B58",
            "wb_read 0x00100B5C",
            "wb_read 0x00100B60",
            "wb_read 0x00100B64",
            "wb_read 0x00100B88",
        ]
        positions = [f4l_source.index(read) for read in reads]
        final_epoch_read = f4l_source.rindex("wb_read 0x00100B58")
        self.assertEqual(positions, sorted(positions))
        self.assertGreater(final_epoch_read, positions[-1])
        self.assertIn("$epoch_after == $epoch_before", f4l_source)
        self.assertIn("$magic == 0x46344c31", f4l_source)
        self.assertIn("$servo_after == $pair_ucnt", f4l_source)
        self.assertIn(">= 5000", source)
        self.assertNotIn("wb_write ", source)

    def test_counts_only_counter_stable_rows_and_pairs(self) -> None:
        lines = [
            "S6_SERVO_PAIR_SAMPLE board=slave sample=0 READS_VALID=1 UCNT_AFTER=00000001 UCNT_BRACKET_STABLE=1 COHERENT=1 PAIR_VALID=0 SERVO_STATE=5 CKO_PS=120 SETP_PS=30 STATUS_TIME_VALID=0 RESET_CHANGED=0",
            "S6_SERVO_PAIR_SAMPLE board=slave sample=1 READS_VALID=1 UCNT_AFTER=00000002 UCNT_BRACKET_STABLE=1 COHERENT=1 PAIR_VALID=1 SERVO_STATE=5 CKO_PS=120 SETP_PS=150 STATUS_TIME_VALID=0 RESET_CHANGED=0",
            "S6_SERVO_PAIR_SAMPLE board=slave sample=2 READS_VALID=1 UCNT_AFTER=00000002 UCNT_BRACKET_STABLE=1 COHERENT=1 PAIR_VALID=0 SERVO_STATE=5 CKO_PS=120 SETP_PS=150 STATUS_TIME_VALID=0 RESET_CHANGED=0",
            "S6_SERVO_PAIR_SAMPLE board=slave sample=3 READS_VALID=1 UCNT_AFTER=00000003 UCNT_BRACKET_STABLE=1 COHERENT=1 PAIR_VALID=1 SERVO_STATE=5 CKO_PS=80 SETP_PS=150 STATUS_TIME_VALID=0 RESET_CHANGED=0",
            "S6_SERVO_PAIR_SAMPLE board=slave sample=4 READS_VALID=1 UCNT_AFTER=00000004 UCNT_BRACKET_STABLE=0 COHERENT=0 PAIR_VALID=0 SERVO_STATE=5 CKO_PS=40 SETP_PS=150 STATUS_TIME_VALID=0 RESET_CHANGED=0",
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trace.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path)

        self.assertEqual(result["sample_rows"], 5)
        self.assertEqual(result["counter_stable_rows"], 4)
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
                    f"S6_SERVO_PAIR_SAMPLE board=slave sample={index} READS_VALID=1 UCNT_AFTER=00000001 UCNT_BRACKET_STABLE=1 COHERENT=1 PAIR_VALID=0 CKO_PS=100 SETP_PS=50 SERVO_STATE=5 STATUS_TIME_VALID=0 RESET_CHANGED=0"
                    for index in range(3)
                )
                + "\n",
                encoding="utf-8",
            )
            result = ANALYZER.summarize(path)

        self.assertEqual(result["counter_stable_rows"], 3)
        self.assertEqual(result["adjacent_update_pairs"], 0)
        self.assertEqual(result["verdict"], "INCONCLUSIVE_NO_ADJACENT_UPDATE_PAIRS")

    def test_f4l_current_is_joined_only_with_coherent_same_servo_counter(self) -> None:
        lines = [
            "S6_SERVO_PAIR_SAMPLE board=slave sample=7 READS_VALID=1 UCNT_AFTER=0000002A UCNT_BRACKET_STABLE=1 COHERENT=1 SERVO_STATE=5 CKO_PS=110 SETP_PS=250 STATUS_TIME_VALID=0 RESET_CHANGED=0",
            "S6_F4L_PHASE_SAMPLE board=slave sample=7 FRAME_VALID=1 PHASE_SHIFT_CURRENT_UNITS=246 PHASE_SHIFT_CURRENT_PS=240 SERVO_UCNT_BEFORE=0000002A SERVO_UCNT_AFTER=0000002A SERVO_UPDATE_MATCH=1 PAIR_UCNT=42",
            "S6_SERVO_PAIR_SAMPLE board=slave sample=8 READS_VALID=1 UCNT_AFTER=0000002B UCNT_BRACKET_STABLE=1 COHERENT=1 SERVO_STATE=5 CKO_PS=90 SETP_PS=300 STATUS_TIME_VALID=0 RESET_CHANGED=0",
            "S6_F4L_PHASE_SAMPLE board=slave sample=8 FRAME_VALID=1 PHASE_SHIFT_CURRENT_UNITS=300 PHASE_SHIFT_CURRENT_PS=293 SERVO_UCNT_BEFORE=0000002A SERVO_UCNT_AFTER=0000002B SERVO_UPDATE_MATCH=0 PAIR_UCNT=43",
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trace.log"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = ANALYZER.summarize(path)

        self.assertEqual(result["f4l_phase_samples"], 2)
        self.assertEqual(result["f4l_phase_frames_valid"], 2)
        self.assertEqual(result["f4l_same_servo_update_matches"], 1)
        self.assertEqual(result["f4l_current_setpoint_comparison_rows"], 1)
        self.assertEqual(result["f4l_current_minus_setpoint_ps"], [-10])
        self.assertEqual(result["f4l_phase_current_units_min"], 246)
        self.assertEqual(result["f4l_phase_current_units_max"], 300)


if __name__ == "__main__":
    unittest.main()
