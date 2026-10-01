from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[5]
EXP = ROOT / "experiments/step6/EXP-S6-WRH-SERVO-HALF-ACQUIRE-QUARTER-TRACK-20261001"
WRAPPER = EXP / "scripts/run_same_boot_acquisition_trace.sh"


class SameBootAcquisitionWrapperTests(unittest.TestCase):
    def setUp(self):
        self.text = WRAPPER.read_text(encoding="utf-8")

    def test_capture_is_durable_and_outside_checkout(self):
        self.assertIn("/tmp/wr-s6-half-acquire-quarter-track-20261001", self.text)
        self.assertIn("S6_ACQ_WRAPPER_DONE", self.text)
        self.assertIn('sha256sum "$LOG"', self.text)
        self.assertNotIn("rm -", self.text)

    def test_pins_candidate_and_refuses_source_or_checkout_drift(self):
        self.assertIn("ba9514c555edc672dff4eea9cfa5690d614a20a4", self.text)
        self.assertIn("candidate_source_not_in_head", self.text)
        self.assertIn("candidate_servo_source_changed_since_program", self.text)
        self.assertIn("worktree_not_clean", self.text)

    def test_refuses_concurrent_jtag_or_programmer_sessions(self):
        self.assertIn("quartus_stp quartus_pgm quartus_pgmw", self.text)
        self.assertIn("concurrent_$process_name", self.text)

    def test_uses_bounded_read_only_capture_and_same_boot_smoke(self):
        self.assertIn("905s", self.text)
        self.assertIn('"$STP_BIN" -t "$TCL_SCRIPT"', self.text)
        self.assertIn("mode=read_only_same_boot reset=0 fpga_program=0 compile=0", self.text)
        self.assertIn("TRACK_PHASE_REACHED_DURING_ARMING_HEALTH_READY", self.text)
        self.assertIn("15000 500 1-11.2 2", self.text)
        self.assertIn("reset=0 reprogram=0", self.text)


if __name__ == "__main__":
    unittest.main()
