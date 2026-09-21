#!/usr/bin/env python3
"""Analyze the passive post-Slave Endpoint/link attribution capture.

The analyzer is deliberately conservative.  It never treats S_LOCK, SoftPLL,
or TM_VALID as evidence for this boundary.  Its only question is whether the
Endpoint control, recovered RX stream, PHY/PCS input, or Endpoint PCS/autoneg
is the first supported failure class.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Iterable


_SAMPLE_RE = re.compile(r"^ENDPOINTLINK_SAMPLE\s+(?P<body>.*)$")
_FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
_BOARD_RE = re.compile(r"\bBOARD=(?P<board>DE5\s+\[[^\]]+\])\s+SAMPLE=")
_INVALID = {"", "INVALID", "TIMEOUT", "DECREASED", "NA", "N/A", "UNKNOWN"}


def _value(text: str) -> int | str:
    try:
        if text.lower().startswith("0x"):
            return int(text, 16)
        return int(text, 10)
    except ValueError:
        return text


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


def _int(row: dict[str, Any], key: str, default: int | None = None) -> int | None:
    value = row.get(key, default)
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if not isinstance(value, str) or value.upper() in _INVALID:
        return default
    try:
        return int(value, 0)
    except ValueError:
        try:
            return int(value, 10)
        except ValueError:
            return default


def _hex(row: dict[str, Any], key: str) -> int | None:
    value = row.get(key)
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if not isinstance(value, str) or value.upper() in _INVALID:
        return None
    try:
        return int(value, 16)
    except ValueError:
        return None


def _reset_signature(row: dict[str, Any]) -> tuple[int | None, ...]:
    return tuple(_hex(row, key) for key in (
        "BOOT_GENERATION",
        "CPU_RESET_COUNT",
        "WR_CORE_RESET_COUNT",
        "SI_CONFIG_DROP_COUNT",
    ))


def _streak(rows: Iterable[dict[str, Any]], key: str, minimum: int) -> int:
    maximum = current = 0
    for row in rows:
        if (_int(row, key, 0) or 0) >= minimum:
            current += 1
            maximum = max(maximum, current)
        else:
            current = 0
    return maximum


def _first_row(rows: list[dict[str, Any]], predicate) -> dict[str, Any] | None:
    return next((row for row in rows if predicate(row)), None)


def analyze_rows(rows: list[dict[str, Any]], source: str = "") -> dict[str, Any]:
    board = rows[0].get("BOARD", "UNKNOWN") if rows else "UNKNOWN"
    role = rows[0].get("ROLE", "UNKNOWN") if rows else "UNKNOWN"
    read_errors = sum(1 for row in rows if _int(row, "READ_VALID", 0) != 1)
    stop_candidates = [
        str(row.get("STOP_CANDIDATE"))
        for row in rows
        if row.get("STOP_CANDIDATE") not in (None, "NONE")
    ]

    reset_values = [_reset_signature(row) for row in rows]
    reset_change_rows = sum(
        1
        for previous, current in zip(reset_values, reset_values[1:])
        if None not in previous + current and previous != current
    )
    explicit_reset_changes = sum(
        1 for row in rows if _int(row, "BOOT_CHANGED", 0) == 1 or _int(row, "RESET_CHANGED", 0) == 1
    )
    reset_changes = reset_change_rows + explicit_reset_changes

    if not rows:
        classification = "INCONCLUSIVE_NO_SAMPLES"
        failure_class = "NONE"
        stop_reason = classification
    elif read_errors:
        classification = "INCONCLUSIVE_TRANSPORT"
        failure_class = "NONE"
        stop_reason = "INCONCLUSIVE_TRANSPORT"
    elif reset_changes:
        classification = "INCONCLUSIVE_RESET"
        failure_class = "NONE"
        stop_reason = "INCONCLUSIVE_RESET"
    else:
        late_recovery = _first_row(rows, lambda r: (_int(r, "LINK_GOOD_STREAK", 0) or 0) >= 5)
        control_fail = _first_row(rows, lambda r: (_int(r, "CONTROL_BAD_STREAK", 0) or 0) >= 5)
        serdes_fail = _first_row(
            rows,
            lambda r: (_int(r, "RX_NO_LOCK_STREAK", 0) or 0) >= 5
            or (_int(r, "RX_NO_ACTIVITY_STREAK", 0) or 0) >= 5,
        )
        phy_fail = _first_row(rows, lambda r: (_int(r, "PHY_BAD_STREAK", 0) or 0) >= 5)
        endpoint_fail = _first_row(rows, lambda r: (_int(r, "RAW_LINK_BAD_STREAK", 0) or 0) >= 10)

        # The observer's candidate is source-adjacent evidence; the streaks
        # above are recomputed here so an edited/truncated capture cannot turn
        # a single line into a PASS.
        if late_recovery is not None:
            classification = "PASS_LATE_RECOVERY"
            failure_class = "NONE"
            stop_reason = "PASS_LATE_RECOVERY"
        elif control_fail is not None:
            classification = "FAIL_ENDPOINT_CONTROL_NOT_ENABLED"
            failure_class = classification
            stop_reason = classification
        elif serdes_fail is not None:
            classification = "FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED"
            failure_class = classification
            stop_reason = classification
        elif phy_fail is not None:
            classification = "FAIL_PHY_PCS_INPUT_INTEGRITY"
            failure_class = classification
            stop_reason = classification
        elif endpoint_fail is not None:
            classification = "FAIL_ENDPOINT_PCS_OR_AUTONEG_NOT_ESTABLISHED"
            failure_class = classification
            stop_reason = classification
        else:
            classification = "INCONCLUSIVE_MAX_CAPTURE"
            failure_class = "NONE"
            stop_reason = classification

    raw_healthy_samples = sum(1 for row in rows if _int(row, "RAW_PHY_HEALTHY", 0) == 1)
    link_zero_samples = sum(
        1
        for row in rows
        if _int(row, "DSR_LINK", 0) == 0
        and _int(row, "CORE_TM_LINK_UP", 0) == 0
        and _int(row, "CORE_LINK_OK", 0) == 0
    )
    sticky_increase_samples = sum(1 for row in rows if _int(row, "STICKY_ERROR_DELTA", 0) == 1)

    return {
        "format": "step6-post-slave-endpoint-link-attribution-v1",
        "source": source,
        "board": board,
        "role": role,
        "sample_count": len(rows),
        "valid_samples": len(rows) - read_errors,
        "transport_errors": read_errors,
        "reset_changes": reset_changes,
        "classification": classification,
        "failure_class": failure_class,
        "stop_reason": stop_reason,
        "link_attribution": "PASS" if classification.startswith("FAIL_") or classification == "PASS_LATE_RECOVERY" else "INCONCLUSIVE",
        "post_slave_link_establishment": "PASS_LATE_RECOVERY" if classification == "PASS_LATE_RECOVERY" else ("FAIL" if classification.startswith("FAIL_") else "INCONCLUSIVE"),
        "step6a": "NOT_PASS",
        "step6b_trigger_run": False,
        "raw_phy_healthy_samples": raw_healthy_samples,
        "link_zero_samples": link_zero_samples,
        "sticky_error_increase_samples": sticky_increase_samples,
        "max_control_bad_streak": max((_int(row, "CONTROL_BAD_STREAK", 0) or 0 for row in rows), default=0),
        "max_rx_no_lock_streak": max((_int(row, "RX_NO_LOCK_STREAK", 0) or 0 for row in rows), default=0),
        "max_rx_no_activity_streak": max((_int(row, "RX_NO_ACTIVITY_STREAK", 0) or 0 for row in rows), default=0),
        "max_phy_bad_streak": max((_int(row, "PHY_BAD_STREAK", 0) or 0 for row in rows), default=0),
        "max_raw_link_bad_streak": max((_int(row, "RAW_LINK_BAD_STREAK", 0) or 0 for row in rows), default=0),
        "stop_candidates": stop_candidates,
        "rows": rows,
    }


def analyze_text(text: str, source: str = "") -> dict[str, Any]:
    return analyze_rows(parse_samples(text), source=source)


def analyze_files(paths: list[Path]) -> dict[str, Any]:
    board_results: list[dict[str, Any]] = []
    for path in paths:
        board_results.append(analyze_text(path.read_text(encoding="utf-8", errors="replace"), str(path)))
    if len(board_results) == 1:
        return board_results[0]
    overall_classification = "INCONCLUSIVE"
    if board_results and all(result["classification"] == "PASS_LATE_RECOVERY" for result in board_results):
        overall_classification = "PASS_LATE_RECOVERY"
    elif board_results and all(result["classification"].startswith("FAIL_") for result in board_results):
        overall_classification = "FAIL_MULTI_BOARD_ENDPOINT_LINK"
    return {
        "format": "step6-post-slave-endpoint-link-attribution-v1",
        "classification": overall_classification,
        "link_attribution": "PASS" if overall_classification != "INCONCLUSIVE" else "INCONCLUSIVE",
        "post_slave_link_establishment": "PASS_LATE_RECOVERY" if overall_classification == "PASS_LATE_RECOVERY" else ("FAIL" if overall_classification.startswith("FAIL_") else "INCONCLUSIVE"),
        "step6a": "NOT_PASS",
        "step6b_trigger_run": False,
        "boards": board_results,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_files(args.inputs)
    encoded = json.dumps(result, indent=2, ensure_ascii=False)
    if args.json_out:
        args.json_out.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
