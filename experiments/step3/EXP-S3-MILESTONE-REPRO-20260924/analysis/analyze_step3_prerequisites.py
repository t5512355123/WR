#!/usr/bin/env python3
"""Validate Step 1/2 prerequisites without treating debug aliases as resets."""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


EXPECTED: dict[str, dict[str, Any]] = {
    "DE5 [1-11.1]": {"mode": 2, "ptp": 6, "mac": "0200020022334401"},
    "DE5 [1-11.2]": {"mode": 3, "ptp": 9, "mac": "0200020022334402"},
}
STEP1_REQUIRED_BITS = (0, 1, 2, 3, 6, 7, 15)
STEP1_ERROR_BITS = (13, 14)
MINIMUM_ACCEPTED = 20


def clean_terminal_controls(text: str) -> str:
    return re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)


def parse_snapshot(path: Path) -> dict[str, dict[str, list[str]]]:
    text = clean_terminal_controls(path.read_text(errors="replace"))
    sections: dict[str, dict[str, list[str]]] = {}
    current: str | None = None
    for line in text.splitlines():
        board = re.match(r"^=== (DE5 \[1-11\.\d\]) ===$", line.strip())
        if board:
            current = board.group(1)
            sections[current] = defaultdict(list)
            continue
        if current is None:
            continue
        field = re.match(r"^([A-Za-z0-9_]+):\s*(.*?)\s*$", line)
        if field:
            sections[current][field.group(1)].append(field.group(2))
    return sections


def snapshot_hex(fields: dict[str, list[str]], key: str) -> int:
    values = fields.get(key, [])
    if not values:
        raise ValueError(f"snapshot is missing {key}")
    return int(values[-1], 16)


def validate_snapshot_board(
    board: str, fields: dict[str, list[str]], label: str
) -> list[str]:
    errors: list[str] = []
    expected = EXPECTED[board]
    try:
        mac = f"{snapshot_hex(fields, 'EP_MAC_H'):08X}{snapshot_hex(fields, 'EP_MAC_L'):08X}"
        if mac != expected["mac"]:
            errors.append(f"{label}: {board} MAC {mac} != {expected['mac']}")
        if snapshot_hex(fields, "WDIAGS_MODE") != expected["mode"]:
            errors.append(f"{label}: {board} role mode mismatch")
        if snapshot_hex(fields, "WDIAGS_PTP") != expected["ptp"]:
            errors.append(f"{label}: {board} PTP state mismatch")
        probe = snapshot_hex(fields, "status_probe") & 0xFFFF
        for bit in STEP1_REQUIRED_BITS:
            if not probe & (1 << bit):
                errors.append(f"{label}: {board} Step1 status bit {bit} is low")
        for bit in STEP1_ERROR_BITS:
            if probe & (1 << bit):
                errors.append(f"{label}: {board} encoding-error status bit {bit} is high")
        cpu_debug = fields.get("cpu_debug", [])
        if len(cpu_debug) < 2:
            errors.append(f"{label}: {board} CPU debug samples are missing")
        for sample, value in enumerate(cpu_debug, start=1):
            if not re.search(r"\breset=0\b", value):
                errors.append(f"{label}: {board} CPU debug sample {sample} reports reset")
            if not re.search(r"\bfault=0\b", value):
                errors.append(f"{label}: {board} CPU debug sample {sample} reports fault")
            if not re.search(r"\bim_valid=1\b", value):
                errors.append(f"{label}: {board} firmware image is invalid")
        if not any(
            re.search(r"0x0*B004\s+seen=1\b", value, re.I)
            for value in fields.get("cpu_marker", [])
        ):
            errors.append(f"{label}: {board} firmware marker B004 is not present")
    except ValueError as exc:
        errors.append(f"{label}: {board}: {exc}")
    return errors


def parse_timeseries(path: Path) -> dict[str, list[dict[str, int | bool]]]:
    text = clean_terminal_controls(path.read_text(errors="replace"))
    chunks = re.split(r"(?=SESSION_SAMPLE board=)", text)
    rows: dict[str, list[dict[str, int | bool]]] = defaultdict(list)
    for chunk in chunks:
        header = re.search(
            r"SESSION_SAMPLE board=(DE5 \[1-11\.\d\]) sample=(\d+) "
            r"attempt=(\d+) status=([0-9A-Fa-f]+)",
            chunk,
        )
        result = re.search(
            r"SESSION_SAMPLE_RESULT board=DE5 \[1-11\.\d\] sample=(\d+) "
            r"accepted=(\d+) retries=(\d+)",
            chunk,
        )
        if header is None or result is None:
            continue
        if header.group(2) != result.group(1):
            raise ValueError("sample header/result index mismatch")

        def hex_value(name: str, width: int = 16) -> int:
            match = re.search(rf"\b{name}:\s*([0-9A-Fa-f]{{1,{width}}})", chunk)
            if match is None:
                raise ValueError(f"sample {header.group(1)} #{header.group(2)} missing {name}")
            return int(match.group(1), 16)

        row: dict[str, int | bool] = {
            "sample": int(header.group(2)),
            "attempt": int(header.group(3)),
            "status": int(header.group(4), 16) & 0xFFFF,
            "accepted": result.group(2) == "1",
            "retries": int(result.group(3)),
            "frame_valid": bool(re.search(r"FRAME_VALID:\s*1\b", chunk)),
            "ptp_rx": hex_value("WDIAGS_PTP_RX"),
            "ptp_tx": hex_value("WDIAGS_PTP_TX"),
            "ptp_meta": hex_value("WDIAGS_PTP_META"),
            "foreign_meta": hex_value("WDIAGS_FOREIGN_META"),
        }
        rows[header.group(1)].append(row)
    return rows


def delta_u32(start: int, end: int) -> int:
    return (end - start) & 0xFFFFFFFF


def validate_series_board(
    board: str, rows: list[dict[str, int | bool]], expected_count: int = 30
) -> list[str]:
    errors: list[str] = []
    indices = [int(row["sample"]) for row in rows]
    if indices != list(range(1, expected_count + 1)):
        errors.append(f"{board}: expected result indexes 1..{expected_count}")
    accepted = [row for row in rows if row["accepted"] and row["frame_valid"]]
    if len(accepted) < MINIMUM_ACCEPTED:
        errors.append(
            f"{board}: only {len(accepted)} coherent accepted frames; need {MINIMUM_ACCEPTED}"
        )
    if accepted and (
        int(accepted[0]["sample"]) != 1
        or int(accepted[-1]["sample"]) != expected_count
    ):
        errors.append(f"{board}: accepted boundary samples 1 and {expected_count} are missing")

    expected = EXPECTED[board]
    for row in accepted:
        sample = int(row["sample"])
        status = int(row["status"])
        for bit in STEP1_REQUIRED_BITS:
            if not status & (1 << bit):
                errors.append(f"{board} sample {sample}: Step1 status bit {bit} is low")
        for bit in STEP1_ERROR_BITS:
            if status & (1 << bit):
                errors.append(f"{board} sample {sample}: encoding-error status bit {bit} is high")
        meta = int(row["ptp_meta"])
        if ((meta >> 24) & 0xFF) != expected["mode"] or (meta & 0xFF) != expected["ptp"]:
            errors.append(f"{board} sample {sample}: role/PTP metadata mismatch")
        if board == "DE5 [1-11.2]":
            foreign = int(row["foreign_meta"])
            if (foreign & 0xFF) != 1 or ((foreign >> 8) & 0xFF) != 0:
                errors.append(f"{board} sample {sample}: foreign-parent metadata mismatch")

    for name in ("ptp_rx", "ptp_tx"):
        values = [int(row[name]) for row in accepted]
        if len(values) >= 2 and delta_u32(values[0], values[-1]) == 0:
            errors.append(f"{board}: {name} counter did not advance")
    return errors


def validate_window(
    start: dict[str, dict[str, list[str]]],
    rows: dict[str, list[dict[str, int | bool]]],
    end: dict[str, dict[str, list[str]]],
) -> list[str]:
    errors: list[str] = []
    counters = ("WDIAGS_TX", "WDIAGS_RX", "WDIAGS_PTP_RX", "WDIAGS_PTP_TX")
    for board in EXPECTED:
        if board not in start or board not in end:
            errors.append(f"snapshots: missing {board} start/end capture")
            continue
        errors.extend(validate_snapshot_board(board, start[board], "start"))
        errors.extend(validate_snapshot_board(board, end[board], "end"))
        try:
            for key in counters:
                before = snapshot_hex(start[board], key)
                after = snapshot_hex(end[board], key)
                if delta_u32(before, after) == 0:
                    errors.append(f"snapshots: {board} {key} counter did not advance")
            if snapshot_hex(start[board], "WDIAGS_RXERR") != snapshot_hex(end[board], "WDIAGS_RXERR"):
                errors.append(f"snapshots: {board} WDIAGS_RXERR changed")
            for key in ("SYSC_RSTR", "SYSC_GPSR"):
                if snapshot_hex(start[board], key) != snapshot_hex(end[board], key):
                    errors.append(f"snapshots: {board} {key} changed")
        except ValueError as exc:
            errors.append(f"snapshots: {board}: {exc}")
        errors.extend(validate_series_board(board, rows.get(board, [])))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", type=Path, required=True)
    parser.add_argument("--series", type=Path, required=True)
    parser.add_argument("--end", type=Path, required=True)
    args = parser.parse_args()
    start = parse_snapshot(args.start)
    end = parse_snapshot(args.end)
    rows = parse_timeseries(args.series)

    for board in EXPECTED:
        accepted = [row for row in rows.get(board, []) if row["accepted"] and row["frame_valid"]]
        if accepted:
            first, last = accepted[0], accepted[-1]
            print(
                f"{board}: coherent_accepted={len(accepted)}/{len(rows.get(board, []))} "
                f"PTP_RX={first['ptp_rx']}->{last['ptp_rx']} "
                f"PTP_TX={first['ptp_tx']}->{last['ptp_tx']}"
            )
        else:
            print(f"{board}: coherent_accepted=0/{len(rows.get(board, []))}")

    errors = validate_window(start, rows, end)
    if errors:
        print("STEP3_PREREQUISITES=NOT_PASS")
        for error in errors:
            print(f"ERROR: {error}")
        print("RESET_GENERATION_COUNTER=NOT_EXPOSED; sampled reset indicators are checked instead")
        return 1

    print("STEP3_PREREQUISITES=PASS")
    print("Step 1/2 gates, endpoint roles, counter progress, and sampled reset indicators passed.")
    print("RESET_GENERATION_COUNTER=NOT_EXPOSED; no reset-generation claim is made.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
