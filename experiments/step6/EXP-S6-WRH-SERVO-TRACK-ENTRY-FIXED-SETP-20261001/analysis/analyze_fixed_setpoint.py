#!/usr/bin/env python3
"""Audit a read-only Step 6 capture with a boot-lifetime fixed-SETPOINT latch."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


PREFIX = "S6_INTERLEAVED_SAMPLE "
STEP1_FIELDS = (
    "STATUS_SI_CONFIG_DONE",
    "STATUS_WR_READY",
    "STATUS_TM_LINK",
    "STATUS_LINK_OK",
    "STATUS_RX_READY",
    "STATUS_TX_READY",
    "STATUS_CPU_RESET_N",
    "STATUS_RX_LOCKED_TO_DATA",
)
LOCK_FIELDS = (
    "HELPER_LOCK",
    "MAIN_FREQ_LOCK",
    "MAIN_PHASE_LOCK",
    "MAIN_LOCK",
    "PSTAT_LOCK",
)


def _fields(line: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for token in line.split():
        if "=" in token:
            key, value = token.split("=", maxsplit=1)
            result[key] = value
    return result


def _one(row: dict[str, str], key: str) -> bool:
    return row.get(key) == "1"


def _number(row: dict[str, str], key: str) -> int | None:
    try:
        return int(row[key])
    except (KeyError, ValueError):
        return None


def _step1(row: dict[str, str]) -> bool:
    return _one(row, "STEP1_GATE") and all(_one(row, key) for key in STEP1_FIELDS)


def _all_locks(row: dict[str, str]) -> bool:
    return all(_one(row, key) for key in LOCK_FIELDS)


def _paired(row: dict[str, str]) -> bool:
    return (
        _one(row, "READS_VALID")
        and _one(row, "COHERENT")
        and _one(row, "DIAG_FRAME_VALID")
        and _one(row, "DIAG_EPOCH_STABLE")
        and _one(row, "PHASE_CONTEXT_VALID")
        and _one(row, "PHASE_CONTEXT_FRAME_VALID")
        and _one(row, "PHASE_CONTEXT_MATCH")
        and row.get("RESET_CHANGED") == "0"
        and all(_number(row, key) is not None for key in ("CKO_PS", "DMS_PS", "SETP_PS"))
        and _number(row, "SERVO_STATE") is not None
    )


def _trusted(row: dict[str, str]) -> bool:
    return (
        _paired(row)
        and _one(row, "GLOBAL_TIME_VALID")
        and _one(row, "SNAPSHOT_VALID")
        and _one(row, "SNAPSHOT_STABLE")
        and _one(row, "STATUS_TIME_VALID")
        and _one(row, "STATUS_PPS_VALID")
        and _one(row, "ESCR_TIME_VALID")
        and _one(row, "ESCR_PPS_VALID")
        and _step1(row)
        and _all_locks(row)
        and _number(row, "SERVO_STATE") == 4
    )


def _range(values: list[int]) -> dict[str, int | None]:
    return {
        "min": min(values) if values else None,
        "max": max(values) if values else None,
    }


def _adjacent_deltas(
    rows: list[dict[str, str]], key: str
) -> list[int]:
    result: list[int] = []
    previous: dict[str, str] | None = None
    for row in rows:
        if not _paired(row):
            previous = None
            continue
        if previous is not None:
            previous_sample = _number(previous, "sample")
            sample = _number(row, "sample")
            previous_value = _number(previous, key)
            value = _number(row, key)
            if (
                previous_sample is not None
                and sample == previous_sample + 1
                and previous_value is not None
                and value is not None
            ):
                result.append(abs(value - previous_value))
        previous = row
    return result


def analyze_text(text: str) -> dict[str, Any]:
    rows = [_fields(line[len(PREFIX) :]) for line in text.splitlines() if line.startswith(PREFIX)]
    config_line = next(
        (line for line in text.splitlines() if line.startswith("S6_INTERLEAVED_CONFIG ")),
        "",
    )
    done_line = next(
        (line for line in text.splitlines() if line.startswith("S6_INTERLEAVED_BOARD_DONE ")),
        "",
    )
    summary_line = next(
        (line for line in text.splitlines() if line.startswith("S6_INTERLEAVED_SUMMARY ")),
        "",
    )
    config, done, summary = map(_fields, (config_line, done_line, summary_line))
    paired_rows = [row for row in rows if _paired(row)]
    trusted_rows = [row for row in rows if _trusted(row)]
    valid_rows = [row for row in rows if _one(row, "READS_VALID")]
    cko_values = [value for row in valid_rows if (value := _number(row, "CKO_PS")) is not None]
    paired_cko = [int(row["CKO_PS"]) for row in paired_rows]
    paired_dms = [int(row["DMS_PS"]) for row in paired_rows]
    paired_setp = [int(row["SETP_PS"]) for row in paired_rows]
    residuals = [int(row["CKO_PS"]) - int(row["DMS_PS"]) for row in paired_rows]
    trusted_setp = sorted({int(row["SETP_PS"]) for row in trusted_rows})
    paired_setp_distinct = sorted(set(paired_setp))
    state_counts: dict[str, int] = {}
    for row in valid_rows:
        state = row.get("SERVO_STATE", "NA")
        state_counts[state] = state_counts.get(state, 0) + 1

    sample_ms = [value for row in trusted_rows if (value := _number(row, "elapsed_ms")) is not None]
    max_gap_ms = max((b - a for a, b in zip(sample_ms, sample_ms[1:])), default=None)
    cko_deltas = _adjacent_deltas(rows, "CKO_PS")
    dms_deltas = _adjacent_deltas(rows, "DMS_PS")
    residual_deltas = [
        abs((int(rows[index]["CKO_PS"]) - int(rows[index]["DMS_PS"]))
            - (int(rows[index - 1]["CKO_PS"]) - int(rows[index - 1]["DMS_PS"])))
        for index in range(1, len(rows))
        if _paired(rows[index - 1])
        and _paired(rows[index])
        and _number(rows[index], "sample") == _number(rows[index - 1], "sample") + 1
    ]
    expected_ms = int(config.get("duration_ms", "0") or 0)
    observed_ms = int(done.get("elapsed_ms", "0") or 0)
    coherent_count = sum(_one(row, "COHERENT") for row in rows)
    marker_count = sum(_one(row, "QUALIFYING_SAMPLE") for row in rows)
    summary_consistent = (
        summary.get("rows") == str(len(rows))
        and summary.get("accepted") == str(coherent_count)
        and summary.get("qualifying") == str(marker_count)
    )
    read_only = (
        config.get("read_only") == "1"
        and config.get("wb_register_writes") == "0"
        and config.get("fpga_program") == "0"
        and config.get("reset") == "0"
    )
    no_errors = (
        done.get("reset_stop") == "0"
        and summary.get("reset_stop") == "0"
        and summary.get("timeout_count") == "0"
        and summary.get("invalid_count") == "0"
        and "S6_INTERLEAVED_ERROR " not in text
    )
    complete = (
        "S6_INTERLEAVED_DONE" in text
        and bool(done_line)
        and expected_ms > 0
        and observed_ms >= expected_ms
        and summary_consistent
        and read_only
        and no_errors
    )
    context_coverage = len(paired_rows) / len(rows) if rows else 0.0
    gates_valid = bool(rows) and all(
        _one(row, "READS_VALID")
        and _one(row, "GLOBAL_TIME_VALID")
        and _one(row, "SNAPSHOT_VALID")
        and _one(row, "SNAPSHOT_STABLE")
        and _step1(row)
        and _all_locks(row)
        and row.get("RESET_CHANGED") == "0"
        for row in rows
    )
    state_fixed = bool(paired_rows) and all(_number(row, "SERVO_STATE") == 4 for row in paired_rows)
    setp_fixed = len(paired_setp_distinct) == 1
    smoke_pass = (
        complete
        and expected_ms >= 30000
        and len(trusted_rows) >= 20
        and context_coverage >= 0.75
        and gates_valid
        and state_fixed
        and setp_fixed
    )
    unique_ucnt = len({row.get("UCNT") for row in trusted_rows if row.get("UCNT")})
    step6_pass = (
        complete
        and expected_ms >= 300000
        and unique_ucnt >= 900
        and context_coverage >= 0.95
        and max_gap_ms is not None
        and max_gap_ms <= 1000
        and gates_valid
        and state_fixed
        and setp_fixed
        and bool(trusted_rows)
        and all(abs(int(row["CKO_PS"])) < 60 for row in trusted_rows)
    )

    return {
        "capture_complete": complete,
        "read_only_contract": read_only,
        "no_stop_or_read_errors": no_errors,
        "summary_consistent": summary_consistent,
        "expected_duration_ms": expected_ms,
        "observed_duration_ms": observed_ms,
        "sample_rows": len(rows),
        "read_valid_rows": len(valid_rows),
        "coherent_rows": coherent_count,
        "paired_context_rows": len(paired_rows),
        "trusted_rows": len(trusted_rows),
        "unique_trusted_ucnt": unique_ucnt,
        "phase_context_coverage": context_coverage,
        "max_trusted_gap_ms": max_gap_ms,
        "all_gates_valid_every_row": gates_valid,
        "servo_state_counts_read_valid": state_counts,
        "all_paired_rows_track": state_fixed,
        "paired_setp_values_ps": paired_setp_distinct,
        "trusted_setp_values_ps": trusted_setp,
        "setp_fixed": setp_fixed,
        "valid_read_cko_ps_range": _range(cko_values),
        "paired_cko_ps_range": _range(paired_cko),
        "paired_dms_ps_range": _range(paired_dms),
        "paired_cko_minus_dms_ps_range": _range(residuals),
        "max_adjacent_paired_abs_delta_ps": {
            "cko": max(cko_deltas) if cko_deltas else None,
            "dms": max(dms_deltas) if dms_deltas else None,
            "cko_minus_dms": max(residual_deltas) if residual_deltas else None,
        },
        "adjacent_paired_delta_ge_120_ps_count": {
            "cko": sum(delta >= 120 for delta in cko_deltas),
            "dms": sum(delta >= 120 for delta in dms_deltas),
            "cko_minus_dms": sum(delta >= 120 for delta in residual_deltas),
        },
        "fixed_setpoint_smoke_pass": smoke_pass,
        "step6_strict_offset_300s_pass": step6_pass,
        "step6_verdict": "PASS" if step6_pass else "NOT_ESTABLISHED",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze_text(args.capture.read_text(encoding="utf-8", errors="replace")), indent=2))


if __name__ == "__main__":
    main()
