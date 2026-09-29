#!/usr/bin/env python3
"""Summarize Slave SSTAT/CKO correlation with WR servo counters and delay."""

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
SAMPLE = re.compile(r"CORR_SAMPLE board=(DE5_1-11\.2) sample=(\d+) attempt=(\d+) (.*)")
RESULT = re.compile(
    r"CORR_SAMPLE_RESULT board=(DE5_1-11\.2) sample=(\d+) accepted=(\d+) retries=(\d+) consecutive_invalid=(\d+)"
)
BOARD_RESULT = re.compile(
    r"CORR_BOARD_RESULT board=(DE5_1-11\.2) samples=(\d+) accepted=(\d+) failed=(\d+) elapsed_ms=(\d+)"
)
FIELD = re.compile(r"([A-Za-z][A-Za-z0-9_]*)=([A-Za-z0-9_./+-]+)")
STATES = {
    0: "UNINITIALIZED", 1: "SYNC_TAI", 2: "SYNC_NSEC",
    3: "SYNC_PHASE", 4: "TRACK_PHASE", 5: "WAIT_OFFSET_STABLE",
}
OFFSET_EVENT_THRESHOLD_PS = 120


@dataclass
class Attempt:
    sample: int
    attempt: int
    received: datetime
    fields: dict[str, str] = field(default_factory=dict)


def parse_time(raw: str) -> datetime:
    normalized = re.sub(r"(\.\d{6})\d+Z$", r"\1Z", raw)
    return datetime.fromisoformat(normalized.replace("Z", "+00:00"))


def int_field(row: Attempt, name: str, base: int = 10) -> int | None:
    value = row.fields.get(name)
    if value is None:
        return None
    try:
        return int(value, base)
    except ValueError:
        return None


def parse_log(text: str) -> tuple[
    list[Attempt], dict[int, tuple[int, int]], int | None, int, str | None,
    dict[str, int] | None,
]:
    attempts: list[Attempt] = []
    results: dict[int, tuple[int, int]] = {}
    exit_code: int | None = None
    errors = 0
    stop_reason: str | None = None
    board_result: dict[str, int] | None = None
    for original in text.splitlines():
        line = ANSI.sub("", original.replace("\r", "")).strip()
        match = TIMESTAMP_LINE.match(line)
        if not match:
            continue
        received = parse_time(match.group(1))
        body = match.group(2)
        if re.search(r"CORR_READER_ERROR|(?:^error:|\bTIMEOUT\b)", body, re.IGNORECASE):
            errors += 1
        exit_match = re.search(r"CAPTURE_PROCESS_EXIT=(\d+)", body)
        if exit_match:
            exit_code = int(exit_match.group(1))
        stop = re.search(r"CORR_STOP reason=([A-Za-z0-9_-]+)", body)
        if stop:
            stop_reason = stop.group(1)
        sample_match = SAMPLE.search(body)
        if sample_match:
            _, sample, attempt, raw_fields = sample_match.groups()
            attempts.append(Attempt(int(sample), int(attempt), received, dict(FIELD.findall(raw_fields))))
            continue
        result_match = RESULT.search(body)
        if result_match:
            _, sample, accepted, retries, _ = result_match.groups()
            results[int(sample)] = (int(accepted), int(retries))
        board_match = BOARD_RESULT.search(body)
        if board_match:
            _, samples, accepted, failed, elapsed_ms = board_match.groups()
            board_result = {
                "samples": int(samples), "accepted": int(accepted),
                "failed": int(failed), "elapsed_ms": int(elapsed_ms),
            }
    return attempts, results, exit_code, errors, stop_reason, board_result


def stats(values: list[int | float]) -> dict[str, int | float | None]:
    if not values:
        return {"count": 0, "min": None, "median": None, "max": None}
    return {"count": len(values), "min": min(values), "median": statistics.median(values), "max": max(values)}


def dms_value(row: Attempt, suffix: str) -> int | None:
    hi = int_field(row, f"dms_hi_{suffix}", 16)
    lo = int_field(row, f"dms_lo_{suffix}", 16)
    if hi is None or lo is None:
        return None
    value = ((hi & 0xFFFFFFFF) << 32) | (lo & 0xFFFFFFFF)
    return value - (1 << 64) if value >= (1 << 63) else value


def summarize(
    attempts: list[Attempt], results: dict[int, tuple[int, int]], exit_code: int | None,
    errors: int, stop_reason: str | None, board_result: dict[str, int] | None = None,
) -> dict[str, object]:
    final_rows: list[Attempt] = []
    for sample, (accepted, _) in sorted(results.items()):
        candidates = [row for row in attempts if row.sample == sample and int_field(row, "row_valid") == 1]
        if accepted and candidates:
            final_rows.append(candidates[-1])

    state_begin_counts: Counter[str] = Counter()
    state_end_counts: Counter[str] = Counter()
    cko_within: list[int] = []
    cko_between: list[int] = []
    ucnt_within: list[int] = []
    ucnt_between: list[int] = []
    setp_within: list[int] = []
    setp_between: list[int] = []
    dms_within: list[int] = []
    dms_between: list[int] = []
    elapsed: list[int] = []
    strict_rows = track_strict_rows = track_boundary_rows = 0
    within_state_changes = between_state_changes = 0
    correlation_events: list[dict[str, object]] = []
    previous: dict[str, int] | None = None
    previous_sample: int | None = None

    for row in final_rows:
        f = row.fields
        state_b = int_field(row, "state_begin")
        state_e = int_field(row, "state_end")
        cko_b = int_field(row, "offset_begin_ps")
        cko_e = int_field(row, "offset_end_ps")
        ucnt_b = int_field(row, "ucnt_begin", 16)
        ucnt_e = int_field(row, "ucnt_end", 16)
        setp_b = int_field(row, "setp_begin_ps")
        setp_e = int_field(row, "setp_end_ps")
        dms_b = dms_value(row, "begin")
        dms_e = dms_value(row, "end")
        row_us = int_field(row, "elapsed_us")
        if row_us is not None:
            elapsed.append(row_us)
        if state_b is not None:
            state_begin_counts[STATES.get(state_b, f"STATE_{state_b}")] += 1
        if state_e is not None:
            state_end_counts[STATES.get(state_e, f"STATE_{state_e}")] += 1
        if state_b is not None and state_e is not None and state_b != state_e:
            within_state_changes += 1
        if previous is not None and previous_sample == row.sample - 1 and state_b is not None and previous["state_end"] != state_b:
            between_state_changes += 1

        if cko_b is not None and cko_e is not None:
            cko_within_delta = cko_e - cko_b
            cko_within.append(cko_within_delta)
            strict = abs(cko_b) < 60 and abs(cko_e) < 60
            strict_rows += int(strict)
            track_strict_rows += int(strict and state_b == 4 and state_e == 4)
        else:
            cko_within_delta = None
            strict = False

        if ucnt_b is not None and ucnt_e is not None:
            ucnt_within_delta = (ucnt_e - ucnt_b) & 0xFFFFFFFF
            ucnt_within.append(ucnt_within_delta)
        else:
            ucnt_within_delta = None
        setp_within_delta = setp_e - setp_b if setp_b is not None and setp_e is not None else None
        if setp_within_delta is not None:
            setp_within.append(setp_within_delta)
        dms_within_delta = dms_e - dms_b if dms_b is not None and dms_e is not None else None
        if dms_within_delta is not None:
            dms_within.append(dms_within_delta)

        cko_cross = ucnt_cross = setp_cross = dms_cross = None
        if previous is not None and previous_sample == row.sample - 1:
            if cko_b is not None:
                cko_cross = cko_b - previous["cko_end"]
                cko_between.append(cko_cross)
            if ucnt_b is not None:
                ucnt_cross = (ucnt_b - previous["ucnt_end"]) & 0xFFFFFFFF
                ucnt_between.append(ucnt_cross)
            if setp_b is not None:
                setp_cross = setp_b - previous["setp_end"]
                setp_between.append(setp_cross)
            if dms_b is not None:
                dms_cross = dms_b - previous["dms_end"]
                dms_between.append(dms_cross)

        if state_b == 4 or state_e == 4:
            track_boundary_rows += 1
        largest_cko_change = max(
            (abs(value) for value in (cko_cross, cko_within_delta) if value is not None),
            default=0,
        )
        if largest_cko_change >= OFFSET_EVENT_THRESHOLD_PS:
            ucnt_changed = bool((ucnt_within_delta or 0) or (ucnt_cross or 0))
            setp_changed = bool((setp_within_delta or 0) or (setp_cross or 0))
            dms_changed = bool((dms_within_delta or 0) or (dms_cross or 0))
            correlation_events.append({
                "sample": row.sample,
                "state_begin": STATES.get(state_b, str(state_b)) if state_b is not None else None,
                "state_end": STATES.get(state_e, str(state_e)) if state_e is not None else None,
                "offset_step_from_previous_row_end_ps": cko_cross,
                "within_row_offset_delta_ps": cko_within_delta,
                "ucnt_delta_across_rows": ucnt_cross,
                "ucnt_delta_within_row": ucnt_within_delta,
                "setp_delta_across_rows_ps": setp_cross,
                "setp_delta_within_row_ps": setp_within_delta,
                "dms_delta_across_rows_ps": dms_cross,
                "dms_delta_within_row_ps": dms_within_delta,
                "ucnt_changed_in_bracket": ucnt_changed,
                "setp_changed_in_bracket": setp_changed,
                "dms_changed_in_bracket": dms_changed,
            })

        if None not in (cko_e, ucnt_e, setp_e, dms_e, state_e):
            previous = {"cko_end": cko_e, "ucnt_end": ucnt_e, "setp_end": setp_e, "dms_end": dms_e, "state_end": state_e}
            previous_sample = row.sample
        else:
            previous = None
            previous_sample = None

    arrivals = [row.received for row in final_rows]
    arrival_ms = [(b - a).total_seconds() * 1000 for a, b in zip(arrivals, arrivals[1:])]
    retry_count = sum(accepted and retries > 0 for accepted, retries in results.values())
    failed_attempts = sum(int_field(row, "row_valid") != 1 for row in attempts)
    correlation_events.sort(
        key=lambda event: max(
            abs(value) for value in (
                event["offset_step_from_previous_row_end_ps"],
                event["within_row_offset_delta_ps"],
            ) if value is not None
        ),
        reverse=True,
    )
    event_association = {
        "events_at_or_above_120ps": len(correlation_events),
        "events_with_ucnt_change_in_bracket": sum(bool(event["ucnt_changed_in_bracket"]) for event in correlation_events),
        "events_with_setp_change_in_bracket": sum(bool(event["setp_changed_in_bracket"]) for event in correlation_events),
        "events_with_dms_change_in_bracket": sum(bool(event["dms_changed_in_bracket"]) for event in correlation_events),
        "events_with_both_ucnt_and_dms_change": sum(
            bool(event["ucnt_changed_in_bracket"] and event["dms_changed_in_bracket"])
            for event in correlation_events
        ),
        "events_with_ucnt_but_no_dms_change": sum(
            bool(event["ucnt_changed_in_bracket"] and not event["dms_changed_in_bracket"])
            for event in correlation_events
        ),
        "events_with_dms_but_no_ucnt_change": sum(
            bool(event["dms_changed_in_bracket"] and not event["ucnt_changed_in_bracket"])
            for event in correlation_events
        ),
        "events_with_no_ucnt_setp_or_dms_change": sum(
            bool(not event["ucnt_changed_in_bracket"] and
                 not event["setp_changed_in_bracket"] and
                 not event["dms_changed_in_bracket"])
            for event in correlation_events
        ),
        "top_20_offset_events": correlation_events[:20],
    }
    return {
        "board": "DE5_1-11.2",
        "capture_process_exit": exit_code,
        "board_result": board_result,
        "reader_error_lines": errors,
        "stop_reason": stop_reason,
        "attempt_rows": len(attempts),
        "failed_attempt_rows": failed_attempts,
        "sample_results": len(results),
        "accepted_samples": len(final_rows),
        "accepted_samples_with_retries": retry_count,
        "state_at_row_begin": dict(state_begin_counts),
        "state_at_row_end": dict(state_end_counts),
        "track_phase_boundary_rows": track_boundary_rows,
        "strict_offset_both_boundaries_rows": strict_rows,
        "strict_offset_and_track_phase_both_boundaries_rows": track_strict_rows,
        "within_row_state_change_rows": within_state_changes,
        "between_row_state_change_boundaries": between_state_changes,
        "cko_within_row_delta_ps": stats(cko_within),
        "cko_between_row_step_ps": stats(cko_between),
        "ucnt_delta_within_row": stats(ucnt_within),
        "ucnt_delta_between_rows": stats(ucnt_between),
        "setp_delta_within_row_ps": stats(setp_within),
        "setp_delta_between_rows_ps": stats(setp_between),
        "dms_delta_within_row_ps": stats(dms_within),
        "dms_delta_between_rows_ps": stats(dms_between),
        "offset_event_correlation": event_association,
        "reader_row_elapsed_us": stats(elapsed),
        "host_output_arrival_interval_ms": stats(arrival_ms),
        "first_sample_output_received_utc": arrivals[0].isoformat() if arrivals else None,
        "last_sample_output_received_utc": arrivals[-1].isoformat() if arrivals else None,
        "interpretation_limit": (
            "Fields are sequential diagnostic mailbox reads, not an atomic snapshot. "
            "UCNT/SETP/DMS changes in the same bracket support correlation only, not "
            "causality. Host output arrival timestamps may be buffered; use the "
            "reader_row_elapsed_us field for measured row duration."
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = summarize(*parse_log(args.log.read_text(encoding="utf-8", errors="replace")))
    rendered = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("w", encoding="utf-8", newline="\n") as output_file:
            output_file.write(rendered)
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
