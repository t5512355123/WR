from __future__ import annotations

from pathlib import Path
import re
import unittest


EXPERIMENT = Path(__file__).resolve().parents[1]
ROOT = EXPERIMENT.parents[2]
SOURCE = ROOT / "vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"
HEADER = ROOT / "vendor/wrpc-sw/ppsi/include/hw-specific/wrh.h"


class FixedSetpointLatchSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_latch_is_independent_static_boot_lifetime_state(self) -> None:
        self.assertEqual(
            self.source.count("static int wrh_fixed_setpoint_latched = 0;"), 1
        )
        setter = self.source.split(
            "void wrh_servo_enable_tracking(int enable)", 1
        )[1].split("}", 1)[0]
        self.assertIn("wrh_tracking_enabled = enable;", setter)
        self.assertNotIn("wrh_fixed_setpoint_latched", setter)
        reset = self.source.split("void wrh_servo_reset(", 1)[1].split(
            "int wrh_servo_got_sync(", 1
        )[0]
        self.assertNotIn("wrh_fixed_setpoint_latched = 0", reset)
        header = HEADER.read_text(encoding="utf-8")
        reset_macro = header.split("#define WRH_SERVO_RESET_DATA_SIZE", 1)[1].split(
            "typedef struct wrh_servo_t", 1
        )[0]
        self.assertIn("offsetof(wrh_servo_t,clock_period_ps)", reset_macro)
        self.assertLess(
            header.index("int32_t cur_setpoint_ps;"),
            header.index("int32_t clock_period_ps;"),
        )

    def test_first_strict_wait_success_latches_before_track_state(self) -> None:
        wait = self.source.split("case WRH_WAIT_OFFSET_STABLE:", 1)[1].split(
            "case WRH_TRACK_PHASE:", 1
        )[0]
        success = wait.split(
            "if(remaining_offset < WRH_SERVO_OFFSET_STABILITY_THRESHOLD)", 1
        )[1].split("} else {", 1)[0]
        self.assertLess(
            success.index("wrh_fixed_setpoint_latched = 1;"),
            success.index("setState(ppi,WRH_TRACK_PHASE);"),
        )
        self.assertIn("remaining_offset < WRH_SERVO_OFFSET_STABILITY_THRESHOLD", wait)

    def test_all_servo_phase_write_sites_are_latch_guarded(self) -> None:
        call = "WRH_OPER()->adjust_phase(s->cur_setpoint_ps);"
        self.assertEqual(self.source.count(call), 3)

        init = self.source.split("int wrh_servo_init(", 1)[1].split(
            "void wrh_servo_reset(", 1
        )[0]
        sync = self.source.split("case WRH_SYNC_PHASE:", 1)[1].split(
            "case WRH_WAIT_OFFSET_STABLE:", 1
        )[0]
        track = self.source.split("case WRH_TRACK_PHASE:", 1)[1].split(
            "gs->servo_locked", 1
        )[0]

        self.assertRegex(
            init,
            r"(?s)if\s*\(!wrh_fixed_setpoint_latched\)\s*\{.*?"
            + re.escape(call),
        )
        self.assertRegex(
            init,
            r"(?s)if\s*\(!wrh_fixed_setpoint_latched\)\s*\{.*?"
            r"s->cur_setpoint_ps\s*>\s*s->clock_period_ps.*?"
            r"s->cur_setpoint_ps\s*%=\s*s->clock_period_ps",
        )
        self.assertRegex(
            sync,
            r"(?s)if\s*\(!wrh_fixed_setpoint_latched\)\s*\{.*?"
            r"s->cur_setpoint_ps\s*\+=\s*\(offset_ps\s*/\s*4\);.*?"
            + re.escape(call),
        )
        self.assertRegex(
            track,
            r"(?s)if\s*\(!wrh_fixed_setpoint_latched\s*&&\s*"
            r"wrh_tracking_enabled\)\s*\{.*?"
            r"2\s*\*\s*WRH_SERVO_OFFSET_STABILITY_THRESHOLD.*?"
            r"s->cur_setpoint_ps\s*\+=\s*\(offset_ps\s*/\s*4\);.*?"
            + re.escape(call),
        )

    def test_sync_wait_flag_and_transition_remain_outside_setpoint_guard(self) -> None:
        sync = self.source.split("case WRH_SYNC_PHASE:", 1)[1].split(
            "case WRH_WAIT_OFFSET_STABLE:", 1
        )[0]
        self.assertRegex(
            sync,
            r"(?s)if\s*\(!wrh_fixed_setpoint_latched\)\s*\{.*?"
            r"\}\s*gs->flags\s*\|=\s*PP_SERVO_FLAG_WAIT_HW;\s*"
            r"setState\(ppi,WRH_WAIT_OFFSET_STABLE\);",
        )

    def test_quarter_step_and_lock_thresholds_are_unchanged(self) -> None:
        self.assertEqual(
            self.source.count("s->cur_setpoint_ps += (offset_ps / 4);"), 2
        )
        self.assertIn("remaining_offset < WRH_SERVO_OFFSET_STABILITY_THRESHOLD", self.source)
        self.assertIn("2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD", self.source)


if __name__ == "__main__":
    unittest.main()
