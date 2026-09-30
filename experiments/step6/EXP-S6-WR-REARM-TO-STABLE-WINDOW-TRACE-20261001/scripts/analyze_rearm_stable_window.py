#!/usr/bin/env python3
"""Conservatively validate the Step 6 re-arm and sampled stable-offset trace."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
from typing import Any


PASS_REASON = "PASS_300S_SAMPLED_STABLE_OFFSET"
U32 = 1 << 32


def parse_fields(line: str) -> dict[str, str]:
    return {key.upper(): value for key, value in re.findall(r"([A-Za-z][A-Za-z0-9_]*)=([^\s]+)", line)}


def number(row: dict[str, str], key: str) -> int | None:
    value = row.get(key.upper())
    if value is None or value in {"NA", "INVALID", "TIMEOUT", "SKIPPED"}:
        return None
    try:
        if key.upper().endswith("_RAW"):
            return int(value.removeprefix("0x"), 16)
        return int(value, 10)
    except (TypeError, ValueError):
        return None


def _has_required_gates(row: dict[str, str]) -> bool:
    expected_ones = (
        "ROW_RAW_VALID", "RESET_SIGNATURE_VALID", "STEP1_GATE", "DIAG_FRAME_VALID",
        "GLOBAL_FRAME_VALID", "GLOBAL_TIME_OK", "HELPER_LOCK", "MAIN_ENABLED",
        "MAIN_FREQ_LOCK", "MAIN_PHASE_LOCK", "MAIN_LOCK", "PSTAT_LOCK",
    )
    if any(number(row, key) != 1 for key in expected_ones):
        return False
    if number(row, "RESET_CHANGED") != 0 or number(row, "SERVO_STATE") != 4:
        return False
    offset = number(row, "CKO_PS")
    if offset is None or abs(offset) >= 60:
        return False
    if number(row, "FAILURE_DELTA_U8") != 0:
        return False
    if number(row, "WR_DISABLE_VALID") == 1:
        return False
    return True


def analyze_text(text: str) -> dict[str, Any]:
    rows = [parse_fields(line) for line in text.splitlines() if line.startswith("S6R_SAMPLE ")]
    stop_lines = [parse_fields(line) for line in text.splitlines() if line.startswith("S6R_STOP ")]
    summary_lines = [parse_fields(line) for line in text.splitlines() if line.startswith("S6R_SUMMARY ")]
    stop = stop_lines[-1] if stop_lines else (summary_lines[-1] if summary_lines else {})
    reason = stop.get("REASON", stop.get("STOP_REASON", "MISSING_STOP"))
    summary = summary_lines[-1] if summary_lines else {}

    result: dict[str, Any] = {
        "verdict": "NOT_ESTABLISHED",
        "stop_reason": reason,
        "samples": len(rows),
        "raw_valid_rows": sum(number(row, "ROW_RAW_VALID") == 1 for row in rows),
        "recovery_admission_supported": number(summary, "RECOVERY_ADMISSION_SUPPORTED") == 1,
        "stable_window_started": number(summary, "STABLE_WINDOW_STARTED") == 1,
        "stable_unique_rows": 0,
        "stable_elapsed_ms": number(summary, "STABLE_WINDOW_ELAPSED_MS"),
        "maximum_unique_observation_gap_ms": None,
        "offset_min_ps": None,
        "offset_max_ps": None,
        "atomic_cross_group_causality_claimed": False,
    }

    if not rows or not summary:
        result["verdict"] = "INCONCLUSIVE_MISSING_ROWS_OR_SUMMARY"
        return result
    if reason != PASS_REASON:
        return result
    if not result["recovery_admission_supported"] or not result["stable_window_started"]:
        result["verdict"] = "INCONCLUSIVE_PASS_WITHOUT_ADMISSION_OR_WINDOW"
        return result

    stable = [row for row in rows if number(row, "STABLE_WINDOW_STARTED") == 1]
    if not stable:
        result["verdict"] = "INCONCLUSIVE_PASS_WITHOUT_STABLE_ROWS"
        return result
    start_values = {number(row, "STABLE_WINDOW_START_MS") for row in stable}
    start_values.discard(None)
    if len(start_values) != 1:
        result["verdict"] = "INCONCLUSIVE_STABLE_START_MISMATCH"
        return result
    start_ms = next(iter(start_values))

    for row in stable:
        if not _has_required_gates(row):
            result["verdict"] = "REJECTED_QUALIFICATION_LOSS_IN_PASS_WINDOW"
            return result

    fresh = [row for row in stable if row.get("PUB_STATUS") in {"FIRST", "ADVANCE"}]
    if len(fresh) < 2:
        result["verdict"] = "REJECTED_TOO_FEW_FRESH_PUBLICATIONS"
        return result
    reported_unique = number(summary, "STABLE_WINDOW_ROWS")
    if reported_unique is None or reported_unique != len(fresh):
        result["verdict"] = "REJECTED_UNIQUE_ROW_COUNT_MISMATCH"
        return result

    times: list[int] = []
    offsets: list[int] = []
    previous_ucnt: int | None = None
    gaps: list[int] = []
    for row in fresh:
        timestamp = number(row, "ELAPSED_MS")
        ucnt = number(row, "UCNT")
        offset = number(row, "CKO_PS")
        if timestamp is None or ucnt is None or offset is None:
            result["verdict"] = "REJECTED_INVALID_FRESH_ROW"
            return result
        if previous_ucnt is not None:
            delta = (ucnt - previous_ucnt) & 0xFFFFFFFF
            if delta == 0 or delta > 128 or delta >= 0x80000000:
                result["verdict"] = "REJECTED_UCNT_NOT_ADVANCING"
                return result
            gaps.append(timestamp - times[-1])
        previous_ucnt = ucnt
        times.append(timestamp)
        offsets.append(offset)

    if times[0] < start_ms or times[-1] - start_ms < 300_000:
        result["verdict"] = "REJECTED_STABLE_WINDOW_SHORTER_THAN_300S"
        return result
    reported_elapsed = number(summary, "STABLE_WINDOW_ELAPSED_MS")
    if reported_elapsed is not None and reported_elapsed != times[-1] - start_ms:
        result["verdict"] = "REJECTED_STABLE_ELAPSED_MISMATCH"
        return result
    if any(gap <= 0 or gap > 1_000 for gap in gaps):
        result["verdict"] = "REJECTED_UNIQUE_PUBLICATION_GAP_GT_1S"
        return result
    result.update(
        verdict=PASS_REASON,
        stable_unique_rows=len(fresh),
        stable_elapsed_ms=times[-1] - start_ms,
        maximum_unique_observation_gap_ms=max(gaps, default=0),
        offset_min_ps=min(offsets),
        offset_max_ps=max(offsets),
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_text(args.log.read_text(encoding="utf-8", errors="replace"))
    rendered = json.dumps(result, indent=2, sort_keys=True)
    if args.json_out:
        args.json_out.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
