from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT
    / "scripts"
    / "analysis"
    / "step6_same_pps_global_time_consistency.py"
)
SPEC = importlib.util.spec_from_file_location("step6_same_pps", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _contract(gate: str = "PASS") -> str:
    text = "".join(
        f"S6A2_GATE_PAIR SAMPLE={index} READ_VALID=1 MASTER_GATE=1 SLAVE_GATE=1 "
        "MASTER_RESET_CHANGED=0 SLAVE_RESET_CHANGED=0\n"
        for index in range(3)
    )
    return text + f"S6A2_GATE_RESULT={gate}\n"


def _sample(
    board: str,
    index: int,
    *,
    tai: int,
    cycles: int,
    count: int,
    accepted: int = 1,
    time_valid: int = 1,
    snapshot_valid: int = 1,
    stable: int = 1,
    reset_changed: int = 0,
    capture_healthy: int = 1,
) -> str:
    return (
        "S6A2_SAMPLE "
        f"BOARD={board} SAMPLE={index} ELAPSED_MS={index * 250} "
        f"READ_VALID=1 CAPTURE_HEALTHY={capture_healthy} RESET_CHANGED={reset_changed} "
        "STATUS_TM_LINK_UP=1 STATUS_LINK_OK=1 RX_PATTERN_READY=1 "
        f"STATUS_TIME_VALID={time_valid} STATUS_PPS_VALID={time_valid} "
        f"SNAPSHOT_STABLE={stable} SNAPSHOT_ACCEPTED={accepted} "
        f"SNAPSHOT_VALID={snapshot_valid} SNAPSHOT_TIME_VALID={time_valid} "
        f"SNAPSHOT_PPS_VALID={time_valid} SNAPSHOT_TAI={tai} "
        f"SNAPSHOT_CYCLES={cycles} SNAPSHOT_COUNT={count} "
        "SPLL_SEQ_STATE=8 PSTAT_LOCKED=1 MAIN_LOCKED=1 "
        "RX_LOCKED_TO_DATA=1 RX_PATTERN_READY=1\n"
    )


def _exact_pass() -> str:
    text = _contract()
    for index in range(5):
        text += _sample("MASTER", index, tai=8000 + index, cycles=123, count=10 + index)
        text += _sample("SLAVE", index, tai=8000 + index, cycles=123, count=20 + index)
    return text + "S6A2_CAPTURE_RESULT=PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY\n"


def test_exact_common_tai_and_cycles_pass() -> None:
    result = MODULE.analyze_text(_exact_pass())
    assert result["classification"] == "PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY"
    assert result["common_tai_count"] == 5
    assert result["exact_match_count"] == 5
    assert result["max_abs_delta_ticks"] == 0
    assert result["step6a_2"] == "PASS"


def test_gate_failure_is_not_evaluated() -> None:
    result = MODULE.analyze_text(_contract("INCONCLUSIVE_STEP6A2_PRECONDITION_CHANGED"))
    assert result["classification"] == "INCONCLUSIVE_STEP6A2_PRECONDITION_CHANGED"
    assert result["step6a_2"] == "NOT_EVALUATED"


def test_three_cycle_mismatches_fail_offset() -> None:
    text = _contract()
    for index in range(3):
        text += _sample("MASTER", index, tai=8100 + index, cycles=500, count=index)
        text += _sample("SLAVE", index, tai=8100 + index, cycles=501, count=index)
    text += "S6A2_CAPTURE_RESULT=FAIL_SAME_PPS_GLOBAL_TIME_OFFSET\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_SAME_PPS_GLOBAL_TIME_OFFSET"
    assert result["unique_delta_ticks"] == [1]
    assert result["max_abs_delta_ns"] == 8


def test_same_tai_twice_with_different_cycles_is_inconclusive() -> None:
    text = _contract()
    text += _sample("MASTER", 0, tai=8200, cycles=500, count=1)
    text += _sample("MASTER", 1, tai=8200, cycles=501, count=2)
    text += _sample("SLAVE", 0, tai=8200, cycles=500, count=1)
    text += "S6A2_CAPTURE_RESULT=INCONCLUSIVE_SNAPSHOT_COHERENCE_VIOLATION\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE_SNAPSHOT_COHERENCE_VIOLATION"
    assert result["coherence_violation"] is True


def test_global_time_loss_blocks_same_pps_verdict() -> None:
    text = _contract()
    text += _sample("MASTER", 0, tai=8300, cycles=500, count=1)
    text += _sample("SLAVE", 0, tai=8300, cycles=500, count=1)
    text += _sample("MASTER", 1, tai=8301, cycles=500, count=2,
                    time_valid=0, snapshot_valid=0, accepted=0)
    text += _sample("SLAVE", 1, tai=8301, cycles=500, count=2,
                    time_valid=0, snapshot_valid=0, accepted=0)
    text += "S6A2_CAPTURE_RESULT=FAIL_STEP6A1_STABILITY_REGRESSION_DURING_STEP6A2\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_STEP6A1_STABILITY_REGRESSION_DURING_STEP6A2"


def test_insufficient_common_labels_is_inconclusive() -> None:
    text = _contract()
    for index in range(2):
        text += _sample("MASTER", index, tai=8400 + index, cycles=1, count=index)
        text += _sample("SLAVE", index, tai=8400 + index, cycles=1, count=index)
    text += "S6A2_CAPTURE_RESULT=CAPTURE_COMPLETE\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE_INSUFFICIENT_COMMON_PPS_LABELS"


def test_runtime_invalid_is_inconclusive() -> None:
    text = _contract()
    text += _sample("MASTER", 0, tai=8500, cycles=1, count=1, capture_healthy=0)
    text += _sample("SLAVE", 0, tai=8500, cycles=1, count=1, capture_healthy=0)
    result = MODULE.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
