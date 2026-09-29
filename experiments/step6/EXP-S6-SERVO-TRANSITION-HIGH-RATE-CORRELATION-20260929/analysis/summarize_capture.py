#!/usr/bin/env python3
"""Summarize timestamped output from the frozen Step 6 runtime reader."""

from __future__ import annotations

import argparse
import json
import re
import statistics
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


TIMESTAMP_LINE = re.compile(r"^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z)\t(.*)$")
ANSI = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
SAMPLE_START = re.compile(
    r"SESSION_SAMPLE board=(DE5 \[1-11\.[12]\]) sample=(\d+) attempt=(\d+) status=([0-9A-Fa-f]+)"
)
SAMPLE_RESULT = re.compile(
    r"SESSION_SAMPLE_RESULT board=(DE5 \[1-11\.[12]\]) sample=(\d+) accepted=(\d+) retries=(\d+)"
)
PAIR = re.compile(r"([A-Za-z][A-Za-z0-9_]*)(?:=|:)([A-Za-z0-9_./+-]+)")
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
    end: datetime | None = None
    accepted: int | None = None
    retries: int | None = None
    frame_valid: int | None = None
    step5_sample_valid: int | None = None
    wr_state_block_valid: int | None = None
    servo_state_valid: int | None = None
    servo_state: int | None = None
    link_up: int | None = None
    spll_locked: int | None = None
    time_valid: int | None = None
    pps_valid: int | None = None
    cko_raw: str | None = None
    offset_ps: int | None = None
    dms_raw: int | None = None
    setp_raw: int | None = None
    ucnt_raw: int | None = None
    helper_locked: int | None = None
    main_freq_locked: int | None = None
    main_phase_locked: int | None = None
    main_locked: int | None = None
    pstat_locked: int | None = None


def parse_u32_hex(value: str) -> int | None:
    if not re.fullmatch(r"[0-9A-Fa-f]{1,8}", value):
        return None
    return int(value, 16)


def signed_u32(value: str) -> int | None:
    number = parse_u32_hex(value)
    if number is None:
        return None
    return number - 0x1_0000_0000 if number & 0x8000_0000 else number


def parse_capture(text: str) -> tuple[list[Row], int | None, int]:
    rows: list[Row] = []
    current: dict[tuple[str, int, int], Row] = {}
    current_for_board: dict[str, Row] = {}
    exit_code: int | None = None
    reader_errors = 0

    for original in text.splitlines():
        line = ANSI.sub("", original.replace("\r", "")).strip()
        timestamp_match = TIMESTAMP_LINE.match(line)
        if not timestamp_match:
            continue
        raw_timestamp = timestamp_match.group(1)
        # Python versions before 3.11 accept at most six fractional digits.
        compatible_timestamp = re.sub(r"(\.\d{6})\d+Z$", r"\1Z", raw_timestamp)
        timestamp = datetime.fromisoformat(compatible_timestamp.replace("Z", "+00:00"))
        body = timestamp_match.group(2)

        exit_match = re.search(r"CAPTURE_PROCESS_EXIT=(\d+)", body)
        if exit_match:
            exit_code = int(exit_match.group(1))
        if re.search(r"(?:^error:|\bTIMEOUT\b)", body, re.IGNORECASE):
            reader_errors += 1

        start_match = SAMPLE_START.search(body)
        if start_match:
            board, sample, attempt, _status = start_match.groups()
            row = Row(board, int(sample), int(attempt), timestamp)
            rows.append(row)
            current[(board, row.sample, row.attempt)] = row
            current_for_board[board] = row
            continue

        result_match = SAMPLE_RESULT.search(body)
        if result_match:
            board, sample, accepted, retries = result_match.groups()
            row = current_for_board.get(board)
            if row and row.sample == int(sample):
                row.end = timestamp
                row.accepted = int(accepted)
                row.retries = int(retries)
            continue

        row = next(reversed(rows), None)
        if row is None:
            continue

        if body.startswith("FRAME_VALID:"):
            match = re.search(r"FRAME_VALID:\s*(\d+)", body)
            if match:
                row.frame_valid = int(match.group(1))
        elif body.startswith("WR_STATE_BLOCK_VALID:"):
            match = re.search(r"WR_STATE_BLOCK_VALID:\s*(\d+)", body)
            if match:
                row.wr_state_block_valid = int(match.group(1))
        elif body.startswith("WDIAGS_DMS_H:"):
            values = dict(PAIR.findall(body))
            dms_hi = parse_u32_hex(values.get("WDIAGS_DMS_H", ""))
            dms_lo = parse_u32_hex(values.get("WDIAGS_DMS_L", ""))
            row.cko_raw = values.get("WDIAGS_CKO")
            if row.cko_raw:
                row.offset_ps = signed_u32(row.cko_raw)
            if dms_hi is not None and dms_lo is not None:
                row.dms_raw = (dms_hi << 32) | dms_lo
            row.setp_raw = parse_u32_hex(values.get("WDIAGS_SETP", ""))
            row.ucnt_raw = parse_u32_hex(values.get("WDIAGS_UCNT", ""))
        elif body.startswith("DECODE:"):
            values = dict(PAIR.findall(body))
            for key, attr in (
                ("servo_state", "servo_state"),
                ("sstat_wr_valid", "servo_state_valid"),
                ("link_up", "link_up"),
                ("spll_locked", "spll_locked"),
                ("time_valid", "time_valid"),
                ("pps_valid", "pps_valid"),
            ):
                if key in values and values[key].isdigit():
                    setattr(row, attr, int(values[key]))
        elif body.startswith("STEP5_LOCKDET:"):
            patterns = (
                (r"HELPER locked=(\d+)", "helper_locked"),
                (r"MAIN enabled=\d+ locked=(\d+)", "main_locked"),
                (r"MAIN .*? freq=(\d+)", "main_freq_locked"),
                (r"MAIN .*? phase=(\d+)", "main_phase_locked"),
                (r"PSTAT_locked=(\d+)", "pstat_locked"),
            )
            for pattern, attr in patterns:
                match = re.search(pattern, body)
                if match:
                    setattr(row, attr, int(match.group(1)))
        elif body.startswith("STEP5_SAMPLE_VALID:"):
            match = re.search(r"STEP5_SAMPLE_VALID:\s*(\d+)", body)
            if match:
                row.step5_sample_valid = int(match.group(1))

    return rows, exit_code, reader_errors


def summarize(rows: list[Row], exit_code: int | None, reader_errors: int) -> dict[str, object]:
    boards: dict[str, list[Row]] = {"DE5 [1-11.1]": [], "DE5 [1-11.2]": []}
    for row in rows:
        boards.setdefault(row.board, []).append(row)

    board_summary: dict[str, object] = {}
    for name, board_rows in boards.items():
        board_rows.sort(key=lambda row: (row.sample, row.attempt))
        accepted = [row for row in board_rows if row.accepted == 1]
        valid = [row for row in accepted if row.step5_sample_valid == 1]
        lock_keys = ("helper_locked", "main_freq_locked", "main_phase_locked", "main_locked", "pstat_locked")
        all_locks = [row for row in valid if all(getattr(row, key) == 1 for key in lock_keys)]
        offsets = [row.offset_ps for row in valid if row.offset_ps is not None and row.servo_state_valid == 1]
        states: dict[str, int] = {}
        transitions: list[dict[str, object]] = []
        prior_state: int | None = None
        for row in accepted:
            if row.servo_state is None or row.servo_state_valid != 1:
                continue
            states[STATE_NAMES.get(row.servo_state, f"UNKNOWN_{row.servo_state}")] = (
                states.get(STATE_NAMES.get(row.servo_state, f"UNKNOWN_{row.servo_state}"), 0) + 1
            )
            if row.servo_state != prior_state:
                transitions.append({
                    "sample": row.sample,
                    "timestamp": row.start.isoformat(),
                    "state": STATE_NAMES.get(row.servo_state, f"UNKNOWN_{row.servo_state}"),
                    "offset_ps": row.offset_ps,
                })
                prior_state = row.servo_state

        starts = [row.start for row in accepted]
        intervals_ms = [
            (right - left).total_seconds() * 1000
            for left, right in zip(starts, starts[1:])
        ]
        board_summary[name] = {
            "sample_rows": len(board_rows),
            "accepted_samples": len(accepted),
            "step5_valid_samples": len(valid),
            "full_frame_valid_samples": sum(row.frame_valid == 1 for row in accepted),
            "servo_state_valid_samples": sum(row.servo_state_valid == 1 for row in accepted),
            "all_five_lock_samples": len(all_locks),
            "valid_global_time_samples": sum(row.time_valid == 1 and row.pps_valid == 1 for row in valid),
            "first_sample_utc": accepted[0].start.isoformat() if accepted else None,
            "last_sample_utc": accepted[-1].start.isoformat() if accepted else None,
            "sample_start_span_seconds": round((accepted[-1].start - accepted[0].start).total_seconds(), 6) if len(accepted) > 1 else 0,
            "sample_interval_ms_median": round(statistics.median(intervals_ms), 3) if intervals_ms else None,
            "sample_interval_ms_min": round(min(intervals_ms), 3) if intervals_ms else None,
            "sample_interval_ms_max": round(max(intervals_ms), 3) if intervals_ms else None,
            "servo_state_samples": states,
            "servo_state_transitions": transitions,
            "phase_offset_samples": len(offsets),
            "phase_offset_strictly_under_60ps_samples": sum(abs(value) < 60 for value in offsets),
            "phase_offset_min_ps": min(offsets) if offsets else None,
            "phase_offset_max_ps": max(offsets) if offsets else None,
            "phase_offset_median_ps": statistics.median(offsets) if offsets else None,
            "phase_offset_ps_first_last": [offsets[0], offsets[-1]] if offsets else None,
            "distinct_dms_values": len({row.dms_raw for row in valid if row.dms_raw is not None}),
            "distinct_setp_values": len({row.setp_raw for row in valid if row.setp_raw is not None}),
            "ucnt_first_last": [
                next((row.ucnt_raw for row in valid if row.ucnt_raw is not None), None),
                next((row.ucnt_raw for row in reversed(valid) if row.ucnt_raw is not None), None),
            ],
        }

    return {
        "capture_process_exit": exit_code,
        "reader_error_lines": reader_errors,
        "total_sample_rows": len(rows),
        "boards": board_summary,
        "interpretation_limit": "Rows are sequential diagnostic reads, not atomic single-cycle snapshots.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture_log", type=Path)
    args = parser.parse_args()
    rows, exit_code, errors = parse_capture(args.capture_log.read_text(encoding="utf-8", errors="replace"))
    print(json.dumps(summarize(rows, exit_code, errors), indent=2))


if __name__ == "__main__":
    main()
