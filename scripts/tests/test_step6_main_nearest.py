"""Scoped admission candidate; integer model is not a hardware PASS."""
import re
import subprocess
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='bf0651769e9abe373d220d9444dc79ce91edc814'
def original(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode()
def baseline_form(text):
    text=re.sub(r'^\s*(?://|--) MAIN_NEAREST_BEGIN_\w+\n.*?^\s*(?://|--) MAIN_NEAREST_END_\w+\n','',text,flags=re.M|re.S)
    text=text.replace('DPLL_UP_ADMISSION_CODE','DPLL_STEP_CODE').replace('DPLL_DOWN_ADMISSION_CODE','DPLL_STEP_CODE')
    return '\n'.join(line for line in text.splitlines() if line.strip())
def step(target,applied):
    if target>applied and target-applied>=8:return applied+16
    if applied>target and applied-target>=9:return applied-16
    return applied
class NearestTests(unittest.TestCase):
    def test_only_four_main_admission_comparisons_and_slave_enable(self):
        for path in ('quartus/si5340a_controller_dco.v','quartus/DE5a_wr_master_jtag.vhd','quartus/DE5a_wr_slave_jtag.vhd'):
            self.assertEqual(baseline_form((ROOT/path).read_text()),baseline_form(original(path)),path)
        text=(ROOT/'quartus/si5340a_controller_dco.v').read_text()
        self.assertEqual(text.count('>= DPLL_UP_ADMISSION_CODE'),2)
        self.assertEqual(text.count('>= DPLL_DOWN_ADMISSION_CODE'),2)
        self.assertIn('parameter integer ENABLE_DPLL_NEAREST_STEP = 0',text)
        self.assertIn('((DPLL_STEP_CODE + 1) >> 1) : DPLL_STEP_CODE',text)
        self.assertIn('((DPLL_STEP_CODE >> 1) + 1) : DPLL_STEP_CODE',text)
        self.assertNotIn('ENABLE_DPLL_NEAREST_STEP =>',(ROOT/'quartus/DE5a_wr_master_jtag.vhd').read_text())
        self.assertEqual((ROOT/'quartus/DE5a_wr_slave_jtag.vhd').read_text().count('ENABLE_DPLL_NEAREST_STEP => 1'),1)
    def test_firmware_helper_constraints_physical_step_and_verifier_unchanged(self):
        for path in ('firmware/configs/de5a_slave_identity.h','firmware/configs/de5a_master_identity.h',
            'vendor/wrpc-sw/softpll/spll_common.c','vendor/wrpc-sw/softpll/spll_main.c',
            'vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c','vendor/wrpc-sw/lib/task-diags.c',
            'quartus/i2c_bus_controller_dco.v','quartus/si5340a_i2c_reg_controller_dco.v',
            'quartus/DE5a_wr_master_jtag.sdc','quartus/DE5a_wr_slave_jtag.sdc',
            'quartus/DE5a_wr_master_jtag.qsf','quartus/DE5a_wr_slave_jtag.qsf',
            'scripts/jtag/read_step6_main_dco_capture.tcl','scripts/analysis/step6_main_dco_capture.py',
            'scripts/jtag/read_step6_strict_offset_validity.tcl','scripts/analysis/step6_strict_offset_300s.py'):
            self.assertEqual((ROOT/path).read_text(),original(path),path)
        text=(ROOT/'quartus/si5340a_controller_dco.v').read_text()
        self.assertIn('dpll_applied_position <= dpll_applied_position - DPLL_STEP_CODE;',text)
        self.assertIn('dpll_applied_position <= dpll_applied_position + DPLL_STEP_CODE;',text)
    def test_all_unsigned_targets_unique_nearest_grid_and_no_chatter(self):
        for target in range(65536):
            wanted=((target+8)//16)*16
            seeds={target//16*16,wanted,min(65536,wanted+16),max(0,wanted-16)}
            for applied in seeds:
                for _ in range(3):
                    next_applied=step(target,applied)
                    self.assertIn(next_applied-applied,(-16,0,16))
                    self.assertTrue(0<=next_applied<=65536)
                    applied=next_applied
                self.assertEqual(applied,wanted,(target,seeds))
                self.assertEqual(step(target,applied),applied)
    def test_midpoint_and_unsigned_boundaries(self):
        self.assertEqual(step(32776,32768),32784)
        self.assertEqual(step(32776,32784),32784)
        self.assertEqual(step(32775,32784),32768)
        self.assertEqual(step(5,0),0)
        self.assertEqual(step(65535,65520),65536)
        self.assertEqual(step(65535,65536),65536)
if __name__=='__main__':unittest.main()
