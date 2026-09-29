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


def hex_integer(row: dict[str, str], key: str) -> int | None:
    try:
        return int(row[key], 16)
    except (KeyError, TypeError, ValueError):
        return None


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
    diag_frame_rows = [r for r in rows if "DIAG_FRAME_VALID" in r]
    diag_frame_valid_rows = [r for r in diag_frame_rows if integer(r, "DIAG_FRAME_VALID", 0) == 1]
    # Older captures predate the explicit WDIAGS publication-frame guard.
    # Keep their recorded validity semantics while reporting the guard as absent.
    trusted_offset_rows = [
        r for r in read_valid_rows if integer(r, "DIAG_FRAME_VALID", 1) == 1
    ]
    valid_offsets = [integer(r, "CKO_PS") for r in trusted_offset_rows]
    valid_offsets = [value for value in valid_offsets if value is not None]
    offsets_by_servo_state: dict[int, list[int]] = {}
    for row in trusted_offset_rows:
        state = integer(row, "SERVO_STATE")
        offset = integer(row, "CKO_PS")
        if state is not None and offset is not None:
            offsets_by_servo_state.setdefault(state, []).append(offset)
    servo_state_offset_summary = {
        str(state): {
            "rows": len(offsets),
            "median_offset_ps": statistics.median(offsets),
            "offset_min_ps": min(offsets),
            "offset_max_ps": max(offsets),
            "offset_abs_lt_60_count": sum(abs(offset) < 60 for offset in offsets),
        }
        for state, offsets in sorted(offsets_by_servo_state.items())
    }
    update_counts = [
        value for row in trusted_offset_rows
        if (value := hex_integer(row, "UCNT")) is not None
    ]
    update_deltas = [
        (right - left) & 0xFFFFFFFF
        for left, right in zip(update_counts, update_counts[1:])
    ]
    all_lock_rows = [
        r for r in read_valid_rows
        if all(integer(r, key, 0) == 1 for key in (
            "HELPER_LOCK", "MAIN_LOCK", "MAIN_FREQ_LOCK", "MAIN_PHASE_LOCK", "PSTAT_LOCK"
        ))
    ]
    global_time_rows = [r for r in read_valid_rows if integer(r, "GLOBAL_TIME_VALID", 0) == 1]
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
    timing_rows = [
        parse_fields(line.split("S6_INTERLEAVED_TIMING ", 1)[1])
        for line in text.splitlines()
        if "S6_INTERLEAVED_TIMING " in line
    ]
    timing_by_sample = {
        integer(r, "sample"): r for r in timing_rows if integer(r, "sample") is not None
    }
    pre_cko_gaps = []
    post_cko_gaps = []
    critical_frame_durations = []
    for row in rows:
        timing = timing_by_sample.get(integer(row, "sample"))
        if not timing:
            continue
        frame_start = integer(timing, "FRAME_START_US")
        frame_end = integer(timing, "FRAME_END_US")
        if frame_start is not None and frame_end is not None and frame_end >= frame_start:
            critical_frame_durations.append(frame_end - frame_start)
        cko_host = integer(timing, "CKO_HOST_US")
        pre_end = integer(timing, "DMS_PRE_END_US")
        post_start = integer(timing, "DMS_POST_START_US")
        if cko_host is not None and pre_end is not None and cko_host >= pre_end:
            pre_cko_gaps.append(cko_host - pre_end)
        if cko_host is not None and post_start is not None and post_start >= cko_host:
            post_cko_gaps.append(post_start - cko_host)
    sample_ms = integer(config, "sample_ms", 500) or 500
    requested_duration = integer(config, "duration_ms", expected_duration_ms) or expected_duration_ms
    observed_duration = integer(board_done, "elapsed_ms", times[-1] if times else 0) or 0
    capture_tail_gap = max(0, observed_duration - times[-1]) if times else 0
    covered_gaps = gaps + ([capture_tail_gap] if times else [])
    reset_stop = integer(wire_summary, "reset_stop", integer(board_done, "reset_stop", 0)) or 0
    timeout_count = integer(wire_summary, "timeout_count", 0) or 0
    invalid_count = integer(wire_summary, "invalid_count", 0) or 0
    stopped = any("S6_INTERLEAVED_STOP " in line or "S6_INTERLEAVED_ERROR " in line for line in text.splitlines())
    exit_code = _last_value(text, "CAPTURE_PROCESS_EXIT=")
    observed_sample_period = statistics.median(gaps) if gaps else float(sample_ms)
    expected_rows = max(1, int(requested_duration / max(1.0, observed_sample_period)))

    complete = observed_duration >= expected_duration_ms and not stopped and exit_code in {None, "0"}
    uninterrupted_samples = (
        bool(rows)
        and len(read_valid_rows) == len(rows)
        and len(accepted) / len(rows) >= 0.75
        and len(strict_rows) == len(rows)
        and reset_stop == 0
        and timeout_count == 0
        and invalid_count == 0
        and bool(gaps)
        and max(gaps) <= maximum_gap_ms
        and capture_tail_gap <= maximum_gap_ms
    )
    smoke_ok = (
        len(rows) >= 20
        and len(read_valid_rows) == len(rows)
        and len(accepted) / len(rows) >= 0.75
        and bool(row_durations)
        and statistics.median(row_durations) < 450.0
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
        "diagnostic_frame_checked_rows": len(diag_frame_rows),
        "diagnostic_frame_valid_rows": len(diag_frame_valid_rows),
        "diagnostic_epoch_changed_rows": sum(
            1 for r in diag_frame_rows if integer(r, "DIAG_EPOCH_STABLE", 0) == 0
        ),
        "global_time_valid_rows": len(global_time_rows),
        "all_five_step5_locks_rows": len(all_lock_rows),
        "qualifying_rows": len(strict_rows),
        "qualifying_fraction": (len(strict_rows) / len(rows)) if rows else None,
        "strict_offset_limit_ps": 60,
        "offset_abs_lt_60_count": sum(abs(value) < 60 for value in valid_offsets),
        "offset_valid_rows": len(valid_offsets),
        "offset_min_ps": min(valid_offsets) if valid_offsets else None,
        "offset_max_ps": max(valid_offsets) if valid_offsets else None,
        "servo_state_offset_summary": servo_state_offset_summary,
        "ucnt_valid_rows": len(update_counts),
        "ucnt_changed_pairs": sum(delta != 0 for delta in update_deltas),
        "ucnt_unchanged_pairs": sum(delta == 0 for delta in update_deltas),
        "ucnt_delta_min": min(update_deltas) if update_deltas else None,
        "ucnt_delta_max": max(update_deltas) if update_deltas else None,
        "maximum_sample_gap_ms": max(covered_gaps) if covered_gaps else None,
        "median_sample_gap_ms": statistics.median(gaps) if gaps else None,
        "capture_tail_gap_ms": capture_tail_gap,
        "estimated_expected_rows_at_observed_cadence": expected_rows,
        "median_row_duration_ms": statistics.median(row_durations) if row_durations else None,
        "median_cko_after_pre_dms_us": statistics.median(pre_cko_gaps) if pre_cko_gaps else None,
        "maximum_cko_after_pre_dms_us": max(pre_cko_gaps) if pre_cko_gaps else None,
        "median_post_dms_start_after_cko_us": statistics.median(post_cko_gaps) if post_cko_gaps else None,
        "maximum_post_dms_start_after_cko_us": max(post_cko_gaps) if post_cko_gaps else None,
        "median_critical_frame_duration_us": statistics.median(critical_frame_durations) if critical_frame_durations else None,
        "maximum_critical_frame_duration_us": max(critical_frame_durations) if critical_frame_durations else None,
        "reset_stop": reset_stop,
        "timeout_count": timeout_count,
        "invalid_count": invalid_count,
        "reader_stopped_early": stopped,
        "process_exit": exit_code,
        "complete_capture": complete,
        "all_rows_step6_qualifying": uninterrupted_samples,
        "limitations": [
            "Sequential Wishbone/probe reads are bounded by host-time markers, not atomic.",
            "New captures additionally reject rows crossing an invalid or changed WDIAGS publication frame; historical captures predate this guard.",
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
