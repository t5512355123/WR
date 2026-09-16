#!/usr/bin/env python3
"""Classify the read-only WDIAGS mapping/transport preflight output.

The preflight deliberately distinguishes a mailbox transaction timeout from a
completed transaction whose returned WDIAGS words do not match the established
mapping.  It never infers Step5 lock from this test.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


HEX_RE = re.compile(r"^(?:0x)?[0-9a-fA-F]+$")
KV_RE = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*)=([^\s]+)")
SAMPLE_RE = re.compile(r"^WDIAGS_MAP_SAMPLE\b")
RESULT_RE = re.compile(r"^WDIAGS_MAP_RESULT\b")
DONE_RE = re.compile(r"^WDIAGS_MAP_DONE\b")
TIMEOUT_VALUES = {"", "TIMEOUT", "INVALID", "NA"}


def _fields(line: str) -> dict[str, str]:
    result = {key.upper(): value for key, value in KV_RE.findall(line)}
    if "board=" in line:
        marker = line.index("board=") + len("board=")
        end_markers = (" label=", " attempt=", " begin_valid=")
        ends = [line.find(marker_text, marker) for marker_text in end_markers]
        ends = [end for end in ends if end >= 0]
        if ends:
            result["BOARD"] = line[marker : min(ends)]
    return result


def _is_hex(value: str | None) -> bool:
    return value is not None and value.upper() not in TIMEOUT_VALUES and bool(
        HEX_RE.fullmatch(value)
    )


def _transport_complete(row: dict[str, str]) -> bool:
    required = ("MAGIC_A", "MAGIC_B", "COUNTER", "INVERSE")
    return all(_is_hex(row.get(field)) for field in required)


def _map_valid(row: dict[str, str]) -> bool:
    return row.get("VALID", "0") == "1"


def analyze(path: Path, min_boards: int = 2) -> dict[str, Any]:
    samples: list[dict[str, str]] = []
    results: list[dict[str, str]] = []
    done = False
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if SAMPLE_RE.match(line):
            samples.append(_fields(line))
        elif RESULT_RE.match(line):
            results.append(_fields(line))
        elif DONE_RE.match(line):
            done = True

    boards = sorted(
        {row.get("BOARD", "UNKNOWN") for row in samples + results}
        - {"UNKNOWN", ""}
    )
    transport_rows = [row for row in samples if _transport_complete(row)]
    timeout_rows = [row for row in samples if not _transport_complete(row)]
    valid_rows = [row for row in samples if _map_valid(row)]

    board_summary: dict[str, dict[str, int]] = {}
    for board in boards:
        board_samples = [row for row in samples if row.get("BOARD") == board]
        board_results = [row for row in results if row.get("BOARD") == board]
        board_summary[board] = {
            "sample_rows": len(board_samples),
            "transport_complete_rows": sum(
                _transport_complete(row) for row in board_samples
            ),
            "mapping_valid_rows": sum(_map_valid(row) for row in board_samples),
            "begin_valid": sum(
                row.get("BEGIN_VALID") == "1" for row in board_results
            ),
            "end_valid": sum(row.get("END_VALID") == "1" for row in board_results),
        }

    complete_result_boards = {
        board
        for board, summary in board_summary.items()
        if summary["begin_valid"] > 0 and summary["end_valid"] > 0
    }
    if not samples:
        classification = "NO_PREFLIGHT_ROWS"
    elif not transport_rows:
        classification = "TRANSPORT_TIMEOUT"
    elif len(complete_result_boards) >= min_boards:
        classification = "PASS"
    elif valid_rows or transport_rows:
        classification = "MAP_SEMANTICS_INVALID" if not valid_rows else "PARTIAL"
    else:
        classification = "TRANSPORT_INCONCLUSIVE"

    return {
        "source": str(path),
        "done_marker_seen": done,
        "classification": classification,
        "preflight_pass": classification == "PASS",
        "step5_complete": False,
        "step5_pass": False,
        "sample_rows": len(samples),
        "transport_complete_rows": len(transport_rows),
        "transport_timeout_rows": len(timeout_rows),
        "mapping_valid_rows": len(valid_rows),
        "board_count": len(boards),
        "boards": boards,
        "board_summary": board_summary,
        "minimum_boards_required": min_boards,
        "results": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--min-boards", type=int, default=2)
    args = parser.parse_args()
    if args.min_boards <= 0:
        parser.error("--min-boards must be positive")
    verdict = analyze(args.input, args.min_boards)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(verdict, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({key: verdict[key] for key in (
        "classification", "preflight_pass", "sample_rows",
        "transport_complete_rows", "transport_timeout_rows", "mapping_valid_rows",
    )}, ensure_ascii=False))
    return 0 if verdict["preflight_pass"] else 2


if __name__ == "__main__":
    sys.exit(main())
