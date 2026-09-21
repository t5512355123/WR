from __future__ import annotations

import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "analysis" / "step6b_digital_scheduled_dual_board_trigger.py"
SPEC = importlib.util.spec_from_file_location("step6b_analyzer", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _board(role: str, actual_tai: int = 100, actual_cycles: int = 62_500_000, count: int = 1, fired: int = 1) -> str:
    return (
        f"S6B_SAMPLE ROLE={role} READ_VALID=1 RESET_CHANGED=0 "
        "CAPTURE_HEALTHY=1 LINK_HEALTHY=1 STATUS_TIME_VALID=1 "
        "STATUS_PPS_VALID=1 STATUS_LINK_OK=1 STATUS_TM_LINK_UP=1 "
        f"PLL_READY=1 RX_PATTERN_READY=1 STEP6B_FIRED={fired} "
        f"STEP6B_FIRE_COUNT={count} STEP6B_ACTUAL_TAI={actual_tai} "
        f"STEP6B_ACTUAL_CYCLES={actual_cycles} STEP6B_FIXED_TARGET_CYCLES=62500000"
    )


def _base(master: str, slave: str) -> str:
    return "\n".join(
        [
            "S6B_CONFIG TARGET_CYCLES=62500000",
            "S6B_PREARM_PAIR PAIRED_HEALTHY=5 COMMON_TAI_COUNT=3",
            "S6B_GATE_RESULT=PASS PAIRED_HEALTHY=5 COMMON_TAI_COUNT=3 T0=80",
            "S6B_TARGET_VERIFY ROLE=MASTER TARGET_TAI_SOURCE=100",
            "S6B_TARGET_VERIFY ROLE=SLAVE TARGET_TAI_SOURCE=100",
            "S6B_TARGET_SETUP_RESULT=PASS TARGET_TAI=100 TARGET_CYCLES=62500000",
            "S6B_ARM_VERIFY ROLE=MASTER STEP6B_ARMED=1 STEP6B_FIRED=0",
            "S6B_ARM_VERIFY ROLE=SLAVE STEP6B_ARMED=1 STEP6B_FIRED=0",
            "S6B_ARM_RESULT=PASS TARGET_TAI=100 TARGET_CYCLES=62500000",
            master,
            slave,
            "S6B_CAPTURE_RESULT=PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER "
            "TARGET_TAI=100 TARGET_CYCLES=62500000 MASTER_FIRED=1 SLAVE_FIRED=1 "
            "MASTER_FIRE_COUNT=1 SLAVE_FIRE_COUNT=1 TARGET_MATCH=PASS "
            "DIGITAL_TRIGGER_DELTA_TICKS=0 DIGITAL_TRIGGER_DELTA_NS=0",
        ]
    )


def test_pass_requires_exact_target_and_one_shot() -> None:
    result = MODULE.analyze_text(_base(_board("MASTER"), _board("SLAVE")))
    assert result["classification"] == "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER"
    assert result["step6a"] == "PASS"
    assert result["step6b_1_digital_scheduled_trigger"] == "PASS"
    assert result["digital_trigger_delta_ticks"] == 0


def test_one_sided_fire_fails() -> None:
    result = MODULE.analyze_text(_base(_board("MASTER"), _board("SLAVE", fired=0, count=0)))
    assert result["classification"] == "FAIL_ONE_SIDED_SCHEDULED_TRIGGER"
    assert result["step6b_1_digital_scheduled_trigger"] == "NOT_PASS"


def test_timestamp_mismatch_fails() -> None:
    result = MODULE.analyze_text(_base(_board("MASTER"), _board("SLAVE", actual_cycles=62_500_001)))
    assert result["classification"] == "FAIL_SCHEDULED_TRIGGER_TIMESTAMP_MISMATCH"
    assert result["digital_trigger_delta_ticks"] == 1


def test_target_miss_fails() -> None:
    result = MODULE.analyze_text(_base(_board("MASTER", actual_tai=101), _board("SLAVE", actual_tai=101)))
    assert result["classification"] == "FAIL_COMMON_TRIGGER_TARGET_MISS"


def test_count_above_one_fails() -> None:
    result = MODULE.analyze_text(_base(_board("MASTER", count=2), _board("SLAVE", count=2)))
    assert result["classification"] == "FAIL_TRIGGER_ONE_SHOT_VIOLATION"


def test_prearm_failure_does_not_claim_step6b() -> None:
    text = _base(_board("MASTER"), _board("SLAVE")).replace(
        "S6B_GATE_RESULT=PASS", "S6B_GATE_RESULT=INCONCLUSIVE_STEP6A_PRECONDITION_NOT_RECOVERED"
    )
    result = MODULE.analyze_text(text)
    assert result["verdict"] == "INCONCLUSIVE"
    assert result["step6a"] == "NOT_PASS"
    assert result["step6b_1_digital_scheduled_trigger"] == "NOT_PASS"


def test_runtime_loss_is_inconclusive() -> None:
    text = _base(_board("MASTER"), _board("SLAVE")).replace(
        "S6B_CAPTURE_RESULT=PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER",
        "S6B_CAPTURE_RESULT=INCONCLUSIVE_RUNTIME_STATE_CHANGED",
    ).replace("S6B_SAMPLE ROLE=SLAVE READ_VALID=1", "S6B_SAMPLE ROLE=SLAVE READ_VALID=0")
    result = MODULE.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
    assert result["verdict"] == "INCONCLUSIVE"
