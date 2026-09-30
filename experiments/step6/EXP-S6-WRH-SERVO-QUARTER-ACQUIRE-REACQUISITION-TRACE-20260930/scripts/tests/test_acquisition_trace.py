from __future__ import annotations

from pathlib import Path
import sys
import unittest


EXPERIMENT = Path(__file__).resolve().parents[2]
ROOT = EXPERIMENT.parents[2]
sys.path.insert(0, str(EXPERIMENT / "scripts"))
import analyze_acquisition_trace as analyzer  # noqa: E402


TCL = ROOT / "scripts/jtag/read_step6_servo_acquisition_context.tcl"
WRAPPER = EXPERIMENT / "scripts/run_acquisition_trace.sh"


def sample(
    n: int,
    *,
    trusted: int = 1,
    state: int = 5,
    cko: int = -200,
    dms: int = 1000,
    setp: int = 300,
    global_valid: int = 0,
    qualifying: int = 0,
) -> str:
    return (
        "S6_ACQ_SAMPLE "
        f"sample={n} READS_VALID=1 STRUCTURALLY_TRUSTED_ROW={trusted} "
        f"STEP6_QUALIFYING_ROW={qualifying} GLOBAL_TIME_VALID={global_valid} "
        "DIAG_FRAME_VALID=1 PHASE_CONTEXT_FRAME_VALID=1 PHASE_CONTEXT_MATCH=1 "
        f"SERVO_STATE={state} CKO_PS={cko} DMS_PS={dms} SETP_PS={setp} "
        f"UCNT={n + 10:08X} PHASE_CONTEXT_UCNT={n + 10:08X} RESET_CHANGED=0 "
        "BOOT_GENERATION=00000001 CPU_RESET_COUNT=0000000A "
        "WR_CORE_RESET_COUNT=0000000B SI_CONFIG_DROP_COUNT=0000000C "
        "STEP1_GATE=1 HELPER_LOCK=1 MAIN_FREQ_LOCK=1 "
        "MAIN_PHASE_LOCK=1 MAIN_LOCK=1 PSTAT_LOCK=1"
    )


class AcquisitionTraceTests(unittest.TestCase):
    def test_global_time_invalid_row_remains_structurally_trusted(self):
        summary = analyzer.analyze_text(
            sample(0, global_valid=0, qualifying=0)
            + "\nS6_ACQ_STOP REQUESTED_DURATION_MS=600000 ELAPSED_MS=500 "
            "LAST_ROW_START_MS=0 LAST_ROW_END_MS=400 STOP_REASON=STEP1_GATE_LOST"
        )
        self.assertEqual(summary["structurally_trusted_count"], 1)
        self.assertEqual(summary["global_valid_trusted_count"], 0)
        self.assertEqual(summary["step6_qualifying_count"], 0)

    def test_only_structurally_trusted_track_row_counts_as_reacquired(self):
        untrusted = sample(0, trusted=0, state=4)
        stop = (
            "\nS6_ACQ_STOP REQUESTED_DURATION_MS=600000 ELAPSED_MS=600000 "
            "LAST_ROW_START_MS=599900 LAST_ROW_END_MS=600200 "
            "STOP_REASON=DURATION_LIMIT"
        )
        self.assertEqual(
            analyzer.analyze_text(untrusted + stop)["result"],
            "INCONCLUSIVE_STRUCTURAL_COVERAGE",
        )
        trusted = sample(0, trusted=1, state=4)
        self.assertEqual(
            analyzer.analyze_text(trusted + stop)["result"],
            "ACQUISITION_REACQUIRED",
        )

    def test_well_covered_full_window_without_track_is_a_bounded_finding(self):
        text = "\n".join(sample(n, state=5) for n in range(1000))
        text += (
            "\nS6_ACQ_STOP REQUESTED_DURATION_MS=600000 ELAPSED_MS=600100 "
            "LAST_ROW_START_MS=599900 LAST_ROW_END_MS=600050 "
            "STOP_REASON=DURATION_LIMIT"
        )
        summary = analyzer.analyze_text(text)
        self.assertEqual(summary["result"], "REPRODUCIBLE_ACQUISITION_FAILURE_OBSERVED")
        self.assertTrue(summary["adequate_full_window"])
        self.assertFalse(summary["track_phase_observed"])

    def test_context_mismatch_is_not_structurally_trusted(self):
        row = sample(0).replace(
            "PHASE_CONTEXT_UCNT=0000000A", "PHASE_CONTEXT_UCNT=0000000B"
        )
        summary = analyzer.analyze_text(row)
        self.assertEqual(summary["structurally_trusted_count"], 0)

    def test_adjacent_deltas_do_not_bridge_an_untrusted_sample(self):
        text = "\n".join(
            [
                sample(0, cko=-200, setp=100),
                sample(1, trusted=0, cko=-100, setp=200),
                sample(2, cko=-50, setp=300),
                "S6_ACQ_STOP REQUESTED_DURATION_MS=600000 ELAPSED_MS=1 "
                "LAST_ROW_START_MS=0 LAST_ROW_END_MS=1 STOP_REASON=OBSERVER_READ_ERROR",
            ]
        )
        summary = analyzer.analyze_text(text)
        self.assertEqual(summary["adjacent_trusted_pairs"], 0)
        self.assertIsNone(summary["delta_cko_max_abs_ps"])

    def test_analyzer_reports_setp_dms_and_residual_deltas(self):
        text = "\n".join(
            [
                sample(0, state=3, cko=-400, dms=1000, setp=300),
                sample(1, state=5, cko=-300, dms=1050, setp=200),
                "S6_ACQ_STOP REQUESTED_DURATION_MS=600000 ELAPSED_MS=1 "
                "LAST_ROW_START_MS=0 LAST_ROW_END_MS=1 STOP_REASON=OBSERVER_READ_ERROR",
            ]
        )
        summary = analyzer.analyze_text(text)
        self.assertEqual(summary["setp_distinct_count"], 2)
        self.assertEqual(summary["delta_cko_max_abs_ps"], 100)
        self.assertEqual(summary["delta_dms_max_abs_ps"], 50)
        self.assertEqual(summary["delta_residual_max_abs_ps"], 50)
        self.assertEqual(len(summary["sync_step_rows"]), 1)
        self.assertEqual(summary["sync_step_rows"][0]["delta_setp"], -100)

    def test_hex_encoded_ucnt_and_reset_fields_parse_as_hex(self):
        row = analyzer.parse_fields(sample(0))
        self.assertEqual(analyzer.as_int(row, "UCNT"), 0xA)
        self.assertEqual(analyzer.as_int(row, "PHASE_CONTEXT_UCNT"), 0xA)
        self.assertEqual(analyzer.as_int(row, "CPU_RESET_COUNT"), 0xA)
        self.assertTrue(analyzer.structurally_valid(row))

    def test_observer_has_hard_monotonic_deadline_and_global_independent_trust(self):
        source = TCL.read_text(encoding="utf-8")
        structural = (
            "set structurally_trusted [expr "
            "{$reads_valid && $diagnostic_frame_match ? 1 : 0}]"
        )
        self.assertIn(structural, source)
        self.assertIn("$structurally_trusted && $global_valid", source)
        self.assertIn("clock clicks -milliseconds", source)
        self.assertIn("elapsed_before_ms >= 600000", source)
        self.assertIn("$structural_trusted && $servo_state == 4", source)
        self.assertIn("if {$step1_gate != 1}", source)
        self.assertIn("$helper_lock != 1 || $main_freq != 1", source)
        self.assertIn("FIVE_CONSECUTIVE_STRUCTURALLY_INVALID_ROWS", source)

    def test_wrapper_logs_directly_to_raw_and_never_deletes_capture(self):
        source = WRAPPER.read_text(encoding="utf-8")
        self.assertIn('RAW_DIR="$EXP_DIR/raw/observe"', source)
        self.assertIn('tee -a "$LOG"', source)
        self.assertIn("605s", source)
        self.assertNotIn("rm -rf", source)
        self.assertNotIn("/tmp/capture.log", source)


if __name__ == "__main__":
    unittest.main()
