import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "analysis" / "step6_master_last_exact_image_recovery_attribution.py"
SPEC = importlib.util.spec_from_file_location("step6_master_last", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def preflight_row(index: int, activity_changed: int = 1) -> str:
    return (
        "PREFLIGHT_SAMPLE "
        f"SAMPLE={index} ELAPSED_MS={index * 250} READ_VALID=1 "
        "MASTER_BASIC_READY=1 SLAVE_BASIC_READY=1 "
        "SLAVE_RX_LOCKED_TO_DATA=1 SLAVE_RX_ACTIVITY_COUNT=100 "
        f"SLAVE_RX_ACTIVITY_CHANGED={activity_changed} MASTER_PTP_STATE=6 "
        "SLAVE_PTP_STATE=9 MASTER_BOOT_GENERATION=00000001 "
        "SLAVE_BOOT_GENERATION=00000001 RESET_CHANGED=0"
    )


def recovery_row(index: int, good: int = 1, streak: int | None = None) -> str:
    if streak is None:
        streak = index + 1 if good else 0
    return (
        "RECOVERY_PAIR_SAMPLE "
        f"SAMPLE={index} ELAPSED_MS={index * 250} READ_VALID=1 "
        "MASTER_READ_VALID=1 SLAVE_READ_VALID=1 "
        "MASTER_LOCAL_READY=1 MASTER_READY_STREAK=3 MASTER_PTP_STATE=6 "
        "SLAVE_RX_LOCKED_TO_DATA=1 SLAVE_RX_ACTIVITY_COUNT=200 "
        f"SLAVE_RX_ACTIVITY_CHANGED={good} SLAVE_RX_PATTERN_READY={good} "
        f"SLAVE_CORE_LINK_OK={good} SLAVE_CORE_TM_LINK_UP={good} "
        f"SLAVE_RECOVERY_GOOD={good} SLAVE_RECOVERY_STREAK={streak} "
        f"SLAVE_RECOVERY_SEEN={good} MAX_RECOVERY_STREAK={streak} "
        "MASTER_BOOT_GENERATION=00000001 SLAVE_BOOT_GENERATION=00000001 RESET_CHANGED=0"
    )


def make_capture(result: str, recovery_rows: list[str]) -> tuple[str, str]:
    preflight = "\n".join([preflight_row(i) for i in range(5)] + ["PREFLIGHT_RESULT=PASS"])
    recovery = "\n".join(recovery_rows + [f"RECOVERY_RESULT={result}"])
    return preflight, recovery


def test_exact_master_last_pass():
    preflight, recovery = make_capture(
        "PASS_EXACT_MASTER_LAST_RECOVERY",
        [recovery_row(i) for i in range(5)],
    )
    result = MODULE.analyze_text(preflight, recovery)
    assert result["classification"] == "PASS_EXACT_MASTER_LAST_RECOVERY"
    assert result["recovery_verdict"] == "PASS"


def test_transient_recovery_is_not_pass():
    rows = [recovery_row(0, good=1, streak=1), recovery_row(1, good=0, streak=0)]
    preflight, recovery = make_capture("FAIL_TRANSIENT_RECOVERY", rows)
    result = MODULE.analyze_text(preflight, recovery)
    assert result["classification"] == "FAIL_TRANSIENT_RECOVERY"
    assert result["recovery_verdict"] == "FAIL_TRANSIENT"


def test_no_recovery_is_fail_not_reproduced():
    rows = [recovery_row(i, good=0, streak=0) for i in range(6)]
    preflight, recovery = make_capture("FAIL_EXACT_MASTER_LAST_RECOVERY_NOT_REPRODUCED", rows)
    result = MODULE.analyze_text(preflight, recovery)
    assert result["classification"] == "FAIL_EXACT_MASTER_LAST_RECOVERY_NOT_REPRODUCED"


def test_bad_preflight_blocks_programming_result():
    preflight = "\n".join([preflight_row(i, activity_changed=0) for i in range(5)] + ["PREFLIGHT_RESULT=FAIL_BASIC_GATE"])
    recovery = "RECOVERY_RESULT=NOT_RUN"
    result = MODULE.analyze_text(preflight, recovery)
    assert result["classification"] == "INCONCLUSIVE_PREPROGRAM_STATE"
    assert result["recovery_verdict"] == "NOT_RUN"
