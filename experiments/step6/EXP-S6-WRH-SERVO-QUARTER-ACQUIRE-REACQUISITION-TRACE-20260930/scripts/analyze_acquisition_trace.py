#!/usr/bin/env python3
"""Summarize the dedicated Step 6 acquisition trace without inferring causality."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
import re
import sys
from typing import Any


def parse_fields(line: str) -> dict[str, str]:
    return {
        key: value
        for key, value in re.findall(r"([A-Za-z][A-Za-z0-9_]*)=([^\s]+)", line)
    }


def as_int(row: dict[str, str], key: str) -> int | None:
    try:
        return int(row[key], 10)
    except (KeyError, TypeError, ValueError):
        try:
            return int(row[key], 0)
        except (KeyError, TypeError, ValueError):
            return None


def structurally_valid(row: dict[str, str]) -> bool:
    required_flags = {
        "READS_VALID": 1,
        "DIAG_FRAME_VALID": 1,
        "PHASE_CONTEXT_FRAME_VALID": 1,
        "PHASE_CONTEXT_MATCH": 1,
        "RESET_CHANGED": 0,
    }
    if any(as_int(row, key) != expected for key, expected in required_flags.items()):
        return False
    numeric_fields = (
        "SERVO_STATE",
        "CKO_PS",
        "UCNT",
        "PHASE_CONTEXT_UCNT",
        "SETP_PS",
        "DMS_PS",
    )
    if any(as_int(row, key) is None for key in numeric_fields):
        return False
    if as_int(row, "UCNT") != as_int(row, "PHASE_CONTEXT_UCNT"):
        return False
    reset_fields = (
        "BOOT_GENERATION",
        "CPU_RESET_COUNT",
        "WR_CORE_RESET_COUNT",
        "SI_CONFIG_DROP_COUNT",
    )
    return all(as_int(row, key) is not None for key in reset_fields)


def trusted_samples(text: str) -> tuple[list[dict[str, str]], list[dict[str, str]], int]:
    all_rows: list[dict[str, str]] = []
    trusted: list[dict[str, str]] = []
    flag_mismatches = 0
    for line in text.splitlines():
        if not line.startswith("S6_ACQ_SAMPLE "):
            continue
        row = parse_fields(line)
        all_rows.append(row)
        derived = structurally_valid(row)
        asserted = as_int(row, "STRUCTURALLY_TRUSTED_ROW") == 1
        if derived != asserted:
            flag_mismatches += 1
        if derived and asserted:
            trusted.append(row)
    return all_rows, trusted, flag_mismatches


def _range(values: list[int]) -> str:
    return f"{min(values)}..{max(values)}" if values else "NA"


def _delta_summary(values: list[int]) -> tuple[int, int | None]:
    jumps = [abs(value) for value in values]
    return sum(value >= 120 for value in jumps), max(jumps) if jumps else None


def analyze_text(text: str) -> dict[str, Any]:
    all_rows, trusted, flag_mismatches = trusted_samples(text)
    stop_records = [
        parse_fields(line)
        for line in text.splitlines()
        if line.startswith("S6_ACQ_STOP ")
    ]
    stop = stop_records[-1] if stop_records else {}
    stop_reason = stop.get("STOP_REASON", "MISSING_STOP_RECORD")
    requested_ms = as_int(stop, "REQUESTED_DURATION_MS")
    elapsed_ms = as_int(stop, "ELAPSED_MS")

    states = Counter(
        str(as_int(row, "SERVO_STATE"))
        for row in trusted
        if as_int(row, "SERVO_STATE") is not None
    )
    cko = [v for row in trusted if (v := as_int(row, "CKO_PS")) is not None]
    dms = [v for row in trusted if (v := as_int(row, "DMS_PS")) is not None]
    setp = [v for row in trusted if (v := as_int(row, "SETP_PS")) is not None]
    global_valid = sum(as_int(row, "GLOBAL_TIME_VALID") == 1 for row in trusted)
    step1_pass = sum(as_int(row, "STEP1_GATE") == 1 for row in trusted)
    lock_keys = (
        "HELPER_LOCK",
        "MAIN_FREQ_LOCK",
        "MAIN_PHASE_LOCK",
        "MAIN_LOCK",
        "PSTAT_LOCK",
    )
    lock_counts = {key: sum(as_int(row, key) == 1 for row in trusted) for key in lock_keys}
    all_trusted_health = bool(trusted) and step1_pass == len(trusted) and all(
        lock_counts[key] == len(trusted) for key in lock_keys
    )

    adjacent: list[tuple[dict[str, str], dict[str, str]]] = []
    for left, right in zip(trusted, trusted[1:]):
        left_n = as_int(left, "sample")
        right_n = as_int(right, "sample")
        if left_n is not None and right_n == left_n + 1:
            adjacent.append((left, right))

    delta_cko: list[int] = []
    delta_dms: list[int] = []
    delta_setp: list[int] = []
    delta_residual: list[int] = []
    sync_step_rows: list[dict[str, int | None]] = []
    for left, right in adjacent:
        lc, rc = as_int(left, "CKO_PS"), as_int(right, "CKO_PS")
        ld, rd = as_int(left, "DMS_PS"), as_int(right, "DMS_PS")
        ls, rs = as_int(left, "SETP_PS"), as_int(right, "SETP_PS")
        if lc is not None and rc is not None:
            delta_cko.append(rc - lc)
        if ld is not None and rd is not None:
            delta_dms.append(rd - ld)
        if ls is not None and rs is not None:
            step = rs - ls
            delta_setp.append(step)
            if as_int(left, "SERVO_STATE") == 3:
                sync_step_rows.append(
                    {
                        "sample": as_int(left, "sample"),
                        "ucnt": as_int(left, "UCNT"),
                        "cko_before": lc,
                        "setp_before": ls,
                        "setp_after": rs,
                        "delta_setp": step,
                        "dms_before": ld,
                        "dms_after": rd,
                        "delta_dms": None if ld is None or rd is None else rd - ld,
                        "expected_cko_div4": None if lc is None else int(lc / 4),
                    }
                )
        if all(value is not None for value in (lc, rc, ld, rd)):
            delta_residual.append((rc - rd) - (lc - ld))

    sstat4_observed = any(as_int(row, "SERVO_STATE") == 4 for row in trusted)
    full_window = requested_ms == 600000 and elapsed_ms is not None and elapsed_ms >= 600000
    coverage = len(trusted) / len(all_rows) if all_rows else 0.0
    known_acquisition_states = bool(states) and set(states).issubset({"3", "5"})
    adequate_full_window = (
        requested_ms == 600000
        and elapsed_ms is not None
        and elapsed_ms >= 600000
        and len(trusted) >= 1000
        and coverage >= 0.95
        and all_trusted_health
        and known_acquisition_states
        and flag_mismatches == 0
    )
    if sstat4_observed:
        result = "ACQUISITION_REACQUIRED"
    elif stop_reason == "DURATION_LIMIT" and full_window and adequate_full_window:
        result = "REPRODUCIBLE_ACQUISITION_FAILURE_OBSERVED"
    elif stop_reason == "DURATION_LIMIT" and full_window:
        result = "INCONCLUSIVE_STRUCTURAL_COVERAGE"
    elif stop_reason == "FIVE_CONSECUTIVE_STRUCTURALLY_INVALID_ROWS":
        result = "INCONCLUSIVE_STRUCTURAL_COVERAGE"
    else:
        result = f"STOPPED_EARLY_{stop_reason}"

    return {
        "result": result,
        "stop_reason": stop_reason,
        "requested_ms": requested_ms,
        "elapsed_ms": elapsed_ms,
        "last_row_start_ms": stop.get("LAST_ROW_START_MS", "NA"),
        "last_row_end_ms": stop.get("LAST_ROW_END_MS", "NA"),
        "sample_count": len(all_rows),
        "structurally_trusted_count": len(trusted),
        "structural_coverage": coverage,
        "structural_flag_mismatches": flag_mismatches,
        "adequate_full_window": adequate_full_window,
        "known_acquisition_states_only": known_acquisition_states,
        "step6_qualifying_count": sum(
            as_int(row, "STEP6_QUALIFYING_ROW") == 1 for row in all_rows
        ),
        "global_valid_trusted_count": global_valid,
        "step1_pass_trusted_count": step1_pass,
        "lock_counts": lock_counts,
        "state_counts": dict(states),
        "track_phase_observed": sstat4_observed,
        "latch_trigger_established": sstat4_observed,
        "cko_range_ps": _range(cko),
        "dms_range_ps": _range(dms),
        "setp_range_ps": _range(setp),
        "setp_distinct_count": len(set(setp)),
        "adjacent_trusted_pairs": len(adjacent),
        "delta_cko_ge_120_count": _delta_summary(delta_cko)[0],
        "delta_cko_max_abs_ps": _delta_summary(delta_cko)[1],
        "delta_dms_ge_120_count": _delta_summary(delta_dms)[0],
        "delta_dms_max_abs_ps": _delta_summary(delta_dms)[1],
        "delta_setp_ge_120_count": _delta_summary(delta_setp)[0],
        "delta_setp_max_abs_ps": _delta_summary(delta_setp)[1],
        "delta_residual_ge_120_count": _delta_summary(delta_residual)[0],
        "delta_residual_max_abs_ps": _delta_summary(delta_residual)[1],
        "sync_step_rows": sync_step_rows,
    }


def render(summary: dict[str, Any]) -> str:
    latch = "ESTABLISHED_BY_TRACK_SAMPLE" if summary["latch_trigger_established"] else "NOT_ESTABLISHED"
    lines = [
        f"RESULT={summary['result']}",
        f"STOP_REASON={summary['stop_reason']}",
        f"REQUESTED_DURATION_MS={summary['requested_ms']}",
        f"ELAPSED_MS={summary['elapsed_ms']}",
        f"LAST_ROW_START_MS={summary['last_row_start_ms']}",
        f"LAST_ROW_END_MS={summary['last_row_end_ms']}",
        f"SAMPLE_COUNT={summary['sample_count']}",
        f"STRUCTURALLY_TRUSTED_COUNT={summary['structurally_trusted_count']}",
        f"STRUCTURAL_COVERAGE={summary['structural_coverage']:.4f}",
        f"STRUCTURAL_FLAG_MISMATCHES={summary['structural_flag_mismatches']}",
        f"ADEQUATE_FULL_WINDOW={int(summary['adequate_full_window'])}",
        f"STEP6_QUALIFYING_COUNT={summary['step6_qualifying_count']}",
        f"GLOBAL_VALID_TRUSTED_COUNT={summary['global_valid_trusted_count']}",
        f"STEP1_PASS_TRUSTED_COUNT={summary['step1_pass_trusted_count']}",
        f"SERVO_STATE_COUNTS={summary['state_counts']}",
        f"TRACK_PHASE_OBSERVED={int(summary['track_phase_observed'])}",
        f"FIXED_SETP_LATCH_TRIGGER={latch}",
        f"CKO_RANGE_PS={summary['cko_range_ps']}",
        f"DMS_RANGE_PS={summary['dms_range_ps']}",
        f"SETP_RANGE_PS={summary['setp_range_ps']}",
        f"SETP_DISTINCT_COUNT={summary['setp_distinct_count']}",
        f"ADJACENT_TRUSTED_PAIRS={summary['adjacent_trusted_pairs']}",
        f"DELTA_CKO_GE_120_COUNT={summary['delta_cko_ge_120_count']}",
        f"DELTA_CKO_MAX_ABS_PS={summary['delta_cko_max_abs_ps']}",
        f"DELTA_DMS_GE_120_COUNT={summary['delta_dms_ge_120_count']}",
        f"DELTA_DMS_MAX_ABS_PS={summary['delta_dms_max_abs_ps']}",
        f"DELTA_SETP_GE_120_COUNT={summary['delta_setp_ge_120_count']}",
        f"DELTA_SETP_MAX_ABS_PS={summary['delta_setp_max_abs_ps']}",
        f"DELTA_CKO_MINUS_DMS_GE_120_COUNT={summary['delta_residual_ge_120_count']}",
        f"DELTA_CKO_MINUS_DMS_MAX_ABS_PS={summary['delta_residual_max_abs_ps']}",
        f"LOCK_COUNTS={summary['lock_counts']}",
        "INTERPRETATION=correlation_only_not_same_cycle_causality",
        "SYNC_PHASE_ADJACENT_STEP_ROWS:",
    ]
    lines.extend(str(row) for row in summary["sync_step_rows"])
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    args = parser.parse_args(argv)
    try:
        text = args.log.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        print(f"ERROR={exc}", file=sys.stderr)
        return 2
    print(render(analyze_text(text)), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
