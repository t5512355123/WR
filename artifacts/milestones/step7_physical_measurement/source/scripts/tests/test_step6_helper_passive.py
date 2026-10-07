from pathlib import Path
import tkinter
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PassiveHelperTests(unittest.TestCase):
    def test_library_returns_before_any_hardware_work(self):
        source = (ROOT / 'scripts/jtag/read_step6_ip_vuart.tcl').read_text()
        self.assertLess(source.index('if {[info exists ::step6_vuart_library_only]'),
                        source.index('foreach hardware_name [get_hardware_names]'))

    def test_valid_and_rejected_frames_execute(self):
        source = (ROOT / 'scripts/jtag/read_step6_helper_passive.tcl').read_text()
        helpers = source[source.index('proc helper_signed32'):source.index('set boards 0')]
        tcl = tkinter.Tcl()
        tcl.eval('proc word32 {v} {if {![regexp {^[0-9a-fA-F]{8}$} $v]} {return INVALID}; return [expr 0x$v]}')
        tcl.eval('proc wb_read {board addr} {if {$addr == 0x00100B00} {return 00000002}; if {$addr == 0x00100B04} {return 00000100}; if {$addr == 0x00100B08} {return 00000101}; if {$addr == 0x00100B0C} {return FFFFFFFF}; if {$addr == 0x00100B1C} {return 0000FFFB}; return 00000001}')
        tcl.eval(helpers)
        frame = tcl.splitlist(tcl.eval('passive_helper_frame test'))
        self.assertEqual(frame[0], '1')
        self.assertEqual(frame[-2:], ('-1', '65531'))
        tcl.eval('proc wb_read {board addr} {return FFFFFFFF}')
        self.assertEqual(tcl.splitlist(tcl.eval('passive_helper_frame test'))[0], '0')

    def test_no_control_or_snapshot_writes(self):
        source = (ROOT / 'scripts/jtag/read_step6_helper_passive.tcl').read_text()
        self.assertNotIn('wb_write ', source)
        self.assertNotIn('send_vuart_command ', source)
        self.assertIn('NOT atomic', source)


if __name__ == '__main__':
    unittest.main()
