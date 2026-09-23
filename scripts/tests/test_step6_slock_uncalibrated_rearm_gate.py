from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/common-fun.c"


class SLockUncalibratedRearmGateTests(unittest.TestCase):
    def test_rearm_accepts_uncalibrated_and_slave_ptp_states(self):
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn(
            "(ppi->state != PPS_SLAVE &&\n"
            "\t\t\tppi->state != PPS_UNCALIBRATED)",
            source,
        )

    def test_uncalibrated_rearm_enters_present_without_state_change_hook(self):
        source = SOURCE.read_text(encoding="utf-8").split(
            "static int wr_auto_rearm_slave_after_s_lock_timeout", 1
        )[1].split("/* The handshake failed:", 1)[0]
        self.assertIn(
            "if (ppi->state == PPS_UNCALIBRATED)\n"
            "\t\twrp->next_state = WRS_PRESENT;\n"
            "\telse\n"
            "\t\twrp->next_state = WRS_IDLE;",
            source,
        )

    def test_rearm_remains_limited_to_slave_s_lock_with_wr_parent(self):
        source = SOURCE.read_text(encoding="utf-8").split(
            "static int wr_auto_rearm_slave_after_s_lock_timeout", 1
        )[1]
        guard = source.split("/* The handshake failed:", 1)[0]
        for required_guard in (
            "reason != WR_FAIL_REASON_WR_S_LOCK_TIMEOUT",
            "wrp->wrMode != WR_SLAVE",
            "!wrp->parentIsWRnode",
            "wrp->parentWrConfig == WR_MASTER",
            "wrp->parentWrConfig == WR_M_AND_S",
        ):
            with self.subTest(required_guard=required_guard):
                self.assertIn(required_guard, guard)


if __name__ == "__main__":
    unittest.main()
