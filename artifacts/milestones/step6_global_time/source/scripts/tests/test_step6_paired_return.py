import importlib.util
import json
import re
import tempfile
import unittest
from pathlib import Path
try:
    import tkinter
except ImportError:
    tkinter=None

ROOT=Path(__file__).resolve().parents[2]

def module(name,path):
    s=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

mod=module('paired',ROOT/'scripts/analysis/step6_paired_return_provenance.py')
ft=module('four_fixture',ROOT/'scripts/tests/test_step6_four_timestamps.py')
MASTER_MAC='02:00:22:33:30:01'
SLAVE_MAC='02:00:22:33:30:02'
MASTER_ID='020022fffe333001'
SLAVE_ID='020022fffe333002'

def slave_words(i,tai=1800000000):
    w=ft.words(i,tai)
    # Shift ALL absolute stamps, not relative delays, across real-second wraps.
    for at in range(16,48,4):
        ft.puttime(w,at,mod.four.time_value(w,at)+i*125000000*65536)
    w[7]=int(MASTER_ID[:8],16);w[8]=int(MASTER_ID[8:],16)
    w[3]=w[4]=100
    return w

def master_words(j,tai=1800000000):
    i=j-16; sw=slave_words(i,tai); t4=mod.four.time_value(sw,28)
    sec,scaled=divmod(t4,mod.four.SCALED_PER_SEC); ns=scaled//65536
    ahead=not(i%2)
    # falling branch: phase_r0, phase_f4000+4000 wraps; ahead cancels+8ns.
    raw_ns=ns-(0 if ahead else 8)
    w=[j+1,0x01000000|(984+j),int(SLAVE_ID[:8],16),int(SLAVE_ID[8:],16),
       1|(1<<16)|(int(ahead)<<17)|(1<<18),sec>>32,sec&0xffffffff,raw_ns,
       1000,1000,sec>>32,sec&0xffffffff,ns,0,0,0,0,8000]
    return w

def master_page(p,change=None,tai=1800000000):
    rows=[]
    for j in range(p*4,p*4+4):
        w=master_words(j,tai)
        if change: change(j,w)
        rows.append(f'RXTS_V1 idx={j} words='+' '.join(f'{x&0xffffffff:08x}' for x in w))
    return f'RXTS_PAGE v=1 snapshot=00000001 total=00000020 page={p} count=32\n'+'\n'.join(rows)+f'\nRXTS_END snapshot=00000001 page={p}\nwrc# '

def slave_page(i,tai=1800000000):
    return ft.page_text(i,slave_words(i,tai))

def identities():
    lines=[]
    for role,mac,cid in [('MASTER',MASTER_MAC,MASTER_ID),('SLAVE',SLAVE_MAC,SLAVE_ID)]:
        payload=f'MAC-address: {mac}\nwrc# '.encode().hex()
        lines += [f'PAIR_MAC_REPLY role={role} status=OK hex={payload}',
                  f'PAIR_ID role={role} mac={mac} clockid={cid} port=1']
    return lines

def fixture(change=None,tai=1800000000):
    lines=identities()+[ft.health(),ft.health('SLAVE'),
       'PAIR_FREEZE_REQUEST role=SLAVE kind=TS4 start_ms=100 end_ms=120',
       'PAIR_FREEZE_REQUEST role=MASTER kind=RXTS start_ms=140 end_ms=160',
       'PAIR_SMOKE_PASS master_rows=4 slave_rows=1 rx_snapshot=00000001 ts_snapshot=00000001']
    for p in range(8):
        raw=master_page(p,change,tai).encode().hex()
        lines.append(f'RXTS_REPLY board={{DE5 [1-11.1]}} capture=0 page={p} start_ms={200+p*100} end_ms={250+p*100} status=OK hex={raw}')
    for p in range(16):
        lines.append(f'TS4_REPLY page={p} start_ms={1000+p*100} end_ms={1050+p*100} status=OK hex={slave_page(p,tai).encode().hex()}')
        if p==1: lines.append('TS4_SMOKE_PASS records=2 snapshot=00000001 math_verified=1')
    return '\n'.join(lines+[ft.health(),ft.health('SLAVE'),
       'TS4_DONE records=16 elapsed_ms=3000',
       'PAIR_DONE master_records=32 slave_records=16 elapsed_ms=3000'])

class PairedTests(unittest.TestCase):
    def result(self,trace):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'raw.log';path.write_text(trace);return mod.analyze(path)

    def test_exact_pair_and_eight_ns_linearizer_step_not_step6_pass(self):
        r=self.result(fixture());self.assertEqual(r['errors'],[])
        self.assertEqual(r['verdict'],'PASS_PAIRED_RETURN_DATA_ONLY')
        self.assertEqual(r['paired_updates'],16);self.assertEqual(r['consecutive_paired_differences'],15)
        step=r['large_cko_transition_pairs'][0]
        self.assertEqual(step['cko_delta_ps'],4000)
        self.assertEqual(step['linearization_correction_delta_ps'],8000)
        self.assertEqual(step['coarse_return_delta_ps'],0)
        self.assertEqual(step['setp_current_action_ps'],0)

    def test_high_tai_preserves_full_seconds_and_overlaps(self):
        self.assertEqual(self.result(fixture(tai=2**39+55))['errors'],[])

    def test_raw_mac_not_fallback_and_source_port_domain_bound(self):
        for trace in [fixture().replace('clockid='+MASTER_ID,'clockid='+SLAVE_ID),
                fixture(lambda j,w:w.__setitem__(2,0x040022ff)),
                fixture(lambda j,w:w.__setitem__(4,w[4]+1)),
                fixture(lambda j,w:w.__setitem__(1,w[1]+0x10000))]:
            self.assertEqual(self.result(trace)['verdict'],'INCONCLUSIVE')

    def test_same_sequence_wrong_whole_time_or_incorrect_stamp_rejects(self):
        def shift(j,w):
            if j==16: w[7]+=8;w[12]+=8
        r=self.result(fixture(shift))
        self.assertIn('same-sequence Master RX != accepted Slave raw T4',r['errors'])
        r=self.result(fixture(lambda j,w:w.__setitem__(4,w[4]&~(1<<16))))
        self.assertIn('paired Master RX marked incorrect',r['errors'])

    def test_wrong_math_missing_duplicate_pages_never_complete(self):
        cases=[fixture(lambda j,w:w.__setitem__(13,7)),
               fixture().replace('capture=0 page=3','capture=0 page=4',1),
               fixture().replace('master_records=32','master_records=31'),
               fixture()+'\nPAIR_STOP reason={timeout}',
               fixture().replace('elapsed_ms=3000','elapsed_ms=360001')]
        for case in cases: self.assertEqual(self.result(case)['verdict'],'INCONCLUSIVE')

    def test_no_forced_pairing_of_nonoverlapping_history(self):
        r=self.result(fixture(lambda j,w:w.__setitem__(1,w[1]+100)))
        self.assertEqual(r['paired_updates'],0)
        self.assertIn('fewer than8 exact paired accepted updates',r['errors'])

    def test_partial_overlap_exact_eight_pair_boundary(self):
        def missing_before(boundary):
            return lambda j,w: w.__setitem__(1,w[1]+100) if j<boundary else None
        enough=self.result(fixture(missing_before(24)))
        self.assertEqual(enough['errors'],[])
        self.assertEqual(enough['paired_updates'],8)
        self.assertEqual(enough['unpaired_slave_updates'],8)
        self.assertEqual(enough['consecutive_paired_differences'],7)
        short=self.result(fixture(missing_before(25)))
        self.assertEqual(short['paired_updates'],7)
        self.assertIn('fewer than8 exact paired accepted updates',short['errors'])

    def test_unrelated_historical_snapshots_cannot_be_joined(self):
        # Old complete TS4 evidence alone lacks the live peer and Master RX history.
        r=self.result(ft.fixture());self.assertEqual(r['verdict'],'INCONCLUSIVE')
        self.assertIn('incomplete32 Master history',r['errors'])

    def test_fifo_bounds_with_shell_echo_crlf_and_prompt(self):
        for payload in [master_page(0),master_page(7)]+[slave_page(i) for i in range(16)]:
            # Includes fixture prompt plus conservative echo and newline expansion.
            self.assertLess(len(payload.encode())+payload.count('\n')+64,1024)
        core=(ROOT/'vendor/wr-cores/modules/wrc_core/wr_core.vhd').read_text()
        self.assertRegex(core,r'g_vuart_fifo_size\s*: integer\s*:= 1024')
        for role in ('master','slave'):
            top=(ROOT/f'quartus/DE5a_wr_{role}_jtag.vhd').read_text()
            self.assertIn('g_virtual_uart              => true',top)
            self.assertNotRegex(top,r'g_vuart_fifo_size\s*=>')

@unittest.skipIf(tkinter is None,'Tcl unavailable')
class WholeObserverTests(unittest.TestCase):
    def execute(self,bad_page=-1,reset_page=-1):
        t=tkinter.Tcl();script=ROOT/'scripts/jtag/read_step6_paired_return_provenance.tcl'
        t.eval('package provide ::quartus::insystem_source_probe 1.0; set argv {}; set ::pair_library_only 1')
        t.call('source',str(script));t.eval('unset ::pair_library_only')
        for p in range(8):
            text=master_page(p)
            if p==bad_page: text=text.replace('00001f40','00001f41',1)
            t.setvar(f'::rx_payload({p})',text)
        for p in range(16): t.setvar(f'::ts_payload({p})',slave_page(p))
        t.setvar('::reset_page',reset_page)
        t.eval('''
            set ::now 0; set ::selected ""; set ::output {}; set ::events {}; set ::ts_page -1
            rename clock real_clock
            proc clock {what} { if {$what eq "milliseconds"} { incr ::now 20; return $::now }; return [real_clock $what] }
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
                        if {$::reset_page>=0 && $::ts_page>=$::reset_page && [string first 1-11.2 $::selected]>=0} { return 0000000200000000 }
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
                if {$command ne "mac get" && ![regexp {^pll (ts4|rxts) ([0-9]+)$} $command -> kind page]} { error "Unexpected control command" }
                set ::pending($hw) $command
                lappend ::events [list SEND $hw $command]
                if {$command ne "mac get" && $kind eq "ts4"} { set ::ts_page $page }
                return OK
            }
            proc capture_vuart_reply {hw timeout} {
                set command $::pending($hw); lappend ::events [list READ $hw $command]
                if {$command eq "mac get"} {
                    set last [format %02x [expr {[string first 1-11.1 $hw]>=0 ? 1 : 2}]]
                    set text "MAC-address: 02:00:22:33:30:$last\\nwrc# "
                } else {
                    regexp {^pll (ts4|rxts) ([0-9]+)$} $command -> kind page
                    if {$kind eq "ts4"} {set text $::ts_payload($page)} else {set text $::rx_payload($page)}
                }
                binary scan $text H* hex; return [list OK $hex $text]
            }
        ''')
        body=script.read_text().split('set begin [clock milliseconds];',1)[1]
        try: t.eval('set begin [clock milliseconds];'+body);error=None
        except tkinter.TclError as exc: error=str(exc)
        return '\n'.join(t.splitlist(t.eval('set ::output'))),error,t.splitlist(t.eval('set ::events'))

    def test_actual_whole_observer_primes_both_before_any_page_read(self):
        text,error,events=self.execute();self.assertIsNone(error)
        result=PairedTests().result(text);self.assertEqual(result['errors'],[])
        events=[str(e) for e in events]
        first_read=next(i for i,e in enumerate(events) if e.startswith('READ') and 'pll' in e)
        primes=[e for e in events[:first_read] if e.startswith('SEND') and 'pll' in e]
        self.assertEqual(len(primes),2);self.assertIn('ts4 0',primes[0]);self.assertIn('rxts 0',primes[1])
        self.assertEqual(sum('SEND' in e and 'ts4 0' in e for e in events),1)
        self.assertEqual(sum('SEND' in e and 'rxts 0' in e for e in events),1)

    def test_actual_observer_stops_on_bad_math_and_reset_no_restart(self):
        for fault in ({'bad_page':2},{'reset_page':3}):
            text,error,events=self.execute(**fault);self.assertIsNotNone(error)
            self.assertIn('PAIR_STOP ',text)
            self.assertIn('Invalid RX scale/calibration' if 'bad_page' in fault else 'Reset identity changed',error)
            self.assertEqual(PairedTests().result(text)['verdict'],'INCONCLUSIVE')

if __name__=='__main__':unittest.main()
