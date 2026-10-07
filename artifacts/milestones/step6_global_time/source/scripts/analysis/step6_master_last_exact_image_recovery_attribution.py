#!/usr/bin/env python3
"""Analyze the exact-Master-last Step6 recovery attribution capture."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
PREFLIGHT_RE = re.compile(r"^PREFLIGHT_SAMPLE\s+(?P<body>.*)$")
RECOVERY_RE = re.compile(r"^RECOVERY_PAIR_SAMPLE\s+(?P<body>.*)$")
PREFLIGHT_RESULT_RE = re.compile(r"^PREFLIGHT_RESULT=(?P<value>[^\s]+)")
RECOVERY_RESULT_RE = re.compile(r"^RECOVERY_RESULT=(?P<value>[^\s]+)")
INVALID = {"", "INVALID", "TIMEOUT", "DECREASED", "NA", "N/A", "UNKNOWN"}


def _value(text: str) -> int | str:
    try:
        if text.lower().startswith("0x"):
            return int(text, 16)
        return int(text, 10)
    except ValueError:
        try:
            return int(text, 16)
        except ValueError:
            return text


def parse_log(text: str) -> dict[str, Any]:
    preflight: list[dict[str, Any]] = []
    recovery: list[dict[str, Any]] = []
    preflight_result: str | None = None
    recovery_result: str | None = None
    for line in text.splitlines():
        line = line.strip()
        match = PREFLIGHT_RE.match(line)
        if match:
            row = {key.upper(): _value(value) for key, value in FIELD_RE.findall(match.group("body"))}
            preflight.append(row)
            continue
        match = RECOVERY_RE.match(line)
        if match:
            row = {key.upper(): _value(value) for key, value in FIELD_RE.findall(match.group("body"))}
            recovery.append(row)
            continue
        match = PREFLIGHT_RESULT_RE.match(line)
        if match:
            preflight_result = match.group("value")
        match = RECOVERY_RESULT_RE.match(line)
        if match:
            recovery_result = match.group("value")
    return {
        "preflight": preflight,
        "recovery": recovery,
        "preflight_result": preflight_result,
        "recovery_result": recovery_result,
    }


def _int(row: dict[str, Any], key: str, default: int | None = None) -> int | None:
    value = row.get(key, default)
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
            try:
                return int(value, 16)
            except ValueError:
                return default


def _max(rows: list[dict[str, Any]], key: str) -> int:
    return max((_int(row, key, 0) or 0 for row in rows), default=0)


def analyze_text(preflight_text: str, recovery_text: str, source: str = "") -> dict[str, Any]:
    pre = parse_log(preflight_text)
    rec = parse_log(recovery_text)
    preflight = pre["preflight"]
    recovery = rec["recovery"]
    preflight_transport_errors = sum(
        1 for row in preflight if _int(row, "READ_VALID", 0) != 1
    )
    recovery_transport_errors = sum(
        1 for row in recovery if _int(row, "READ_VALID", 0) != 1
    )
    reset_changes = sum(
        1 for row in recovery if _int(row, "RESET_CHANGED", 0) == 1
    )
    preflight_reset_changes = sum(
        1 for row in preflight if _int(row, "RESET_CHANGED", 0) == 1
    )
    master_ready_streak = _max(recovery, "MASTER_READY_STREAK")
    recovery_streak = _max(recovery, "SLAVE_RECOVERY_STREAK")
    recovery_seen = any(
        _int(row, "SLAVE_RECOVERY_SEEN", 0) == 1 for row in recovery
    )
    max_recovery_streak = _max(recovery, "MAX_RECOVERY_STREAK")
    master_local_ready = master_ready_streak >= 3
    result = rec["recovery_result"] or "MISSING"

    if pre["preflight_result"] != "PASS":
        classification = "INCONCLUSIVE_PREPROGRAM_STATE"
        recovery_verdict = "NOT_RUN"
    elif preflight_transport_errors or recovery_transport_errors:
        classification = "INCONCLUSIVE_TRANSPORT"
        recovery_verdict = "INCONCLUSIVE"
    elif preflight_reset_changes or reset_changes:
        classification = "INCONCLUSIVE_RESET"
        recovery_verdict = "INCONCLUSIVE"
    elif not master_local_ready and result == "INCONCLUSIVE_MASTER_LOCAL_READY":
        classification = "INCONCLUSIVE_MASTER_LOCAL_READY"
        recovery_verdict = "INCONCLUSIVE"
    elif result == "PASS_EXACT_MASTER_LAST_RECOVERY" and master_local_ready and recovery_streak >= 5:
        classification = "PASS_EXACT_MASTER_LAST_RECOVERY"
        recovery_verdict = "PASS"
    elif result == "FAIL_TRANSIENT_RECOVERY" and recovery_seen:
        classification = "FAIL_TRANSIENT_RECOVERY"
        recovery_verdict = "FAIL_TRANSIENT"
    elif result == "FAIL_EXACT_MASTER_LAST_RECOVERY_NOT_REPRODUCED":
        classification = "FAIL_EXACT_MASTER_LAST_RECOVERY_NOT_REPRODUCED"
        recovery_verdict = "FAIL_NOT_REPRODUCED"
    else:
        classification = "INCONCLUSIVE_RECOVERY_CAPTURE"
        recovery_verdict = "INCONCLUSIVE"

    return {
        "format": "step6-master-last-exact-image-recovery-attribution-v1",
        "source": source,
        "preflight_result": pre["preflight_result"],
        "recovery_result": result,
        "classification": classification,
        "recovery_verdict": recovery_verdict,
        "preflight_samples": len(preflight),
        "recovery_samples": len(recovery),
        "preflight_transport_errors": preflight_transport_errors,
        "recovery_transport_errors": recovery_transport_errors,
        "preflight_reset_changes": preflight_reset_changes,
        "recovery_reset_changes": reset_changes,
        "master_local_ready": master_local_ready,
        "master_ready_max_streak": master_ready_streak,
        "recovery_seen": recovery_seen,
        "recovery_max_streak": max(recovery_streak, max_recovery_streak),
        "step6a": "NOT_PASS",
        "step6b": "NOT_RUN",
        "preflight_rows": preflight,
        "recovery_rows": recovery,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("preflight", type=Path)
    parser.add_argument("recovery", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_text(
        args.preflight.read_text(encoding="utf-8", errors="replace"),
        args.recovery.read_text(encoding="utf-8", errors="replace"),
        source=f"{args.preflight};{args.recovery}",
    )
    encoded = json.dumps(result, indent=2, ensure_ascii=False)
    if args.json_out:
        args.json_out.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
