#!/usr/bin/env python3
"""Analyze the passive Master TX K28.5 attribution capture."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SAMPLE_RE = re.compile(
    r"^(?P<kind>COMMA_(?:LOCAL|FORMAL|SLAVE)_SAMPLE)\s+(?P<body>.*)$"
)
FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
BOARD_RE = re.compile(r"\bBOARD=(?P<board>DE5\s+\[[^\]]+\])\s+(?:SAMPLE|ELAPSED_MS)=")
INVALID = {"", "INVALID", "TIMEOUT", "NA", "N/A", "UNKNOWN", "DECREASED"}


def parse_samples(text: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = SAMPLE_RE.match(line.strip())
        if not match:
            continue
        row: dict[str, Any] = {"KIND": match.group("kind")}
        for key, value in FIELD_RE.findall(match.group("body")):
            try:
                row[key.upper()] = int(value, 0)
            except ValueError:
                try:
                    row[key.upper()] = int(value, 10)
                except ValueError:
                    row[key.upper()] = value
        board = BOARD_RE.search(line)
        if board:
            row["BOARD"] = board.group("board")
        rows.append(row)
    return rows


def integer(row: dict[str, Any], key: str, default: int | None = None) -> int | None:
    value = row.get(key)
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if not isinstance(value, str) or value.upper() in INVALID:
        return default
    try:
        return int(value, 0)
    except ValueError:
        try:
            return int(value, 10)
        except ValueError:
            return default


def reset_signature(row: dict[str, Any]) -> tuple[Any, ...]:
    return tuple(
        row.get(key)
        for key in (
            "BOOT_GENERATION",
            "CPU_RESET_COUNT",
            "WR_CORE_RESET_COUNT",
            "SI_CONFIG_DROP_COUNT",
        )
    )


def consecutive_ready(rows: list[dict[str, Any]]) -> int:
    best = current = 0
    for row in rows:
        if integer(row, "LOCAL_READY", 0) == 1:
            current += 1
            best = max(best, current)
        else:
            current = 0
    return best


def analyze_text(text: str, *, source: str = "<text>") -> dict[str, Any]:
    rows = parse_samples(text)
    local = [row for row in rows if row.get("KIND") == "COMMA_LOCAL_SAMPLE"]
    formal = [row for row in rows if row.get("KIND") == "COMMA_FORMAL_SAMPLE"]
    slave = [row for row in rows if row.get("KIND") == "COMMA_SLAVE_SAMPLE"]

    transport_errors = sum(
        1 for row in local + formal if integer(row, "READ_VALID", 0) != 1
    )
    reset_changes = sum(
        1
        for old, new in zip(formal, formal[1:])
        if reset_signature(old) != reset_signature(new)
    )
    slave_recovery = any(
        integer(row, "POST_MASTER_REPROGRAM_RECOVERY", 0) == 1 for row in slave
    )
    local_ready_pass = consecutive_ready(local) >= 3
    formal_deltas = [
        (integer(row, "TX_CYCLE_DELTA"), integer(row, "TX_K28P5_DELTA"))
        for row in formal
    ]
    cycle_delta = formal_deltas[-1][0] if formal_deltas else None
    k28p5_delta = formal_deltas[-1][1] if formal_deltas else None

    if slave_recovery:
        classification = "POST_MASTER_REPROGRAM_RECOVERY_OBSERVED"
    elif not local_ready_pass:
        classification = "INCONCLUSIVE_DIAG_IMAGE_STARTUP"
    elif transport_errors:
        classification = "INCONCLUSIVE_TRANSPORT"
    elif reset_changes or any(
        integer(row, "RESET_CHANGED", 0) == 1 for row in formal
    ):
        classification = "INCONCLUSIVE_RESET"
    elif len(formal) < 5:
        classification = "INCONCLUSIVE_OBSERVATION_WINDOW"
    elif cycle_delta in (None, -1) or k28p5_delta in (None, -1):
        classification = "INCONCLUSIVE_COUNTER_BASELINE"
    elif cycle_delta is not None and cycle_delta < 0 or k28p5_delta is not None and k28p5_delta < 0:
        classification = "INCONCLUSIVE_COUNTER_BASELINE"
    elif cycle_delta > 0 and k28p5_delta > 0:
        classification = "MASTER_TX_K28P5_EMISSION_PASS"
    elif cycle_delta > 0 and k28p5_delta == 0:
        classification = "FAIL_MASTER_TX_PCS_COMMA_GENERATION"
    else:
        classification = "INCONCLUSIVE_TX_CLOCK_NO_ACTIVITY"

    return {
        "format": "step6-master-tx-comma-attribution-v1",
        "source": source,
        "sample_count": len(rows),
        "local_ready_samples": len(local),
        "formal_samples": len(formal),
        "slave_samples": len(slave),
        "transport_errors": transport_errors,
        "reset_changes": reset_changes,
        "local_ready_pass": local_ready_pass,
        "local_ready_max_streak": consecutive_ready(local),
        "post_master_reprogram_recovery": slave_recovery,
        "tx_cycle_delta": cycle_delta,
        "tx_k28p5_delta": k28p5_delta,
        "classification": classification,
        "master_tx_k28p5_emission": (
            "PASS"
            if classification == "MASTER_TX_K28P5_EMISSION_PASS"
            else "FAIL" if classification == "FAIL_MASTER_TX_PCS_COMMA_GENERATION" else "NOT_DETERMINED"
        ),
        "step6a": "NOT_PASS",
        "step6b": "NOT_RUN",
        "rows": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    text = args.capture.read_text(encoding="utf-8", errors="replace")
    result = analyze_text(text, source=str(args.capture))
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        for key in (
            "classification",
            "local_ready_pass",
            "formal_samples",
            "transport_errors",
            "reset_changes",
            "tx_cycle_delta",
            "tx_k28p5_delta",
            "step6a",
            "step6b",
        ):
            print(f"{key.upper()}={result[key]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
