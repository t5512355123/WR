from scripts.analysis.step6_post_settling_cko import analyze,GUARDS,LOCKS
import unittest

def capture(offset=20,duplicate=False,invalid=False,reset=False,short=False):
    lines=[]; count=305 if not short else 20
    for i in range(count):
        row={k:'1' for k in GUARDS+LOCKS}
        row.update(PHASE_CONTEXT='1',RESET_CHANGED='0',BOOT_GENERATION='00000001',
                   CPU_RESET_COUNT='00',WR_CORE_RESET_COUNT='00',SI_CONFIG_DROP_COUNT='00',
                   UCNT=f'{0 if duplicate else i:08x}',PHASE_CONTEXT_UCNT=f'{0 if duplicate else i:08x}',elapsed_ms=str(i*1000),
                   CKO_PS=str(offset),SERVO_STATE='4',SETP_PS='100',DMS_PS='170000',
                   STATUS_TIME_VALID='1',STEP1_GATE='1')
        if invalid: row['DIAG_FRAME_VALID']='0'
        if reset and i==count-1: row['BOOT_GENERATION']='00000002'
        lines.append('S6_INTERLEAVED_SAMPLE board=DE5 [1-11.2] '+' '.join(f'{k}={v}' for k,v in row.items()))
    lines.append(f'S6_INTERLEAVED_BOARD_DONE board=DE5 [1-11.2] samples={count} elapsed_ms={count*1000} reset_stop=0 invalid_streak=0')
    return '\n'.join(lines)

class CkoTests(unittest.TestCase):
    def test_inband_stable(self):
        result=analyze(capture()); self.assertTrue(result['capture_complete'])
        self.assertEqual(result['cko_stable_within_120ps_300s'],'SUPPORTED_AT_SAMPLED_UPDATES')
    def test_large_cko_does_not_revoke_time_valid(self):
        result=analyze(capture(2000)); self.assertEqual(result['time_valid_unique_rows'],305)
        self.assertEqual(result['cko_stable_within_120ps_300s'],'NOT_ESTABLISHED')
    def test_duplicates_not_fresh(self): self.assertFalse(analyze(capture(duplicate=True))['capture_complete'])
    def test_short_not_stable(self): self.assertFalse(analyze(capture(short=True))['capture_complete'])
    def test_guard_rejection(self): self.assertEqual(analyze(capture(invalid=True))['unique_update_rows'],0)
    def test_reset_rejection(self): self.assertFalse(analyze(capture(reset=True))['capture_complete'])
    def test_untrusted_done(self): self.assertFalse(analyze(capture().replace('samples=305','samples=999'))['capture_complete'])
    def test_sparse_diagnostic_does_not_pass_stability(self):
        text=capture().replace('elapsed_ms=1000 ','elapsed_ms=2500 ').replace('elapsed_ms=2000 ','elapsed_ms=2600 ')
        result=analyze(text); self.assertTrue(result['diagnostic_capture_complete']); self.assertFalse(result['capture_complete'])
    def test_context_counter_mismatch(self):
        result=analyze(capture().replace('PHASE_CONTEXT_UCNT=','PHASE_CONTEXT_UCNT=1'))
        self.assertFalse(result['diagnostic_capture_complete'])
if __name__=='__main__': unittest.main()
