#!/usr/bin/env python3
"""Decode and evaluate a raw Step1 JTAG probe capture."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple


SAMPLE_RE = re.compile(
    r'^STEP1_SAMPLE board="(?P<board>[^"]+)" n=(?P<n>\d+) '
    r'elapsed_ms=(?P<elapsed>\d+) read_ok=(?P<ok>[01]) '
    r'raw=(?P<raw>[0-9A-Fa-f]{1,16}|INVALID)$'
)
MIN_SAMPLES = 300
MIN_DURATION_MS = 30_000
ERROR_PERSISTENCE_SAMPLES = 5
MAX_SAMPLE_GAP_MS = 250


@dataclass(frozen=True)
class Sample:
    board: str
    number: int
    elapsed_ms: int
    raw: int


def bit(raw: int, index: int) -> int:
    return (raw >> index) & 1


def parse_capture(text: str) -> Tuple[Dict[str, List[Sample]], Dict[str, int]]:
    boards: Dict[str, List[Sample]] = {}
    counts = {"sample_lines": 0, "malformed": 0, "read_failures": 0}
    for line in text.splitlines():
        if not line.startswith("STEP1_SAMPLE"):
            continue
        counts["sample_lines"] += 1
        match = SAMPLE_RE.match(line.strip())
        if not match:
            counts["malformed"] += 1
            continue
        if match.group("ok") != "1" or match.group("raw") == "INVALID":
            counts["read_failures"] += 1
            continue
        board = match.group("board")
        sample = Sample(
            board=board,
            number=int(match.group("n")),
            elapsed_ms=int(match.group("elapsed")),
            raw=int(match.group("raw"), 16),
        )
        boards.setdefault(board, []).append(sample)
    return boards, counts


def role_for(board: str) -> str | None:
    if "1-11.1" in board:
        return "MASTER"
    if "1-11.2" in board:
        return "SLAVE"
    return None


def summarize_board(samples: List[Sample]) -> dict:
    ordered = sorted(samples, key=lambda item: item.number)
    required = {
        "PHY_READY": 1,  # top-level wr_ready, probe bit 1
        "TM_LINK_UP": 2,  # core_tm_link_up, bit 2
        "CORE_LINK_OK": 3,  # core_link_ok, bit 3
        "RX_READY": 6,  # wr_rx_ready, bit 6
        "TX_READY": 7,  # wr_tx_ready, bit 7
        "CPU_RESET_N": 15,  # CPU_RESET_n, bit 15
        "RX_LOCKED_TO_DATA": 32,  # wr_rx_locked_to_data, bit 32
    }
    gate_drop_counts = {
        name: sum(bit(sample.raw, index) != 1 for sample in ordered)
        for name, index in required.items()
    }

    error_runs: List[int] = []
    current_run = 0
    previous: Sample | None = None
    error_samples = 0
    error_bits = (13, 14, 34, 35)
    for sample in ordered:
        has_error = any(bit(sample.raw, index) for index in error_bits)
        gap = sample.elapsed_ms - previous.elapsed_ms if previous else 0
        if has_error:
            error_samples += 1
            if previous is None or gap > MAX_SAMPLE_GAP_MS:
                if current_run:
                    error_runs.append(current_run)
                current_run = 1
            else:
                current_run += 1
        elif current_run:
            error_runs.append(current_run)
            current_run = 0
        previous = sample
    if current_run:
        error_runs.append(current_run)

    contiguous = bool(ordered) and ordered[0].number == 1 and all(
        current.number == previous_sample.number + 1
        for previous_sample, current in zip(ordered, ordered[1:])
    )
    duration_ms = (
        ordered[-1].elapsed_ms - ordered[0].elapsed_ms if len(ordered) >= 2 else 0
    )
    enough_capture = len(ordered) >= MIN_SAMPLES and duration_ms >= MIN_DURATION_MS
    max_error_run = max(error_runs, default=0)
    gates_pass = all(value == 0 for value in gate_drop_counts.values())
    errors_pass = max_error_run < ERROR_PERSISTENCE_SAMPLES
    verdict = "PASS" if enough_capture and contiguous and gates_pass and errors_pass else (
        "INCONCLUSIVE" if not enough_capture or not contiguous else "FAIL"
    )
    return {
        "samples": len(ordered),
        "duration_ms": duration_ms,
        "contiguous": contiguous,
        "enough_capture": enough_capture,
        "gate_drop_counts": gate_drop_counts,
        "error_samples": error_samples,
        "max_error_run": max_error_run,
        "verdict": verdict,
    }


def analyze(text: str) -> Tuple[str, List[str]]:
    boards, counts = parse_capture(text)
    output = [
        "STEP1_CAPTURE_SUMMARY "
        f"sample_lines={counts['sample_lines']} malformed={counts['malformed']} "
        f"read_failures={counts['read_failures']}"
    ]
    verdicts = []
    roles_seen = set()
    unknown_boards = []
    for board, samples in sorted(boards.items()):
        role = role_for(board)
        if role is None:
            output.append(f"STEP1_BOARD_UNKNOWN board={board!r} samples={len(samples)}")
            unknown_boards.append(board)
            continue
        if role in roles_seen:
            output.append(f"STEP1_DUPLICATE_ROLE role={role} board={board!r}")
            return "INCONCLUSIVE", output
        roles_seen.add(role)
        summary = summarize_board(samples)
        drops = ",".join(
            f"{name}:{count}" for name, count in summary["gate_drop_counts"].items()
        )
        output.append(
            f"STEP1_BOARD role={role} board={board!r} verdict={summary['verdict']} "
            f"samples={summary['samples']} duration_ms={summary['duration_ms']} "
            f"gate_drops=[{drops}] transient_error_samples={summary['error_samples']} "
            f"max_consecutive_error_samples={summary['max_error_run']}"
        )
        verdicts.append(summary["verdict"])
    if counts["malformed"] or counts["read_failures"]:
        output.append("STEP1_OVERALL=INCONCLUSIVE invalid_or_unreadable_rows=1")
        return "INCONCLUSIVE", output
    if roles_seen != {"MASTER", "SLAVE"} or unknown_boards:
        output.append(f"STEP1_OVERALL=INCONCLUSIVE roles_seen={','.join(sorted(roles_seen))}")
        return "INCONCLUSIVE", output
    overall = "PASS" if all(value == "PASS" for value in verdicts) else (
        "FAIL" if "FAIL" in verdicts else "INCONCLUSIVE"
    )
    output.append(f"STEP1_OVERALL={overall}")
    return overall, output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    verdict, lines = analyze(args.capture.read_text(encoding="utf-8", errors="replace"))
    print("\n".join(lines))
    return 0 if verdict == "PASS" else 2 if verdict == "INCONCLUSIVE" else 1


if __name__ == "__main__":
    sys.exit(main())
