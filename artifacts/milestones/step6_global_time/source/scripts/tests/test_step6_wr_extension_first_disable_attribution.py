from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "experiment" / "step6_wr_extension_first_disable_attribution.py"
SPEC = importlib.util.spec_from_file_location("step6_wr_extension_first_disable_attribution", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _row(
    sample: int,
    *,
    valid: int = 1,
    cause: int = 1,
    cause_name: str = "PROTOCOL_DETECTION_TIMEOUT",
    reason: int = 0,
    reason_name: str = "UNKNOWN",
    pd: int = 4,
    ext: int = 2,
    stop: str = "NONE",
) -> str:
    return (
        "EXTDISABLE_SAMPLE board=DE5 [1-11.2] sample={sample} elapsed_ms={elapsed} "
        "READ_VALID=1 WDIAGS_PTP_META=03020409 WRC_MODE=3 PTP_STATE=9 "
        "PD_STATE={pd} EXT_STATE={ext} WDIAGS_SSTAT=98D31007 SERVO_STATE=0 "
        "WR_DISABLE_VALID={valid} WR_DISABLE_CAUSE={cause} "
        "WR_DISABLE_CAUSE_NAME={cause_name} WR_FAILURE_REASON={reason} "
        "WR_FAILURE_REASON_NAME={reason_name} WR_DISABLE_PD_STATE=3 "
        "WR_DISABLE_EXT_STATE=1 BOOT_CHANGED=0 RESET_CHANGED=0 "
        "RECORD_CHANGED=0 HELPER_LOCKED=1 PSTAT_LOCKED=1 "
        "CANDIDATE={candidate} CANDIDATE_STREAK={streak} "
        "STOP_CANDIDATE={stop}"
    ).format(
        sample=sample,
        elapsed=sample * 1000,
        valid=valid,
        cause=cause,
        cause_name=cause_name,
        reason=reason,
        reason_name=reason_name,
        pd=pd,
        ext=ext,
        candidate="PASS_PROTOCOL_TIMEOUT" if cause == 1 else "NONE",
        streak=sample + 1,
        stop=stop,
    )


def test_protocol_timeout_is_a_diagnostic_pass() -> None:
    result = MODULE.analyze_text("\n".join(_row(i) for i in range(3)))
    board = result["boards"]["DE5 [1-11.2]"]
    assert board["classification"] == "PASS_PROTOCOL_TIMEOUT"
    assert result["wr_extension_disable_attribution"] == "PASS"


def test_handshake_reason_is_preserved() -> None:
    text = "\n".join(
        _row(
            i,
            cause=2,
            cause_name="HANDSHAKE_FAILURE",
            reason=3,
            reason_name="WR_S_LOCK_TIMEOUT",
        )
        for i in range(3)
    )
    result = MODULE.analyze_text(text)
    board = result["boards"]["DE5 [1-11.2]"]
    assert board["classification"] == "PASS_HANDSHAKE_WR_S_LOCK_TIMEOUT"


def test_other_caller_is_not_overclaimed() -> None:
    text = "\n".join(
        _row(i, cause=0, cause_name="OTHER_CALLER") for i in range(3)
    )
    result = MODULE.analyze_text(text)
    board = result["boards"]["DE5 [1-11.2]"]
    assert board["classification"] == "INCONCLUSIVE_OTHER_CALLER"
    assert result["wr_extension_disable_attribution"] == "INCONCLUSIVE"


def test_contract_failure_is_not_step6_pass() -> None:
    text = "\n".join(
        _row(i, valid=0, cause=0, cause_name="OTHER_CALLER", pd=4, ext=2)
        for i in range(3)
    )
    result = MODULE.analyze_text(text)
    board = result["boards"]["DE5 [1-11.2]"]
    assert board["classification"] == "FAIL_DIAGNOSTIC_CONTRACT"
    assert result["step6a"] == "NOT_PASS"
