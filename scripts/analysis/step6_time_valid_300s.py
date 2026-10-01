#!/usr/bin/env python3
"""Audit a 300-second, read-only Step 6 Global-Time validity capture."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SAMPLE_PREFIX = "GLOBAL_TIME_SAMPLE "
REQUIRED_ONE_FIELDS = (
    "STABLE",
    "SNAPSHOT_VALID",
    "SNAPSHOT_TIME_VALID",
    "STATUS_TIME_VALID",
)
STEP1_FIELDS = (
    "STATUS_SI_CONFIG",
    "STATUS_PHY_READY",
    "STATUS_TM_LINK_UP",
    "STATUS_LINK_OK",
    "STATUS_RX_READY",
    "STATUS_TX_READY",
    "STATUS_CPU_RESET_N",
)


def _fields(line: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for token in line.split():
        if "=" in token:
            key, value = token.split("=", maxsplit=1)
            parsed[key] = value
    return parsed


def _is_one(row: dict[str, str], key: str) -> bool:
    return row.get(key) == "1"


def analyze_text(text: str, *, required_duration_ms: int = 300_000,
                 max_sample_gap_ms: int = 1_000,
                 minimum_samples: int = 301) -> dict[str, Any]:
    lines = text.splitlines()
    config_line = next(
        (line for line in lines if line.startswith("GLOBAL_TIME_CONFIG ")), ""
    )
    done_lines = [line for line in lines if line.startswith("GLOBAL_TIME_DONE ")]
    rows = [
        _fields(line[len(SAMPLE_PREFIX):])
        for line in lines
        if line.startswith(SAMPLE_PREFIX)
    ]
    config = _fields(config_line)
    sample_lines = [line for line in lines if line.startswith(SAMPLE_PREFIX)]
    elapsed_values: list[int] = []
    invalid_rows: list[int] = []
    sample_sequence_ok = True
    for index, row in enumerate(rows):
        try:
            elapsed_values.append(int(row["elapsed_ms"]))
            sample_sequence_ok &= int(row["sample"]) == index
        except (KeyError, ValueError):
            invalid_rows.append(index)
            sample_sequence_ok = False

    gaps = [right - left for left, right in zip(elapsed_values, elapsed_values[1:])]
    for index, row in enumerate(rows):
        try:
            valid_tuple = all(_is_one(row, key) for key in REQUIRED_ONE_FIELDS)
            int(row["TAI"])
            int(row["CYCLES"])
            int(row["SNAPSHOT_COUNT"])
            int(row["SNAPSHOT_PPS_VALID"])
            int(row["STATUS_PPS_VALID"])
            for key in STEP1_FIELDS:
                int(row[key])
        except (KeyError, ValueError):
            valid_tuple = False
        if not valid_tuple and index not in invalid_rows:
            invalid_rows.append(index)

    done_elapsed: list[int] = []
    for line in done_lines:
        try:
            done_elapsed.append(int(_fields(line)["elapsed_ms"]))
        except (KeyError, ValueError):
            pass
    requested_duration = int(config.get("duration_ms", "0"))
    observed_span = elapsed_values[-1] - elapsed_values[0] if len(elapsed_values) > 1 else 0
    capture_elapsed = done_elapsed[-1] if done_elapsed else 0
    board_identity_rows = sum("[1-11.2]" in line for line in sample_lines)
    done_identity = bool(done_lines) and all("[1-11.2]" in line for line in done_lines)
    try:
        done_samples_match = int(_fields(done_lines[-1])["samples"]) == len(rows)
    except (IndexError, KeyError, ValueError):
        done_samples_match = False
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
    timing_ok = (
        len(elapsed_values) == len(rows)
        and observed_span >= required_duration_ms
        and capture_elapsed >= required_duration_ms
        and not any(gap <= 0 or gap > max_sample_gap_ms for gap in gaps)
    )
    complete = (
        bool(rows)
        and len(done_lines) == 1
        and not any(line.startswith("GLOBAL_TIME_ERROR ") for line in lines)
        and requested_duration >= required_duration_ms
        and config.get("board_filter") == "1-11.2"
        and len(rows) >= minimum_samples
        and board_identity_rows == len(rows)
        and done_identity
        and done_samples_match
        and sample_sequence_ok
        and timing_ok
        and live_time_monotonic
    )
    pass_300s = complete and not invalid_rows

    return {
        "verdict": "PASS_TIME_VALID_300S" if pass_300s else "TIME_VALID_300S_NOT_ESTABLISHED",
        "capture_complete": complete,
        "required_duration_ms": required_duration_ms,
        "requested_duration_ms": requested_duration,
        "observed_sample_span_ms": observed_span,
        "capture_elapsed_ms": capture_elapsed,
        "sample_rows": len(rows),
        "minimum_samples": minimum_samples,
        "max_sample_gap_ms": max(gaps) if gaps else None,
        "gap_limit_ms": max_sample_gap_ms,
        "valid_rows": len(rows) - len(invalid_rows),
        "invalid_rows": invalid_rows,
        "time_valid_rows": sum(_is_one(row, "STATUS_TIME_VALID") for row in rows),
        "snapshot_time_valid_rows": sum(
            _is_one(row, "SNAPSHOT_TIME_VALID") for row in rows
        ),
        "pps_valid_rows": sum(_is_one(row, "STATUS_PPS_VALID") for row in rows),
        "snapshot_pps_valid_rows": sum(
            _is_one(row, "SNAPSHOT_PPS_VALID") for row in rows
        ),
        "snapshot_valid_rows": sum(_is_one(row, "SNAPSHOT_VALID") for row in rows),
        "step1_link_ready_rows": sum(
            all(_is_one(row, key) for key in STEP1_FIELDS) for row in rows
        ),
        "cpu_reset_released_rows": sum(
            _is_one(row, "STATUS_CPU_RESET_N") for row in rows
        ),
        "slave_board_identity_rows": board_identity_rows,
        "done_board_identity_valid": done_identity,
        "done_sample_count_matches": done_samples_match,
        "sample_sequence_ok": sample_sequence_ok,
        "live_time_monotonic": live_time_monotonic,
        "global_time_errors": [line for line in lines if line.startswith("GLOBAL_TIME_ERROR ")],
        "done_records": done_lines,
        "phase_offset_is_not_a_gate": True,
    }


def analyze_file(path: Path, **kwargs: Any) -> dict[str, Any]:
    return analyze_text(path.read_text(encoding="utf-8", errors="replace"), **kwargs)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--required-duration-ms", type=int, default=300_000)
    parser.add_argument("--max-sample-gap-ms", type=int, default=1_000)
    parser.add_argument("--minimum-samples", type=int, default=301)
    args = parser.parse_args()
    result = analyze_file(
        args.capture,
        required_duration_ms=args.required_duration_ms,
        max_sample_gap_ms=args.max_sample_gap_ms,
        minimum_samples=args.minimum_samples,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["verdict"] != "PASS_TIME_VALID_300S":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
