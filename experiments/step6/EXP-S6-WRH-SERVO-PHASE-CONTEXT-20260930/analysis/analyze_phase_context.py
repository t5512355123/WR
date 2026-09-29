from __future__ import annotations

import argparse
import json
import re
import statistics
from pathlib import Path


ROW_MARKER = "S6_INTERLEAVED_SAMPLE "
STATE_NAMES = {
    0: "UNINITIALIZED",
    1: "SYNC_TAI",
    2: "SYNC_NSEC",
    3: "SYNC_PHASE",
    4: "TRACK_PHASE",
    5: "WAIT_OFFSET_STABLE",
}


def fields(text: str) -> dict[str, str]:
    return dict(re.findall(r"([A-Za-z][A-Za-z0-9_]*)=([^\s]+)", text))


def integer(row: dict[str, str], key: str, *, hexadecimal: bool = False) -> int | None:
    value = row.get(key)
    if value is None or value in {"NA", "TIMEOUT", "INVALID", "SKIPPED"}:
        return None
    try:
        if hexadecimal:
            return int(value, 16)
        return int(value, 0) if value.lower().startswith("0x") else int(value, 10)
    except ValueError:
        return None


def summarize(path: Path, *, mode: str, expected_duration_ms: int = 15_000) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    parsed = [fields(line.split(ROW_MARKER, 1)[1])
              for line in text.splitlines() if ROW_MARKER in line]
    config = next((fields(line.split("S6_INTERLEAVED_CONFIG ", 1)[1])
                   for line in text.splitlines()
                   if "S6_INTERLEAVED_CONFIG " in line), {})
    done = next((fields(line.split("S6_INTERLEAVED_BOARD_DONE ", 1)[1])
                 for line in reversed(text.splitlines())
                 if "S6_INTERLEAVED_BOARD_DONE " in line), {})
    wire_summary = next((fields(line.split("S6_INTERLEAVED_SUMMARY ", 1)[1])
                         for line in reversed(text.splitlines())
                         if "S6_INTERLEAVED_SUMMARY " in line), {})

    read_valid = [row for row in parsed if integer(row, "READS_VALID") == 1]
    framed = [row for row in parsed if integer(row, "DIAG_FRAME_VALID") == 1]
    context_valid = [row for row in parsed
                      if integer(row, "PHASE_CONTEXT") == 1
                      and integer(row, "PHASE_CONTEXT_VALID") == 1]
    trusted = [row for row in parsed
               if integer(row, "READS_VALID") == 1
               and integer(row, "COHERENT") == 1
               and integer(row, "DIAG_FRAME_VALID") == 1
               and integer(row, "PHASE_CONTEXT") == 1
               and integer(row, "PHASE_CONTEXT_VALID") == 1
               and integer(row, "UCNT", hexadecimal=True) is not None
               and integer(row, "SERVO_STATE") is not None
               and integer(row, "CKO_PS") is not None
               and integer(row, "DMS_PS") is not None
               and integer(row, "SETP_PS") is not None]
    fully_live = [row for row in trusted
                  if integer(row, "GLOBAL_TIME_VALID") == 1
                  and all(integer(row, key) == 1 for key in (
                      "HELPER_LOCK", "MAIN_LOCK", "MAIN_FREQ_LOCK",
                      "MAIN_PHASE_LOCK", "PSTAT_LOCK"))]
    strict_offset = [row for row in fully_live
                     if abs(integer(row, "CKO_PS") or 0) < 60]

    state_summary: dict[str, dict] = {}
    for row in trusted:
        state = integer(row, "SERVO_STATE")
        name = STATE_NAMES.get(state, f"UNKNOWN_{state}")
        group = state_summary.setdefault(name, {"state": state, "rows": 0,
            "cko_min_ps": None, "cko_max_ps": None,
            "dms_min_ps": None, "dms_max_ps": None,
            "setp_min_ps": None, "setp_max_ps": None,
            "offset_abs_lt_60_count": 0})
        group["rows"] += 1
        for field, key in (("cko", "CKO_PS"), ("dms", "DMS_PS"),
                           ("setp", "SETP_PS")):
            value = integer(row, key)
            lo, hi = f"{field}_min_ps", f"{field}_max_ps"
            group[lo] = value if group[lo] is None else min(group[lo], value)
            group[hi] = value if group[hi] is None else max(group[hi], value)
        if abs(integer(row, "CKO_PS") or 0) < 60:
            group["offset_abs_lt_60_count"] += 1

    adjacent_pairs = 0
    one_step_pairs = 0
    repeated_pairs = 0
    skipped_pairs = 0
    one_step_setp_changed = 0
    one_step_dms_changed = 0
    one_step_cko_changed = 0
    one_step_state_changed = 0
    for left, right in zip(trusted, trusted[1:]):
        u0 = integer(left, "UCNT", hexadecimal=True)
        u1 = integer(right, "UCNT", hexadecimal=True)
        assert u0 is not None and u1 is not None
        delta = (u1 - u0) & 0xFFFFFFFF
        adjacent_pairs += 1
        if delta == 0:
            repeated_pairs += 1
        elif delta == 1:
            one_step_pairs += 1
            one_step_setp_changed += integer(left, "SETP_PS") != integer(right, "SETP_PS")
            one_step_dms_changed += integer(left, "DMS_PS") != integer(right, "DMS_PS")
            one_step_cko_changed += integer(left, "CKO_PS") != integer(right, "CKO_PS")
            one_step_state_changed += integer(left, "SERVO_STATE") != integer(right, "SERVO_STATE")
        else:
            skipped_pairs += 1

    row_ms = [float(row["row_ms"]) for row in parsed if row.get("row_ms") is not None]
    elapsed = integer(done, "elapsed_ms") or 0
    timeout_count = integer(wire_summary, "timeout_count") or 0
    invalid_count = integer(wire_summary, "invalid_count") or 0
    reset_stop = integer(wire_summary, "reset_stop",
                         hexadecimal=False)
    if reset_stop is None:
        reset_stop = integer(done, "reset_stop") or 0
    stopped = any("S6_INTERLEAVED_STOP " in line or "S6_INTERLEAVED_ERROR " in line
                  for line in text.splitlines())
    exit_text = next((line.split("CAPTURE_PROCESS_EXIT=", 1)[1].strip()
                      for line in reversed(text.splitlines())
                      if "CAPTURE_PROCESS_EXIT=" in line), None)
    process_ok = exit_text in {None, "0"}
    context_and_frame_floor = bool(parsed) and len(trusted) / len(parsed) >= 0.75
    all_reads = bool(parsed) and len(read_valid) == len(parsed)
    all_live = bool(parsed) and len(fully_live) == len(parsed)
    expected = integer(config, "duration_ms") or expected_duration_ms
    no_transport_or_reset_error = timeout_count == 0 and invalid_count == 0 and reset_stop == 0
    no_early_stop = not stopped and process_ok

    if mode == "smoke":
        passed = (len(parsed) >= 20 and elapsed >= expected_duration_ms
                  and all_reads and context_and_frame_floor and all_live
                  and no_transport_or_reset_error and no_early_stop
                  and bool(row_ms) and statistics.median(row_ms) < 250.0)
        verdict = "SMOKE_PASS" if passed else "SMOKE_FAIL"
    else:
        verdict = ("CAPTURE_COMPLETE_DIAGNOSTIC"
                   if elapsed >= expected and no_transport_or_reset_error and no_early_stop
                   else "INCONCLUSIVE_INCOMPLETE_CAPTURE")

    return {
        "source_log": str(path),
        "mode": mode,
        "verdict": verdict,
        "step6_gate": "NOT_EVALUATED_BY_PHASE_CONTEXT_DIAGNOSTIC",
        "requested_duration_ms": expected,
        "observed_duration_ms": elapsed,
        "sample_rows": len(parsed),
        "read_valid_rows": len(read_valid),
        "wdiags_frame_valid_rows": len(framed),
        "phase_context_valid_rows": len(context_valid),
        "trusted_phase_context_rows": len(trusted),
        "global_time_and_all_five_lock_rows": len(fully_live),
        "strict_abs_cko_lt_60_rows_with_live_gates": len(strict_offset),
        "servo_state_summary": state_summary,
        "adjacent_ucnt_pairs": adjacent_pairs,
        "ucnt_one_step_pairs": one_step_pairs,
        "ucnt_repeated_pairs": repeated_pairs,
        "ucnt_skipped_pairs": skipped_pairs,
        "one_step_pairs_with_setp_change": one_step_setp_changed,
        "one_step_pairs_with_dms_change": one_step_dms_changed,
        "one_step_pairs_with_cko_change": one_step_cko_changed,
        "one_step_pairs_with_servo_state_change": one_step_state_changed,
        "median_row_duration_ms": statistics.median(row_ms) if row_ms else None,
        "timeout_count": timeout_count,
        "invalid_count": invalid_count,
        "reset_stop": reset_stop,
        "reader_stopped_early": stopped,
        "process_exit": exit_text,
        "limitations": [
            "The WDIAGS epoch/data-valid guard is a publication-frame check, not a hardware-atomic snapshot.",
            "Global-Time and lock reads are separate from the WDIAGS servo payload.",
            "Adjacent rows can skip servo updates; only UCNT delta 1 is counted as a one-step pair.",
            "Correlation among CKO, DMS, SETP, and servo state does not prove actuator causality.",
            "A diagnostic capture does not establish Step 6 acceptance or physical SMA edge skew.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--mode", choices=("smoke", "capture"), default="capture")
    parser.add_argument("--expected-duration-ms", type=int, default=15_000)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = summarize(args.log, mode=args.mode,
                       expected_duration_ms=args.expected_duration_ms)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["verdict"] in {"SMOKE_PASS", "CAPTURE_COMPLETE_DIAGNOSTIC"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
