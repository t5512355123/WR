import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts/analysis'))
spec=importlib.util.spec_from_file_location('fixed',ROOT/'scripts/analysis/step6_fixed_setp.py')
fixed=importlib.util.module_from_spec(spec); spec.loader.exec_module(fixed)
from scripts.tests.test_step6_strict_offset_300s import row

class FixedAnalysisTests(unittest.TestCase):
    def run_capture(self,changed='',short=False):
        with tempfile.TemporaryDirectory() as directory:
            d=Path(directory)
            before='FIXED_V1 enabled=1 latched=1 entry=0 writes=10 inits=1 revoked=0 setp=100 spll_init=1 current=100 target=100\r\n'
            after=before.replace('revoked=0','revoked=1')
            if changed: after=after.replace(changed.split(':')[0],changed.split(':')[1])
            for name,text in [('before',before),('after',after)]:
                (d/name).write_text('STEP6_VUART_QUERY_RESULT board=slave status=OK reply_hex='+text.encode().hex()+'\nSTEP6_VUART_POSTFLIGHT reset_changed=0\n')
            rows=[row(n,200,time_valid=0)+f' SETP_RAW=00000064 SETP_UCNT={n:08X} SETP_EPOCH_BEFORE=00000001 SETP_EPOCH_AFTER=00000001 DMS_HI=00000000 DMS_LO=000186A0 DMS_UCNT={n:08X} DMS_EPOCH_BEFORE=00000002 DMS_EPOCH_AFTER=00000002 SPLL_INIT=00000001'
                  for n in range(30 if short else 61)]
            (d/'capture').write_text('\n'.join(rows)+'\nS6_STRICT_DONE timeout_count=0 invalid_count=0\n')
            return fixed.analyze(d/'capture',d/'before',d/'after')
    def test_constant_setpoint_invalid_time_is_diagnostic_not_goal_pass(self):
        result=self.run_capture()
        self.assertEqual(result['verdict'],'PASS_FIXED_SETP_DIAGNOSTIC_ONLY')
        self.assertEqual(result['strict_goal']['verdict'],'NOT_ESTABLISHED')
    def test_phase_write_or_reinit_breaks_invariant(self):
        for change in ('writes=10:writes=11','inits=1:inits=2',
                       'spll_init=1:spll_init=2','target=100:target=101'):
            self.assertEqual(self.run_capture(change)['verdict'],'INCONCLUSIVE')
    def test_short_capture_cannot_pass(self):
        self.assertEqual(self.run_capture(short=True)['verdict'],'INCONCLUSIVE')

if __name__=='__main__': unittest.main()
