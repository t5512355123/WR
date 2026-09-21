#!/usr/bin/env python3
"""Analyze the read-only Master-first Step6 S_LOCK reacquisition trace."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "analysis"))
from step5_replay import parse_key_values  # noqa: E402


SAMPLE_PREFIX = "SLOCK_REACQ_SAMPLE"
INVALID = {"INVALID", "UNKNOWN", "NEVER", "NA", "N/A"}


def parse_samples(text: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for line in text.splitlines():
        if line.startswith(SAMPLE_PREFIX + " "):
            row = parse_key_values(line)
            row["_line"] = line.rstrip("\r\n")
            rows.append(row)
    return rows


def _number(value: Any) -> Optional[int]:
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if not isinstance(value, str):
        return None
    text = value.strip()
    if text.upper() in INVALID:
        return None
    match = re.match(r"^[-+]?\d+", text)
    if match:
        try:
            return int(match.group(0), 10)
        except ValueError:
            return None
    if re.fullmatch(r"[0-9A-Fa-f]+", text):
        try:
            return int(text, 16)
        except ValueError:
            return None
    return None


def _hex_number(value: Any) -> Optional[int]:
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if not isinstance(value, str) or value.upper() in INVALID:
        return None
    if not re.fullmatch(r"[0-9A-Fa-f]+", value.strip()):
        return None
    try:
        return int(value.strip(), 16)
    except ValueError:
        return None


def _embedded(value: Any) -> Optional[int]:
    return _number(value)


def _same_reset(previous: Dict[str, Any], current: Dict[str, Any]) -> bool:
    keys = ("BOOT_GENERATION", "CPU_RESET_COUNT", "WR_CORE_RESET_COUNT", "SI_CONFIG_DROP_COUNT")
    return all(previous.get(key) == current.get(key) for key in keys)


def _row(record: Dict[str, Any], previous: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    polls = _hex_number(record.get("LOCK_POLLS"))
    unlocked = _hex_number(record.get("LOCK_UNLOCKED"))
    calib = _hex_number(record.get("LOCK_CALIB_FAIL"))
    success = None
    if polls is not None and unlocked is not None and calib is not None:
        success = polls - unlocked - calib
    timestamp = _number(record.get("TIMESTAMP_MS"))
    previous_timestamp = _number(previous.get("TIMESTAMP_MS")) if previous else None
    return {
        "role": record.get("ROLE"),
        "board": record.get("BOARD"),
        "sample": _number(record.get("SAMPLE")),
        "timestamp_ms": timestamp,
        "read_valid": record.get("READ_VALID"),
        "ptp_state": _embedded(record.get("PTP_STATE")),
        "pd_state": _embedded(record.get("PD_STATE")),
        "ext_state": _embedded(record.get("EXT_STATE")),
        "wr_state_value": _number(record.get("WR_STATE_VALUE")),
        "wr_tx_id": _number(record.get("WR_TX_ID")),
        "wr_disable_valid": _number(record.get("WR_DISABLE_VALID")),
        "wr_disable_cause": _number(record.get("WR_DISABLE_CAUSE")),
        "wr_failure_reason": _number(record.get("WR_FAILURE_REASON")),
        "lock_polls": polls,
        "lock_unlocked": unlocked,
        "lock_calib_fail": calib,
        "lock_enable": _hex_number(record.get("LOCK_ENABLE")),
        "lock_success_count": success,
        "spll_seq_state": _number(record.get("SPLL_SEQ_STATE")),
        "pstat_locked": _number(record.get("PSTAT_LOCKED")),
        "helper_locked": _number(record.get("HELPER_LOCKED")),
        "main_enabled": _number(record.get("MAIN_ENABLED")),
        "main_locked": _number(record.get("MAIN_LOCKED")),
        "main_freq_locked": _number(record.get("MAIN_FREQ_LOCKED")),
        "main_phase_locked": _number(record.get("MAIN_PHASE_LOCKED")),
        "boot_generation": _hex_number(record.get("BOOT_GENERATION")),
        "cpu_reset_count": _hex_number(record.get("CPU_RESET_COUNT")),
        "wr_core_reset_count": _hex_number(record.get("WR_CORE_RESET_COUNT")),
        "si_config_drop_count": _hex_number(record.get("SI_CONFIG_DROP_COUNT")),
        "slock_stage": _hex_number(record.get("SLOCK_STAGE")),
        "slock_remaining_ms": _hex_number(record.get("SLOCK_REMAINING_MS")),
        "first_slock_ms": _number(record.get("FIRST_SLOCK_MS")),
        "first_success_ms": _number(record.get("FIRST_SUCCESS_MS")),
        "first_exit_ms": _number(record.get("FIRST_EXIT_MS")),
        "first_failure_ms": _number(record.get("FIRST_FAILURE_MS")),
        "pass_ready": _number(record.get("PASS_READY")),
        "failure_seen": _number(record.get("FAILURE_SEEN")),
        "failure_class": record.get("FAILURE_CLASS"),
        "post_event_samples": _number(record.get("POST_EVENT_SAMPLES")),
        "stop_candidate": record.get("STOP_CANDIDATE"),
        "same_reset_as_previous": int(previous is not None and _same_reset(previous, record)),
        "timestamp_gap_ms": timestamp - previous_timestamp if timestamp is not None and previous_timestamp is not None else None,
    }


def analyze_text(text: str, source: str = "", mode: str = "reacquisition") -> Dict[str, Any]:
    records = parse_samples(text)
    rows: List[Dict[str, Any]] = []
    previous: Optional[Dict[str, Any]] = None
    for record in records:
        rows.append(_row(record, previous))
        previous = record

    errors = sum(1 for line in text.splitlines() if line.startswith("SLOCK_REACQ_ERROR"))
    valid_rows = [row for row in rows if row["read_valid"] == 1]
    reset_changes = 0
    for old, new in zip(rows, rows[1:]):
        # The marker belongs to the newer row; the first row has no previous
        # sample and must not be counted as a reset transition.
        if new["same_reset_as_previous"] == 0:
            reset_changes += 1

    if mode == "preflight":
        gate_ok = bool(rows) and len(rows) >= 10 and all(
            row["read_valid"] == 1
            and row["ptp_state"] == 6
            and row["wr_disable_valid"] == 0
            and row["same_reset_as_previous"] in (0, 1)
            for row in rows
        )
        stable = reset_changes == 0 and errors == 0 and len(valid_rows) == len(rows)
        result = "PASS_MASTER_PRECONDITION" if gate_ok and stable else "INCONCLUSIVE_MASTER_PRECONDITION"
        return {
            "format": "step6-slock-master-first-preflight-v1",
            "source": source,
            "mode": mode,
            "sample_count": len(rows),
            "valid_samples": len(valid_rows),
            "transport_errors": errors,
            "reset_changes": reset_changes,
            "master_ptp_states": sorted({row["ptp_state"] for row in rows}),
            "master_precondition": result,
            "pass": result == "PASS_MASTER_PRECONDITION",
            "step6a": "NOT_PASS",
            "step6b_trigger_run": False,
            "rows": rows,
        }

    first_slock = next((row for row in rows if row["wr_state_value"] == 2), None)
    first_success = next((row for row in rows if (row["lock_success_count"] or 0) > 0), None)
    first_exit = next((row for row in rows if row["pass_ready"] == 1), None)
    first_failure = next((row for row in rows if row["failure_seen"] == 1), None)
    max_success = max((row["lock_success_count"] or 0 for row in rows), default=0)
    max_calib_fail = max((row["lock_calib_fail"] or 0 for row in rows), default=0)
    max_polls = max((row["lock_polls"] or 0 for row in rows), default=0)
    max_unlocked = max((row["lock_unlocked"] or 0 for row in rows), default=0)
    stop_reason = None
    classification = "INCONCLUSIVE_MAX_CAPTURE"
    if errors or reset_changes or any(row["read_valid"] != 1 for row in rows):
        classification = "INCONCLUSIVE"
        stop_reason = "TRANSPORT_OR_RESET"
    elif first_exit is not None and (first_failure is None or first_exit["timestamp_ms"] < first_failure["timestamp_ms"]):
        post = max((row["post_event_samples"] or 0 for row in rows if row["timestamp_ms"] >= first_exit["timestamp_ms"]), default=0)
        if post >= 20:
            classification = "PASS_SLOCK_SUCCESS"
            stop_reason = "PASS_SLOCK_SUCCESS"
        else:
            classification = "INCONCLUSIVE_POST_SUCCESS_WINDOW"
    elif first_failure is not None:
        reason = first_failure["wr_failure_reason"]
        if reason == 3 and max_success == 0 and max_calib_fail == 0:
            classification = "FAIL_SPLL_NOT_LOCKED_BEFORE_SLOCK_DEADLINE"
        elif reason == 3 and max_calib_fail > 0:
            classification = "FAIL_T24P_CALIBRATION_BEFORE_SLOCK_DEADLINE"
        elif reason in range(1, 8):
            classification = f"FAIL_DOWNSTREAM_WR_REASON_{reason}"
        else:
            classification = "INCONCLUSIVE_UNKNOWN_FAILURE"
        stop_reason = classification
    elif first_slock is None:
        classification = "INCONCLUSIVE_NO_SLOCK_ENTRY"
        stop_reason = classification

    return {
        "format": "step6-slock-master-first-reacquisition-v1",
        "source": source,
        "mode": mode,
        "sample_count": len(rows),
        "valid_samples": len(valid_rows),
        "transport_errors": errors,
        "reset_changes": reset_changes,
        "first_slock_ms": first_slock["timestamp_ms"] if first_slock else None,
        "first_success_ms": first_success["timestamp_ms"] if first_success else None,
        "first_exit_ms": first_exit["timestamp_ms"] if first_exit else None,
        "first_failure_ms": first_failure["timestamp_ms"] if first_failure else None,
        "max_lock_polls": max_polls,
        "max_lock_unlocked": max_unlocked,
        "max_lock_calib_fail": max_calib_fail,
        "max_lock_success_count": max_success,
        "failure_reason": first_failure["wr_failure_reason"] if first_failure else None,
        "failure_class": first_failure["failure_class"] if first_failure else None,
        "classification": classification,
        "stop_reason": stop_reason,
        "slock_master_first_reacquisition": classification == "PASS_SLOCK_SUCCESS",
        "slock_success_before_deadline": classification == "PASS_SLOCK_SUCCESS",
        "startup_order_sensitivity": classification == "PASS_SLOCK_SUCCESS",
        "step6a": "NOT_PASS",
        "step6b_trigger_run": False,
        "rows": rows,
    }


def write_outputs(result: Dict[str, Any], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    compact = {key: value for key, value in result.items() if key != "rows"}
    (output_dir / "summary.json").write_text(json.dumps(compact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    rows = result.get("rows", [])
    if rows:
        fields = list(rows[0].keys())
        with (output_dir / "samples.csv").open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--mode", choices=("preflight", "reacquisition"), default="reacquisition")
    args = parser.parse_args()
    result = analyze_text(args.input.read_text(encoding="utf-8", errors="replace"), str(args.input), args.mode)
    write_outputs(result, args.output_dir)
    print(json.dumps({key: value for key, value in result.items() if key != "rows"}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
