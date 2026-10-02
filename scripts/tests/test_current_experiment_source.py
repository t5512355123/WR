"""Guard the promoted controller and the Quartus firmware load path."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
FROZEN = ROOT / 'artifacts/milestones/step6_global_time/source'


class CurrentSourceTests(unittest.TestCase):
    def test_controller_is_exact_proven_candidate(self):
        path = 'vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c'
        expected = (FROZEN / path).read_text().replace(
            's->cur_setpoint_ps += offset_ps;',
            's->cur_setpoint_ps += (offset_ps / 2);').replace(
            's->cur_setpoint_ps += (offset_ps / 4);',
            's->cur_setpoint_ps += (offset_ps / 12);')
        self.assertEqual((ROOT / path).read_text(), expected)

    def test_top_levels_preserve_validated_memory_path(self):
        for role in ('master', 'slave'):
            path = f'quartus/DE5a_wr_{role}_jtag.vhd'
            expected = (FROZEN / path).read_text()
            if role == 'master':
                old = '''      -- Keep the Master's normal HPLL path enabled: it is the upstream
      -- frequency reference for the Slave calibration image.  The normal
      -- tracker is disabled only in the Slave under test.
      ENABLE_NORMAL_HPLL_TRACKER => 1,
      ENABLE_STEP5_BOOTSTRAP => 0,'''
                new = '''      -- Master range-recovery candidate: the unbootstrapped fine range
      -- exhausted at HY=65531 with Helper unlocked. Shift only its physical
      -- origin; keep the existing 34-code fine step and all firmware gains.
      -- Explicit actuator polarity makes every bootstrap step FINC, rather
      -- than allowing the changing normal target direction to reverse it.
      ENABLE_STEP5_ACTUATOR_IDENTIFICATION => 1,
      ENABLE_NORMAL_HPLL_TRACKER => 1,
      ENABLE_STEP5_BOOTSTRAP => 1,
      STEP5_BOOTSTRAP_STEPS => 2048,
      STEP5_BOOTSTRAP_REVERSE => 1,'''
                self.assertEqual(expected.count(old), 1)
                expected = expected.replace(old, new)
            self.assertEqual((ROOT / path).read_text(), expected)


if __name__ == '__main__':
    unittest.main()
