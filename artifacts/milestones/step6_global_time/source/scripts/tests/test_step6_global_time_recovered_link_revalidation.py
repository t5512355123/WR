from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "analysis" / "step6_global_time_recovered_link_revalidation.py"
SPEC = importlib.util.spec_from_file_location("step6_gt_revalidation", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _gate() -> str:
    return "\n".join(
        f"GLOBAL_TIME_REVALIDATION_GATE_PAIR SAMPLE={i} READ_VALID=1 "
        "MASTER_PRECONDITION=1 SLAVE_PRECONDITION=1 "
        "MASTER_RESET_CHANGED=0 SLAVE_RESET_CHANGED=0"
        for i in range(5)
    ) + "\nGLOBAL_TIME_GATE_RESULT=PASS\n"


def _sample(board: str, sample: int, *, time_valid: int = 1,
            snapshot_valid: int = 1, snapshot_count: int | None = None,
            live_cycles: int | None = None, stable: int = 1,
            link_healthy: int = 1, reset_changed: int = 0,
            ptp_state: int = 9, pd_state: int = 0,
            ext_state: int = 2, wrc_mode: int = 3) -> str:
    count = sample + 10 if snapshot_count is None else snapshot_count
    cycles = 10_000_000 + sample * 1_000_000
    live = cycles if live_cycles is None else live_cycles
    return (
        "GLOBAL_TIME_REVALIDATION_SAMPLE BOARD={board} SAMPLE={sample} "
        "READ_VALID=1 STABLE={stable} LINK_HEALTHY={link} "
        "RESET_CHANGED={reset} STATUS_TIME_VALID={time} STATUS_PPS_VALID=1 "
        "SNAPSHOT_VALID={snap} SNAPSHOT_TIME_VALID={time} "
        "SNAPSHOT_PPS_VALID=1 SNAPSHOT_COUNT={count} TAI=100 CYCLES={cycles} "
        "LIVE_TAI_LO=100 LIVE_CYCLES={live} PTP_STATE={ptp} PD_STATE={pd} "
        "EXT_STATE={ext} WRC_MODE={mode}\n"
    ).format(
        board=board, sample=sample, stable=stable, link=link_healthy,
        reset=reset_changed, time=time_valid, snap=snapshot_valid,
        count=count, cycles=cycles, live=live, ptp=ptp_state,
        pd=pd_state, ext=ext_state, mode=wrc_mode,
    )


def test_both_boards_pass_step6a1() -> None:
    text = _gate()
    for i in range(6):
        text += _sample("MASTER", i)
        text += _sample("SLAVE", i)
    text += "GLOBAL_TIME_CAPTURE_RESULT=PASS_CAPTURE SAMPLES=12 ELAPSED_MS=8000\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "GLOBAL_TIME_RECOVERY_PASS"
    assert result["step6a_1"] == "PASS"
    assert result["step6b"] == "NOT_RUN"
    assert result["master_slave_same_pps"] == "NOT_EVALUATED"


def test_slave_link_recovered_but_global_time_invalid_is_failure() -> None:
    text = _gate()
    for i in range(6):
        text += _sample("MASTER", i)
        text += _sample(
            "SLAVE", i, time_valid=0, snapshot_valid=0,
            snapshot_count=0, ptp_state=9, pd_state=4, ext_state=2, wrc_mode=3,
        )
    text += "GLOBAL_TIME_CAPTURE_RESULT=PASS_CAPTURE SAMPLES=12 ELAPSED_MS=8000\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_SLAVE_GLOBAL_TIME_NOT_VALID_AFTER_LINK_RECOVERY"
    assert result["failure_class"] == "FAIL_GLOBAL_TIME_BLOCKED_BY_WR_EXTENSION_PTP_FALLBACK"
    assert result["step6a_1"] == "FAIL"


def test_gate_failure_does_not_evaluate_global_time() -> None:
    text = (
        "GLOBAL_TIME_REVALIDATION_GATE_PAIR SAMPLE=0 READ_VALID=1 "
        "MASTER_PRECONDITION=1 SLAVE_PRECONDITION=0 "
        "MASTER_RESET_CHANGED=0 SLAVE_RESET_CHANGED=0\n"
        "GLOBAL_TIME_GATE_RESULT=INCONCLUSIVE_LINK_PRECONDITION\n"
        "GLOBAL_TIME_REVALIDATION_DONE result=INCONCLUSIVE_LINK_PRECONDITION phase=gate\n"
    )
    result = MODULE.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE_LINK_PRECONDITION"
    assert result["step6a_1"] == "NOT_EVALUATED"


def test_non_monotonic_live_counter_fails() -> None:
    text = _gate()
    for i in range(6):
        text += _sample("MASTER", i, live_cycles=100_000_000 - i * 100)
        text += _sample("SLAVE", i)
    text += "GLOBAL_TIME_CAPTURE_RESULT=PASS_CAPTURE SAMPLES=12 ELAPSED_MS=8000\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_GLOBAL_TIME_MONOTONICITY"
