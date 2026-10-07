import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
try:
    import tkinter
except ImportError:
    tkinter = None

ROOT = Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0, str(ROOT / 'scripts/analysis'))
import step6_main_timestamp_pair as mod


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m


ft = load('ft_fixture', ROOT / 'scripts/tests/test_step6_four_timestamps.py')
hp = load('hp_fixture', ROOT / 'scripts/tests/test_step6_phase_history.py')


def tw(serial):
    w = ft.words(serial & 15)
    w[0] = serial & 0xffffffff; w[1] = (serial + 100) & 0xffffffff
    w[2] = 0x40004; w[3] = w[4] = 12; w[10] = 9
    w[11] = 2; w[13] = 1
    return w


def pw(serial):
    a = tw(serial); w = hp.words(serial & 31)
    w[0:2] = a[0:2]; w[2:6] = a[2:5] + [a[10]]
    w[6] = a[13]; w[7] = ((serial & 0xffffffff) * 1000) & 0xffffffff
    w[8:12] = a[76:80]; w[12:16] = a[68:72]
    w[17] = w[25] = (serial * 100) & 0xffffffff
    w[28] = (serial * 7) & 0xffffffff; w[29] = (w[7] - 20) & 0xffffffff
    return w


def payload(kind, page, ttotal=64, skew=4, change=None):
    total = ttotal if kind == 'TS4' else (ttotal + skew) & 0xffffffff
    count, width = (16, 86) if kind == 'TS4' else (32, 36)
    indexes = [page] if kind == 'TS4' else [page * 2, page * 2 + 1]
    rows = []
    for i in indexes:
        serial = (total - count + i + 1) & 0xffffffff
        w = tw(serial) if kind == 'TS4' else pw(serial)
        if change: change(kind, i, w)
        rows.append(f'{kind}_V1 idx={i} words=' + ' '.join(f'{v & 0xffffffff:08x}' for v in w))
    return (f'{kind}_PAGE v=1 snapshot=00000001 total={total:08x} page={page} count={count} words={width}\n'
            + '\n'.join(rows) + f'\n{kind}_END snapshot=00000001 page={page}\nwrc# ')


def fixture(ttotal=64, skew=4, change=None):
    lines = [mod.analyze.__globals__['__doc__'] or '',
             'MTP_CONFIG ts4_records=16 phist_records=32 min_joined=12 max_actual_ms=480000 control_changed=0 cycle_atomic=0',
             ft.health('MASTER'), ft.health('SLAVE'), 'MTP_SMOKE_PASS ts4_records=1 phist_records=2 skew_updates=4']
    order = [('TS4', 0), ('PHIST', 0)] + [('PHIST', p) for p in range(1, 16)] + [('TS4', p) for p in range(1, 16)]
    for n, (kind, p) in enumerate(order):
        raw = payload(kind, p, ttotal, skew, change)
        lines.append(f'{kind}_REPLY page={p} start_ms={100+n*100} end_ms={150+n*100} status=OK hex={raw.encode().hex()}')
    return '\n'.join(lines + [ft.health('MASTER'), ft.health('SLAVE'),
                              'MTP_DONE ts4_records=16 phist_records=32 elapsed_ms=4000'])


class PairTests(unittest.TestCase):
    def result(self, text):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'raw.log'; path.write_text(text); return mod.analyze(path)

    def test_complete_exact_join_not_step6(self):
        r = self.result(fixture()); self.assertEqual(r['errors'], [])
        self.assertEqual(r['joined_rows'], 16); self.assertEqual(r['freeze_skew_updates'], 4)
        self.assertEqual(len(r['differences']), 15); self.assertIn('DATA_ONLY', r['verdict'])
        self.assertEqual(r['ranges']['tracker_age_ms'], [20, 20])

    def test_overlap_gate_and_counter_wrap(self):
        for total in (64, 0xfffffff8):
            r = self.result(fixture(total, 20)); self.assertEqual(r['errors'], [])
            self.assertEqual(r['joined_rows'], 12)
        self.assertEqual(self.result(fixture(skew=21))['verdict'], 'INCONCLUSIVE')

    def test_exact_fields_must_agree(self):
        for index in (2, 3, 4, 5, 6, 8, 11, 12, 15):
            r = self.result(fixture(change=lambda k, i, w: w.__setitem__(index, w[index] ^ 1)
                                    if k == 'PHIST' and i == 20 else None))
            self.assertEqual(r['verdict'], 'INCONCLUSIVE', index)

    def test_torn_generation_branch_math_are_not_dropped(self):
        for index, value in ((16, 0), (26, 0), (34, 3), (35, 3), (18, 4), (27, 3), (19, 0), (24, 0)):
            r = self.result(fixture(change=lambda k, i, w: w.__setitem__(index, value)
                                    if k == 'PHIST' and i == 20 else None))
            self.assertEqual(r['verdict'], 'INCONCLUSIVE')

    def test_missing_duplicate_order_deadline_and_failed_transport(self):
        for text in (fixture().replace('PHIST_REPLY page=3', 'PHIST_REPLY page=4', 1),
                     fixture().replace('status=OK hex=', 'status=TIMEOUT hex=', 1),
                     fixture().replace('elapsed_ms=4000', 'elapsed_ms=480001'),
                     fixture() + '\nMTP_STOP reason={failed}',
                     fixture().replace('P=00000002', 'P=00000000'),
                     fixture().replace('RESET={1', 'RESET={2', 1)):
            self.assertEqual(self.result(text)['verdict'], 'INCONCLUSIVE')

    def test_backward_updates_reject_stall_is_reported(self):
        r = self.result(fixture(change=lambda k, i, w: w.__setitem__(25, 0)
                                if k == 'PHIST' and i == 20 else None))
        self.assertEqual(r['verdict'], 'INCONCLUSIVE')
        r = self.result(fixture(change=lambda k, i, w: w.__setitem__(25, 100) if k == 'PHIST' else None))
        self.assertEqual(r['errors'], [])
        self.assertTrue(all(d['main_updates'] == 0 for d in r['differences']))

    def test_fifo_and_no_production_change(self):
        for kind in ('TS4', 'PHIST'):
            for p in range(16):
                raw = payload(kind, p); self.assertLess(len(raw) + raw.count('\n') + 64, 1024)
        paths = ['firmware', 'vendor', 'quartus', 'quartus_generated', 'artifacts',
                 'scripts/jtag/read_step6_strict_offset_validity.tcl',
                 'scripts/analysis/step6_strict_offset_300s.py',
                 'scripts/jtag/read_step6_phase_history.tcl',
                 'scripts/jtag/read_step6_four_timestamp_diagnostic.tcl']
        self.assertEqual(subprocess.check_output(['git', 'diff', '--name-only',
                                                 'c8460b08a3d94d0285ee4bbcf21637ad5d57f691', '--', *paths], cwd=ROOT), b'')


def tcl_setup(bad=False, skew=4):
    script = ROOT / 'scripts/jtag/read_step6_main_timestamp_pair.tcl'
    lines = ['package provide ::quartus::insystem_source_probe 1.0;set argv {};set ::mtp_library_only 1',
             f'source {{{script.as_posix()}}}', 'unset ::mtp_library_only']
    for kind in ('TS4', 'PHIST'):
        for p in range(16):
            raw = payload(kind, p, skew=skew)
            if bad and kind == 'PHIST' and p == 2: raw = raw.replace('words=36', 'words=35')
            lines.append(f'set ::payload({kind},{p}) {{{raw}}}')
    lines.append('''
set ::now 0;set ::output {};set ::events {};set ::selected ""
rename clock real_clock
proc clock {what} {if {$what eq "milliseconds"} {incr ::now 50;return $::now};return [real_clock $what]}
proc after {args} {}
proc puts {args} {lappend ::output [lindex $args end]}
proc flush {args} {}
proc get_hardware_names {} {return [list {DE5 [1-11.1]} {DE5 [1-11.2]}]}
proc get_device_names {args} {return [list device]}
proc start_insystem_source_probe {args} {set ::selected [lindex $args 1]}
proc end_insystem_source_probe {} {}
proc wb_sync_toggle {hw} {}
proc stable_shell_ready {hw} {return 1}
proc drain_preexisting_uart {hw timeout} {return [list OK "" ""]}
proc probe_word {idx} {switch $idx {0 {return 00000001000080df} 26 {return 0000000100000000} 27 {return 0000000000000000}};return INVALID}
proc wb_read {hw addr} {switch $addr {0x0010031C {return 0000000c} 0x00100ABC {return 00000001} 0x00100AC4 {return 0000000e} 0x00100A0C {return 00000002}};return INVALID}
proc send_vuart_command {hw command} {
    if {![regexp {^pll (ts4|phist) ([0-9]+)$} $command -> k p]} {error "Control command forbidden"}
    set ::key "[string toupper $k],$p";lappend ::events $command;return OK
}
proc capture_vuart_reply {hw timeout} {set text $::payload($::key);binary scan $text H* hex;return [list OK $hex $text]}
''')
    body = script.read_text().split('set begin [clock milliseconds];', 1)[1]
    lines.append('set ::error [catch {set begin [clock milliseconds];' + body + '} ::reason]')
    return '\n'.join(lines)


@unittest.skipIf(tkinter is None, 'Tcl unavailable; native Quartus fixture required')
class TclTests(unittest.TestCase):
    def run_tcl(self, **kwargs):
        t = tkinter.Tcl(); t.eval(tcl_setup(**kwargs)); return t

    def test_whole_actual_reader_freezes_once_then_pages(self):
        t = self.run_tcl(); self.assertEqual(t.eval('set ::error'), '0', t.eval('set ::reason'))
        commands = t.splitlist(t.eval('set ::events'))
        self.assertEqual(commands[:2], ('pll ts4 0', 'pll phist 0'))
        self.assertEqual(len(commands), 32); self.assertEqual(len(set(commands)), 32)
        self.assertEqual(PairTests().result('\n'.join(t.splitlist(t.eval('set ::output'))))['errors'], [])

    def test_reader_bad_schema_and_overlap_stop_no_retry(self):
        for kwargs in ({'bad': True}, {'skew': 21}):
            t = self.run_tcl(**kwargs); self.assertEqual(t.eval('set ::error'), '1')
            commands = t.splitlist(t.eval('set ::events'))
            self.assertEqual(len(commands), len(set(commands)))
            self.assertIn('MTP_STOP ', '\n'.join(t.splitlist(t.eval('set ::output'))))

    def test_options_rejected_before_hardware_calls(self):
        t = tkinter.Tcl()
        t.eval('package provide ::quartus::insystem_source_probe 1.0;set argv {unexpected};set ::mtp_library_only 1')
        with self.assertRaisesRegex(tkinter.TclError, 'No options'):
            t.call('source', str(ROOT / 'scripts/jtag/read_step6_main_timestamp_pair.tcl'))


if __name__ == '__main__':
    if len(sys.argv) in (3, 4) and sys.argv[1] == '--emit-native-tcl':
        # Generated offline fixture, not task-source edits or hardware actions.
        case = sys.argv[3] if len(sys.argv) == 4 else 'good'
        if case not in ('good', 'bad', 'skew'):
            raise ValueError('Unknown native fixture')
        code = tcl_setup(bad=case == 'bad', skew=21 if case == 'skew' else 4)
        if case == 'good':
            code += '\nif {$::error || [llength $::events]!=32} {error "Native paired reader failed: $::reason"}\n'
        else:
            code += '\nif {!$::error || [llength $::events]!=[llength [lsort -unique $::events]] || ![string match {*MTP_STOP*} $::output]} {error "Native rejection failed"}\n'
        code += f'real_puts "ACTUAL_QUARTUS_TCL_MTP=PASS hardware_session=0 case={case}"\n'
        # Rename puts before mocks so the actual CLI can display the result.
        code = code.replace('set ::now 0;', 'rename puts real_puts\nset ::now 0;', 1)
        Path(sys.argv[2]).write_text(code)
    else:
        unittest.main()
