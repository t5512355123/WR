#!/usr/bin/env python3
"""Conservative offline audit for the Step 6 interleaved servo capture."""

from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path


ROW_MARKER = "S6_INTERLEAVED_SAMPLE "


def parse_fields(line: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for token in line.split():
        if "=" in token:
            key, value = token.split("=", 1)
            fields[key] = value
    return fields


def integer(row: dict[str, str], key: str, default: int | None = None) -> int | None:
    try:
        return int(row[key], 0)
    except (KeyError, TypeError, ValueError):
        try:
            return int(row[key])
        except (KeyError, TypeError, ValueError):
            return default


def summarize(
    path: Path,
    *,
    expected_duration_ms: int = 300_000,
    maximum_gap_ms: int = 1_500,
    mode: str = "capture",
) -> dict[str, object]:
    text = path.read_text(encoding="utf-8", errors="replace")
    rows = [parse_fields(line.split(ROW_MARKER, 1)[1]) for line in text.splitlines() if ROW_MARKER in line]
    config = next(
        (parse_fields(line.split("S6_INTERLEAVED_CONFIG ", 1)[1]) for line in text.splitlines() if "S6_INTERLEAVED_CONFIG " in line),
        {},
    )
    done_rows = [
        parse_fields(line.split("S6_INTERLEAVED_BOARD_DONE ", 1)[1])
        for line in text.splitlines()
        if "S6_INTERLEAVED_BOARD_DONE " in line
    ]
    summary_rows = [
        parse_fields(line.split("S6_INTERLEAVED_SUMMARY ", 1)[1])
        for line in text.splitlines()
        if "S6_INTERLEAVED_SUMMARY " in line
    ]
    board_done = done_rows[-1] if done_rows else {}
    wire_summary = summary_rows[-1] if summary_rows else {}
    accepted = [r for r in rows if integer(r, "READS_VALID", 0) == 1 and integer(r, "COHERENT", 0) == 1]
    read_valid_rows = [r for r in rows if integer(r, "READS_VALID", 0) == 1]
    valid_offsets = [integer(r, "CKO_PS") for r in accepted]
    valid_offsets = [value for value in valid_offsets if value is not None]
    strict_rows = [
        r for r in rows
        if integer(r, "QUALIFYING_SAMPLE", 0) == 1
        and integer(r, "GLOBAL_TIME_VALID", 0) == 1
        and integer(r, "HELPER_LOCK", 0) == 1
        and integer(r, "MAIN_LOCK", 0) == 1
        and integer(r, "MAIN_FREQ_LOCK", 0) == 1
        and integer(r, "MAIN_PHASE_LOCK", 0) == 1
        and integer(r, "PSTAT_LOCK", 0) == 1
        and (offset := integer(r, "CKO_PS")) is not None
        and abs(offset) < 60
    ]
    times = [integer(r, "elapsed_ms") for r in rows]
    times = [value for value in times if value is not None]
    gaps = [right - left for left, right in zip(times, times[1:]) if right >= left]
    row_durations = [float(r["row_ms"]) for r in rows if _is_float(r.get("row_ms"))]
    sample_ms = integer(config, "sample_ms", 500) or 500
    requested_duration = integer(config, "duration_ms", expected_duration_ms) or expected_duration_ms
    observed_duration = integer(board_done, "elapsed_ms", times[-1] if times else 0) or 0
    reset_stop = integer(wire_summary, "reset_stop", integer(board_done, "reset_stop", 0)) or 0
    timeout_count = integer(wire_summary, "timeout_count", 0) or 0
    invalid_count = integer(wire_summary, "invalid_count", 0) or 0
    stopped = any("S6_INTERLEAVED_STOP " in line or "S6_INTERLEAVED_ERROR " in line for line in text.splitlines())
    exit_code = _last_value(text, "CAPTURE_PROCESS_EXIT=")
    expected_rows = max(1, requested_duration // sample_ms)

    complete = observed_duration >= expected_duration_ms and not stopped and exit_code in {None, "0"}
    uninterrupted_samples = (
        bool(rows)
        and len(read_valid_rows) == len(rows)
        and len(accepted) / len(rows) >= 0.95
        and len(strict_rows) == len(rows)
        and reset_stop == 0
        and timeout_count == 0
        and invalid_count == 0
        and bool(gaps)
        and max(gaps) <= maximum_gap_ms
    )
    smoke_ok = (
        len(rows) >= 20
        and len(read_valid_rows) == len(rows)
        and len(accepted) / len(rows) >= 0.95
        and bool(row_durations)
        and statistics.median(row_durations) < 250.0
        and timeout_count == 0
        and invalid_count == 0
        and not stopped
        and exit_code in {None, "0"}
    )
    if mode == "smoke":
        verdict = "SMOKE_PASS" if smoke_ok else "SMOKE_FAIL"
    elif complete and uninterrupted_samples and len(rows) >= expected_rows // 2:
        verdict = "STEP6_EXPANDED_SAMPLE_GATE_PASS"
    elif rows and not complete:
        verdict = "INCONCLUSIVE_INCOMPLETE_CAPTURE"
    else:
        verdict = "STEP6_EXPANDED_GATE_NOT_ESTABLISHED"

    return {
        "source_log": str(path),
        "mode": mode,
        "verdict": verdict,
        "requested_duration_ms": requested_duration,
        "observed_duration_ms": observed_duration,
        "requested_sample_ms": sample_ms,
        "sample_rows": len(rows),
        "trusted_rows": len(accepted),
        "individual_reads_valid_rows": len(read_valid_rows),
        "qualifying_rows": len(strict_rows),
        "qualifying_fraction": (len(strict_rows) / len(rows)) if rows else None,
        "strict_offset_limit_ps": 60,
        "offset_abs_lt_60_count": sum(abs(value) < 60 for value in valid_offsets),
        "offset_valid_rows": len(valid_offsets),
        "offset_min_ps": min(valid_offsets) if valid_offsets else None,
        "offset_max_ps": max(valid_offsets) if valid_offsets else None,
        "maximum_sample_gap_ms": max(gaps) if gaps else None,
        "median_row_duration_ms": statistics.median(row_durations) if row_durations else None,
        "reset_stop": reset_stop,
        "timeout_count": timeout_count,
        "invalid_count": invalid_count,
        "reader_stopped_early": stopped,
        "process_exit": exit_code,
        "complete_capture": complete,
        "all_rows_step6_qualifying": uninterrupted_samples,
        "limitations": [
            "Sequential Wishbone/probe reads are bounded by host-time markers, not atomic.",
            "Sampled pass does not prove behavior between observations or physical SMA edge skew.",
            "Global Time and lock fields are separate groups from the interleaved CKO/DMS reads.",
        ],
    }


def _is_float(value: str | None) -> bool:
    try:
        float(value or "")
        return True
    except ValueError:
        return False


def _last_value(text: str, prefix: str) -> str | None:
    return next((line.split(prefix, 1)[1].strip() for line in reversed(text.splitlines()) if prefix in line), None)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--mode", choices=("smoke", "capture"), default="capture")
    parser.add_argument("--expected-duration-ms", type=int, default=300_000)
    parser.add_argument("--maximum-gap-ms", type=int, default=1_500)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = summarize(
        args.log,
        expected_duration_ms=args.expected_duration_ms,
        maximum_gap_ms=args.maximum_gap_ms,
        mode=args.mode,
    )
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["verdict"] in {"SMOKE_PASS", "STEP6_EXPANDED_SAMPLE_GATE_PASS"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
