from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "analysis" / "step6_master_last_ec1f25e8_rebuild_recovery.py"
SPEC = importlib.util.spec_from_file_location("step6_rebuild", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def baseline(link_up: bool) -> str:
    link = 1 if link_up else 0
    rows = []
    for sample in range(5):
        rows.append(
            "REBUILD_BASELINE_PAIR SAMPLE={sample} READ_VALID=1 "
            "MASTER_BASIC_READY=1 SLAVE_BASIC_READY=1 "
            "SLAVE_RX_LOCKED_TO_DATA=1 SLAVE_RX_ACTIVITY_CHANGED={activity} "
            "MASTER_CORE_LINK_OK=1 MASTER_CORE_TM_LINK_UP=1 "
            "SLAVE_CORE_LINK_OK={link} SLAVE_CORE_TM_LINK_UP={link} "
            "SLAVE_STICKY45_ENC=10 SLAVE_STICKY45_DISPERR=20 "
            "SLAVE_STICKY46_ERRDETECT=30 SLAVE_STICKY46_SYNC_LOSS=40 "
            "SLAVE_STICKY47_LOCK_LOSS=50 SLAVE_STICKY47_LINK_DROP=60 "
            "SLAVE_STICKY48_TM_LINK_DROP=70".format(
                sample=sample, activity=1 if sample else 0, link=link
            )
        )
    return "\n".join(rows) + "\nBASELINE_RESULT=PASS\n" \
        "BASELINE_SAMPLE_COUNT=5\n" \
        f"BASELINE_SLAVE_LINK_UP_COUNT={5 if link_up else 0}\n" \
        f"BASELINE_SLAVE_LINK_MODE={'UP' if link_up else 'DOWN'}\n"


def recovery(*, link_up: bool, drop: bool, good: bool = True) -> str:
    rows = []
    for sample in range(6):
        value = 11 if drop else 10
        is_good = 1 if good and sample >= 1 else 0
        rows.append(
            "REBUILD_RECOVERY_PAIR SAMPLE={sample} READ_VALID=1 "
            "MASTER_LOCAL_READY=1 MASTER_READY_STREAK=3 "
            "SLAVE_RX_LOCKED_TO_DATA=1 SLAVE_RX_ACTIVITY_CHANGED={activity} "
            "SLAVE_RX_PATTERN_READY={pattern} SLAVE_CORE_LINK_OK={link} "
            "SLAVE_CORE_TM_LINK_UP={link} SLAVE_STICKY45_ENC={value} "
            "SLAVE_STICKY45_DISPERR=20 SLAVE_STICKY46_ERRDETECT=30 "
            "SLAVE_STICKY46_SYNC_LOSS=40 SLAVE_STICKY47_LOCK_LOSS=50 "
            "SLAVE_STICKY47_LINK_DROP=60 SLAVE_STICKY48_TM_LINK_DROP=70 "
            "STICKY_DELTA_VALID=1 STICKY_DELTA_SEEN={drop} "
            "STICKY_DROP_OBSERVED={drop} BASELINE_LINK_MODE={mode} "
            "SLAVE_RECOVERY_GOOD={good} SLAVE_RECOVERY_ELIGIBLE={good} "
            "SLAVE_RECOVERY_SEEN={good} SLAVE_RECOVERY_STREAK={streak} "
            "MAX_RECOVERY_STREAK={streak} RESET_CHANGED=0".format(
                sample=sample,
                activity=is_good,
                pattern=is_good,
                link=is_good,
                value=value,
                drop=1 if drop else 0,
                mode="UP" if link_up else "DOWN",
                good=is_good,
                streak=max(0, sample) if is_good else 0,
            )
        )
    return "\n".join(rows) + "\nREBUILD_RECOVERY_RESULT=" \
        + ("PASS_REBUILT_MASTER_LAST_RECOVERY" if good else "FAIL_REBUILT_MASTER_LAST_RECOVERY_NOT_REPRODUCED") \
        + "\n"


def test_down_baseline_pass() -> None:
    result = MODULE.analyze_text(baseline(False), recovery(link_up=False, drop=False))
    assert result["classification"] == "PASS_REBUILT_MASTER_LAST_RECOVERY"
    assert result["recovery_verdict"] == "PASS"
    assert result["startup_order_sensitivity"] == "SUPPORTED"


def test_up_baseline_requires_fresh_drop() -> None:
    result = MODULE.analyze_text(baseline(True), recovery(link_up=True, drop=True))
    assert result["classification"] == "PASS_REBUILT_MASTER_LAST_RECOVERY"
    assert result["sticky_drop_observed"] is True


def test_up_baseline_without_drop_is_not_pass() -> None:
    result = MODULE.analyze_text(
        baseline(True),
        recovery(link_up=True, drop=False, good=True).replace(
            "REBUILD_RECOVERY_RESULT=PASS_REBUILT_MASTER_LAST_RECOVERY",
            "REBUILD_RECOVERY_RESULT=FAIL_REBUILT_MASTER_LAST_RECOVERY_NOT_REPRODUCED",
        ),
    )
    assert result["classification"] == "FAIL_REBUILT_MASTER_LAST_RECOVERY_NOT_REPRODUCED"
    assert result["recovery_verdict"] == "FAIL_NOT_REPRODUCED"


def test_failed_baseline_stops_before_recovery() -> None:
    result = MODULE.analyze_text(
        baseline(False).replace("BASELINE_RESULT=PASS", "BASELINE_RESULT=INCONCLUSIVE_PREPROGRAM_SLAVE_HEALTH"),
        recovery(link_up=False, drop=False),
    )
    assert result["classification"] == "INCONCLUSIVE_PREPROGRAM_SLAVE_HEALTH"


if __name__ == "__main__":
    test_down_baseline_pass()
    test_up_baseline_requires_fresh_drop()
    test_up_baseline_without_drop_is_not_pass()
    test_failed_baseline_stops_before_recovery()
    print("STEP6_EC1F25E8_REBUILD_OFFLINE_TESTS=PASS")

