"""Analyze the single-Slave-PTP-restart Step6A recovery capture.

The experiment is deliberately narrow: a validated pre-restart gate is
required, exactly one Slave ``ptp stop`` and one ``ptp start`` are injected,
and the post-start capture must show WR-extension re-arm, Master
re-engagement, and five consecutive valid Global-Time snapshots whose
snapshot counter advances at least twice.  This module never treats a
transient ``time_valid`` bit as a Step6 pass.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Callable


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
GATE_RE = re.compile(r"^S6_PTP_RESTART_GATE_PAIR\s+(?P<body>.*)$")
SAMPLE_RE = re.compile(r"^S6_PTP_RESTART_SAMPLE\s+(?P<body>.*)$")
GATE_RESULT_RE = re.compile(r"^S6_PTP_RESTART_GATE_RESULT=(?P<value>[^\s]+)")
INJECTION_RESULT_RE = re.compile(
    r"^S6_PTP_RESTART_INJECTION_RESULT=(?P<value>[^\s]+)"
)
CAPTURE_RESULT_RE = re.compile(
    r"^S6_PTP_RESTART_CAPTURE_RESULT=(?P<value>[^\s]+)"
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


def _max_streak(rows: list[dict[str, Any]], predicate: Callable[[dict[str, Any]], bool]) -> int:
    current = best = 0
    for row in rows:
        if predicate(row):
            current += 1
            best = max(best, current)
        else:
            current = 0
    return best


def _board(rows: list[dict[str, Any]], role: str) -> dict[str, Any]:
    selected = [
        row for row in rows if str(row.get("BOARD", "")).upper() == role
    ]
    valid = [row for row in selected if _int(row, "READ_VALID", 0) == 1]
    healthy = [row for row in valid if _int(row, "CAPTURE_HEALTHY", 0) == 1]
    return {
        "sample_count": len(selected),
        "read_valid_count": len(valid),
        "capture_healthy_count": len(healthy),
        "last_elapsed_ms": _int(selected[-1], "ELAPSED_MS") if selected else None,
        "rows": selected,
    }


def _runtime_invalid(rows: list[dict[str, Any]]) -> bool:
    return any(
        _int(row, "READ_VALID", 0) != 1
        or _int(row, "RESET_CHANGED", 0) == 1
        or _int(row, "CAPTURE_HEALTHY", 0) != 1
        for row in rows
    )


def _pll_ready(row: dict[str, Any]) -> bool:
    return _int(row, "SPLL_SEQ_STATE") == 8 and all(
        _int(row, key) == 1 for key in ("PSTAT_LOCKED", "MAIN_LOCKED")
    )


def _time_candidate(row: dict[str, Any]) -> bool:
    return (
        _int(row, "READ_VALID") == 1
        and _int(row, "CAPTURE_HEALTHY") == 1
        and _int(row, "STATUS_TIME_VALID") == 1
        and _int(row, "GLOBAL_TIME_SNAPSHOT_STABLE") == 1
        and _int(row, "GLOBAL_TIME_SNAPSHOT_VALID") == 1
        and _int(row, "GLOBAL_TIME_SNAPSHOT_TIME_VALID") == 1
        and _int(row, "GLOBAL_TIME_SNAPSHOT_PPS_VALID") == 1
    )


def _formal_time_recovery(rows: list[dict[str, Any]]) -> tuple[bool, int, int]:
    best_streak = best_advances = 0
    current: list[int] = []
    for row in rows:
        if not _time_candidate(row):
            current = []
            continue
        count = _int(row, "GLOBAL_TIME_SNAPSHOT_COUNT")
        if count is None:
            current = []
            continue
        current.append(count)
        if len(current) > 5:
            current = current[-5:]
        best_streak = max(best_streak, len(current))
        advances = sum(
            current[index] > current[index - 1]
            for index in range(1, len(current))
        )
        best_advances = max(best_advances, advances)
        if len(current) >= 5 and advances >= 2:
            return True, best_streak, best_advances
    return False, best_streak, best_advances


def analyze_text(text: str) -> dict[str, Any]:
    gates = _parse_rows(text, GATE_RE)
    samples = _parse_rows(text, SAMPLE_RE)
    gate_result = _scalar(text, GATE_RESULT_RE) or "MISSING"
    injection_result = _scalar(text, INJECTION_RESULT_RE) or "MISSING"
    capture_result = _scalar(text, CAPTURE_RESULT_RE) or "MISSING"

    master = _board(samples, "MASTER")
    slave = _board(samples, "SLAVE")
    master_rows = master["rows"]
    slave_rows = slave["rows"]
    runtime_invalid = _runtime_invalid(samples) or not master_rows or not slave_rows

    slave_rearm_rows = [
        row for row in slave_rows if _int(row, "SLAVE_REARM_EVIDENCE") == 1
    ]
    master_reengagement_rows = [
        row
        for row in samples
        if _int(row, "MASTER_REENGAGEMENT_EVIDENCE") == 1
    ]
    slave_rearmed = bool(slave_rearm_rows)
    master_reengaged = bool(master_reengagement_rows)
    handshake_rearmed = any(
        _int(row, "HANDSHAKE_REARMED") == 1
        or _int(row, "WR_STATE_VALUE") == 2
        for row in slave_rows
    )
    softpll_bad = _max_streak(slave_rows, lambda row: not _pll_ready(row)) >= 3
    time_candidate_ever = any(_time_candidate(row) for row in slave_rows)
    formal_time_pass, best_time_streak, best_count_advances = _formal_time_recovery(
        slave_rows
    )

    if gate_result != "PASS":
        classification = (
            gate_result
            if gate_result != "MISSING"
            else "INCONCLUSIVE_PRE_RESTART_STATE_CHANGED"
        )
        verdict = "INCONCLUSIVE"
        failure_class = "PRE_RESTART_GATE_NOT_PASS"
    elif injection_result != "PASS":
        classification = (
            injection_result
            if injection_result != "MISSING"
            else "INCONCLUSIVE_COMMAND_TRANSPORT"
        )
        verdict = "INCONCLUSIVE"
        failure_class = "SLAVE_PTP_RESTART_COMMAND_TRANSPORT"
    elif runtime_invalid:
        classification = "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
        verdict = "INCONCLUSIVE"
        failure_class = "RUNTIME_READ_OR_RESET_INVALID"
    elif softpll_bad:
        classification = "FAIL_SLAVE_PTP_RESTART_DISTURBED_SOFTPLL_READY_STATE"
        verdict = "FAIL"
        failure_class = "SOFTPLL_READY_STATE_DISTURBED"
    elif formal_time_pass and slave_rearmed and master_reengaged:
        classification = "PASS_SLAVE_PTP_RESTART_WR_EXTENSION_RECOVERY"
        verdict = "PASS"
        failure_class = ""
    elif not slave_rearmed:
        classification = "FAIL_SLAVE_PTP_RESTART_DID_NOT_REARM_WR_EXTENSION"
        verdict = "FAIL"
        failure_class = "PTP_RESTART_INSUFFICIENT_TO_REENTER_WR_HANDSHAKE"
    elif not master_reengaged:
        classification = "FAIL_SLAVE_REARMED_MASTER_NOT_REENGAGED"
        verdict = "FAIL"
        failure_class = "MASTER_WR_EXTENSION_NOT_REACTIVATED_BY_FRESH_SLAVE_PRESENT"
    elif handshake_rearmed and not time_candidate_ever:
        classification = "FAIL_WR_HANDSHAKE_REARMED_BUT_GLOBAL_TIME_NOT_RECOVERED"
        verdict = "FAIL"
        failure_class = "WR_HANDSHAKE_REARMED_GLOBAL_TIME_STILL_INVALID"
    elif time_candidate_ever:
        classification = "FAIL_TRANSIENT_GLOBAL_TIME_RECOVERY"
        verdict = "FAIL"
        failure_class = "GLOBAL_TIME_RECOVERY_STREAK_OR_COUNTER_INSUFFICIENT"
    else:
        classification = capture_result if capture_result != "MISSING" else "FAIL_RECOVERY_INCOMPLETE"
        verdict = "FAIL"
        failure_class = "RECOVERY_DID_NOT_MEET_FORMAL_GLOBAL_TIME_GATE"

    passed = classification == "PASS_SLAVE_PTP_RESTART_WR_EXTENSION_RECOVERY"
    return {
        "format": "step6-slave-ptp-restart-wr-extension-recovery-v1",
        "gate_result": gate_result,
        "injection_result": injection_result,
        "capture_result": capture_result,
        "classification": classification,
        "verdict": verdict,
        "failure_class": failure_class,
        "step6a_1": "PASS_POST_RECOVERY" if passed else "NOT_PASS",
        "step6a_global_time": "PARTIAL_PASS_STEP6A1" if passed else "NOT_PASS",
        "master_slave_same_pps": "NOT_EVALUATED",
        "step6b": "NOT_RUN",
        "gate_pair_count": len(gates),
        "sample_count": len(samples),
        "runtime_invalid": runtime_invalid,
        "slave_rearmed": slave_rearmed,
        "master_reengaged": master_reengaged,
        "handshake_rearmed": handshake_rearmed,
        "softpll_bad": softpll_bad,
        "time_candidate_ever": time_candidate_ever,
        "formal_time_pass": formal_time_pass,
        "best_time_streak": best_time_streak,
        "best_count_advances": best_count_advances,
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
