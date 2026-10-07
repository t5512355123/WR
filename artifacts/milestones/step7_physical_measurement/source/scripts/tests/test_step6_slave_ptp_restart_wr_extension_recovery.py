from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT
    / "scripts"
    / "analysis"
    / "step6_slave_ptp_restart_wr_extension_recovery.py"
)
SPEC = importlib.util.spec_from_file_location("step6_ptp_restart_recovery", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _contract(*, gate: str = "PASS", injection: str = "PASS") -> str:
    text = "".join(
        f"S6_PTP_RESTART_GATE_PAIR SAMPLE={index} READ_VALID=1 "
        "MASTER_PRECONDITION=1 SLAVE_PRECONDITION=1 "
        "MASTER_RESET_CHANGED=0 SLAVE_RESET_CHANGED=0\n"
        for index in range(5)
    )
    if gate == "PASS":
        text += "S6_PTP_RESTART_GATE_RESULT=PASS\n"
    else:
        text += "S6_PTP_RESTART_GATE_RESULT=INCONCLUSIVE_PRE_RESTART_STATE_CHANGED\n"
    text += f"S6_PTP_RESTART_INJECTION_RESULT={injection}\n"
    return text


def _sample(
    board: str,
    sample: int,
    *,
    ext_state: int = 1,
    wr_state: int = 2,
    time_valid: int = 1,
    snapshot_valid: int = 1,
    snapshot_time_valid: int = 1,
    snapshot_pps_valid: int = 1,
    snapshot_count: int = 10,
    rearm: int = 1,
    master_reengagement: int = 1,
    seq: int = 8,
    pstat: int = 1,
    main_locked: int = 1,
    handshake: int = 1,
    snapshot_stable: int = 1,
) -> str:
    return (
        "S6_PTP_RESTART_SAMPLE "
        f"BOARD={board} SAMPLE={sample} READ_VALID=1 CAPTURE_HEALTHY=1 "
        "RESET_CHANGED=0 LINK_HEALTHY=1 "
        f"EXT_STATE={ext_state} WR_STATE_VALUE={wr_state} "
        f"STATUS_TIME_VALID={time_valid} "
        f"GLOBAL_TIME_SNAPSHOT_STABLE={snapshot_stable} "
        f"GLOBAL_TIME_SNAPSHOT_VALID={snapshot_valid} "
        f"GLOBAL_TIME_SNAPSHOT_TIME_VALID={snapshot_time_valid} "
        f"GLOBAL_TIME_SNAPSHOT_PPS_VALID={snapshot_pps_valid} "
        f"GLOBAL_TIME_SNAPSHOT_COUNT={snapshot_count} "
        f"SLAVE_REARM_EVIDENCE={rearm} "
        f"MASTER_REENGAGEMENT_EVIDENCE={master_reengagement} "
        f"SPLL_SEQ_STATE={seq} PSTAT_LOCKED={pstat} MAIN_LOCKED={main_locked} "
        f"HANDSHAKE_REARMED={handshake}\n"
    )


def _pass_capture() -> str:
    text = _contract()
    for index in range(5):
        text += _sample("SLAVE", index, snapshot_count=10 + index)
        text += _sample("MASTER", index, time_valid=1, snapshot_valid=0,
                        snapshot_time_valid=0, snapshot_pps_valid=0,
                        rearm=0, master_reengagement=1, handshake=0)
    text += (
        "S6_PTP_RESTART_CAPTURE_RESULT="
        "PASS_SLAVE_PTP_RESTART_WR_EXTENSION_RECOVERY SAMPLES=10\n"
    )
    return text


def test_pass_requires_five_valid_advancing_snapshots() -> None:
    result = MODULE.analyze_text(_pass_capture())
    assert result["classification"] == "PASS_SLAVE_PTP_RESTART_WR_EXTENSION_RECOVERY"
    assert result["step6a_1"] == "PASS_POST_RECOVERY"
    assert result["formal_time_pass"] is True
    assert result["best_count_advances"] >= 2
    assert result["step6b"] == "NOT_RUN"


def test_gate_failure_is_inconclusive_and_no_restart_evidence_is_used() -> None:
    result = MODULE.analyze_text(_contract(gate="FAIL"))
    assert result["classification"] == "INCONCLUSIVE_PRE_RESTART_STATE_CHANGED"
    assert result["verdict"] == "INCONCLUSIVE"
    assert result["step6a_1"] == "NOT_PASS"


def test_command_transport_failure_is_inconclusive() -> None:
    text = _contract(injection="INCONCLUSIVE_COMMAND_TRANSPORT")
    result = MODULE.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE_COMMAND_TRANSPORT"
    assert result["verdict"] == "INCONCLUSIVE"


def test_no_slave_rearm_is_a_failure() -> None:
    text = _contract()
    for index in range(4):
        text += _sample("SLAVE", index, ext_state=2, wr_state=0,
                        time_valid=0, snapshot_valid=0,
                        snapshot_time_valid=0, snapshot_pps_valid=0,
                        rearm=0, master_reengagement=0, handshake=0)
        text += _sample("MASTER", index, ext_state=1, wr_state=3,
                        rearm=0, master_reengagement=1, handshake=0)
    text += "S6_PTP_RESTART_CAPTURE_RESULT=FAIL_SLAVE_PTP_RESTART_DID_NOT_REARM_WR_EXTENSION\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_SLAVE_PTP_RESTART_DID_NOT_REARM_WR_EXTENSION"


def test_slave_rearm_without_master_is_a_failure() -> None:
    text = _contract()
    for index in range(3):
        text += _sample("SLAVE", index, time_valid=0, snapshot_valid=0,
                        snapshot_time_valid=0, snapshot_pps_valid=0,
                        master_reengagement=0)
        text += _sample("MASTER", index, ext_state=2, wr_state=0,
                        time_valid=1, snapshot_valid=0,
                        snapshot_time_valid=0, snapshot_pps_valid=0,
                        rearm=0, master_reengagement=0, handshake=0)
    text += "S6_PTP_RESTART_CAPTURE_RESULT=FAIL_SLAVE_REARMED_MASTER_NOT_REENGAGED\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_SLAVE_REARMED_MASTER_NOT_REENGAGED"


def test_softpll_disturbance_precedes_recovery_classification() -> None:
    text = _contract()
    for index in range(3):
        text += _sample("SLAVE", index, seq=4, pstat=0, main_locked=0,
                        time_valid=0, snapshot_valid=0,
                        snapshot_time_valid=0, snapshot_pps_valid=0)
        text += _sample("MASTER", index, rearm=0, master_reengagement=1)
    text += "S6_PTP_RESTART_CAPTURE_RESULT=FAIL_SLAVE_PTP_RESTART_DISTURBED_SOFTPLL_READY_STATE\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_SLAVE_PTP_RESTART_DISTURBED_SOFTPLL_READY_STATE"


def test_transient_time_valid_does_not_pass() -> None:
    text = _contract()
    for index in range(5):
        text += _sample("SLAVE", index, snapshot_count=20 + index,
                        snapshot_stable=1 if index == 0 else 0)
        text += _sample("MASTER", index, rearm=0, master_reengagement=1)
    text += "S6_PTP_RESTART_CAPTURE_RESULT=FAIL_TRANSIENT_GLOBAL_TIME_RECOVERY\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_TRANSIENT_GLOBAL_TIME_RECOVERY"
    assert result["formal_time_pass"] is False
