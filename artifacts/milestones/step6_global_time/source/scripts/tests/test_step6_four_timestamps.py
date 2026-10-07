import importlib.util
from pathlib import Path
import tempfile
import unittest
try:
    import tkinter
except ImportError:
    tkinter=None
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('ts4_analysis',ROOT/'scripts/analysis/step6_four_timestamps.py')
mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

def put64(w,at,value):
    v=value&((1<<64)-1); w[at]=v>>32; w[at+1]=v&0xffffffff

def puttime(w,at,value):
    sec,ns=divmod(value,mod.SCALED_PER_SEC)
    put64(w,at,sec); put64(w,at+2,ns)

def words(index=0,tai=1800000000):
    w=[0]*86
    w[:16]=[index+1,index+51,0x40004,100,101,((index+42)<<16)|(index+1000),
            0x09000001,0xff102030,0x40506070,1,index+8,2,0,1,1,1]
    t1=tai*mod.SCALED_PER_SEC+65536*100
    t2=t1+65536*177
    t3=t1+65536*100000000
    t4=t3+65536*(179+(8 if index%2 else 0))
    ts=[t1,t2,t3,t4]
    for i,t in enumerate(ts): puttime(w,16+i*4,t); puttime(w,32+i*4,t)
    rtt=(t2-t1)+(t4-t3); mean=rtt//2; cko=mean-(t2-t1)
    for at,val in ((64,rtt),(68,mean),(72,mean),(76,cko),(80,rtt)):
        puttime(w,at,val)
    return w

def page_text(index,w=None,sid='00000001',total='00000010'):
    w=words(index) if w is None else w
    return (f'TS4_PAGE v=1 snapshot={sid} total={total} page={index} count=16 words=86\n'
            f'TS4_V1 idx={index} words='+' '.join(f'{x:08x}' for x in w)+
            f'\nTS4_END snapshot={sid} page={index}\nwrc# ')

def health(role='MASTER'):
    return (f'TS4_HEALTH_OK role={role} STATUS=00000001000080df ESCR=0000000c '
            'H=00000001 M=0000000e P=00000002 RESET={1 0 0 0 0}')

def fixture():
    lines=[health(),health('SLAVE')]
    for i in range(16):
        data=page_text(i).encode('ascii').hex()
        lines.append(f'TS4_REPLY page={i} start_ms={100+i*100} end_ms={150+i*100} status=OK hex={data}')
        if i==1: lines.append('TS4_SMOKE_PASS records=2 snapshot=00000001 math_verified=1')
    return '\n'.join(lines+[health(),health('SLAVE'),'TS4_DONE records=16 elapsed_ms=2000'])

class FourStampTests(unittest.TestCase):
    def analyze(self,s):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'raw.log'; p.write_text(s); return mod.analyze(p)

    def mutate(self,index,change):
        w=words(index); change(w)
        return fixture().replace(page_text(index).encode().hex(),page_text(index,w).encode().hex())

    def test_complete_snapshot_reproduces_half_return_jump_not_pass(self):
        r=self.analyze(fixture())
        self.assertEqual(r['errors'],[])
        self.assertEqual(r['verdict'],'PASS_COHERENT_TIMESTAMP_DATA_ONLY')
        self.assertEqual(r['records'],16); self.assertEqual(r['consecutive_pairs'],15)
        step=r['large_cko_transition_pairs'][0]
        self.assertEqual(step['cko_delta_ps'],4000)
        self.assertEqual(step['raw_return_delta_ps'],8000)
        self.assertEqual(step['raw_forward_delta_ps'],0)

    def test_full_seconds_larger_than_signed64_picos(self):
        w=words(tai=2**40-1); d=mod.decode(w)
        self.assertEqual(d['raw_forward'],177000)
        self.assertGreater(mod.time_value(w,16),2**63)

    def test_negative64_setpoint_and_correct_delta_add_sub(self):
        w=words(); w[3]=0xffffffff; w[4]=0x80000000
        raw=mod.time_value(w,16); puttime(w,48,123); puttime(w,32,raw+123)
        # Corrected RTT loses123 scaled units; DMS/mean within allowed rounding.
        puttime(w,64,mod.time_value(w,64)-123)
        puttime(w,76,mod.time_value(w,76)+123)
        d=mod.decode(w); self.assertEqual(d['setp_before'],-1)
        self.assertEqual(d['setp_after'],-2**31)

    def test_torn_missing_or_wrong_records_reject(self):
        cases=[fixture().replace('TS4_REPLY page=2','TS4_REPLY page=3',1),
            fixture().replace('records=16 elapsed_ms=2000','records=15 elapsed_ms=2000'),
            fixture()+'\nTS4_STOP reason={timeout}',
            fixture().replace('elapsed_ms=2000','elapsed_ms=360001')]
        for c in cases: self.assertEqual(self.analyze(c)['verdict'],'INCONCLUSIVE')
        s=fixture().replace(page_text(3).encode().hex(),page_text(3,sid='00000002').encode().hex())
        self.assertIn('changed TS4 snapshot',self.analyze(s)['errors'])

    def test_incorrect_or_changed_math_reject(self):
        for index,value in ((16,0x8f000000),(79,1),(83,1),(35,7)):
            text=self.mutate(4,lambda w:w.__setitem__(index,value))
            self.assertEqual(self.analyze(text)['verdict'],'INCONCLUSIVE')

    def test_wrong_control_mode_and_generation_reject(self):
        for index,value in ((12,3),(13,2),(11,3),(9,0),(6,0x08000001)):
            self.assertEqual(self.analyze(self.mutate(4,lambda w:w.__setitem__(index,value)))['verdict'],'INCONCLUSIVE')

    def test_false_health_and_reset_are_not_accepted(self):
        for role,old,new in [('MASTER','H=00000001','H=00000000'),
                        ('SLAVE','M=0000000e','M=00000002'),
                        ('SLAVE','P=00000002','P=00000000'),
                        ('MASTER','STATUS=00000001000080df','STATUS=00000001000080cf'),
                        ('MASTER','ESCR=0000000c','ESCR=00000000')]:
            with self.subTest(role=role,field=old):
                changed=fixture().replace(health(role),health(role).replace(old,new),1)
                self.assertEqual(self.analyze(changed)['verdict'],'INCONCLUSIVE')
        self.assertEqual(self.analyze(fixture()+'\n'+health().replace('RESET={1','RESET={2'))['verdict'],'INCONCLUSIVE')

    def test_duplicate_updates_and_unknown_schema_reject(self):
        self.assertIn('duplicate update',self.analyze(self.mutate(4,lambda w:w.__setitem__(1,51)))['errors'])
        with self.assertRaises(ValueError): mod.parse_page(page_text(0).replace('words=86','words=85',1),0)
        with self.assertRaises(ValueError): mod.parse_page(page_text(0).replace('TS4_V1 idx=0','TS4_V1 idx=1'),0)

    def test_only_passive_hook_added_normal_feedback_restored(self):
        h=(ROOT/'vendor/wrpc-sw/include/wrh-fixed-diag.h').read_text()
        self.assertIn('#define WRH_FIXED_SETP_DIAGNOSTIC 0',h)
        c=(ROOT/'vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/wr-servo.c').read_text()
        record=c.split('static void ts_record',1)[1].split('int wr_ts_diag_show_page',1)[0]
        for banned in ('adjust_phase(', 'adjust_counters(', 'spll_set_', 'enable_timing_output(', 'pp_printf('):
            self.assertNotIn(banned,record)
        self.assertIn('gs->update_count == before_count',record)
        self.assertIn('WRPC_ARCH_I(ppi)->timingMode != WRH_TM_BOUNDARY_CLOCK',record)
        self.assertIn('ts_put_time(r + 32, &gs->t1)',record)
        self.assertIn('DWRH_FIXED_SETP_DIAGNOSTIC=1',(ROOT/'scripts/tests/run_wrh_fixed_c.sh').read_text())

@unittest.skipIf(tkinter is None,'Tcl interpreter unavailable')
class TclExecutionTests(unittest.TestCase):
    def setUp(self):
        self.tcl=tkinter.Tcl()
        code=(ROOT/'scripts/jtag/read_step6_four_timestamp_diagnostic.tcl').read_text()
        code=code[code.index('proc ts4_u32'):code.index('proc ts4_select')]
        self.tcl.eval(code)

    def parse(self,text,page=0):
        self.tcl.setvar('payload',text)
        return self.tcl.eval(f'ts4_parse_page $payload {page} "" ""')

    def test_real_tcl_math_large_tai_and_half_period(self):
        self.parse(page_text(0,words(tai=2**40-1)))
        self.parse(page_text(0))
        self.tcl.setvar('word_data',' '.join(f'{x:08x}' for x in words(1)))
        self.tcl.eval('ts4_math $word_data')

    def test_real_tcl_rejects_wrong_fixed_flag_math_and_marker(self):
        for index,value in ((12,3),(16,0x8f000000),(79,1),(83,1),(35,7)):
            w=words(); w[index]=value
            with self.assertRaises(tkinter.TclError): self.parse(page_text(0,w))

    def test_real_tcl_rejects_missing_changed_or_duplicate_record(self):
        with self.assertRaises(tkinter.TclError): self.parse(page_text(0).replace('TS4_END','NO_END'))
        text=page_text(1).replace('snapshot=00000001','snapshot=00000002')
        self.tcl.setvar('payload',text)
        with self.assertRaises(tkinter.TclError): self.tcl.eval('ts4_parse_page $payload 1 00000001 00000010')
        line=page_text(0).splitlines()[1]
        with self.assertRaises(tkinter.TclError): self.parse(page_text(0)+'\n'+line)

    def execute_capture(self,bad_page=-1,reset_page=-1):
        # Execute the actual whole observer, not a second control-flow model.
        t=tkinter.Tcl()
        t.eval('package provide ::quartus::insystem_source_probe 1.0; set argv {}; set ::ts4_library_only 1')
        script=ROOT/'scripts/jtag/read_step6_four_timestamp_diagnostic.tcl'
        t.call('source',str(script)); t.eval('unset ::ts4_library_only')
        for i in range(16):
            w=words(i)
            if i==bad_page: w[83]=1
            t.setvar(f'::fixture_page({i})',page_text(i,w))
        t.setvar('::reset_page',reset_page)
        t.eval('''
            set ::now 0; set ::selected ""; set ::page_n -1; set ::output {}
            rename clock real_clock
            proc clock {what} { if {$what eq "milliseconds"} { incr ::now 100; return $::now }; return [real_clock $what] }
            proc after {args} {}
            proc puts {args} { lappend ::output [lindex $args end] }
            proc flush {args} {}
            proc get_hardware_names {} { return [list {DE5 [1-11.1]} {DE5 [1-11.2]}] }
            proc get_device_names {args} { return [list device] }
            proc start_insystem_source_probe {args} { set ::selected [lindex $args 1] }
            proc end_insystem_source_probe {} {}
            proc wb_sync_toggle {hw} {}
            proc stable_shell_ready {hw} { return 1 }
            proc drain_preexisting_uart {hw timeout} { return [list OK "" ""] }
            proc probe_word {index} {
                switch $index {
                    0 { return 00000001000080df }
                    26 {
                        if {$::reset_page>=0 && $::page_n>=$::reset_page && [string first 1-11.2 $::selected]>=0} { return 0000000200000000 }
                        return 0000000100000000
                    }
                    27 { return 0000000000000000 }
                }
                return INVALID
            }
            proc wb_read {hw addr} {
                switch $addr {
                    0x0010031C { return 0000000c }
                    0x00100ABC { return 00000001 }
                    0x00100AC4 { return 0000000e }
                    0x00100A0C { return 00000002 }
                }
                return INVALID
            }
            proc send_vuart_command {hw command} {
                if {![regexp {^pll ts4 ([0-9]+)$} $command -> page]} { error "Unexpected control command" }
                set ::page_n $page; return OK
            }
            proc capture_vuart_reply {hw timeout} {
                set text $::fixture_page($::page_n); binary scan $text H* hex
                return [list OK $hex $text]
            }
        ''')
        code=script.read_text().split('set begin [clock milliseconds];',1)[1]
        try:
            t.eval('set begin [clock milliseconds];'+code)
            error=None
        except tkinter.TclError as exc: error=str(exc)
        return '\n'.join(t.splitlist(t.eval('set ::output'))),error

    def test_whole_observer_smoke_and_same_snapshot_extension(self):
        text,error=self.execute_capture()
        self.assertIsNone(error)
        self.assertIn('TS4_SMOKE_PASS records=2',text)
        self.assertIn('TS4_DONE records=16',text)
        r=FourStampTests().analyze(text)
        self.assertEqual(r['errors'],[])

    def test_whole_observer_stops_on_bad_math_and_reset_not_restarts(self):
        for fault in ({'bad_page':4},{'reset_page':3}):
            text,error=self.execute_capture(**fault)
            self.assertIsNotNone(error)
            self.assertIn('TS4_STOP ',text)
            self.assertNotIn('TS4_DONE records=16',text)
            self.assertEqual(FourStampTests().analyze(text)['verdict'],'INCONCLUSIVE')

if __name__=='__main__': unittest.main()
