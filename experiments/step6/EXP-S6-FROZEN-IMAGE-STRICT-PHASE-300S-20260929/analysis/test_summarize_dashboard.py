import unittest
from datetime import datetime, timedelta

from summarize_dashboard import parse_dashboard, summarize


def dashboard_frame(offset: int, timestamp: str, *, complete: bool = True) -> str:
    text = f"""White Rabbit Step 1-6 dashboard  {timestamp}  (read-only)
+------------------------------------------------------------+
| MASTER   DE5_1-11.1                                      |
| Step 1  PHY / Link           PASS                        |
| Link health                  Link=1  TM=1  RX=1  TX=1 |
| Global-Time validity         TIME_VALID=1 PPS_VALID=1     |
| Snapshot                     snapshot=1 stable=1 count=10 |
| TAI=100 CYCLES=1 |
+------------------------------------------------------------+
| SLAVE    DE5_1-11.2                                      |
| Step 1  PHY / Link           PASS                        |
| Link health                  Link=1  TM=1  RX=1  TX=1 |
| Lock signals                 Helper=1  MainFreq=1  MainPhase=1 |
|                              MainLock=1  PSTAT=1             |
| Global-Time validity         TIME_VALID=1 PPS_VALID=1     |
| Snapshot                     snapshot=1 stable=1 count=10 |
| TAI=100 CYCLES=1 |
| WR phase offset              {offset} ps (target |offset| <60 ps) |
+------------------------------------------------------------+
"""
    return text + ("Dashboard read complete.\n" if complete else "")


class DashboardSummaryTest(unittest.TestCase):
    def test_strict_gate_accepts_only_magnitude_below_60(self):
        text = "".join(
            dashboard_frame(value, f"2026-09-29T20:00:{second:02d}+08:00")
            for second, value in enumerate((59, -59, 60, -60))
        )
        frames, incomplete, errors = parse_dashboard(text)
        result = summarize(frames, incomplete, errors)
        self.assertEqual(result["complete_frames"], 4)
        self.assertEqual(result["slave_offset_under_60ps_samples_with_valid_global_time"], 2)
        self.assertEqual(result["all_gates_pass_samples"], 2)

    def test_incomplete_final_frame_is_not_counted(self):
        text = dashboard_frame(10, "2026-09-29T20:00:00+08:00") + dashboard_frame(
            10, "2026-09-29T20:00:10+08:00", complete=False
        )
        frames, incomplete, errors = parse_dashboard(text)
        self.assertEqual(len(frames), 1)
        self.assertEqual(incomplete, 1)
        self.assertEqual(errors, 0)

    def test_expanded_gate_requires_300_seconds_and_enough_samples(self):
        start = datetime.fromisoformat("2026-09-29T20:00:00+08:00")
        enough = "".join(
            dashboard_frame(0, (start + timedelta(seconds=10 * index)).isoformat())
            for index in range(31)
        )
        frames, incomplete, errors = parse_dashboard(enough)
        result = summarize(frames, incomplete, errors)
        self.assertTrue(result["expanded_step6_observation_pass"])
        self.assertEqual(result["maximum_consecutive_all_gates_pass_span_seconds"], 300.0)

        short = "".join(
            dashboard_frame(0, (start + timedelta(seconds=10 * index)).isoformat())
            for index in range(30)
        )
        frames, incomplete, errors = parse_dashboard(short)
        result = summarize(frames, incomplete, errors)
        self.assertFalse(result["expanded_step6_observation_pass"])
        self.assertEqual(result["maximum_consecutive_all_gates_pass_span_seconds"], 290.0)


if __name__ == "__main__":
    unittest.main()
