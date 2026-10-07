#!/usr/bin/env python3
"""Replay and validate the F4L paged Main phase/integrator diagnostic.

F4L is deliberately a diagnostic closure test, not a Step5 verdict.  The
reader publishes one page of a 34-word frame at a time, so this analyzer keeps
summary, integrator, and histogram rows separate and never treats different
pages as one atomic sample.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple


MAGIC = 0x46344C31
VERSION = 1
FRAME_WORDS = 34
PAGE_COUNT = 3
UINT32_MASK = (1 << 32) - 1
HALF32 = 1 << 31
MIN_UNIQUE = 20
MIN_SPAN_MS = 30_000
MIN_BINS = 3

INVALID = {"", "INVALID", "UNKNOWN", "TIMEOUT", "NOT_MEASURED", "NONE"}
RAW_RE = re.compile(r"^F4L_W(\d\d)_RAW$", re.IGNORECASE)


def _int(value: Any) -> Optional[int]:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    text = str(value).strip()
    if text.upper() in INVALID:
        return None
    try:
        return int(text, 0)
    except ValueError:
        try:
            return int(text, 16)
        except ValueError:
            try:
                return int(text, 10)
            except ValueError:
                return None


def _u32(value: Any) -> Optional[int]:
    parsed = _int(value)
    return None if parsed is None else parsed & UINT32_MASK


def _s32(value: int) -> int:
    value &= UINT32_MASK
    return value - (1 << 32) if value & 0x80000000 else value


def _flag(value: Any) -> bool:
    return str(value).strip().upper() in {"1", "YES", "TRUE", "PASS"}


def _parse_line(line: str) -> Tuple[str, Dict[str, str]]:
    parts = line.strip().split()
    if not parts:
        return "", {}
    fields: Dict[str, str] = {}
    for token in parts[1:]:
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        fields[key.upper()] = value
    return parts[0], fields


def _delta(previous: Optional[int], current: Optional[int]) -> Optional[int]:
    if previous is None or current is None:
        return None
    value = (current - previous) & UINT32_MASK
    return None if value > HALF32 else value


def _i64(words: Sequence[int], low: int) -> int:
    bits = (words[low] & UINT32_MASK) | ((words[low + 1] & UINT32_MASK) << 32)
    return bits - (1 << 64) if bits & (1 << 63) else bits


def _raw_words(fields: Dict[str, str]) -> Tuple[List[Optional[int]], List[str]]:
    words: List[Optional[int]] = [None] * FRAME_WORDS
    problems: List[str] = []
    for key, value in fields.items():
        match = RAW_RE.match(key)
        if not match:
            continue
        index = int(match.group(1))
        if index >= FRAME_WORDS:
            problems.append("RAW_WORD_INDEX_OUT_OF_RANGE")
            continue
        parsed = _u32(value)
        if parsed is None:
            problems.append(f"RAW_WORD_{index:02d}_NOT_HEX")
        words[index] = parsed
    if any(value is None for value in words):
        problems.append("RAW_FRAME_INCOMPLETE")
    return words, sorted(set(problems))


def _validate_row(kind: str, fields: Dict[str, str]) -> Dict[str, Any]:
    words_optional, problems = _raw_words(fields)
    if any(value is None for value in words_optional):
        return {
            "kind": kind,
            "valid": False,
            "problems": problems,
            "fields": fields,
        }
    words = [int(value) for value in words_optional]
    transport_before = _u32(fields.get("PUBLICATION_EPOCH_RAW_BEFORE"))
    transport_after = _u32(fields.get("PUBLICATION_EPOCH_RAW_AFTER"))
    if transport_before is None or transport_after is None:
        problems.append("PUBLICATION_RAW_MISSING")
    elif transport_before != transport_after or transport_after & 1:
        problems.append("PUBLICATION_NOT_COHERENT")
    if words[0] != transport_after:
        problems.append("TRANSPORT_EPOCH_PAYLOAD_MISMATCH")
    version = words[2] & 0xFF
    page = (words[2] >> 8) & 0xFF
    source_epoch = words[3]
    if words[1] != MAGIC:
        problems.append("MAGIC_MISMATCH")
    if version != VERSION:
        problems.append("VERSION_MISMATCH")
    if page >= PAGE_COUNT:
        problems.append("PAGE_MISMATCH")
    if source_epoch == 0 or source_epoch & 1:
        problems.append("SOURCE_EPOCH_INVALID")
    branch_flags = words[7]
    branch_id = branch_flags & 0xFF
    flags = (branch_flags >> 8) & 0xFFFF
    clamp_code = (branch_flags >> 24) & 0x3
    producer_identity = words[6]
    source_ids = words[16]
    identity_dac = producer_identity & 0xFF
    identity_sources = ((producer_identity >> 8) & 0xFF) | (((producer_identity >> 16) & 0xFF) << 8)
    if identity_dac != 0:
        problems.append("NOT_MAIN_DAC0")
    if identity_sources != source_ids:
        problems.append("SOURCE_ID_MISMATCH")
    if words[13] == 0:
        problems.append("EMPTY_SOURCE_COUNTER")
    payload = {
        "transport_epoch": words[0],
        "magic": words[1],
        "version": version,
        "page": page,
        "source_epoch": source_epoch,
        "update_id": words[4],
        "init_generation": words[5],
        "producer_identity": producer_identity,
        "source_ids": source_ids,
        "branch_id": branch_id,
        "flags": flags,
        "branch_error": _s32(words[8]),
        "freq_error": _s32(words[9]),
        "pi_x": _s32(words[10]),
        "pi_output": _s32(words[11]),
        "phase_shift_current": _s32(words[12]),
        "total_updates": words[13],
        "frequency_updates": words[14],
        "phase_updates": words[15],
        "words": words,
        "elapsed_ms": _int(fields.get("ELAPSED_MS")),
        "host_end_ms": _int(fields.get("HOST_END_MS")),
        "cycle": _int(fields.get("CYCLE")),
        "board": fields.get("BOARD", ""),
    }
    if page == 0:
        payload.update(
            phase_detector_updates=words[17],
            phase_in_band_updates=words[18],
            phase_out_of_band_updates=words[19],
            pair_eligible=words[20],
            pair_breaks=words[21],
            pair_ambiguous=words[22],
            positive_boundary=words[23],
            negative_boundary=words[24],
            phase_delta_sum=_i64(words, 25),
            phase_freq_error_count=words[27],
            phase_freq_error_sum=_i64(words, 28),
            phase_freq_error_min=_s32(words[30]),
            phase_freq_error_max=_s32(words[31]),
            phase_shift_breaks=words[32],
            phase_hist_out_of_range=words[33],
        )
    elif page == 1:
        payload.update(
            frequency_actual_i_sum=_i64(words, 17),
            phase_actual_i_sum=_i64(words, 19),
            frequency_ki_x_sum=_i64(words, 21),
            phase_ki_x_sum=_i64(words, 23),
            frequency_i_count=words[25],
            phase_i_count=words[26],
            clamp_event_count=words[27],
            anti_windup_event_count=words[28],
            actual_delta_mismatch_count=words[29],
            last_i_before=_i64(words, 30),
            last_i_after=_i64(words, 32),
        )
    else:
        histogram = words[17:33]
        payload.update(
            histogram=histogram,
            phase_hist_out_of_range=words[33],
        )
        if sum(histogram) != words[15]:
            problems.append("HISTOGRAM_PHASE_COUNT_MISMATCH")
    if page == 0 and words[17] != words[15]:
        problems.append("SUMMARY_PHASE_COUNT_MISMATCH")
    if page == 1 and (words[25] != words[14] or words[26] != words[15]):
        problems.append("INTEGRATOR_COUNT_MISMATCH")
    payload["valid"] = not problems
    payload["problems"] = sorted(set(problems))
    payload["raw_words"] = [f"0x{word:08X}" for word in words]
    return payload


def _counter_monotonic(rows: Sequence[Dict[str, Any]], field: str) -> Tuple[bool, List[str]]:
    ordered = sorted(rows, key=lambda row: row.get("source_epoch", 0))
    problems: List[str] = []
    for previous, current in zip(ordered, ordered[1:]):
        delta = _delta(previous.get(field), current.get(field))
        if delta is None:
            problems.append(f"{field}_AMBIGUOUS")
    return not problems, sorted(set(problems))


def _cycle_records(lines: Iterable[str]) -> List[Dict[str, Any]]:
    records: List[Dict[str, Any]] = []
    for line in lines:
        kind, fields = _parse_line(line)
        if kind == "STEP5_F4L_CYCLE":
            record = dict(fields)
            record["elapsed_ms"] = _int(fields.get("ELAPSED_MS"))
            record["board"] = fields.get("BOARD", "")
            record["cycle"] = _int(fields.get("CYCLE"))
            records.append(record)
    return records


def analyze_text(text: str, source: str = "<text>") -> Dict[str, Any]:
    lines = text.splitlines()
    frame_rows: List[Dict[str, Any]] = []
    invalid_rows: List[Dict[str, Any]] = []
    cycles = _cycle_records(lines)
    done: Dict[str, str] = {}
    config: Dict[str, str] = {}
    for line in lines:
        kind, fields = _parse_line(line)
        if kind == "STEP5_F4L_MAIN_DIAG":
            row = _validate_row(kind, fields)
            if row.get("valid"):
                frame_rows.append(row)
            else:
                invalid_rows.append(row)
        elif kind == "STEP5_F4L_CONFIG":
            config = fields
        elif kind == "STEP5_F4L_DONE":
            done = fields

    by_page: Dict[str, List[Dict[str, Any]]] = {str(page): [] for page in range(PAGE_COUNT)}
    for row in frame_rows:
        by_page[str(row["page"])].append(row)
    for rows in by_page.values():
        rows.sort(key=lambda row: (row.get("source_epoch", 0), row.get("host_end_ms") or 0))

    unique_keys = {
        (row.get("board"), row["page"], row["source_epoch"], row["update_id"])
        for row in frame_rows
    }
    valid_times = [row.get("host_end_ms") for row in frame_rows if row.get("host_end_ms") is not None]
    first_ms = min(valid_times) if valid_times else None
    last_ms = max(valid_times) if valid_times else None
    span_ms = (last_ms - first_ms) if first_ms is not None and last_ms is not None else 0
    bins = {
        (int(time_ms) // 10_000)
        for time_ms in valid_times
    }
    generations = sorted({row["init_generation"] for row in frame_rows})
    counters: Dict[str, Any] = {}
    for page, rows in by_page.items():
        if not rows:
            continue
        first = rows[0]
        last = rows[-1]
        page_metrics: Dict[str, Any] = {
            "rows": len(rows),
            "first_source_epoch": first["source_epoch"],
            "last_source_epoch": last["source_epoch"],
            "first_update_id": first["update_id"],
            "last_update_id": last["update_id"],
        }
        for field in ("total_updates", "frequency_updates", "phase_updates"):
            page_metrics[field + "_delta"] = _delta(first.get(field), last.get(field))
        if page == "0":
            for field in (
                "phase_detector_updates", "phase_in_band_updates",
                "phase_out_of_band_updates", "pair_eligible", "pair_breaks",
                "pair_ambiguous", "positive_boundary", "negative_boundary",
                "phase_freq_error_count", "phase_shift_breaks",
                "phase_hist_out_of_range",
            ):
                page_metrics[field + "_delta"] = _delta(first.get(field), last.get(field))
            page_metrics["phase_delta_sum_delta"] = (
                last.get("phase_delta_sum", 0) - first.get("phase_delta_sum", 0)
            )
            page_metrics["phase_freq_error_sum_delta"] = (
                last.get("phase_freq_error_sum", 0) - first.get("phase_freq_error_sum", 0)
            )
        elif page == "1":
            for field in (
                "frequency_i_count", "phase_i_count", "clamp_event_count",
                "anti_windup_event_count", "actual_delta_mismatch_count",
            ):
                page_metrics[field + "_delta"] = _delta(first.get(field), last.get(field))
            for field in (
                "frequency_actual_i_sum", "phase_actual_i_sum",
                "frequency_ki_x_sum", "phase_ki_x_sum",
            ):
                page_metrics[field + "_delta"] = last.get(field, 0) - first.get(field, 0)
        else:
            page_metrics["histogram_final"] = last.get("histogram")
            page_metrics["histogram_sum_final"] = sum(last.get("histogram", []))
            page_metrics["histogram_out_of_range_final"] = last.get("phase_hist_out_of_range")
        counters[page] = page_metrics

    semantic_problems: List[str] = []
    for row in frame_rows:
        if not row.get("valid"):
            semantic_problems.extend(row.get("problems", []))
    for page, rows in by_page.items():
        for field in ("total_updates", "frequency_updates", "phase_updates"):
            _, problems = _counter_monotonic(rows, field)
            semantic_problems.extend(f"PAGE{page}_{problem}" for problem in problems)

    cycle_valid = [row for row in cycles if _flag(row.get("MAIN_F4L_VALID"))]
    cycle_main_updates = [_u32(row.get("MAIN_F4L_UPDATE_ID")) for row in cycle_valid]
    main_progress = 0
    for previous, current in zip(cycle_main_updates, cycle_main_updates[1:]):
        delta = _delta(previous, current)
        if delta is not None and delta > 0:
            main_progress += 1
    helper_unlocked_with_main = sum(
        1 for row in cycle_valid
        if str(row.get("HELPER_LOCKED", "")).upper() == "0"
    )
    residual_main_progress = sum(
        1 for row in cycle_valid
        if str(row.get("HELPER_RESIDUAL_PRESENT", "")).upper() == "1"
        and str(row.get("MAIN_F4L_UPDATE_ID", "INVALID")).upper() not in INVALID
    )

    coverage_ok = (
        len(unique_keys) >= MIN_UNIQUE
        and span_ms >= MIN_SPAN_MS
        and len(bins) >= MIN_BINS
        and all(by_page[str(page)] for page in range(PAGE_COUNT))
        and not invalid_rows
        and len(generations) <= 1
        and not semantic_problems
    )
    stop_reason = str(done.get("STOP_REASON", "NONE")).upper()
    classification = "DIAGNOSTIC_COMPLETE" if coverage_ok else "INCONCLUSIVE"
    if invalid_rows:
        classification = "FRAME_SCHEMA_INVALID"
    elif not frame_rows:
        classification = "NO_VALID_F4L_FRAMES"
    elif stop_reason not in {"", "NONE"} and not coverage_ok:
        classification = "DIAGNOSTIC_STOPPED_" + stop_reason
    result: Dict[str, Any] = {
        "source": source,
        "schema": {
            "magic": f"0x{MAGIC:08X}",
            "version": VERSION,
            "frame_words": FRAME_WORDS,
            "page_count": PAGE_COUNT,
            "transport_window": "0x00100B58..0x00100BDC",
        },
        "config": config,
        "done": done,
        "frame_count": len(frame_rows),
        "invalid_frame_count": len(invalid_rows),
        "unique_count": len(unique_keys),
        "unique_span_ms": span_ms,
        "valid_time_bins_10s": len(bins),
        "generations": generations,
        "page_counts": {page: len(rows) for page, rows in by_page.items()},
        "page_counters": counters,
        "invalid_frames": invalid_rows,
        "semantic_problems": sorted(set(semantic_problems)),
        "cycle_count": len(cycles),
        "cycle_main_valid_count": len(cycle_valid),
        "main_progress_intervals": main_progress,
        "helper_unlocked_with_main_valid": helper_unlocked_with_main,
        "helper_residual_with_main_valid": residual_main_progress,
        "diagnostic_complete": coverage_ok,
        "diagnostic_pass": coverage_ok,
        "classification": classification,
        # F4L never establishes Step5 lock.  These are intentionally hard
        # false even when the passive diagnostic itself closes successfully.
        "step5_complete": False,
        "step5_pass": False,
        "merge_approved": False,
    }
    return result


def analyze_file(path: Path) -> Dict[str, Any]:
    return analyze_text(path.read_text(encoding="utf-8", errors="replace"), str(path))


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    result = analyze_file(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "classification": result["classification"],
        "diagnostic_pass": result["diagnostic_pass"],
        "step5_pass": result["step5_pass"],
        "frame_count": result["frame_count"],
        "unique_count": result["unique_count"],
        "unique_span_ms": result["unique_span_ms"],
    }, sort_keys=True))
    return 0 if result["diagnostic_pass"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
