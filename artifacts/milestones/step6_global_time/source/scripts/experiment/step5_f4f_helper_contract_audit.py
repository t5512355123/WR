#!/usr/bin/env python3
"""Replay and classify the read-only Step5 F4F Helper contract audit.

F4F alternates a source-backed FULL seqlock read with a compact CORE read in
one observer process.  Every retry is retained in the raw observer log; this
analyzer only classifies the evidence and never upgrades a CORE observation to
the ten-field FULL contract.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
import sys

sys.path.insert(0, str(REPO_ROOT / "scripts" / "analysis"))

from step5_replay import parse_key_values  # noqa: E402


ATTEMPT_PREFIX = "STEP5_F4F_HELPER_ATTEMPT"
PROFILE_PREFIX = "STEP5_F4F_PROFILE"
CYCLE_PREFIX = "STEP5_F4F_CYCLE"
BACKGROUND_PREFIX = "STEP5_F4F_BACKGROUND"
CONFIG_PREFIX = "STEP5_F4F_CONFIG"
DONE_PREFIX = "STEP5_F4F_DONE"
ROLE_PREFIX = "STEP5_F4F_ROLE_SUMMARY"
INVALID = {"INVALID", "UNKNOWN", "NEVER", "NA", "N/A", "TIMEOUT", "NOT_MEASURED"}
HEX_RE = re.compile(r"^[0-9A-Fa-f]+$")
KEY_RE = re.compile(r"(?<!\S)([A-Za-z][A-Za-z0-9_]*)=")

RAW_FIELDS = (
    "RAW_EPOCH_BEFORE", "RAW_TAG_DELTA", "RAW_EXPECTED_DELTA",
    "RAW_FREQ_ERROR", "RAW_PRECLAMP_ERROR", "RAW_HELPER_ERROR",
    "RAW_UPDATE_COUNT", "RAW_HELPER_OUTPUT", "RAW_DMTD_REF_ACCEPT_COUNT",
    "RAW_DMTD_FB_ACCEPT_COUNT", "RAW_EPOCH_AFTER",
)
FULL_PAYLOAD_FIELDS = (
    "RAW_TAG_DELTA", "RAW_EXPECTED_DELTA", "RAW_FREQ_ERROR",
    "RAW_PRECLAMP_ERROR", "RAW_HELPER_ERROR", "RAW_UPDATE_COUNT",
    "RAW_HELPER_OUTPUT", "RAW_DMTD_REF_ACCEPT_COUNT",
    "RAW_DMTD_FB_ACCEPT_COUNT",
)
REASON_FLAGS = (
    "TRANSPORT_ERROR", "PARSE_ERROR", "ODD_OR_SENTINEL", "EPOCH_CHANGED",
    "ARITHMETIC_MISMATCH", "RANGE_MISMATCH", "ACCEPTED",
    "OWNER_UNVERIFIED",
)


def _records(text: str, prefix: str) -> List[Dict[str, Any]]:
    return [parse_key_values(line) for line in text.splitlines()
            if line.startswith(prefix + " ")]


def parse_attempts(text: str) -> List[Dict[str, Any]]:
    records: List[Dict[str, Any]] = []
    for line in text.splitlines():
        if not line.startswith(ATTEMPT_PREFIX + " "):
            continue
        record = parse_key_values(line)
        matches = list(KEY_RE.finditer(line))
        for index, match in enumerate(matches):
            key = match.group(1).upper()
            if key not in RAW_FIELDS:
                continue
            end = matches[index + 1].start() if index + 1 < len(matches) else len(line)
            # Raw transport tokens are retained as text, including leading
            # zeroes.  Numeric conversion is applied only to parsed fields.
            record[key] = line[match.end():end].strip()
        records.append(record)
    return records


def parse_profiles(text: str) -> List[Dict[str, Any]]:
    return _records(text, PROFILE_PREFIX)


def parse_cycles(text: str) -> List[Dict[str, Any]]:
    return _records(text, CYCLE_PREFIX)


def parse_background(text: str) -> List[Dict[str, Any]]:
    return _records(text, BACKGROUND_PREFIX)


def parse_config(text: str) -> Optional[Dict[str, Any]]:
    records = _records(text, CONFIG_PREFIX)
    return records[0] if records else None


def parse_done(text: str) -> Optional[Dict[str, Any]]:
    records = _records(text, DONE_PREFIX)
    return records[-1] if records else None


def parse_role_summaries(text: str) -> List[Dict[str, Any]]:
    return _records(text, ROLE_PREFIX)


def _num(value: Any) -> Optional[int]:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if not isinstance(value, str):
        return None
    text = value.strip()
    if text.upper() in INVALID:
        return None
    if text.lower().startswith("0x"):
        try:
            return int(text[2:], 16)
        except ValueError:
            return None
    if re.fullmatch(r"[-+]?\d+", text):
        try:
            return int(text, 10)
        except ValueError:
            return None
    if HEX_RE.fullmatch(text):
        try:
            return int(text, 16)
        except ValueError:
            return None
    return None


def _flag(record: Dict[str, Any], key: str) -> bool:
    value = record.get(key)
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value == 1
    return isinstance(value, str) and value.strip().upper() in {
        "1", "YES", "PASS", "TRUE",
    }


def _reason_set(record: Dict[str, Any]) -> set[str]:
    value = record.get("REASON")
    if not isinstance(value, str):
        return set()
    return {item for item in value.split(",") if item}


def _profile(record: Dict[str, Any]) -> str:
    return str(record.get("PROFILE") or "UNKNOWN").upper()


def _raw_payload_isolated(record: Dict[str, Any]) -> bool:
    profile = _profile(record)
    if profile == "CORE":
        return all(record.get(field) == "NOT_MEASURED" for field in (
            "RAW_TAG_DELTA", "RAW_EXPECTED_DELTA", "RAW_FREQ_ERROR",
            "RAW_PRECLAMP_ERROR", "RAW_DMTD_REF_ACCEPT_COUNT",
            "RAW_DMTD_FB_ACCEPT_COUNT",
        ))
    if profile == "FULL":
        return all(record.get(field) != "NOT_MEASURED" for field in FULL_PAYLOAD_FIELDS)
    return False


def _attempt_valid_shape(record: Dict[str, Any]) -> bool:
    if _profile(record) not in {"FULL", "CORE"}:
        return False
    required = {"BOARD", "CYCLE", "RETRY_N", "HOST_START_MS", "HOST_END_MS",
                "DURATION_MS", "ACCEPTED", "OWNER_UNVERIFIED", "REASON"}
    if not required.issubset(record):
        return False
    return all(field in record for field in RAW_FIELDS) and _raw_payload_isolated(record)


def _same_board(records: Sequence[Dict[str, Any]]) -> bool:
    boards = {str(record.get("BOARD")) for record in records if record.get("BOARD") is not None}
    return len(boards) <= 1


def _counter_delta(previous: Optional[int], current: Optional[int], bits: int = 32) -> Optional[int]:
    if previous is None or current is None:
        return None
    delta = (current - previous) & ((1 << bits) - 1)
    return None if delta > (1 << (bits - 1)) - 1 else delta


def _classify_attempts(attempts: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    by_profile: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for record in attempts:
        by_profile[_profile(record)].append(record)
    profile_result: Dict[str, Any] = {}
    all_rows: List[Dict[str, Any]] = []
    for profile in ("FULL", "CORE"):
        records = by_profile.get(profile, [])
        accepted = [record for record in records if _flag(record, "ACCEPTED")]
        epoch_changed = sum(_flag(record, "EPOCH_CHANGED") for record in records)
        transport = sum(_flag(record, "TRANSPORT_ERROR") for record in records)
        parse = sum(_flag(record, "PARSE_ERROR") for record in records)
        odd = sum(_flag(record, "ODD_OR_SENTINEL") for record in records)
        arithmetic = sum(_flag(record, "ARITHMETIC_MISMATCH") for record in records)
        range_mismatch = sum(_flag(record, "RANGE_MISMATCH") for record in records)
        accepted_times = [_num(record.get("HOST_END_MS")) for record in accepted]
        accepted_times = [value for value in accepted_times if value is not None]
        profile_result[profile] = {
            "attempt_count": len(records),
            "accepted_count": len(accepted),
            "epoch_changed_count": epoch_changed,
            "transport_error_count": transport,
            "parse_error_count": parse,
            "odd_or_sentinel_count": odd,
            "arithmetic_mismatch_count": arithmetic,
            "range_mismatch_count": range_mismatch,
            "owner_unverified_count": sum(_flag(record, "OWNER_UNVERIFIED") for record in records),
            "accepted_first_host_ms": min(accepted_times) if accepted_times else None,
            "accepted_last_host_ms": max(accepted_times) if accepted_times else None,
        }
        for record in records:
            row = {
                "board": record.get("BOARD"),
                "profile": profile,
                "cycle": _num(record.get("CYCLE")),
                "retry_n": _num(record.get("RETRY_N")),
                "host_start_ms": _num(record.get("HOST_START_MS")),
                "host_end_ms": _num(record.get("HOST_END_MS")),
                "duration_ms": _num(record.get("DURATION_MS")),
                "raw_epoch_before": record.get("RAW_EPOCH_BEFORE"),
                "raw_tag_delta": record.get("RAW_TAG_DELTA"),
                "raw_expected_delta": record.get("RAW_EXPECTED_DELTA"),
                "raw_freq_error": record.get("RAW_FREQ_ERROR"),
                "raw_preclamp_error": record.get("RAW_PRECLAMP_ERROR"),
                "raw_helper_error": record.get("RAW_HELPER_ERROR"),
                "raw_update_count": record.get("RAW_UPDATE_COUNT"),
                "raw_helper_output": record.get("RAW_HELPER_OUTPUT"),
                "raw_dmtd_ref_accept_count": record.get("RAW_DMTD_REF_ACCEPT_COUNT"),
                "raw_dmtd_fb_accept_count": record.get("RAW_DMTD_FB_ACCEPT_COUNT"),
                "raw_epoch_after": record.get("RAW_EPOCH_AFTER"),
                "epoch_before": _num(record.get("EPOCH_BEFORE")),
                "epoch_after": _num(record.get("EPOCH_AFTER")),
                "update_count": _num(record.get("UPDATE_COUNT")),
                "helper_error": _num(record.get("HELPER_ERROR")),
                "helper_output": _num(record.get("HELPER_OUTPUT")),
                "transport_error": int(_flag(record, "TRANSPORT_ERROR")),
                "parse_error": int(_flag(record, "PARSE_ERROR")),
                "odd_or_sentinel": int(_flag(record, "ODD_OR_SENTINEL")),
                "epoch_changed": int(_flag(record, "EPOCH_CHANGED")),
                "arithmetic_mismatch": int(_flag(record, "ARITHMETIC_MISMATCH")),
                "range_mismatch": int(_flag(record, "RANGE_MISMATCH")),
                "accepted": int(_flag(record, "ACCEPTED")),
                "owner_unverified": int(_flag(record, "OWNER_UNVERIFIED")),
                "reason": record.get("REASON"),
                "shape_valid": int(_attempt_valid_shape(record)),
            }
            all_rows.append(row)

    core_records = by_profile.get("CORE", [])
    core_accepted = [record for record in core_records if _flag(record, "ACCEPTED")]
    core_fresh = 0
    core_stale = 0
    core_ambiguous = 0
    core_progress_rows: List[Dict[str, Any]] = []
    previous_update: Optional[int] = None
    for record in core_accepted:
        current_update = _num(record.get("UPDATE_COUNT"))
        status = "BASELINE"
        delta: Optional[int] = None
        if previous_update is not None:
            delta = _counter_delta(previous_update, current_update)
            if delta is None:
                status = "AMBIGUOUS"
                core_ambiguous += 1
            elif delta > 0:
                status = "FRESH"
                core_fresh += 1
            else:
                status = "STALE"
                core_stale += 1
        previous_update = current_update
        core_progress_rows.append({
            "cycle": _num(record.get("CYCLE")),
            "host_end_ms": _num(record.get("HOST_END_MS")),
            "update_count": current_update,
            "delta": delta,
            "status": status,
        })
    accepted_times = [_num(record.get("HOST_END_MS")) for record in core_accepted]
    accepted_times = [value for value in accepted_times if value is not None]
    core_span_ms = max(accepted_times) - min(accepted_times) if accepted_times else 0

    # Per-cycle profile alternation is checked independently of retry count.
    cycles: Dict[int, str] = {}
    alternating = True
    for record in _records_from_attempts_by_cycle(attempts):
        cycle = _num(record.get("CYCLE"))
        if cycle is None:
            alternating = False
            continue
        profile = _profile(record)
        if cycle in cycles and cycles[cycle] != profile:
            alternating = False
        cycles[cycle] = profile
    ordered_cycles = sorted(cycles)
    for previous_cycle, current_cycle in zip(ordered_cycles, ordered_cycles[1:]):
        if current_cycle == previous_cycle + 1:
            expected = "CORE" if cycles[previous_cycle] == "FULL" else "FULL"
            if cycles[current_cycle] != expected:
                alternating = False
    return {
        "profiles": profile_result,
        "attempt_rows": all_rows,
        "attempt_count": len(attempts),
        "valid_attempt_shape_count": sum(_attempt_valid_shape(record) for record in attempts),
        "attempt_shape_errors": sum(not _attempt_valid_shape(record) for record in attempts),
        "payload_isolation_pass": all(_attempt_valid_shape(record) for record in attempts),
        "core_fresh_count": core_fresh,
        "core_stale_count": core_stale,
        "core_ambiguous_count": core_ambiguous,
        "core_coherent_accepted_count": len(core_accepted),
        "core_accepted_first_host_ms": min(accepted_times) if accepted_times else None,
        "core_accepted_last_host_ms": max(accepted_times) if accepted_times else None,
        "core_accepted_span_ms": core_span_ms,
        "core_progress_rows": core_progress_rows,
        "alternating_profiles_pass": alternating and bool(cycles),
        "cycles_observed": len(cycles),
        "cycle_profile_map": {str(key): cycles[key] for key in ordered_cycles},
    }


def _records_from_attempts_by_cycle(attempts: Sequence[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Return one representative profile record per cycle, preserving order."""
    representatives: Dict[int, Dict[str, Any]] = {}
    for record in attempts:
        cycle = _num(record.get("CYCLE"))
        if cycle is not None and cycle not in representatives:
            representatives[cycle] = record
    return [representatives[key] for key in sorted(representatives)]


def _profile_retry_checks(profiles: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    by_cycle: Dict[Tuple[str, int], int] = defaultdict(int)
    for record in profiles:
        profile = _profile(record)
        cycle = _num(record.get("CYCLE"))
        if cycle is not None:
            by_cycle[(profile, cycle)] += _num(record.get("ATTEMPTS")) or 0
    # PROFILE is emitted once per cycle, so this is a direct upper-bound check.
    maximum = max(by_cycle.values(), default=0)
    return {"profile_summary_rows": len(profiles), "max_attempts_per_cycle": maximum,
            "retry_bound_pass": maximum <= 8}


def _background_summary(background: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    return {
        "sample_count": len(background),
        "roles": dict(Counter(str(record.get("ROLE") or "UNKNOWN") for record in background)),
        "valid_count": sum(_flag(record, "VALID") for record in background),
        "reset_changed_count": sum(_flag(record, "RESET_CHANGED") for record in background),
        "terminal_count": sum(_flag(record, "TERMINAL") for record in background),
        "transport_error_count": sum(_flag(record, "TRANSPORT_ERROR") for record in background),
    }


def classify(result: Dict[str, Any], min_fresh: int = 20,
             min_span_ms: int = 10000) -> str:
    attempts = result["attempts"]
    full = attempts["profiles"].get("FULL", {})
    core = attempts["profiles"].get("CORE", {})
    if result["background"]["reset_changed_count"]:
        return "RESET_OR_GENERATION_CHANGE"
    if result["background"]["terminal_count"]:
        return "WR_SESSION_ENDED"
    if result["config_error"]:
        return "DATA_UNRESOLVED"
    if attempts["attempt_shape_errors"] or not attempts["payload_isolation_pass"]:
        return "DATA_UNRESOLVED"
    if not attempts["attempt_count"]:
        return "NO_READ_ONLY_COHERENT_WINDOW"
    if not attempts["alternating_profiles_pass"]:
        return "PROFILE_ALTERNATION_INVALID"
    if core.get("attempt_count", 0) and core.get("accepted_count", 0) == 0:
        if core.get("transport_error_count", 0) or core.get("parse_error_count", 0):
            return "TRANSPORT_LIMITED"
        if full.get("epoch_changed_count", 0) or core.get("epoch_changed_count", 0):
            return "NO_READ_ONLY_COHERENT_WINDOW"
        return "NO_READ_ONLY_COHERENT_WINDOW"
    if (full.get("epoch_changed_count", 0) > 0
            and attempts["core_fresh_count"] >= min_fresh
            and attempts["core_accepted_span_ms"] >= min_span_ms):
        return "COMPACT_HELPER_CORE_OBSERVABLE"
    if (full.get("accepted_count", 0) == 0
            and (full.get("arithmetic_mismatch_count", 0)
                 or full.get("range_mismatch_count", 0))):
        return "READER_CONTRACT_MISMATCH"
    if (attempts["core_stale_count"] > 0
            and attempts["core_fresh_count"] == 0):
        return "STALE_OR_IDLE_PUBLISHER"
    return "INCONCLUSIVE"


def analyze_text(text: str, source: str = "", min_fresh: int = 20,
                 min_span_ms: int = 10000) -> Dict[str, Any]:
    attempts = parse_attempts(text)
    profiles = parse_profiles(text)
    cycles = parse_cycles(text)
    background = parse_background(text)
    config = parse_config(text)
    done = parse_done(text)
    role_summaries = parse_role_summaries(text)
    config_error = config is None or done is None
    if config is not None:
        config_error = config_error or not all(
            str(config.get(key, "")).upper() == expected
            for key, expected in (("READ_ONLY_OBSERVER", "1"),
                                  ("ONE_READER", "1"),
                                  ("NO_CONTROL_WRITE", "1"),
                                  ("NO_HELPER_PI_SNAPSHOT", "1"),
                                  ("NO_DEBUG_FIFO_DRAIN", "1"),
                                  ("CORE_ENABLED", "1")))
    attempt_result = _classify_attempts(attempts)
    retry_result = _profile_retry_checks(profiles)
    background_result = _background_summary(background)
    result: Dict[str, Any] = {
        "format": "step5-f4f-helper-contract-audit-v1",
        "source": source,
        "config": config,
        "done": done,
        "role_summaries": role_summaries,
        "attempt_count": len(attempts),
        "profile_summary_count": len(profiles),
        "cycle_count": len(cycles),
        "attempts": attempt_result,
        "profile_retries": retry_result,
        "background": background_result,
        "config_error": bool(config_error),
        "all_attempts_same_board": _same_board(attempts),
        "classification": "INCONCLUSIVE",
        "diagnostic_pass": False,
        "step5_complete": False,
        "step5_pass": False,
        "merge_approved": False,
        "attempt_records": attempts,
        "profile_records": profiles,
        "cycle_records": cycles,
        "background_records": background,
    }
    result["classification"] = classify(result, min_fresh=min_fresh, min_span_ms=min_span_ms)
    result["diagnostic_pass"] = result["classification"] in {
        "COMPACT_HELPER_CORE_OBSERVABLE", "READER_CONTRACT_MISMATCH",
        "TRANSPORT_LIMITED", "STALE_OR_IDLE_PUBLISHER",
    }
    return result


def _write_csv(path: Path, rows: Iterable[Dict[str, Any]]) -> None:
    materialized = list(rows)
    fields: List[str] = []
    for row in materialized:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(materialized)


def write_outputs(result: Dict[str, Any], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    _write_csv(output_dir / "attempts.csv", result["attempts"]["attempt_rows"])
    _write_csv(output_dir / "profile_records.csv", result["profile_records"])
    _write_csv(output_dir / "cycle_records.csv", result["cycle_records"])
    _write_csv(output_dir / "background_records.csv", result["background_records"])
    compact = {key: value for key, value in result.items()
               if key not in {"attempt_records", "profile_records", "cycle_records",
                              "background_records"}}
    (output_dir / "verdict.json").write_text(
        json.dumps(compact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--min-fresh", type=int, default=20)
    parser.add_argument("--min-span-ms", type=int, default=10000)
    args = parser.parse_args()
    text = args.log.read_text(encoding="utf-8", errors="replace")
    result = analyze_text(str(text), source=str(args.log), min_fresh=args.min_fresh,
                          min_span_ms=args.min_span_ms)
    if args.output_dir:
        write_outputs(result, args.output_dir)
    print(json.dumps({
        "classification": result["classification"],
        "diagnostic_pass": result["diagnostic_pass"],
        "attempt_count": result["attempt_count"],
        "full_accepted": result["attempts"]["profiles"].get("FULL", {}).get("accepted_count", 0),
        "core_accepted": result["attempts"]["profiles"].get("CORE", {}).get("accepted_count", 0),
        "core_fresh": result["attempts"]["core_fresh_count"],
        "core_span_ms": result["attempts"]["core_accepted_span_ms"],
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
