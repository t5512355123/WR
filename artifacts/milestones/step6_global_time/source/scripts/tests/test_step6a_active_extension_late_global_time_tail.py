from __future__ import annotations

import importlib.util
from pathlib import Path


MODULE_PATH = (
    Path(__file__).parents[1]
    / "analysis"
    / "step6a_active_extension_late_global_time_tail.py"
)
SPEC = importlib.util.spec_from_file_location("step6a_tail", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _result(**extra: str) -> str:
    fields = {
        "GATE_PAIRS": "3",
        "TAIL_SAMPLES": "30",
        "VALID_SAMPLES": "8",
        "MAX_VALID_STREAK": "8",
        "FIRST_VALID_MS": "1000",
        "LAST_VALID_MS": "5000",
        "SNAPSHOT_DELTA": "4",
        "COMMON_TAI_COUNT": "4",
        "MAX_ABS_DELTA_TICKS": "0",
        "TIME_VALID_RISING": "1",
        "TIME_VALID_FALLING": "0",
        "ACTIVE_SAMPLES": "30",
        "COHERENCE_VIOLATION": "0",
    }
    fields.update(extra)
    return "S6A_TAIL_RESULT=PASS_ACTIVE_EXTENSION_LATE_GLOBAL_TIME_RECOVERY " + " ".join(
        f"{key}={value}" for key, value in fields.items()
    )


def test_late_tail_pass_requires_zero_delta_and_streak() -> None:
    result = MODULE.analyze_text(_result())
    assert result["classification"] == "PASS_ACTIVE_EXTENSION_LATE_GLOBAL_TIME_RECOVERY"
    assert result["verdict"] == "PASS"
    assert result["step6a_requalification"] == "PASS"
    assert result["max_abs_delta_ns"] == 0


def test_active_extension_stuck_is_failure() -> None:
    text = _result(
        MAX_VALID_STREAK="0",
        VALID_SAMPLES="0",
        SNAPSHOT_DELTA="0",
        COMMON_TAI_COUNT="0",
        MAX_ABS_DELTA_TICKS="NA",
    ).replace(
        "PASS_ACTIVE_EXTENSION_LATE_GLOBAL_TIME_RECOVERY",
        "FAIL_ACTIVE_EXTENSION_GLOBAL_TIME_STUCK",
    )
    result = MODULE.analyze_text(text)
    assert result["classification"] == "FAIL_ACTIVE_EXTENSION_GLOBAL_TIME_STUCK"
    assert result["verdict"] == "FAIL"


def test_missing_result_is_inconclusive() -> None:
    result = MODULE.analyze_text("S6A_DONE result=INCONCLUSIVE_CURRENT_SESSION_PRECONDITION_CHANGED")
    assert result["classification"] == "INCONCLUSIVE_MISSING_OBSERVER_RESULT"
    assert result["verdict"] == "INCONCLUSIVE"
