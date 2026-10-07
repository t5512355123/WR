from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4f_helper_contract_audit as audit  # noqa: E402


def _header() -> str:
    return (
        "STEP5_F4F_CONFIG experiment=EXP-S5-F4F-HELPER-MEASUREMENT-CONTRACT-AUDIT-20260915 "
        "run_role=f4f READ_ONLY_OBSERVER=1 ONE_READER=1 NO_CONTROL_WRITE=1 "
        "NO_HELPER_PI_SNAPSHOT=1 NO_DEBUG_FIFO_DRAIN=1 CORE_ENABLED=1\n"
        "STEP5_F4F_DONE session_elapsed_ms=25000 run_end_reason=TARGET_REACHED "
        "stop_reason=NONE single_reader=PASS step5_complete=NO merge_approved=NO\n"
    )


def _attempt(profile: str, cycle: int, retry: int = 1, *, accepted: int = 1,
             epoch_before: int = 2, epoch_after: int = 2, update: int = 100,
             host_end: int | None = None, reason: str = "NONE",
             raw_output: str = "000003E8", raw_tag: str = "00000064") -> str:
    if host_end is None:
        host_end = cycle * 1000
    measured = {
        "RAW_EPOCH_BEFORE": f"{epoch_before:08X}",
        "RAW_TAG_DELTA": raw_tag if profile == "FULL" else "NOT_MEASURED",
        "RAW_EXPECTED_DELTA": "00000032" if profile == "FULL" else "NOT_MEASURED",
        "RAW_FREQ_ERROR": "00000032" if profile == "FULL" else "NOT_MEASURED",
        "RAW_PRECLAMP_ERROR": "00000032" if profile == "FULL" else "NOT_MEASURED",
        "RAW_HELPER_ERROR": "FFFFFFF0",
        "RAW_UPDATE_COUNT": f"{update:08X}",
        "RAW_HELPER_OUTPUT": raw_output,
        "RAW_DMTD_REF_ACCEPT_COUNT": "00000010" if profile == "FULL" else "NOT_MEASURED",
        "RAW_DMTD_FB_ACCEPT_COUNT": "00000020" if profile == "FULL" else "NOT_MEASURED",
        "RAW_EPOCH_AFTER": f"{epoch_after:08X}",
    }
    parsed = {
        "EPOCH_BEFORE": epoch_before,
        "EPOCH_AFTER": epoch_after,
        "TAG_DELTA": 100 if profile == "FULL" else "NOT_MEASURED",
        "EXPECTED_DELTA": 50 if profile == "FULL" else "NOT_MEASURED",
        "FREQ_ERROR": 50 if profile == "FULL" else "NOT_MEASURED",
        "PRECLAMP_ERROR": 50 if profile == "FULL" else "NOT_MEASURED",
        "HELPER_ERROR": -16,
        "UPDATE_COUNT": update,
        "HELPER_OUTPUT": 1000,
        "DMTD_REF_ACCEPT_COUNT": 16 if profile == "FULL" else "NOT_MEASURED",
        "DMTD_FB_ACCEPT_COUNT": 32 if profile == "FULL" else "NOT_MEASURED",
    }
    flags = {
        "TRANSPORT_ERROR": 0,
        "PARSE_ERROR": 0,
        "ODD_OR_SENTINEL": 0,
        "EPOCH_CHANGED": int(epoch_before != epoch_after),
        "ARITHMETIC_MISMATCH": 0,
        "RANGE_MISMATCH": 0,
        "ACCEPTED": accepted,
        "OWNER_UNVERIFIED": 1,
    }
    fields = {
        "board": "DE5 [1-11.2]",
        "profile": profile,
        "cycle": cycle,
        "retry_n": retry,
        "host_start_ms": host_end - 10,
        "host_end_ms": host_end,
        "duration_ms": 10,
        **{key.lower(): value for key, value in measured.items()},
        **{key.lower(): value for key, value in parsed.items()},
        **flags,
        "reason": reason,
    }
    return "STEP5_F4F_HELPER_ATTEMPT " + " ".join(
        f"{key}={value}" for key, value in fields.items())


def _profile(profile: str, cycle: int, **kwargs: object) -> str:
    attempts = kwargs.pop("attempts", 1)
    accepted = kwargs.pop("accepted", 1)
    return (
        f"STEP5_F4F_PROFILE board=DE5 [1-11.2] profile={profile} cycle={cycle} "
        f"attempts={attempts} accepted={accepted} profile_start_ms={cycle * 1000 - 10} "
        f"profile_end_ms={cycle * 1000} profile_duration_ms=10 owner_unverified=1"
    )


def test_compact_core_is_observable_without_claiming_full_contract() -> None:
    lines = []
    for cycle in range(1, 51):
        if cycle % 2:
            lines.append(_attempt("FULL", cycle, accepted=0,
                                  epoch_before=2, epoch_after=4,
                                  reason="EPOCH_CHANGED"))
        else:
            lines.append(_attempt("CORE", cycle, update=100 + cycle // 2,
                                  host_end=cycle * 1000))
    result = audit.analyze_text(_header() + "\n".join(lines))
    assert result["classification"] == "COMPACT_HELPER_CORE_OBSERVABLE"
    assert result["diagnostic_pass"] is True
    assert result["attempts"]["profiles"]["FULL"]["accepted_count"] == 0
    assert result["attempts"]["core_fresh_count"] == 24
    assert result["attempts"]["core_accepted_span_ms"] >= 10000
    assert result["step5_pass"] is False


def test_stable_full_arithmetic_mismatch_is_not_full_contract() -> None:
    full = _attempt("FULL", 1, accepted=0, reason="ARITHMETIC_MISMATCH")
    full = full.replace("ARITHMETIC_MISMATCH=0", "ARITHMETIC_MISMATCH=1")
    core = _attempt("CORE", 2, update=101)
    result = audit.analyze_text(_header() + full + "\n" + core)
    assert result["classification"] == "READER_CONTRACT_MISMATCH"


def test_repeated_core_update_is_stale_publisher() -> None:
    lines = []
    for cycle in range(1, 9):
        if cycle % 2:
            lines.append(_attempt("FULL", cycle, accepted=0,
                                  epoch_before=2, epoch_after=4,
                                  reason="EPOCH_CHANGED"))
        else:
            lines.append(_attempt("CORE", cycle, update=100))
    result = audit.analyze_text(_header() + "\n".join(lines))
    assert result["classification"] == "STALE_OR_IDLE_PUBLISHER"
    assert result["attempts"]["core_stale_count"] == 3


def test_core_fields_are_not_allowed_to_inherit_full_payload() -> None:
    line = _attempt("CORE", 2, update=101).replace(
        "raw_tag_delta=NOT_MEASURED", "raw_tag_delta=00000001")
    result = audit.analyze_text(_header() + line)
    assert result["classification"] == "DATA_UNRESOLVED"
    assert result["attempts"]["payload_isolation_pass"] is False


def test_rejected_attempt_preserves_signed_and_range_raw_values() -> None:
    line = _attempt("FULL", 1, accepted=0, reason="RANGE_MISMATCH",
                    raw_output="00000004")
    line = line.replace("RANGE_MISMATCH=0", "RANGE_MISMATCH=1")
    result = audit.analyze_text(_header() + line)
    row = result["attempts"]["attempt_rows"][0]
    assert row["raw_helper_error"] == "FFFFFFF0"
    assert row["helper_error"] == 4294967280 or row["helper_error"] == -16
    assert row["raw_helper_output"] == "00000004"
    assert row["accepted"] == 0
