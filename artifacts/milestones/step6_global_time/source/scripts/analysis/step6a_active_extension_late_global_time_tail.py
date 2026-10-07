"""Analyze the read-only Step6A active-extension late-tail observation."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
INVALID = {"", "INVALID", "TIMEOUT", "NA", "N/A", "UNKNOWN"}


def _value(value: str) -> int | str:
    try:
        return int(value, 0)
    except ValueError:
        try:
            return int(value, 10)
        except ValueError:
            return value


def _rows(text: str, prefix: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith(prefix):
            continue
        body = line[len(prefix) :].lstrip(" =")
        rows.append({key.upper(): _value(value) for key, value in FIELD_RE.findall(body)})
    return rows


def _scalar(text: str, prefix: str) -> str | None:
    result: str | None = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith(prefix):
            body = line[len(prefix) :].lstrip(" =")
            result = body.split()[0] if body else None
    return result


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
            return default


def analyze_text(text: str) -> dict[str, Any]:
    result_rows = _rows(text, "S6A_TAIL_RESULT")
    result = _scalar(text, "S6A_TAIL_RESULT") or "MISSING"
    row = result_rows[-1] if result_rows else {}
    gate_pairs = _int(row, "GATE_PAIRS", 0) or 0
    tail_samples = _int(row, "TAIL_SAMPLES", 0) or 0
    valid_samples = _int(row, "VALID_SAMPLES", 0) or 0
    max_valid_streak = _int(row, "MAX_VALID_STREAK", 0) or 0
    snapshot_delta = _int(row, "SNAPSHOT_DELTA", 0) or 0
    common_tai_count = _int(row, "COMMON_TAI_COUNT", 0) or 0
    max_delta = _int(row, "MAX_ABS_DELTA_TICKS")
    coherence_violation = _int(row, "COHERENCE_VIOLATION", 1)
    formal_pass = (
        result == "PASS_ACTIVE_EXTENSION_LATE_GLOBAL_TIME_RECOVERY"
        and gate_pairs >= 3
        and tail_samples > 0
        and max_valid_streak >= 5
        and snapshot_delta >= 2
        and common_tai_count >= 3
        and max_delta == 0
        and coherence_violation == 0
    )
    if formal_pass:
        classification = "PASS_ACTIVE_EXTENSION_LATE_GLOBAL_TIME_RECOVERY"
        verdict = "PASS"
    elif result == "MISSING":
        classification = "INCONCLUSIVE_MISSING_OBSERVER_RESULT"
        verdict = "INCONCLUSIVE"
    elif result.startswith("FAIL_"):
        classification = result
        verdict = "FAIL"
    else:
        classification = result
        verdict = "INCONCLUSIVE"
    return {
        "format": "step6a-active-extension-late-global-time-tail-v1",
        "classification": classification,
        "verdict": verdict,
        "step6a_requalification": "PASS" if formal_pass else "NOT_PASS",
        "step6b_1": "NOT_RUN",
        "physical_edge": "NOT_EVALUATED",
        "gate_pairs": gate_pairs,
        "tail_samples": tail_samples,
        "valid_samples": valid_samples,
        "max_valid_streak": max_valid_streak,
        "first_valid_ms": _int(row, "FIRST_VALID_MS", -1),
        "last_valid_ms": _int(row, "LAST_VALID_MS", -1),
        "snapshot_delta": snapshot_delta,
        "common_tai_count": common_tai_count,
        "max_abs_delta_ticks": max_delta,
        "max_abs_delta_ns": max_delta * 8 if max_delta is not None else None,
        "time_valid_rising": _int(row, "TIME_VALID_RISING", 0) or 0,
        "time_valid_falling": _int(row, "TIME_VALID_FALLING", 0) or 0,
        "active_samples": _int(row, "ACTIVE_SAMPLES", 0) or 0,
        "coherence_violation": coherence_violation,
        "observer_result": result,
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
