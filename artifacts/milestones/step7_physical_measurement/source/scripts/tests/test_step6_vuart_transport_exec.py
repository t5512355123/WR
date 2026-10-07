"""Execute observer helpers with a Tcl interpreter and mocked hardware."""
from pathlib import Path
import unittest
try:
    import tkinter
except ImportError:
    tkinter = None

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipIf(tkinter is None, 'Tcl interpreter unavailable')
class TransportExecutionTests(unittest.TestCase):
    def setUp(self):
        self.tcl = tkinter.Tcl()
        source = (ROOT / 'scripts/jtag/read_step6_ip_vuart.tcl').read_text()
        helpers = source[source.index('proc is_hex'):source.index('set board_scope SLAVE')]
        self.tcl.eval('set poll_attempts 3; set timeout_ms 1000; array set ::wb_toggle {board 0}')
        self.tcl.eval(helpers)
        self.tcl.eval('''
            proc after {args} {}
            set ::commands {}
            set ::response 0
            set ::force_preload_race 0
            proc write_source_data {args} {
                set index [lsearch -exact $args -value]
                set value [lindex $args [expr {$index + 1}]]
                set command [expr 0x$value]
                lappend ::commands $command
                set toggle [expr {$command & 1}]
                if {$::force_preload_race} { set toggle [expr {$toggle ^ 1}] }
                set ::response [expr {($toggle << 35) | 42}]
            }
            proc read_probe_data {args} {
                return [format %08X%08X [expr {($::response >> 32) & 0xffffffff}] [expr {$::response & 0xffffffff}]]
            }
        ''')

    def test_read_preloads_then_changes_only_toggle(self):
        self.assertEqual(self.tcl.eval('wb_read board 0x00100500'), '0000002A')
        self.assertEqual(self.tcl.eval('llength $::commands'), '2')
        self.assertEqual(self.tcl.eval('expr {[lindex $::commands 0] ^ [lindex $::commands 1]}'), '1')
        self.assertEqual(self.tcl.eval('expr {([lindex $::commands 0] >> 1) & 1}'), '0')

    def test_write_preloads_identical_address_and_data(self):
        self.assertEqual(self.tcl.eval('wb_write board 0x00100510 65'), 'OK')
        self.assertEqual(self.tcl.eval('expr {[lindex $::commands 0] ^ [lindex $::commands 1]}'), '1')
        self.assertEqual(self.tcl.eval('expr {([lindex $::commands 1] >> 38) & 0xffffffff}'), '65')
        self.assertEqual(self.tcl.eval('expr {([lindex $::commands 1] >> 6) & 0xffffffff}'), str(0x100510))

    def test_full_32_bit_write_data_is_not_truncated_in_96_bit_payload(self):
        self.assertEqual(self.tcl.eval('wb_write board 0x00100510 0xffffffff'), 'OK')
        self.assertEqual(self.tcl.eval('expr {([lindex $::commands 1] >> 38) & 0xffffffff}'), str(0xffffffff))

    def test_preload_race_stops_without_commit(self):
        self.tcl.eval('set ::force_preload_race 1')
        self.assertEqual(self.tcl.eval('wb_write board 0x00100510 65'), 'TIMEOUT')
        self.assertEqual(self.tcl.eval('llength $::commands'), '1')

    def test_unstable_completion_is_rejected(self):
        self.tcl.eval('''proc read_probe_data {args} {
            incr ::response
            return [format %08X%08X [expr {($::response >> 32) & 0xffffffff}] [expr {$::response & 0xffffffff}]]
        }''')
        self.assertEqual(self.tcl.eval('wb_read board 0x00100500'), 'TIMEOUT')

    def test_pre_drain_keeps_full_pages(self):
        self.tcl.eval('''set ::pages 0
            proc read_uart_available {board limit} {
                incr ::pages
                if {$::pages == 1} { return [list LIMIT AA first] }
                return [list OK BB second]
            }''')
        self.assertEqual(self.tcl.eval('drain_preexisting_uart board 1000'), 'OK AABB firstsecond')

    def test_uart_backpressure_can_exceed_old_hundred_poll_limit(self):
        self.tcl.eval('''set ::reads 0
            proc wb_read {board addr} {
                incr ::reads
                if {$::reads <= 120} { return 00000002 }
                return 00000000
            }
            proc wb_write {board addr byte} { return OK }
            proc puts {args} {}
        ''')
        self.assertEqual(self.tcl.eval('send_vuart_command board "pll stat"'), 'OK')
        self.assertGreater(int(self.tcl.eval('set ::reads')), 120)

    def test_shell_gate_recognizes_f4l_overlay_without_fabricating_idle_stage(self):
        self.tcl.eval('''
            set ::bank_magic 0x46344c31
            set ::command_value 7849052
            set ::uart_pending 0
            proc probe_word {index} {
                switch $index {
                    26 { return 0000000100000000 }
                    33 { return 0000000000000000 }
                    35 { return 0000000200000000 }
                }
                return INVALID
            }
            proc wb_read {board addr} {
                switch $addr {
                    0x00100A14 { return 03E00000 }
                    0x00100B5C { return [format %08X $::bank_magic] }
                    0x00100BA0 { return [format %08X $::command_value] }
                    0x00100500 { return [format %08X $::uart_pending] }
                }
                return INVALID
            }
        ''')
        self.assertEqual(self.tcl.eval('stable_shell_ready board'), '1')
        diag = self.tcl.eval('set ::gate_debug(board)')
        self.assertIn('command_stage=7849052', diag)
        self.assertIn('command_stage_observable=0', diag)
        self.tcl.eval('set ::bank_magic 0')
        self.assertEqual(self.tcl.eval('stable_shell_ready board'), '0')
        self.tcl.eval('set ::command_value 0')
        self.assertEqual(self.tcl.eval('stable_shell_ready board'), '1')
        self.tcl.eval('set ::bank_magic 0x46344c31; set ::uart_pending 2')
        self.assertEqual(self.tcl.eval('stable_shell_ready board'), '0')
        self.tcl.eval('set ::uart_pending 0; set ::bank_magic 0x11111111; set ::command_value 9')
        self.assertEqual(self.tcl.eval('stable_shell_ready board'), '0')


if __name__ == '__main__':
    unittest.main()
