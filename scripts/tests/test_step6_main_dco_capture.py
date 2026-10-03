import importlib.util
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
try:
    import tkinter
except ImportError:
    tkinter=None
ROOT=Path(__file__).resolve().parents[2]
BASE='eb12a587415fb0c55f620360ddb66c1066a0676b'
spec=importlib.util.spec_from_file_location('dcocap',ROOT/'scripts/analysis/step6_main_dco_capture.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode()
def without_diag(text):
    text=re.sub(r'^\s*(?://|--) MAIN_CAPTURE_DIAG_BEGIN_\w+\n.*?^\s*(?://|--) MAIN_CAPTURE_DIAG_END_\w+\n','',text,flags=re.M|re.S)
    return '\n'.join(line for line in text.splitlines() if line.strip())
def row(n=0):
    meta=(((4000000000+n*50000000)&0xffffffff)<<32)|(1<<29)|(1<<17)|(((n+1)&65535)<<1)|(n&1)
    f=dict(n=str(n),start_ms=str(100+n*1000),capture_end_ms=str(150+n*1000),
        wr_start_ms=str(150+n*1000),wr_end_ms=str(200+n*1000),
        lock_start_ms=str(200+n*1000),lock_end_ms=str(300+n*1000),end_ms=str(350+n*1000),
        META0=f'{meta:016X}',META1=f'{meta:016X}',POSITION=f'{32768:08X}{32775:08X}',
        COUNTS=f'{n:08X}{n:08X}',E0='00000002',E1='00000002',C0='00000001',C1='00000001',
        UCNT=f'{100+n:08X}',CKO='FFFFFFFE',SSTAT='00000401',
        LE0='00000002',LE1='00000002',LC0='00000001',LC1='00000001',H='00000001',M='0000000F',P='00000003',
        L2='0000000000000000',FAILED='0000000000000000',FAILURE='0000000000000000',
        LATENCY='000000000000C350',WAIT='0000000000000000',CURRENT_WAIT='0000000000000000')
    return f
def health(role):
    return f'TS4_HEALTH_OK role={role} STATUS=00000001000080df ESCR=0000000c H=00000001 M=0000000e P=00000002 RESET={{1 0 0 0 0}}'
def fixture(change=None):
    lines=['MAIN_DCO_CONFIG schema=2 samples=60 max_actual_ms=120000 control_changed=0 applied_position_is_virtual=1 cross_group_atomic=0',health('MASTER'),health('SLAVE')]
    for n in range(60):
        f=row(n)
        if change:change(n,f)
        lines.append('MAIN_DCO_CAPTURE_RAW '+' '.join(k+'='+f[k] for k in
            ('n','start_ms','capture_end_ms','META0','POSITION','COUNTS','META1')))
        lines.append('MAIN_DCO_SAMPLE '+' '.join(k+'='+v for k,v in f.items()))
    return '\n'.join(lines+['MAIN_DCO_SMOKE_PASS samples=3',health('MASTER'),health('SLAVE'),'MAIN_DCO_DONE samples=60 elapsed_ms=61000'])

class CaptureTests(unittest.TestCase):
    def result(self,text):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'trace';path.write_text(text);return mod.analyze(path)
    def test_control_source_identical_outside_private_blocks(self):
        for path in ('quartus/si5340a_controller_dco.v','quartus/DE5a_wr_master_jtag.vhd','quartus/DE5a_wr_slave_jtag.vhd'):
            self.assertEqual(without_diag((ROOT/path).read_text()),without_diag(old(path)),path)
        for path in ('firmware/configs/de5a_slave_identity.h','firmware/configs/de5a_master_identity.h',
            'scripts/analysis/step6_strict_offset_300s.py','scripts/jtag/read_step6_strict_offset_validity.tcl'):
            self.assertEqual((ROOT/path).read_text(),old(path),path)
    def test_actual_indices_unique_and_master_inactive(self):
        text=(ROOT/'quartus/DE5a_wr_slave_jtag.vhd').read_text()
        ids=re.findall(r'sld_instance_index\s*=>\s*(\d+)',text)
        self.assertEqual(len(ids),len(set(ids)))
        self.assertIn('iDIAG_MAIN_CAPTURE_TOGGLE => \'0\'',(ROOT/'quartus/DE5a_wr_master_jtag.vhd').read_text())
    def test_coherent_virtual_data_not_sustained_or_physical_pass(self):
        r=self.result(fixture());self.assertEqual(r['errors'],[])
        self.assertEqual(r['main_progress_intervals'],59)
        self.assertEqual(r['rows'][0]['residual'],7);self.assertEqual(r['rows'][0]['cko_ps'],-2)
        self.assertEqual(r['ranges']['main_max_latency_ms'],[1.0,1.0])
        self.assertEqual(r['verdict'],'PASS_DCO_ACCOUNT_DATA_ONLY')
    def test_bad_ack_schema_torn_and_partial64_rejected(self):
        for key,value in [('META1','0000000000000000'),('META0','0'),('POSITION','FFFF'),('FAILED','0000000000000001')]:
            self.assertEqual(self.result(fixture(lambda n,f:f.update({key:value}) if n==3 else None))['verdict'],'INCONCLUSIVE')
    def test_counter_reset_sequence_collision_and_loss_never_pass(self):
        for key,value in [('COUNTS','0000000000000000'),('META0',row(2)['META0']),('M','3'),('E1','3')]:
            def change(n,f):
                if n==3:
                    f[key]=value
                    if key=='META0':f['META1']=value
            self.assertEqual(self.result(fixture(change))['verdict'],'INCONCLUSIVE')
    def test_missing_deadline_and_master_health_never_pass(self):
        for text in [fixture().replace('samples=60 elapsed_ms=61000','samples=59 elapsed_ms=61000'),
                     fixture().replace('elapsed_ms=61000','elapsed_ms=120001'),
                     fixture().replace('ESCR=0000000c','ESCR=00000000'),
                     fixture()+'\nMAIN_DCO_STOP reason={timeout}']:
            self.assertEqual(self.result(text)['verdict'],'INCONCLUSIVE')
    def test_stationary_success_reported_not_removed(self):
        r=self.result(fixture(lambda n,f:f.update(COUNTS='0000000000000000')))
        self.assertEqual(r['errors'],[]);self.assertEqual(r['main_progress_intervals'],0)
        self.assertEqual(len(r['rows']),60)
    def test_unsigned_boundary_applied65536_allowed(self):
        f=row();f['POSITION']='000100000000FFFF'
        self.assertEqual(mod.decode(f)['residual'],-1)
    def test_separate_group_guards_timing_and_raw_preservation_required(self):
        for key,value in [('LE1','00000003'),('LC1','00000000'),
                          ('wr_end_ms','140'),('lock_end_ms','1000')]:
            self.assertEqual(self.result(fixture(lambda n,f:f.update({key:value}) if n==0 else None))['verdict'],'INCONCLUSIVE')
        text='\n'.join(line for line in fixture().splitlines() if not line.startswith('MAIN_DCO_CAPTURE_RAW '))
        self.assertEqual(self.result(text)['verdict'],'INCONCLUSIVE')
    @unittest.skipIf(tkinter is None,'Use native Quartus Tcl runner on Pain')
    def test_actual_native_tcl_fixture_session_ownership_and_wrong_image(self):
        t=tkinter.Tcl();t.eval('package provide ::quartus::insystem_source_probe 1.0')
        t.call('source',str(ROOT/'scripts/tests/test_step6_main_dco_capture.tcl'))
        self.assertEqual(t.eval('set ::test_active'),'0')
    @unittest.skipIf(tkinter is None,'Use native Quartus Tcl runner on Pain')
    def test_actual_tcl_capture_only_writes_private_source_and_checks_freeze(self):
        t=tkinter.Tcl();t.eval('package provide ::quartus::insystem_source_probe 1.0;set argv {};set ::dco_capture_library_only 1')
        t.call('source',str(ROOT/'scripts/jtag/read_step6_main_dco_capture.tcl'))
        t.eval('set ::test_meta 0000000020020000; set ::written {}; proc probe_word {i} {if {$i==72} {return $::test_meta}; return 0000800000008000}; proc write_source_data {args} {lappend ::written [lindex $args 1];set toggle [lindex $args 3];set ::test_meta [format %016X [expr {0x20020002 | $toggle}]]}')
        result=t.call('dco_capture');self.assertEqual(len(result),4)
        self.assertEqual(t.eval('set ::written'),'72')
        t.eval('proc dco_raw {i} {if {$i==72} {incr ::test_n; return [format %016X [expr {0x20020003+$::test_n*2}]]};return 0000000000000000};set ::test_n 0')
        with self.assertRaises(tkinter.TclError):t.call('dco_capture')
if __name__=='__main__':unittest.main()
