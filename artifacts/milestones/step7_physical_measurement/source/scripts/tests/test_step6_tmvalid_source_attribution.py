from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "experiment" / "step6_tmvalid_source_attribution.py"
SPEC = importlib.util.spec_from_file_location("step6_tmvalid_source_attribution", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _row(
    sample: int,
    *,
    board: str = "DE5 [1-11.2]",
    ptp: int = 9,
    servo: int = 4,
    tm_valid: int = 0,
    status_time: int = 0,
    snapshot: int = 0,
    ucnt_inc: int = 1,
    step5: int = 1,
    stop: str = "NONE",
) -> str:
    return (
        "TMVALID_SAMPLE board={board} sample={sample} elapsed_ms={elapsed} "
        "STATUS_TIME_VALID={status_time} STATUS_PPS_VALID=1 ESCR_TM_VALID={tm_valid} "
        "PTP_STATE={ptp} SERVO_STATE={servo} LINK_HEALTHY=1 "
        "PSTAT_LOCKED=1 STEP5_LOCKED={step5} UCNT_INCREASED={ucnt_inc} "
        "BOOT_CHANGED=0 RESET_CHANGED=0 SNAPSHOT_COUNT={snapshot} "
        "SERVO_COMPLETE={servo_complete} STOP_CANDIDATE={stop}"
    ).format(
        board=board,
        sample=sample,
        elapsed=sample * 1000,
        status_time=status_time,
        tm_valid=tm_valid,
        ptp=ptp,
        servo=servo,
        step5=step5,
        ucnt_inc=ucnt_inc,
        snapshot=snapshot,
        servo_complete=int(ptp == 9 and servo == 4),
        stop=stop,
    )


def test_mapping_export_failure_is_attributed() -> None:
    text = "\n".join(_row(i, tm_valid=1, status_time=0) for i in range(12))
    result = MODULE.analyze_text(text)
    board = result["boards"]["DE5 [1-11.2]"]
    assert board["classification"] == "FAIL_MAPPING_EXPORT"
    assert result["tmvalid_attribution"] == "PASS"
    assert result["step6a_slave_global_time"] == "NOT_PASS"


def test_servo_not_complete_is_attributed() -> None:
    text = "\n".join(
        _row(i, ptp=8, servo=3, tm_valid=0, status_time=0, ucnt_inc=0)
        for i in range(12)
    )
    result = MODULE.analyze_text(text)
    board = result["boards"]["DE5 [1-11.2]"]
    assert board["classification"] == "FAIL_PTP_SERVO_NOT_COMPLETE"
    assert result["tmvalid_attribution"] == "PASS"


def test_slave_recovery_requires_two_snapshots() -> None:
    text = "\n".join(
        _row(i, tm_valid=1, status_time=1, snapshot=1 if i >= 10 else 0)
        for i in range(12)
    )
    result = MODULE.analyze_text(text)
    board = result["boards"]["DE5 [1-11.2]"]
    assert board["classification"] != "SLAVE_TM_VALID_RECOVERED"
    assert result["step6a_slave_global_time"] == "NOT_PASS"


def test_slave_recovery_passes_with_stable_valid_and_two_snapshots() -> None:
    text = "\n".join(
        _row(i, tm_valid=1, status_time=1, snapshot=2 if i >= 10 else 0)
        for i in range(12)
    )
    result = MODULE.analyze_text(text)
    board = result["boards"]["DE5 [1-11.2]"]
    assert board["classification"] == "SLAVE_TM_VALID_RECOVERED"
    assert result["step6a_slave_global_time"] == "PASS"


def test_step6b_is_never_claimed_by_attribution() -> None:
    result = MODULE.analyze_text(_row(0))
    assert result["step6b_trigger_run"] is False


def test_master_reference_pass_does_not_require_slave_servo_or_step5_flags() -> None:
    text = "\n".join(
        _row(
            i,
            board="DE5 [1-11.1]",
            ptp=6,
            servo=0,
            tm_valid=1,
            status_time=1,
            snapshot=100 + i,
            step5=0,
            ucnt_inc=0,
        )
        for i in range(12)
    )
    result = MODULE.analyze_text(text)
    board = result["boards"]["DE5 [1-11.1]"]
    assert board["classification"] == "MASTER_REFERENCE_PASS"
