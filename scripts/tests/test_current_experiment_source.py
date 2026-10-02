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
            self.assertEqual((ROOT / path).read_text(), (FROZEN / path).read_text())


if __name__ == '__main__':
    unittest.main()
