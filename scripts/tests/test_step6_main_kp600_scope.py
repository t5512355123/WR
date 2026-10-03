"""One new functional value; historical F4K/threshold20 tests keep old meaning."""
import hashlib
import subprocess
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='8983d6e4ac042c719d9216e67f87b2aeafff1bea'
def old(path):
    return subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT).decode()
def text(path):return (ROOT/path).read_text()
class ScopeTests(unittest.TestCase):
    def test_only_slave_main_kp_value_changes(self):
        path='firmware/configs/de5a_slave_identity.h'
        current=text(path)
        self.assertEqual(current.count('#define DE5A_MAIN_PI_KP_OVERRIDE 600'),1)
        self.assertEqual(current.replace('#define DE5A_MAIN_PI_KP_OVERRIDE 600',
                                        '#define DE5A_MAIN_PI_KP_OVERRIDE 300'),old(path))
    def test_all_controller_and_hardware_inputs_unchanged(self):
        for path in ('firmware/configs/de5a_master_identity.h',
            'firmware/configs/de5a_slave_defconfig',
            'vendor/wrpc-sw/softpll/spll_main.c',
            'vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c',
            'quartus/DE5a_wr_slave_jtag.vhd','quartus/DE5a_wr_master_jtag.vhd'):
            self.assertEqual(text(path),old(path),path)
        changed=subprocess.check_output(['git','diff','--name-only',BASE,'--',
            'firmware','vendor','quartus','quartus_generated'],cwd=ROOT).decode().splitlines()
        self.assertEqual(changed,['firmware/configs/de5a_slave_identity.h'])
    def test_current_good_frequency_acceptance_ki_preload_not_reverted(self):
        c=text('firmware/configs/de5a_slave_identity.h')
        for define in ('DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE 20',
                       'DE5A_MAIN_PHASE_PI_KI_ZERO 0',
                       'DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD 1',
                       'DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE 0'):
            self.assertIn('#define '+define,c)
        m=text('vendor/wrpc-sw/softpll/spll_main.c')
        self.assertIn('s->pi.kp = DE5A_MAIN_PI_KP_OVERRIDE;',m)
        self.assertIn('s->pi.ki = 1;',m)
        self.assertIn('(DE5A_MAIN_PI_KP_OVERRIDE != 600)',m)
    def test_diagnostics_and_strict_proof_are_not_relaxed(self):
        for path in ('scripts/analysis/step6_strict_offset_300s.py',
                     'scripts/jtag/read_step6_strict_offset_validity.tcl',
                     'scripts/jtag/read_step6_phase_history.tcl',
                     'scripts/analysis/step6_phase_history.py',
                     'vendor/wrpc-sw/lib/phase-history.c'):
            self.assertEqual(text(path),old(path),path)
if __name__=='__main__':unittest.main()
