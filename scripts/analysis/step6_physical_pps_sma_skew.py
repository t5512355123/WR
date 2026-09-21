"""Analyze a 20-edge Master/Slave PPS oscilloscope CSV export."""

from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path
from statistics import mean, pstdev
from typing import Any


def _number(row: dict[str, str], *names: str) -> float | None:
    normalized = {key.strip().lower(): value.strip() for key, value in row.items()}
    for name in names:
        value = normalized.get(name.lower())
        if value is not None and value != "":
            try:
                return float(value)
            except ValueError:
                return None
    return None


def analyze_csv(path: Path, expected_edges: int = 20, limit_ns: float = 8.0) -> dict[str, Any]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    deltas: list[float] = []
    indices: list[int] = []
    invalid_rows: list[int] = []
    for position, row in enumerate(rows, start=1):
        index = _number(row, "edge_index", "index", "edge")
        delta = _number(row, "delta_ns", "delta", "slave_minus_master_ns")
        if delta is None:
            master = _number(row, "master_crossing_ns", "master_ns", "master_time_ns")
            slave = _number(row, "slave_crossing_ns", "slave_ns", "slave_time_ns")
            if master is not None and slave is not None:
                delta = slave - master
        if index is None or delta is None or not math.isfinite(delta):
            invalid_rows.append(position)
            continue
        indices.append(int(index))
        deltas.append(delta)

    consecutive = (
        len(indices) == expected_edges
        and len(set(indices)) == expected_edges
        and sorted(indices) == list(range(min(indices), min(indices) + expected_edges))
        if indices
        else False
    )
    complete = len(deltas) == expected_edges and not invalid_rows and consecutive
    max_abs = max((abs(value) for value in deltas), default=float("nan"))
    formal_pass = complete and max_abs < limit_ns
    return {
        "format": "step6-physical-pps-sma-skew-v1",
        "verdict": "PASS" if formal_pass else "FAIL" if complete else "INCONCLUSIVE",
        "classification": (
            "PASS_PHYSICAL_PPS_EDGE_WITHIN_ONE_GLOBAL_TIME_TICK"
            if formal_pass
            else "FAIL_PHYSICAL_PPS_EDGE_EXCEEDS_ONE_GLOBAL_TIME_TICK"
            if complete
            else "INCONCLUSIVE_PHYSICAL_MEASUREMENT_SETUP"
        ),
        "edge_count": len(deltas),
        "expected_edges": expected_edges,
        "indices": indices,
        "consecutive_indices": consecutive,
        "invalid_rows": invalid_rows,
        "min_delta_ns": min(deltas) if deltas else None,
        "max_delta_ns": max(deltas) if deltas else None,
        "mean_delta_ns": mean(deltas) if deltas else None,
        "stddev_delta_ns": pstdev(deltas) if len(deltas) > 1 else 0.0 if deltas else None,
        "pkpk_delta_ns": max(deltas) - min(deltas) if deltas else None,
        "max_abs_delta_ns": max_abs if deltas else None,
        "limit_ns": limit_ns,
        "physical_scheduled_trigger_edge": "NOT_EVALUATED",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", type=Path)
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--expected-edges", type=int, default=20)
    parser.add_argument("--limit-ns", type=float, default=8.0)
    args = parser.parse_args()
    result = analyze_csv(args.csv, args.expected_edges, args.limit_ns)
    output = json.dumps(result, indent=2, sort_keys=True)
    print(output)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(output + "\n", encoding="utf-8")
    return 0 if result["verdict"] == "PASS" else 1 if result["verdict"] == "FAIL" else 3


if __name__ == "__main__":
    raise SystemExit(main())
