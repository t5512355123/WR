import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "experiment" / "step6_rx_activity_decode_correction.py"
SPEC = importlib.util.spec_from_file_location("step6_rx_correction", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def sample(raw: str, index: int, role: str = "MASTER") -> dict:
    return {
        "ROLE": role,
        "BOARD": "DE5 [1-11.1]" if role == "MASTER" else "DE5 [1-11.2]",
        "SAMPLE": index,
        "READ_VALID": 1,
        "CLOCK_ACTIVITY_RAW": raw,
        "RX_CLOCK_ACTIVITY": 0,
        "RX_LOCKED_TO_DATA": 1,
        "PHY_RST": 0,
        "PHY_TX_DISABLE": 0,
        "ECR_TX_EN": 1,
        "ECR_RX_EN": 1,
        "RX_SYNCSTATUS": 0,
        "RX_ENC_ERR": 1 if index % 2 else 0,
        "RX_DISPERR": 0,
        "RX_ERRDETECT": 1 if index % 2 else 0,
        "BOOT_GENERATION": "00000001",
        "CPU_RESET_COUNT": "00000001",
        "WR_CORE_RESET_COUNT": "00000001",
        "SI_CONFIG_DROP_COUNT": "00000001",
        "BOOT_CHANGED": 0,
        "RESET_CHANGED": 0,
    }


class RxActivityCorrectionTests(unittest.TestCase):
    def test_decode_uses_high_word_bits_47_to_32(self):
        self.assertEqual(MODULE.decode_rx_activity("002EBD9D9E3300DA"), 0xBD9D)

    def test_activity_delta_wraps_as_16_bit(self):
        self.assertEqual(MODULE.delta16(0xF000, 0x1000), 0x2000)

    def test_reanalysis_invalidates_old_serdes_classification(self):
        raws = [
            "002EBD9D9E3300DA",
            "002F304B10CF7389",
            "0030A1C5A0E10012",
            "00311337B2E30034",
            "003282EDC4F50056",
            "0033F3E1D6070078",
        ]
        result = MODULE.analyze_rows([sample(raw, index) for index, raw in enumerate(raws)])
        self.assertTrue(result["decoder_bug_confirmed"])
        self.assertEqual(result["rx_activity_corrected"], [0xBD9D, 0x304B, 0xA1C5, 0x1337, 0x82ED, 0xF3E1])
        self.assertTrue(result["previous_failure_class_invalidated"])
        self.assertEqual(result["classification"], "FAIL_PHY_PCS_INPUT_INTEGRITY")


if __name__ == "__main__":
    unittest.main()
