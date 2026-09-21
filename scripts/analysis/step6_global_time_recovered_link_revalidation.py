"""Analyze the read-only Step6A-1 recovered-link Global-Time capture."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
SAMPLE_RE = re.compile(r"^GLOBAL_TIME_REVALIDATION_SAMPLE\s+(?P<body>.*)$")
GATE_RE = re.compile(r"^GLOBAL_TIME_REVALIDATION_GATE_PAIR\s+(?P<body>.*)$")
GATE_RESULT_RE = re.compile(r"^GLOBAL_TIME_GATE_RESULT=(?P<value>[^\s]+)")
CAPTURE_RESULT_RE = re.compile(r"^GLOBAL_TIME_CAPTURE_RESULT=(?P<value>[^\s]+)")
INVALID = {"", "INVALID", "TIMEOUT", "NA", "N/A", "UNKNOWN"}
REFERENCE_CLOCK_HZ = 125_000_000
SNAPSHOT_MODULUS = 1 << 16


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
            {key.upper(): _value(value) for key, value in FIELD_RE.findall(match.group("body"))}
        )
    return rows


def _scalar(text: str, pattern: re.Pattern[str]) -> str | None:
    value: str | None = None
    for line in text.splitlines():
        match = pattern.match(line.strip())
        if match:
            value = match.group("value")
    return value


def _max_streak(rows: list[dict[str, Any]], predicate) -> int:
    current = best = 0
    for row in rows:
        if predicate(row):
            current += 1
            best = max(best, current)
        else:
            current = 0
    return best


def _board_analysis(rows: list[dict[str, Any]]) -> dict[str, Any]:
    read_valid_rows = [row for row in rows if _int(row, "READ_VALID", 0) == 1]
    stable_rows = [row for row in read_valid_rows if _int(row, "STABLE", 0) == 1]
    healthy_rows = [row for row in stable_rows if _int(row, "LINK_HEALTHY", 0) == 1]
    time_rows = [
        row for row in healthy_rows
        if _int(row, "STATUS_TIME_VALID", 0) == 1
        and _int(row, "STATUS_PPS_VALID", 0) == 1
        and _int(row, "SNAPSHOT_VALID", 0) == 1
        and _int(row, "SNAPSHOT_TIME_VALID", 0) == 1
        and _int(row, "SNAPSHOT_PPS_VALID", 0) == 1
    ]

    def time_good(row: dict[str, Any]) -> bool:
        return row in time_rows

    snapshot_count_decreased = False
    snapshot_advances = 0
    snapshot_counts: list[int] = []
    snapshot_cycles_valid = True
    previous_count: int | None = None
    for row in time_rows:
        count = _int(row, "SNAPSHOT_COUNT")
        cycles = _int(row, "CYCLES")
        if count is None or cycles is None:
            snapshot_cycles_valid = False
            continue
        snapshot_counts.append(count)
        if not 0 <= cycles <= REFERENCE_CLOCK_HZ - 1:
            snapshot_cycles_valid = False
        if previous_count is not None:
            if count < previous_count:
                snapshot_count_decreased = True
            delta = (count - previous_count) % SNAPSHOT_MODULUS
            if delta > 0:
                snapshot_advances += delta
        previous_count = count

    live_ticks: list[int] = []
    live_bad_steps = 0
    for row in time_rows:
        tai_lo = _int(row, "LIVE_TAI_LO")
        cycles = _int(row, "LIVE_CYCLES")
        if tai_lo is None or cycles is None:
            live_bad_steps += 1
            continue
        live_ticks.append(tai_lo * REFERENCE_CLOCK_HZ + cycles)
    for previous, current in zip(live_ticks, live_ticks[1:]):
        if current <= previous:
            live_bad_steps += 1

    time_streak = _max_streak(healthy_rows, time_good)
    time_valid_pass = time_streak >= 5
    snapshot_pass = (
        bool(time_rows)
        and snapshot_advances >= 2
        and snapshot_cycles_valid
        and not snapshot_count_decreased
    )
    live_monotonic_pass = len(live_ticks) >= 2 and live_bad_steps == 0
    local_pass = time_valid_pass and snapshot_pass and live_monotonic_pass

    last = rows[-1] if rows else {}
    return {
        "sample_count": len(rows),
        "read_valid_count": len(read_valid_rows),
        "stable_count": len(stable_rows),
        "healthy_count": len(healthy_rows),
        "time_valid_count": len(time_rows),
        "time_valid_streak": time_streak,
        "time_valid_pass": time_valid_pass,
        "snapshot_counts": snapshot_counts,
        "snapshot_advances": snapshot_advances,
        "snapshot_count_decreased": snapshot_count_decreased,
        "snapshot_cycles_valid": snapshot_cycles_valid,
        "snapshot_pass": snapshot_pass,
        "live_sample_count": len(live_ticks),
        "live_bad_steps": live_bad_steps,
        "live_monotonic_pass": live_monotonic_pass,
        "local_pass": local_pass,
        "link_healthy_all_samples": bool(rows) and len(healthy_rows) == len(rows),
        "last_ptp_state": _int(last, "PTP_STATE", -1),
        "last_pd_state": _int(last, "PD_STATE", -1),
        "last_ext_state": _int(last, "EXT_STATE", -1),
        "last_wrc_mode": _int(last, "WRC_MODE", -1),
        "rows": rows,
    }


def analyze_text(text: str) -> dict[str, Any]:
    samples = _parse_rows(text, SAMPLE_RE)
    gates = _parse_rows(text, GATE_RE)
    gate_result = _scalar(text, GATE_RESULT_RE) or "MISSING"
    capture_result = _scalar(text, CAPTURE_RESULT_RE) or "MISSING"
    master_rows = [row for row in samples if str(row.get("BOARD", "")).upper() == "MASTER"]
    slave_rows = [row for row in samples if str(row.get("BOARD", "")).upper() == "SLAVE"]
    master = _board_analysis(master_rows)
    slave = _board_analysis(slave_rows)

    runtime_invalid = (
        capture_result != "PASS_CAPTURE"
        or any(_int(row, "READ_VALID", 0) != 1 for row in samples)
        or any(_int(row, "RESET_CHANGED", 0) == 1 for row in samples)
        or any(_int(row, "LINK_HEALTHY", 0) != 1 for row in samples)
    )

    if gate_result != "PASS":
        classification = gate_result if gate_result != "MISSING" else "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
        verdict = "INCONCLUSIVE"
        step6a1 = "NOT_EVALUATED"
    elif runtime_invalid:
        classification = "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
        verdict = "INCONCLUSIVE"
        step6a1 = "INCONCLUSIVE"
    elif not samples:
        classification = "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
        verdict = "INCONCLUSIVE"
        step6a1 = "INCONCLUSIVE"
    elif not slave["time_valid_pass"]:
        classification = "FAIL_SLAVE_GLOBAL_TIME_NOT_VALID_AFTER_LINK_RECOVERY"
        verdict = "FAIL"
        step6a1 = "FAIL"
    elif not master["time_valid_pass"]:
        classification = "FAIL_MASTER_GLOBAL_TIME_NOT_VALID"
        verdict = "FAIL"
        step6a1 = "FAIL"
    elif not master["snapshot_pass"] or not slave["snapshot_pass"]:
        classification = "FAIL_GLOBAL_TIME_PPS_SNAPSHOT_NOT_ADVANCING"
        verdict = "FAIL"
        step6a1 = "FAIL"
    elif not master["live_monotonic_pass"] or not slave["live_monotonic_pass"]:
        classification = "FAIL_GLOBAL_TIME_MONOTONICITY"
        verdict = "FAIL"
        step6a1 = "FAIL"
    elif not master["local_pass"] or not slave["local_pass"]:
        classification = "FAIL_GLOBAL_TIME_COUNTER_CRITERIA"
        verdict = "FAIL"
        step6a1 = "FAIL"
    else:
        classification = "GLOBAL_TIME_RECOVERY_PASS"
        verdict = "PARTIAL_PASS"
        step6a1 = "PASS"

    failure_class = ""
    if (
        classification == "FAIL_SLAVE_GLOBAL_TIME_NOT_VALID_AFTER_LINK_RECOVERY"
        and slave["last_ptp_state"] == 9
        and slave["last_pd_state"] == 4
        and slave["last_ext_state"] == 2
        and slave["last_wrc_mode"] == 3
    ):
        failure_class = "FAIL_GLOBAL_TIME_BLOCKED_BY_WR_EXTENSION_PTP_FALLBACK"

    return {
        "format": "step6-global-time-recovered-link-revalidation-v1",
        "gate_result": gate_result,
        "capture_result": capture_result,
        "classification": classification,
        "verdict": verdict,
        "step6a_1": step6a1,
        "step6a_global_time": "PARTIAL_PASS_STEP6A1" if step6a1 == "PASS" else "NOT_PASS",
        "step6b": "NOT_RUN",
        "failure_class": failure_class,
        "gate_pair_count": len(gates),
        "sample_count": len(samples),
        "master": master,
        "slave": slave,
        "master_global_time_counter": "PASS" if master["local_pass"] else "FAIL",
        "slave_global_time_counter": "PASS" if slave["local_pass"] else "FAIL",
        "master_slave_same_pps": "NOT_EVALUATED",
        "rows": samples,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_text(args.capture.read_text(encoding="utf-8", errors="replace"))
    encoded = json.dumps(result, indent=2, ensure_ascii=False)
    if args.json_out:
        args.json_out.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
