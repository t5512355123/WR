from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4k_kp_aba as f4k  # noqa: E402


RAW_NAMES = [
    "PRODUCER_EPOCH", "UPDATE_ID", "INIT_GENERATION", "PRODUCER_IDENTITY",
    "FREQ_ERROR", "BRANCH_ID", "BRANCH_ERROR", "PI_X", "PI_OUTPUT",
    "PI_CLAMP_SIDE", "FLAGS", "FREQ_COUNT_BEFORE", "FREQ_COUNT_AFTER",
    "PHASE_COUNT_BEFORE", "PHASE_COUNT_AFTER", "SAMPLE_N", "SOURCE_IDS",
    "TOTAL_UPDATES", "FREQ_UPDATES", "PHASE_UPDATES", "FREQ_TO_PHASE",
    "PHASE_TO_FREQ", "PHASE_DETECTOR", "PHASE_IN_BAND", "PHASE_OUT_BAND",
    "LAST_TRANSITION_UPDATE", "LAST_TRANSITION", "STATUS", "LAST_FREQ_UPDATE",
    "LAST_PHASE_UPDATE", "FRAME_WORDS", "VERSION", "MAGIC",
]


def _hex(value: int) -> str:
    return f"0x{value & 0xFFFFFFFF:08X}"


def _main_line(index: int, in_band_step: int, arm: str, kp: int) -> str:
    phase = index > 1
    phase_iterations = index - 1 if phase else 0
    detector = phase_iterations * 100
    in_band = phase_iterations * in_band_step
    out_band = detector - in_band
    branch = 2 if phase else 1
    freq_error = 20
    branch_error = 100 if phase else -20 * freq_error
    flags = 1
    if phase:
        flags |= 1 << 5
        flags |= (1 << 6) if index % 2 == 0 else (1 << 7)
    values = [
        2 * index, index, 1, 0x00010000, freq_error, branch, branch_error,
        branch_error, 11000 + index, 0, flags, 0 if phase else index - 1,
        index if not phase else index - 1, 0, phase_iterations, index,
        0x00000100, index * 1000, index * 1000 - detector, detector,
        phase_iterations, 0, detector, in_band, out_band,
        1 if phase else 0, 0x0102 if phase else 0, 1,
        0 if phase else index - 1, phase_iterations, 30, 1, f4k.f4j.MAGIC,
    ]
    parts = [
        "STEP5_F4J_MAIN_PRODUCER", "board=DE5 [1-11.2]", f"cycle={index}",
        f"host_start_ms={5000 * index - 1}", f"host_end_ms={5000 * index}",
        f"elapsed_ms={5000 * index}", "READ_DURATION_MS=1",
        "MAIN_PRODUCER_VALID=1", "PUBLICATION_COHERENT=1",
        f"PUBLICATION_EPOCH_RAW_BEFORE={_hex(2 * index)}",
        f"PUBLICATION_EPOCH_RAW_AFTER={_hex(2 * index)}",
        f"PUBLICATION_EPOCH={2 * index}",
        f"F4K_ARM={arm}", f"CONFIGURED_MAIN_KP={kp}",
    ]
    for name, value in zip(RAW_NAMES, values):
        parts.append(f"{name}={value}")
        parts.append(f"{name}_RAW={_hex(value)}")
    parts.extend([
        "SCHEMA_VERSION=1", "SCHEMA_MAGIC_EXPECTED=4D50344A",
        "PRODUCER_SOURCE=MAIN_MPLL_UPDATE_DAC0",
        "DYNAMIC_OWNER=F4J_MAIN_PRODUCER", "TRANSPORT_FAILURE=0", "ATTEMPTS=1",
    ])
    return " ".join(parts) + "\n"


def _wr(role: str, end_ms: int) -> str:
    board = "DE5 [1-11.1]" if role == "MASTER" else "DE5 [1-11.2]"
    return (
        "STEP5_F4J_WR_CORE "
        f"role={role} board={board} host_start_ms={end_ms - 1} host_end_ms={end_ms} "
        "WR_CORE_VALID=1 DIRECT_VALID=1 TRANSPORT_FAILURE=0 ROLE_IDENTITY_VALID=1 "
        "RESET_FIELDS_VALID=1 TERMINAL=0 PHY_LINK_USABLE=1 PSTAT_LOCKED=0 "
        "BOOT_GENERATION=1 CPU_RESET=1 WR_CORE_RESET=0 SI_CONFIG_DROP=0 "
        "PHY_STATUS_SOURCE=JTAG_PROBE0 PHY_STATUS_INSTANCE=0 PHY_STATUS_WIDTH_BITS=64 "
        "PHY_GATE_REQUIRED_MASK=000000CF PHY_STATUS_VALID=1 "
        "PHY_STATUS_PROBE0_RAW=0x00000000000000CF WDIAGS_CTRL_DATA_VALID=1\n"
    )


def _cycle(index: int) -> str:
    end_ms = 5000 * index + 10
    return (
        "STEP5_F4J_CYCLE role=SLAVE board=DE5 [1-11.2] "
        f"cycle={index} host_start_ms={end_ms - 5} host_end_ms={end_ms} "
        f"elapsed_ms={end_ms} HELPER_CORE_VALID=1 HELPER_STATE_VALID=1 "
        "HELPER_LOCKED=1 MAIN_PRODUCER_VALID=1 MAIN_UPDATE_ADVANCED=1 "
        "WR_CORE_VALID=1 PHY_LINK_USABLE=1 TERMINAL=0 STOP_REASON=NONE\n"
    )


def _log(arm: str, kp: int, in_band_step: int, count: int = 30) -> str:
    lines = [
        "STEP5_F4J_CONFIG experiment=EXP-S5-F4K-SLAVE-MAIN-KP-ONLY-300-600-ABA-20260916 "
        "run_role=f4j READ_ONLY_OBSERVER=1 ONE_READER=1 READER_PROCESSES=1 "
        "NO_CONTROL_WRITE=1 NO_HELPER_PI_SNAPSHOT=1 NO_DEBUG_FIFO_DRAIN=1 "
        "PRODUCTION_CONTROL_UNCHANGED=0 FUNCTIONAL_EXPERIMENT_SCOPE=F4K_SLAVE_MAIN_KP_ONLY "
        "SOURCE_CONTRACT_VERIFIED=YES target_duration_ms=120000 hard_duration_ms=130000 "
        f"f4k_arm={arm} configured_main_kp={kp}\n",
        "STEP5_F4J_DONE session_elapsed_ms=120000 target_duration_ms=120000 "
        "hard_duration_ms=130000 stop_reason=NONE single_reader=PASS "
        "step5_complete=NO step5_pass=NO merge_approved=NO\n",
        _wr("MASTER", 500),
    ]
    for index in range(1, count + 1):
        lines.append(_main_line(index, in_band_step, arm, kp))
        lines.append(_cycle(index))
        lines.append(_wr("SLAVE", 5000 * index + 20))
    return "".join(lines)


class F4KComparisonTests(unittest.TestCase):
    def _compare(self, a1_step: int, b_step: int, a2_step: int,
                 bad_arm: bool = False) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = {}
            for arm, kp, step in (("A1", 300, a1_step), ("B", 600, b_step), ("A2", 300, a2_step)):
                label = "A1" if bad_arm and arm == "A2" else arm
                path = root / f"{arm}.log"
                path.write_text(_log(label, kp, step), encoding="utf-8")
                paths[arm] = path
            return f4k.compare(paths["A1"], paths["B"], paths["A2"])

    def test_kp_direction_supported(self) -> None:
        result = self._compare(20, 40, 20)
        self.assertEqual(result["classification"], "KP_INCREASE_DIRECTION_SUPPORTED")
        self.assertTrue(result["direction_supported"])
        self.assertFalse(result["step5_pass"])

    def test_kp_doubling_not_supported(self) -> None:
        result = self._compare(20, 25, 20)
        self.assertEqual(result["classification"], "KP_DOUBLING_NOT_SUPPORTED")
        self.assertFalse(result["direction_supported"])

    def test_baseline_reproducibility_is_required(self) -> None:
        result = self._compare(10, 40, 30)
        self.assertEqual(result["classification"], "BASELINE_NOT_REPRODUCIBLE")
        self.assertFalse(result["baseline_reproducible"])

    def test_arm_metadata_is_not_inferred(self) -> None:
        result = self._compare(20, 40, 20, bad_arm=True)
        self.assertEqual(result["classification"], "ARM_DATA_INVALID")
        self.assertFalse(result["diagnostic_pass"])


if __name__ == "__main__":
    unittest.main()
