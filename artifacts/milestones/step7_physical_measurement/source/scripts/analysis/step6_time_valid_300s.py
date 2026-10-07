#!/usr/bin/env python3
"""Audit sampled 300-second Global-Time validity on both DE5a boards."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


GLOBAL_SAMPLE_PREFIX = "GLOBAL_TIME_SAMPLE "
INTERLEAVED_SAMPLE_PREFIX = "S6_INTERLEAVED_SAMPLE "
STEP1_FIELDS = (
    "STATUS_SI_CONFIG",
    "STATUS_PHY_READY",
    "STATUS_TM_LINK_UP",
    "STATUS_LINK_OK",
    "STATUS_RX_READY",
    "STATUS_TX_READY",
    "STATUS_CPU_RESET_N",
)
BOARD_RE = re.compile(r"\[([^\]]+)\]")


def _fields(line: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for token in line.split():
        if "=" in token:
            key, value = token.split("=", maxsplit=1)
            parsed[key] = value
    return parsed


def _board_id(line: str) -> str:
    match = BOARD_RE.search(line)
    return match.group(1) if match else "UNKNOWN"


def _is_one(row: dict[str, str], key: str) -> bool:
    return row.get(key) == "1"


def _analyze_board(board_id: str, sample_lines: list[str], done_lines: list[str],
                   *, required_duration_ms: int, requested_duration_ms: int,
                   max_sample_gap_ms: int, minimum_samples: int,
                   has_capture_error: bool) -> dict[str, Any]:
    rows = [_fields(line.split(" ", 1)[1]) for line in sample_lines]
    elapsed_values: list[int] = []
    malformed_rows: list[int] = []
    sequence_ok = True
    for index, row in enumerate(rows):
        try:
            elapsed_values.append(int(row["elapsed_ms"]))
            sequence_ok &= int(row["sample"]) == index
        except (KeyError, ValueError):
            malformed_rows.append(index)
            sequence_ok = False

    gaps = [right - left for left, right in zip(elapsed_values, elapsed_values[1:])]
    invalid_rows = list(malformed_rows)
    for index, row in enumerate(rows):
        if not _is_one(row, "STATUS_TIME_VALID") and index not in invalid_rows:
            invalid_rows.append(index)

    done_elapsed: list[int] = []
    for line in done_lines:
        try:
            done_elapsed.append(int(_fields(line)["elapsed_ms"]))
        except (KeyError, ValueError):
            pass
    observed_span = elapsed_values[-1] - elapsed_values[0] if len(elapsed_values) > 1 else 0
    capture_elapsed = done_elapsed[-1] if done_elapsed else 0
    board_identity_ok = (
        bool(sample_lines)
        and all(_board_id(line) == board_id for line in sample_lines)
        and len(done_lines) == 1
        and _board_id(done_lines[0]) == board_id
    )
    try:
        done_samples_match = int(_fields(done_lines[-1])["samples"]) == len(rows)
    except (IndexError, KeyError, ValueError):
        done_samples_match = False

    timing_ok = (
        len(elapsed_values) == len(rows)
        and observed_span >= required_duration_ms
        and capture_elapsed >= required_duration_ms
        and not any(gap <= 0 or gap > max_sample_gap_ms for gap in gaps)
    )
    complete = (
        bool(rows)
        and board_identity_ok
        and not has_capture_error
        and requested_duration_ms >= required_duration_ms
        and len(rows) >= minimum_samples
        and done_samples_match
        and sequence_ok
        and timing_ok
    )

    live_values: list[int] = []
    for row in rows:
        try:
            live_values.append((int(row["LIVE_TAI_LO"]) << 28) | int(row["LIVE_CYCLES"]))
        except (KeyError, ValueError):
            live_values = []
            break
    live_time_monotonic = bool(live_values) and all(
        right >= left for left, right in zip(live_values, live_values[1:])
    ) and live_values[-1] > live_values[0]

    return {
        "board_id": board_id,
        "verdict": "PASS_TIME_VALID_300S" if complete and not invalid_rows
        else "TIME_VALID_300S_NOT_ESTABLISHED",
        "capture_complete": complete,
        "required_duration_ms": required_duration_ms,
        "requested_duration_ms": requested_duration_ms,
        "observed_sample_span_ms": observed_span,
        "capture_elapsed_ms": capture_elapsed,
        "sample_rows": len(rows),
        "minimum_samples": minimum_samples,
        "max_sample_gap_ms": max(gaps) if gaps else None,
        "gap_limit_ms": max_sample_gap_ms,
        "time_valid_rows": sum(_is_one(row, "STATUS_TIME_VALID") for row in rows),
        "invalid_row_count": len(invalid_rows),
        "first_invalid_rows": invalid_rows[:50],
        "snapshot_time_valid_rows": sum(
            _is_one(row, "SNAPSHOT_TIME_VALID") or _is_one(row, "GLOBAL_TIME_VALID")
            for row in rows
        ),
        "snapshot_valid_rows": sum(
            _is_one(row, "SNAPSHOT_VALID") or _is_one(row, "SNAPSHOT_STABLE")
            for row in rows
        ),
        "pps_valid_rows": sum(_is_one(row, "STATUS_PPS_VALID") for row in rows),
        "step1_link_ready_rows": sum(
            all(_is_one(row, key) for key in STEP1_FIELDS) for row in rows
        ),
        "live_time_monotonic": live_time_monotonic,
        "done_sample_count_matches": done_samples_match,
        "sample_sequence_ok": sequence_ok,
        "board_identity_valid": board_identity_ok,
        "done_records": done_lines,
    }


def analyze_text(text: str, *, required_duration_ms: int = 300_000,
                 max_sample_gap_ms: int = 1_000,
                 minimum_samples: int = 301,
                 required_boards: tuple[str, ...] = ("1-11.1", "1-11.2")) -> dict[str, Any]:
    lines = text.splitlines()
    if any(line.startswith(GLOBAL_SAMPLE_PREFIX) for line in lines):
        config_prefix = "GLOBAL_TIME_CONFIG "
        done_prefix = "GLOBAL_TIME_DONE "
        sample_prefix = GLOBAL_SAMPLE_PREFIX
        error_prefix = "GLOBAL_TIME_ERROR "
    else:
        config_prefix = "S6_INTERLEAVED_CONFIG "
        done_prefix = "S6_INTERLEAVED_BOARD_DONE "
        sample_prefix = INTERLEAVED_SAMPLE_PREFIX
        error_prefix = "S6_INTERLEAVED_ERROR "

    config_line = next((line for line in lines if line.startswith(config_prefix)), "")
    config = _fields(config_line)
    sample_lines = [line for line in lines if line.startswith(sample_prefix)]
    done_lines = [line for line in lines if line.startswith(done_prefix)]
    errors = [line for line in lines if line.startswith(error_prefix)]
    try:
        requested_duration = int(config.get("duration_ms", "0"))
    except ValueError:
        requested_duration = 0

    samples_by_board: dict[str, list[str]] = {}
    done_by_board: dict[str, list[str]] = {}
    for line in sample_lines:
        samples_by_board.setdefault(_board_id(line), []).append(line)
    for line in done_lines:
        done_by_board.setdefault(_board_id(line), []).append(line)

    discovered_boards = sorted(set(samples_by_board) | set(done_by_board))
    board_reports = {
        board_id: _analyze_board(
            board_id,
            samples_by_board.get(board_id, []),
            done_by_board.get(board_id, []),
            required_duration_ms=required_duration_ms,
            requested_duration_ms=requested_duration,
            max_sample_gap_ms=max_sample_gap_ms,
            minimum_samples=minimum_samples,
            has_capture_error=any(board_id in line for line in errors),
        )
        for board_id in required_boards
    }

    configured_filter = config.get("board_filter", "")
    filter_matches = not configured_filter or all(
        configured_filter in board_id for board_id in required_boards
    )
    exact_board_set = set(discovered_boards) == set(required_boards)
    all_boards_pass = bool(required_boards) and all(
        report["verdict"] == "PASS_TIME_VALID_300S"
        for report in board_reports.values()
    )
    capture_complete = (
        len(board_reports) == len(required_boards)
        and exact_board_set
        and filter_matches
        and not errors
        and all(report["capture_complete"] for report in board_reports.values())
    )
    passed = capture_complete and all_boards_pass

    return {
        "verdict": "PASS_TIME_VALID_300S" if passed else "TIME_VALID_300S_NOT_ESTABLISHED",
        "capture_complete": capture_complete,
        "required_duration_ms": required_duration_ms,
        "required_boards": list(required_boards),
        "discovered_boards": discovered_boards,
        "requested_duration_ms": requested_duration,
        "acceptance_signal": "STATUS_TIME_VALID",
        "snapshot_pps_link_locks_tai_cycles_and_phase_are_diagnostic_only": True,
        "boards_observed_sequentially": True,
        "capture_errors": errors,
        "boards": board_reports,
    }


def analyze_file(path: Path, **kwargs: Any) -> dict[str, Any]:
    return analyze_text(path.read_text(encoding="utf-8", errors="replace"), **kwargs)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--required-duration-ms", type=int, default=300_000)
    parser.add_argument("--max-sample-gap-ms", type=int, default=1_000)
    parser.add_argument("--minimum-samples", type=int, default=301)
    parser.add_argument("--boards", default="1-11.1,1-11.2",
                        help="comma-separated board IDs that must each pass")
    args = parser.parse_args()
    required_boards = tuple(board.strip() for board in args.boards.split(",") if board.strip())
    result = analyze_file(
        args.capture,
        required_duration_ms=args.required_duration_ms,
        max_sample_gap_ms=args.max_sample_gap_ms,
        minimum_samples=args.minimum_samples,
        required_boards=required_boards,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["verdict"] != "PASS_TIME_VALID_300S":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
