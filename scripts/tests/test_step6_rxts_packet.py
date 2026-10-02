import importlib.util
from pathlib import Path
import tempfile
import unittest
import ctypes
import shutil
import subprocess
try:
    import tkinter
except ImportError:
    tkinter = None
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("rxts_analysis", ROOT / "scripts/analysis/step6_rxts_packet_diagnostic.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class AnalysisTests(unittest.TestCase):
    def fixture(self):
        lines = []
        for b in ("Master", "Slave"):
            for page in range(2):
                lines.append(f"RXTS_CAPTURE_PAGE board={{{b}}} capture=0 snapshot=00000001 total=00000008 page={page} count=8")
                for i in range(page * 4, page * 4 + 4):
                    w = [i+1, i, 1, 2, 0x10001, 0, 10, 8, 4000,
                         0, 0, 10, 8, 4000, 0, 0, 0, 8000]
                    lines.append(f"RXTS_RECORD board={{{b}}} capture=0 snapshot=00000001 RXTS_V1 idx={i} words=" + " ".join(f"{x:08x}" for x in w))
            lines.append(f"RXTS_CAPTURE_DONE board={{{b}}} capture=0 snapshot=00000001 records=8")
        lines.append("RXTS_DONE completed=2 required=2 elapsed_ms=100")
        return "\n".join(lines)

    def analyze(self, text):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "capture.log"
            p.write_text(text)
            return mod.analyze(p)

    def test_complete_data(self):
        self.assertEqual(self.analyze(self.fixture())["errors"], [])

    def test_sync_followup_join_keeps_source_and_sequence(self):
        lines = self.fixture().splitlines()
        for i, line in enumerate(lines):
            if 'RXTS_V1 idx=1 words=' in line:
                prefix, data = line.split('words=')
                words = data.split()
                words[1] = '08000000'
                lines[i] = prefix + 'words=' + ' '.join(words)
        result = self.analyze('\n'.join(lines))
        self.assertEqual(result['sync_followup_forward_leg']['Slave']['matched_sync_followup_pairs'], 1)
        changed = '\n'.join(lines).replace('08000000', '08000001')
        self.assertFalse(self.analyze(changed)['sync_followup_forward_leg'])

    def test_missing_page(self):
        s = self.fixture().replace("page=1 count=8", "page=2 count=8", 1)
        self.assertIn("missing pages/records", self.analyze(s)["errors"])

    def test_changed_linearization(self):
        s = self.fixture().replace("00000fa0 00000000 00000000 00000000 00001f40", "00000fa1 00000000 00000000 00000000 00001f40", 1)
        self.assertIn("recorded linearization does not reproduce", self.analyze(s)["errors"])

    def test_stopped_session(self):
        self.assertIn("capture incomplete/stopped", self.analyze(self.fixture()+"\nRXTS_STOP reason=reset")["errors"])

    def test_second_rollover_and_edges(self):
        self.assertEqual(mod.linearize(10, 999999992, 1500, False, 1000, 8000), (11, 0, 500, True))
        self.assertEqual(mod.linearize(10, 8, 2000, True, 0, 8000), (10, 8, 2000, False))
        self.assertEqual(mod.linearize(10, 8, 6000, True, 0, 8000), (10, 8, 6000, False))

    @unittest.skipUnless(shutil.which("cc"), "Native C compiler unavailable")
    def test_actual_production_linearizer_matches_decoder(self):
        # Compile the unchanged production function body verbatim, not a
        # second hand-written C model. This temporary is a test product only.
        source = (ROOT / "vendor/wrpc-sw/lib/net.c").read_text()
        body = source.split("void ptpd_netif_linearize_rx_timestamp", 1)[1].split("/* Slow, but we don't care much... */", 1)[0]
        class Stamp(ctypes.Structure):
            _fields_ = [("sec", ctypes.c_int64)] + [(n, ctypes.c_int32) for n in
                ("nsec", "phase", "raw_phase", "raw_nsec", "raw_ahead", "correct")]
        with tempfile.TemporaryDirectory() as tmp:
            c = Path(tmp) / "linearizer.c"
            so = Path(tmp) / "linearizer.so"
            c.write_text('#include "net.h"\nvoid ptpd_netif_linearize_rx_timestamp' + body)
            subprocess.run(["cc", "-shared", "-fPIC", "-Wall", "-Wextra", "-Werror",
                "-fsanitize=undefined", "-fno-sanitize-recover=all", "-iquote",
                str(ROOT / "vendor/wrpc-sw/include"), str(c), "-o", str(so)], check=True)
            fn = ctypes.CDLL(str(so)).ptpd_netif_linearize_rx_timestamp
            fn.argtypes = [ctypes.POINTER(Stamp), ctypes.c_int32] + [ctypes.c_int] * 3
            for t24p in (0, 2389, 7050):
                for ahead in (False, True):
                    for raw_ns in (8, 999999992):
                        for phase in range(8000):
                            ts = Stamp(sec=10, nsec=raw_ns)
                            fn(ctypes.byref(ts), phase, int(ahead), t24p, 8000)
                            expected = mod.linearize(10, raw_ns, phase, ahead, t24p, 8000)
                            self.assertEqual((ts.sec, ts.nsec, ts.phase), expected[:3])


@unittest.skipIf(tkinter is None, "Tcl runtime unavailable")
class ReaderTests(unittest.TestCase):
    def setUp(self):
        self.t = tkinter.Tcl()
        self.t.eval("package provide ::quartus::insystem_source_probe 1.0; set argv {}; set ::rxts_library_only 1")
        self.t.eval("source {" + (ROOT / "scripts/jtag/read_step6_rxts_packet_diagnostic.tcl").as_posix() + "}")
        self.t.eval("set words [join [lrepeat 18 00000000] { }]; set text \"RXTS_PAGE v=1 snapshot=00000001 total=00000001 page=0 count=1\\nRXTS_V1 idx=0 words=$words\\nRXTS_END snapshot=00000001 page=0\\n\"")

    def test_complete_page(self):
        self.assertEqual(self.t.eval("lindex [rxts_parse_page $text 0 {} {}] 2"), "1")

    def test_dropped_word(self):
        self.t.eval("set text [string map {\"00000000 \" \"\"} $text]")
        with self.assertRaises(tkinter.TclError):
            self.t.eval("rxts_parse_page $text 0 {} {}")

    def test_wrong_snapshot(self):
        with self.assertRaises(tkinter.TclError):
            self.t.eval("rxts_parse_page $text 1 deadbeef 00000001")

    def test_health_detects_full_byte_reset_change(self):
        self.t.eval('''
            set ::reset 0000040302010000
            proc probe_word {idx} {
                switch $idx {
                    0 {return 00000001000080DF}
                    26 {return 0000000100000000}
                    27 {return $::reset}
                }
            }
            proc wb_read {hw addr} {
                switch $addr {
                    0x0010031C {return 0000000C}
                    0x00100ABC {return 00000001}
                    0x00100AC4 {return 0000000E}
                    0x00100A0C {return 00000002}
                }
            }
            proc puts {args} {}
            rxts_health board 1
            set ::reset 0000040304010000
        ''')
        with self.assertRaises(tkinter.TclError):
            self.t.eval("rxts_health board 1")


if __name__ == "__main__":
    unittest.main()
