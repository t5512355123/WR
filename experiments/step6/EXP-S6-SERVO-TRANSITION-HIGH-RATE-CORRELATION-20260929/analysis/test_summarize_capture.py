import unittest
from datetime import datetime, timezone

from summarize_capture import parse_capture, signed_u32, summarize


class CaptureParserTest(unittest.TestCase):
    def test_signed_u32_offset(self):
        self.assertEqual(signed_u32("0000003B"), 59)
        self.assertEqual(signed_u32("FFFFFFC5"), -59)
        self.assertIsNone(signed_u32("TIMEOUT"))

    def test_parses_sample_validity_locks_and_transition(self):
        ts = "2026-09-29T13:40:27.000000000Z"
        log = "\n".join([
            f"{ts}\tSESSION_SAMPLE board=DE5 [1-11.2] sample=001 attempt=0 status=ABCDEF01",
            f"{ts}\tFRAME_VALID: 0 CTRL_BEGIN=00000001 CTRL_END=00000001 RETRY_INDEX=0",
            f"{ts}\tWR_STATE_BLOCK_VALID: 1 A=A040035F B=A040035F",
            f"{ts}\tWDIAGS_DMS_H:00000000 WDIAGS_DMS_L:00000001 WDIAGS_CKO:FFFFFFC5 WDIAGS_SETP:FFFFEB78 WDIAGS_UCNT:00000002",
            f"{ts}\tDECODE: status_low=FF time_valid=1 pps_valid=1 wr_mode=3 sstat_wr_valid=1 servo_state=5 link_up=1 spll_locked=1",
            f"{ts}\tSTEP5_LOCKDET: boundary=LOCKED_SAMPLE HELPER locked=1 changed=0 cnt=1000/1000 MAIN enabled=1 locked=1 freq=1 phase=1 PSTAT_locked=1",
            f"{ts}\tSTEP5_SAMPLE_VALID: 1 (full_frame_valid=0)",
            f"{ts}\tSESSION_SAMPLE_RESULT board=DE5 [1-11.2] sample=001 accepted=1 retries=0",
            f"{ts}\tCAPTURE_PROCESS_EXIT=0",
        ])
        rows, exit_code, errors = parse_capture(log)
        result = summarize(rows, exit_code, errors)
        slave = result["boards"]["DE5 [1-11.2]"]
        self.assertEqual(exit_code, 0)
        self.assertEqual(errors, 0)
        self.assertEqual(slave["accepted_samples"], 1)
        self.assertEqual(slave["all_five_lock_samples"], 1)
        self.assertEqual(slave["phase_offset_median_ps"], -59)
        self.assertEqual(slave["servo_state_samples"], {"WAIT_OFFSET_STABLE": 1})


if __name__ == "__main__":
    unittest.main()
