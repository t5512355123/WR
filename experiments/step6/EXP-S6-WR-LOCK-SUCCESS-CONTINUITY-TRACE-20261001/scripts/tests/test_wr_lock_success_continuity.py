from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from analyze_wr_lock_success_continuity import (
    analyze_text,
    derive_success_delta,
    delta32,
)


def row(**overrides):
    data = {
        "ROW_VALID": "1",
        "ELAPSED_MS": "100",
        "SUCCESS_CONFIRMED": "0",
        "SUCCESS_TRIGGER_MS": "-1",
        "SUCCESS_TRIGGER_CONFIRM_MS": "-1",
        "LOCK_POLL_COUNT_RAW": "00000010",
        "WR_STATE": "2",
        "WR_TX_ID": "4097",
        "WR_RX_ID": "0",
        "WR_DISABLE_VALID": "0",
        "WR_FAILURE_REASON": "0",
        "LOCK_UNLOCKED_COUNT_RAW": "00000010",
        "LOCK_CALIB_FAIL_COUNT_RAW": "00000002",
        "HELPER_LOCK": "1",
        "MAIN_FREQ_LOCK": "1",
        "MAIN_PHASE_LOCK": "1",
        "MAIN_LOCK": "1",
        "PSTAT_LOCK": "1",
    }
    data.update({key: str(value) for key, value in overrides.items()})
    return "S6W_SAMPLE " + " ".join(f"{key}={value}" for key, value in data.items())


class WrLockContinuityTests(unittest.TestCase):
    def test_success_delta_subtracts_unlock_and_calibration_fail(self):
        previous = {
            "LOCK_POLL_COUNT_RAW": "00000020",
            "LOCK_UNLOCKED_COUNT_RAW": "00000010",
            "LOCK_CALIB_FAIL_COUNT_RAW": "00000002",
        }
        current = {
            "LOCK_POLL_COUNT_RAW": "00000025",
            "LOCK_UNLOCKED_COUNT_RAW": "00000012",
            "LOCK_CALIB_FAIL_COUNT_RAW": "00000003",
        }
        result = derive_success_delta(previous, current)
        self.assertTrue(result["valid"])
        self.assertEqual(result["delta"], 2)

    def test_discontinuity_is_not_a_negative_success_delta(self):
        previous = {
            "LOCK_POLL_COUNT_RAW": "10000000",
            "LOCK_UNLOCKED_COUNT_RAW": "00000010",
            "LOCK_CALIB_FAIL_COUNT_RAW": "00000002",
        }
        current = {
            "LOCK_POLL_COUNT_RAW": "00000020",
            "LOCK_UNLOCKED_COUNT_RAW": "00000011",
            "LOCK_CALIB_FAIL_COUNT_RAW": "00000002",
        }
        result = derive_success_delta(previous, current)
        self.assertFalse(result["valid"])
        self.assertIsNone(result["delta"])

    def test_uint32_wrap_is_only_accepted_near_edges(self):
        self.assertEqual(delta32(0xFFFFFFFE, 3), (5, "ROLLOVER"))
        self.assertEqual(delta32(0x80000000, 3), (None, "DISCONTINUITY"))

    def test_no_success_and_timeout_classification(self):
        text = row(LOCK_POLL_COUNT_RAW="00000010") + "\nS6W_STOP reason=NO_SUCCESSFUL_LOCK_POLL_300S\n"
        result = analyze_text(text)
        self.assertEqual(result["class"], "SUCCESSFUL_SLOCK_ADMISSION_NOT_REPRODUCED")

    def test_actual_tcl_lowercase_row_valid_field_is_accepted(self):
        line = "S6W_SAMPLE board=DE5_1-11.2 sample=000001 elapsed_ms=100 row_valid=1 WR_STATE=2"
        result = analyze_text(line + "\nS6W_STOP reason=FIVE_CONSECUTIVE_INVALID_SUCCESS_METRICS\n")
        self.assertEqual(result["valid_rows"], 1)
        self.assertEqual(result["invalid_rows"], 0)

    def test_posthoc_positive_interval_is_reported_separately_from_confirmation(self):
        first = row(LOCK_POLL_COUNT_RAW="00000020", LOCK_UNLOCKED_COUNT_RAW="00000010",
                    LOCK_CALIB_FAIL_COUNT_RAW="00000002")
        second = row(ELAPSED_MS=200, LOCK_POLL_COUNT_RAW="00000025",
                     LOCK_UNLOCKED_COUNT_RAW="00000012", LOCK_CALIB_FAIL_COUNT_RAW="00000003")
        result = analyze_text(first + "\n" + second + "\nS6W_STOP reason=FIVE_CONSECUTIVE_INVALID_SUCCESS_METRICS\n")
        self.assertEqual(result["metric_positive_intervals"], 1)
        self.assertEqual(result["success_confirmed_rows"], 0)

    def test_success_with_handshake_progress_is_supported(self):
        first = row(ELAPSED_MS=100, SUCCESS_CONFIRMED=1, SUCCESS_TRIGGER_MS=90,
                    SUCCESS_TRIGGER_CONFIRM_MS=110,
                    WR_STATE=4, WR_TX_ID=4098, WR_RX_ID=4099)
        second = row(ELAPSED_MS=120, WR_STATE=4, WR_TX_ID=4098, WR_RX_ID=4099)
        third = row(ELAPSED_MS=5100, WR_STATE=6, WR_TX_ID=4098, WR_RX_ID=4099)
        result = analyze_text(first + "\n" + second + "\n" + third +
                              "\nS6W_STOP reason=POST_SUCCESS_WINDOW_COMPLETE\n")
        self.assertEqual(result["class"], "WR_LOCK_ADMISSION_CONTINUITY_SUPPORTED")

    def test_failure_waiting_for_calibrate_is_separated(self):
        trace = "\n".join([
            row(ELAPSED_MS=100, SUCCESS_CONFIRMED=1, SUCCESS_TRIGGER_MS=90,
                SUCCESS_TRIGGER_CONFIRM_MS=110,
                WR_STATE=4, WR_TX_ID=4098, WR_RX_ID=0),
            row(ELAPSED_MS=120, WR_STATE=4, WR_TX_ID=4098, WR_RX_ID=0,
                SUCCESS_TRIGGER_CONFIRM_MS=110,
                WR_DISABLE_VALID=1, WR_FAILURE_REASON=4),
            "S6W_STOP reason=POST_SUCCESS_WINDOW_COMPLETE",
        ])
        self.assertEqual(analyze_text(trace)["class"], "FIRST_FAILURE_AFTER_SUCCESS_MASTER_CALIBRATE_HANDSHAKE")

    def test_success_followed_by_partial_handshake_is_not_called_pass(self):
        trace = "\n".join([
            row(ELAPSED_MS=100, SUCCESS_CONFIRMED=1,
                SUCCESS_TRIGGER_CONFIRM_MS=110, WR_STATE=4, WR_TX_ID=4098),
            row(ELAPSED_MS=120, WR_STATE=4, WR_TX_ID=4098),
            "S6W_STOP reason=POST_SUCCESS_WINDOW_COMPLETE",
        ])
        self.assertEqual(analyze_text(trace)["class"], "POST_SUCCESS_WR_ADMISSION_PARTIAL")

    def test_phase_state_is_not_a_step6_verdict(self):
        result = analyze_text(row(ELAPSED_MS=50, SERVO_STATE=3) + "\nS6W_STOP reason=POST_SUCCESS_WINDOW_COMPLETE\n")
        self.assertEqual(result["step6_stable_offset"], "NOT_EVALUATED")


if __name__ == "__main__":
    unittest.main()
