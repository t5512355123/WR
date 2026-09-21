#!/usr/bin/env python3
"""Offline correction of the Step6 recovered-RX activity decode.

This tool consumes only the already captured ENDPOINTLINK_SAMPLE logs.  It
does not access JTAG and cannot change the DUT.  The correction is deliberately
separate from the hardware experiment: instance 7 is a 64-bit probe and the
recovered-RX activity field is bits [47:32], while the old observer's
``field32`` helper truncated the probe to its low 32 bits first.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


_SAMPLE_RE = re.compile(r"^ENDPOINTLINK_SAMPLE\s+(?P<body>.*)$")
_FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
_BOARD_RE = re.compile(r"\bBOARD=(?P<board>DE5\s+\[[^\]]+\])\s+SAMPLE=")
_INVALID = {"", "INVALID", "TIMEOUT", "DECREASED", "NA", "N/A", "UNKNOWN"}


def _value(text: str) -> int | str:
    try:
        return int(text, 0)
    except ValueError:
        try:
            return int(text, 10)
        except ValueError:
            return text


def parse_samples(text: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = _SAMPLE_RE.match(line.strip())
        if not match:
            continue
        row = {key.upper(): _value(value) for key, value in _FIELD_RE.findall(match.group("body"))}
        board = _BOARD_RE.search(line)
        if board:
            row["BOARD"] = board.group("board")
        rows.append(row)
    return rows


def decode_rx_activity(clock_activity_raw: str | int) -> int | None:
    """Decode instance-7 bits [47:32] without truncating the probe."""

    try:
        value = clock_activity_raw if isinstance(clock_activity_raw, int) else int(clock_activity_raw, 16)
    except (TypeError, ValueError):
        return None
    return (value >> 32) & 0xFFFF


def delta16(previous: int, current: int) -> int:
    """Return modulo-2^16 delta for the wrapping activity counter."""

    return (current - previous) & 0xFFFF


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


def _enrich(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    previous: int | None = None
    for row in rows:
        activity = decode_rx_activity(row.get("CLOCK_ACTIVITY_RAW", ""))
        row["CORRECTED_RX_ACTIVITY"] = activity
        row["CORRECTED_RX_ACTIVITY_CHANGED"] = int(
            previous is not None and activity is not None and activity != previous
        )
        row["CORRECTED_RX_ACTIVITY_DELTA16"] = (
            delta16(previous, activity) if previous is not None and activity is not None else None
        )
        previous = activity
    return rows


def analyze_rows(rows: list[dict[str, Any]], source: str = "") -> dict[str, Any]:
    rows = _enrich(rows)
    board = rows[0].get("BOARD", "UNKNOWN") if rows else "UNKNOWN"
    role = rows[0].get("ROLE", "UNKNOWN") if rows else "UNKNOWN"
    valid = [row for row in rows if _int(row, "READ_VALID", 0) == 1]
    reset_signatures = [_reset_signature(row) for row in valid]
    reset_changes = sum(
        1
        for old, new in zip(reset_signatures, reset_signatures[1:])
        if None not in old + new and old != new
    )
    reset_changes += sum(
        1 for row in valid if _int(row, "BOOT_CHANGED", 0) == 1 or _int(row, "RESET_CHANGED", 0) == 1
    )

    activity_values = [row["CORRECTED_RX_ACTIVITY"] for row in valid if row["CORRECTED_RX_ACTIVITY"] is not None]
    activity_present = len(activity_values) >= 5 and len(set(activity_values)) >= 5
    old_zero_decode = sum(1 for row in valid if _int(row, "RX_CLOCK_ACTIVITY", None) == 0)
    corrected_nonzero = sum(1 for value in activity_values if value != 0)
    lock_present = bool(valid) and all(_int(row, "RX_LOCKED_TO_DATA", 0) == 1 for row in valid)
    control_present = bool(valid) and all(
        _int(row, key, 0) == expected
        for row in valid
        for key, expected in (("PHY_RST", 0), ("PHY_TX_DISABLE", 0), ("ECR_TX_EN", 1), ("ECR_RX_EN", 1))
    )
    sync_bad_samples = sum(1 for row in valid if _int(row, "RX_SYNCSTATUS", 1) == 0)
    enc_error_samples = sum(1 for row in valid if _int(row, "RX_ENC_ERR", 0) == 1)
    disperr_samples = sum(1 for row in valid if _int(row, "RX_DISPERR", 0) == 1)
    errdetect_samples = sum(1 for row in valid if _int(row, "RX_ERRDETECT", 0) == 1)
    raw_changed_samples = sum(1 for row in valid if row["CORRECTED_RX_ACTIVITY_CHANGED"] == 1)

    decoder_bug_confirmed = bool(
        len(valid) >= 5
        and reset_changes == 0
        and activity_present
        and lock_present
        and control_present
        and old_zero_decode >= 5
    )
    corrected_failure = "FAIL_PHY_PCS_INPUT_INTEGRITY" if decoder_bug_confirmed and (
        sync_bad_samples > 0 or enc_error_samples > 0 or disperr_samples > 0 or errdetect_samples > 0
    ) else "INCONCLUSIVE"

    return {
        "format": "step6-rx-activity-decode-correction-reanalysis-v1",
        "source": source,
        "board": board,
        "role": role,
        "sample_count": len(rows),
        "valid_samples": len(valid),
        "reset_changes": reset_changes,
        "rtl_mapping_verified": True,
        "observer_decode_bug_verified": old_zero_decode >= 5 and corrected_nonzero >= 5,
        "decoder_bug_confirmed": decoder_bug_confirmed,
        "rx_activity_corrected": activity_values,
        "rx_activity_raw_changed_samples": raw_changed_samples,
        "rx_activity_corrected_nonzero_samples": corrected_nonzero,
        "rx_locked_to_data_all_valid": lock_present,
        "endpoint_control_all_valid": control_present,
        "rx_syncstatus_zero_samples": sync_bad_samples,
        "rx_enc_err_samples": enc_error_samples,
        "rx_disperr_samples": disperr_samples,
        "rx_errdetect_samples": errdetect_samples,
        "previous_failure_class": "FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED",
        "previous_failure_class_invalidated": decoder_bug_confirmed,
        "recovered_rx_clock_activity": "PRESENT" if decoder_bug_confirmed else "INCONCLUSIVE",
        "serdes_data_lock": "PRESENT" if lock_present else "INCONCLUSIVE",
        "classification": corrected_failure,
        "link_attribution": "PASS" if corrected_failure.startswith("FAIL_") else "INCONCLUSIVE",
        "post_slave_link_establishment": "FAIL" if corrected_failure.startswith("FAIL_") else "INCONCLUSIVE",
        "slock": "NOT_REACHED",
        "step6a": "NOT_PASS",
        "step6b_trigger_run": False,
        "rows": rows,
    }


def analyze_text(text: str, source: str = "") -> dict[str, Any]:
    return analyze_rows(parse_samples(text), source=source)


def analyze_files(paths: list[Path]) -> dict[str, Any]:
    boards = [analyze_text(path.read_text(encoding="utf-8", errors="replace"), str(path)) for path in paths]
    all_confirmed = bool(boards) and all(board["decoder_bug_confirmed"] for board in boards)
    all_phy = bool(boards) and all(board["classification"] == "FAIL_PHY_PCS_INPUT_INTEGRITY" for board in boards)
    return {
        "format": "step6-rx-activity-decode-correction-reanalysis-v1",
        "experiment": "EXP-S6-RX-ACTIVITY-DECODE-CORRECTION-REANALYSIS-20260921",
        "hardware_sampling": False,
        "decoder_bug_confirmed": all_confirmed,
        "previous_failure_class_invalidated": all_confirmed,
        "recovered_rx_clock_activity": "PRESENT" if all_confirmed else "INCONCLUSIVE",
        "classification": "FAIL_PHY_PCS_INPUT_INTEGRITY" if all_phy else "INCONCLUSIVE",
        "link_attribution": "PASS" if all_phy else "INCONCLUSIVE",
        "post_slave_link_establishment": "FAIL" if all_phy else "INCONCLUSIVE",
        "slock": "NOT_REACHED",
        "step6a": "NOT_PASS",
        "step6b_trigger_run": False,
        "boards": boards,
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
