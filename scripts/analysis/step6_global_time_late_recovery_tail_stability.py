"""Analyze the read-only late-recovery Global-Time tail capture."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
GATE_RE = re.compile(r"^S6_TAIL_GATE_PAIR\s+(?P<body>.*)$")
SAMPLE_RE = re.compile(r"^S6_TAIL_SAMPLE\s+(?P<body>.*)$")
GATE_RESULT_RE = re.compile(r"^S6_TAIL_GATE_RESULT=(?P<value>[^\s]+)")
CAPTURE_RESULT_RE = re.compile(r"^S6_TAIL_CAPTURE_RESULT=(?P<value>[^\s]+)")
INVALID = {"", "INVALID", "TIMEOUT", "NA", "N/A", "UNKNOWN"}


def _value(text: str) -> int | str:
    try:
        if text.lower().startswith("0x"):
            return int(text, 16)
        return int(text, 10)
    except ValueError:
        return text


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


def _parse_rows(text: str, pattern: re.Pattern[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = pattern.match(line.strip())
        if not match:
            continue
        rows.append(
            {
                key.upper(): _value(value)
                for key, value in FIELD_RE.findall(match.group("body"))
            }
        )
    return rows


def _scalar(text: str, pattern: re.Pattern[str]) -> str | None:
    result: str | None = None
    for line in text.splitlines():
        match = pattern.match(line.strip())
        if match:
            result = match.group("value")
    return result


def _max_streak(rows: list[dict[str, Any]], predicate) -> int:
    current = best = 0
    for row in rows:
        if predicate(row):
            current += 1
            best = max(best, current)
        else:
            current = 0
    return best


def _accepted(row: dict[str, Any]) -> bool:
    required = (
        "TIME_RECOVERY_CANDIDATE",
        "READ_VALID",
        "CAPTURE_HEALTHY",
        "STATUS_TIME_VALID",
        "GLOBAL_TIME_SNAPSHOT_STABLE",
        "GLOBAL_TIME_SNAPSHOT_VALID",
        "GLOBAL_TIME_SNAPSHOT_TIME_VALID",
        "GLOBAL_TIME_SNAPSHOT_PPS_VALID",
        "STATUS_TM_LINK_UP",
        "STATUS_LINK_OK",
        "RX_LOCKED_TO_DATA",
        "RX_PATTERN_READY",
    )
    if not all(_int(row, key) == 1 for key in required):
        return False
    if _int(row, "SPLL_SEQ_STATE") != 8 or _int(row, "PSTAT_LOCKED") != 1:
        return False
    if _int(row, "MAIN_LOCKED") != 1:
        return False
    cycles = _int(row, "GLOBAL_TIME_CYCLES")
    tick = _int(row, "GLOBAL_TIME_TICK")
    return cycles is not None and 0 <= cycles <= 124_999_999 and tick is not None


def _formal_pass(rows: list[dict[str, Any]]) -> tuple[bool, int, int]:
    current: list[dict[str, Any]] = []
    best_streak = best_advances = 0
    for row in rows:
        if not _accepted(row):
            current = []
            continue
        if current:
            previous_tick = _int(current[-1], "GLOBAL_TIME_TICK")
            current_tick = _int(row, "GLOBAL_TIME_TICK")
            if previous_tick is None or current_tick is None or current_tick <= previous_tick:
                current = []
        current.append(row)
        if len(current) > 5:
            current = current[-5:]
        best_streak = max(best_streak, len(current))
        counts = [_int(item, "GLOBAL_TIME_SNAPSHOT_COUNT") for item in current]
        if any(value is None for value in counts):
            continue
        advances = sum(
            counts[index] > counts[index - 1] for index in range(1, len(counts))
        )
        best_advances = max(best_advances, advances)
        if len(current) >= 5 and advances >= 2:
            return True, best_streak, best_advances
    return False, best_streak, best_advances


def _runtime_invalid(rows: list[dict[str, Any]]) -> bool:
    return any(
        _int(row, "READ_VALID", 0) != 1
        or _int(row, "CAPTURE_HEALTHY", 0) != 1
        or _int(row, "RESET_CHANGED", 0) == 1
        for row in rows
    )


def _board(rows: list[dict[str, Any]], role: str) -> dict[str, Any]:
    selected = [
        row for row in rows if str(row.get("BOARD", "")).upper() == role
    ]
    return {
        "sample_count": len(selected),
        "read_valid_count": sum(_int(row, "READ_VALID", 0) == 1 for row in selected),
        "capture_healthy_count": sum(
            _int(row, "CAPTURE_HEALTHY", 0) == 1 for row in selected
        ),
        "rows": selected,
    }


def _time_edges(rows: list[dict[str, Any]]) -> tuple[int, int]:
    previous: int | None = None
    rising = falling = 0
    for row in rows:
        current = _int(row, "STATUS_TIME_VALID")
        if current is None:
            continue
        if previous is not None and current != previous:
            if current == 1:
                rising += 1
            else:
                falling += 1
        previous = current
    return rising, falling


def analyze_text(text: str) -> dict[str, Any]:
    gates = _parse_rows(text, GATE_RE)
    samples = _parse_rows(text, SAMPLE_RE)
    gate_result = _scalar(text, GATE_RESULT_RE) or "MISSING"
    capture_result = _scalar(text, CAPTURE_RESULT_RE) or "MISSING"
    slave_rows = [
        row for row in samples if str(row.get("BOARD", "")).upper() == "SLAVE"
    ]
    master_rows = [
        row for row in samples if str(row.get("BOARD", "")).upper() == "MASTER"
    ]
    runtime_invalid = _runtime_invalid(samples) or not slave_rows or not master_rows
    formal_pass, best_streak, best_advances = _formal_pass(slave_rows)
    rising_edges, falling_edges = _time_edges(slave_rows)
    max_valid_streak = _max_streak(
        slave_rows, lambda row: _int(row, "STATUS_TIME_VALID", 0) == 1
    )
    max_terminal_streak = _max_streak(
        slave_rows,
        lambda row: (
            _int(row, "STATUS_TIME_VALID", 0) == 0
            and _int(row, "PTP_STATE", 0) == 9
            and _int(row, "PD_STATE", 0) == 4
            and _int(row, "EXT_STATE", 0) == 2
            and _int(row, "WR_STATE_VALUE", 0) == 0
            and _int(row, "SPLL_SEQ_STATE", 0) == 8
            and _int(row, "PSTAT_LOCKED", 0) == 1
            and _int(row, "MAIN_LOCKED", 0) == 1
        ),
    )
    time_candidate_ever = any(_accepted(row) for row in slave_rows)
    active_time_rows = [
        row for row in slave_rows if _int(row, "EXT_STATE", 0) == 1
    ]
    first_valid = next(
        (_int(row, "ELAPSED_MS") for row in slave_rows if _int(row, "STATUS_TIME_VALID") == 1),
        None,
    )
    last_valid_rows = [
        row for row in slave_rows if _int(row, "STATUS_TIME_VALID") == 1
    ]
    last_valid = _int(last_valid_rows[-1], "ELAPSED_MS") if last_valid_rows else None

    if gate_result != "PASS":
        classification = (
            gate_result
            if gate_result != "MISSING"
            else "INCONCLUSIVE_TAIL_PRECONDITION_CHANGED"
        )
        verdict = "INCONCLUSIVE"
        failure_class = "TAIL_BASIC_HEALTH_GATE_NOT_PASS"
        step6a = "NOT_EVALUATED"
    elif runtime_invalid:
        classification = "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
        verdict = "INCONCLUSIVE"
        failure_class = "RUNTIME_READ_OR_RESET_INVALID"
        step6a = "NOT_PASS"
    elif formal_pass:
        classification = "PASS_LATE_RECOVERY_STABLE"
        verdict = "PASS"
        failure_class = ""
        step6a = "PASS"
    elif capture_result == "FAIL_GLOBAL_TIME_RECOVERY_LOST" or (
        rising_edges > 0 and falling_edges > 0 and max_valid_streak > 0
    ):
        classification = "FAIL_GLOBAL_TIME_RECOVERY_LOST"
        verdict = "FAIL"
        failure_class = "POST_RECOVERY_TIME_VALID_LOSS"
        step6a = "FAIL"
    elif max_terminal_streak >= 5:
        classification = "FAIL_LATE_RECOVERY_NOT_SUSTAINED"
        verdict = "FAIL"
        failure_class = "WR_EXTENSION_RETURNED_TO_TERMINAL_FALLBACK_AFTER_LATE_RECOVERY"
        step6a = "FAIL"
    elif max_valid_streak >= 5 and best_advances < 2:
        classification = "FAIL_GLOBAL_TIME_PPS_SNAPSHOT_NOT_ADVANCING"
        verdict = "FAIL"
        failure_class = "GLOBAL_TIME_VALID_BUT_PPS_SNAPSHOT_COUNT_NOT_ADVANCING"
        step6a = "FAIL"
    elif active_time_rows and (rising_edges > 0 or falling_edges > 0):
        classification = "FAIL_INTERMITTENT_GLOBAL_TIME_VALIDITY"
        verdict = "FAIL"
        failure_class = "WR_EXTENSION_ACTIVE_BUT_GLOBAL_TIME_NOT_STABLE"
        step6a = "FAIL"
    elif capture_result == "FAIL_LATE_RECOVERY_NOT_SUSTAINED":
        classification = "FAIL_LATE_RECOVERY_NOT_SUSTAINED"
        verdict = "FAIL"
        failure_class = "WR_EXTENSION_RETURNED_TO_TERMINAL_FALLBACK_AFTER_LATE_RECOVERY"
        step6a = "FAIL"
    else:
        classification = "INCONCLUSIVE_TAIL_NO_GLOBAL_TIME_STABILITY"
        verdict = "INCONCLUSIVE"
        failure_class = "NO_FORMAL_GLOBAL_TIME_WINDOW_OBSERVED"
        step6a = "NOT_PASS"

    passed = classification == "PASS_LATE_RECOVERY_STABLE"
    return {
        "format": "step6-global-time-late-recovery-tail-stability-v1",
        "gate_result": gate_result,
        "capture_result": capture_result,
        "classification": classification,
        "verdict": verdict,
        "failure_class": failure_class,
        "step6a_1": step6a,
        "step6a_global_time": "PARTIAL_PASS_STEP6A1" if passed else "NOT_PASS",
        "global_time_late_recovery": "CONFIRMED_STABLE" if passed else "NOT_CONFIRMED",
        "slave_global_time_counter": "PASS" if passed else "NOT_PASS",
        "slave_pps_snapshot": "PASS" if passed else "NOT_PASS",
        "master_slave_same_pps": "NOT_EVALUATED",
        "step6b": "NOT_RUN",
        "gate_pair_count": len(gates),
        "sample_count": len(samples),
        "runtime_invalid": runtime_invalid,
        "time_valid_rising_edges": rising_edges,
        "time_valid_falling_edges": falling_edges,
        "max_valid_streak": max_valid_streak,
        "max_terminal_streak": max_terminal_streak,
        "first_valid_ms": first_valid,
        "last_valid_ms": last_valid,
        "time_candidate_ever": time_candidate_ever,
        "formal_time_pass": formal_pass,
        "best_time_streak": best_streak,
        "best_count_advances": best_advances,
        "master": _board(samples, "MASTER"),
        "slave": _board(samples, "SLAVE"),
        "rows": samples,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_text(args.capture.read_text(encoding="utf-8", errors="replace"))
    output = json.dumps(result, indent=2, sort_keys=True)
    print(output)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(output + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
