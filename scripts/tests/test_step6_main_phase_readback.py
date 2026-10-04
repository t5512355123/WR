import unittest
from pathlib import Path
try:
    import tkinter
except ImportError:
    tkinter = None


@unittest.skipIf(tkinter is None, 'Run native Quartus Tcl mock tests on Pain instead')
class MainReadbackTests(unittest.TestCase):
    def setUp(self):
        self.tcl = tkinter.Tcl()
        self.tcl.eval('''
            set response_index 0
            proc s6_a_us {} {return 1000000}
            proc is_hex {v} {return [regexp {^[0-9A-Fa-f]{1,16}$} $v]}
            proc word32 {v} {
                if {![is_hex $v]} {return -1}
                set number [expr 0x$v]
                return [expr {$number & 0xffffffff}]
            }
            proc s6_a_signed32 {v} {
                set n [word32 $v]
                return [expr {$n >= 0x80000000 ? $n-0x100000000 : $n}]
            }
            proc wb_read {address} {
                lappend ::addresses $address
                set result [lindex $::responses $::response_index]
                incr ::response_index
                return $result
            }
            proc puts {args} {set ::last_line [lindex $args end]}
            proc flush {args} {}
        ''')
        self.tcl.eval(Path('scripts/jtag/step6_main_phase_readback_lib.tcl').read_text())

    def frame(self, **changes):
        values = dict(e0='00000002', magic='46344C31', vp='00000101',
            epoch='00000002', update='00000010', init='00000001',
            producer='00000002', phase='FFFFFC00', e1='00000002')
        values.update(changes)
        return list(values.values())

    def run_frame(self, frame=None, u0='00000007', u1='00000007', pair='00000007'):
        self.tcl.setvar('response_index', 0)
        frame = self.frame() if frame is None else frame
        responses = [u0] + frame * 3 + [u1]
        # A valid first attempt reads u1 immediately after that frame.
        if frame == self.frame():
            responses = [u0] + frame + [u1]
        self.tcl.setvar('responses', tuple(responses))
        self.tcl.setvar('addresses', ())
        valid = self.tcl.call('s6_main_phase_readback', 'DE5 [1-11.2]', 0, pair, 0)
        return int(valid), str(self.tcl.getvar('last_line'))

    def test_valid_negative_signed_phase(self):
        valid, line = self.run_frame()
        self.assertEqual(valid, 1)
        self.assertIn('PHASE_CURRENT_UNITS=-1024', line)
        self.assertIn('PHASE_CURRENT_PS=-1000', line)
        self.assertIn('SERVO_UPDATE_MATCH=1', line)

    def test_mismatched_publication_rejected(self):
        self.assertEqual(self.run_frame(self.frame(e1='00000004'))[0], 0)

    def test_odd_publication_rejected(self):
        self.assertEqual(self.run_frame(self.frame(e0='00000003', e1='00000003'))[0], 0)

    def test_odd_source_epoch_rejected(self):
        self.assertEqual(self.run_frame(self.frame(epoch='00000003'))[0], 0)

    def test_wrong_magic_rejected(self):
        self.assertEqual(self.run_frame(self.frame(magic='A5A50158'))[0], 0)

    def test_wrong_schema_or_page_rejected(self):
        for vp in ('00000002', '00000301'):
            self.assertEqual(self.run_frame(self.frame(vp=vp))[0], 0)
            self.tcl.setvar('response_index', 0)

    def test_uninitialized_source_rejected(self):
        self.assertEqual(self.run_frame(self.frame(epoch='00000000'))[0], 0)

    def test_invalid_payload_rejected(self):
        self.assertEqual(self.run_frame(self.frame(phase='TIMEOUT'))[0], 0)

    def test_servo_changed_is_not_same_update(self):
        valid, line = self.run_frame(u1='00000008')
        self.assertEqual(valid, 1)
        self.assertIn('SERVO_UPDATE_MATCH=0', line)

    def test_pair_changed_is_not_same_update(self):
        valid, line = self.run_frame(pair='00000006')
        self.assertEqual(valid, 1)
        self.assertIn('SERVO_UPDATE_MATCH=0', line)

    def test_read_only_mapping(self):
        self.run_frame()
        addresses = self.tcl.splitlist(self.tcl.getvar('addresses'))
        self.assertEqual(addresses[0], '0x00100A48')
        self.assertEqual(addresses[-1], '0x00100A48')
        self.assertEqual(addresses[8], '0x00100B88')
        text = Path('scripts/jtag/step6_main_phase_readback_lib.tcl').read_text()
        self.assertNotIn('wb_write', text)
        self.assertNotIn('write_source_data', text)


if __name__ == '__main__':
    unittest.main()
