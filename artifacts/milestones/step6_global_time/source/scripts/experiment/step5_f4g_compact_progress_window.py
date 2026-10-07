#!/usr/bin/env python3
"""Replay the read-only F4G Helper/Main service-window audit.

F4G keeps Helper CORE, Main CORE, WR CORE, demand, and per-word service
counter observations separate.  The analyzer correlates them in fixed
10-second host-time bins; it never upgrades a CORE record to a FULL
measurement and never treats different L2 probe reads as one atomic sample.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
import sys

sys.path.insert(0, str(REPO_ROOT / "scripts" / "analysis"))
from step5_replay import parse_key_values  # noqa: E402


CONFIG_PREFIX = "STEP5_F4G_CONFIG"
DONE_PREFIX = "STEP5_F4G_DONE"
HELPER_PREFIX = "STEP5_F4G_HELPER_ATTEMPT"
MAIN_PREFIX = "STEP5_F4G_MAIN_CORE"
DETECTOR_PREFIX = "STEP5_F4G_MAIN_DETECTOR"
HELPER_STATE_PREFIX = "STEP5_F4G_HELPER_STATE"
POSITION_PREFIX = "STEP5_F4G_HELPER_POSITION"
L2_PREFIX = "STEP5_F4G_L2_WORD"
SERVICE_PREFIX = "STEP5_F4G_SERVICE_COUNTER"
DEMAND_PREFIX = "STEP5_F4G_SERVICE_DEMAND"
WR_PREFIXES = ("STEP5_F4G_WR_CORE", "STEP5_F4G_MASTER_CORE")
CYCLE_PREFIX = "STEP5_F4G_CYCLE"
MASTER_PREFIX = "STEP5_F4G_MASTER_SAMPLE"
ROLE_PREFIX = "STEP5_F4G_ROLE_SUMMARY"

INVALID = {"", "INVALID", "UNKNOWN", "NEVER", "NA", "N/A", "TIMEOUT",
            "NOT_MEASURED"}
HEX_RE = re.compile(r"^[0-9A-Fa-f]+$")


def _records(text: str, prefix: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for line in text.splitlines():
        if line.startswith(prefix + " "):
            row = parse_key_values(line)
            row["_line"] = line.rstrip("\r\n")
            rows.append(row)
    return rows


def parse_config(text: str) -> Optional[Dict[str, Any]]:
    rows = _records(text, CONFIG_PREFIX)
    return rows[0] if rows else None


def parse_done(text: str) -> Optional[Dict[str, Any]]:
    rows = _records(text, DONE_PREFIX)
    return rows[-1] if rows else None


def parse_helper(text: str) -> List[Dict[str, Any]]:
    return _records(text, HELPER_PREFIX)


def parse_main(text: str) -> List[Dict[str, Any]]:
    return _records(text, MAIN_PREFIX)


def parse_detector(text: str) -> List[Dict[str, Any]]:
    return _records(text, DETECTOR_PREFIX)


def parse_helper_state(text: str) -> List[Dict[str, Any]]:
    return _records(text, HELPER_STATE_PREFIX)


def parse_position(text: str) -> List[Dict[str, Any]]:
    return _records(text, POSITION_PREFIX)


def parse_l2(text: str) -> List[Dict[str, Any]]:
    return _records(text, L2_PREFIX)


def parse_service(text: str) -> List[Dict[str, Any]]:
    return _records(text, SERVICE_PREFIX)


def parse_demand(text: str) -> List[Dict[str, Any]]:
    return _records(text, DEMAND_PREFIX)


def parse_wr(text: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for line in text.splitlines():
        if any(line.startswith(prefix + " ") for prefix in WR_PREFIXES):
            row = parse_key_values(line)
            row["_line"] = line.rstrip("\r\n")
            rows.append(row)
    return rows


def parse_cycles(text: str) -> List[Dict[str, Any]]:
    return _records(text, CYCLE_PREFIX)


def parse_master_samples(text: str) -> List[Dict[str, Any]]:
    return _records(text, MASTER_PREFIX)


def parse_roles(text: str) -> List[Dict[str, Any]]:
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
    value = value.strip()
    if value.upper() in INVALID:
        return None
    try:
        if value.lower().startswith(("0x", "+0x", "-0x")):
            return int(value, 16)
        if re.fullmatch(r"[-+]?\d+", value):
            return int(value, 10)
        if HEX_RE.fullmatch(value):
            return int(value, 16)
    except ValueError:
        return None
    return None


def _flag(row: Dict[str, Any], key: str) -> bool:
    value = row.get(key)
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value == 1
    return isinstance(value, str) and value.strip().upper() in {
        "1", "YES", "TRUE", "PASS",
    }


def _text(row: Dict[str, Any], key: str) -> str:
    value = row.get(key)
    return "" if value is None else str(value)


def _host_end(row: Dict[str, Any]) -> Optional[int]:
    return _num(row.get("HOST_END_MS"))


def _host_start(row: Dict[str, Any]) -> Optional[int]:
    return _num(row.get("HOST_START_MS"))


def _attempt_shape(row: Dict[str, Any]) -> bool:
    required = {
        "BOARD", "CYCLE", "RETRY_N", "HOST_START_MS", "HOST_END_MS",
        "RAW_EPOCH_BEFORE", "RAW_HELPER_ERROR", "RAW_UPDATE_COUNT",
        "RAW_HELPER_OUTPUT", "RAW_EPOCH_AFTER", "ACCEPTED", "REASON",
    }
    return required.issubset(row) and _num(row.get("CYCLE")) is not None


def _main_shape(row: Dict[str, Any]) -> bool:
    required = {"BOARD", "CYCLE", "HOST_START_MS", "HOST_END_MS",
                "MAIN_CORE_VALID", "MAIN_SAMPLE_N", "MAIN_PI_X",
                "MAIN_PI_OUTPUT", "MAIN_PI_CLAMP_SIDE", "MAIN_STATE"}
    return required.issubset(row)


def _wr_shape(row: Dict[str, Any]) -> bool:
    required = {"BOARD", "ROLE", "HOST_START_MS", "HOST_END_MS",
                "WR_CORE_VALID", "ROLE_IDENTITY_VALID", "RESET_FIELDS_VALID",
                "TERMINAL"}
    return required.issubset(row)


def _counter_delta(previous: Optional[int], current: Optional[int], bits: int = 32) -> Tuple[Optional[int], bool]:
    if previous is None or current is None:
        return None, False
    delta = (current - previous) & ((1 << bits) - 1)
    if delta > (1 << (bits - 1)) - 1:
        return None, True
    return delta, False


def _relative_bins(rows: Sequence[Dict[str, Any]], base: int, width: int = 10000) -> Dict[int, List[Dict[str, Any]]]:
    bins: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
    for row in rows:
        end = _host_end(row)
        if end is not None and end >= base:
            bins[(end - base) // width].append(row)
    return bins


def _window_deltas(rows: Sequence[Dict[str, Any]], side: str, start: int,
                   end: int, base: int) -> Dict[str, Any]:
    usable: List[Tuple[int, int]] = []
    invalid = 0
    for row in rows:
        t = _host_end(row)
        value = _num(row.get(f"{side}_VALUE"))
        valid = _flag(row, "VALID")
        if t is None or value is None or not valid or not (start <= t - base < end):
            continue
        usable.append((t, value))
    usable.sort()
    deltas: List[int] = []
    ambiguous = 0
    previous: Optional[int] = None
    previous_t: Optional[int] = None
    for timestamp, value in usable:
        if previous is not None and previous_t is not None and timestamp > previous_t:
            delta, is_ambiguous = _counter_delta(previous, value)
            if is_ambiguous:
                ambiguous += 1
            elif delta is not None:
                deltas.append(delta)
        previous = value
        previous_t = timestamp
    return {
        "sample_count": len(usable),
        "delta_samples": len(deltas),
        "delta_sum": sum(deltas),
        "ambiguous": ambiguous,
        "window_start_ms": start,
        "window_end_ms": end,
        "coverage_start_ms": usable[0][0] - base if usable else None,
        "coverage_end_ms": usable[-1][0] - base if usable else None,
        "service_window": ("TRUSTED" if len(deltas) > 0 and not ambiguous
                            else "UNKNOWN"),
    }


def _all_host_rows(groups: Iterable[Sequence[Dict[str, Any]]]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for group in groups:
        rows.extend(group)
    return rows


def _source_gate(config: Optional[Dict[str, Any]], done: Optional[Dict[str, Any]],
                 wr_rows: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    required = {
        "READ_ONLY_OBSERVER": "1",
        "ONE_READER": "1",
        "READER_PROCESSES": "1",
        "NO_CONTROL_WRITE": "1",
        "NO_HELPER_PI_SNAPSHOT": "1",
        "NO_DEBUG_FIFO_DRAIN": "1",
        "PRODUCTION_CONTROL_UNCHANGED": "1",
        "SOURCE_CONTRACT_VERIFIED": "YES",
    }
    config_pass = bool(config) and all(
        str(config.get(key, "")).upper() == expected for key, expected in required.items()
    )
    done_pass = bool(done) and str(done.get("SINGLE_READER", "")).upper() == "PASS"
    roles = {str(row.get("ROLE")) for row in wr_rows if _flag(row, "WR_CORE_VALID")}
    identity = all(_flag(row, "ROLE_IDENTITY_VALID") for row in wr_rows
                   if _flag(row, "WR_CORE_VALID"))
    return {
        "config_pass": config_pass,
        "done_single_reader_pass": done_pass,
        "source_contract_verified": bool(config and str(config.get("SOURCE_CONTRACT_VERIFIED", "")).upper() == "YES"),
        "dynamic_owner": str(config.get("DYNAMIC_OWNER_VERIFIED", "NOT_AVAILABLE")) if config else "NOT_AVAILABLE",
        "runtime_identity_roles": sorted(roles),
        "runtime_identity_pass": identity and roles.issuperset({"MASTER", "SLAVE"}),
        "limited_source_backed_core": bool(config_pass and done_pass),
    }


def _bin_rows(helper: Sequence[Dict[str, Any]], main: Sequence[Dict[str, Any]],
              detector: Sequence[Dict[str, Any]], cycles: Sequence[Dict[str, Any]],
              wr: Sequence[Dict[str, Any]], demand: Sequence[Dict[str, Any]],
              service: Sequence[Dict[str, Any]], base: int,
              width: int = 10000) -> List[Dict[str, Any]]:
    all_rows = _all_host_rows((helper, main, detector, cycles, wr, demand, service))
    if not all_rows:
        return []
    max_end = max((_host_end(row) or base) for row in all_rows)
    count = max(1, (max_end - base) // width + 1)
    output: List[Dict[str, Any]] = []
    for index in range(count):
        start = index * width
        end = (index + 1) * width
        in_bin = lambda row: (_host_end(row) is not None and
                              start <= (_host_end(row) - base) < end)
        h_rows = [row for row in helper if in_bin(row)]
        m_rows = [row for row in main if in_bin(row)]
        d_rows = [row for row in detector if in_bin(row)]
        c_rows = [row for row in cycles if in_bin(row)]
        w_rows = [row for row in wr if in_bin(row)]
        q_rows = [row for row in demand if in_bin(row)]
        s_rows = [row for row in service if in_bin(row)]
        helper_fresh = sum(_flag(row, "ACCEPTED") and
                           (_num(row.get("UPDATE_COUNT")) is not None)
                           for row in h_rows)
        # A CORE attempt is fresh only relative to the previous accepted
        # attempt. The observer's cycle summary is the authoritative
        # de-duplicated freshness result when present.
        helper_fresh = sum(_flag(row, "HELPER_CORE_FRESH") for row in c_rows)
        main_fresh = sum(_flag(row, "MAIN_CORE_FRESH") and
                         _flag(row, "MAIN_CORE_VALID") for row in c_rows)
        if not c_rows:
            main_fresh = sum(_flag(row, "MAIN_CORE_FRESH") and
                             _flag(row, "MAIN_CORE_VALID") for row in m_rows)
        phase_qualified = sum(_flag(row, "PHASE_QUALIFIED") for row in c_rows)
        phase_locked = sum(_flag(row, "MAIN_PHASE_LOCKED") for row in c_rows)
        if not c_rows:
            phase_locked = sum(_flag(row, "MAIN_PHASE_LOCKED") for row in d_rows)
        wr_valid = sum(_flag(row, "WR_CORE_VALID") for row in w_rows)
        helper_demand = sum(_flag(row, "HELPER_PENDING") for row in q_rows
                            if _flag(row, "STATUS_VALID"))
        main_demand = sum(_flag(row, "MAIN_PENDING") for row in q_rows
                          if _flag(row, "STATUS_VALID"))
        completed_main = _window_deltas(
            [row for row in s_rows if str(row.get("COUNTER_GROUP")) == "COMPLETED"],
            "MAIN", start, end, base)
        completed_helper = _window_deltas(
            [row for row in s_rows if str(row.get("COUNTER_GROUP")) == "COMPLETED"],
            "HELPER", start, end, base)
        start_main = _window_deltas(
            [row for row in s_rows if str(row.get("COUNTER_GROUP")) == "START"],
            "MAIN", start, end, base)
        start_helper = _window_deltas(
            [row for row in s_rows if str(row.get("COUNTER_GROUP")) == "START"],
            "HELPER", start, end, base)
        output.append({
            "bin_index": index,
            "bin_start_ms": start,
            "bin_end_ms": end,
            "helper_fresh_count": helper_fresh,
            "main_fresh_count": main_fresh,
            "phase_qualified_count": phase_qualified,
            "phase_locked_count": phase_locked,
            "wr_core_valid_count": wr_valid,
            "helper_demand_count": helper_demand,
            "main_demand_count": main_demand,
            "main_completed_delta": completed_main["delta_sum"],
            "helper_completed_delta": completed_helper["delta_sum"],
            "main_start_delta": start_main["delta_sum"],
            "helper_start_delta": start_helper["delta_sum"],
            "main_completed_service_window": completed_main["service_window"],
            "helper_completed_service_window": completed_helper["service_window"],
            "main_start_service_window": start_main["service_window"],
            "helper_start_service_window": start_helper["service_window"],
            "main_completed_delta_samples": completed_main["delta_samples"],
            "helper_completed_delta_samples": completed_helper["delta_samples"],
            "service_ambiguous_count": completed_main["ambiguous"] + completed_helper["ambiguous"] + start_main["ambiguous"] + start_helper["ambiguous"],
            "helper_core_rows": len(h_rows),
            "main_core_rows": len(m_rows),
            "detector_rows": len(d_rows),
            "wr_core_rows": len(w_rows),
            "demand_rows": len(q_rows),
            "service_rows": len(s_rows),
            "qualified_bin": int(helper_fresh >= 2 and main_fresh >= 2),
        })
    return output


def _counter_support(service: Sequence[Dict[str, Any]], base: int) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    groups = sorted({str(row.get("COUNTER_GROUP")) for row in service})
    for group in groups:
        selected = [row for row in service if str(row.get("COUNTER_GROUP")) == group]
        for side in ("MAIN", "HELPER"):
            result = _window_deltas(selected, side, 0, 1 << 60, base)
            rows.append({
                "counter_group": group,
                "side": side,
                "source_semantics": "VERIFIED" if all(
                    str(row.get("SOURCE_SEMANTICS", "")).upper() == "VERIFIED"
                    for row in selected) else "UNKNOWN",
                "counter_width_bits": 32,
                "read_atomicity": "WORD_ONLY",
                "sample_count": result["sample_count"],
                "trusted_delta_samples": result["delta_samples"],
                "delta_sum": result["delta_sum"],
                "ambiguous": result["ambiguous"],
                "coverage_start_ms": result["coverage_start_ms"],
                "coverage_end_ms": result["coverage_end_ms"],
                "service_window": result["service_window"],
                "delta_policy": "SAME_FIELD_TRUSTED_READS_ONLY",
            })
    return rows


def classify(result: Dict[str, Any]) -> str:
    done = result.get("done") or {}
    stop_reason = str(done.get("STOP_REASON", "NONE")).upper()
    if "RESET_OR_GENERATION_CHANGE" in stop_reason:
        return "RESET_OR_GENERATION_CHANGE"
    if "WR_SESSION_ENDED" in stop_reason:
        return "HELPER_OR_SESSION_REGRESSION"
    if any(item in stop_reason for item in ("HELPER_REGRESSION", "FREQ_REGRESSION")):
        return "HELPER_OR_SESSION_REGRESSION"
    if "DATA_UNRESOLVED" in stop_reason:
        return "DATA_UNRESOLVED"
    if result["shape_errors"] or not result["source_gate"]["config_pass"]:
        return "DATA_UNRESOLVED"
    if result["core_full_field_contamination"]:
        return "DATA_UNRESOLVED"
    if result["wr_core_count"] and not result["source_gate"]["runtime_identity_pass"]:
        return "DATA_UNRESOLVED"
    qualified = [row for row in result["bins"] if row["qualified_bin"] and
                 row["phase_qualified_count"] > 0]
    progress = [row for row in qualified
                if row["main_completed_service_window"] == "TRUSTED" and
                row["main_completed_delta"] > 0 and
                row["helper_completed_service_window"] == "TRUSTED"]
    phase_unlocked = [row for row in progress if row["phase_locked_count"] == 0]
    if len(phase_unlocked) >= 3:
        return "MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK"
    demand_gap = [row for row in qualified
                  if row["main_demand_count"] + row["helper_demand_count"] >= 2 and
                  row["main_completed_service_window"] == "TRUSTED" and
                  row["main_completed_delta"] == 0]
    if demand_gap:
        return "MAIN_DEMAND_SERVICE_GAP_SUSPECTED"
    if qualified and not progress:
        return "SERVICE_EVIDENCE_UNRESOLVED"
    if result["counter_support"] and not any(
        row["service_window"] == "TRUSTED" for row in result["counter_support"]
    ):
        return "SERVICE_EVIDENCE_UNRESOLVED"
    if result["fresh_bin_count"] >= 3:
        return "INCONCLUSIVE"
    return "INCONCLUSIVE"


def analyze_text(text: str, source: str = "") -> Dict[str, Any]:
    config = parse_config(text)
    done = parse_done(text)
    helper = parse_helper(text)
    main = parse_main(text)
    detector = parse_detector(text)
    helper_state = parse_helper_state(text)
    position = parse_position(text)
    l2 = parse_l2(text)
    service = parse_service(text)
    demand = parse_demand(text)
    wr = parse_wr(text)
    cycles = parse_cycles(text)
    master = parse_master_samples(text)
    roles = parse_roles(text)
    shape_errors = sum(not _attempt_shape(row) for row in helper)
    shape_errors += sum(not _main_shape(row) for row in main)
    shape_errors += sum(not _wr_shape(row) for row in wr)
    all_rows = _all_host_rows((helper, main, detector, helper_state, position,
                               l2, service, demand, wr, cycles, master))
    times = [_host_end(row) for row in all_rows if _host_end(row) is not None]
    base = min(times) if times else 0
    bins = _bin_rows(helper, main, detector, cycles, wr, demand, service, base)
    counter_support = _counter_support(service, base)
    source_gate = _source_gate(config, done, wr)
    core_full_field_contamination = any(
        any(key in row for key in ("RAW_TAG_DELTA", "RAW_EXPECTED_DELTA",
                                   "RAW_FREQ_ERROR", "RAW_PRECLAMP_ERROR",
                                   "RAW_DMTD_REF_ACCEPT_COUNT",
                                   "RAW_DMTD_FB_ACCEPT_COUNT"))
        for row in helper
    )
    result: Dict[str, Any] = {
        "format": "step5-f4g-compact-progress-window-v1",
        "source": source,
        "config": config,
        "done": done,
        "source_gate": source_gate,
        "shape_errors": shape_errors,
        "core_full_field_contamination": core_full_field_contamination,
        "helper_attempt_count": len(helper),
        "helper_accepted_count": sum(_flag(row, "ACCEPTED") for row in helper),
        "main_core_count": len(main),
        "main_core_valid_count": sum(_flag(row, "MAIN_CORE_VALID") for row in main),
        "detector_count": len(detector),
        "helper_state_count": len(helper_state),
        "position_count": len(position),
        "l2_word_count": len(l2),
        "service_counter_count": len(service),
        "service_demand_count": len(demand),
        "wr_core_count": len(wr),
        "cycle_count": len(cycles),
        "master_sample_count": len(master),
        "role_summary_count": len(roles),
        "host_base_ms": base if times else None,
        "host_last_ms": max(times) if times else None,
        "host_span_ms": max(times) - min(times) if times else 0,
        "bins": bins,
        "counter_support": counter_support,
        "fresh_bin_count": sum(row["qualified_bin"] for row in bins),
        "classification": "INCONCLUSIVE",
        "diagnostic_pass": False,
        "step5_complete": False,
        "step5_pass": False,
        "merge_approved": False,
        "helper_records": helper,
        "main_records": main,
        "detector_records": detector,
        "helper_state_records": helper_state,
        "position_records": position,
        "l2_records": l2,
        "service_records": service,
        "demand_records": demand,
        "wr_records": wr,
        "cycle_records": cycles,
        "master_records": master,
        "role_records": roles,
    }
    result["classification"] = classify(result)
    result["diagnostic_pass"] = result["classification"] in {
        "MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK",
        "MAIN_DEMAND_SERVICE_GAP_SUSPECTED",
        "HELPER_OR_SESSION_REGRESSION",
    }
    return result


def _write_csv(path: Path, rows: Iterable[Dict[str, Any]]) -> None:
    materialized = list(rows)
    fields: List[str] = []
    for row in materialized:
        for key in row:
            if key not in fields and not key.startswith("_"):
                fields.append(key)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(materialized)


def write_outputs(result: Dict[str, Any], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    _write_csv(output_dir / "bins.csv", result["bins"])
    _write_csv(output_dir / "counter_support.csv", result["counter_support"])
    _write_csv(output_dir / "helper_attempts.csv", result["helper_records"])
    _write_csv(output_dir / "main_core.csv", result["main_records"])
    _write_csv(output_dir / "detector.csv", result["detector_records"])
    _write_csv(output_dir / "l2_words.csv", result["l2_records"])
    _write_csv(output_dir / "service_counters.csv", result["service_records"])
    _write_csv(output_dir / "service_demand.csv", result["demand_records"])
    _write_csv(output_dir / "wr_core.csv", result["wr_records"])
    _write_csv(output_dir / "cycles.csv", result["cycle_records"])
    compact = {key: value for key, value in result.items() if not key.endswith("_records")}
    (output_dir / "verdict.json").write_text(
        json.dumps(compact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    text = args.log.read_text(encoding="utf-8", errors="replace")
    result = analyze_text(text, str(args.log))
    if args.output_dir:
        write_outputs(result, args.output_dir)
    print(json.dumps({
        "classification": result["classification"],
        "diagnostic_pass": result["diagnostic_pass"],
        "helper_accepted": result["helper_accepted_count"],
        "main_core_valid": result["main_core_valid_count"],
        "fresh_bins": result["fresh_bin_count"],
        "step5_pass": False,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
