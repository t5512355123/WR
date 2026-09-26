#!/usr/bin/env python3
"""Regression checks for Step 1..6 dashboard gating and stale time snapshots."""

from __future__ import annotations

import os
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DASHBOARD = ROOT / "scripts" / "monitor" / "step1_6_dashboard.sh"


def dashboard_line(step6: str, link: int, tm: int, step1: str = "PASS") -> str:
    return (
        "DASHBOARD_BOARD board=DE5_1-11.1 role=MASTER | "
        f"Step1={step1} Step2=INVALID Step3=INFO Step4=INFO Step5=INFO "
        f"Step6={step6} | HelperLock=NA MainFreq=NA MainPhase=NA "
        "MainLock=NA PSTAT=NA | "
        "WR_SERVO_STATE=NA WR_SERVO_OFFSET_PS=NA | "
        f"Link={link} TM={tm} RX=1 TX=1 STATUS_TIME_VALID=1 "
        "STATUS_PPS_VALID=1 TIME_VALID=1 PPS_VALID=1 SNAPSHOT_VALID=1 "
        "SNAPSHOT_STABLE=1 SNAPSHOT_COUNT=17 | TAI=1155 CYCLES=124999999 | "
        "PPS_CR=0x20000006 PPS_CR_ENABLE=0 PPS_ESCR=0x0000000C "
        "ESCR_TM_VALID=1 ESCR_PPS_VALID=1 Step5Result=NOT_APPLICABLE_MASTER"
    )


class DashboardGateTest(unittest.TestCase):
    def run_dashboard(self, line: str, wait_seconds: int = 0) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory(prefix="step1-6-dashboard-test-") as temp:
            fake_stp = Path(temp) / "quartus_stp"
            fake_stp.write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\n' " + shlex.quote(line) + "\n"
                "printf '%s\\n' DASHBOARD_DONE\n",
                encoding="utf-8",
            )
            fake_stp.chmod(0o755)
            env = os.environ.copy()
            env.update(
                {
                    "QUARTUS_STP": str(fake_stp),
                    "ONCE": "1",
                    "CLEAR_SCREEN": "0",
                    "WAIT_FOR_GLOBAL_TIME_SECONDS": str(wait_seconds),
                    "WAIT_FOR_GLOBAL_TIME_POLL_SECONDS": "1",
                    "OBS_GAP_MS": "0",
                }
            )
            return subprocess.run(
                ["bash", str(DASHBOARD)],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                timeout=8,
                check=False,
            )

    def test_continuous_dashboard_ignores_inherited_wait(self) -> None:
        source = DASHBOARD.read_text(encoding="utf-8")
        self.assertIn('if [ "$ONCE" != "1" ] && [ "$WAIT_FOR_GLOBAL_TIME_SECONDS" -gt 0 ]; then', source)
        self.assertIn("WAIT_FOR_GLOBAL_TIME_SECONDS=0", source)
        self.assertIn("live sampling is immediate", source)

    def test_wr_servo_state_names_match_firmware_enum(self) -> None:
        tcl_source = (ROOT / "scripts" / "jtag" / "read_step1_6_dashboard.tcl").read_text(
            encoding="utf-8"
        )
        self.assertIn("1 { return SYNC_TAI }", tcl_source)
        self.assertIn("2 { return SYNC_NSEC }", tcl_source)

    def test_valid_snapshot_does_not_pass_step6_when_link_is_down(self) -> None:
        result = self.run_dashboard(dashboard_line("INFO", 0, 0, step1="FAIL"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Step 6  Global Time", result.stdout)
        self.assertIn("LINK DOWN", result.stdout)
        self.assertIn("WR link gate failed (Link=0, TM=0)", result.stdout)
        self.assertIn(
            "SNAPSHOT VALID; Step1=FAIL Step6=INFO Link=0 TM=0", result.stdout
        )

    def test_wait_gate_does_not_accept_retained_snapshot_without_step6_pass(self) -> None:
        result = self.run_dashboard(
            dashboard_line("INFO", 0, 0, step1="FAIL"), wait_seconds=1
        )
        self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
        self.assertIn("DASHBOARD_GLOBAL_TIME_WAIT_INCOMPLETE seconds=1", result.stdout)
        self.assertIn("scope=host-only", result.stdout)
        self.assertIn("reason=host-side-max", result.stderr)

    def test_slave_waiting_for_ptp_phase_reports_the_offset_gate(self) -> None:
        line = dashboard_line("INFO", 1, 1).replace(
            "TIME_VALID=1 PPS_VALID=1 SNAPSHOT_VALID=1",
            "TIME_VALID=0 PPS_VALID=0 SNAPSHOT_VALID=0",
        ).replace(
            "WR_SERVO_STATE=NA WR_SERVO_OFFSET_PS=NA",
            "WR_SERVO_STATE=WAIT_OFFSET_STABLE WR_SERVO_OFFSET_PS=2318",
        )
        result = self.run_dashboard(line)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PTP servo offset not yet <60 ps", result.stdout)
        self.assertIn("WAIT_OFFSET_STABLE", result.stdout)
        self.assertIn("2318 ps (target <60 ps)", result.stdout)

    def test_negative_wr_servo_offset_is_displayed_as_signed(self) -> None:
        line = dashboard_line("INFO", 1, 1).replace(
            "TIME_VALID=1 PPS_VALID=1 SNAPSHOT_VALID=1",
            "TIME_VALID=0 PPS_VALID=0 SNAPSHOT_VALID=0",
        ).replace(
            "WR_SERVO_STATE=NA WR_SERVO_OFFSET_PS=NA",
            "WR_SERVO_STATE=WAIT_OFFSET_STABLE WR_SERVO_OFFSET_PS=-37",
        )
        result = self.run_dashboard(line)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-37 ps (target <60 ps)", result.stdout)

    def test_linked_valid_snapshot_renders_as_pass(self) -> None:
        result = self.run_dashboard(dashboard_line("PASS", 1, 1))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Step 6  Global Time", result.stdout)
        self.assertIn("VALID", result.stdout)
        self.assertRegex(result.stdout, r"CYCLES=124999999\s+VALID")

    def test_step6_pass_is_rejected_when_step1_fails(self) -> None:
        result = self.run_dashboard(dashboard_line("PASS", 1, 1, step1="FAIL"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("STEP1 BLOCKED", result.stdout)
        self.assertIn("SNAPSHOT VALID; Step1=FAIL Step6=PASS Link=1 TM=1", result.stdout)


if __name__ == "__main__":
    unittest.main()
