#!/usr/bin/env python3
"""Analyze the fresh-Slave RX word-align acquisition observer."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SAMPLE_RE = re.compile(r"^WORDALIGN_SAMPLE\s+(?P<body>.*)$")
FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
BOARD_RE = re.compile(r"\bBOARD=(?P<board>DE5\s+\[[^\]]+\])\s+SAMPLE=")
INVALID = {"", "INVALID", "TIMEOUT", "NA", "N/A", "UNKNOWN", "DECREASED"}


def parse_samples(text: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = SAMPLE_RE.match(line.strip())
        if not match:
            continue
        row: dict[str, Any] = {}
        for key, value in FIELD_RE.findall(match.group("body")):
            try:
                row[key.upper()] = int(value, 0)
            except ValueError:
                try:
                    row[key.upper()] = int(value, 10)
                except ValueError:
                    row[key.upper()] = value
        board = BOARD_RE.search(line)
        if board:
            row["BOARD"] = board.group("board")
        rows.append(row)
    return rows


def integer(row: dict[str, Any], key: str, default: int | None = None) -> int | None:
    value = row.get(key)
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if not isinstance(value, str) or value.upper() in INVALID:
        return default
    try:
        return int(value, 0)
    except ValueError:
        try:
            return int(value, 10)
        except ValueError:
            return default


def reset_signature(row: dict[str, Any]) -> tuple[Any, ...]:
    return tuple(row.get(key) for key in (
        "BOOT_GENERATION", "CPU_RESET_COUNT", "WR_CORE_RESET_COUNT",
        "SI_CONFIG_DROP_COUNT",
    ))


def max_streak(rows: list[dict[str, Any]], key: str, value: int = 1) -> int:
    best = current = 0
    for row in rows:
        if integer(row, key, 0) == value:
            current += 1
            best = max(best, current)
        else:
            current = 0
    return best


def analyze_master(rows: list[dict[str, Any]], source: str) -> dict[str, Any]:
    errors = sum(1 for row in rows if integer(row, "READ_VALID", 0) != 1)
    resets = sum(
        1 for old, new in zip(rows, rows[1:])
        if reset_signature(old) != reset_signature(new)
    )
    required = (
        "SI_CONFIG_DONE", "WR_READY", "TX_READY", "CPU_RESET_N",
        "PHY_RST", "PHY_TX_DISABLE", "PTP_STATE",
    )
    good = [
        all(integer(row, key, -1) == (0 if key in {"PHY_RST", "PHY_TX_DISABLE"} else (6 if key == "PTP_STATE" else 1))
            for key in required)
        for row in rows
    ]
    passed = bool(rows) and not errors and not resets and len(rows) >= 5 and all(good)
    return {
        "format": "step6-slave-rx-word-align-fresh-acquisition-v1",
        "mode": "master-precondition",
        "source": source,
        "board": rows[0].get("BOARD", "UNKNOWN") if rows else "UNKNOWN",
        "sample_count": len(rows),
        "valid_samples": len(rows) - errors,
        "transport_errors": errors,
        "reset_changes": resets,
        "master_tx_precondition": "PASS" if passed else "FAIL_OR_INCONCLUSIVE",
        "pass": passed,
        "rows": rows,
    }


def analyze_word_align(rows: list[dict[str, Any]], source: str) -> dict[str, Any]:
    errors = sum(1 for row in rows if integer(row, "READ_VALID", 0) != 1)
    resets = sum(
        1 for old, new in zip(rows, rows[1:])
        if reset_signature(old) != reset_signature(new)
    )
    local_ready = any(integer(row, "LOCAL_READY_PASS", 0) == 1 for row in rows)
    max_elapsed_ms = max((integer(row, "TIMESTAMP_MS", 0) or 0 for row in rows), default=0)
    observation_window_complete = max_elapsed_ms >= 10000
    pass_row = next(
        (row for row in rows if integer(row, "ALIGNMENT_STREAK", 0) >= 5), None
    )
    stop_candidates = [
        row.get("STOP_CANDIDATE") for row in rows
        if row.get("STOP_CANDIDATE") not in (None, "NONE")
    ]
    preliminary_failure_class: str | None = None
    if not rows or errors:
        classification = "INCONCLUSIVE_TRANSPORT"
    elif resets:
        classification = "INCONCLUSIVE_RESET"
    elif pass_row is not None:
        classification = "PASS_WORD_ALIGN_ACQUISITION"
    else:
        candidate = stop_candidates[-1] if stop_candidates else "INCONCLUSIVE_MAX_CAPTURE"
        if (not any(integer(row, "SYNC_SEEN", 0) == 1 for row in rows)
                and not any(integer(row, "PATTERN_SEEN", 0) == 1 for row in rows)
                and any(integer(row, "ERROR_SEEN", 0) == 1 for row in rows)):
            preliminary_failure_class = "FAIL_RX_WORD_ALIGNMENT_WITH_8B10B_ERRORS"
            classification = (preliminary_failure_class
                              if observation_window_complete
                              else "INCONCLUSIVE_OBSERVATION_WINDOW_SHORT")
        elif candidate in {
            "FAIL_SLAVE_PHY_LOCAL_READY",
            "FAIL_RX_CDR_OR_RECOVERED_CLOCK_REGRESSION",
            "FAIL_RX_WORD_ALIGNMENT_LOSS",
            "FAIL_RX_WORD_ALIGNMENT_WITH_8B10B_ERRORS",
            "INCONCLUSIVE_COUNTER_BASELINE",
        }:
            classification = candidate
        elif not local_ready:
            classification = "FAIL_SLAVE_PHY_LOCAL_READY"
        else:
            classification = "INCONCLUSIVE_MAX_CAPTURE"

    error_delta_keys = (
        "ENC_ERR_DELTA", "DISPERR_DELTA", "ERRDETECT_DELTA",
        "SYNC_LOSS_DELTA",
    )
    error_delta_seen = any(
        (integer(row, key, 0) or 0) > 0
        for row in rows for key in error_delta_keys
    )
    activity_values = [integer(row, "RX_CLOCK_ACTIVITY") for row in rows]
    activity_values = [value for value in activity_values if value is not None and value >= 0]
    return {
        "format": "step6-slave-rx-word-align-fresh-acquisition-v1",
        "mode": "word-align",
        "source": source,
        "board": rows[0].get("BOARD", "UNKNOWN") if rows else "UNKNOWN",
        "sample_count": len(rows),
        "valid_samples": len(rows) - errors,
        "transport_errors": errors,
        "reset_changes": resets,
        "local_ready_pass": local_ready,
        "classification": classification,
        "word_align_acquisition": "PASS" if classification == "PASS_WORD_ALIGN_ACQUISITION" else "FAIL" if classification.startswith("FAIL_") else "INCONCLUSIVE",
        "recovered_rx_clock_activity": "PRESENT" if len(set(activity_values)) >= 2 else "NOT_PROVEN",
        "eightbtenb_error_delta_seen": error_delta_seen,
        "max_alignment_streak": max((integer(row, "ALIGNMENT_STREAK", 0) or 0 for row in rows), default=0),
        "max_elapsed_ms": max_elapsed_ms,
        "observation_window_complete": observation_window_complete,
        "preliminary_failure_class": preliminary_failure_class,
        "max_local_ready_streak": max((integer(row, "LOCAL_READY_STREAK", 0) or 0 for row in rows), default=0),
        "max_rx_no_lock_streak": max((integer(row, "RX_NO_LOCK_STREAK", 0) or 0 for row in rows), default=0),
        "max_rx_no_activity_streak": max((integer(row, "RX_NO_ACTIVITY_STREAK", 0) or 0 for row in rows), default=0),
        "sync_seen": any(integer(row, "SYNC_SEEN", 0) == 1 for row in rows),
        "pattern_seen": any(integer(row, "PATTERN_SEEN", 0) == 1 for row in rows),
        "error_seen": any(integer(row, "ERROR_SEEN", 0) == 1 for row in rows),
        "stop_candidates": stop_candidates,
        "step6a": "NOT_PASS",
        "step6b": "NOT_RUN",
        "rows": rows,
    }


def analyze_text(text: str, source: str = "", mode: str = "word-align") -> dict[str, Any]:
    rows = parse_samples(text)
    if mode == "master-precondition":
        return analyze_master(rows, source)
    return analyze_word_align(rows, source)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--mode", choices=("master-precondition", "word-align"), default="word-align")
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_text(args.input.read_text(encoding="utf-8", errors="replace"), str(args.input), args.mode)
    encoded = json.dumps({key: value for key, value in result.items() if key != "rows"}, indent=2, ensure_ascii=False)
    if args.json_out:
        args.json_out.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
