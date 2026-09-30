#!/usr/bin/env python3
"""Conservatively analyze source-backed WR admission-event continuity logs."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
import re
from typing import Any


U32 = 1 << 32
EVENT_KINDS = {
    "SLOCK_HANDOFF_NEXT_LOCKED",
    "WRS_LOCKED_STATE",
    "TX_LOCKED_SEND_SUCCESS",
}


def parse_fields(line: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for raw_key, value in re.findall(r"([A-Za-z][A-Za-z0-9_]*)=([^\s]+)", line):
        key = raw_key.upper()
        if key in fields and fields[key] != value:
            raise ValueError(f"FIELD_CASE_CONFLICT key={key}")
        fields[key] = value
    return fields


def as_int(row: dict[str, str], key: str) -> int | None:
    value = row.get(key.upper())
    if value is None or value in {"NA", "INVALID", "TIMEOUT", "SKIPPED"}:
        return None
    try:
        if key.upper().endswith("_RAW"):
            return int(value.removeprefix("0x"), 16)
        return int(value, 10)
    except (ValueError, TypeError):
        return None


def delta32(first: int | None, last: int | None) -> tuple[int | None, str]:
    if first is None or last is None:
        return None, "MISSING"
    if last >= first:
        return last - first, "DIRECT"
    if first >= 0xF0000000 and last <= 0x0FFFFFFF:
        return U32 - first + last, "ROLLOVER"
    return None, "DISCONTINUITY"


def non_atomic_counter_summary(rows: list[dict[str, str]]) -> dict[str, int]:
    """Describe legacy poll-counter arithmetic as context, never as an event."""
    deltas: list[tuple[int | None, str]] = []
    for previous, current in zip(rows, rows[1:]):
        poll, poll_kind = delta32(
            as_int(previous, "LOCK_POLL_COUNT_RAW"), as_int(current, "LOCK_POLL_COUNT_RAW")
        )
        unlocked, unlocked_kind = delta32(
            as_int(previous, "LOCK_UNLOCKED_COUNT_RAW"), as_int(current, "LOCK_UNLOCKED_COUNT_RAW")
        )
        calib, calib_kind = delta32(
            as_int(previous, "LOCK_CALIB_FAIL_COUNT_RAW"), as_int(current, "LOCK_CALIB_FAIL_COUNT_RAW")
        )
        if any(value is None for value in (poll, unlocked, calib)):
            deltas.append((None, "INVALID"))
            continue
        result = int(poll) - int(unlocked) - int(calib)
        deltas.append((result, "NONATOMIC" if result >= 0 else "NEGATIVE"))

    return {
        "intervals": len(deltas),
        "nonnegative": sum(kind == "NONATOMIC" for _, kind in deltas),
        "positive": sum(kind == "NONATOMIC" and value > 0 for value, kind in deltas),
        "zero": sum(kind == "NONATOMIC" and value == 0 for value, kind in deltas),
        "negative_or_invalid": sum(kind != "NONATOMIC" for _, kind in deltas),
    }


def _row_kind(row: dict[str, str]) -> str:
    kind = row.get("ROW_EVENT_KIND", "NONE")
    return kind if kind in EVENT_KINDS else "NONE"


def analyze_text(text: str) -> dict[str, Any]:
    lines = text.splitlines()
    rows = [parse_fields(line) for line in lines if line.startswith("S6E_SAMPLE ")]
    legacy_rows = [parse_fields(line) for line in lines if line.startswith("S6W_SAMPLE ")]
    stops = [parse_fields(line) for line in lines if line.startswith("S6E_STOP ")]
    summaries = [parse_fields(line) for line in lines if line.startswith("S6E_SUMMARY ")]
    stop = stops[-1] if stops else (summaries[-1] if summaries else {})
    stop_reason = stop.get("REASON", stop.get("STOP_REASON", "MISSING_STOP"))
    valid_rows = [row for row in rows if as_int(row, "READ_VALID") == 1]
    event_valid_rows = [
        row for row in valid_rows
        if as_int(row, "EVENT_EVIDENCE_VALID") == 1 and as_int(row, "STEP1_GATE") == 1
    ]
    required_valid_rows = [
        row for row in rows
        if as_int(row, "REQUIRED_ROW_VALID") == 1
    ]
    context_valid_rows = [
        row for row in rows
        if as_int(row, "CONTEXT_READ_VALID") == 1
    ]
    counter_valid_rows = [
        row for row in rows
        if as_int(row, "COUNTER_READ_VALID") == 1
    ]

    baseline_reset = None
    reset_changed = False
    for row in valid_rows:
        signature = tuple(row.get(key) for key in (
            "BOOT_GENERATION", "CPU_RESET_COUNT", "WR_CORE_RESET_COUNT", "SI_CONFIG_DROP_COUNT"
        ))
        if baseline_reset is None:
            baseline_reset = signature
        elif signature != baseline_reset:
            reset_changed = True

    event_rows = [row for row in event_valid_rows if _row_kind(row) != "NONE"]
    eligible_events = []
    for row in event_rows:
        signature = tuple(row.get(key) for key in (
            "BOOT_GENERATION", "CPU_RESET_COUNT", "WR_CORE_RESET_COUNT", "SI_CONFIG_DROP_COUNT"
        ))
        if signature == baseline_reset:
            eligible_events.append(row)
    first_event = eligible_events[0] if eligible_events else None
    live_trigger_rows = [row for row in rows if as_int(row, "EVENT_TRIGGERED") == 1]
    live_trigger_edges = sum(
        as_int(row, "EVENT_TRIGGERED") == 1 and
        (index == 0 or as_int(rows[index - 1], "EVENT_TRIGGERED") != 1)
        for index, row in enumerate(rows)
    )

    event_kind = _row_kind(first_event) if first_event else "NONE"
    event_elapsed_ms = as_int(first_event, "EVENT_ELAPSED_MS") if first_event else None
    post_rows = [
        row for row in valid_rows
        if event_elapsed_ms is not None
        and as_int(row, "POST_EVENT_ELAPSED_MS") is not None
        and as_int(row, "POST_EVENT_ELAPSED_MS") >= 0
    ]
    post_max_ms = max(
        (as_int(row, "POST_EVENT_ELAPSED_MS") for row in post_rows),
        default=-1,
    )
    if first_event is None:
        if stop_reason == "NO_SUCCESS_EVIDENCE_OBSERVED_300S":
            result = "NO_SUCCESS_EVIDENCE_OBSERVED_300S"
        elif stop_reason == "NEW_FAILURE_RECORD_AND_TERMINAL_WR_EXIT":
            # This is the observer's historical stop-rule label. Its three
            # follow-up rows can be WRS_PRESENT (a re-arm state), so do not
            # promote the label into a claim that the extension was disabled.
            result = "NEW_FAILURE_AND_STOP_POLICY_STATE_EXIT_BEFORE_EVENT"
        else:
            result = f"INCONCLUSIVE_{stop_reason}"
    elif reset_changed or stop_reason in {
        "RESET_OR_BOOT_SIGNATURE_CHANGED", "STEP1_LOST_AFTER_ESTABLISHED", "FATAL_JTAG_OR_TCL_ERROR"
    }:
        result = "POST_EVENT_CAPTURE_STOPPED_EARLY"
    elif stop_reason == "POST_EVENT_WINDOW_COMPLETE" and post_max_ms >= 5000:
        result = "SOURCE_EVENT_WITH_5S_CONTINUITY_CAPTURE"
    else:
        result = "POST_EVENT_CAPTURE_INCOMPLETE"

    row_spacing = [as_int(row, "ROW_SPACING_MS") for row in rows]
    spacing_valid = [value for value in row_spacing if value is not None and value >= 0]
    counter_summary = non_atomic_counter_summary(legacy_rows)
    state_counts = Counter(str(as_int(row, "WR_STATE")) for row in valid_rows)
    return {
        "result": result,
        "stop_reason": stop_reason,
        "samples": len(rows),
        "read_valid_rows": len(valid_rows),
        "required_valid_rows": len(required_valid_rows),
        "event_evidence_valid_rows": len(event_valid_rows),
        "context_valid_rows": len(context_valid_rows),
        "counter_valid_rows": len(counter_valid_rows),
        "invalid_rows": len(rows) - len(valid_rows),
        "state_counts": dict(state_counts),
        "source_event_row_count": len(event_rows),
        "live_event_trigger_edges": live_trigger_edges,
        "live_trigger_rows": len(live_trigger_rows),
        "first_event_kind": event_kind,
        "first_event_elapsed_ms": event_elapsed_ms,
        "post_event_max_ms": post_max_ms,
        "reset_changed": reset_changed,
        "row_spacing_min_ms": min(spacing_valid, default=None),
        "row_spacing_max_ms": max(spacing_valid, default=None),
        "legacy_counter_intervals": counter_summary,
        "counter_nonatomic": True,
        "tail_context_only": True,
        "step6_stable_offset": "NOT_EVALUATED",
    }


def render(result: dict[str, Any]) -> str:
    counters = result["legacy_counter_intervals"]
    return "\n".join([
        f"RESULT={result['result']}",
        f"STOP_REASON={result['stop_reason']}",
        f"SAMPLES={result['samples']}",
        f"READ_VALID_ROWS={result['read_valid_rows']}",
        f"REQUIRED_VALID_ROWS={result['required_valid_rows']}",
        f"EVENT_EVIDENCE_VALID_ROWS={result['event_evidence_valid_rows']}",
        f"CONTEXT_VALID_ROWS={result['context_valid_rows']}",
        f"COUNTER_VALID_ROWS={result['counter_valid_rows']}",
        f"INVALID_ROWS={result['invalid_rows']}",
        f"WR_STATE_COUNTS={result['state_counts']}",
        f"SOURCE_BACKED_EVENT_ROWS={result['source_event_row_count']}",
        f"LIVE_EVENT_TRIGGER_EDGES={result['live_event_trigger_edges']}",
        f"LIVE_TRIGGER_ROWS={result['live_trigger_rows']}",
        f"FIRST_EVENT_KIND={result['first_event_kind']}",
        f"FIRST_EVENT_ELAPSED_MS={result['first_event_elapsed_ms']}",
        f"POST_EVENT_MAX_MS={result['post_event_max_ms']}",
        f"RESET_CHANGED={int(result['reset_changed'])}",
        f"ROW_SPACING_MS={result['row_spacing_min_ms']}..{result['row_spacing_max_ms']}",
        f"COUNTER_NONATOMIC=1",
        f"TAIL_CONTEXT_ONLY=1",
        f"LEGACY_POSTHOC_COUNTER_INTERVALS={counters['nonnegative']}/{counters['intervals']}",
        f"LEGACY_POSTHOC_POSITIVE_INTERVALS={counters['positive']}",
        f"LEGACY_POSTHOC_ZERO_INTERVALS={counters['zero']}",
        f"LEGACY_POSTHOC_NEGATIVE_OR_INVALID={counters['negative_or_invalid']}",
        f"STEP6_STABLE_OFFSET={result['step6_stable_offset']}",
    ])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    print(render(analyze_text(args.log.read_text(encoding="utf-8", errors="replace"))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
