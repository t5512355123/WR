#!/usr/bin/env python3
"""Summarize the Step 6 startup/admission trace without causal overclaim."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
import re
from typing import Any


GROUPS = ("HEALTH", "ADMISSION", "SPLL", "EVENTS")
COUNTERS = {
    "ADMISSION": (
        "PTP_RX_COUNT_RAW",
        "PTP_TX_COUNT_RAW",
        "ETH_TX_COUNT_RAW",
        "ETH_RX_COUNT_RAW",
        "WR_LOCK_POLL_COUNT_RAW",
        "LOCK_UNLOCKED_COUNT_RAW",
        "LOCK_CALIB_FAIL_COUNT_RAW",
        "LOCK_ENABLE_COUNT_RAW",
    ),
    "SPLL": (
        "SPLL_STATE_TRANSITIONS_RAW",
        "SPLL_INIT_COUNT_RAW",
        "SPLL_CLEAR_DACS_COUNT_RAW",
    ),
    "EVENTS": (
        "DMTD_REF_ACCEPT_COUNT_RAW",
        "DMTD_FB_ACCEPT_COUNT_RAW",
        "DMTD_REF_EVENT_COUNT_RAW",
        "DMTD_FB_EVENT_COUNT_RAW",
        "TAG_VALID_COUNT_RAW",
        "TRR_WRITE_COUNT_RAW",
        "TRR_POP_COUNT_RAW",
        "IRQ_COUNT_RAW",
        "HELPER_UPDATE_COUNT_RAW",
    ),
}
CHAIN_COUNTERS = (
    "DMTD_REF_ACCEPT_COUNT_RAW",
    "DMTD_FB_ACCEPT_COUNT_RAW",
    "DMTD_REF_EVENT_COUNT_RAW",
    "DMTD_FB_EVENT_COUNT_RAW",
    "TAG_VALID_COUNT_RAW",
    "TRR_WRITE_COUNT_RAW",
    "TRR_POP_COUNT_RAW",
    "IRQ_COUNT_RAW",
    "HELPER_UPDATE_COUNT_RAW",
)


def parse_fields(line: str) -> dict[str, str]:
    return {
        key: value
        for key, value in re.findall(r"([A-Za-z][A-Za-z0-9_]*)=([^\s]+)", line)
    }


def as_int(row: dict[str, str], key: str) -> int | None:
    value = row.get(key)
    if value is None or value in {"NA", "INVALID", "TIMEOUT", "SKIPPED"}:
        return None
    try:
        if key.endswith("_RAW"):
            return int(value.removeprefix("0x"), 16)
        if key.endswith("_MS") and "." in value:
            return int(float(value))
        return int(value, 10)
    except (ValueError, TypeError):
        return None


def counter_delta32(first: int | None, last: int | None) -> tuple[int | None, str]:
    if first is None or last is None:
        return None, "MISSING"
    if last >= first:
        return last - first, "DIRECT"
    # Only accept a decrease as natural rollover when both endpoints are near
    # opposite ends of the 32-bit range; otherwise preserve it as a reset or
    # reinitialization discontinuity instead of inventing negative progress.
    if first >= 0xF0000000 and last <= 0x0FFFFFFF:
        return (1 << 32) - first + last, "ROLLOVER"
    return None, "DISCONTINUITY"


def _valid_group_records(groups: list[dict[str, str]], name: str) -> list[dict[str, str]]:
    return [
        row
        for row in groups
        if row.get("group") == name and as_int(row, "valid") == 1
    ]


def _counter_delta(
    groups: list[dict[str, str]], group_name: str, field: str
) -> tuple[int | None, str]:
    records = _valid_group_records(groups, group_name)
    if len(records) < 2:
        return None, "INSUFFICIENT_VALID_ROWS"
    return counter_delta32(as_int(records[0], field), as_int(records[-1], field))


def first_inactive_boundary(groups: list[dict[str, str]]) -> str:
    lock_enable, _ = _counter_delta(groups, "ADMISSION", "LOCK_ENABLE_COUNT_RAW")
    lock_poll, _ = _counter_delta(groups, "ADMISSION", "WR_LOCK_POLL_COUNT_RAW")
    if lock_enable is None or lock_poll is None:
        return "INCONCLUSIVE_ADMISSION_COUNTER_DISCONTINUITY_OR_COVERAGE"
    if lock_enable == 0 and lock_poll == 0:
        return "WR_LOCK_ADMISSION_NO_OBSERVED_PROGRESS"

    state_transitions, _ = _counter_delta(
        groups, "SPLL", "SPLL_STATE_TRANSITIONS_RAW"
    )
    init, _ = _counter_delta(groups, "SPLL", "SPLL_INIT_COUNT_RAW")
    if state_transitions is None or init is None:
        return "INCONCLUSIVE_SPLL_COUNTER_DISCONTINUITY_OR_COVERAGE"
    if state_transitions == 0 and init == 0:
        return "WR_LOCK_TO_SPLL_STARTUP_NO_OBSERVED_PROGRESS"

    accepted_ref, _ = _counter_delta(groups, "EVENTS", "DMTD_REF_ACCEPT_COUNT_RAW")
    accepted_fb, _ = _counter_delta(groups, "EVENTS", "DMTD_FB_ACCEPT_COUNT_RAW")
    if accepted_ref is None or accepted_fb is None:
        return "INCONCLUSIVE_DMTD_ACCEPT_COUNTER_DISCONTINUITY_OR_COVERAGE"
    if accepted_ref == 0:
        return "REF_DMTD_ACCEPT_NO_OBSERVED_PROGRESS"
    if accepted_fb == 0:
        return "FB_DMTD_ACCEPT_NO_OBSERVED_PROGRESS"

    ref_events, _ = _counter_delta(groups, "EVENTS", "DMTD_REF_EVENT_COUNT_RAW")
    fb_events, _ = _counter_delta(groups, "EVENTS", "DMTD_FB_EVENT_COUNT_RAW")
    if ref_events is None or fb_events is None:
        return "INCONCLUSIVE_DMTD_EVENT_COUNTER_DISCONTINUITY_OR_COVERAGE"
    if ref_events == 0:
        return "REF_ACCEPT_TO_SYS_EVENT_NO_OBSERVED_PROGRESS"
    if fb_events == 0:
        return "FB_ACCEPT_TO_SYS_EVENT_NO_OBSERVED_PROGRESS"

    deltas: dict[str, int | None] = {}
    for name in CHAIN_COUNTERS[4:]:
        deltas[name], _kind = _counter_delta(groups, "EVENTS", name)
        if deltas[name] is None:
            return "INCONCLUSIVE_TAG_HELPER_COUNTER_DISCONTINUITY_OR_COVERAGE"

    if deltas["TAG_VALID_COUNT_RAW"] == 0:
        return "SYS_EVENT_TO_TAG_NO_OBSERVED_PROGRESS"
    if deltas["TRR_WRITE_COUNT_RAW"] == 0:
        return "TAG_TO_TRR_WRITE_NO_OBSERVED_PROGRESS"
    if deltas["TRR_POP_COUNT_RAW"] == 0:
        return "TRR_WRITE_TO_POP_NO_OBSERVED_PROGRESS"
    if deltas["IRQ_COUNT_RAW"] == 0:
        return "TRR_POP_TO_IRQ_NO_OBSERVED_PROGRESS"
    if deltas["HELPER_UPDATE_COUNT_RAW"] == 0:
        return "IRQ_TO_HELPER_UPDATE_NO_OBSERVED_PROGRESS"
    return "NO_SINGLE_INACTIVE_COUNTER_BOUNDARY_OBSERVED"


def analyze_text(text: str) -> dict[str, Any]:
    row_records = [
        parse_fields(line) for line in text.splitlines() if line.startswith("S6S_ROW ")
    ]
    group_records = [
        parse_fields(line) for line in text.splitlines() if line.startswith("S6S_GROUP ")
    ]
    stop_records = [
        parse_fields(line) for line in text.splitlines() if line.startswith("S6S_STOP ")
    ]
    stop = stop_records[-1] if stop_records else {}
    stop_reason = stop.get("stop_reason", "MISSING_STOP_RECORD")

    trusted = [row for row in row_records if as_int(row, "STRUCTURALLY_TRUSTED_ROW") == 1]
    trusted_states = Counter(
        str(as_int(row, "SERVO_STATE"))
        for row in trusted
        if as_int(row, "SERVO_STATE") is not None
    )
    group_counts = Counter(row.get("group", "UNKNOWN") for row in group_records)
    group_valid_counts = Counter(
        row.get("group", "UNKNOWN")
        for row in group_records
        if as_int(row, "valid") == 1
    )
    group_coverage = {
        group: (
            group_valid_counts[group] / group_counts[group]
            if group_counts[group]
            else 0.0
        )
        for group in GROUPS
    }
    structural_coverage = len(trusted) / len(row_records) if row_records else 0.0
    step1_rows = sum(as_int(row, "STEP1_GATE") == 1 for row in trusted)
    lock_keys = (
        "HELPER_LOCK",
        "MAIN_FREQ_LOCK",
        "MAIN_PHASE_LOCK",
        "MAIN_LOCK",
        "PSTAT_LOCK",
    )
    lock_high_counts = {
        key: sum(as_int(row, key) == 1 for row in trusted) for key in lock_keys
    }
    helper_lock_seen = any(as_int(row, "HELPER_LOCK") == 1 for row in trusted)
    max_ready_rows = max(
        (as_int(row, "READY_STREAK_ROWS") or 0 for row in row_records), default=0
    )
    max_ready_ms = max(
        (as_int(row, "READY_STREAK_MS") or 0 for row in row_records), default=0
    )
    spacings = [
        float(row["ROW_SPACING_MS"])
        for row in row_records
        if row.get("ROW_SPACING_MS") not in {None, "NA"}
    ]

    deltas: dict[str, dict[str, int | str | None]] = {}
    for group_name, fields in COUNTERS.items():
        for field in fields:
            delta, kind = _counter_delta(group_records, group_name, field)
            deltas[field] = {"delta": delta, "kind": kind}

    phase_boundary_seen = any(
        as_int(row, "STRUCTURALLY_TRUSTED_ROW") == 1
        and as_int(row, "SERVO_STATE") in {3, 4, 5}
        for row in row_records
    )
    if stop_reason == "READINESS_REACHED":
        result = "STARTUP_RECOVERED_BOUNDARY_STOPPED"
    elif stop_reason == "PHASE_STATE_BOUNDARY" or phase_boundary_seen:
        result = "PHASE_STATE_REACHED_BOUNDARY_STOPPED"
    elif stop_reason == "DURATION_LIMIT":
        if structural_coverage >= 0.95 and all(
            group_coverage[group] >= 0.95 for group in GROUPS
        ):
            result = "READ_ONLY_STARTUP_TRACE_COMPLETE"
        else:
            result = "INCONCLUSIVE_STRUCTURAL_OR_GROUP_COVERAGE"
    else:
        result = f"INCONCLUSIVE_STOPPED_{stop_reason}"

    return {
        "result": result,
        "stop_reason": stop_reason,
        "duration_ms": as_int(stop, "duration_ms"),
        "elapsed_ms": as_int(stop, "elapsed_ms"),
        "samples": len(row_records),
        "structurally_trusted": len(trusted),
        "structural_coverage": structural_coverage,
        "group_counts": dict(group_counts),
        "group_valid_counts": dict(group_valid_counts),
        "group_coverage": group_coverage,
        "state_counts": dict(trusted_states),
        "step1_pass_trusted": step1_rows,
        "lock_high_counts": lock_high_counts,
        "helper_lock_seen": helper_lock_seen,
        "max_ready_rows": max_ready_rows,
        "max_ready_ms": max_ready_ms,
        "phase_boundary_seen": phase_boundary_seen,
        "row_spacing_ms_min": min(spacings) if spacings else None,
        "row_spacing_ms_max": max(spacings) if spacings else None,
        "counter_deltas": deltas,
        "first_inactive_boundary_candidate": first_inactive_boundary(group_records),
    }


def render(summary: dict[str, Any]) -> str:
    lines = [
        f"RESULT={summary['result']}",
        f"STOP_REASON={summary['stop_reason']}",
        f"REQUESTED_DURATION_MS={summary['duration_ms']}",
        f"ELAPSED_MS={summary['elapsed_ms']}",
        f"SAMPLE_COUNT={summary['samples']}",
        f"STRUCTURALLY_TRUSTED={summary['structurally_trusted']}/{summary['samples']}",
        f"STRUCTURAL_COVERAGE={summary['structural_coverage']:.4f}",
        f"TRUSTED_SERVO_STATE_COUNTS={summary['state_counts']}",
        f"STEP1_PASS_TRUSTED_ROWS={summary['step1_pass_trusted']}",
        f"LOCK_HIGH_TRUSTED_ROWS={summary['lock_high_counts']}",
        f"HELPER_LOCK_SEEN={int(summary['helper_lock_seen'])}",
        f"MAX_READY_STREAK_ROWS={summary['max_ready_rows']}",
        f"MAX_READY_STREAK_MS={summary['max_ready_ms']}",
        f"PHASE_STATE_BOUNDARY_SEEN={int(summary['phase_boundary_seen'])}",
        f"GROUP_VALID_COUNTS={summary['group_valid_counts']}",
        f"GROUP_COVERAGE={summary['group_coverage']}",
        f"ROW_SPACING_MS_MIN={summary['row_spacing_ms_min']}",
        f"ROW_SPACING_MS_MAX={summary['row_spacing_ms_max']}",
        f"FIRST_INACTIVE_BOUNDARY_CANDIDATE={summary['first_inactive_boundary_candidate']}",
        "COUNTER_DELTAS:",
    ]
    for field, result in sorted(summary["counter_deltas"].items()):
        lines.append(f"  {field}={result['delta']} ({result['kind']})")
    lines.extend(
        [
            "CAUSAL_LIMIT=READ_ONLY_GROUPED_CORRELATION_NOT_SINGLE_CYCLE_CAUSALITY",
            "STEP6_STABLE_OFFSET=NOT_EVALUATED_BY_THIS_TRACE",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    summary = analyze_text(args.log.read_text(encoding="utf-8", errors="replace"))
    print(render(summary))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
