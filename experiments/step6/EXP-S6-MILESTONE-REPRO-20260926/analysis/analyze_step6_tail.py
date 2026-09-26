#!/usr/bin/env python3
"""Audit direct Slave Step 5 locks and Step 6A validity in a paired tail log."""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path


DEFAULT_LOG = (
    Path(__file__).resolve().parents[1]
    / "raw"
    / "observe"
    / "slave-postprogram-360s-step5-step6a-tail-20260926.log"
)
LOCK_FIELDS = (
    "HELPER_LOCKED",
    "MAIN_FREQ_LOCKED",
    "MAIN_PHASE_LOCKED",
    "MAIN_LOCKED",
    "PSTAT_LOCKED",
)
REQUIRED_FIELDS = (
    "SAMPLE",
    "ELAPSED_MS",
    "READ_VALID",
    "LINK_HEALTHY",
    "CAPTURE_HEALTHY",
    "RESET_CHANGED",
    "STATUS_TIME_VALID",
    "BOOT_GENERATION",
    "CPU_RESET_COUNT",
    "WR_CORE_RESET_COUNT",
    "SI_CONFIG_DROP_COUNT",
    *LOCK_FIELDS,
)


def parse_int(value: str) -> int:
    return int(value, 0) if value.startswith("0x") else int(value, 10)


def main() -> int:
    log = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_LOG
    rows: list[dict[str, str]] = []
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        if "S6_TAIL_SAMPLE ROLE=SLAVE " not in line:
            continue
        row = dict(re.findall(r"([A-Z][A-Z0-9_]*)=([^\s]+)", line))
        missing = [field for field in REQUIRED_FIELDS if field not in row]
        if missing:
            raise SystemExit(f"sample row missing fields {missing}: {row.get('SAMPLE')}")
        rows.append(row)

    if not rows:
        raise SystemExit(f"no Slave sample rows found in {log}")
    samples = [parse_int(row["SAMPLE"]) for row in rows]
    if len(samples) != len(set(samples)):
        raise SystemExit("duplicate Slave sample index")
    if samples != sorted(samples):
        raise SystemExit("Slave sample indices are not monotonic")

    valid_rows = [
        row
        for row in rows
        if parse_int(row["READ_VALID"]) == 1
        and parse_int(row["LINK_HEALTHY"]) == 1
        and parse_int(row["CAPTURE_HEALTHY"]) == 1
        and parse_int(row["RESET_CHANGED"]) == 0
        and all(parse_int(row[field]) == 1 for field in LOCK_FIELDS)
    ]
    bad_rows = [row for row in rows if row not in valid_rows]
    first_ms = parse_int(rows[0]["ELAPSED_MS"])
    last_ms = parse_int(rows[-1]["ELAPSED_MS"])
    span_ms = last_ms - first_ms
    sample_gaps = [
        (parse_int(a["SAMPLE"]), parse_int(b["SAMPLE"]))
        for a, b in zip(rows, rows[1:])
        if parse_int(b["SAMPLE"]) != parse_int(a["SAMPLE"]) + 1
    ]
    reset_signatures = sorted(
        {
            tuple(row[field] for field in (
                "BOOT_GENERATION",
                "CPU_RESET_COUNT",
                "WR_CORE_RESET_COUNT",
                "SI_CONFIG_DROP_COUNT",
            ))
            for row in rows
        }
    )
    servo_states = Counter(
        row.get("SERVO_STATE", "MISSING") for row in rows
    )
    valid_time_rows = [
        row for row in rows if parse_int(row["STATUS_TIME_VALID"]) == 1
    ]

    step5_pass = (
        len(valid_rows) == len(rows)
        and not sample_gaps
        and len(reset_signatures) == 1
        and span_ms >= 300_000
    )
    result = {
        "log": str(log),
        "role": "SLAVE",
        "sample_count": len(rows),
        "first_sample": samples[0],
        "last_sample": samples[-1],
        "first_elapsed_ms": first_ms,
        "last_elapsed_ms": last_ms,
        "sampled_span_ms": span_ms,
        "valid_five_lock_samples": len(valid_rows),
        "lock_or_health_violations": len(bad_rows),
        "sample_gaps": sample_gaps,
        "reset_signatures": [list(signature) for signature in reset_signatures],
        "servo_state_counts": dict(sorted(servo_states.items())),
        "time_valid_sample_count": len(valid_time_rows),
        "step5_direct_locks_300s": "PASS" if step5_pass else "FAIL",
        "step6a_slave_time_valid": "PASS" if len(valid_time_rows) == len(rows) else "NOT_PASS",
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if step5_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
