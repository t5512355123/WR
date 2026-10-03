import importlib.util
import tempfile
import unittest
from pathlib import Path
try:
    import tkinter
except ImportError:
    tkinter=None
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('phist',ROOT/'scripts/analysis/step6_phase_history.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

def words(i):
    w=[0]*36
    w[:8]=[i+1,100+i,0x40004,12,12,9,1,1000+i*125]
    w[10]=w[11]=0xffffffff # signed64 -1 scaled-ns, not truncated int32 ps
    w[15]=10000
    w[16:26]=[1,100+i*10,1,2,(-200)&0xffffffff,2,(-4)&0xffffffff,32768,1,101+i*10]
    w[26:36]=[1,2,i+10,w[7]-20,123,3,1000,1123,20+i*2,10+i*2]
    return w
def page(p,change=None):
    rows=[]
    for i in range(p*2,p*2+2):
        w=words(i)
        if change: change(i,w)
        rows.append(f'PHIST_V1 idx={i} words='+' '.join(f'{x:08x}' for x in w))
    return f'PHIST_PAGE v=1 snapshot=00000001 total=00000020 page={p} count=32 words=36\n'+'\n'.join(rows)+f'\nPHIST_END snapshot=00000001 page={p}\nwrc# '
def health(role):
    return f'TS4_HEALTH_OK role={role} STATUS=00000001000080df ESCR=0000000c H=00000001 M=0000000e P=00000002 RESET={{1 0 0 0 0}}'
def fixture(change=None):
    lines=[health('MASTER'),health('SLAVE'),'PHIST_SMOKE_PASS records=2 snapshot=00000001']
    for p in range(16):lines.append(f'PHIST_REPLY page={p} start_ms={100+p*100} end_ms={150+p*100} status=OK hex={page(p,change).encode().hex()}')
    return '\n'.join(lines+[health('MASTER'),health('SLAVE'),'PHIST_DONE records=32 elapsed_ms=2000'])
class HistoryTests(unittest.TestCase):
    def result(self,text):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'raw.log';p.write_text(text);return mod.analyze(p)
    def test_signed_conversion_progress_and_not_step6_pass(self):
        r=self.result(fixture());self.assertEqual(r['errors'],[])
        self.assertEqual(r['main_progress_pairs'],31);self.assertEqual(r['tracker_progress_pairs'],31)
        self.assertEqual(r['rows'][0]['cko_ps'],-1000/65536)
        self.assertEqual(r['rows'][0]['main_error_ps'],-200*16000/16384)
        self.assertEqual(r['rows'][0]['tracker_phase_ps'],120)
        self.assertIn('DATA_ONLY',r['verdict'])
    def test_bad_group_and_generation_never_pass(self):
        for idx,value in ((16,0),(26,0),(34,3),(35,3),(6,2),(18,2),(27,3)):
            r=self.result(fixture(lambda i,w:w.__setitem__(idx,value) if i==1 else None))
            self.assertEqual(r['verdict'],'INCONCLUSIVE')
    def test_stalled_main_is_reported_not_silently_removed(self):
        r=self.result(fixture(lambda i,w:w.__setitem__(25,100)))
        self.assertEqual(r['errors'],[]);self.assertEqual(r['main_progress_pairs'],0)
        self.assertEqual(len(r['rows']),32)
    def test_missing_duplicate_deadline_health(self):
        for text in (fixture().replace('page=4 start','page=5 start'),
                     fixture().replace('elapsed_ms=2000','elapsed_ms=240001'),
                     fixture()+'\nPHIST_STOP reason={timeout}',
                     fixture().replace('role=MASTER','role=UNKNOWN'),
                     fixture().replace('P=00000002','P=00000000')):
            self.assertEqual(self.result(text)['verdict'],'INCONCLUSIVE')
    def test_fifo_worst_page(self):
        for p in range(16):
            text=page(p);self.assertLess(len(text)+text.count('\n')+64,1024)
    def test_control_source_not_modified(self):
        text=(ROOT/'vendor/wrpc-sw/lib/phase-history.c').read_text()
        for forbidden in ('adjust_phase(', 'spll_set_', 'enable_timing_output(', 'disable_irq(', 'pi_update('):
            self.assertNotIn(forbidden,text)
        self.assertNotIn('spll_ptracker_diag_frame',(ROOT/'vendor/wrpc-sw/softpll/spll_ptracker.h').read_text())

@unittest.skipIf(tkinter is None,'Tcl unavailable')
class TclTests(unittest.TestCase):
    def execute(self,bad_page=-1):
        t=tkinter.Tcl();script=ROOT/'scripts/jtag/read_step6_phase_history.tcl'
        t.eval('package provide ::quartus::insystem_source_probe 1.0;set argv {};set ::phist_library_only 1')
        t.call('source',str(script));t.eval('unset ::phist_library_only')
        for p in range(16):
            payload=page(p)
            if p==bad_page:payload=payload.replace('words=36','words=35')
            t.setvar(f'::payload({p})',payload)
        t.eval('''
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
                if {![regexp {^pll phist ([0-9]+)$} $command -> p]} {error "Control command forbidden"}
                set ::page $p;lappend ::events $command;return OK
            }
            proc capture_vuart_reply {hw timeout} {set text $::payload($::page);binary scan $text H* hex;return [list OK $hex $text]}
        ''')
        body=script.read_text().split('set begin [clock milliseconds];',1)[1]
        try:t.eval('set begin [clock milliseconds];'+body);error=None
        except tkinter.TclError as exc:error=str(exc)
        return '\n'.join(t.splitlist(t.eval('set ::output'))),error,t.splitlist(t.eval('set ::events'))
    def test_whole_actual_observer_one_freeze_and_frozen_pages(self):
        text,error,events=self.execute();self.assertIsNone(error)
        self.assertEqual(HistoryTests().result(text)['errors'],[])
        self.assertEqual(list(events),[f'pll phist {i}' for i in range(16)])
    def test_bad_schema_stops_without_retry(self):
        text,error,events=self.execute(2);self.assertIsNotNone(error)
        self.assertIn('PHIST_STOP ',text);self.assertEqual(len(events),3)
        self.assertEqual(HistoryTests().result(text)['verdict'],'INCONCLUSIVE')
if __name__=='__main__':unittest.main()
