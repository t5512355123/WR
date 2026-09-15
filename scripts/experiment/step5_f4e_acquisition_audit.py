#!/usr/bin/env python3
"""Replay and classify the read-only Step5 F4E acquisition capture.

F4E is deliberately a diagnostic result, not a Step5 lock verdict.  The
observer interleaves one Master and one Slave from a single Tcl process, while
the analysis keeps the roles, publication groups, counter windows, and actual
elapsed times separate.  In particular, a changing publication epoch is not
treated as a Main producer update; only a fresh producer ``sample_n`` is.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import tarfile
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
import sys

sys.path.insert(0, str(REPO_ROOT / "scripts" / "analysis"))

from step5_replay import parse_key_values  # noqa: E402


SAMPLE_PREFIX = "STEP5_F4E_SAMPLE"
ENTRY_PREFIX = "STEP5_F4E_ENTRY"
CONFIG_PREFIX = "STEP5_F4E_CONFIG"
DONE_PREFIX = "STEP5_F4E_DONE"
ROLE_SUMMARY_PREFIX = "STEP5_F4E_ROLE_SUMMARY"
INVALID = {"INVALID", "UNKNOWN", "NEVER", "NA", "N/A", "TIMEOUT"}
HEX_RE = re.compile(r"^[0-9A-Fa-f]+$")


def parse_samples(text: str) -> List[Dict[str, Any]]:
    return [
        {**parse_key_values(line), "_line": line.rstrip("\r\n")}
        for line in text.splitlines()
        if line.startswith(SAMPLE_PREFIX + " ")
    ]


def parse_entries(text: str) -> List[Dict[str, Any]]:
    return [parse_key_values(line) for line in text.splitlines()
            if line.startswith(ENTRY_PREFIX + " ")]


def parse_config(text: str) -> Optional[Dict[str, Any]]:
    for line in text.splitlines():
        if line.startswith(CONFIG_PREFIX + " "):
            return parse_key_values(line)
    return None


def parse_done(text: str) -> Optional[Dict[str, Any]]:
    for line in text.splitlines():
        if line.startswith(DONE_PREFIX + " "):
            return parse_key_values(line)
    return None


def parse_role_summaries(text: str) -> List[Dict[str, Any]]:
    return [parse_key_values(line) for line in text.splitlines()
            if line.startswith(ROLE_SUMMARY_PREFIX + " ")]


def _num(value: Any) -> Optional[int]:
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if not isinstance(value, str):
        return None
    text = value.strip()
    if text.upper() in INVALID:
        return None
    prefixed_hex = text.lower().startswith("0x")
    if prefixed_hex:
        text = text[2:]
        try:
            return int(text, 16)
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
    return isinstance(value, str) and value.strip().upper() in {"1", "YES", "PASS", "TRUE"}


def _time(record: Dict[str, Any]) -> Optional[int]:
    return _num(record.get("ELAPSED_MS"))


def _same_reset(previous: Dict[str, Any], current: Dict[str, Any]) -> bool:
    keys = ("BOOT_GENERATION", "CPU_RESET_COUNT", "WR_CORE_RESET_COUNT",
            "SI_CONFIG_DROP_COUNT")
    values = [(_num(previous.get(key)), _num(current.get(key))) for key in keys]
    return all(old is not None and new is not None and old == new
               for old, new in values)


def _gap_ok(previous: Dict[str, Any], current: Dict[str, Any], max_gap_ms: int) -> bool:
    old = _time(previous)
    new = _time(current)
    return old is not None and new is not None and 0 < new - old <= max_gap_ms


def _main_sample_n(record: Dict[str, Any]) -> Optional[int]:
    return _num(record.get("MAIN_SAMPLE_N"))


def _publication_coherent(record: Dict[str, Any]) -> bool:
    before = _num(record.get("MAIN_TRACE_PUBLICATION_EPOCH_BEFORE_RAW"))
    after = _num(record.get("MAIN_TRACE_PUBLICATION_EPOCH_AFTER_RAW"))
    epoch = _num(record.get("MAIN_PUBLICATION_EPOCH"))
    return (before is not None and after is not None and epoch is not None
            and before == after == epoch and epoch % 2 == 0)


def _producer_fresh(record: Dict[str, Any], previous: Optional[Dict[str, Any]]) -> bool:
    if previous is None or not _flag(record, "MAIN_SAMPLE_N_ADVANCED"):
        return False
    current = _main_sample_n(record)
    old = _main_sample_n(previous)
    if current is None or old is None or current == old:
        return False
    if _flag(record, "MAIN_SAMPLE_N_DELTA_AMBIGUOUS"):
        return False
    return True


def _valid_acquisition_frame(record: Dict[str, Any]) -> bool:
    """Return whether this row can belong to the phase-qualified segment."""
    required_flags = (
        "TRANSPORT_VALID", "ROLE_IDENTITY_VALID", "PHY_LINK_USABLE",
        "RESET_FIELDS_VALID", "RESET_STABLE", "MAIN_CORE_VALID",
        "MAIN_TRACE_VALID", "MAIN_DETECTOR_VALID", "MAIN_DETECTOR_STABLE",
        "MAIN_DETECTOR_ENABLED", "MAIN_DETECTOR_FREQ_LOCKED",
        "HELPER_MEASUREMENT_OK", "POSITION_OK", "L2_VALID",
        "HELPER_LOCKED",
    )
    if not all(_flag(record, key) for key in required_flags):
        return False
    if _num(record.get("WR_STATE")) != 2:
        return False
    if _flag(record, "WR_DISABLE_VALID"):
        return False
    if _num(record.get("PD_STATE")) == 4 or _num(record.get("EXT_STATE")) == 0:
        return False
    if not _publication_coherent(record):
        return False
    if _main_sample_n(record) is None:
        return False
    if _time(record) is None:
        return False
    return True


def _phase_domain(record: Dict[str, Any]) -> bool:
    return (record.get("MAIN_PHASE_INPUT_DOMAIN") == "PHASE"
            and _num(record.get("MAIN_PI_X")) is not None
            and _num(record.get("MAIN_PHASE_THRESHOLD")) is not None)


def _counter_window(previous: Dict[str, Any], current: Dict[str, Any], key: str,
                    max_gap_ms: int) -> Optional[Dict[str, Any]]:
    if not (_valid_acquisition_frame(previous) and _valid_acquisition_frame(current)):
        return None
    if not (_gap_ok(previous, current, max_gap_ms)
            and _same_reset(previous, current)):
        return None
    old = _num(previous.get(key))
    new = _num(current.get(key))
    if old is None or new is None:
        return None
    delta = (new - old) & 0xFFFFFFFF
    if delta > 0x7FFFFFFF:
        return {"delta": None, "ambiguous": 1}
    return {"delta": delta, "ambiguous": 0}


def _segments(records: Sequence[Dict[str, Any]], max_gap_ms: int) -> List[Dict[str, Any]]:
    segments: List[Dict[str, Any]] = []
    active: Optional[Dict[str, Any]] = None
    previous: Optional[Dict[str, Any]] = None
    for record in records:
        valid = _valid_acquisition_frame(record)
        contiguous = (previous is not None and valid
                       and _gap_ok(previous, record, max_gap_ms)
                       and _same_reset(previous, record)
                       and not _flag(record, "MAIN_SAMPLE_N_DELTA_AMBIGUOUS"))
        fresh = valid and _producer_fresh(record, previous)
        if valid and (active is None or contiguous):
            if active is None:
                active = {"start_ms": _time(record), "end_ms": _time(record),
                          "valid_samples": 1, "fresh_samples": 0,
                          "phase_lock_samples": 0, "phase_inband_samples": 0,
                          "records": [record]}
            else:
                active["end_ms"] = _time(record)
                active["valid_samples"] += 1
                active["records"].append(record)
            if fresh:
                active["fresh_samples"] += 1
            if _flag(record, "MAIN_DETECTOR_PHASE_LOCKED"):
                active["phase_lock_samples"] += 1
            if record.get("MAIN_PHASE_INBAND") == 1:
                active["phase_inband_samples"] += 1
        else:
            if active is not None:
                active["duration_ms"] = active["end_ms"] - active["start_ms"]
                segments.append(active)
            active = None
            if valid:
                active = {"start_ms": _time(record), "end_ms": _time(record),
                          "valid_samples": 1, "fresh_samples": 0,
                          "phase_lock_samples": int(_flag(record, "MAIN_DETECTOR_PHASE_LOCKED")),
                          "phase_inband_samples": int(record.get("MAIN_PHASE_INBAND") == 1),
                          "records": [record]}
        previous = record
    if active is not None:
        active["duration_ms"] = active["end_ms"] - active["start_ms"]
        segments.append(active)
    return segments


def _service_windows(records: Sequence[Dict[str, Any]], max_gap_ms: int) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for previous, current in zip(records, records[1:]):
        if not (_valid_acquisition_frame(previous) and _valid_acquisition_frame(current)):
            continue
        if not (_gap_ok(previous, current, max_gap_ms)
                and _same_reset(previous, current)):
            continue
        row: Dict[str, Any] = {
            "role": current.get("ROLE"),
            "board": current.get("BOARD"),
            "previous_elapsed_ms": _time(previous),
            "elapsed_ms": _time(current),
            "gap_ms": (_time(current) or 0) - (_time(previous) or 0),
            "main_sample_n_advanced": int(_producer_fresh(current, previous)),
            "helper_residual_present": current.get("HELPER_RESIDUAL_PRESENT"),
            "helper_measurement_residual_present": current.get("HELPER_MEASUREMENT_RESIDUAL_PRESENT"),
            "l2_main_pending": current.get("L2_MAIN_PENDING"),
            "l2_helper_pending": current.get("L2_HELPER_PENDING"),
        }
        for field in (
            "L2_MAIN_PENDING_COUNT", "L2_HELPER_PENDING_COUNT",
            "L2_MAIN_START_COUNT", "L2_HELPER_START_COUNT",
            "L2_MAIN_COMPLETED_COUNT", "L2_HELPER_COMPLETED_COUNT",
            "L2_MAIN_FAILED_COUNT", "L2_HELPER_FAILED_COUNT",
        ):
            result = _counter_window(previous, current, field, max_gap_ms)
            row[field.lower() + "_delta"] = result["delta"] if result else None
            row[field.lower() + "_ambiguous"] = result["ambiguous"] if result else None
        rows.append(row)
    return rows


def _reset_changes(records: Sequence[Dict[str, Any]]) -> Dict[str, int]:
    generation = 0
    reset = 0
    for previous, current in zip(records, records[1:]):
        old_generation = _num(previous.get("BOOT_GENERATION"))
        new_generation = _num(current.get("BOOT_GENERATION"))
        if old_generation is not None and new_generation is not None and old_generation != new_generation:
            generation += 1
        for key in ("CPU_RESET_COUNT", "WR_CORE_RESET_COUNT", "SI_CONFIG_DROP_COUNT"):
            old = _num(previous.get(key))
            new = _num(current.get(key))
            if old is not None and new is not None and old != new:
                reset += 1
                break
    return {"generation_changes": generation, "reset_changes": reset}


def _record_row(record: Dict[str, Any], previous: Optional[Dict[str, Any]],
                max_gap_ms: int) -> Dict[str, Any]:
    row: Dict[str, Any] = {
        "role": record.get("ROLE"),
        "board": record.get("BOARD"),
        "sample": record.get("SAMPLE"),
        "elapsed_ms": _time(record),
        "read_start_ms": _num(record.get("READ_START_MS")),
        "read_end_ms": _num(record.get("READ_END_MS")),
        "transport_valid": int(_flag(record, "TRANSPORT_VALID")),
        "core_frame_valid": int(_flag(record, "CORE_FRAME_VALID")),
        "role_identity_valid": int(_flag(record, "ROLE_IDENTITY_VALID")),
        "phy_link_usable": int(_flag(record, "PHY_LINK_USABLE")),
        "boot_generation": _num(record.get("BOOT_GENERATION")),
        "cpu_reset_count": _num(record.get("CPU_RESET_COUNT")),
        "wr_core_reset_count": _num(record.get("WR_CORE_RESET_COUNT")),
        "si_config_drop_count": _num(record.get("SI_CONFIG_DROP_COUNT")),
        "reset_stable": int(_flag(record, "RESET_STABLE")),
        "ptp_state": _num(record.get("PTP_STATE")),
        "pd_state": _num(record.get("PD_STATE")),
        "ext_state": _num(record.get("EXT_STATE")),
        "wr_state": _num(record.get("WR_STATE")),
        "wr_disable_valid": int(_flag(record, "WR_DISABLE_VALID")),
        "wr_failure_reason": _num(record.get("WR_FAILURE_REASON")),
        "main_core_valid": int(_flag(record, "MAIN_CORE_VALID")),
        "main_trace_valid": int(_flag(record, "MAIN_TRACE_VALID")),
        "main_detector_valid": int(_flag(record, "MAIN_DETECTOR_VALID")),
        "main_detector_stable": int(_flag(record, "MAIN_DETECTOR_STABLE")),
        "main_enabled": int(_flag(record, "MAIN_DETECTOR_ENABLED")),
        "main_freq_locked": int(_flag(record, "MAIN_DETECTOR_FREQ_LOCKED")),
        "main_phase_locked": int(_flag(record, "MAIN_DETECTOR_PHASE_LOCKED")),
        "main_phase_input_domain": record.get("MAIN_PHASE_INPUT_DOMAIN"),
        "main_phase_inband": record.get("MAIN_PHASE_INBAND"),
        "main_pi_x": _num(record.get("MAIN_PI_X")),
        "main_phase_threshold": _num(record.get("MAIN_PHASE_THRESHOLD")),
        "main_sample_n": _main_sample_n(record),
        "main_sample_n_delta": _num(record.get("MAIN_SAMPLE_N_DELTA")),
        "main_sample_n_delta_ambiguous": int(_flag(record, "MAIN_SAMPLE_N_DELTA_AMBIGUOUS")),
        "main_sample_n_advanced": int(_flag(record, "MAIN_SAMPLE_N_ADVANCED")),
        "producer_fresh_vs_previous": int(_producer_fresh(record, previous)),
        "main_publication_epoch": _num(record.get("MAIN_PUBLICATION_EPOCH")),
        "publication_coherent": int(_publication_coherent(record)),
        "helper_measurement_ok": int(_flag(record, "HELPER_MEASUREMENT_OK")),
        "helper_locked": int(_flag(record, "HELPER_LOCKED")),
        "helper_error": _num(record.get("HELPER_ERROR")),
        "helper_output": _num(record.get("HELPER_OUTPUT")),
        "helper_target_code": _num(record.get("HELPER_TARGET_CODE")),
        "helper_applied_code": _num(record.get("HELPER_APPLIED_CODE")),
        "helper_residual_present": record.get("HELPER_RESIDUAL_PRESENT"),
        "helper_measurement_residual_present": record.get("HELPER_MEASUREMENT_RESIDUAL_PRESENT"),
        "position_ok": int(_flag(record, "POSITION_OK")),
        "l2_valid": int(_flag(record, "L2_VALID")),
        "l2_main_pending": record.get("L2_MAIN_PENDING"),
        "l2_helper_pending": record.get("L2_HELPER_PENDING"),
        "l2_main_pending_count": _num(record.get("L2_MAIN_PENDING_COUNT")),
        "l2_helper_pending_count": _num(record.get("L2_HELPER_PENDING_COUNT")),
        "l2_main_start_count": _num(record.get("L2_MAIN_START_COUNT")),
        "l2_helper_start_count": _num(record.get("L2_HELPER_START_COUNT")),
        "l2_main_completed_count": _num(record.get("L2_MAIN_COMPLETED_COUNT")),
        "l2_helper_completed_count": _num(record.get("L2_HELPER_COMPLETED_COUNT")),
        "l2_main_failed_count": _num(record.get("L2_MAIN_FAILED_COUNT")),
        "l2_helper_failed_count": _num(record.get("L2_HELPER_FAILED_COUNT")),
        "acquisition_diagnostic_allowed": int(_flag(record, "ACQUISITION_DIAGNOSTIC_ALLOWED")),
        "entry_class": record.get("ENTRY_CLASS"),
        "stop_reason": record.get("STOP_REASON"),
    }
    if previous is None:
        row["gap_ms"] = None
        row["same_reset_as_previous"] = 0
    else:
        old = _time(previous)
        new = _time(record)
        row["gap_ms"] = new - old if old is not None and new is not None else None
        row["same_reset_as_previous"] = int(_same_reset(previous, record))
    return row


def _classify_role(role: str, records: Sequence[Dict[str, Any]],
                   max_gap_ms: int, done: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    rows: List[Dict[str, Any]] = []
    previous: Optional[Dict[str, Any]] = None
    for record in records:
        rows.append(_record_row(record, previous, max_gap_ms))
        previous = record
    entry_records = [record for record in records if _flag(record, "ACQUISITION_DIAGNOSTIC_ALLOWED")]
    valid_records = [record for record in records if _valid_acquisition_frame(record)]
    fresh_valid_count = sum(
        _producer_fresh(record, records[index - 1] if index > 0 else None)
        for index, record in enumerate(records)
        if _valid_acquisition_frame(record)
    )
    segments = _segments(records, max_gap_ms)
    best_segment = max(segments, key=lambda item: (item["fresh_samples"], item["duration_ms"]), default=None)
    service_windows = _service_windows(records, max_gap_ms)
    residual_windows = [row for row in service_windows
                        if row.get("helper_residual_present") == 1
                        or row.get("helper_measurement_residual_present") == 1]
    main_service_stalled_windows = [row for row in residual_windows
                                    if row.get("l2_main_start_count_delta") == 0
                                    and row.get("l2_main_completed_count_delta") == 0]
    helper_service_stalled_windows = [row for row in residual_windows
                                      if row.get("l2_helper_start_count_delta") == 0
                                      and row.get("l2_helper_completed_count_delta") == 0]
    reset_changes = _reset_changes(records)
    stop_reason = None
    if done is not None:
        stop_reason = done.get("STOP_REASON")
    if not stop_reason:
        for record in records:
            if record.get("STOP_REASON") not in (None, "NONE"):
                stop_reason = record.get("STOP_REASON")
                break
    phase_locked_count = sum(_flag(record, "MAIN_DETECTOR_PHASE_LOCKED") for record in valid_records)
    progress_count = sum(_flag(record, "MAIN_SAMPLE_N_ADVANCED") for record in valid_records)
    phase_domain_count = sum(_phase_domain(record) for record in valid_records)
    phase_inband_count = sum(record.get("MAIN_PHASE_INBAND") == 1 for record in valid_records)
    pi_values = [_num(record.get("MAIN_PI_X")) for record in valid_records]
    pi_values = [value for value in pi_values if value is not None]
    return {
        "role": role,
        "sample_count": len(records),
        "entry_seen": bool(entry_records),
        "entry_sample": _num(entry_records[0].get("SAMPLE")) if entry_records else None,
        "entry_elapsed_ms": _time(entry_records[0]) if entry_records else None,
        "acquisition_allowed_samples": len(entry_records),
        "valid_acquisition_samples": len(valid_records),
        "fresh_main_producer_samples": fresh_valid_count,
        "main_progress_samples": progress_count,
        "phase_domain_samples": phase_domain_count,
        "phase_inband_samples": phase_inband_count,
        "phase_locked_samples": phase_locked_count,
        "phase_pi_min": min(pi_values) if pi_values else None,
        "phase_pi_max": max(pi_values) if pi_values else None,
        "segments": [
            {key: value for key, value in segment.items() if key != "records"}
            for segment in segments
        ],
        "best_segment": ({key: value for key, value in best_segment.items() if key != "records"}
                         if best_segment else None),
        "service_window_count": len(service_windows),
        "residual_window_count": len(residual_windows),
        "main_service_stalled_window_count": len(main_service_stalled_windows),
        "helper_service_stalled_window_count": len(helper_service_stalled_windows),
        "reset_changes": reset_changes,
        "transport_invalid_samples": sum(not _flag(record, "TRANSPORT_VALID") for record in records),
        "phase_convergence_observed": phase_locked_count > 0,
        "stop_reason": stop_reason,
        "diagnostic_result": "INCONCLUSIVE",
        "diagnostic_pass": False,
        "step5_complete": False,
        "step5_pass": False,
    }, rows, service_windows, main_service_stalled_windows, helper_service_stalled_windows


def _diagnostic_result(role_result: Dict[str, Any], done: Optional[Dict[str, Any]],
                      min_fresh_samples: int, min_duration_ms: int) -> str:
    if role_result["reset_changes"]["generation_changes"] or role_result["reset_changes"]["reset_changes"]:
        return "DETECTOR_CONSISTENCY_UNRESOLVED"
    if role_result["transport_invalid_samples"] >= 3:
        return "DATA_UNRESOLVED"
    if not role_result["entry_seen"]:
        return "NO_ELIGIBLE_ACQUISITION_WINDOW"
    best = role_result.get("best_segment")
    enough_segment = bool(best and best.get("fresh_samples", 0) >= min_fresh_samples
                          and best.get("duration_ms", 0) >= min_duration_ms)
    stop_reason = str(role_result.get("stop_reason") or "")
    if stop_reason in {"WR_SESSION_ENDED", "REFERENCE_OR_SESSION_LIMITED"}:
        return "REFERENCE_OR_SESSION_LIMITED"
    if stop_reason in {"DATA_UNRESOLVED", "RESET_OR_GENERATION_CHANGE"}:
        return "DATA_UNRESOLVED"
    if role_result["main_service_stalled_window_count"] >= 2 and role_result["main_progress_samples"] == 0:
        return "MAIN_SERVICE_BLOCKED_SUSPECTED"
    if role_result["helper_service_stalled_window_count"] >= 2 and role_result["main_progress_samples"] > 0:
        return "HELPER_ADMISSION_SUSPECTED"
    if not enough_segment:
        return "INCONCLUSIVE"
    if role_result["phase_convergence_observed"]:
        return "LOCK_OBSERVED_NOT_CLOSED"
    return "PHASE_CONVERGENCE_NOT_REACHED"


def analyze_text(text: str, source: str = "", max_gap_ms: int = 10000,
                min_fresh_samples: int = 20, min_duration_ms: int = 10000) -> Dict[str, Any]:
    samples = parse_samples(text)
    config = parse_config(text)
    done = parse_done(text)
    entries = parse_entries(text)
    role_summaries = parse_role_summaries(text)
    grouped: Dict[str, List[Dict[str, Any]]] = {}
    for record in samples:
        grouped.setdefault(str(record.get("ROLE", "UNKNOWN")), []).append(record)
    timeline: List[Dict[str, Any]] = []
    service_windows: List[Dict[str, Any]] = []
    main_stalled_windows: List[Dict[str, Any]] = []
    helper_stalled_windows: List[Dict[str, Any]] = []
    roles: Dict[str, Dict[str, Any]] = {}
    for role, records in grouped.items():
        role_result, rows, windows, main_stalled, helper_stalled = _classify_role(
            role, records, max_gap_ms, done)
        role_result["diagnostic_result"] = _diagnostic_result(
            role_result, done, min_fresh_samples, min_duration_ms)
        role_result["diagnostic_pass"] = role_result["diagnostic_result"] not in {
            "DATA_UNRESOLVED", "NO_ELIGIBLE_ACQUISITION_WINDOW", "INCONCLUSIVE",
        }
        roles[role] = role_result
        timeline.extend(rows)
        service_windows.extend(windows)
        main_stalled_windows.extend(main_stalled)
        helper_stalled_windows.extend(helper_stalled)

    slave = roles.get("SLAVE")
    if config is None or done is None:
        overall_result = "DATA_UNRESOLVED"
    elif slave is None:
        overall_result = "NO_ELIGIBLE_ACQUISITION_WINDOW"
    else:
        overall_result = slave["diagnostic_result"]
    return {
        "format": "step5-f4e-acquisition-audit-v1",
        "source": source,
        "config": config,
        "done": done,
        "entries": entries,
        "role_summaries": role_summaries,
        "sample_count": len(samples),
        "sample_error_count": sum(1 for line in text.splitlines() if "READ_ERROR=" in line),
        "roles": roles,
        "overall_result": overall_result,
        "overall_pass": overall_result not in {
            "DATA_UNRESOLVED", "NO_ELIGIBLE_ACQUISITION_WINDOW", "INCONCLUSIVE",
        },
        "step5_complete": False,
        "step5_pass": False,
        "merge_approved": False,
        "timeline": timeline,
        "service_windows": service_windows,
        "main_service_stalled_windows": main_stalled_windows,
        "helper_service_stalled_windows": helper_stalled_windows,
    }


def _write_csv(path: Path, rows: Iterable[Dict[str, Any]]) -> None:
    rows = list(rows)
    fields: List[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def write_outputs(result: Dict[str, Any], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    compact = {key: value for key, value in result.items()
               if key not in {"timeline", "service_windows", "main_service_stalled_windows",
                              "helper_service_stalled_windows"}}
    (output_dir / "verdict.json").write_text(
        json.dumps(compact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    _write_csv(output_dir / "timeline.csv", result["timeline"])
    _write_csv(output_dir / "service_windows.csv", result["service_windows"])
    _write_csv(output_dir / "main_service_stalled_windows.csv",
               result["main_service_stalled_windows"])
    _write_csv(output_dir / "helper_service_stalled_windows.csv",
               result["helper_service_stalled_windows"])
    summary_rows: List[Dict[str, Any]] = []
    for role, role_result in result["roles"].items():
        summary_rows.append({key: value for key, value in role_result.items()
                             if key not in {"segments", "best_segment"}})
    _write_csv(output_dir / "role_summary.csv", summary_rows)


def _read_path(path: Path) -> str:
    if path.suffix == ".tgz" or path.suffixes[-2:] == [".tar", ".gz"]:
        with tarfile.open(path, "r:gz") as archive:
            members = [member for member in archive.getmembers()
                       if member.isfile() and member.name.endswith((".log", ".txt"))]
            if not members:
                raise ValueError(f"no log file in {path}")
            member = sorted(members, key=lambda item: item.name)[-1]
            extracted = archive.extractfile(member)
            if extracted is None:
                raise ValueError(f"cannot read {member.name} in {path}")
            return extracted.read().decode("utf-8", errors="replace")
    return path.read_text(encoding="utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", action="append", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--max-gap-ms", type=int, default=10000)
    parser.add_argument("--min-fresh-samples", type=int, default=20)
    parser.add_argument("--min-duration-ms", type=int, default=10000)
    args = parser.parse_args()
    results = [analyze_text(_read_path(path), str(path), args.max_gap_ms,
                            args.min_fresh_samples, args.min_duration_ms)
               for path in args.input]
    for index, result in enumerate(results):
        destination = args.output_dir if len(results) == 1 else args.output_dir / f"run-{index + 1:02d}"
        write_outputs(result, destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
