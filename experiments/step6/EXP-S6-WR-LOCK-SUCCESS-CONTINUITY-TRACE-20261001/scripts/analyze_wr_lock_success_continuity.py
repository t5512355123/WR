#!/usr/bin/env python3
"""Analyze the read-only first-success WR admission trace conservatively."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
import re
from typing import Any


U32 = 1 << 32


def parse_fields(line: str) -> dict[str, str]:
    return {
        key: value
        for key, value in re.findall(r"([A-Za-z][A-Za-z0-9_]*)=([^\s]+)", line)
    }


def as_int(row: dict[str, str], key: str) -> int | None:
    value = row.get(key)
    if value is None or value in {"NA", "INVALID", "TIMEOUT", "SKIPPED"}:
        return None
    try:
        if key.endswith("_RAW"):
            return int(value.removeprefix("0x"), 16)
        return int(value, 10)
    except (ValueError, TypeError):
        return None


def delta32(first: int | None, last: int | None) -> tuple[int | None, str]:
    if first is None or last is None:
        return None, "MISSING"
    if last >= first:
        return last - first, "DIRECT"
    if first >= 0xF0000000 and last <= 0x0FFFFFFF:
        return U32 - first + last, "ROLLOVER"
    return None, "DISCONTINUITY"


def derive_success_delta(previous: dict[str, str], current: dict[str, str]) -> dict[str, Any]:
    names = {
        "poll": "LOCK_POLL_COUNT_RAW",
        "unlocked": "LOCK_UNLOCKED_COUNT_RAW",
        "calib_fail": "LOCK_CALIB_FAIL_COUNT_RAW",
    }
    deltas: dict[str, int | None] = {}
    kinds: dict[str, str] = {}
    for short, field in names.items():
        deltas[short], kinds[short] = delta32(as_int(previous, field), as_int(current, field))
    if any(value is None for value in deltas.values()):
        return {"valid": False, "delta": None, "deltas": deltas, "kinds": kinds}
    result = int(deltas["poll"]) - int(deltas["unlocked"]) - int(deltas["calib_fail"])
    return {
        "valid": result >= 0,
        "delta": result if result >= 0 else None,
        "deltas": deltas,
        "kinds": kinds,
    }


def classify(rows: list[dict[str, str]], stop_reason: str) -> str:
    valid = [r for r in rows if as_int(r, "ROW_VALID") == 1]
    triggered = [r for r in valid if as_int(r, "SUCCESS_CONFIRMED") == 1]
    if not triggered:
        if stop_reason == "NO_SUCCESSFUL_LOCK_POLL_300S":
            return "SUCCESSFUL_SLOCK_ADMISSION_NOT_REPRODUCED"
        if stop_reason == "WR_SESSION_TERMINATED_BEFORE_SUCCESS":
            return "WR_SESSION_TERMINATED_BEFORE_SUCCESS"
        return f"INCONCLUSIVE_{stop_reason or 'MISSING_STOP'}"

    trigger_row = triggered[0]
    confirm_ms = as_int(trigger_row, "SUCCESS_TRIGGER_CONFIRM_MS")
    post = [r for r in valid if confirm_ms is not None and
            (as_int(r, "ELAPSED_MS") or -1) >= confirm_ms]
    if not post:
        return "POST_SUCCESS_CAPTURE_INCONCLUSIVE"
    tx_locked = any(as_int(r, "WR_TX_ID") == 0x1002 for r in post)
    rx_calibrate = any(as_int(r, "WR_RX_ID") == 0x1003 for r in post)
    wr_locked = any(as_int(r, "WR_STATE") == 4 for r in post)
    wr_locked_timeout = any(
        as_int(r, "WR_DISABLE_VALID") == 1 and as_int(r, "WR_FAILURE_REASON") == 4
        for r in post
    )
    locks_healthy = bool(post) and all(
        all(as_int(r, key) == 1 for key in (
            "HELPER_LOCK", "MAIN_FREQ_LOCK", "MAIN_PHASE_LOCK", "MAIN_LOCK", "PSTAT_LOCK"
        ))
        for r in post
    )
    unlock_delta = None
    if len(post) >= 2:
        unlock_delta, _ = delta32(
            as_int(post[0], "LOCK_UNLOCKED_COUNT_RAW"),
            as_int(post[-1], "LOCK_UNLOCKED_COUNT_RAW"),
        )

    if wr_locked and tx_locked and rx_calibrate and locks_healthy:
        return "WR_LOCK_ADMISSION_CONTINUITY_SUPPORTED"
    if wr_locked and tx_locked and not rx_calibrate and wr_locked_timeout:
        return "FIRST_FAILURE_AFTER_SUCCESS_MASTER_CALIBRATE_HANDSHAKE"
    if unlock_delta is not None and unlock_delta > 0 and not wr_locked_timeout:
        return "FIRST_FAILURE_AFTER_SUCCESS_SOFTPLL_LOCK_CONTINUITY_SUSPECTED"
    if wr_locked or tx_locked:
        return "POST_SUCCESS_WR_ADMISSION_PARTIAL"
    if rx_calibrate:
        return "POST_SUCCESS_RX_CALIBRATE_WITHOUT_LOCKED_STATE"
    return "POST_SUCCESS_CAPTURE_INCONCLUSIVE"


def analyze_text(text: str) -> dict[str, Any]:
    rows = [parse_fields(line) for line in text.splitlines() if line.startswith("S6W_SAMPLE ")]
    stops = [parse_fields(line) for line in text.splitlines() if line.startswith("S6W_STOP ")]
    summaries = [parse_fields(line) for line in text.splitlines() if line.startswith("S6W_SUMMARY ")]
    stop = stops[-1] if stops else (summaries[-1] if summaries else {})
    stop_reason = stop.get("reason", stop.get("stop_reason", "MISSING_STOP"))
    valid = [row for row in rows if as_int(row, "ROW_VALID") == 1]
    state_counts = Counter(str(as_int(row, "WR_STATE")) for row in valid)
    confirmed = [row for row in valid if as_int(row, "SUCCESS_CONFIRMED") == 1]
    candidate_rows = sum(as_int(row, "SUCCESS_CANDIDATE") == 1 for row in rows)
    rejected_candidates = sum(as_int(row, "SUCCESS_CANDIDATE_REJECTED") == 1 for row in rows)
    deltas = []
    for previous, current in zip(rows, rows[1:]):
        if as_int(previous, "ROW_VALID") != 1 or as_int(current, "ROW_VALID") != 1:
            continue
        deltas.append(derive_success_delta(previous, current))
    all_metric_valid = sum(result["valid"] for result in deltas)
    tx_locked_rows = sum(as_int(row, "WR_TX_ID") == 0x1002 for row in valid)
    rx_calibrate_rows = sum(as_int(row, "WR_RX_ID") == 0x1003 for row in valid)
    result = classify(rows, stop_reason)
    return {
        "result": result,
        "stop_reason": stop_reason,
        "samples": len(rows),
        "valid_rows": len(valid),
        "invalid_rows": len(rows) - len(valid),
        "state_counts": dict(state_counts),
        "success_candidates": candidate_rows,
        "rejected_candidates": rejected_candidates,
        "success_confirmed_rows": len(confirmed),
        "success_trigger_ms": as_int(confirmed[0], "SUCCESS_TRIGGER_MS") if confirmed else None,
        "success_confirm_ms": as_int(confirmed[0], "SUCCESS_TRIGGER_CONFIRM_MS") if confirmed else None,
        "metric_intervals_valid": all_metric_valid,
        "metric_intervals_total": len(deltas),
        "tx_locked_rows": tx_locked_rows,
        "rx_calibrate_rows": rx_calibrate_rows,
        "class": result,
        "causal_limit": "COUNTER_AND_SIGNAL_CORRELATION_NOT_ATOMIC_CAUSALITY",
        "step6_stable_offset": "NOT_EVALUATED",
    }


def render(result: dict[str, Any]) -> str:
    return "\n".join(
        [
            f"RESULT={result['result']}",
            f"STOP_REASON={result['stop_reason']}",
            f"SAMPLES={result['samples']}",
            f"VALID_ROWS={result['valid_rows']}",
            f"INVALID_ROWS={result['invalid_rows']}",
            f"WR_STATE_COUNTS={result['state_counts']}",
            f"SUCCESS_CANDIDATES={result['success_candidates']}",
            f"SUCCESS_CANDIDATES_REJECTED={result['rejected_candidates']}",
            f"SUCCESS_CONFIRMED_ROWS={result['success_confirmed_rows']}",
            f"SUCCESS_TRIGGER_MS={result['success_trigger_ms']}",
            f"SUCCESS_CONFIRM_MS={result['success_confirm_ms']}",
            f"SUCCESS_METRIC_VALID_INTERVALS={result['metric_intervals_valid']}/{result['metric_intervals_total']}",
            f"TX_LOCKED_ROWS={result['tx_locked_rows']}",
            f"RX_CALIBRATE_ROWS={result['rx_calibrate_rows']}",
            f"CLASS={result['class']}",
            f"CAUSAL_LIMIT={result['causal_limit']}",
            f"STEP6_STABLE_OFFSET={result['step6_stable_offset']}",
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    print(render(analyze_text(args.log.read_text(encoding="utf-8", errors="replace"))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
