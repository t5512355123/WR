import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("strict",ROOT/"scripts/analysis/step6_strict_offset_300s.py")
analysis=importlib.util.module_from_spec(spec); spec.loader.exec_module(analysis)

def row(n,cko=50,time_valid=1,state=4,ucnt=None):
    return (f"S6_STRICT_SAMPLE board={{DE5 [1-11.2]}} row_end_ms={n*1000} "
        f"READS_VALID=1 FRAME_VALID=1 TRUSTWORTHY=1 STEP1_GATE=1 LOCK_GATE=1 RESET_CHANGED=0 "
        f"EPOCH_BEFORE={n:08X} EPOCH_AFTER={n:08X} EPOCH_AGE_MS=0 "
        f"UCNT={(n if ucnt is None else ucnt):08X} CKO_PS={cko} CKO_RAW={cko&0xffffffff:08X} "
        f"TIME_VALID={time_valid} SERVO_STATE={state} RESET_SIGNATURE={{1 1 1 1}}")

class StrictOffsetTests(unittest.TestCase):
    def run_rows(self,rows,done=True):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/"trace.log"
            path.write_text("\n".join(rows)+( "\nS6_STRICT_DONE timeout_count=0 invalid_count=0\n" if done else "\n"))
            return analysis.analyze(path)
    def test_300s_all_updates_in_band_after_entry_passes(self):
        self.assertEqual(self.run_rows([row(n) for n in range(301)])["verdict"],"PASS_SAMPLED_STRICT_GOAL")
    def test_exact_60_never_qualifies_entry(self):
        self.assertNotEqual(self.run_rows([row(n,60) for n in range(301)])["verdict"],"PASS_SAMPLED_STRICT_GOAL")
    def test_exact_120_retains_but_121_resets_dwell(self):
        rows=[row(0)]+[row(n,120) for n in range(1,301)]
        self.assertEqual(self.run_rows(rows)["verdict"],"PASS_SAMPLED_STRICT_GOAL")
        rows[150]=row(150,121)
        result=self.run_rows(rows)
        self.assertNotEqual(result["verdict"],"PASS_SAMPLED_STRICT_GOAL")
        self.assertEqual(result["pointwise_valid_outside_retention"],1)
    def test_old_valid_latch_and_short_capture_do_not_pass(self):
        self.assertNotEqual(self.run_rows([row(n,3917,state=5) for n in range(301)])["verdict"],"PASS_SAMPLED_STRICT_GOAL")
        self.assertNotEqual(self.run_rows([row(n) for n in range(300)])["verdict"],"PASS_SAMPLED_STRICT_GOAL")
    def test_revocation_state_reset_or_transport_breaks_window(self):
        for replacement in (row(150,time_valid=0),row(150,state=3),
            row(150).replace("RESET_SIGNATURE={1 1 1 1}","RESET_SIGNATURE={2 2 2 2}"),
            row(150).replace("FRAME_VALID=1","FRAME_VALID=0")):
            rows=[row(n) for n in range(301)]; rows[150]=replacement
            self.assertNotEqual(self.run_rows(rows)["verdict"],"PASS_SAMPLED_STRICT_GOAL")
    def test_frozen_ucnt_skipped_update_and_torn_epoch_do_not_pass(self):
        for rows in ([row(n,ucnt=1) for n in range(301)],
            [row(n,ucnt=n*2) for n in range(301)],
            [row(n).replace(f"EPOCH_AFTER={n:08X}",f"EPOCH_AFTER={n+1:08X}") for n in range(301)]):
            self.assertNotEqual(self.run_rows(rows)["verdict"],"PASS_SAMPLED_STRICT_GOAL")
    def test_missing_completion_is_inconclusive(self):
        self.assertEqual(self.run_rows([row(n) for n in range(301)],False)["verdict"],"INCONCLUSIVE")

if __name__=="__main__": unittest.main()
