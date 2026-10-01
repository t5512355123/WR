from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


EXPERIMENT = Path(__file__).resolve().parents[1]
ANALYZER_PATH = EXPERIMENT / "analysis/analyze_fixed_setpoint.py"
SPEC = importlib.util.spec_from_file_location("fixed_setpoint_analysis", ANALYZER_PATH)
assert SPEC and SPEC.loader
ANALYZER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ANALYZER)


def capture(setp_values: list[int], cko_values: list[int]) -> str:
    duration = 30000
    rows = []
    for index, (setp, cko) in enumerate(zip(setp_values, cko_values)):
        fields = {
            "sample": f"{index:04d}",
            "elapsed_ms": str(index * 1500),
            "READS_VALID": "1",
            "COHERENT": "1",
            "DIAG_FRAME_VALID": "1",
            "DIAG_EPOCH_STABLE": "1",
            "PHASE_CONTEXT_VALID": "1",
            "PHASE_CONTEXT_FRAME_VALID": "1",
            "PHASE_CONTEXT_MATCH": "1",
            "GLOBAL_TIME_VALID": "1",
            "SNAPSHOT_VALID": "1",
            "SNAPSHOT_STABLE": "1",
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
            "RESET_CHANGED": "0",
            "SERVO_STATE": "4",
            "SSTAT": "00000401",
            "CKO_PS": str(cko),
            "DMS_PS": "1000",
            "SETP_PS": str(setp),
            "UCNT": f"{index + 1:08X}",
            "QUALIFYING_SAMPLE": "0",
        }
        rows.append("S6_INTERLEAVED_SAMPLE " + " ".join(f"{k}={v}" for k, v in fields.items()))
    return "\n".join(
        [
            f"S6_INTERLEAVED_CONFIG duration_ms={duration} read_only=1 wb_register_writes=0 fpga_program=0 reset=0",
            *rows,
            f"S6_INTERLEAVED_BOARD_DONE board=DE5 [1-11.2] samples={len(rows)} elapsed_ms={duration} reset_stop=0 invalid_streak=0",
            f"S6_INTERLEAVED_SUMMARY boards=1 rows={len(rows)} accepted={len(rows)} qualifying=0 reset_stop=0 timeout_count=0 invalid_count=0",
            "S6_INTERLEAVED_DONE",
        ]
    )


class FixedSetpointAnalyzerTests(unittest.TestCase):
    def test_valid_30_second_fixed_setp_smoke_passes(self) -> None:
        result = ANALYZER.analyze_text(capture([4000] * 20, [0, 10] * 10))
        self.assertTrue(result["capture_complete"])
        self.assertTrue(result["all_gates_valid_every_row"])
        self.assertTrue(result["all_paired_rows_track"])
        self.assertTrue(result["setp_fixed"])
        self.assertTrue(result["fixed_setpoint_smoke_pass"])
        self.assertFalse(result["step6_strict_offset_300s_pass"])

    def test_setpoint_change_rejects_smoke(self) -> None:
        result = ANALYZER.analyze_text(capture([4000] * 19 + [4001], [0] * 20))
        self.assertFalse(result["setp_fixed"])
        self.assertFalse(result["fixed_setpoint_smoke_pass"])

    def test_out_of_band_cko_is_retained_and_rejects_step6(self) -> None:
        result = ANALYZER.analyze_text(capture([4000] * 20, [0] * 19 + [60]))
        self.assertEqual(result["valid_read_cko_ps_range"], {"min": 0, "max": 60})
        self.assertFalse(result["step6_strict_offset_300s_pass"])


if __name__ == "__main__":
    unittest.main()
