from __future__ import annotations

import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "analysis" / "step6b_live_session_trigger.py"
SPEC = importlib.util.spec_from_file_location("step6b_live", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


PASS = """\
S6B_SOURCE_WRITE BOARD=MASTER ROLE=MASTER INDEX=67 VALUE=00000000000000000001 OK=1
S6B_SOURCE_WRITE BOARD=SLAVE ROLE=SLAVE INDEX=67 VALUE=00000000000000000001 OK=1
S6B_SOURCE_WRITE BOARD=MASTER ROLE=MASTER INDEX=68 VALUE=1 OK=1
S6B_SOURCE_WRITE BOARD=SLAVE ROLE=SLAVE INDEX=68 VALUE=1 OK=1
S6B_LIVE_RESULT=PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER PHASE=capture TRIAL=x T0=100 TARGET_TAI=120 TARGET_CYCLES=62500000 GATE_PAIRS=3 COMMON_TAI_COUNT=3 COHERENCE_VIOLATION=0 TARGET_WRITE_MASTER=1 TARGET_WRITE_SLAVE=1 ARM_WRITE_MASTER=1 ARM_WRITE_SLAVE=1 CAPTURE_SAMPLES=10 POST_FIRE_SAMPLES=3 MASTER_FIRED=1 SLAVE_FIRED=1 MASTER_FIRE_COUNT=1 SLAVE_FIRE_COUNT=1 MASTER_ACTUAL_TAI=120 MASTER_ACTUAL_CYCLES=62500000 SLAVE_ACTUAL_TAI=120 SLAVE_ACTUAL_CYCLES=62500000 DIGITAL_TRIGGER_DELTA_TICKS=0 DIGITAL_TRIGGER_DELTA_NS=0
"""


def test_formal_pass_requires_exact_source_write_sequence() -> None:
    result = MODULE.analyze_text(PASS)
    assert result["classification"] == "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER"
    assert result["verdict"] == "PASS"
    assert result["step6b_postfit_timing"] == "NOT_EVALUATED"
    assert result["source_write_counts"] == {
        "master_target": 1,
        "slave_target": 1,
        "master_arm": 1,
        "slave_arm": 1,
    }


def test_timestamp_mismatch_is_failure() -> None:
    result = MODULE.analyze_text(
        PASS.replace(
            "SLAVE_ACTUAL_CYCLES=62500000",
            "SLAVE_ACTUAL_CYCLES=62500001",
        ).replace(
            "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER",
            "FAIL_SCHEDULED_TRIGGER_TIMESTAMP_MISMATCH",
        )
    )
    assert result["classification"] == "FAIL_SCHEDULED_TRIGGER_TIMESTAMP_MISMATCH"
    assert result["verdict"] == "FAIL"


def test_prewrite_gate_failure_is_inconclusive() -> None:
    result = MODULE.analyze_text(
        "S6B_LIVE_RESULT=INCONCLUSIVE_LIVE_SESSION_PREWRITE_GATE_FAILED PHASE=prewrite_gate "
        "GATE_PAIRS=1 COMMON_TAI_COUNT=0 COHERENCE_VIOLATION=0 "
        "TARGET_WRITE_MASTER=0 TARGET_WRITE_SLAVE=0 ARM_WRITE_MASTER=0 ARM_WRITE_SLAVE=0"
    )
    assert result["classification"] == "INCONCLUSIVE_LIVE_SESSION_PREWRITE_GATE_FAILED"
    assert result["verdict"] == "INCONCLUSIVE"
