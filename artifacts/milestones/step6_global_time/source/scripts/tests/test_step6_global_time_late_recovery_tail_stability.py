from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT
    / "scripts"
    / "analysis"
    / "step6_global_time_late_recovery_tail_stability.py"
)
SPEC = importlib.util.spec_from_file_location("step6_tail_stability", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _contract(gate: str = "PASS") -> str:
    text = "".join(
        f"S6_TAIL_GATE_PAIR SAMPLE={index} READ_VALID=1 MASTER_HEALTH=1 "
        "SLAVE_HEALTH=1 MASTER_RESET_CHANGED=0 SLAVE_RESET_CHANGED=0\n"
        for index in range(3)
    )
    return text + f"S6_TAIL_GATE_RESULT={gate}\n"


def _sample(
    board: str,
    index: int,
    *,
    time_valid: int = 1,
    snapshot_valid: int = 1,
    snapshot_time_valid: int = 1,
    snapshot_pps_valid: int = 1,
    snapshot_count: int = 10,
    tick: int = 1000,
    cycles: int = 100,
    ext_state: int = 1,
    ptp_state: int = 9,
    pd_state: int = 4,
    wr_state: int = 2,
    seq: int = 8,
    pstat: int = 1,
    main_locked: int = 1,
    capture_healthy: int = 1,
    time_candidate: int = 1,
) -> str:
    return (
        "S6_TAIL_SAMPLE "
        f"BOARD={board} SAMPLE={index} ELAPSED_MS={index * 400} READ_VALID=1 "
        f"CAPTURE_HEALTHY={capture_healthy} RESET_CHANGED=0 "
        "STATUS_TM_LINK_UP=1 STATUS_LINK_OK=1 RX_LOCKED_TO_DATA=1 "
        "RX_PATTERN_READY=1 "
        f"STATUS_TIME_VALID={time_valid} GLOBAL_TIME_SNAPSHOT_STABLE=1 "
        f"GLOBAL_TIME_SNAPSHOT_VALID={snapshot_valid} "
        f"GLOBAL_TIME_SNAPSHOT_TIME_VALID={snapshot_time_valid} "
        f"GLOBAL_TIME_SNAPSHOT_PPS_VALID={snapshot_pps_valid} "
        f"GLOBAL_TIME_SNAPSHOT_COUNT={snapshot_count} "
        f"GLOBAL_TIME_TICK={tick} GLOBAL_TIME_CYCLES={cycles} "
        f"PTP_STATE={ptp_state} PD_STATE={pd_state} EXT_STATE={ext_state} "
        f"WR_STATE_VALUE={wr_state} SPLL_SEQ_STATE={seq} "
        f"PSTAT_LOCKED={pstat} MAIN_LOCKED={main_locked} "
        f"TIME_RECOVERY_CANDIDATE={time_candidate}\n"
    )


def _pass_capture() -> str:
    text = _contract()
    for index in range(5):
        text += _sample("SLAVE", index, snapshot_count=10 + index, tick=1000 + index * 10)
        text += _sample(
            "MASTER",
            index,
            snapshot_count=100 + index,
            tick=10000 + index * 10,
            time_candidate=0,
        )
    return text + "S6_TAIL_CAPTURE_RESULT=PASS_LATE_RECOVERY_STABLE SAMPLES=10\n"


def test_formal_late_recovery_pass() -> None:
    result = MODULE.analyze_text(_pass_capture())
    assert result["classification"] == "PASS_LATE_RECOVERY_STABLE"
    assert result["global_time_late_recovery"] == "CONFIRMED_STABLE"
    assert result["step6a_1"] == "PASS"
    assert result["best_count_advances"] >= 2


def test_gate_failure_is_inconclusive() -> None:
    result = MODULE.analyze_text(_contract("INCONCLUSIVE_TAIL_PRECONDITION_CHANGED"))
    assert result["classification"] == "INCONCLUSIVE_TAIL_PRECONDITION_CHANGED"
    assert result["step6a_1"] == "NOT_EVALUATED"


def test_terminal_fallback_not_sustained() -> None:
    text = _contract()
    for index in range(5):
        text += _sample(
            "SLAVE",
            index,
            time_valid=0,
            snapshot_valid=0,
            snapshot_time_valid=0,
            snapshot_pps_valid=0,
            snapshot_count=0,
            tick=-1,
            ext_state=2,
            ptp_state=9,
            pd_state=4,
            wr_state=0,
            time_candidate=0,
        )
        text += _sample("MASTER", index, time_candidate=0)
    text += "S6_TAIL_CAPTURE_RESULT=FAIL_LATE_RECOVERY_NOT_SUSTAINED\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_LATE_RECOVERY_NOT_SUSTAINED"


def test_recovery_loss_is_reported() -> None:
    text = _contract()
    states = [(0, 1), (1, 1), (0, 1), (0, 1)]
    for index, (time_valid, ext_state) in enumerate(states):
        text += _sample(
            "SLAVE",
            index,
            time_valid=time_valid,
            snapshot_valid=time_valid,
            snapshot_time_valid=time_valid,
            snapshot_pps_valid=time_valid,
            snapshot_count=10 + index if time_valid else 0,
            tick=1000 + index if time_valid else -1,
            ext_state=ext_state,
            time_candidate=time_valid,
        )
        text += _sample("MASTER", index, time_candidate=0)
    text += "S6_TAIL_CAPTURE_RESULT=FAIL_GLOBAL_TIME_RECOVERY_LOST\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_GLOBAL_TIME_RECOVERY_LOST"
    assert result["time_valid_rising_edges"] == 1
    assert result["time_valid_falling_edges"] == 1


def test_valid_streak_without_snapshot_progress_fails() -> None:
    text = _contract()
    for index in range(5):
        text += _sample("SLAVE", index, snapshot_count=7, tick=2000 + index)
        text += _sample("MASTER", index, time_candidate=0)
    text += "S6_TAIL_CAPTURE_RESULT=CAPTURE_COMPLETE\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_GLOBAL_TIME_PPS_SNAPSHOT_NOT_ADVANCING"


def test_active_oscillation_fails_when_no_formal_window_exists() -> None:
    text = _contract()
    for index, time_valid in enumerate((0, 1, 1, 1)):
        text += _sample(
            "SLAVE",
            index,
            time_valid=time_valid,
            snapshot_valid=time_valid,
            snapshot_time_valid=time_valid,
            snapshot_pps_valid=time_valid,
            snapshot_count=index if time_valid else 0,
            tick=3000 + index if time_valid else -1,
            time_candidate=time_valid,
        )
        text += _sample("MASTER", index, time_candidate=0)
    text += "S6_TAIL_CAPTURE_RESULT=CAPTURE_COMPLETE\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_INTERMITTENT_GLOBAL_TIME_VALIDITY"


def test_runtime_invalid_is_inconclusive() -> None:
    text = _contract()
    text += _sample("SLAVE", 0, capture_healthy=0, time_candidate=0)
    text += _sample("MASTER", 0, capture_healthy=0, time_candidate=0)
    text += "S6_TAIL_CAPTURE_RESULT=INCONCLUSIVE_RUNTIME_STATE_CHANGED\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
