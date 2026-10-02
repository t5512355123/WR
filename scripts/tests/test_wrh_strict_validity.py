"""Strict-source contracts plus actual servo C execution when CC is available."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SERVO = ROOT / "vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"

class StrictValidityTests(unittest.TestCase):
    def test_actual_c_with_undefined_behaviour_sanitizer(self):
        cc = shutil.which("cc") or shutil.which("gcc") or shutil.which("clang")
        if cc is None:
            self.skipTest("No native C compiler here; run run_wrh_strict_c.sh on Pain before firmware build")
        with tempfile.TemporaryDirectory() as out:
            exe = Path(out)/"servo-test"
            subprocess.run([cc,"-std=gnu99","-fsanitize=undefined",
                "-fno-sanitize-recover=all","-I",str(ROOT/"scripts/tests/wrh_strict"),
                str(ROOT/"scripts/tests/wrh_strict/servo_test.c"),"-o",str(exe)],check=True)
            result = subprocess.run([str(exe)],check=True,capture_output=True,text=True)
            self.assertIn("ACTUAL_WRH_SERVO_C_TEST=PASS",result.stdout)

    def test_full_offset_gate_precedes_busy_return_and_ignores_tracking_switch(self):
        text = SERVO.read_text()
        gate = text.index("s->offsetMS_ps > 2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD")
        self.assertLess(gate,text.index("if (!WRH_OPER()->adjust_in_progress())"))
        self.assertLess(gate,text.index("if(wrh_tracking_enabled)"))
        self.assertIn("s->offsetMS_ps < -2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD",text)
        self.assertNotIn("abs(pp_time_to_picos",text)
        self.assertNotIn("abs(s->offsetMS_ps)",text)
        self.assertEqual(text.count("s->cur_setpoint_ps += (offset_ps / 2);"),1)
        self.assertEqual(text.count("s->cur_setpoint_ps += (offset_ps / 12);"),1)

    def test_state_and_reinitialization_revoke_before_phase_write(self):
        text=SERVO.read_text()
        state=text.split("static void setState(struct pp_instance *ppi, int newState)\n{",1)[1].split("static int __wrh",1)[0]
        self.assertIn("newState != WRH_TRACK_PHASE",state)
        self.assertIn("enable_timing_output(GLBS(ppi), 0)",state)
        init=text.split("int wrh_servo_init",1)[1].split("void wrh_servo_reset",1)[0]
        self.assertLess(init.index("enable_timing_output(GLBS(ppi), 0)"),init.index("adjust_phase"))

    def test_slave_force_cannot_bypass_gate_and_abi_unchanged(self):
        text=(ROOT/"vendor/wrpc-sw/ppsi/arch-wrpc/wrpc-spll.c").read_text()
        self.assertIn("wrc_ptp_get_mode() != WRC_MODE_SLAVE && GOPTS(ppg)->forcePpsGen",text)
        header=(ROOT/"vendor/wrpc-sw/ppsi/include/hw-specific/wrh.h").read_text()
        self.assertIn("#define WRS_PPSI_SHMEM_VERSION 36",header)
        self.assertIn("#define WRH_SERVO_OFFSET_STABILITY_THRESHOLD 60",header)

if __name__=="__main__": unittest.main()
