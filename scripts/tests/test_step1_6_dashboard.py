#!/usr/bin/env python3
"""Regression checks for Step 1..6 dashboard gating and stale time snapshots."""

from __future__ import annotations

import os
import shutil
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DASHBOARD = ROOT / "scripts" / "monitor" / "step1_6_dashboard.sh"
BASH = shutil.which("bash") or r"C:\Program Files\Git\bin\bash.exe"


def dashboard_line(
    step6: str,
    link: int,
    tm: int,
    step1: str = "PASS",
    role: str = "MASTER",
    offset_ps: str = "NA",
    phase_offset_ok: str | None = None,
) -> str:
    if phase_offset_ok is None:
        try:
            phase_offset_ok = str(int(role != "SLAVE" or abs(int(offset_ps)) < 60))
        except ValueError:
            phase_offset_ok = "0"
    board = "DE5_1-11.2" if role == "SLAVE" else "DE5_1-11.1"
    servo_state = "WAIT_OFFSET_STABLE" if role == "SLAVE" else "NA"
    return (
        f"DASHBOARD_BOARD board={board} role={role} | "
        f"Step1={step1} Step2=INVALID Step3=INFO Step4=INFO Step5=INFO "
        f"Step6={step6} | HelperLock=NA MainFreq=NA MainPhase=NA "
        "MainLock=NA PSTAT=NA | "
        f"WR_SERVO_STATE={servo_state} WR_SERVO_OFFSET_PS={offset_ps} "
        f"WR_PHASE_OFFSET_OK={phase_offset_ok} | "
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
                [BASH, str(DASHBOARD)],
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

    def test_tcl_step6_gate_uses_time_validity_not_other_signals(self) -> None:
        tcl_source = (ROOT / "scripts" / "jtag" / "read_step1_6_dashboard.tcl").read_text(
            encoding="utf-8"
        )
        self.assertIn("$global_time_valid == 1", tcl_source)
        self.assertNotIn("$global_pps_valid == 1 ?", tcl_source)
        self.assertIn("$status_time_valid == 1", tcl_source)
        self.assertIn("$status_time_valid == 1 ? \"PASS\" : \"INFO\"", tcl_source)
        self.assertNotIn("$phase_offset_ok == 1", tcl_source)
        self.assertNotIn("$step1 eq \"PASS\"", tcl_source)
        self.assertIn("WR_PHASE_OFFSET_OK=%s", tcl_source)

    def test_slave_time_valid_pass_is_independent_of_phase_offset(self) -> None:
        for offset in ("59", "-59", "60", "-60", "2318"):
            with self.subTest(offset=offset):
                result = self.run_dashboard(
                    dashboard_line("PASS", 1, 1, role="SLAVE", offset_ps=offset)
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("Step 6  Global Time", result.stdout)
                self.assertIn("VALID", result.stdout)
                phase_display = (
                    f"{offset} ps (diagnostic only)" if offset != "NA" else "NA ps"
                )
                self.assertIn(phase_display, result.stdout)

    def test_shell_fails_closed_if_reported_time_validity_disagrees(self) -> None:
        line = dashboard_line("PASS", 1, 1).replace(
            "TIME_VALID=1 PPS_VALID=1 SNAPSHOT_VALID=1",
            "TIME_VALID=0 PPS_VALID=1 SNAPSHOT_VALID=1",
        )
        result = self.run_dashboard(line)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("WAITING", result.stdout)
        self.assertIn("TIME_VALID=0, PPS_VALID=1", result.stdout)

    def test_time_valid_pass_does_not_require_step1_or_pps_valid(self) -> None:
        result = self.run_dashboard(dashboard_line("PASS", 0, 0, step1="FAIL"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Step 6  Global Time", result.stdout)
        self.assertIn("VALID", result.stdout)
        self.assertIn("TIME_VALID snapshot valid", result.stdout)
        self.assertIn(
            "TAI=1155         CYCLES=124999999    TIME_VALID", result.stdout
        )

    def test_wait_gate_does_not_accept_retained_snapshot_without_step6_pass(self) -> None:
        result = self.run_dashboard(
            dashboard_line("INFO", 0, 0, step1="FAIL"), wait_seconds=1
        )
        self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
        self.assertIn("DASHBOARD_GLOBAL_TIME_WAIT_INCOMPLETE seconds=1", result.stdout)
        self.assertIn("scope=host-only", result.stdout)
        self.assertIn("reason=host-side-max", result.stderr)

    def test_slave_waiting_for_time_valid_reports_global_time_gate(self) -> None:
        line = dashboard_line("INFO", 1, 1, role="SLAVE", offset_ps="2318").replace(
            "TIME_VALID=1 PPS_VALID=1 SNAPSHOT_VALID=1",
            "TIME_VALID=0 PPS_VALID=0 SNAPSHOT_VALID=0",
        )
        result = self.run_dashboard(line)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("TIME_VALID=0, PPS_VALID=0", result.stdout)
        self.assertIn("WAIT_OFFSET_STABLE", result.stdout)
        self.assertIn("2318 ps (diagnostic only)", result.stdout)

    def test_negative_wr_servo_offset_is_displayed_as_signed(self) -> None:
        line = dashboard_line("INFO", 1, 1, role="SLAVE", offset_ps="-37").replace(
            "TIME_VALID=1 PPS_VALID=1 SNAPSHOT_VALID=1",
            "TIME_VALID=0 PPS_VALID=0 SNAPSHOT_VALID=0",
        )
        result = self.run_dashboard(line)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-37 ps (diagnostic only)", result.stdout)

    def test_linked_valid_snapshot_renders_as_pass(self) -> None:
        result = self.run_dashboard(dashboard_line("PASS", 1, 1))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Step 6  Global Time", result.stdout)
        self.assertIn("VALID", result.stdout)
        self.assertRegex(result.stdout, r"CYCLES=124999999\s+TIME_VALID")

    def test_step6_time_valid_does_not_require_step1_pass(self) -> None:
        result = self.run_dashboard(dashboard_line("PASS", 1, 1, step1="FAIL"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Step 6  Global Time", result.stdout)
        self.assertIn("VALID", result.stdout)


if __name__ == "__main__":
    unittest.main()
