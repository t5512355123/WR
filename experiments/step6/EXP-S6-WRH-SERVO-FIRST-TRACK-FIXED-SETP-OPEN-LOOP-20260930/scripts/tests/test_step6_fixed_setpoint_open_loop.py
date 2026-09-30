from __future__ import annotations

from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


EXPERIMENT = Path(__file__).resolve().parents[2]
ROOT = EXPERIMENT.parents[2]
PATCH = EXPERIMENT / "candidate.patch"
SOURCE_PATH = Path(
    "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/"
    "proto-ext-common/wrh-servo.c"
)
BASE_SOURCE = ROOT / SOURCE_PATH


def patched_source() -> str:
    with tempfile.TemporaryDirectory(prefix="step6-fixed-setp-") as tmp:
        temp_root = Path(tmp)
        target = temp_root / SOURCE_PATH
        target.parent.mkdir(parents=True)
        shutil.copyfile(BASE_SOURCE, target)
        subprocess.run(["git", "init", "-q"], cwd=temp_root, check=True)
        subprocess.run(
            ["git", "config", "core.autocrlf", "false"],
            cwd=temp_root,
            check=True,
        )
        subprocess.run(["git", "add", str(SOURCE_PATH)], cwd=temp_root, check=True)
        subprocess.run(
            [
                "git",
                "-c",
                "user.name=Offline test",
                "-c",
                "user.email=offline-test@example.invalid",
                "commit",
                "-qm",
                "frozen source fixture",
            ],
            cwd=temp_root,
            check=True,
        )
        subprocess.run(["git", "apply", str(PATCH)], cwd=temp_root, check=True)
        return target.read_text(encoding="utf-8")


class FixedSetpointOpenLoopTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = patched_source()
        cls.patch = PATCH.read_text(encoding="utf-8")

    def test_candidate_applies_to_frozen_source_and_declares_one_shot_latch(self):
        self.assertIn("static int wrh_fixed_setpoint_latched = 0;", self.source)
        self.assertIn("diff --git a/" + SOURCE_PATH.as_posix(), self.patch)

    def test_quarter_step_acquisition_and_tracking_are_preserved(self):
        sync = self.source.split("case WRH_SYNC_PHASE:", 1)[1].split(
            "case WRH_WAIT_OFFSET_STABLE:", 1
        )[0]
        track = self.source.split("case WRH_TRACK_PHASE:", 1)[1].split(
            "gs->servo_locked", 1
        )[0]
        self.assertIn("s->cur_setpoint_ps += (offset_ps / 4);", sync)
        self.assertIn("s->cur_setpoint_ps += (offset_ps / 4);", track)
        self.assertIn("WRH_SERVO_OFFSET_STABILITY_THRESHOLD", self.source)
        self.assertIn("2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD", self.source)

    def test_first_successful_track_entry_latches_before_state_change(self):
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
        self.assertNotIn("wrh_tracking_enabled = 0;", self.source)

    def test_all_phase_setpoint_write_sites_are_latch_guarded(self):
        calls = "WRH_OPER()->adjust_phase(s->cur_setpoint_ps);"
        self.assertEqual(self.source.count(calls), 3)

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
            r"if\s*\(!wrh_fixed_setpoint_latched\)\s*"
            + re.escape(calls),
        )
        self.assertRegex(
            init,
            r"if\s*\(!wrh_fixed_setpoint_latched\s*&&\s*"
            r"s->cur_setpoint_ps\s*>\s*s->clock_period_ps\)",
        )
        self.assertRegex(
            sync,
            r"(?s)if\s*\(!wrh_fixed_setpoint_latched\)\s*\{.*?"
            + re.escape(calls),
        )
        self.assertRegex(
            track,
            r"(?s)if\s*\(!wrh_fixed_setpoint_latched\s*&&\s*"
            r"wrh_tracking_enabled\)\s*\{.*?"
            + re.escape(calls),
        )

    def test_sync_wait_flag_and_transition_remain_outside_phase_write_guard(self):
        sync = self.source.split("case WRH_SYNC_PHASE:", 1)[1].split(
            "case WRH_WAIT_OFFSET_STABLE:", 1
        )[0]
        self.assertRegex(
            sync,
            r"(?s)if\s*\(!wrh_fixed_setpoint_latched\)\s*\{.*?"
            r"\}\s*gs->flags\s*\|=\s*PP_SERVO_FLAG_WAIT_HW;\s*"
            r"setState\(ppi,WRH_WAIT_OFFSET_STABLE\);",
        )

    def test_ipc_reenable_cannot_reopen_phase_actuation_after_latch(self):
        track = self.source.split("case WRH_TRACK_PHASE:", 1)[1].split(
            "gs->servo_locked", 1
        )[0]
        sync = self.source.split("case WRH_SYNC_PHASE:", 1)[1].split(
            "case WRH_WAIT_OFFSET_STABLE:", 1
        )[0]
        self.assertIn(
            "if(!wrh_fixed_setpoint_latched && wrh_tracking_enabled)", track
        )
        self.assertIn("if (!wrh_fixed_setpoint_latched)", sync)

    def test_tracking_ipc_setter_remains_unchanged_and_latch_independent(self):
        setter = self.source.split(
            "void wrh_servo_enable_tracking(int enable)", 1
        )[1].split("}", 1)[0]
        self.assertIn("wrh_tracking_enabled = enable;", setter)
        self.assertNotIn("wrh_fixed_setpoint_latched", setter)

    def test_reset_does_not_clear_the_boot_lifetime_latch(self):
        reset = self.source.split("void wrh_servo_reset(", 1)[1].split(
            "int wrh_servo_got_sync(", 1
        )[0]
        self.assertNotIn("wrh_fixed_setpoint_latched = 0", reset)


if __name__ == "__main__":
    unittest.main()
