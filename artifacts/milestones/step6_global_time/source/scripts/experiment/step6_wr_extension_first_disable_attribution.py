"""Offline decoder for EXP-S6-WR-EXTENSION-FIRST-DISABLE-ATTRIBUTION."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


_SAMPLE_RE = re.compile(r"^EXTDISABLE_SAMPLE\s+(?P<body>.*)$")
_FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
_BOARD_RE = re.compile(r"\bboard=(?P<board>DE5\s+\[[^\]]+\])\s+sample=")


def _value(value: str) -> int | str:
    try:
        return int(value, 0)
    except ValueError:
        try:
            return int(value, 10)
        except ValueError:
            return value


def parse_samples(text: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = _SAMPLE_RE.match(line.strip())
        if not match:
            continue
        row = {
            key.upper(): _value(value)
            for key, value in _FIELD_RE.findall(match.group("body"))
        }
        board = _BOARD_RE.search(line)
        if board:
            row["BOARD"] = board.group("board")
        rows.append(row)
    return rows


def _int(row: dict[str, Any], key: str, default: int = -1) -> int:
    value = row.get(key, default)
    return value if isinstance(value, int) else default


def _max_streak(rows: list[dict[str, Any]], predicate) -> int:
    current = maximum = 0
    for row in rows:
        if predicate(row):
            current += 1
            maximum = max(maximum, current)
        else:
            current = 0
    return maximum


def _board_result(rows: list[dict[str, Any]]) -> dict[str, Any]:
    if not rows:
        return {
            "classification": "NO_SAMPLES",
            "diagnostic_pass": False,
            "sample_count": 0,
        }

    transport_valid = all(_int(row, "READ_VALID") == 1 for row in rows)
    reset_changed = any(
        _int(row, "BOOT_CHANGED") == 1 or _int(row, "RESET_CHANGED") == 1
        for row in rows
    )
    record_changed = any(_int(row, "RECORD_CHANGED") == 1 for row in rows)
    stop_reasons = [
        str(row.get("STOP_CANDIDATE"))
        for row in rows
        if str(row.get("STOP_CANDIDATE", "NONE")) != "NONE"
    ]
    stop_reason = stop_reasons[0] if stop_reasons else "TIME_LIMIT_OR_CAPTURE_END"

    protocol_streak = _max_streak(
        rows, lambda row: _int(row, "WR_DISABLE_VALID") == 1
        and _int(row, "WR_DISABLE_CAUSE") == 1
    )
    handshake_streak = _max_streak(
        rows, lambda row: _int(row, "WR_DISABLE_VALID") == 1
        and _int(row, "WR_DISABLE_CAUSE") == 2
        and 1 <= _int(row, "WR_FAILURE_REASON") <= 7
    )
    other_streak = _max_streak(
        rows, lambda row: _int(row, "WR_DISABLE_VALID") == 1
        and _int(row, "WR_DISABLE_CAUSE") == 0
    )
    contract_streak = _max_streak(
        rows, lambda row: _int(row, "WR_DISABLE_VALID") == 0
        and _int(row, "PD_STATE") == 4
        and _int(row, "EXT_STATE") == 2
    )

    if not transport_valid:
        classification = "INCONCLUSIVE_TRANSPORT"
        diagnostic_pass = False
    elif reset_changed:
        classification = "INCONCLUSIVE_RESET"
        diagnostic_pass = False
    elif record_changed:
        classification = "INCONCLUSIVE_RECORD_CHANGED"
        diagnostic_pass = False
    elif protocol_streak >= 3:
        classification = "PASS_PROTOCOL_TIMEOUT"
        diagnostic_pass = True
    elif handshake_streak >= 3:
        reason = _int(rows[-1], "WR_FAILURE_REASON")
        classification = f"PASS_HANDSHAKE_{rows[-1].get('WR_FAILURE_REASON_NAME', reason)}"
        diagnostic_pass = True
    elif other_streak >= 3:
        classification = "INCONCLUSIVE_OTHER_CALLER"
        diagnostic_pass = False
    elif contract_streak >= 3:
        classification = "FAIL_DIAGNOSTIC_CONTRACT"
        diagnostic_pass = False
    else:
        classification = "INCONCLUSIVE_NO_STABLE_FIRST_DISABLE_CLASS"
        diagnostic_pass = False

    return {
        "classification": classification,
        "diagnostic_pass": diagnostic_pass,
        "sample_count": len(rows),
        "transport_valid": transport_valid,
        "reset_changed": reset_changed,
        "record_changed": record_changed,
        "protocol_timeout_streak_max": protocol_streak,
        "handshake_failure_streak_max": handshake_streak,
        "other_caller_streak_max": other_streak,
        "diagnostic_contract_failure_streak_max": contract_streak,
        "stop_reason": stop_reason,
        "first_disable_valid": _int(rows[0], "WR_DISABLE_VALID"),
        "first_disable_cause": _int(rows[0], "WR_DISABLE_CAUSE"),
        "first_disable_cause_name": rows[0].get("WR_DISABLE_CAUSE_NAME", "UNKNOWN"),
        "first_failure_reason": _int(rows[0], "WR_FAILURE_REASON"),
        "first_failure_reason_name": rows[0].get("WR_FAILURE_REASON_NAME", "UNKNOWN"),
        "pre_disable_pd_state": _int(rows[0], "WR_DISABLE_PD_STATE"),
        "pre_disable_ext_state": _int(rows[0], "WR_DISABLE_EXT_STATE"),
        "current_pd_state": _int(rows[-1], "PD_STATE"),
        "current_ext_state": _int(rows[-1], "EXT_STATE"),
        "current_wr_state": _int(rows[-1], "WR_STATE_VALUE"),
        "step5_helper_locked_last": _int(rows[-1], "HELPER_LOCKED"),
        "step5_pstat_locked_last": _int(rows[-1], "PSTAT_LOCKED"),
    }


def analyze_text(text: str) -> dict[str, Any]:
    rows = parse_samples(text)
    grouped: dict[str, list[dict[str, Any]]] = {}
    for row in rows:
        grouped.setdefault(str(row.get("BOARD", "UNKNOWN")), []).append(row)
    boards = {board: _board_result(board_rows) for board, board_rows in grouped.items()}
    transport = {
        key.lower(): int(value)
        for key, value in re.findall(
            r"\b(timeout_count|invalid_count|stale_count|unstable_count)=(\d+)",
            text,
            flags=re.IGNORECASE,
        )
    }
    results = [result["classification"] for result in boards.values()]
    attribution = "PASS" if results and all(
        result.startswith("PASS_HANDSHAKE_") or result == "PASS_PROTOCOL_TIMEOUT"
        for result in results
    ) else "INCONCLUSIVE"
    return {
        "experiment": "EXP-S6-WR-EXTENSION-FIRST-DISABLE-ATTRIBUTION",
        "sample_count": len(rows),
        "board_count": len(boards),
        "boards": boards,
        "transport": transport,
        "wr_extension_disable_attribution": attribution,
        "step6a": "NOT_PASS",
        "step6b_trigger_run": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze_text(args.capture.read_text(encoding="utf-8")),
                     indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
