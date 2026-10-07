#!/usr/bin/env python3
"""Compare the approved F4K Slave-Main-Kp ABA experiment.

The three inputs are fresh F4J captures made with the same observer:
  A1: Slave Main Kp=300
   B: Slave Main Kp=600
  A2: Slave Main Kp=300

This is a directionality diagnostic.  It never upgrades a 120-second arm to
Step5 PASS, and it never treats a sparse host sample as a producer counter.
Primary metrics are calculated from the producer's cumulative counters over a
common-length window.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4j_main_producer_handoff_audit as f4j  # noqa: E402


UINT32_MASK = (1 << 32) - 1
HALF32 = 1 << 31
ARM_NAMES = ("A1", "B", "A2")
EXPECTED_KP = {"A1": 300, "B": 600, "A2": 300}
MIN_UNIQUE = 20
MIN_SPAN_MS = 30_000
MIN_BACKGROUND_BINS = 3
TARGET_DURATION_MS = 120_000


def _value(mapping: Optional[Dict[str, Any]], key: str, default: Any = None) -> Any:
    if not mapping:
        return default
    wanted = key.upper()
    for name, value in mapping.items():
        if str(name).upper() == wanted:
            return value
    return default


def _int(value: Any) -> Optional[int]:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    text = str(value).strip()
    if text.upper() in f4j.INVALID:
        return None
    try:
        return int(text, 0)
    except ValueError:
        try:
            return int(text, 10)
        except ValueError:
            return None


def _flag(value: Any) -> bool:
    return str(value).strip().upper() in {"1", "YES", "TRUE", "PASS"}


def _row_flag(row: Dict[str, Any], key: str) -> bool:
    return _flag(_value(row, key))


def _delta(previous: Optional[int], current: Optional[int]) -> Optional[int]:
    if previous is None or current is None:
        return None
    value = (current - previous) & UINT32_MASK
    return None if value > HALF32 else value


def _rows_in_window(rows: Sequence[Dict[str, Any]], span_ms: int) -> List[Dict[str, Any]]:
    ordered = sorted(
        (row for row in rows if _int(row.get("HOST_END_MS")) is not None),
        key=lambda row: _int(row.get("HOST_END_MS")) or 0,
    )
    if not ordered:
        return []
    start = _int(ordered[0].get("HOST_END_MS"))
    assert start is not None
    end = start + span_ms
    return [
        row for row in ordered
        if start <= (_int(row.get("HOST_END_MS")) or start) <= end
    ]


def _counter_window(rows: Sequence[Dict[str, Any]], field: str) -> Optional[int]:
    if len(rows) < 2:
        return None
    return _delta(_int(rows[0].get(field)), _int(rows[-1].get(field)))


def _producer_metrics(rows: Sequence[Dict[str, Any]], span_ms: int) -> Dict[str, Any]:
    window = _rows_in_window(rows, span_ms)
    if len(window) < 2:
        return {"valid": False, "reason": "TOO_FEW_PRODUCER_ROWS", "rows": len(window)}
    first_time = _int(window[0].get("HOST_END_MS"))
    last_time = _int(window[-1].get("HOST_END_MS"))
    fields = {
        "total": "TOTAL_UPDATES",
        "frequency": "FREQ_UPDATES",
        "phase": "PHASE_UPDATES",
        "detector": "PHASE_DETECTOR",
        "in_band": "PHASE_IN_BAND",
        "out_band": "PHASE_OUT_BAND",
        "freq_to_phase": "FREQ_TO_PHASE",
        "phase_to_freq": "PHASE_TO_FREQ",
    }
    deltas = {name: _counter_window(window, field) for name, field in fields.items()}
    invalid = [name for name, value in deltas.items() if value is None]
    if invalid:
        return {"valid": False, "reason": "COUNTER_WINDOW_INVALID", "invalid": invalid,
                "rows": len(window)}
    detector = deltas["detector"]
    total = deltas["total"]
    phase = deltas["phase"]
    in_band = deltas["in_band"]
    out_band = deltas["out_band"]
    if detector <= 0 or total <= 0:
        return {"valid": False, "reason": "COUNTER_WINDOW_EMPTY", "rows": len(window),
                "deltas": deltas}
    if in_band + out_band != detector:
        return {"valid": False, "reason": "PHASE_BAND_COUNTER_MISMATCH",
                "rows": len(window), "deltas": deltas}
    freq_errors = [
        _int(row.get("FREQ_ERROR")) for row in window
        if _int(row.get("FREQ_ERROR")) is not None
    ]
    phase_counts = [
        _int(row.get("PHASE_COUNT_AFTER")) for row in window
        if _int(row.get("PHASE_COUNT_AFTER")) is not None
    ]
    phase_lock_seen = any(
        ((_int(row.get("FLAGS")) or 0) & (1 << 4)) != 0
        or (_int(row.get("PHASE_COUNT_AFTER")) or 0) >= 1000
        for row in window
    )
    seconds = max((last_time or first_time or 0) - (first_time or 0), 1) / 1000.0
    return {
        "valid": True,
        "rows": len(window),
        "first_ms": first_time,
        "last_ms": last_time,
        "span_ms": (last_time - first_time) if first_time is not None and last_time is not None else 0,
        "deltas": deltas,
        "phase_in_band_ratio": in_band / detector,
        "phase_active_ratio": phase / total,
        "handoff_delta": deltas["freq_to_phase"] + deltas["phase_to_freq"],
        "handoff_per_second": (deltas["freq_to_phase"] + deltas["phase_to_freq"]) / seconds,
        "freq_error_min": min(freq_errors) if freq_errors else None,
        "freq_error_max": max(freq_errors) if freq_errors else None,
        "freq_error_mean": (sum(freq_errors) / len(freq_errors)) if freq_errors else None,
        "phase_count_max_sampled": max(phase_counts) if phase_counts else None,
        "phase_lock_seen": phase_lock_seen,
    }


def _safety(result: Dict[str, Any]) -> Dict[str, Any]:
    problems: List[str] = []
    for reason in result.get("observed_stop_reasons", []):
        if str(reason).upper() not in {"", "NONE"}:
            problems.append("STOP_" + str(reason))
    if result.get("frame_error_count", 0):
        problems.append("FRAME_ERRORS")
    if result.get("publication_context_mismatch_count", 0):
        problems.append("PUBLICATION_CONTEXT_MISMATCH")

    cycles = [row for row in result.get("cycle_records", [])
              if str(_value(row, "ROLE", "")).upper() == "SLAVE"]
    if not cycles:
        problems.append("SLAVE_CYCLES_MISSING")
    for row in cycles:
        for key in ("HELPER_CORE_VALID", "HELPER_STATE_VALID", "HELPER_LOCKED",
                    "MAIN_PRODUCER_VALID", "WR_CORE_VALID", "PHY_LINK_USABLE"):
            if not _row_flag(row, key):
                problems.append(key + "_REGRESSION")
        if _row_flag(row, "TERMINAL"):
            problems.append("WR_TERMINAL")
        reason = str(_value(row, "STOP_REASON", "NONE")).upper()
        if reason not in {"", "NONE"}:
            problems.append("CYCLE_" + reason)

    wr_rows = result.get("wr_records", [])
    if not wr_rows:
        problems.append("WR_ROWS_MISSING")
    for row in wr_rows:
        for key in ("WR_CORE_VALID", "PHY_LINK_USABLE", "ROLE_IDENTITY_VALID",
                    "RESET_FIELDS_VALID"):
            if not _row_flag(row, key):
                problems.append(key + "_FAIL")
        if _row_flag(row, "TERMINAL"):
            problems.append("WR_TERMINAL")
    for key in ("BOOT_GENERATION", "CPU_RESET", "WR_CORE_RESET", "SI_CONFIG_DROP"):
        values = [_int(_value(row, key)) for row in wr_rows]
        values = [value for value in values if value is not None]
        if values and (min(values) != max(values)):
            problems.append(key + "_CHANGED")

    return {"safe": not problems, "problems": sorted(set(problems)),
            "cycle_count": len(cycles), "wr_count": len(wr_rows)}


def _arm(path: Path, expected_arm: str) -> Dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace")
    result = f4j.analyze_text(text, str(path))
    config = result.get("config") or {}
    configured_arm = str(_value(config, "F4K_ARM", "UNSPECIFIED"))
    configured_kp = _int(_value(config, "CONFIGURED_MAIN_KP"))
    scope = str(_value(config, "FUNCTIONAL_EXPERIMENT_SCOPE", ""))
    expected_kp = EXPECTED_KP[expected_arm]
    checks: List[str] = []
    if configured_arm != expected_arm:
        checks.append("ARM_METADATA_MISMATCH")
    if configured_kp != expected_kp:
        checks.append("KP_METADATA_MISMATCH")
    if scope != "F4K_SLAVE_MAIN_KP_ONLY":
        checks.append("EXPERIMENT_SCOPE_MISMATCH")
    if str(_value(config, "READ_ONLY_OBSERVER", "0")) != "1":
        checks.append("OBSERVER_NOT_READ_ONLY")
    if str(_value(config, "ONE_READER", "0")) != "1":
        checks.append("READER_COUNT_INVALID")
    if str(_value(config, "NO_CONTROL_WRITE", "0")) != "1":
        checks.append("RUNTIME_CONTROL_WRITE_ENABLED")
    if str(_value(config, "NO_HELPER_PI_SNAPSHOT", "0")) != "1":
        checks.append("HELPER_PI_SNAPSHOT_ENABLED")
    if str(_value(config, "NO_DEBUG_FIFO_DRAIN", "0")) != "1":
        checks.append("DEBUG_FIFO_DRAIN_ENABLED")

    done = result.get("done") or {}
    session_ms = _int(_value(done, "SESSION_ELAPSED_MS"))
    stop_reason = str(_value(done, "STOP_REASON", "NONE")).upper()
    if session_ms is None or session_ms < TARGET_DURATION_MS:
        checks.append("FORMAL_WINDOW_SHORT")
    if stop_reason != "NONE":
        checks.append("FORMAL_STOP_" + stop_reason)
    if result.get("unique_count", 0) < MIN_UNIQUE:
        checks.append("UNIQUE_COVERAGE_SHORT")
    if result.get("unique_span_ms", 0) < MIN_SPAN_MS:
        checks.append("PRODUCER_SPAN_SHORT")
    if result.get("valid_background_bin_count", 0) < MIN_BACKGROUND_BINS:
        checks.append("BACKGROUND_COVERAGE_SHORT")
    safety = _safety(result)
    if not safety["safe"]:
        checks.extend(safety["problems"])
    return {
        "path": str(path),
        "expected_arm": expected_arm,
        "expected_main_kp": expected_kp,
        "configured_arm": configured_arm,
        "configured_main_kp": configured_kp,
        "config_scope": scope,
        "session_elapsed_ms": session_ms,
        "stop_reason": stop_reason,
        "ready": not checks,
        "checks": sorted(set(checks)),
        "classification": result.get("classification"),
        "f4j_diagnostic_pass": result.get("diagnostic_pass", False),
        "unique_count": result.get("unique_count", 0),
        "unique_span_ms": result.get("unique_span_ms", 0),
        "valid_background_bin_count": result.get("valid_background_bin_count", 0),
        "safety": safety,
        "result": result,
    }


def _public_arm(arm: Dict[str, Any], common_span_ms: Optional[int]) -> Dict[str, Any]:
    result = arm["result"]
    span = common_span_ms if common_span_ms is not None else arm["unique_span_ms"]
    metrics = _producer_metrics(result.get("unique_records", []), span)
    wr_rows = result.get("wr_records", [])
    if metrics.get("valid"):
        first = metrics.get("first_ms")
        last = metrics.get("last_ms")
        in_window = [
            row for row in wr_rows
            if _int(_value(row, "HOST_END_MS")) is not None and
            first is not None and last is not None and
            first <= (_int(_value(row, "HOST_END_MS")) or first) <= last
        ]
        metrics["pstat_locked_seen"] = any(_row_flag(row, "PSTAT_LOCKED") for row in in_window)
        metrics["wr_rows_in_window"] = len(in_window)
    public = {key: value for key, value in arm.items() if key != "result"}
    public["metrics"] = metrics
    return public


def compare(a1_path: Path, b_path: Path, a2_path: Path) -> Dict[str, Any]:
    arms = {"A1": _arm(a1_path, "A1"), "B": _arm(b_path, "B"), "A2": _arm(a2_path, "A2")}
    ready_arms = [arm for arm in arms.values() if arm["ready"]]
    spans = [arm["unique_span_ms"] for arm in ready_arms]
    common_span = min(spans) if len(ready_arms) == 3 else None
    public = {name: _public_arm(arm, common_span) for name, arm in arms.items()}
    classification = "ARM_DATA_INVALID"
    baseline_reproducible = False
    direction_supported = False
    comparison_checks: List[str] = []
    if len(ready_arms) == 3 and all(public[name]["metrics"].get("valid") for name in ARM_NAMES):
        a1 = public["A1"]["metrics"]
        b = public["B"]["metrics"]
        a2 = public["A2"]["metrics"]
        baseline_reproducible = abs(
            a1["phase_in_band_ratio"] - a2["phase_in_band_ratio"]
        ) <= 0.10
        if not baseline_reproducible:
            comparison_checks.append("BASELINE_IN_BAND_DELTA_OVER_10PP")
        if baseline_reproducible:
            active_floor = min(a1["phase_active_ratio"], a2["phase_active_ratio"]) - 0.05
            handoff_floor = min(a1["handoff_per_second"], a2["handoff_per_second"])
            direction_supported = (
                b["phase_in_band_ratio"] >= max(
                    a1["phase_in_band_ratio"], a2["phase_in_band_ratio"]
                ) + 0.10 and
                b["phase_active_ratio"] >= active_floor and
                b["handoff_per_second"] >= handoff_floor and
                public["B"]["safety"]["safe"]
            )
            if direction_supported:
                comparison_checks.append("B_IN_BAND_DIRECTION_PASS")
            else:
                comparison_checks.append("B_IN_BAND_DIRECTION_NOT_SUPPORTED")
            if b.get("phase_lock_seen") or b.get("pstat_locked_seen"):
                classification = "LOCK_OBSERVED_NOT_CLOSED"
            elif direction_supported:
                classification = "KP_INCREASE_DIRECTION_SUPPORTED"
            else:
                classification = "KP_DOUBLING_NOT_SUPPORTED"
        else:
            classification = "BASELINE_NOT_REPRODUCIBLE"
    elif len(ready_arms) < 3:
        comparison_checks.append("ONE_OR_MORE_ARMS_NOT_READY")
    else:
        comparison_checks.append("PRODUCER_COUNTER_WINDOW_INVALID")
        classification = "COUNTER_WINDOW_INVALID"

    return {
        "format": "step5-f4k-slave-main-kp-aba-v1",
        "experiment": "EXP-S5-F4K-SLAVE-MAIN-KP-ONLY-300-600-ABA-20260916",
        "arms": public,
        "common_window_ms": common_span,
        "baseline_reproducible": baseline_reproducible,
        "direction_supported": direction_supported,
        "comparison_checks": sorted(set(comparison_checks)),
        "classification": classification,
        "diagnostic_pass": classification not in {"ARM_DATA_INVALID", "COUNTER_WINDOW_INVALID"},
        "step5_complete": False,
        "step5_pass": False,
        "merge_approved": False,
    }


def _write_csv(path: Path, result: Dict[str, Any]) -> None:
    fields = [
        "arm", "expected_main_kp", "configured_main_kp", "ready", "checks",
        "unique_count", "unique_span_ms", "common_window_ms", "producer_rows",
        "phase_detector_delta", "phase_in_band_delta", "phase_out_band_delta",
        "phase_in_band_ratio", "phase_active_ratio", "handoff_delta",
        "handoff_per_second", "phase_count_max_sampled", "phase_lock_seen",
        "pstat_locked_seen", "safety_safe", "safety_problems",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for name in ARM_NAMES:
            arm = result["arms"][name]
            metrics = arm.get("metrics", {})
            deltas = metrics.get("deltas", {})
            writer.writerow({
                "arm": name,
                "expected_main_kp": arm.get("expected_main_kp"),
                "configured_main_kp": arm.get("configured_main_kp"),
                "ready": int(bool(arm.get("ready"))),
                "checks": ";".join(arm.get("checks", [])),
                "unique_count": arm.get("unique_count"),
                "unique_span_ms": arm.get("unique_span_ms"),
                "common_window_ms": result.get("common_window_ms"),
                "producer_rows": metrics.get("rows"),
                "phase_detector_delta": deltas.get("detector"),
                "phase_in_band_delta": deltas.get("in_band"),
                "phase_out_band_delta": deltas.get("out_band"),
                "phase_in_band_ratio": metrics.get("phase_in_band_ratio"),
                "phase_active_ratio": metrics.get("phase_active_ratio"),
                "handoff_delta": metrics.get("handoff_delta"),
                "handoff_per_second": metrics.get("handoff_per_second"),
                "phase_count_max_sampled": metrics.get("phase_count_max_sampled"),
                "phase_lock_seen": int(bool(metrics.get("phase_lock_seen"))),
                "pstat_locked_seen": int(bool(metrics.get("pstat_locked_seen"))),
                "safety_safe": int(bool(arm.get("safety", {}).get("safe"))),
                "safety_problems": ";".join(arm.get("safety", {}).get("problems", [])),
            })


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--a1", required=True, type=Path)
    parser.add_argument("--b", required=True, type=Path)
    parser.add_argument("--a2", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args(argv)
    result = compare(args.a1, args.b, args.a2)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    compact = {key: value for key, value in result.items() if key != "arms"}
    compact["arms"] = result["arms"]
    (args.output_dir / "comparison.json").write_text(
        json.dumps(compact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    _write_csv(args.output_dir / "comparison.csv", result)
    print(json.dumps({
        "classification": result["classification"],
        "diagnostic_pass": result["diagnostic_pass"],
        "baseline_reproducible": result["baseline_reproducible"],
        "direction_supported": result["direction_supported"],
        "common_window_ms": result["common_window_ms"],
        "step5_pass": False,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
