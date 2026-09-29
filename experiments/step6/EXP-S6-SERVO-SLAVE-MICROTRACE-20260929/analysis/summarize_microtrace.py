#!/usr/bin/env python3
"""Summarize timestamped Slave-only SSTAT/CKO microtrace logs."""

from __future__ import annotations

import argparse
import json
import re
import statistics
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path


TIMESTAMP_LINE = re.compile(r"^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z)\t(.*)$")
ANSI = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
SAMPLE = re.compile(r"MICRO_SAMPLE board=(DE5_1-11\.2) sample=(\d+) attempt=(\d+) (.*)")
SAMPLE_RESULT = re.compile(
    r"MICRO_SAMPLE_RESULT board=(DE5_1-11\.2) sample=(\d+) accepted=(\d+) retries=(\d+) consecutive_invalid=(\d+)"
)
FIELD = re.compile(r"([A-Za-z][A-Za-z0-9_]*)=([A-Za-z0-9_./+-]+)")
STATES = {
    0: "UNINITIALIZED",
    1: "SYNC_TAI",
    2: "SYNC_NSEC",
    3: "SYNC_PHASE",
    4: "TRACK_PHASE",
    5: "WAIT_OFFSET_STABLE",
}


@dataclass
class Attempt:
    sample: int
    attempt: int
    received: datetime
    fields: dict[str, str] = field(default_factory=dict)


def parse_time(raw: str) -> datetime:
    normalized = re.sub(r"(\.\d{6})\d+Z$", r"\1Z", raw)
    return datetime.fromisoformat(normalized.replace("Z", "+00:00"))


def int_field(row: Attempt, name: str) -> int | None:
    value = row.fields.get(name)
    if value is None or not re.fullmatch(r"-?\d+", value):
        return None
    return int(value)


def parse_log(text: str) -> tuple[list[Attempt], dict[int, tuple[int, int]], int | None, int, str | None]:
    attempts: list[Attempt] = []
    results: dict[int, tuple[int, int]] = {}
    current: dict[tuple[int, int], Attempt] = {}
    exit_code: int | None = None
    errors = 0
    stop_reason: str | None = None
    for original in text.splitlines():
        line = ANSI.sub("", original.replace("\r", "")).strip()
        match = TIMESTAMP_LINE.match(line)
        if not match:
            continue
        timestamp = parse_time(match.group(1))
        body = match.group(2)
        if re.search(r"MICRO_READER_ERROR|(?:^error:|\bTIMEOUT\b)", body, re.IGNORECASE):
            errors += 1
        exit_match = re.search(r"CAPTURE_PROCESS_EXIT=(\d+)", body)
        if exit_match:
            exit_code = int(exit_match.group(1))
        reason = re.search(r"MICRO_STOP reason=([A-Za-z0-9_-]+)", body)
        if reason:
            stop_reason = reason.group(1)

        sample_match = SAMPLE.search(body)
        if sample_match:
            _, sample_raw, attempt_raw, raw_fields = sample_match.groups()
            row = Attempt(int(sample_raw), int(attempt_raw), timestamp, dict(FIELD.findall(raw_fields)))
            attempts.append(row)
            current[(row.sample, row.attempt)] = row
            continue

        result_match = SAMPLE_RESULT.search(body)
        if result_match:
            _, sample_raw, accepted_raw, retries_raw, _ = result_match.groups()
            results[int(sample_raw)] = (int(accepted_raw), int(retries_raw))

    return attempts, results, exit_code, errors, stop_reason


def stats(values: list[int | float]) -> dict[str, int | float | None]:
    if not values:
        return {"count": 0, "min": None, "median": None, "max": None}
    return {
        "count": len(values),
        "min": min(values),
        "median": statistics.median(values),
        "max": max(values),
    }


def summarize(
    attempts: list[Attempt], results: dict[int, tuple[int, int]], exit_code: int | None,
    errors: int, stop_reason: str | None,
) -> dict[str, object]:
    final_rows: list[Attempt] = []
    for sample, (accepted, _) in sorted(results.items()):
        candidates = [row for row in attempts if row.sample == sample]
        if accepted:
            valid = [row for row in candidates if int_field(row, "row_valid") == 1]
            if valid:
                final_rows.append(valid[-1])

    states_begin = Counter()
    states_end = Counter()
    cko_begin: list[int] = []
    cko_end: list[int] = []
    deltas: list[int] = []
    elapsed: list[int] = []
    either_under = both_under = 0
    within_row_state_changes = 0
    between_row_state_changes = 0
    previous_end: int | None = None
    state_rows_valid = 0
    strict_offset_run: list[Attempt] = []
    strict_offset_runs: list[list[Attempt]] = []
    strict_track_samples = 0
    previous_sample: int | None = None
    for row in final_rows:
        if previous_sample is not None and row.sample != previous_sample + 1:
            if strict_offset_run:
                strict_offset_runs.append(strict_offset_run)
            strict_offset_run = []
        previous_sample = row.sample
        begin = int_field(row, "state_begin")
        end = int_field(row, "state_end")
        ob = int_field(row, "offset_begin_ps")
        oe = int_field(row, "offset_end_ps")
        duration = int_field(row, "elapsed_us")
        if duration is not None and duration >= 0:
            elapsed.append(duration)
        if int_field(row, "sstat_valid_begin") == 1 and int_field(row, "sstat_valid_end") == 1 and begin is not None and end is not None:
            state_rows_valid += 1
            states_begin[STATES.get(begin, f"STATE_{begin}")] += 1
            states_end[STATES.get(end, f"STATE_{end}")] += 1
            if begin != end:
                within_row_state_changes += 1
            if previous_end is not None and previous_end != begin:
                between_row_state_changes += 1
            previous_end = end
        if ob is not None:
            cko_begin.append(ob)
        if oe is not None:
            cko_end.append(oe)
        if ob is not None and oe is not None:
            deltas.append(oe - ob)
            under_begin = abs(ob) < 60
            under_end = abs(oe) < 60
            either_under += int(under_begin or under_end)
            both_under += int(under_begin and under_end)
            if under_begin and under_end:
                strict_offset_run.append(row)
                if begin == 4 and end == 4:
                    strict_track_samples += 1
            else:
                if strict_offset_run:
                    strict_offset_runs.append(strict_offset_run)
                strict_offset_run = []
    if strict_offset_run:
        strict_offset_runs.append(strict_offset_run)
    longest_strict_offset_run = max(strict_offset_runs, key=len, default=[])

    strict_offset_run_summaries = []
    for run in strict_offset_runs:
        run_offsets_begin = [int_field(row, "offset_begin_ps") for row in run]
        run_offsets_end = [int_field(row, "offset_end_ps") for row in run]
        strict_offset_run_summaries.append({
            "first_sample": run[0].sample,
            "last_sample": run[-1].sample,
            "samples": len(run),
            "sum_of_reader_row_elapsed_us": sum(
                (int_field(row, "elapsed_us") or 0) for row in run
            ),
            "track_phase_both_boundaries_samples": sum(
                int(int_field(row, "state_begin") == 4 and int_field(row, "state_end") == 4)
                for row in run
            ),
            "offset_begin_min_ps": min(v for v in run_offsets_begin if v is not None),
            "offset_begin_max_ps": max(v for v in run_offsets_begin if v is not None),
            "offset_end_min_ps": min(v for v in run_offsets_end if v is not None),
            "offset_end_max_ps": max(v for v in run_offsets_end if v is not None),
        })

    arrivals = [row.received for row in final_rows]
    arrival_intervals_ms = [
        (right - left).total_seconds() * 1000
        for left, right in zip(arrivals, arrivals[1:])
    ]
    retry_count = sum(retries > 0 for accepted, retries in results.values() if accepted)
    failed_attempts = sum(int_field(row, "row_valid") != 1 for row in attempts)
    return {
        "board": "DE5_1-11.2",
        "capture_process_exit": exit_code,
        "reader_error_lines": errors,
        "stop_reason": stop_reason,
        "attempt_rows": len(attempts),
        "failed_attempt_rows": failed_attempts,
        "sample_results": len(results),
        "accepted_samples": len(final_rows),
        "accepted_samples_with_retries": retry_count,
        "servo_state_valid_rows": state_rows_valid,
        "state_at_row_begin": dict(states_begin),
        "state_at_row_end": dict(states_end),
        "track_phase_observed_at_boundary": states_begin["TRACK_PHASE"] + states_end["TRACK_PHASE"] > 0,
        "within_row_state_change_rows": within_row_state_changes,
        "between_row_state_change_boundaries": between_row_state_changes,
        "offset_begin_ps": stats(cko_begin),
        "offset_end_ps": stats(cko_end),
        "within_row_offset_delta_ps": stats(deltas),
        "either_boundary_strictly_under_60ps_samples": either_under,
        "both_boundaries_strictly_under_60ps_samples": both_under,
        "strict_offset_run_episodes": strict_offset_run_summaries,
        "longest_consecutive_both_boundaries_under_60ps_samples": len(longest_strict_offset_run),
        "longest_run_first_sample": longest_strict_offset_run[0].sample if longest_strict_offset_run else None,
        "longest_run_last_sample": longest_strict_offset_run[-1].sample if longest_strict_offset_run else None,
        "longest_run_sum_of_reader_row_elapsed_us": sum(
            (int_field(row, "elapsed_us") or 0) for row in longest_strict_offset_run
        ),
        "longest_run_offset_begin_ps": stats([
            int_field(row, "offset_begin_ps") for row in longest_strict_offset_run
            if int_field(row, "offset_begin_ps") is not None
        ]),
        "longest_run_offset_end_ps": stats([
            int_field(row, "offset_end_ps") for row in longest_strict_offset_run
            if int_field(row, "offset_end_ps") is not None
        ]),
        "both_boundaries_under_60ps_and_track_phase_samples": strict_track_samples,
        "reader_row_elapsed_us": stats(elapsed),
        "host_output_arrival_interval_ms": stats(arrival_intervals_ms),
        "first_sample_output_received_utc": arrivals[0].isoformat() if arrivals else None,
        "last_sample_output_received_utc": arrivals[-1].isoformat() if arrivals else None,
        "interpretation_limit": (
            "The host receives timestamped output lines, not hardware-edge timestamps. "
            "Use reader_row_elapsed_us for row duration. SSTAT and CKO are sequential "
            "bracketed mailbox reads, not an atomic snapshot; absence of a sampled "
            "TRACK_PHASE/under-60-ps boundary cannot exclude a sub-row transient."
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    parsed = summarize(*parse_log(args.log.read_text(encoding="utf-8", errors="replace")))
    rendered = json.dumps(parsed, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
