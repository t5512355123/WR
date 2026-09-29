#!/usr/bin/env python3
"""Audit a read-only Step 6 dashboard-equivalent interleaved capture."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SAMPLE_PREFIX = "S6_INTERLEAVED_SAMPLE "
STEP1_FIELDS = (
    "STATUS_SI_CONFIG_DONE",
    "STATUS_WR_READY",
    "STATUS_TM_LINK",
    "STATUS_LINK_OK",
    "STATUS_RX_READY",
    "STATUS_TX_READY",
    "STATUS_CPU_RESET_N",
    "STATUS_RX_LOCKED_TO_DATA",
)
LOCK_FIELDS = (
    "HELPER_LOCK",
    "MAIN_FREQ_LOCK",
    "MAIN_PHASE_LOCK",
    "MAIN_LOCK",
    "PSTAT_LOCK",
)


def _parse_fields(line: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for token in line.split():
        if "=" not in token:
            continue
        key, value = token.split("=", maxsplit=1)
        fields[key] = value
    return fields


def _is_one(row: dict[str, str], key: str) -> bool:
    return row.get(key) == "1"


def _step1_gate(row: dict[str, str]) -> bool:
    return _is_one(row, "STEP1_GATE") and all(_is_one(row, key) for key in STEP1_FIELDS)


def _all_locks(row: dict[str, str]) -> bool:
    return all(_is_one(row, key) for key in LOCK_FIELDS)


def _qualifies(row: dict[str, str]) -> bool:
    try:
        offset_ps = int(row["CKO_PS"])
    except (KeyError, ValueError):
        return False

    return (
        _is_one(row, "READS_VALID")
        and _is_one(row, "COHERENT")
        and _is_one(row, "GLOBAL_TIME_VALID")
        and _is_one(row, "SNAPSHOT_VALID")
        and _is_one(row, "SNAPSHOT_STABLE")
        and _is_one(row, "STATUS_TIME_VALID")
        and _is_one(row, "STATUS_PPS_VALID")
        and _is_one(row, "ESCR_TIME_VALID")
        and _is_one(row, "ESCR_PPS_VALID")
        and _step1_gate(row)
        and _all_locks(row)
        and _is_one(row, "DIAG_FRAME_VALID")
        and _is_one(row, "DIAG_EPOCH_STABLE")
        and _is_one(row, "PHASE_CONTEXT_VALID")
        and _is_one(row, "PHASE_CONTEXT_FRAME_VALID")
        and _is_one(row, "PHASE_CONTEXT_MATCH")
        and row.get("RESET_CHANGED") == "0"
        and abs(offset_ps) < 60
    )


def analyze_text(text: str) -> dict[str, Any]:
    rows = [
        _parse_fields(line[len(SAMPLE_PREFIX) :])
        for line in text.splitlines()
        if line.startswith(SAMPLE_PREFIX)
    ]
    config_line = next(
        (line for line in text.splitlines() if line.startswith("S6_INTERLEAVED_CONFIG ")),
        "",
    )
    board_done_line = next(
        (line for line in text.splitlines() if line.startswith("S6_INTERLEAVED_BOARD_DONE ")),
        "",
    )
    summary_line = next(
        (line for line in text.splitlines() if line.startswith("S6_INTERLEAVED_SUMMARY ")),
        "",
    )
    config = _parse_fields(config_line)
    board_done = _parse_fields(board_done_line)
    summary = _parse_fields(summary_line)

    qualified_indexes = [index for index, row in enumerate(rows) if _qualifies(row)]
    marker_indexes = [
        index for index, row in enumerate(rows) if _is_one(row, "QUALIFYING_SAMPLE")
    ]
    marker_mismatches = [
        index
        for index, row in enumerate(rows)
        if _is_one(row, "QUALIFYING_SAMPLE") != _qualifies(row)
    ]

    longest_run = 0
    current_run: list[int] = []
    longest_indexes: list[int] = []
    for index in range(len(rows)):
        if index in qualified_indexes:
            if current_run and index != current_run[-1] + 1:
                current_run = []
            current_run.append(index)
            if len(current_run) > longest_run:
                longest_run = len(current_run)
                longest_indexes = list(current_run)
        else:
            current_run = []

    valid_offset_values: list[int] = []
    for row in rows:
        if not _is_one(row, "READS_VALID"):
            continue
        try:
            valid_offset_values.append(int(row["CKO_PS"]))
        except (KeyError, ValueError):
            continue

    def count(predicate: Any) -> int:
        return sum(1 for row in rows if predicate(row))

    qualifying_samples: list[dict[str, Any]] = []
    for index in qualified_indexes:
        row = rows[index]
        qualifying_samples.append(
            {
                "sample": row.get("sample"),
                "elapsed_ms": int(row["elapsed_ms"]),
                "cko_ps": int(row["CKO_PS"]),
                "servo_state": int(row["SERVO_STATE"]),
                "tai": row.get("TAI"),
                "cycles": row.get("CYCLES"),
                "ucnt": row.get("UCNT"),
            }
        )

    capture_duration_ms = int(board_done.get("elapsed_ms", "0"))
    expected_duration_ms = int(config.get("duration_ms", "0"))
    summary_consistent = (
        summary.get("rows") == str(len(rows))
        and summary.get("accepted") == str(count(lambda row: _is_one(row, "COHERENT")))
        and summary.get("qualifying") == str(len(marker_indexes))
    )
    read_only_contract = (
        config.get("read_only") == "1"
        and config.get("wb_register_writes") == "0"
        and config.get("fpga_program") == "0"
        and config.get("reset") == "0"
    )
    no_stop_or_read_errors = (
        board_done.get("reset_stop") == "0"
        and summary.get("reset_stop") == "0"
        and summary.get("timeout_count") == "0"
        and summary.get("invalid_count") == "0"
    )
    capture_complete = (
        "S6_INTERLEAVED_DONE" in text
        and bool(board_done_line)
        and expected_duration_ms > 0
        and capture_duration_ms >= expected_duration_ms
        and summary_consistent
        and read_only_contract
        and no_stop_or_read_errors
    )
    marker_consistent = not marker_mismatches
    pointwise_pass = capture_complete and marker_consistent and bool(qualified_indexes)

    consecutive_sample_span_ms: int | None = None
    if len(longest_indexes) > 1:
        start = rows[longest_indexes[0]]
        end = rows[longest_indexes[-1]]
        consecutive_sample_span_ms = int(end["elapsed_ms"]) - int(start["elapsed_ms"])

    return {
        "capture_complete": capture_complete,
        "read_only_contract": read_only_contract,
        "no_stop_or_read_errors": no_stop_or_read_errors,
        "expected_duration_ms": expected_duration_ms,
        "observed_duration_ms": capture_duration_ms,
        "sample_rows": len(rows),
        "read_valid_rows": count(lambda row: _is_one(row, "READS_VALID")),
        "diagnostic_frame_valid_rows": count(lambda row: _is_one(row, "DIAG_FRAME_VALID")),
        "global_time_valid_rows": count(lambda row: _is_one(row, "GLOBAL_TIME_VALID")),
        "stable_snapshot_rows": count(
            lambda row: _is_one(row, "SNAPSHOT_VALID") and _is_one(row, "SNAPSHOT_STABLE")
        ),
        "all_step1_status_rows": count(_step1_gate),
        "all_five_lock_rows": count(_all_locks),
        "phase_context_ucnt_match_rows": count(
            lambda row: _is_one(row, "PHASE_CONTEXT_MATCH")
        ),
        "coherent_accepted_rows": count(lambda row: _is_one(row, "COHERENT")),
        "strict_offset_rows_abs_lt_60_ps": sum(
            1 for offset in valid_offset_values if abs(offset) < 60
        ),
        "valid_offset_min_ps": min(valid_offset_values) if valid_offset_values else None,
        "valid_offset_max_ps": max(valid_offset_values) if valid_offset_values else None,
        "observer_qualifying_rows": len(marker_indexes),
        "independently_qualified_rows": len(qualified_indexes),
        "qualification_marker_mismatches": marker_mismatches,
        "longest_consecutive_qualified_rows": longest_run,
        "consecutive_sample_span_ms": consecutive_sample_span_ms,
        "qualifying_samples": qualifying_samples,
        "reset_changed_rows": count(lambda row: row.get("RESET_CHANGED") != "0"),
        "observer_summary_consistent": summary_consistent,
        "pointwise_verdict": "STEP6_POINTWISE_GATE_PASS"
        if pointwise_pass
        else "STEP6_POINTWISE_GATE_NOT_ESTABLISHED",
        "sustained_300s_offset_stability": "NOT_ESTABLISHED",
    }


def analyze_file(path: Path) -> dict[str, Any]:
    return analyze_text(path.read_text(encoding="utf-8", errors="replace"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path, help="raw S6_INTERLEAVED capture log")
    args = parser.parse_args()
    print(json.dumps(analyze_file(args.capture), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
