"""Guard the promoted controller and the Quartus firmware load path."""
from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FROZEN = ROOT / 'artifacts/milestones/step6_global_time/source'
CURRENT_HASHES = {
    'vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c':
        '83e929dc284a2d1be71242684c293fc193eac3fde1f6abd086bf48e84a2d9bc2',
    'quartus/DE5a_wr_master_jtag.vhd':
        '1cbaf7b40f831bd7d1ba32702dbfc80b1a7dfb3948eca5d7dd8922e57cc880ed',
    'quartus/DE5a_wr_slave_jtag.vhd':
        'cf4db299a18e954fba52b379673717494be22448b47df6a40af4c6845cdb449e',
}


class CurrentSourceTests(unittest.TestCase):
    def check_standalone_source(self, path):
        """The promoted package must not require a second old milestone."""
        current = (ROOT / path).read_bytes()
        historical = FROZEN / path
        if not historical.exists() or historical.read_bytes() == current:
            self.assertEqual(hashlib.sha256(current).hexdigest(), CURRENT_HASHES[path])
            return True
        return False

    def test_controller_is_current_strict_candidate(self):
        path = 'vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c'
        self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), CURRENT_HASHES[path])
        text = (ROOT / path).read_text()
        self.assertEqual(text.count('s->cur_setpoint_ps += (offset_ps / 2);'), 1)
        self.assertEqual(text.count('s->cur_setpoint_ps += (offset_ps / 12);'), 1)
        self.assertIn('s->offsetMS_ps > 2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD', text)
        self.assertIn('if (newState != WRH_TRACK_PHASE)', text)

    def test_top_levels_preserve_validated_memory_path(self):
        for role in ('master', 'slave'):
            path = f'quartus/DE5a_wr_{role}_jtag.vhd'
            if self.check_standalone_source(path):
                continue
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
                expected = expected.replace(
                    '      STEP5_BOOTSTRAP_REVERSE => 1,\n',
                    '      STEP5_BOOTSTRAP_REVERSE => 1,\n'
                    '      -- Repeatability candidate: the Master with the inherited 34-code\n'
                    '      -- account alternated between both PI rails while the 64-code Slave\n'
                    '      -- remained locked. Test the same physical-step account on the Master;\n'
                    '      -- bootstrap origin, PI and firmware validity decisions stay unchanged.\n'
                    '      HPLL_TRACKER_CODE_PER_PHYSICAL_STEP => 64,\n')
                expected = expected.replace(
                    '      STEP5_BOOTSTRAP_STEPS : integer := 6336;\n',
                    '      STEP5_BOOTSTRAP_STEPS : integer := 6336;\n'
                    '      STEP5_BOOTSTRAP_REVERSE : integer := 0;\n')
            self.assertEqual((ROOT / path).read_text(), expected)

    def test_master_controller_generic_map_matches_declared_interface(self):
        source = (ROOT / 'quartus/DE5a_wr_master_jtag.vhd').read_text()
        interface = source.split('component si5340a_controller_dco is', 1)[1].split('port (', 1)[0]
        mapping = source.split('u_si5340a_controller : si5340a_controller_dco', 1)[1].split('port map', 1)[0]
        declared = set(re.findall(r'(\w+)\s*:\s*integer', interface))
        used = set(re.findall(r'(\w+)\s*=>', mapping))
        self.assertTrue(used <= declared, f'undeclared generic(s): {used - declared}')


if __name__ == '__main__':
    unittest.main()
