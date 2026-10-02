from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "analysis" / "step6_dashboard_gate_capture.py"
SPEC = importlib.util.spec_from_file_location("step6_dashboard_gate_capture", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def sample_row(sample: int, elapsed_ms: int, *, offset_ps: int = 59, **overrides: str) -> str:
    fields = {
        "board": "slave",
        "sample": f"{sample:04d}",
        "elapsed_ms": str(elapsed_ms),
        "READS_VALID": "1",
        "COHERENT": "1",
        "QUALIFYING_SAMPLE": "1",
        "GLOBAL_TIME_VALID": "1",
        "SNAPSHOT_STABLE": "1",
        "SNAPSHOT_VALID": "1",
        "STATUS_TIME_VALID": "1",
        "STATUS_PPS_VALID": "1",
        "ESCR_TIME_VALID": "1",
        "ESCR_PPS_VALID": "1",
        "STEP1_GATE": "1",
        "STATUS_SI_CONFIG_DONE": "1",
        "STATUS_WR_READY": "1",
        "STATUS_TM_LINK": "1",
        "STATUS_LINK_OK": "1",
        "STATUS_RX_READY": "1",
        "STATUS_TX_READY": "1",
        "STATUS_CPU_RESET_N": "1",
        "STATUS_RX_LOCKED_TO_DATA": "1",
        "HELPER_LOCK": "1",
        "MAIN_FREQ_LOCK": "1",
        "MAIN_PHASE_LOCK": "1",
        "MAIN_LOCK": "1",
        "PSTAT_LOCK": "1",
        "DIAG_FRAME_VALID": "1",
        "DIAG_EPOCH_STABLE": "1",
        "PHASE_CONTEXT_VALID": "1",
        "PHASE_CONTEXT": "2",
        "PHASE_CONTEXT_FRAME_VALID": "1",
        "PHASE_CONTEXT_MATCH": "1",
        "RESET_CHANGED": "0",
        "CKO_PS": str(offset_ps),
        "SERVO_STATE": "4",
        "TAI": "30432",
        "CYCLES": "123289344",
        "UCNT": "0000708D",
    }
    fields.update(overrides)
    return "S6_INTERLEAVED_SAMPLE " + " ".join(f"{key}={value}" for key, value in fields.items())


def capture(rows: list[str], *, qualifying: int | None = None) -> str:
    if qualifying is None:
        qualifying = sum("QUALIFYING_SAMPLE=1" in row for row in rows)
    accepted = sum("COHERENT=1" in row for row in rows)
    return "\n".join(
        [
            "S6_INTERLEAVED_CONFIG duration_ms=300000 read_only=1 wb_register_writes=0 fpga_program=0 reset=0",
            *rows,
            f"S6_INTERLEAVED_BOARD_DONE samples={len(rows)} elapsed_ms=300062 reset_stop=0 invalid_streak=0",
            f"S6_INTERLEAVED_SUMMARY boards=1 rows={len(rows)} accepted={accepted} qualifying={qualifying} reset_stop=0 timeout_count=0 invalid_count=0",
            "S6_INTERLEAVED_DONE",
        ]
    )


class Step6DashboardGateCaptureTests(unittest.TestCase):
    def test_offset_capture_reads_the_same_dashboard_cko_probe(self) -> None:
        dashboard_source = (
            ROOT / "scripts" / "jtag" / "read_step1_6_dashboard.tcl"
        ).read_text(encoding="utf-8")
        runtime_source = (ROOT / "scripts" / "jtag" / "read_wb_runtime.tcl").read_text(
            encoding="utf-8"
        )
        capture_source = (
            ROOT / "scripts" / "jtag" / "read_step6_servo_interleaved_offset.tcl"
        ).read_text(encoding="utf-8")

        self.assertIn("dashboard_signed32 [get_snap $board after cko]", dashboard_source)
        self.assertIn("put_snap $board $label cko [wb_read 0x00100A40]", runtime_source)
        self.assertIn("set cko_raw [wb_read 0x00100A40]", capture_source)

    def test_preserved_hardware_capture_reproduces_pointwise_verdict(self) -> None:
        raw_capture = (
            ROOT
            / "experiments"
            / "step6"
            / "EXP-S6-DASHBOARD-EQUIVALENT-GATE-CAPTURE-20260930"
            / "raw"
            / "observe"
            / "capture_dashboard_gate_20260929T205329Z.log"
        )
        result = MODULE.analyze_file(raw_capture)

        self.assertTrue(result["capture_complete"])
        self.assertTrue(result["read_only_contract"])
        self.assertTrue(result["no_stop_or_read_errors"])
        self.assertEqual(result["sample_rows"], 958)
        self.assertEqual(result["observer_summary_consistent"], True)
        self.assertEqual(result["all_step1_status_rows"], 958)
        self.assertEqual(result["all_five_lock_rows"], 958)
        self.assertEqual(result["independently_qualified_rows"], 2)
        self.assertEqual(result["longest_consecutive_qualified_rows"], 2)
        self.assertEqual(result["consecutive_sample_span_ms"], 296)
        self.assertEqual(result["pointwise_verdict"], "STEP6_POINTWISE_GATE_PASS")

    def test_two_consecutive_full_gate_samples_are_pointwise_pass(self) -> None:
        result = MODULE.analyze_text(
            capture([sample_row(91, 29161), sample_row(92, 29457)])
        )

        self.assertEqual(result["pointwise_verdict"], "STEP6_POINTWISE_GATE_PASS")
        self.assertEqual(result["independently_qualified_rows"], 2)
        self.assertEqual(result["longest_consecutive_qualified_rows"], 2)
        self.assertEqual(result["consecutive_sample_span_ms"], 296)
        self.assertEqual(result["sustained_300s_offset_stability"], "NOT_ESTABLISHED")

    def test_strict_limit_excludes_exactly_sixty_ps(self) -> None:
        result = MODULE.analyze_text(
            capture([sample_row(1, 1000, offset_ps=60, QUALIFYING_SAMPLE="0")], qualifying=0)
        )

        self.assertEqual(result["independently_qualified_rows"], 0)
        self.assertEqual(result["pointwise_verdict"], "STEP6_POINTWISE_GATE_NOT_ESTABLISHED")

    def test_every_dashboard_step1_status_bit_is_required(self) -> None:
        result = MODULE.analyze_text(
            capture(
                [
                    sample_row(
                        1,
                        1000,
                        STATUS_LINK_OK="0",
                        STEP1_GATE="0",
                        QUALIFYING_SAMPLE="0",
                    )
                ],
                qualifying=0,
            )
        )

        self.assertEqual(result["all_step1_status_rows"], 0)
        self.assertEqual(result["independently_qualified_rows"], 0)

    def test_observer_and_offline_qualification_must_agree(self) -> None:
        result = MODULE.analyze_text(
            capture([sample_row(1, 1000, QUALIFYING_SAMPLE="0")], qualifying=0)
        )

        self.assertEqual(result["qualification_marker_mismatches"], [0])
        self.assertEqual(result["pointwise_verdict"], "STEP6_POINTWISE_GATE_NOT_ESTABLISHED")

    def test_phase_observation_survives_invalid_global_time_but_not_step6_gate(self) -> None:
        row = sample_row(
            1,
            1000,
            COHERENT="0",
            QUALIFYING_SAMPLE="0",
            GLOBAL_TIME_VALID="0",
            SNAPSHOT_VALID="0",
            STATUS_TIME_VALID="0",
            ESCR_TIME_VALID="0",
            PHASE_OBSERVATION_VALID="1",
        )
        text = capture([row], qualifying=0).replace(
            "accepted=0 qualifying=0", "accepted=0 phase_accepted=1 qualifying=0"
        )
        result = MODULE.analyze_text(text)

        self.assertEqual(result["phase_observation_valid_rows"], 1)
        self.assertEqual(result["phase_observation_cko_min_ps"], 59)
        self.assertEqual(result["phase_observation_strict_offset_rows_abs_lt_60_ps"], 1)
        self.assertEqual(result["independently_qualified_rows"], 0)
        self.assertEqual(result["pointwise_verdict"], "STEP6_POINTWISE_GATE_NOT_ESTABLISHED")

    def test_unmatched_ucnt_is_not_a_valid_phase_observation(self) -> None:
        row = sample_row(
            1,
            1000,
            READS_VALID="1",
            COHERENT="0",
            QUALIFYING_SAMPLE="0",
            PHASE_OBSERVATION_VALID="0",
            PHASE_CONTEXT_MATCH="0",
        )
        text = capture([row], qualifying=0).replace(
            "accepted=0 qualifying=0", "accepted=0 phase_accepted=0 qualifying=0"
        )
        result = MODULE.analyze_text(text)

        self.assertEqual(result["read_valid_cko_min_ps"], 59)
        self.assertEqual(result["phase_observation_valid_rows"], 0)
        self.assertIsNone(result["valid_offset_min_ps"])



if __name__ == "__main__":
    unittest.main()
