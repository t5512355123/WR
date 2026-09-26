#!/usr/bin/env python3
"""Summarize the read-only Slave CKO/SETP WR-servo time series."""

from __future__ import annotations

import hashlib
import json
import re
import statistics
import sys
from collections import Counter
from pathlib import Path


DEFAULT_LOG = (
    Path(__file__).resolve().parents[1]
    / "raw"
    / "observe"
    / "slave-phase-offset-loop-60x1s.log"
)
START = re.compile(r"^SESSION_SAMPLE board=DE5 \[1-11\.2\] sample=(\d+)")
HEX_FIELD = re.compile(r"\b(WDIAGS_(?:CKO|SETP|UCNT)):([0-9A-Fa-f]{8})\b")
SERVO_STATE = re.compile(r"\bservo_state=(\d+)")
STEP5_BOUNDARY = re.compile(r"\bboundary=([A-Z_]+)")
LOCAL_FIELDS = re.compile(
    r"\bparent_is_wr=(\d+) parent_calibrated=(\d+) "
    r"wr_config=(\d+) parent_wr_config=(\d+) state=(\d+) "
    r"next_state=(\d+) parent_detection=(\d+) wr_mode=(\d+)"
)


def signed32(raw: str) -> int:
    value = int(raw, 16)
    return value - 0x1_0000_0000 if value & 0x8000_0000 else value


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_LOG
    content = path.read_bytes()
    text = content.decode("utf-8", errors="replace")
    rows: list[dict[str, int | str | bool | None]] = []
    current: dict[str, int | str | bool | None] | None = None
    frame_valid_count = 0
    frame_count = 0

    for line in text.splitlines():
        match = START.match(line)
        if match:
            if current is not None:
                rows.append(current)
            current = {"sample": int(match.group(1))}
            continue
        if current is None:
            continue

        if line.startswith("FRAME_VALID:"):
            frame_count += 1
            is_valid = line.startswith("FRAME_VALID: 1 ")
            current["frame_valid"] = is_valid
            frame_valid_count += int(is_valid)
        elif line.startswith("WDIAGS_DMS_H:"):
            values = dict(HEX_FIELD.findall(line))
            if all(f"WDIAGS_{field}" in values for field in ("CKO", "SETP", "UCNT")):
                current["cko_ps"] = signed32(values["WDIAGS_CKO"])
                current["setp_ps"] = signed32(values["WDIAGS_SETP"])
                current["update_count"] = int(values["WDIAGS_UCNT"], 16)
        elif line.startswith("DECODE:"):
            match = SERVO_STATE.search(line)
            if match:
                current["servo_state"] = int(match.group(1))
            current["time_valid"] = "time_valid=1" in line
            current["pps_valid"] = "pps_valid=1" in line
        elif line.startswith("STEP5_LOCKDET:"):
            match = STEP5_BOUNDARY.search(line)
            if match:
                current["step5_boundary"] = match.group(1)
        elif line.startswith("WR_LOCAL:"):
            match = LOCAL_FIELDS.search(line)
            if match:
                labels = (
                    "parent_is_wr",
                    "parent_calibrated",
                    "wr_config",
                    "parent_wr_config",
                    "wr_state",
                    "wr_next_state",
                    "parent_detection",
                    "wr_mode",
                )
                current.update({label: int(value) for label, value in zip(labels, match.groups())})

    if current is not None:
        rows.append(current)

    parsed = [row for row in rows if "cko_ps" in row and "setp_ps" in row]
    if not parsed:
        raise SystemExit(f"no CKO/SETP samples found in {path}")

    cko_values = [int(row["cko_ps"]) for row in parsed]
    setp_values = [int(row["setp_ps"]) for row in parsed]
    states = Counter(str(row.get("servo_state", "MISSING")) for row in parsed)
    boundaries = Counter(str(row.get("step5_boundary", "MISSING")) for row in parsed)
    setpoint_changes = []
    for before, after in zip(parsed, parsed[1:]):
        if before["setp_ps"] != after["setp_ps"]:
            setpoint_changes.append(
                {
                    "sample": after["sample"],
                    "old_setp_ps": before["setp_ps"],
                    "new_setp_ps": after["setp_ps"],
                    "cko_before_ps": before["cko_ps"],
                    "cko_after_ps": after["cko_ps"],
                    "servo_state_after": after.get("servo_state"),
                }
            )

    coherent_count = sum(bool(row.get("frame_valid")) for row in parsed)
    valid_step5_count = sum(row.get("step5_boundary") == "LOCKED_SAMPLE" for row in parsed)
    within_gate = sum(abs(value) < 60 for value in cko_values)
    local_wr = Counter(
        (
            row.get("wr_mode"),
            row.get("parent_is_wr"),
            row.get("parent_calibrated"),
            row.get("wr_state"),
        )
        for row in parsed
        if "wr_mode" in row
    )
    summary = {
        "log": str(path),
        "sha256": hashlib.sha256(content).hexdigest(),
        "slave_samples": len(rows),
        "cko_setp_parsed_samples": len(parsed),
        "frame_valid_samples": coherent_count,
        "frame_samples": frame_count,
        "servo_state_counts": dict(sorted(states.items())),
        "step5_boundary_counts": dict(sorted(boundaries.items())),
        "step5_locked_sample_count": valid_step5_count,
        "time_valid_sample_count": sum(bool(row.get("time_valid")) for row in parsed),
        "pps_valid_sample_count": sum(bool(row.get("pps_valid")) for row in parsed),
        "cko_ps": {
            "min": min(cko_values),
            "max": max(cko_values),
            "median": statistics.median(cko_values),
            "within_abs_60_ps": within_gate,
        },
        "setp_ps": {
            "min": min(setp_values),
            "max": max(setp_values),
            "distinct_values": sorted(set(setp_values)),
            "change_count": len(setpoint_changes),
        },
        "setpoint_change_samples": setpoint_changes,
        "local_wr_mode_parent_state_counts": [
            {"wr_mode": key[0], "parent_is_wr": key[1], "parent_calibrated": key[2], "wr_state": key[3], "count": count}
            for key, count in sorted(local_wr.items(), key=lambda item: str(item[0]))
        ],
        "causal_direction_verdict": (
            "INCONCLUSIVE_NONCOHERENT_FRAMES"
            if coherent_count != len(parsed)
            else "REQUIRES_ENGINEERING_REVIEW"
        ),
    }
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
