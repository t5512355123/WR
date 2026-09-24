import unittest

from analyze_step3_runtime import analyze, parse_timeseries_text


def frame(
    board: str,
    sample: int,
    *,
    state: int = 2,
    enable: int = 1,
    fail_state: int = 0,
) -> str:
    return f"""SESSION_SAMPLE board={board} sample={sample:03d} attempt=0 status=82CF
FRAME_VALID: 1 CTRL_BEGIN=00000001 CTRL_END=00000001 RETRY_INDEX=0
PARENT_BLOCK_VALID: 1 A=03000009/03000001/07000000 B=03000009/03000001/07000000
WR_STATE_BLOCK_VALID: 1 A=A0001000 B=A0001000
WR_SIGNAL_BLOCK_VALID: 1 RX=10010001/10010001 TX=10000001/10000001 FAIL=00000000/00000000 REJECT=00000000/00000000
WR_LOCK_BLOCK_VALID: 1 RESULT=00000000/00000000 POLLS=00000000/00000000 UNLOCKED=00000000/00000000 CALIB_FAIL=00000000/00000000 ENABLE={enable:08X}/{enable:08X} SPLL=00000000/00000000
WDIAGS_PTP_META:03000009
WDIAGS_FOREIGN_META:03000001
PARENT: foreign_count=1 foreign_best=0 detection=1 wr_config=3 is_wr=1 mode_on=1 calibrated=1
WR_LOCAL: tag=A mode_on=1 parent_mode_on=1 calibrated=1 parent_is_wr=1 parent_calibrated=1 wr_config=3 parent_wr_config=3 state={state} next_state={state} parent_detection=1 wr_mode=3
WR_SIGNAL: rx_msg=0x1001 rx_count=2 tx_msg=0x1000 tx_count=2 fail_role=0 fail_state={fail_state} fail_count=0
WR_SIGNAL_REJECT: count=0 reason=0
WR_LOCK: result=0 spll_locked=0 polls=0 unlocked=0 calibration_fail=0 enable={enable} seq_state=0 align_state=0 mode=3 delock_count=0
SESSION_SAMPLE_RESULT board={board} sample={sample:03d} accepted=1 retries=0
"""


def series(
    *,
    slave_state: int = 2,
    slave_enable: int = 1,
    fail_state: int = 0,
    last_reject_count: int = 0,
) -> str:
    frames = []
    for sample in range(1, 31):
        frames.append(frame("DE5 [1-11.1]", sample))
        slave_frame = frame(
            "DE5 [1-11.2]",
            sample,
            state=slave_state,
            enable=slave_enable,
            fail_state=fail_state,
        )
        if sample == 30 and last_reject_count:
            slave_frame = slave_frame.replace(
                "WR_SIGNAL_REJECT: count=0 reason=0",
                f"WR_SIGNAL_REJECT: count={last_reject_count} reason=1",
            )
        frames.append(slave_frame)
    return "".join(frames)


class Step3RuntimeAnalyzerTests(unittest.TestCase):
    def test_full_valid_series_passes(self) -> None:
        self.assertEqual(analyze(parse_timeseries_text(series())), [])

    def test_fail_state_does_not_substitute_for_current_state_or_entry(self) -> None:
        rows = parse_timeseries_text(series(slave_state=0, slave_enable=0, fail_state=2))
        errors = analyze(rows)
        self.assertTrue(any("neither current WRS_S_LOCK" in error for error in errors))

    def test_enable_counter_proves_entry_after_current_state_returns_idle(self) -> None:
        rows = parse_timeseries_text(series(slave_state=0, slave_enable=1))
        self.assertEqual(analyze(rows), [])

    def test_signaling_reject_growth_fails(self) -> None:
        rows = parse_timeseries_text(series(last_reject_count=1))
        errors = analyze(rows)
        self.assertTrue(any("signaling-reject count advanced" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
