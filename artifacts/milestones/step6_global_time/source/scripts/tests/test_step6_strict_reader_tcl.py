"""Run the actual Tcl reader against a deterministic no-hardware transport."""
from pathlib import Path
import unittest
import tkinter
ROOT=Path(__file__).resolve().parents[2]

class StrictReaderTests(unittest.TestCase):
    def test_actual_reader_parses_and_reports_strict_health(self):
        t=tkinter.Tcl()
        # Use the real shared parser/bit routines, not mocks of their packing.
        t.eval("package provide ::quartus::insystem_source_probe 1.0; set ::wb_library_mode 1")
        t.eval((ROOT/"scripts/jtag/read_wb_runtime.tcl").read_text())
        t.eval(r'''
          rename source original_source
          proc source {args} { return }
          rename puts original_puts
          proc puts {args} { lappend ::emitted [lindex $args end] }
          proc get_hardware_names {} { return [list {DE5 [1-11.1]} {DE5 [1-11.2]}] }
          proc get_device_names {args} { return [list {device}] }
          proc start_insystem_source_probe {args} {}
          proc end_insystem_source_probe {args} {}
          rename wb_sync_toggle original_sync
          proc wb_sync_toggle {} {}
          rename wb_read original_read
          proc wb_read {addr} {
            switch -- $addr {
              0x00100B34 {return 00000001}
              0x00100B38 {return 0000FFFE}
              0x00100A04 {return 00000001}
              0x00100A48 {return 00000001}
              0x00100A40 {return 0000003B}
              0x00100A08 {return 00000401}
              0x00100A44 {return 00000064}
              0x00100A34 {return 00000000}
              0x00100A38 {return 000186A0}
              0x00100B44 {return 00000001}
              0x00100ABC {return 00000001}
              0x00100AC4 {return 0000000E}
              0x00100A0C {return 00000002}
              0x0010031C {return 0000000C}
            }
            error "unexpected address $addr"
          }
          rename safe_probe_read original_probe
          proc safe_probe_read {index} {
            switch -- $index {
              0 {return 00000001000080DF}
              26 {return 0000000100000000}
              27 {return 0000040302010000}
            }
            error "unexpected probe $index"
          }
          set ::emitted {}; set argv {3 1 1-11.2}
        ''')
        t.eval((ROOT/"scripts/jtag/read_step6_strict_offset_validity.tcl").read_text())
        output=t.splitlist(t.getvar("emitted"))
        rows=[line for line in output if line.startswith("S6_STRICT_SAMPLE ")]
        self.assertTrue(rows)
        self.assertIn("FRAME_VALID=1",rows[0])
        self.assertIn("TIME_VALID=1",rows[0])
        self.assertIn("STEP1_GATE=1",rows[0])
        self.assertIn("LOCK_GATE=1",rows[0])
        self.assertIn("MASTER_TIME_VALID=1",rows[0])
        self.assertTrue(any(line.startswith("S6_STRICT_MASTER_SAMPLE ") for line in output))
        self.assertIn("RESET_SIGNATURE={00000001 00000001 00000002 00000003 00000004}",rows[0])
        self.assertTrue(output[-1].startswith("S6_STRICT_DONE "))
        self.assertEqual(t.eval("strict_byte 0000040302010000 24"),"00000002")
        # Execute the actual fixed-mode loop again: changed phase setpoint must
        # stop immediately, rather than being hidden by stable live lock bits.
        t.eval(r'''
          rename wb_read first_mock_read
          proc wb_read {addr} {
            if {$addr eq "0x00100A44"} {
              incr ::setp_reads
              return [format %08X [expr {100+($::setp_reads>1)}]]
            }
            return [first_mock_read $addr]
          }
          set ::emitted {}; set ::setp_reads 0; set argv {100 1 1-11.2 1}
        ''')
        t.eval((ROOT/"scripts/jtag/read_step6_strict_offset_validity.tcl").read_text())
        changed=t.splitlist(t.getvar("emitted"))
        self.assertTrue(any('reason=fixed_diagnostic_invariant_or_health' in line
                            for line in changed))

if __name__=="__main__": unittest.main()
