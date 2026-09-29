#!/usr/bin/env python3
"""Summarize timestamped narrow SSTAT/CKO diagnostic captures."""

from __future__ import annotations

import argparse
import json
import re
import statistics
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path


TIMESTAMP_LINE = re.compile(r"^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z)\t(.*)$")
ANSI = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
FAST_SAMPLE = re.compile(r"FAST_SAMPLE board=(DE5 \[1-11\.[12]\]) sample=(\d+) attempt=(\d+) (.*)")
FAST_RESULT = re.compile(r"FAST_SAMPLE_RESULT board=(DE5 \[1-11\.[12]\]) sample=(\d+) accepted=(\d+) retries=(\d+)")
FIELD = re.compile(r"([A-Za-z][A-Za-z0-9_]*)=([A-Za-z0-9_./+-]+)")
STATE_NAMES = {
    0: "UNINITIALIZED",
    1: "SYNC_TAI",
    2: "SYNC_NSEC",
    3: "SYNC_PHASE",
    4: "TRACK_PHASE",
    5: "WAIT_OFFSET_STABLE",
}


@dataclass
class Row:
    board: str
    sample: int
    attempt: int
    start: datetime
    fields: dict[str, str] = field(default_factory=dict)
    end: datetime | None = None
    accepted: int | None = None
    retries: int | None = None


def parse_timestamp(raw: str) -> datetime:
    # Python versions before 3.11 accept at most six fractional digits.
    normalized = re.sub(r"(\.\d{6})\d+Z$", r"\1Z", raw)
    return datetime.fromisoformat(normalized.replace("Z", "+00:00"))


def int_field(row: Row, name: str) -> int | None:
    value = row.fields.get(name)
    if value is None or not re.fullmatch(r"-?\d+", value):
        return None
    return int(value)


def parse_capture(text: str) -> tuple[list[Row], int | None, int]:
    rows: list[Row] = []
    current: dict[str, Row] = {}
    exit_code: int | None = None
    errors = 0
    for original in text.splitlines():
        line = ANSI.sub("", original.replace("\r", "")).strip()
        match = TIMESTAMP_LINE.match(line)
        if not match:
            continue
        timestamp = parse_timestamp(match.group(1))
        body = match.group(2)
        exit_match = re.search(r"CAPTURE_PROCESS_EXIT=(\d+)", body)
        if exit_match:
            exit_code = int(exit_match.group(1))
        if re.search(r"FAST_READER_ERROR|(?:^error:|\bTIMEOUT\b)", body, re.IGNORECASE):
            errors += 1

        sample_match = FAST_SAMPLE.search(body)
        if sample_match:
            board, sample, attempt, field_text = sample_match.groups()
            row = Row(board, int(sample), int(attempt), timestamp, dict(FIELD.findall(field_text)))
            rows.append(row)
            current[board] = row
            continue

        result_match = FAST_RESULT.search(body)
        if result_match:
            board, sample, accepted, retries = result_match.groups()
            row = current.get(board)
            if row and row.sample == int(sample):
                row.end = timestamp
                row.accepted = int(accepted)
                row.retries = int(retries)

    return rows, exit_code, errors


def state_name(value: int | None) -> str:
    if value is None:
        return "INVALID"
    return STATE_NAMES.get(value, f"UNKNOWN_{value}")


def summarize(rows: list[Row], exit_code: int | None, errors: int) -> dict[str, object]:
    boards: dict[str, list[Row]] = {"DE5 [1-11.1]": [], "DE5 [1-11.2]": []}
    for row in rows:
        boards.setdefault(row.board, []).append(row)

    result: dict[str, object] = {}
    for name, board_rows in boards.items():
        board_rows.sort(key=lambda row: (row.sample, row.attempt))
        accepted = [row for row in board_rows if row.accepted == 1]
        valid = [row for row in accepted if int_field(row, "sample_valid") == 1]
        state_valid = [
            row for row in valid
            if int_field(row, "sstat_valid_begin") == 1
            and int_field(row, "sstat_valid_end") == 1
        ]
        offsets_begin = [int_field(row, "offset_begin_ps") for row in state_valid]
        offsets_end = [int_field(row, "offset_end_ps") for row in state_valid]
        offsets_begin = [value for value in offsets_begin if value is not None]
        offsets_end = [value for value in offsets_end if value is not None]
        offset_deltas = [
            int_field(row, "offset_end_ps") - int_field(row, "offset_begin_ps")
            for row in state_valid
            if int_field(row, "offset_begin_ps") is not None
            and int_field(row, "offset_end_ps") is not None
        ]
        states_begin: dict[str, int] = {}
        states_end: dict[str, int] = {}
        within_row_edges: list[dict[str, object]] = []
        transitions: list[dict[str, object]] = []
        previous_end: int | None = None

        for row in state_valid:
            first = int_field(row, "state_begin")
            last = int_field(row, "state_end")
            first_name, last_name = state_name(first), state_name(last)
            states_begin[first_name] = states_begin.get(first_name, 0) + 1
            states_end[last_name] = states_end.get(last_name, 0) + 1
            if first is not None and last is not None and first != last:
                within_row_edges.append({
                    "sample": row.sample,
                    "timestamp": row.start.isoformat(),
                    "begin_state": first_name,
                    "end_state": last_name,
                    "offset_begin_ps": int_field(row, "offset_begin_ps"),
                    "offset_end_ps": int_field(row, "offset_end_ps"),
                    "elapsed_us": int_field(row, "elapsed_us"),
                })
            if previous_end is not None and first is not None and previous_end != first:
                transitions.append({
                    "sample": row.sample,
                    "timestamp": row.start.isoformat(),
                    "from_state": state_name(previous_end),
                    "to_state": first_name,
                    "offset_begin_ps": int_field(row, "offset_begin_ps"),
                })
            previous_end = last

        starts = [row.start for row in accepted]
        intervals_ms = [(b - a).total_seconds() * 1000 for a, b in zip(starts, starts[1:])]
        row_elapsed_us = [
            value for row in accepted
            if (value := int_field(row, "elapsed_us")) is not None
        ]
        strict_both = sum(
            abs(int_field(row, "offset_begin_ps") or 0) < 60
            and abs(int_field(row, "offset_end_ps") or 0) < 60
            for row in state_valid
            if int_field(row, "offset_begin_ps") is not None
            and int_field(row, "offset_end_ps") is not None
        )
        result[name] = {
            "sample_rows": len(board_rows),
            "accepted_samples": len(accepted),
            "failed_attempt_rows": sum(row.accepted == 0 for row in board_rows),
            "accepted_samples_with_retries": sum((row.retries or 0) > 0 for row in accepted),
            "max_retries_used": max((row.retries or 0 for row in accepted), default=0),
            "data_valid_samples": sum(int_field(row, "data_valid") == 1 for row in accepted),
            "sample_valid_samples": len(valid),
            "control_framing_valid_samples": sum(int_field(row, "ctrl_valid") == 1 for row in valid),
            "servo_state_valid_samples": len(state_valid),
            "servo_state_begin_samples": states_begin,
            "servo_state_end_samples": states_end,
            "state_changes_within_row": within_row_edges,
            "between_row_state_transitions": transitions,
            "all_five_step5_lock_samples": sum(
                all(int_field(row, key) == 1 for key in (
                    "helper_locked", "main_freq", "main_phase", "main_locked", "spll_locked"
                ))
                for row in valid
            ),
            "valid_time_and_pps_samples": sum(
                int_field(row, "time_valid_begin") == 1
                and int_field(row, "time_valid_end") == 1
                and int_field(row, "pps_valid_begin") == 1
                and int_field(row, "pps_valid_end") == 1
                for row in valid
            ),
            "time_pps_probe_complete_samples": sum(
                all(int_field(row, key) is not None and int_field(row, key) >= 0
                    for key in ("time_valid_begin", "time_valid_end", "pps_valid_begin", "pps_valid_end"))
                for row in valid
            ),
            "clock_probe_complete_samples": sum(
                bool(re.fullmatch(r"[0-9A-Fa-f]{1,16}", row.fields.get("clock_begin", "")))
                and bool(re.fullmatch(r"[0-9A-Fa-f]{1,16}", row.fields.get("clock_end", "")))
                for row in valid
            ),
            "first_output_received_utc": accepted[0].start.isoformat() if accepted else None,
            "last_output_received_utc": accepted[-1].start.isoformat() if accepted else None,
            "output_received_span_seconds": round((accepted[-1].start - accepted[0].start).total_seconds(), 6) if len(accepted) > 1 else 0,
            "host_output_arrival_interval_ms_median": round(statistics.median(intervals_ms), 3) if intervals_ms else None,
            "host_output_arrival_interval_ms_min": round(min(intervals_ms), 3) if intervals_ms else None,
            "host_output_arrival_interval_ms_max": round(max(intervals_ms), 3) if intervals_ms else None,
            "reader_row_elapsed_us_samples": len(row_elapsed_us),
            "reader_row_elapsed_us_min": min(row_elapsed_us) if row_elapsed_us else None,
            "reader_row_elapsed_us_median": statistics.median(row_elapsed_us) if row_elapsed_us else None,
            "reader_row_elapsed_us_max": max(row_elapsed_us) if row_elapsed_us else None,
            "offset_begin_samples": len(offsets_begin),
            "offset_begin_min_ps": min(offsets_begin) if offsets_begin else None,
            "offset_begin_max_ps": max(offsets_begin) if offsets_begin else None,
            "offset_begin_median_ps": statistics.median(offsets_begin) if offsets_begin else None,
            "offset_end_samples": len(offsets_end),
            "offset_end_min_ps": min(offsets_end) if offsets_end else None,
            "offset_end_max_ps": max(offsets_end) if offsets_end else None,
            "offset_end_median_ps": statistics.median(offsets_end) if offsets_end else None,
            "within_row_offset_delta_samples": len(offset_deltas),
            "within_row_offset_delta_min_ps": min(offset_deltas) if offset_deltas else None,
            "within_row_offset_delta_max_ps": max(offset_deltas) if offset_deltas else None,
            "within_row_offset_delta_median_ps": statistics.median(offset_deltas) if offset_deltas else None,
            "within_row_offset_delta_max_abs_ps": max((abs(value) for value in offset_deltas), default=None),
            "both_offsets_strictly_under_60ps_samples": strict_both,
            "dms_distinct_pairs": len({(row.fields.get("dms_h"), row.fields.get("dms_l")) for row in valid}),
            "setp_distinct_values": len({row.fields.get("setp") for row in valid}),
            "ucnt_first_last": [valid[0].fields.get("ucnt"), valid[-1].fields.get("ucnt")] if valid else None,
        }

    return {
        "capture_process_exit": exit_code,
        "reader_error_lines": errors,
        "total_rows": len(rows),
        "boards": result,
        "interpretation_limit": "SSTAT and CKO are bracketed within one row, but other fields remain sequential reads; this diagnostic cannot prove single-cycle causality or Step 6 acceptance. Host output-arrival timestamps may be batched by Quartus/Tcl buffering; use reader_row_elapsed_us as the measured per-row duration, not host output-arrival intervals, as sample cadence.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture_log", type=Path)
    args = parser.parse_args()
    rows, exit_code, errors = parse_capture(args.capture_log.read_text(encoding="utf-8", errors="replace"))
    print(json.dumps(summarize(rows, exit_code, errors), indent=2))


if __name__ == "__main__":
    main()
