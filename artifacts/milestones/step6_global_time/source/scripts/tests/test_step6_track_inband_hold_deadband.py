from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"


def state_blocks():
    text = SOURCE.read_text(encoding="utf-8")
    sync_start = text.index("case WRH_SYNC_PHASE:")
    wait_start = text.index("case WRH_WAIT_OFFSET_STABLE:", sync_start)
    track_start = text.index("case WRH_TRACK_PHASE:", wait_start)
    servo_locked = text.index("gs->servo_locked =", track_start)
    return text, text[sync_start:wait_start], text[wait_start:track_start], text[track_start:servo_locked]


class TrackInbandHoldDeadbandTests(unittest.TestCase):
    def test_candidate_restores_measured_quarter_acquisition_baseline(self):
        _, sync, _, _ = state_blocks()
        self.assertEqual(sync.count("s->cur_setpoint_ps += (offset_ps / 4);"), 1)
        self.assertNotIn("s->cur_setpoint_ps += (offset_ps / 2);", sync)

    def test_wait_entry_and_track_exit_thresholds_are_unchanged(self):
        _, _, wait, track = state_blocks()
        self.assertIn(
            "remaining_offset < WRH_SERVO_OFFSET_STABILITY_THRESHOLD", wait
        )
        self.assertIn(
            "abs(offset_ps) >\n\t\t\t    2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD",
            track,
        )
        self.assertIn("s->missed_iters >= 10", wait)

    def test_track_phase_holds_setpoint_only_inside_strict_band(self):
        _, _, _, track = state_blocks()
        guard = "if (abs(offset_ps) >=\n\t\t\t    WRH_SERVO_OFFSET_STABILITY_THRESHOLD) {"
        self.assertEqual(track.count(guard), 1)
        update = "s->cur_setpoint_ps += (offset_ps / 4);"
        self.assertEqual(track.count(update), 1)
        guard_pos = track.index(guard)
        update_pos = track.index(update)
        adjust_pos = track.index("WRH_OPER()->adjust_phase(s->cur_setpoint_ps);")
        guard_end = track.index("\n\t\t\t}", guard_pos)
        self.assertLess(guard_pos, update_pos)
        self.assertLess(update_pos, adjust_pos)
        self.assertLess(adjust_pos, guard_end)

    def test_deadband_boundary_matches_strict_acceptance_inequality(self):
        should_adjust = lambda offset: abs(offset) >= 60
        for offset in (-59, 0, 59):
            self.assertFalse(should_adjust(offset))
        for offset in (-60, 60, -61, 61):
            self.assertTrue(should_adjust(offset))


if __name__ == "__main__":
    unittest.main()
