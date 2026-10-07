"""Analyze the read-only current-session gate for the physical PPS baseline."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
GATE_SAMPLE_RE = re.compile(r"^S6A2_GATE_SAMPLE\s+(?P<body>.*)$")
GATE_PAIR_RE = re.compile(r"^S6A2_GATE_PAIR\s+(?P<body>.*)$")
GATE_RESULT_RE = re.compile(r"^S6A2_GATE_RESULT=(?P<value>[^\s]+)")
INVALID = {"", "INVALID", "TIMEOUT", "NA", "N/A", "UNKNOWN"}


def _value(value: str) -> int | str:
    try:
        return int(value, 0)
    except ValueError:
        try:
            return int(value, 10)
        except ValueError:
            return value


def _rows(text: str, pattern: re.Pattern[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = pattern.match(line.strip())
        if match:
            rows.append(
                {key.upper(): _value(value) for key, value in FIELD_RE.findall(match.group("body"))}
            )
    return rows


def _int(row: dict[str, Any], key: str, default: int | None = None) -> int | None:
    value = row.get(key, default)
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


def _gate_row_ok(row: dict[str, Any]) -> bool:
    cycles = _int(row, "SNAPSHOT_CYCLES")
    return all(
        _int(row, key) == expected
        for key, expected in {
            "READ_VALID": 1,
            "LINK_HEALTHY": 1,
            "CAPTURE_HEALTHY": 1,
            "RESET_CHANGED": 0,
            "STATUS_TIME_VALID": 1,
            "STATUS_PPS_VALID": 1,
            "SNAPSHOT_STABLE": 1,
            "SNAPSHOT_ACCEPTED": 1,
            "SNAPSHOT_VALID": 1,
            "SNAPSHOT_TIME_VALID": 1,
            "SNAPSHOT_PPS_VALID": 1,
            "STATUS_TM_LINK_UP": 1,
            "STATUS_LINK_OK": 1,
            "RX_PATTERN_READY": 1,
        }.items()
    ) and cycles is not None and 0 <= cycles <= 124_999_999


def analyze_text(text: str) -> dict[str, Any]:
    samples = _rows(text, GATE_SAMPLE_RE)
    pairs = _rows(text, GATE_PAIR_RE)
    gate_result = "MISSING"
    for line in text.splitlines():
        match = GATE_RESULT_RE.match(line.strip())
        if match:
            gate_result = match.group("value")

    common_labels = sorted(
        {
            _int(pair, "MASTER_TAI")
            for pair in pairs
            if _int(pair, "READ_VALID") == 1
            and _int(pair, "MASTER_GATE") == 1
            and _int(pair, "SLAVE_GATE") == 1
            and _int(pair, "MASTER_TAI") is not None
            and _int(pair, "MASTER_TAI") == _int(pair, "SLAVE_TAI")
            and _int(pair, "MASTER_CYCLES") == _int(pair, "SLAVE_CYCLES")
        }
    )
    common_labels = [label for label in common_labels if label is not None]
    roles = {
        role: [row for row in samples if str(row.get("ROLE", "")).upper() == role]
        for role in ("MASTER", "SLAVE")
    }
    reset_signatures = [
        tuple(_int(row, key) for key in
              ("BOOT_GENERATION", "CPU_RESET_COUNT", "WR_CORE_RESET_COUNT", "SI_CONFIG_DROP_COUNT"))
        for row in samples
    ]
    formal_pass = (
        gate_result == "PASS"
        and len(pairs) >= 3
        and len(roles["MASTER"]) >= 3
        and len(roles["SLAVE"]) >= 3
        and all(_gate_row_ok(row) for row in samples)
        and len(common_labels) >= 2
        and all(signature == (1, 1, 1, 1) for signature in reset_signatures)
    )
    return {
        "format": "step6-physical-pps-sma-gate-v1",
        "gate_result": gate_result,
        "verdict": "PASS" if formal_pass else "INCONCLUSIVE",
        "classification": (
            "PASS_PHYSICAL_PPS_PRECONDITION"
            if formal_pass
            else "INCONCLUSIVE_PHYSICAL_PPS_PRECONDITION_CHANGED"
        ),
        "pair_count": len(pairs),
        "master_sample_count": len(roles["MASTER"]),
        "slave_sample_count": len(roles["SLAVE"]),
        "common_tai_count": len(common_labels),
        "common_tai_labels": common_labels,
        "all_gate_rows_valid": all(_gate_row_ok(row) for row in samples),
        "reset_signatures": [list(signature) for signature in reset_signatures],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_text(args.capture.read_text(encoding="utf-8", errors="replace"))
    output = json.dumps(result, indent=2, sort_keys=True)
    print(output)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(output + "\n", encoding="utf-8")
    return 0 if result["verdict"] == "PASS" else 3


if __name__ == "__main__":
    raise SystemExit(main())
