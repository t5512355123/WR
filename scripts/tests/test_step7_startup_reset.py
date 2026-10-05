"""Startup timing reference model + structural wiring guards (not HDL simulation)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class StartupModel:
    def __init__(self, reset_cycles=3, settle_cycles=5):
        self.reset_cycles = reset_cycles
        self.release = reset_cycles + settle_cycles
        self.elapsed = 0

    def tick(self, reset_n=True):
        self.elapsed = min(self.elapsed + 1, self.release) if reset_n else 0

    def outputs(self, reset_n=True):
        return (reset_n and self.elapsed >= self.reset_cycles,
                reset_n and self.elapsed == self.release)


class StartupResetTests(unittest.TestCase):
    def test_release_boundaries_and_saturation(self):
        # Small constants exercise the same saturating counter/event ordering.
        model = StartupModel()
        outputs = []
        for _ in range(12):
            outputs.append(model.outputs())
            model.tick()
        self.assertEqual(outputs[:3], [(False, False)] * 3)
        self.assertEqual(outputs[3:8], [(True, False)] * 5)
        self.assertEqual(outputs[8:], [(True, True)] * 4)

    def test_board_reset_restarts_full_sequence(self):
        # Reset is asynchronous and starts the full pulse/delay again.
        for old_elapsed in (0, 3, 8):
            model = StartupModel()
            model.elapsed = old_elapsed
            self.assertEqual(model.outputs(reset_n=False), (False, False))
            model.tick(reset_n=False)
            self.assertEqual(model.elapsed, 0)
            self.assertEqual(model.outputs(), (False, False))
            for _ in range(8):
                model.tick()
            self.assertEqual(model.outputs(), (True, True))

    def test_hdl_initialization_and_board_clock(self):
        text = (ROOT / 'quartus/wr_si5340_startup_reset.vhd').read_text()
        self.assertRegex(text, r'signal elapsed.*:= 0;')
        self.assertIn('elapsed < c_release', text)
        self.assertIn("if board_reset_n_i = '0' then", text)
        values = dict(re.findall(r'g_(reset|settle)_cycles : positive := (\d+)', text))
        self.assertEqual(values, {'reset': '50000', 'settle': '2500000'})
        slave = (ROOT / 'quartus/DE5a_wr_slave_jtag.vhd').read_text()
        block = slave.split('u_si_startup_reset :', 1)[1].split('u_si5340a_controller :', 1)[0]
        self.assertIn('clk_i => CLK_50_B2J', block)
        self.assertIn('SI5340A_RST_n <= si_startup_chip_reset_n;', block)
        controller = slave.split('u_si5340a_controller :', 1)[1].split('u_wr_arria10_transceiver :', 1)[0]
        self.assertRegex(controller, r'iRST_n\s*=> si_startup_controller_reset_n')
        self.assertRegex(controller, r'STEP5_BOOTSTRAP_STEPS\s*=> 3388')
        self.assertRegex(controller, r'HPLL_TRACKER_CODE_PER_PHYSICAL_STEP\s*=> 64')
        master = (ROOT / 'quartus/DE5a_wr_master_jtag.vhd').read_text()
        self.assertNotIn('u_si_startup_reset', master)
        self.assertRegex(master, r'SI5340A_RST_n\s*<= CPU_RESET_n;')


if __name__ == '__main__':
    unittest.main()
