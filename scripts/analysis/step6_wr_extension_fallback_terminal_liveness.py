"""Analyze the read-only WR-extension fallback liveness capture.

The analyzer keeps the three outcomes from the experiment contract separate:
autonomous WR re-entry, terminal fallback with the SoftPLL ready, and terminal
fallback with the SoftPLL not ready.  It never turns a partial Step6 result
into a Global-Time or scheduled-trigger pass.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
SAMPLE_RE = re.compile(r"^WR_FALLBACK_LIVENESS_SAMPLE\s+(?P<body>.*)$")
GATE_RE = re.compile(r"^WR_FALLBACK_LIVENESS_GATE_PAIR\s+(?P<body>.*)$")
GATE_RESULT_RE = re.compile(r"^WR_FALLBACK_LIVENESS_GATE_RESULT=(?P<value>[^\s]+)")
CAPTURE_RESULT_RE = re.compile(
    r"^WR_FALLBACK_LIVENESS_CAPTURE_RESULT=(?P<value>[^\s]+)"
)
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


def _terminal_row(row: dict[str, Any]) -> bool:
    return all(
        _int(row, key) == value
        for key, value in (
            ("READ_VALID", 1),
            ("CAPTURE_HEALTHY", 1),
            ("WR_STATE_VALUE", 0),
            ("PTP_STATE", 9),
            ("PD_STATE", 4),
            ("EXT_STATE", 2),
            ("WRC_MODE", 3),
            ("STATUS_TIME_VALID", 0),
        )
    )


def _pll_ready_row(row: dict[str, Any]) -> bool:
    return _int(row, "SPLL_SEQ_STATE") == 8 and all(
        _int(row, key) == 1
        for key in (
            "PSTAT_LOCKED",
            "MAIN_ENABLED",
            "MAIN_FREQ_LOCKED",
            "MAIN_PHASE_LOCKED",
            "MAIN_LOCKED",
        )
    )


def _board_summary(rows: list[dict[str, Any]], *, slave: bool) -> dict[str, Any]:
    valid = [row for row in rows if _int(row, "READ_VALID", 0) == 1]
    healthy = [row for row in valid if _int(row, "CAPTURE_HEALTHY", 0) == 1]
    runtime_bad = [
        row
        for row in rows
        if _int(row, "READ_VALID", 0) != 1
        or _int(row, "RESET_CHANGED", 0) == 1
        or _int(row, "COUNTER_DECREASE", 0) == 1
        or _int(row, "CAPTURE_HEALTHY", 0) != 1
        or (slave and _int(row, "RX_PATTERN_READY", 0) != 1)
    ]
    terminal_rows = [row for row in rows if _terminal_row(row)] if slave else []
    ready_rows = [row for row in rows if _pll_ready_row(row)] if slave else []
    last = rows[-1] if rows else {}

    counter_keys = (
        "WR_LOCK_POLL_COUNT",
        "LOCK_ENABLE_COUNT",
        "SLOCK_TRACE_SEQ",
    )
    counter_values: dict[str, list[int]] = {}
    for key in counter_keys:
        counter_values[key] = [
            value
            for value in (_int(row, key) for row in rows)
            if value is not None
        ]
    counter_stable = bool(rows) and all(
        len(set(values)) <= 1 for values in counter_values.values()
    )

    return {
        "sample_count": len(rows),
        "read_valid_count": len(valid),
        "capture_healthy_count": len(healthy),
        "runtime_bad_count": len(runtime_bad),
        "terminal_row_count": len(terminal_rows),
        "terminal_all": bool(rows) and len(terminal_rows) == len(rows),
        "counter_values": counter_values,
        "fallback_counters_stable": counter_stable,
        "pll_ready_streak": _max_streak(rows, _pll_ready_row) if slave else 0,
        "pll_ready_sample_count": len(ready_rows),
        "first_ptp_state": _int(rows[0], "PTP_STATE") if rows else None,
        "last_ptp_state": _int(last, "PTP_STATE"),
        "last_pd_state": _int(last, "PD_STATE"),
        "last_ext_state": _int(last, "EXT_STATE"),
        "last_wrc_mode": _int(last, "WRC_MODE"),
        "last_time_valid": _int(last, "STATUS_TIME_VALID"),
        "rows": rows,
    }


def analyze_text(text: str) -> dict[str, Any]:
    samples = _parse_rows(text, SAMPLE_RE)
    gates = _parse_rows(text, GATE_RE)
    gate_result = _scalar(text, GATE_RESULT_RE) or "MISSING"
    capture_result = _scalar(text, CAPTURE_RESULT_RE) or "MISSING"
    master_rows = [
        row for row in samples if str(row.get("BOARD", "")).upper() == "MASTER"
    ]
    slave_rows = [
        row for row in samples if str(row.get("BOARD", "")).upper() == "SLAVE"
    ]
    master = _board_summary(master_rows, slave=False)
    slave = _board_summary(slave_rows, slave=True)

    reentry_rows = [
        row
        for row in slave_rows
        if _int(row, "REENTRY_COUNTER_INCREASE", 0) == 1
        or _int(row, "WR_STATE_VALUE", 0) != 0
        or _int(row, "EXT_STATE", 0) != 2
        or _int(row, "STATUS_TIME_VALID", 0) == 1
    ]
    autonomous_reentry = bool(reentry_rows)
    recovery_event_observed = any(
        _int(row, "STATUS_TIME_VALID", 0) == 1
        and _int(row, "EXT_STATE", 0) != 2
        for row in reentry_rows
    )

    runtime_invalid = (
        capture_result == "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
        or any(
            _int(row, "READ_VALID", 0) != 1
            or _int(row, "RESET_CHANGED", 0) == 1
            or _int(row, "COUNTER_DECREASE", 0) == 1
            or _int(row, "CAPTURE_HEALTHY", 0) != 1
            for row in samples
        )
        or not master_rows
        or not slave_rows
    )

    terminal_fallback_live = (
        capture_result == "PASS_CAPTURE"
        and not runtime_invalid
        and slave["terminal_all"]
        and slave["fallback_counters_stable"]
    )
    pll_ready = terminal_fallback_live and slave["pll_ready_streak"] >= 5

    if gate_result != "PASS":
        classification = (
            gate_result
            if gate_result != "MISSING"
            else "INCONCLUSIVE_FALLBACK_PRECONDITION_CHANGED"
        )
        verdict = "INCONCLUSIVE"
        liveness = "NOT_EVALUATED"
    elif autonomous_reentry or capture_result == "WR_EXTENSION_AUTONOMOUS_REENTRY_OBSERVED":
        classification = "WR_EXTENSION_AUTONOMOUS_REENTRY_OBSERVED"
        verdict = "EVENT"
        liveness = "AUTONOMOUS_REENTRY_OBSERVED"
    elif runtime_invalid:
        classification = "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
        verdict = "INCONCLUSIVE"
        liveness = "INCONCLUSIVE"
    elif not terminal_fallback_live:
        classification = "INCONCLUSIVE_FALLBACK_NOT_TERMINAL"
        verdict = "INCONCLUSIVE"
        liveness = "NOT_TERMINAL"
    elif pll_ready:
        classification = "PASS_TERMINAL_WR_FALLBACK_WITH_PLL_READY"
        verdict = "PASS"
        liveness = "TERMINAL_NO_AUTONOMOUS_RETRY"
    else:
        classification = "PASS_TERMINAL_WR_FALLBACK_WITH_PLL_NOT_READY"
        verdict = "PASS"
        liveness = "TERMINAL_NO_AUTONOMOUS_RETRY"

    failure_class = (
        "WR_EXTENSION_DISABLED_WHILE_SOFTPLL_READY"
        if classification == "PASS_TERMINAL_WR_FALLBACK_WITH_PLL_READY"
        else (
            "WR_EXTENSION_DISABLED_AND_SOFTPLL_NOT_READY"
            if classification == "PASS_TERMINAL_WR_FALLBACK_WITH_PLL_NOT_READY"
            else ""
        )
    )
    return {
        "format": "step6-wr-extension-fallback-terminal-liveness-v1",
        "gate_result": gate_result,
        "capture_result": capture_result,
        "classification": classification,
        "verdict": verdict,
        "wr_extension_fallback_liveness": liveness,
        "step6a_recovery_event": "OBSERVED" if recovery_event_observed else "NOT_OBSERVED",
        "failure_class": failure_class,
        "step6a": "NOT_PASS",
        "step6b": "NOT_RUN",
        "gate_pair_count": len(gates),
        "sample_count": len(samples),
        "autonomous_reentry": autonomous_reentry,
        "runtime_invalid": runtime_invalid,
        "terminal_fallback_live": terminal_fallback_live,
        "pll_ready": pll_ready,
        "master": master,
        "slave": slave,
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
