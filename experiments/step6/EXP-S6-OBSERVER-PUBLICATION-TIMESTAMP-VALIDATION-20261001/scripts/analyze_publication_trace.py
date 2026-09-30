#!/usr/bin/env python3
"""Conservatively validate offline WDIAGS publication/read-trace fixtures.

This analyzer does not read hardware and never claims Step 6 lock or offset
success. A source-backed publication protocol is an explicit prerequisite.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


GROUP_FIELDS = {
    "EVENT": {"STATE", "RX", "TX", "A8C"},
    "PHASE": {"CKO", "SETP", "UCNT"},
}
AUDIT_FIELDS = (
    "field_writer_contract_complete",
    "writer_aliases_complete",
    "publication_protocol_proven",
    "sequence_owner_proven",
    "aba_excluded_for_60s",
)
U32_MASK = 0xFFFFFFFF
U16_MASK = 0xFFFF
A6C_FIRST_DISABLE_VALID = 1 << 11
TIMED_READ_FIELDS = {
    "WR_STATE_RAW": "STATE",
    "WR_RX_RAW": "RX",
    "WR_TX_RAW": "TX",
}


def word(value: Any) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if 0 <= value <= U32_MASK else None
    if not isinstance(value, str):
        return None
    text = value.strip().lower()
    if text.startswith("0x"):
        text = text[2:]
    if not text or any(ch not in "0123456789abcdef" for ch in text):
        return None
    try:
        parsed = int(text, 16)
        return parsed if parsed <= U32_MASK else None
    except ValueError:
        return None


def time_value(value: Any) -> int | None:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        return None
    return value


def normalize_timed_read(raw_field: str, start: Any, end: Any) -> dict[str, Any]:
    """Return the canonical row keys for a timed raw read."""
    field = TIMED_READ_FIELDS.get(raw_field)
    if field is None:
        raise ValueError(f"unrecognized timed-read field: {raw_field}")
    return {f"{field}_READ_BEGIN_MS": start, f"{field}_READ_END_MS": end}


def strict_offset_in_band(cko_ps: Any) -> bool:
    """Strict future qualification boundary; this never establishes a frame."""
    return type(cko_ps) is int and -60 < cko_ps < 60


def _int_flag(value: Any, expected: int) -> bool:
    return type(value) is int and value == expected


def _audit_blockers(audit: Any) -> list[str]:
    if not isinstance(audit, dict):
        return ["SOURCE_AUDIT_MISSING"]
    return [f"{key.upper()}_UNPROVEN" for key in AUDIT_FIELDS if audit.get(key) is not True]


def _payload_sort_key(item: tuple[str, Any]) -> tuple[int, int, str]:
    name, record = item
    start = time_value(record.get("read_start_ms")) if isinstance(record, dict) else None
    return (start is None, start if start is not None else 0, name)


def _validate_payload_interval(
    record: Any, frame_start: int, frame_end: int, previous_end: int
) -> tuple[bool, str | None, int | None, int | None]:
    if not isinstance(record, dict):
        return False, "PAYLOAD_RECORD_MISSING", None, None
    if record.get("valid") is not True or record.get("transport_valid") is not True:
        return False, "PAYLOAD_NOT_VALID", None, None
    if word(record.get("raw")) is None:
        return False, "PAYLOAD_RAW_INVALID", None, None
    start = time_value(record.get("read_start_ms"))
    end = time_value(record.get("read_end_ms"))
    if start is None or end is None or start > end:
        return False, "PAYLOAD_TIMESTAMP_INVALID", start, end
    if start < frame_start or end > frame_end or start < previous_end:
        return False, "PAYLOAD_TIMESTAMP_OUTSIDE_OR_NONMONOTONIC", start, end
    return True, None, start, end


def validate_frame(frame: Any) -> tuple[bool, str | None, dict[str, Any]]:
    if not isinstance(frame, dict):
        return False, "FRAME_RECORD_MISSING", {}
    kind = frame.get("kind")
    if kind not in GROUP_FIELDS:
        return False, "FRAME_KIND_INVALID", {}

    frame_start = time_value(frame.get("frame_start_ms"))
    frame_end = time_value(frame.get("frame_end_ms"))
    if frame_start is None or frame_end is None or frame_start > frame_end:
        return False, "FRAME_TIMESTAMP_INVALID", {"kind": kind}

    if not _int_flag(frame.get("data_valid_before"), 1) or not _int_flag(frame.get("data_valid_after"), 1):
        return False, "DATA_VALID_GUARD_REJECTED", {"kind": kind}
    if not _int_flag(frame.get("snapshot_before"), 0) or not _int_flag(frame.get("snapshot_after"), 0):
        return False, "DATA_SNAPSHOT_GUARD_REJECTED", {"kind": kind}

    generation_before = word(frame.get("generation_before"))
    generation_after = word(frame.get("generation_after"))
    inverse_before = word(frame.get("generation_inverse_before"))
    inverse_after = word(frame.get("generation_inverse_after"))
    if None in (generation_before, generation_after, inverse_before, inverse_after):
        return False, "PUBLICATION_SEQUENCE_RAW_INVALID", {"kind": kind}
    if (generation_before ^ inverse_before) != U32_MASK or (generation_after ^ inverse_after) != U32_MASK:
        return False, "PUBLICATION_SEQUENCE_INVERSE_MISMATCH", {"kind": kind}
    if generation_before != generation_after or inverse_before != inverse_after:
        return False, "PUBLICATION_SEQUENCE_CHANGED", {"kind": kind}
    if generation_before & 1:
        return False, "PUBLICATION_SEQUENCE_UNCOMMITTED", {"kind": kind}

    if (
        frame.get("owner_before") != "DIAG_PUBLISHER"
        or frame.get("owner_after") != "DIAG_PUBLISHER"
        or frame.get("overlay_active_before") is not False
        or frame.get("overlay_active_after") is not False
    ):
        return False, "PUBLICATION_OWNER_OR_OVERLAY_REJECTED", {"kind": kind}

    payload = frame.get("payload")
    if not isinstance(payload, dict) or set(payload) != GROUP_FIELDS[kind]:
        return False, "PAYLOAD_GROUP_MEMBERSHIP_INVALID", {"kind": kind}

    previous_end = frame_start
    payload_windows: dict[str, tuple[int, int]] = {}
    for name, record in sorted(payload.items(), key=_payload_sort_key):
        ok, reason, start, end = _validate_payload_interval(
            record, frame_start, frame_end, previous_end
        )
        if not ok:
            return False, reason, {"kind": kind, "field": name}
        assert start is not None and end is not None
        previous_end = end
        payload_windows[name] = (start, end)

    return True, None, {
        "kind": kind,
        "publication_id": generation_before,
        "payload_windows": payload_windows,
        "frame_start_ms": frame_start,
        "frame_end_ms": frame_end,
        "payload": payload,
    }


def _validate_statuses(
    observations: Any, capture_start: int, capture_end: int
) -> tuple[str | None, list[dict[str, Any]]]:
    if not isinstance(observations, list):
        return "STATUS_OBSERVATIONS_MISSING", []
    clean: list[dict[str, Any]] = []
    previous_end = capture_start
    for item in observations:
        if not isinstance(item, dict) or item.get("name") not in {"SSTAT", "A6C"}:
            return "STATUS_RECORD_INVALID", clean
        raw = word(item.get("raw"))
        start = time_value(item.get("read_start_ms"))
        end = time_value(item.get("read_end_ms"))
        if raw is None or start is None or end is None or start > end:
            return "STATUS_TIMESTAMP_OR_RAW_INVALID", clean
        if start < capture_start or end > capture_end or start < previous_end:
            return "STATUS_TIMESTAMP_NONMONOTONIC_OR_OUTSIDE_CAPTURE", clean
        previous_end = end
        clean.append({"name": item["name"], "raw": raw, "read_start_ms": start, "read_end_ms": end})

    for name in ("SSTAT", "A6C"):
        if not any(item["name"] == name for item in clean):
            return f"STATUS_{name}_MISSING", clean

    a6c = [item for item in clean if item["name"] == "A6C"]
    if a6c and a6c[0]["raw"] & A6C_FIRST_DISABLE_VALID:
        return "PREEXISTING_STICKY_DISABLE_RECORD", clean
    if any(item["raw"] & A6C_FIRST_DISABLE_VALID for item in a6c[1:]):
        return "NEW_STICKY_DISABLE_RECORD", clean
    return None, clean


def analyze_trace(trace: dict[str, Any]) -> dict[str, Any]:
    blockers = _audit_blockers(trace.get("source_audit"))
    result: dict[str, Any] = {
        "verdict": "NOT_ESTABLISHED",
        "source_audit_blockers": blockers,
        "event_candidate_frames": 0,
        "phase_candidate_frames": 0,
        "event_structurally_valid_frames": 0,
        "phase_structurally_valid_frames": 0,
        "event_trusted_frames": 0,
        "phase_trusted_frames": 0,
        "event_distinct_publications": 0,
        "phase_distinct_publications": 0,
        "candidate_rejection_reasons": {},
        "phase_ucnt_advanced": False,
        "status_observations_valid": False,
        "cross_group_atomicity_claimed": False,
        "sstat_a6c_joined_to_frames": False,
        "step6_offset_claimed": False,
        "stable_window_established": False,
        "servo_offset_verdict": "NOT_ESTABLISHED",
        "stop_reason": None,
    }

    raw_frames = trace.get("frames")
    if not isinstance(raw_frames, list):
        raw_frames = []
    frames_by_group: dict[str, list[dict[str, Any]]] = {"EVENT": [], "PHASE": []}
    rejected: Counter[str] = Counter()
    invalid_streak: dict[str, int] = {"EVENT": 0, "PHASE": 0}
    consecutive_invalid_stop: str | None = None
    sequence_rollback_stop: str | None = None

    for frame in raw_frames:
        kind = frame.get("kind") if isinstance(frame, dict) else None
        if kind not in GROUP_FIELDS:
            rejected["FRAME_KIND_INVALID"] += 1
            continue
        result[f"{kind.lower()}_candidate_frames"] += 1
        valid, reason, clean = validate_frame(frame)
        if not valid:
            rejected[reason or "FRAME_INVALID"] += 1
            invalid_streak[kind] += 1
            if invalid_streak[kind] >= 5:
                consecutive_invalid_stop = f"FIVE_CONSECUTIVE_INVALID_{kind}_FRAMES:{reason}"
            continue
        invalid_streak[kind] = 0
        group_rows = frames_by_group[kind]
        if group_rows:
            previous = group_rows[-1]["publication_id"]
            marker = clean["publication_id"]
            if marker == previous:
                rejected["DUPLICATE_PUBLICATION"] += 1
                invalid_streak[kind] += 1
                if invalid_streak[kind] >= 5:
                    consecutive_invalid_stop = f"FIVE_CONSECUTIVE_INVALID_{kind}_FRAMES:DUPLICATE_PUBLICATION"
                continue
            if marker < previous:
                rejected["PUBLICATION_SEQUENCE_ROLLBACK_OR_WRAP"] += 1
                sequence_rollback_stop = f"{kind}_PUBLICATION_SEQUENCE_ROLLBACK_OR_WRAP"
                continue
        group_rows.append(clean)

    result["candidate_rejection_reasons"] = dict(sorted(rejected.items()))
    result["event_structurally_valid_frames"] = len(frames_by_group["EVENT"])
    result["phase_structurally_valid_frames"] = len(frames_by_group["PHASE"])
    result["event_distinct_publications"] = len({row["publication_id"] for row in frames_by_group["EVENT"]})
    result["phase_distinct_publications"] = len({row["publication_id"] for row in frames_by_group["PHASE"]})

    # Structural validity is not trusted evidence unless the source contract is
    # proven. Still compute rejection counts above so an offline raw replay can
    # show why its candidate frames were rejected.
    if blockers:
        result.update(
            verdict="BLOCKED_SOURCE_AUDIT_UNPROVEN",
            stop_reason=consecutive_invalid_stop or ";".join(blockers),
            event_trusted_frames=0,
            phase_trusted_frames=0,
        )
        return result

    capture = trace.get("capture")
    if not isinstance(capture, dict):
        result.update(verdict="REJECTED_CAPTURE_METADATA_MISSING", stop_reason="CAPTURE_METADATA_MISSING")
        return result
    start = time_value(capture.get("start_ms"))
    end = time_value(capture.get("end_ms"))
    if start is None or end is None or end < start or end - start > 60_000:
        result.update(verdict="REJECTED_CAPTURE_WINDOW_INVALID", stop_reason="CAPTURE_WINDOW_INVALID")
        return result
    if (
        not _int_flag(capture.get("step1_gate_initial"), 1)
        or not _int_flag(capture.get("step1_gate_final"), 1)
        or capture.get("reset_signature_valid") is not True
        or capture.get("reset_changed") is not False
    ):
        result.update(verdict="REJECTED_STEP1_OR_RESET_GATE", stop_reason="STEP1_OR_RESET_GATE")
        return result
    for key in ("wb_timeout_count", "wb_unstable_count", "unexpected_transaction_trigger_count"):
        if capture.get(key) != 0:
            result.update(verdict="REJECTED_TRANSPORT_OR_UNEXPECTED_TRIGGER", stop_reason=key.upper())
            return result

    status_reason, _statuses = _validate_statuses(trace.get("status_observations"), start, end)
    if status_reason:
        result.update(verdict="STOP_STATUS_GUARD", stop_reason=status_reason)
        return result
    result["status_observations_valid"] = True

    if consecutive_invalid_stop:
        result.update(verdict="STOP_FIVE_CONSECUTIVE_INVALID_FRAMES", stop_reason=consecutive_invalid_stop)
        return result
    if sequence_rollback_stop:
        result.update(
            verdict="REJECTED_PUBLICATION_SEQUENCE_ROLLBACK_OR_WRAP",
            stop_reason=sequence_rollback_stop,
        )
        return result

    event_rows = frames_by_group["EVENT"]
    phase_rows = frames_by_group["PHASE"]
    if len(event_rows) < 10 or len(phase_rows) < 10:
        result.update(verdict="NOT_ENOUGH_VALID_DISTINCT_PUBLICATIONS", stop_reason="MINIMUM_FRAME_COUNT")
        return result

    phase_ucnt = [word(row["payload"]["UCNT"]["raw"]) for row in phase_rows]
    for before, after in zip(phase_ucnt, phase_ucnt[1:]):
        if before is not None and after is not None:
            delta = (after - before) & U32_MASK
            if 0 < delta < 0x80000000:
                result["phase_ucnt_advanced"] = True
                break
    if not result["phase_ucnt_advanced"]:
        result.update(verdict="REJECTED_PHASE_UCNT_NOT_ADVANCING", stop_reason="PHASE_UCNT_NOT_ADVANCING")
        return result

    previous_ucnt: int | None = None
    previous_phase_payload: tuple[int | None, int | None] | None = None
    for row in phase_rows:
        current_ucnt = word(row["payload"]["UCNT"]["raw"])
        current_payload = (
            word(row["payload"]["CKO"]["raw"]),
            word(row["payload"]["SETP"]["raw"]),
        )
        if previous_ucnt is not None and current_ucnt is not None:
            delta = (current_ucnt - previous_ucnt) & U32_MASK
            if delta == 0 and current_payload != previous_phase_payload:
                result.update(
                    verdict="REJECTED_SAME_UCNT_PHASE_PAYLOAD_CONFLICT",
                    stop_reason="SAME_UCNT_PHASE_PAYLOAD_CONFLICT",
                )
                return result
            if delta >= 0x80000000:
                result.update(
                    verdict="REJECTED_PHASE_UCNT_ROLLBACK_OR_RESET",
                    stop_reason="PHASE_UCNT_ROLLBACK_OR_RESET",
                )
                return result
        previous_ucnt = current_ucnt
        previous_phase_payload = current_payload

    result.update(
        verdict="OFFLINE_OBSERVER_CONTRACT_PASS_NOT_STEP6",
        stop_reason="NONE",
        event_trusted_frames=len(event_rows),
        phase_trusted_frames=len(phase_rows),
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    trace = json.loads(args.trace.read_text(encoding="utf-8"))
    result = analyze_trace(trace)
    rendered = json.dumps(result, indent=2, sort_keys=True)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
