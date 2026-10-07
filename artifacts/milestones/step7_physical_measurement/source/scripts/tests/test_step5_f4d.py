#!/usr/bin/env python3
"""Hardware-independent tests for the F4D upstream gate/session audit."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts" / "experiment"))

import step5_f4d_gate_audit  # noqa: E402


def f4d_sample(
    *,
    role: str = "SLAVE",
    sample: int = 1,
    timestamp_ms: int = 1000,
    generation: int = 1,
    core_valid: int = 1,
    frame_valid: int = 1,
    terminal_state: str = "ACTIVE",
    history_valid: int = 0,
    terminal_streak: int = 0,
    upstream_pass: int = 0,
    upstream_streak: int = 0,
    wr_state_value: int = 2,
    ptp_state: int = 9,
    parent_flags: int = 1,
    pd_state: int = 3,
    ext_state: int = 2,
    wr_disable_valid: int = 0,
    failure_reason: int = 0,
    generation_changed: int = 0,
    reset_changed: int = 0,
    ptp_rx: str = "00000010",
    ptp_tx: str = "00000020",
) -> str:
    values = {
        "trial": "F4D",
        "role": role,
        "board": "DE5 [1-11.2]" if role == "SLAVE" else "DE5 [1-11.1]",
        "sample": sample,
        "timestamp_ms": timestamp_ms,
        "FRAME_VALID": frame_valid,
        "CORE_FRAME_VALID": core_valid,
        "BOOT_GENERATION": f"{generation:08X}",
        "CPU_RESET_COUNT": 0,
        "WR_CORE_RESET_COUNT": 0,
        "SI_CONFIG_RESET_COUNT": 0,
        "WRC_MODE": 3,
        "PTP_STATE": ptp_state,
        "PPSI_PDSTATE": pd_state,
        "PPSI_EXTSTATE": ext_state,
        "PARENTISWRNODE": parent_flags,
        "PARENTMODEON": parent_flags,
        "PARENTCALIBRATED": parent_flags,
        "WR_STATE_VALUE": wr_state_value,
        "WR_STATE_NAME": "WRS_S_LOCK" if wr_state_value == 2 else "WRS_IDLE",
        "WR_FAILURE_LOW16": 0,
        "WR_FAILURE_REASON": failure_reason,
        "WR_FAILURE_REASON_NAME": "UNKNOWN" if failure_reason == 0 else "WR_S_LOCK_TIMEOUT",
        "WR_DISABLE_VALID": wr_disable_valid,
        "WR_DISABLE_CAUSE": 0,
        "F4D_TERMINAL_STATE": terminal_state,
        "F4D_TERMINAL_HISTORY_VALID": history_valid,
        "F4D_TERMINAL_STREAK": terminal_streak,
        "F4D_UPSTREAM_FULL_PASS": upstream_pass,
        "F4D_UPSTREAM_PASS_STREAK": upstream_streak,
        "F4D_GENERATION_CHANGED": generation_changed,
        "F4D_RESET_CHANGED": reset_changed,
        "F4D_STOP_REASON": "NONE",
        "F4D_STOP_ROLE": "NONE",
        "PTP_RX_COUNT": ptp_rx,
        "PTP_TX_COUNT": ptp_tx,
        "WR_RX_SIGNAL": "00001001",
        "WR_TX_SIGNAL": "00001002",
    }
    return "STARTUP_TIMELINE_SAMPLE " + " ".join(f"{key}={value}" for key, value in values.items())


class Step5F4DAuditTests(unittest.TestCase):
    def test_three_terminal_frames_classify_session_already_terminated(self) -> None:
        text = "\n".join([
            "STARTUP_TIMELINE_CONFIG trial=F4D duration_ms=120000 hard_duration_ms=130000",
            f4d_sample(sample=1, timestamp_ms=1000, terminal_state="IDLE", history_valid=1, terminal_streak=1,
                       wr_state_value=0, ptp_rx="00000010"),
            f4d_sample(sample=2, timestamp_ms=2000, terminal_state="IDLE", history_valid=1, terminal_streak=2,
                       wr_state_value=0, ptp_rx="00000011"),
            f4d_sample(sample=3, timestamp_ms=3000, terminal_state="IDLE", history_valid=1, terminal_streak=3,
                       wr_state_value=0, ptp_rx="00000012"),
            "STARTUP_TIMELINE_DONE trial=F4D elapsed_ms=3000 end_reason=SESSION_ALREADY_TERMINATED",
        ])
        result = step5_f4d_gate_audit.analyze_text(text)
        self.assertEqual(result["f4d_result"], "SESSION_ALREADY_TERMINATED")
        self.assertTrue(result["f4d_pass"])
        self.assertFalse(result["step5_pass"])
        self.assertEqual(result["roles"]["SLAVE"]["ptp_rx_accounting"]["delta_sum"], 2)

    def test_three_upstream_pass_frames_are_not_step5_pass(self) -> None:
        text = "\n".join([
            f4d_sample(sample=1, timestamp_ms=1000, upstream_pass=1, upstream_streak=1),
            f4d_sample(sample=2, timestamp_ms=2000, upstream_pass=1, upstream_streak=2),
            f4d_sample(sample=3, timestamp_ms=3000, upstream_pass=1, upstream_streak=3),
        ])
        result = step5_f4d_gate_audit.analyze_text(text)
        self.assertEqual(result["f4d_result"], "GATE_RECOVERED_OBSERVED")
        self.assertFalse(result["step5_pass"])
        self.assertFalse(result["merge_approved"])

    def test_generation_change_makes_result_inconclusive(self) -> None:
        text = "\n".join([
            f4d_sample(sample=1, timestamp_ms=1000, generation=1),
            f4d_sample(sample=2, timestamp_ms=2000, generation=2, generation_changed=1),
            f4d_sample(sample=3, timestamp_ms=3000, generation=2),
        ])
        result = step5_f4d_gate_audit.analyze_text(text)
        self.assertEqual(result["generation_changes"], 1)
        self.assertEqual(result["f4d_result"], "INCONCLUSIVE")
        self.assertFalse(result["f4d_pass"])

    def test_invalid_core_frames_do_not_form_a_streak(self) -> None:
        text = "\n".join([
            f4d_sample(sample=1, timestamp_ms=1000, terminal_state="IDLE", history_valid=1, core_valid=1),
            f4d_sample(sample=2, timestamp_ms=2000, terminal_state="IDLE", history_valid=1, core_valid=0),
            f4d_sample(sample=3, timestamp_ms=3000, terminal_state="IDLE", history_valid=1, core_valid=1),
            f4d_sample(sample=4, timestamp_ms=4000, terminal_state="IDLE", history_valid=1, core_valid=1),
        ])
        result = step5_f4d_gate_audit.analyze_text(text)
        self.assertEqual(result["roles"]["SLAVE"]["terminal_streak_max"], 2)
        self.assertEqual(result["f4d_result"], "ACQUISITION_WINDOW_OBSERVED")


if __name__ == "__main__":
    unittest.main()
