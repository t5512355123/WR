"""Source guard for explicitly requested, read-only RXTS diagnostics."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PassiveRxtsTests(unittest.TestCase):
    def test_only_diagnostic_function_added_to_calibrator(self):
        path = 'vendor/wrpc-sw/dev/rxts_calibrator.c'
        current = (ROOT / path).read_text()
        frozen = (ROOT / 'artifacts/milestones/step6_global_time/source' / path).read_text()
        start = current.index('\n/* Passive, non-atomic diagnostic;')
        end = current.index('\n/* finds the transition', start)
        # Original executable calibration implementation remains byte-identical.
        self.assertEqual(current[:start] + current[end:], frozen)

    def test_diagnostic_has_no_calibration_or_phase_write(self):
        text = (ROOT / 'vendor/wrpc-sw/dev/rxts_calibrator.c').read_text()
        function = text.split('void calib_t24p_show_state(void)', 1)[1].split('\n}', 1)[0]
        for forbidden in ('spll_set_', 'storage_', 'calib_t24p_init(',
                          'rxts_calibration_update(', 'ep_timestamper_cal_pulse('):
            self.assertNotIn(forbidden, function)
        self.assertIn('spll_read_ptracker(', function)
        self.assertIn('netif_get_device(0)->phase_transition', function)

    def test_call_is_only_in_stat(self):
        text = (ROOT / 'vendor/wrpc-sw/shell/cmd_pll.c').read_text()
        self.assertEqual(text.count('calib_t24p_show_state();'), 1)
        stat = text.split('case CMD_STAT:', 1)[1].split('case CMD_SPS:', 1)[0]
        self.assertIn('calib_t24p_show_state();', stat)


if __name__ == '__main__':
    unittest.main()
