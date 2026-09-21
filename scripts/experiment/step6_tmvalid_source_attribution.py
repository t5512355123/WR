"""Offline analysis for EXP-S6-SLAVE-TMVALID-SOURCE-ATTRIBUTION.

The capture is intentionally passive.  It correlates the exported
``STATUS_TIME_VALID`` bit with its source-side ``PPS_ESCR.TM_VALID`` bit and
the WR PTP/servo state.  It never talks to JTAG and never changes the verdict
based on a single host-side read.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


_SAMPLE_RE = re.compile(r"^TMVALID_SAMPLE\s+(?P<body>.*)$")
_FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
_BOARD_RE = re.compile(r"\bboard=(?P<board>DE5\s+\[[^\]]+\])\s+sample=")
_COUNT_MODULUS = 1 << 16


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


def _delta16(current: int, previous: int) -> int:
    return (current - previous) % _COUNT_MODULUS


def _streak(rows: list[dict[str, Any]], predicate) -> int:
    current = maximum = 0
    for row in rows:
        if predicate(row):
            current += 1
            maximum = max(maximum, current)
        else:
            current = 0
    return maximum


def _stable_reference(rows: list[dict[str, Any]]) -> bool:
    if len(rows) < 10:
        return False
    return all(
        _int(row, "LINK_HEALTHY") == 1
        and _int(row, "BOOT_CHANGED") == 0
        and _int(row, "RESET_CHANGED") == 0
        for row in rows
    )


def _board_result(rows: list[dict[str, Any]]) -> dict[str, Any]:
    if not rows:
        return {
            "classification": "NO_SAMPLES",
            "sample_count": 0,
            "diagnostic_pass": False,
            "step6a_slave_global_time": False,
        }

    first = rows[0]
    last = rows[-1]
    role = "UNKNOWN"
    if any(_int(row, "PTP_STATE") == 6 for row in rows):
        role = "MASTER"
    elif any(_int(row, "PTP_STATE") == 9 for row in rows):
        role = "SLAVE"

    recovery_rows = [
        row
        for row in rows
        if _int(row, "PTP_STATE") == (6 if role == "MASTER" else 9)
        and (role != "SLAVE" or _int(row, "SERVO_STATE") == 4)
        and _int(row, "ESCR_TM_VALID") == 1
        and _int(row, "STATUS_TIME_VALID") == 1
        and _int(row, "STATUS_PPS_VALID") == 1
        and _int(row, "STEP5_LOCKED") == 1
        and _int(row, "BOOT_CHANGED") == 0
        and _int(row, "RESET_CHANGED") == 0
    ]
    recovery_streak = _streak(
        rows,
        lambda row: row in recovery_rows,
    )

    snapshot_delta = -1
    first_snapshot = _int(first, "SNAPSHOT_COUNT")
    last_snapshot = _int(last, "SNAPSHOT_COUNT")
    if first_snapshot >= 0 and last_snapshot >= 0:
        snapshot_delta = _delta16(last_snapshot, first_snapshot)

    mapping_streak = _streak(
        rows,
        lambda row: _int(row, "ESCR_TM_VALID") == 1
        and _int(row, "STATUS_TIME_VALID") == 0,
    )
    servo_streak = _streak(
        rows,
        lambda row: _int(row, "LINK_HEALTHY") == 1
        and _int(row, "ESCR_TM_VALID") == 0
        and _int(row, "STATUS_TIME_VALID") == 0
        and _int(row, "SERVO_COMPLETE") == 0,
    )
    timing_output_streak = _streak(
        rows,
        lambda row: _int(row, "LINK_HEALTHY") == 1
        and _int(row, "SERVO_COMPLETE") == 1
        and _int(row, "UCNT_INCREASED") == 1
        and _int(row, "PSTAT_LOCKED") == 1
        and _int(row, "STEP5_LOCKED") == 1
        and _int(row, "ESCR_TM_VALID") == 0
        and _int(row, "STATUS_TIME_VALID") == 0,
    )
    reset_seen = any(
        _int(row, "BOOT_CHANGED") == 1 or _int(row, "RESET_CHANGED") == 1
        for row in rows
    )

    stop_reasons = [
        str(row.get("STOP_CANDIDATE"))
        for row in rows
        if str(row.get("STOP_CANDIDATE", "NONE")) != "NONE"
    ]
    stop_reason = stop_reasons[0] if stop_reasons else "TIME_LIMIT_OR_CAPTURE_END"

    if role == "MASTER":
        master_ok = (
            recovery_streak >= 10
            and _stable_reference(rows)
            and all(_int(row, "PTP_STATE") == 6 for row in rows[-10:])
        )
        classification = "MASTER_REFERENCE_PASS" if master_ok else "MASTER_REFERENCE_FAIL"
        return {
            "role": role,
            "classification": classification,
            "sample_count": len(rows),
            "recovery_streak_max": recovery_streak,
            "mapping_streak_max": mapping_streak,
            "ptp_servo_streak_max": servo_streak,
            "timing_output_streak_max": timing_output_streak,
            "snapshot_delta_first_to_last": snapshot_delta,
            "reset_seen": reset_seen,
            "stop_reason": stop_reason,
            "diagnostic_pass": master_ok,
            "step6a_slave_global_time": False,
        }

    if recovery_streak >= 10 and snapshot_delta >= 2:
        classification = "SLAVE_TM_VALID_RECOVERED"
        diagnostic_pass = True
        step6a_pass = True
    elif mapping_streak >= 3:
        classification = "FAIL_MAPPING_EXPORT"
        diagnostic_pass = True
        step6a_pass = False
    elif reset_seen or stop_reason == "RESET_INIT_FAIL":
        classification = "FAIL_RESET_INIT"
        diagnostic_pass = True
        step6a_pass = False
    elif timing_output_streak >= 10:
        classification = "FAIL_TIMING_OUTPUT_ENABLE_PATH"
        diagnostic_pass = True
        step6a_pass = False
    elif servo_streak >= 10 or stop_reason == "FAIL_PTP_SERVO_NOT_COMPLETE":
        classification = "FAIL_PTP_SERVO_NOT_COMPLETE"
        diagnostic_pass = True
        step6a_pass = False
    else:
        classification = "TMVALID_ATTRIBUTION_INCONCLUSIVE"
        diagnostic_pass = False
        step6a_pass = False

    return {
        "role": role,
        "classification": classification,
        "sample_count": len(rows),
        "recovery_streak_max": recovery_streak,
        "mapping_streak_max": mapping_streak,
        "ptp_servo_streak_max": servo_streak,
        "timing_output_streak_max": timing_output_streak,
        "snapshot_delta_first_to_last": snapshot_delta,
        "reset_seen": reset_seen,
        "stop_reason": stop_reason,
        "diagnostic_pass": diagnostic_pass,
        "step6a_slave_global_time": step6a_pass,
        "first_status_time_valid": _int(first, "STATUS_TIME_VALID"),
        "last_status_time_valid": _int(last, "STATUS_TIME_VALID"),
        "first_escr_tm_valid": _int(first, "ESCR_TM_VALID"),
        "last_escr_tm_valid": _int(last, "ESCR_TM_VALID"),
        "last_ptp_state": _int(last, "PTP_STATE"),
        "last_servo_state": _int(last, "SERVO_STATE"),
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
    slave = [result for result in boards.values() if result.get("role") == "SLAVE"]
    slave_pass = bool(slave) and any(
        result.get("step6a_slave_global_time") is True for result in slave
    )
    attribution_pass = bool(boards) and all(
        result.get("diagnostic_pass") is True for result in boards.values()
    )
    return {
        "experiment": "EXP-S6-SLAVE-TMVALID-SOURCE-ATTRIBUTION",
        "sample_count": len(rows),
        "board_count": len(boards),
        "boards": boards,
        "transport": transport,
        "tmvalid_attribution": "PASS" if attribution_pass else "INCONCLUSIVE",
        "step6a_slave_global_time": "PASS" if slave_pass else "NOT_PASS",
        "step6b_trigger_run": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    result = analyze_text(args.capture.read_text(encoding="utf-8"))
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
