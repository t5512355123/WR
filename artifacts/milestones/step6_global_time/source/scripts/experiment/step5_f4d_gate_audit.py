#!/usr/bin/env python3
"""Replay the read-only F4D WR gate/session timeline.

The observer samples independently published groups.  This audit keeps the
groups and board roles separate, requires adjacent same-generation frames for
streaks and counter deltas, and never converts an upstream observation into a
Step5 lock claim.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple


REPO_ROOT = Path(__file__).resolve().parents[2]
import sys

sys.path.insert(0, str(REPO_ROOT / "scripts" / "analysis"))

from step5_replay import parse_key_values  # noqa: E402


SAMPLE_PREFIX = "STARTUP_TIMELINE_SAMPLE"
SAMPLE_ERROR_PREFIX = "STARTUP_TIMELINE_SAMPLE_ERROR"
CONFIG_PREFIX = "STARTUP_TIMELINE_CONFIG"
DONE_PREFIX = "STARTUP_TIMELINE_DONE"
INVALID = {"INVALID", "UNKNOWN", "NEVER", "NA", "N/A"}
HEX_RE = re.compile(r"^[0-9A-Fa-f]+$")


def parse_samples(text: str) -> List[Dict[str, Any]]:
    samples: List[Dict[str, Any]] = []
    for line in text.splitlines():
        if line.startswith(SAMPLE_PREFIX + " "):
            record = parse_key_values(line)
            record["_line"] = line.rstrip("\r\n")
            samples.append(record)
    return samples


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


def _int(value: Any) -> Optional[int]:
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if isinstance(value, str):
        text = value.strip()
        if text.upper() in INVALID or not HEX_RE.fullmatch(text):
            return None
        try:
            return int(text, 16)
        except ValueError:
            return None
    return None


def _decimal(value: Any) -> Optional[int]:
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if isinstance(value, str) and re.fullmatch(r"[-+]?\d+", value.strip()):
        try:
            return int(value, 10)
        except ValueError:
            return None
    return None


def _embedded_decimal(value: Any) -> Optional[int]:
    """Read the numeric prefix from source-backed values such as 9(SLAVE)."""
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if isinstance(value, str):
        match = re.match(r"^[-+]?\d+", value.strip())
        if match:
            try:
                return int(match.group(0), 10)
            except ValueError:
                return None
    return None


def _same_generation(previous: Dict[str, Any], current: Dict[str, Any]) -> bool:
    old = _int(previous.get("BOOT_GENERATION"))
    new = _int(current.get("BOOT_GENERATION"))
    return old is not None and new is not None and old == new


def _gap_ok(previous: Dict[str, Any], current: Dict[str, Any], max_gap_ms: int) -> bool:
    old = _decimal(previous.get("TIMESTAMP_MS"))
    new = _decimal(current.get("TIMESTAMP_MS"))
    return old is not None and new is not None and 0 < new - old <= max_gap_ms


def _core_valid(record: Dict[str, Any]) -> bool:
    return record.get("CORE_FRAME_VALID") == 1


def _terminal_state(record: Dict[str, Any]) -> str:
    value = record.get("F4D_TERMINAL_STATE")
    if isinstance(value, str) and value.upper() not in INVALID:
        return value.upper()
    return "UNKNOWN"


def _history_valid(record: Dict[str, Any]) -> bool:
    return record.get("F4D_TERMINAL_HISTORY_VALID") == 1


def _terminal_candidate(record: Dict[str, Any]) -> bool:
    return (_core_valid(record) and _terminal_state(record) in {"IDLE", "DISABLED", "FAILURE"}
            and _history_valid(record))


def _upstream_full_pass(record: Dict[str, Any]) -> bool:
    return record.get("F4D_UPSTREAM_FULL_PASS") == 1 and _core_valid(record)


def _streaks(records: Sequence[Dict[str, Any]], max_gap_ms: int) -> Tuple[List[int], List[int]]:
    terminal: List[int] = []
    upstream: List[int] = []
    terminal_streak = 0
    upstream_streak = 0
    previous: Optional[Dict[str, Any]] = None
    for record in records:
        adjacent = (previous is not None and _gap_ok(previous, record, max_gap_ms)
                    and _same_generation(previous, record))
        if _terminal_candidate(record):
            terminal_streak = terminal_streak + 1 if adjacent else 1
        else:
            terminal_streak = 0
        if _upstream_full_pass(record):
            upstream_streak = upstream_streak + 1 if adjacent else 1
        else:
            upstream_streak = 0
        terminal.append(terminal_streak)
        upstream.append(upstream_streak)
        previous = record
    return terminal, upstream


def _counter_deltas(records: Sequence[Dict[str, Any]], key: str, max_gap_ms: int) -> Dict[str, Any]:
    values: List[int] = []
    deltas: List[int] = []
    interrupted = 0
    previous: Optional[Dict[str, Any]] = None
    for record in records:
        value = _int(record.get(key))
        if value is None:
            interrupted += 1
            previous = record
            continue
        values.append(value)
        if previous is not None:
            old = _int(previous.get(key))
            if old is None or not _gap_ok(previous, record, max_gap_ms) or not _same_generation(previous, record):
                interrupted += 1
            else:
                deltas.append((value - old) & 0xFFFFFFFF)
        previous = record
    return {
        "first": values[0] if values else None,
        "final": values[-1] if values else None,
        "delta_sum": sum(deltas),
        "delta_samples": len(deltas),
        "interrupted": interrupted,
    }


def _group_by_role(samples: Iterable[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    groups: Dict[str, List[Dict[str, Any]]] = {}
    for record in samples:
        role = str(record.get("ROLE", "UNKNOWN"))
        groups.setdefault(role, []).append(record)
    return groups


def _reset_changes(records: Sequence[Dict[str, Any]]) -> Tuple[int, int]:
    generation_changes = 0
    reset_changes = 0
    for previous, current in zip(records, records[1:]):
        old_generation = _int(previous.get("BOOT_GENERATION"))
        new_generation = _int(current.get("BOOT_GENERATION"))
        if old_generation is not None and new_generation is not None and old_generation != new_generation:
            generation_changes += 1
        for key in ("CPU_RESET_COUNT", "WR_CORE_RESET_COUNT", "SI_CONFIG_RESET_COUNT"):
            old = _int(previous.get(key))
            new = _int(current.get(key))
            if old is not None and new is not None and old != new:
                reset_changes += 1
                break
    return generation_changes, reset_changes


def _condition_row(record: Dict[str, Any], terminal_streak: int, upstream_streak: int,
                   max_gap_ms: int, previous: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    row: Dict[str, Any] = {
        "role": record.get("ROLE"),
        "board": record.get("BOARD"),
        "sample": record.get("SAMPLE"),
        "timestamp_ms": record.get("TIMESTAMP_MS"),
        "core_frame_valid": record.get("CORE_FRAME_VALID"),
        "frame_valid": record.get("FRAME_VALID"),
        "boot_generation": _int(record.get("BOOT_GENERATION")),
        "cpu_reset_count": _int(record.get("CPU_RESET_COUNT")),
        "wr_core_reset_count": _int(record.get("WR_CORE_RESET_COUNT")),
        "si_config_reset_count": _int(record.get("SI_CONFIG_RESET_COUNT")),
        "wrc_mode": record.get("WRC_MODE"),
        "ptp_state": _embedded_decimal(record.get("PTP_STATE")),
        "ptp_state_name": record.get("PTP_STATE"),
        "pd_state": _embedded_decimal(record.get("PPSI_PDSTATE")),
        "ext_state": _embedded_decimal(record.get("PPSI_EXTSTATE")),
        "parent_is_wrnode": record.get("PARENTISWRNODE"),
        "parent_mode_on": record.get("PARENTMODEON"),
        "parent_calibrated": record.get("PARENTCALIBRATED"),
        "wr_state_value": record.get("WR_STATE_VALUE"),
        "wr_state_name": record.get("WR_STATE_NAME"),
        "wr_failure_low16": record.get("WR_FAILURE_LOW16"),
        "wr_failure_reason": record.get("WR_FAILURE_REASON"),
        "wr_failure_reason_name": record.get("WR_FAILURE_REASON_NAME"),
        "wr_disable_valid": record.get("WR_DISABLE_VALID"),
        "wr_disable_cause": record.get("WR_DISABLE_CAUSE"),
        "terminal_state": _terminal_state(record),
        "terminal_history_valid": int(_history_valid(record)),
        "terminal_candidate": int(_terminal_candidate(record)),
        "terminal_streak": terminal_streak,
        "reported_terminal_streak": record.get("F4D_TERMINAL_STREAK"),
        "upstream_full_pass": int(_upstream_full_pass(record)),
        "upstream_pass_streak": upstream_streak,
        "reported_upstream_pass_streak": record.get("F4D_UPSTREAM_PASS_STREAK"),
        "f4d_generation_changed": record.get("F4D_GENERATION_CHANGED"),
        "f4d_reset_changed": record.get("F4D_RESET_CHANGED"),
        "f4d_stop_reason": record.get("F4D_STOP_REASON"),
        "f4d_stop_role": record.get("F4D_STOP_ROLE"),
    }
    if previous is None:
        row["adjacent_same_generation"] = 0
        row["timestamp_gap_ms"] = None
    else:
        old = _decimal(previous.get("TIMESTAMP_MS"))
        new = _decimal(record.get("TIMESTAMP_MS"))
        row["adjacent_same_generation"] = int(_same_generation(previous, record) and _gap_ok(previous, record, max_gap_ms))
        row["timestamp_gap_ms"] = new - old if old is not None and new is not None else None
    for key in ("PTP_RX_COUNT", "PTP_TX_COUNT", "WR_RX_SIGNAL", "WR_TX_SIGNAL"):
        row[key.lower()] = record.get(key)
    return row


def analyze_text(text: str, source: str = "", max_gap_ms: int = 2500) -> Dict[str, Any]:
    samples = parse_samples(text)
    config = parse_config(text)
    done = parse_done(text)
    groups = _group_by_role(samples)
    condition_rows: List[Dict[str, Any]] = []
    role_results: Dict[str, Dict[str, Any]] = {}

    for role, records in groups.items():
        terminal_streaks, upstream_streaks = _streaks(records, max_gap_ms)
        previous: Optional[Dict[str, Any]] = None
        for record, terminal_streak, upstream_streak in zip(records, terminal_streaks, upstream_streaks):
            condition_rows.append(_condition_row(record, terminal_streak, upstream_streak, max_gap_ms, previous))
            previous = record
        generation_changes, reset_changes = _reset_changes(records)
        core_valid_count = sum(_core_valid(record) for record in records)
        terminal_hit = next((index for index, streak in enumerate(terminal_streaks) if streak >= 3), None)
        upstream_hit = next((index for index, streak in enumerate(upstream_streaks) if streak >= 3), None)
        role_results[role] = {
            "sample_count": len(records),
            "core_frame_valid_count": core_valid_count,
            "core_frame_valid_fraction": core_valid_count / len(records) if records else None,
            "generation_changes": generation_changes,
            "reset_changes": reset_changes,
            "terminal_streak_max": max(terminal_streaks, default=0),
            "terminal_hit_sample": records[terminal_hit].get("SAMPLE") if terminal_hit is not None else None,
            "terminal_hit_timestamp_ms": records[terminal_hit].get("TIMESTAMP_MS") if terminal_hit is not None else None,
            "terminal_history_at_capture_start": int(bool(records) and _history_valid(records[0])),
            "upstream_pass_streak_max": max(upstream_streaks, default=0),
            "upstream_hit_sample": records[upstream_hit].get("SAMPLE") if upstream_hit is not None else None,
            "upstream_hit_timestamp_ms": records[upstream_hit].get("TIMESTAMP_MS") if upstream_hit is not None else None,
            "ptp_rx_accounting": _counter_deltas(records, "PTP_RX_COUNT", max_gap_ms),
            "ptp_tx_accounting": _counter_deltas(records, "PTP_TX_COUNT", max_gap_ms),
        }

    selected_role = "SLAVE" if "SLAVE" in role_results else next(iter(role_results), None)
    selected = role_results.get(selected_role, {}) if selected_role else {}
    generation_changes = sum(result["generation_changes"] for result in role_results.values())
    reset_changes = sum(result["reset_changes"] for result in role_results.values())
    terminal_found = any(result["terminal_hit_sample"] is not None for result in role_results.values())
    upstream_found = any(result["upstream_hit_sample"] is not None for result in role_results.values())
    core_valid_total = sum(result["core_frame_valid_count"] for result in role_results.values())
    error_count = sum(1 for line in text.splitlines() if line.startswith(SAMPLE_ERROR_PREFIX))

    if generation_changes or reset_changes:
        f4d_result = "INCONCLUSIVE"
    elif selected_role and selected.get("terminal_hit_sample") is not None:
        f4d_result = "SESSION_ALREADY_TERMINATED"
    elif selected_role and selected.get("upstream_hit_sample") is not None:
        f4d_result = "GATE_RECOVERED_OBSERVED"
    elif core_valid_total >= 3:
        f4d_result = "ACQUISITION_WINDOW_OBSERVED"
    else:
        f4d_result = "INCONCLUSIVE"

    terminal_reason = "SESSION_ALREADY_TERMINATED" if terminal_found else None
    done_reason = done.get("END_REASON") if done else None
    return {
        "format": "step5-f4d-gate-audit-v1",
        "source": source,
        "config": config,
        "done": done,
        "sample_count": len(samples),
        "sample_error_count": error_count,
        "roles": role_results,
        "selected_role": selected_role,
        "core_frame_valid_total": core_valid_total,
        "generation_changes": generation_changes,
        "reset_changes": reset_changes,
        "terminal_found": terminal_found,
        "terminal_reason": terminal_reason,
        "upstream_full_pass_found": upstream_found,
        "end_reason": done_reason,
        "f4d_result": f4d_result,
        "f4d_pass": f4d_result != "INCONCLUSIVE",
        "step5_complete": False,
        "step5_pass": False,
        "merge_approved": False,
        "gate_conditions": condition_rows,
    }


def _write_csv(path: Path, rows: Sequence[Dict[str, Any]], fields: Sequence[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(fields), extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def write_outputs(result: Dict[str, Any], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    compact = dict(result)
    compact.pop("gate_conditions", None)
    (output_dir / "verdict.json").write_text(
        json.dumps(compact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    fields = [
        "role", "board", "sample", "timestamp_ms", "core_frame_valid", "frame_valid",
        "boot_generation", "cpu_reset_count", "wr_core_reset_count", "si_config_reset_count",
        "wrc_mode", "ptp_state", "ptp_state_name", "pd_state", "ext_state",
        "parent_is_wrnode", "parent_mode_on", "parent_calibrated", "wr_state_value",
        "wr_state_name", "wr_failure_low16", "wr_failure_reason", "wr_failure_reason_name",
        "wr_disable_valid", "wr_disable_cause", "terminal_state", "terminal_history_valid",
        "terminal_candidate", "terminal_streak", "reported_terminal_streak",
        "upstream_full_pass", "upstream_pass_streak", "reported_upstream_pass_streak",
        "adjacent_same_generation", "timestamp_gap_ms", "f4d_generation_changed",
        "f4d_reset_changed", "f4d_stop_reason", "f4d_stop_role", "ptp_rx_count",
        "ptp_tx_count", "wr_rx_signal", "wr_tx_signal",
    ]
    _write_csv(output_dir / "gate_conditions.csv", result["gate_conditions"], fields)
    _write_csv(output_dir / "timeline.csv", result["gate_conditions"], fields)
    summary_rows: List[Dict[str, Any]] = []
    for role, role_result in result["roles"].items():
        summary_rows.append({"role": role, **{key: value for key, value in role_result.items()
                                               if not isinstance(value, dict)}})
    _write_csv(output_dir / "role_summary.csv", summary_rows,
               ["role", "sample_count", "core_frame_valid_count", "core_frame_valid_fraction",
                "generation_changes", "reset_changes", "terminal_streak_max",
                "terminal_hit_sample", "terminal_hit_timestamp_ms",
                "terminal_history_at_capture_start", "upstream_pass_streak_max",
                "upstream_hit_sample", "upstream_hit_timestamp_ms"])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", action="append", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--max-gap-ms", type=int, default=2500)
    args = parser.parse_args()
    results = []
    for path in args.input:
        results.append(analyze_text(path.read_text(encoding="utf-8", errors="replace"), str(path), args.max_gap_ms))
    for index, result in enumerate(results):
        destination = args.output_dir if len(results) == 1 else args.output_dir / f"run-{index + 1:02d}"
        write_outputs(result, destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
