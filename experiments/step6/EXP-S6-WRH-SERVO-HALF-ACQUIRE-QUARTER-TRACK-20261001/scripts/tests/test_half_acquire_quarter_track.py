import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[5]
SOURCE = ROOT / "vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"


def servo_blocks():
    text = SOURCE.read_text(encoding="utf-8")
    sync_start = text.index("case WRH_SYNC_PHASE:")
    wait_start = text.index("case WRH_WAIT_OFFSET_STABLE:", sync_start)
    track_start = text.index("case WRH_TRACK_PHASE:", wait_start)
    locked_start = text.index("gs->servo_locked =", track_start)
    return text[sync_start:wait_start], text[track_start:locked_start]


class HalfAcquireQuarterTrackTests(unittest.TestCase):
    def test_sync_phase_uses_measured_half_step(self):
        sync, _ = servo_blocks()
        self.assertEqual(sync.count("s->cur_setpoint_ps += (offset_ps / 2);"), 1)
        self.assertNotIn("s->cur_setpoint_ps += offset_ps;", sync)
        self.assertNotIn("s->cur_setpoint_ps += (offset_ps / 4);", sync)

    def test_track_phase_remains_quarter_step(self):
        _, track = servo_blocks()
        self.assertIn("s->cur_setpoint_ps += (offset_ps / 4);", track)

    def test_existing_threshold_retry_and_exit_guard_remain(self):
        _, track = servo_blocks()
        text = SOURCE.read_text(encoding="utf-8")
        self.assertIn(
            "remaining_offset < WRH_SERVO_OFFSET_STABILITY_THRESHOLD", text
        )
        self.assertIn("2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD", track)
        self.assertIn("s->missed_iters >= 10", text)


if __name__ == "__main__":
    unittest.main()
