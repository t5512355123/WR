import subprocess
import sys
import unittest
from pathlib import Path
try:
    import tkinter
except ImportError:
    tkinter = None

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/jtag/run_step6_master_rxts_role_calibration.tcl'


def setup(case='good'):
    return '''package provide ::quartus::insystem_source_probe 1.0
set argv {};set ::rxcal_library_only 1
source {%s}
unset ::rxcal_library_only
rename puts real_puts
proc puts {args} {lappend ::output [lindex $args end];return ""}
rename clock real_clock
proc clock {what} {if {$what eq "milliseconds"} {incr ::now 5;return $::now};return [real_clock $what]}
proc after {ms} {incr ::now $ms}
proc flush {args} {}
set ::now 0;set ::events {};set ::output {};set ::selected "";set ::scans 0
set ::mode(M) 2;set ::mode(S) 3;set ::role(M) master;set ::role(S) slave
set ::case %s
proc start_insystem_source_probe {args} {set ::selected [lindex $args 1]}
proc end_insystem_source_probe {} {}
proc wb_sync_toggle {hw} {}
proc probe_word {idx} {
  if {$::case eq "reset" && [llength $::events]>4 && $idx==26} {return 0000000200000000}
  switch $idx {0 {return 00000001000080df} 26 {return 0000000100000000} 27 {return 0000000000000000}}
  return INVALID
}
proc wb_read {hw addr} {
  if {$::case eq "transport" && [llength $::events]>4} {return INVALID}
  switch $addr {
    0x00100ABC {return 00000001}
    0x00100AC4 {if {($::case eq "no_lock" && $hw eq "M") || ($::case eq "preflight_lock" && $hw eq "S")} {return 00000006};return 0000000e}
    0x00100A0C {return 00000002}
    0x00100AA0 {if {$::case eq "temporary_master" && $hw eq "S" && $::mode(S)==2} {return 00030005};return [format %%08x [expr {$::mode($hw)<<16}]]}
    0x00100A98 {return 00000000}
  };return INVALID
}
proc drain_preexisting_uart {hw timeout} {if {$timeout<=0} {error "Bad budget"};return [list OK "" ""]}
proc send_vuart_command {hw command} {
  lappend ::events [list $hw $command];set ::key [list $hw $command]
  switch $command {
    {ptp master start} {set ::mode($hw) 2;set ::role($hw) master}
    {ptp slave start} {set ::mode($hw) 3;set ::role($hw) slave}
    ptp - {calibration status} {}
    default {error "Forbidden write"}
  };return OK
}
proc capture_vuart_reply {hw timeout} {
  lassign $::key hw command;set text "wrc# "
  if {$command eq "ptp"} {
    set role $::role($hw);if {$::case eq "wrong_role"} {set role gm}
    set text "running; e2e $role\\nwrc# "
  } elseif {$command eq "calibration status"} {
    if {$::mode(M)==3 && $hw eq "M"} {incr ::scans}
    set done [expr {$::scans>0 || $::case eq "old_scan"}]
    if {$::case eq "missing_scan"} {set done 0}
    if {$done} {set active 7625;set scan 9500;set state 2;set count 5;set r 7600;set f 3650} else {
      set active 2389;set scan 0;set state 0;set count 0;set r 0;set f 0
    }
    if {$::case eq "bad_midpoint" && $done} {set active 7624}
    if {$::case eq "restore_lost" && $::mode(M)==2 && $::scans>0} {set active 2389}
    set text "RXTS_DIAG active_t24p_ps=$active phase_ps=4000 ptracker_ready=1\\nRXTS_SCAN phase_ps=$scan rising_state=$state rising_count=$count rising_ps=$r falling_state=$state falling_count=$count falling_ps=$f\\nwrc# "
    if {$::case eq "duplicate"} {append text $text}
  }
  binary scan $text H* hex;return [list OK $hex $text]
}
set ::error [catch {rxcal_run {M device MASTER} {S device SLAVE}} ::reason]
''' % (SCRIPT.as_posix(), case)


def validate_code(case):
    # Runs against the actual Tcl operator, not a Python rewrite.
    if case == 'good':
        checks = '''if {$::error || $::role(M) ne "master" || $::role(S) ne "slave" ||
          $::events ne {{M {calibration status}} {S {ptp master start}} {S ptp} {M {ptp slave start}} {M ptp} {M {calibration status}} {M {calibration status}} {M {ptp master start}} {M ptp} {S {ptp slave start}} {S ptp} {M {calibration status}}}} {error "Good role-cal fixture failed: $::reason; $::events"}'''
    else:
        checks = 'if {!$::error} {error "Invalid calibration accepted"}\n'
        if case in ('old_scan', 'duplicate', 'preflight_lock'):
            checks += 'foreach e $::events {if {[lindex $e 1] ni {ptp {calibration status}}} {error "Preflight mutated roles"}}\n'
        elif case in ('reset', 'transport'):
            checks += 'if {[string match {*RXCAL_RESTORE roles_verified*} $::output]} {error "Untrusted restore write"}\n'
        else:
            checks += 'if {$::role(M) ne "master" || $::role(S) ne "slave"} {error "Failed cal not restored"}\n'
        checks += '''foreach hw {M S} {foreach cmd {{ptp master start} {ptp slave start}} {
          set n 0;foreach e $::events {if {$e eq [list $hw $cmd]} {incr n}};if {$n>1} {error "Control retry"}
        }}'''
    return checks + '\nreal_puts "ACTUAL_QUARTUS_RXCAL=PASS hardware_session=0 case=%s"\n' % case


CASES = ('good', 'old_scan', 'duplicate', 'preflight_lock', 'no_lock', 'missing_scan', 'bad_midpoint',
         'temporary_master', 'wrong_role', 'reset', 'transport', 'restore_lost')


class SourceTests(unittest.TestCase):
    def test_only_add_read_only_dispatch(self):
        path = 'vendor/wrpc-sw/shell/cmd_calib.c'
        original = subprocess.check_output(['git', 'show', '6b27b5e9:' + path], cwd=ROOT).decode()
        current = (ROOT / path).read_text()
        begin = current.index('\t/* Read-only, bounded status:')
        end = current.index('\n\tif (!args[0])', begin)
        projected = current[:begin] + current[end+1:]
        projected = projected.replace('#include <errno.h>\n', '')
        self.assertEqual(projected, original)
        self.assertEqual(subprocess.check_output(['git', 'diff', '--name-only', '6b27b5e9', '--',
                         'quartus', 'quartus_generated', 'firmware/configs',
                         'vendor/wrpc-sw/softpll', 'vendor/wrpc-sw/dev/rxts_calibrator.c',
                         'vendor/wrpc-sw/ppsi'], cwd=ROOT), b'')


@unittest.skipIf(tkinter is None, 'Use generated native Quartus Tcl fixtures')
class TclTests(unittest.TestCase):
    def test_actual_whole_operator(self):
        for case in CASES:
            with self.subTest(case=case):
                t = tkinter.Tcl(); t.eval(setup(case)); t.eval(validate_code(case))
                self.assertLessEqual(int(t.eval('set ::now')), 600000)
                raw = '\n'.join(t.splitlist(t.eval('set ::output')))
                self.assertNotIn('goal_pass=1', raw)
                if case == 'missing_scan':
                    self.assertTrue('No qualified actual calibration in240s' in raw or
                                    'RXCAL actual deadline reached' in raw)

    def test_midpoint_c_truncation_and_invalid_status(self):
        t = tkinter.Tcl(); t.eval('package provide ::quartus::insystem_source_probe 1.0;set argv {};set ::rxcal_library_only 1')
        t.call('source', str(SCRIPT))
        text = 'RXTS_DIAG active_t24p_ps=6001 phase_ps=0 ptracker_ready=1\nRXTS_SCAN phase_ps=9500 rising_state=2 rising_count=5 rising_ps=0 falling_state=2 falling_count=5 falling_ps=1\n'
        self.assertEqual(int(t.call('rxcal_measured', t.call('rxcal_status', text))), 1)
        for value in (text.replace('6001', '6000'), text.replace('9500', '9600'),
                      text.replace('rising_count=5', 'rising_count=6'), text + text,
                      text.replace('6001', '8000')):
            with self.assertRaises(tkinter.TclError): t.call('rxcal_measured', t.call('rxcal_status', value))

    def test_commands_and_options_before_io(self):
        t = tkinter.Tcl(); t.eval('package provide ::quartus::insystem_source_probe 1.0;set argv {unexpected};set ::rxcal_library_only 1')
        with self.assertRaisesRegex(tkinter.TclError, 'No options'): t.call('source', str(SCRIPT))
        t.eval('set argv {}'); t.call('source', str(SCRIPT))
        for cmd in ('calibration', 'calibration force', 'calibration setp T24P 4000', 'pll sps 4000', 'ptp stop'):
            with self.assertRaisesRegex(tkinter.TclError, 'Non-allowlisted'): t.call('rxcal_command', 'M device MASTER', cmd)


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--emit-native-tcl':
        case = sys.argv[3]
        if case not in CASES: raise ValueError(case)
        Path(sys.argv[2]).write_text(setup(case) + validate_code(case))
    else:
        unittest.main()
