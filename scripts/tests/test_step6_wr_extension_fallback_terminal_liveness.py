from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT
    / "scripts"
    / "analysis"
    / "step6_wr_extension_fallback_terminal_liveness.py"
)
SPEC = importlib.util.spec_from_file_location("step6_wr_fallback_liveness", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _gate(slave: int = 1) -> str:
    return "".join(
        f"WR_FALLBACK_LIVENESS_GATE_PAIR SAMPLE={i} READ_VALID=1 "
        f"MASTER_PRECONDITION=1 SLAVE_PRECONDITION={slave} "
        "MASTER_RESET_CHANGED=0 SLAVE_RESET_CHANGED=0\n"
        for i in range(5)
    ) + ("WR_FALLBACK_LIVENESS_GATE_RESULT=PASS\n" if slave else
         "WR_FALLBACK_LIVENESS_GATE_RESULT=INCONCLUSIVE_FALLBACK_PRECONDITION_CHANGED\n")


def _sample(
    board: str,
    sample: int,
    *,
    seq: int = 8,
    pstat: int = 1,
    time_valid: int = 0,
    wr_state: int = 0,
    ext_state: int = 2,
    reentry_counter: int = 0,
    capture_healthy: int = 1,
    counter_decrease: int = 0,
) -> str:
    return (
        "WR_FALLBACK_LIVENESS_SAMPLE "
        f"BOARD={board} SAMPLE={sample} READ_VALID=1 "
        f"CAPTURE_HEALTHY={capture_healthy} RESET_CHANGED=0 "
        f"COUNTER_DECREASE={counter_decrease} REENTRY_COUNTER_INCREASE={reentry_counter} "
        f"WR_STATE_VALUE={wr_state} PTP_STATE=9 PD_STATE=4 EXT_STATE={ext_state} WRC_MODE=3 "
        f"STATUS_TIME_VALID={time_valid} RX_PATTERN_READY=1 "
        f"SPLL_SEQ_STATE={seq} PSTAT_LOCKED={pstat} MAIN_ENABLED={pstat} "
        f"MAIN_FREQ_LOCKED={pstat} MAIN_PHASE_LOCKED={pstat} MAIN_LOCKED={pstat} "
        "WR_LOCK_POLL_COUNT=10 LOCK_ENABLE_COUNT=2 SLOCK_TRACE_SEQ=7\n"
    )


def test_terminal_fallback_with_pll_ready() -> None:
    text = _gate()
    for i in range(6):
        text += _sample("MASTER", i)
        text += _sample("SLAVE", i)
    text += "WR_FALLBACK_LIVENESS_CAPTURE_RESULT=PASS_CAPTURE SAMPLES=12 ELAPSED_MS=15000\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "PASS_TERMINAL_WR_FALLBACK_WITH_PLL_READY"
    assert result["wr_extension_fallback_liveness"] == "TERMINAL_NO_AUTONOMOUS_RETRY"
    assert result["failure_class"] == "WR_EXTENSION_DISABLED_WHILE_SOFTPLL_READY"
    assert result["step6a"] == "NOT_PASS"
    assert result["step6b"] == "NOT_RUN"


def test_terminal_fallback_with_pll_not_ready() -> None:
    text = _gate()
    for i in range(6):
        text += _sample("MASTER", i)
        text += _sample("SLAVE", i, seq=4, pstat=0)
    text += "WR_FALLBACK_LIVENESS_CAPTURE_RESULT=PASS_CAPTURE SAMPLES=12 ELAPSED_MS=15000\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "PASS_TERMINAL_WR_FALLBACK_WITH_PLL_NOT_READY"
    assert result["pll_ready"] is False
    assert result["failure_class"] == "WR_EXTENSION_DISABLED_AND_SOFTPLL_NOT_READY"


def test_autonomous_reentry_is_an_event_not_a_step6_pass() -> None:
    text = _gate()
    text += _sample("MASTER", 0)
    text += _sample("SLAVE", 0)
    text += _sample("MASTER", 1)
    text += _sample("SLAVE", 1, wr_state=2, ext_state=1, time_valid=1)
    text += (
        "WR_FALLBACK_LIVENESS_CAPTURE_RESULT="
        "WR_EXTENSION_AUTONOMOUS_REENTRY_OBSERVED SAMPLES=4 ELAPSED_MS=500\n"
    )
    result = MODULE.analyze_text(text)
    assert result["classification"] == "WR_EXTENSION_AUTONOMOUS_REENTRY_OBSERVED"
    assert result["step6a_recovery_event"] == "OBSERVED"
    assert result["step6a"] == "NOT_PASS"


def test_gate_failure_stops_before_liveness_classification() -> None:
    result = MODULE.analyze_text(_gate(slave=0))
    assert result["classification"] == "INCONCLUSIVE_FALLBACK_PRECONDITION_CHANGED"
    assert result["wr_extension_fallback_liveness"] == "NOT_EVALUATED"
    assert result["step6b"] == "NOT_RUN"


def test_runtime_change_is_inconclusive() -> None:
    text = _gate()
    text += _sample("MASTER", 0)
    text += _sample("SLAVE", 0, capture_healthy=0)
    text += "WR_FALLBACK_LIVENESS_CAPTURE_RESULT=INCONCLUSIVE_RUNTIME_STATE_CHANGED SAMPLES=2 ELAPSED_MS=350\n"
    result = MODULE.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
    assert result["runtime_invalid"] is True
