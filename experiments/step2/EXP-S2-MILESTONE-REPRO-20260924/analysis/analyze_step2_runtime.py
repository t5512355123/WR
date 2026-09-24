#!/usr/bin/env python3
"""Offline acceptance analysis for the Step 2 DE5a runtime capture."""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path


EXPECTED = {
    "DE5 [1-11.1]": {
        "mode": 2,
        "ptp": 6,
        "mac": "0200020022334401",
    },
    "DE5 [1-11.2]": {
        "mode": 3,
        "ptp": 9,
        "mac": "0200020022334402",
    },
}

STEP1_REQUIRED_BITS = (0, 1, 2, 3, 6, 7, 15)
STEP1_ERROR_BITS = (13, 14)


def clean_terminal_controls(text: str) -> str:
    return re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)


def parse_snapshot(path: Path) -> dict[str, dict[str, str]]:
    text = clean_terminal_controls(path.read_text(errors="replace"))
    sections: dict[str, dict[str, str]] = {}
    current: str | None = None
    for line in text.splitlines():
        board = re.match(r"^=== (DE5 \[1-11\.\d\]) ===$", line.strip())
        if board:
            current = board.group(1)
            sections[current] = {}
            continue
        if current is None:
            continue
        field = re.match(r"^([A-Za-z0-9_]+):\s*(.*?)\s*$", line)
        if field:
            sections[current][field.group(1)] = field.group(2)
    return sections


def integer(fields: dict[str, str], key: str) -> int:
    value = fields.get(key)
    if value is None:
        raise ValueError(f"snapshot is missing {key}")
    return int(value, 16)


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

        def hex_field(name: str) -> int:
            found = re.search(rf"\b{name}:\s*([0-9A-Fa-f]{{1,16}})", chunk)
            if found is None:
                raise ValueError(
                    f"sample {header.group(1)} #{header.group(2)} "
                    f"is missing {name}"
                )
            return int(found.group(1), 16)

        sample_n = int(header.group(2))
        if sample_n != int(result.group(1)):
            raise ValueError("sample header/result index mismatch")
        row: dict[str, int | bool] = {
            "sample": sample_n,
            "attempt": int(header.group(3)),
            "accepted": int(result.group(2)) == 1,
            "retries": int(result.group(3)),
            "status": int(header.group(4), 16) & 0xFFFF,
            "ptp_rx": hex_field("WDIAGS_PTP_RX"),
            "ptp_tx": hex_field("WDIAGS_PTP_TX"),
            "ptp_meta": hex_field("WDIAGS_PTP_META"),
            "foreign_meta": hex_field("WDIAGS_FOREIGN_META"),
            "frame_valid": bool(
                re.search(r"FRAME_VALID:\s*1\b", chunk)
            ),
        }
        rows[header.group(1)].append(row)

    return rows


def delta_u32(start: int, end: int) -> int:
    return (end - start) & 0xFFFFFFFF


def validate_snapshot(
    label: str,
    snapshot: dict[str, dict[str, str]],
    errors: list[str],
) -> None:
    for board, expected in EXPECTED.items():
        fields = snapshot.get(board)
        if fields is None:
            errors.append(f"{label}: missing board section {board}")
            continue
        try:
            mac = f"{integer(fields, 'EP_MAC_H'):08X}{integer(fields, 'EP_MAC_L'):08X}"
            if mac != expected["mac"]:
                errors.append(f"{label}: {board} MAC {mac} != {expected['mac']}")
            if integer(fields, "WDIAGS_MODE") != expected["mode"]:
                errors.append(f"{label}: {board} role mode mismatch")
            if integer(fields, "WDIAGS_PTP") != expected["ptp"]:
                errors.append(f"{label}: {board} PTP state mismatch")
            if integer(fields, "CPU_RESET") != 0:
                errors.append(f"{label}: {board} CPU reset asserted")
            cpu_debug = fields.get("cpu_debug", "")
            if not re.search(r"\breset=0\b", cpu_debug) or not re.search(
                r"\bfault=0\b", cpu_debug
            ):
                errors.append(f"{label}: {board} CPU debug reports reset/fault")
            if not re.search(r"\bim_valid=1\b", cpu_debug):
                errors.append(f"{label}: {board} firmware image is not valid")
            if not re.search(r"0x0*B004\s+seen=1\b", fields.get("cpu_marker", ""), re.I):
                errors.append(f"{label}: {board} firmware marker B004 is not present")
            if (integer(fields, "WDIAGS_RESTART") & 0xFFFF) == 0:
                errors.append(f"{label}: {board} restart/generation marker invalid")
            if not int(fields.get("status_probe", "0"), 16) & (1 << 15):
                errors.append(f"{label}: {board} CPU_RESET_n probe is low")
            probe = int(fields.get("status_probe", "0"), 16) & 0xFFFF
            for bit in STEP1_REQUIRED_BITS:
                if not (probe & (1 << bit)):
                    errors.append(f"{label}: {board} Step1 status bit {bit} is low")
            for bit in STEP1_ERROR_BITS:
                if probe & (1 << bit):
                    errors.append(f"{label}: {board} encoding-error bit {bit} is high")
        except ValueError as exc:
            errors.append(f"{label}: {board}: {exc}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", type=Path, required=True)
    parser.add_argument("--series", type=Path, required=True)
    parser.add_argument("--end", type=Path, required=True)
    args = parser.parse_args()

    errors: list[str] = []
    start = parse_snapshot(args.start)
    end = parse_snapshot(args.end)
    series = parse_timeseries(args.series)
    validate_snapshot("start", start, errors)
    validate_snapshot("end", end, errors)

    for board, expected in EXPECTED.items():
        samples = series.get(board, [])
        results = samples
        accepted = [row for row in samples if row["accepted"] and row["frame_valid"]]
        sample_indices = [int(row["sample"]) for row in results]
        if sample_indices != list(range(1, 31)):
            errors.append(f"series: {board} expected result indexes 1..30")
        if len(accepted) < 2 or not accepted or accepted[0]["sample"] != 1 or accepted[-1]["sample"] != 30:
            errors.append(f"series: {board} lacks valid accepted boundary samples 1 and 30")

        for row in accepted:
            status = int(row["status"])
            for bit in STEP1_REQUIRED_BITS:
                if not status & (1 << bit):
                    errors.append(f"series: {board} sample {row['sample']} Step1 bit {bit} is low")
            for bit in STEP1_ERROR_BITS:
                if status & (1 << bit):
                    errors.append(f"series: {board} sample {row['sample']} encoding-error bit {bit} is high")
            meta = int(row["ptp_meta"])
            if ((meta >> 24) & 0xFF) != expected["mode"] or (meta & 0xFF) != expected["ptp"]:
                errors.append(f"series: {board} sample {row['sample']} role/PTP metadata mismatch")
            if board == "DE5 [1-11.2]":
                foreign = int(row["foreign_meta"])
                if (foreign & 0xFF) != 1 or ((foreign >> 8) & 0xFF) != 0:
                    errors.append(f"series: Slave sample {row['sample']} foreign-master metadata mismatch")

        for field in ("ptp_rx", "ptp_tx"):
            values = [int(row[field]) for row in accepted]
            if len(values) < 2 or delta_u32(values[0], values[-1]) == 0:
                errors.append(f"series: {board} {field} counter did not advance")

        a, b = start.get(board, {}), end.get(board, {})
        for field in ("WDIAGS_TX", "WDIAGS_RX", "WDIAGS_PTP_RX", "WDIAGS_PTP_TX"):
            try:
                movement = delta_u32(integer(a, field), integer(b, field))
                if movement == 0:
                    errors.append(f"snapshots: {board} {field} counter did not advance")
            except ValueError as exc:
                errors.append(f"snapshots: {board}: {exc}")
        try:
            if integer(a, "WDIAGS_RESTART") != integer(b, "WDIAGS_RESTART"):
                errors.append(f"snapshots: {board} restart/generation marker changed")
            if integer(a, "WDIAGS_RXERR") != integer(b, "WDIAGS_RXERR"):
                errors.append(f"snapshots: {board} WDIAGS_RXERR changed during observation")
        except ValueError as exc:
            errors.append(f"snapshots: {board}: {exc}")

        print(
            f"{board}: results={len(results)} accepted={len(accepted)} "
            f"rejected={len(results)-len(accepted)} "
            f"mode={expected['mode']} PTP={expected['ptp']} "
            f"PTP_RX={accepted[0]['ptp_rx']}->{accepted[-1]['ptp_rx']} "
            f"PTP_TX={accepted[0]['ptp_tx']}->{accepted[-1]['ptp_tx']}"
        )
        if board in start and board in end:
            for field in ("WDIAGS_TX", "WDIAGS_RX", "WDIAGS_PTP_RX", "WDIAGS_PTP_TX"):
                x, y = integer(start[board], field), integer(end[board], field)
                print(f"  {field}: {x} -> {y} (delta {delta_u32(x, y)})")
            print(
                f"  WDIAGS_RXERR: {integer(start[board], 'WDIAGS_RXERR')} -> "
                f"{integer(end[board], 'WDIAGS_RXERR')} (no growth)"
            )

    if errors:
        print("STEP2_RUNTIME=NOT_PASS")
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print("STEP2_RUNTIME=PASS")
    print("Step 2 acceptance verified; Step 3+ behavior is not part of this verdict.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
