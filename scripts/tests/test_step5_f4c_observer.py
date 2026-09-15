#!/usr/bin/env python3
"""Static safety checks for the read-only F4C Quartus observer."""

from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
OBSERVER = REPO_ROOT / "scripts" / "jtag" / "read_step5_main_frequency_prelock_observability.tcl"


class Step5F4CObserverTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = OBSERVER.read_text(encoding="utf-8")

    def test_f4c_identity_and_wall_clock_controls_are_present(self) -> None:
        for token in (
            "EXP-S5-F4C-MAIN-PHASE-SERVICE-CAUSE-AUDIT-20260915",
            "target_duration_ms",
            "hard_duration_ms",
            "run_role",
            "STEP5_F4C_TRANSPORT_GATE",
            "STEP5_F4C_HEALTH",
            "STEP5_F4C_SUMMARY",
        ):
            self.assertIn(token, self.text)
        self.assertNotIn("max_duration_ms", self.text)
        self.assertNotIn("EXP-S5-HPLL-DEMAND-MAIN-PROGRESS-CORRELATION", self.text)
        self.assertNotIn("helper_phase_guard_seconds=60", self.text)

    def test_existing_producer_addresses_are_explicit(self) -> None:
        for address in ("0x00100AC4", "0x00100AC8", "0x00100ACC", "0x00100B58", "0x00100BDC"):
            self.assertIn(address, self.text)
        self.assertIn("main_trace_publication_epoch", self.text)
        self.assertIn("MAIN_SAMPLE_N", self.text)
        self.assertIn("MAIN_SAMPLE_N_DELTA", self.text)

    def test_observer_does_not_request_helper_snapshot_or_write_control(self) -> None:
        self.assertIn("no_helper_pi_snapshot=1", self.text)
        self.assertIn("no_second_reader=1", self.text)
        forbidden = (
            "wdiags_helper_pi_snapshot_request",
            "request_helper_pi_snapshot",
            "write_config",
            "softpll_set",
        )
        for token in forbidden:
            self.assertNotIn(token, self.text)

    def test_step5_is_explicitly_not_completed(self) -> None:
        self.assertIn("step5_complete=NO", self.text)
        self.assertIn("merge_approved=NO", self.text)


if __name__ == "__main__":
    unittest.main()
