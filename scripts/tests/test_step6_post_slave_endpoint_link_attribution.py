import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "experiment" / "step6_post_slave_endpoint_link_attribution.py"
SPEC = importlib.util.spec_from_file_location("step6_endpoint", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def row(**overrides):
    base = {
        "ROLE": "MASTER",
        "BOARD": "DE5 [1-11.1]",
        "READ_VALID": 1,
        "BOOT_GENERATION": "00000001",
        "CPU_RESET_COUNT": "00000000",
        "WR_CORE_RESET_COUNT": "00000000",
        "SI_CONFIG_DROP_COUNT": "00000000",
        "BOOT_CHANGED": 0,
        "RESET_CHANGED": 0,
        "CONTROL_BAD_STREAK": 0,
        "RX_NO_LOCK_STREAK": 0,
        "RX_NO_ACTIVITY_STREAK": 0,
        "PHY_BAD_STREAK": 0,
        "RAW_LINK_BAD_STREAK": 0,
        "LINK_GOOD_STREAK": 0,
        "RAW_PHY_HEALTHY": 0,
        "DSR_LINK": 0,
        "CORE_TM_LINK_UP": 0,
        "CORE_LINK_OK": 0,
        "STICKY_ERROR_DELTA": 0,
        "STOP_CANDIDATE": "NONE",
    }
    base.update(overrides)
    return base


class EndpointAttributionTests(unittest.TestCase):
    def test_endpoint_control_failure(self):
        result = MODULE.analyze_rows(
            [row(CONTROL_BAD_STREAK=n) for n in range(1, 6)]
        )
        self.assertEqual(result["classification"], "FAIL_ENDPOINT_CONTROL_NOT_ENABLED")
        self.assertEqual(result["link_attribution"], "PASS")

    def test_serdes_failure(self):
        result = MODULE.analyze_rows(
            [row(RX_NO_LOCK_STREAK=n) for n in range(1, 6)]
        )
        self.assertEqual(result["classification"], "FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED")

    def test_phy_pcs_input_failure(self):
        result = MODULE.analyze_rows(
            [row(PHY_BAD_STREAK=n, STICKY_ERROR_DELTA=1) for n in range(1, 6)]
        )
        self.assertEqual(result["classification"], "FAIL_PHY_PCS_INPUT_INTEGRITY")

    def test_endpoint_pcs_failure(self):
        result = MODULE.analyze_rows(
            [row(RAW_PHY_HEALTHY=1, RAW_LINK_BAD_STREAK=n) for n in range(1, 11)]
        )
        self.assertEqual(result["classification"], "FAIL_ENDPOINT_PCS_OR_AUTONEG_NOT_ESTABLISHED")
        self.assertEqual(result["post_slave_link_establishment"], "FAIL")

    def test_late_recovery(self):
        result = MODULE.analyze_rows(
            [row(LINK_GOOD_STREAK=n, DSR_LINK=1, CORE_TM_LINK_UP=1, CORE_LINK_OK=1) for n in range(1, 6)]
        )
        self.assertEqual(result["classification"], "PASS_LATE_RECOVERY")
        self.assertEqual(result["post_slave_link_establishment"], "PASS_LATE_RECOVERY")

    def test_transport_or_reset_is_inconclusive(self):
        result = MODULE.analyze_rows([row(READ_VALID=0)])
        self.assertEqual(result["classification"], "INCONCLUSIVE_TRANSPORT")
        result = MODULE.analyze_rows([row(), row(RESET_CHANGED=1)])
        self.assertEqual(result["classification"], "INCONCLUSIVE_RESET")


if __name__ == "__main__":
    unittest.main()
