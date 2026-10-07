#!/usr/bin/env python3
"""Validate the passive F4S Main producer-schedule smoke capture.

F4S answers only where the existing F4L producer schedule stops:
Main-enable continuity, page selector, page2 due, and page2 publication.
It is a diagnostic classification, never a Step5 lock verdict.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

from step5_f4l_main_phase_drift_integrator import (
    _int,
    _parse_line,
    _u32,
)


SCHEDULE_MAGIC = 0x46345331
SCHEDULE_WORDS = 8
UINT32_MASK = (1 << 32) - 1
INVALID = {"", "INVALID", "UNKNOWN", "TIMEOUT", "NOT_MEASURED", "NONE"}


def _raw_u32(value: Any) -> Optional[int]:
    """Parse the observer's fixed-width raw words as hexadecimal.

    F4S emits ``F4S_Wxx_RAW`` as eight hexadecimal digits without a ``0x``
    prefix, while the surrounding metadata uses both prefixed and decimal
    forms.  Treating these fixed-width raw words as decimal silently changes
    the magic and sequence values, so keep their wire representation explicit.
    """
    if value is None or isinstance(value, bool):
        return None
    text = str(value).strip()
    if text.upper() in INVALID:
        return None
    try:
        return int(text, 16) & UINT32_MASK
    except ValueError:
        return _u32(text)


def _raw_schedule_words(fields: Dict[str, str]) -> Tuple[List[Optional[int]], List[str]]:
    words: List[Optional[int]] = [None] * SCHEDULE_WORDS
    problems: List[str] = []
    for index in range(SCHEDULE_WORDS):
        value = _raw_u32(fields.get(f"F4S_W{index:02d}_RAW"))
        words[index] = value
        if value is None:
            problems.append(f"RAW_WORD_{index:02d}_MISSING_OR_INVALID")
    return words, problems


def _validate_schedule_row(fields: Dict[str, str]) -> Dict[str, Any]:
    words_optional, problems = _raw_schedule_words(fields)
    if any(value is None for value in words_optional):
        return {"valid": False, "problems": problems, "fields": fields}
    words = [int(value) for value in words_optional]
    sequence_before = _u32(fields.get("SEQUENCE_RAW_BEFORE"))
    sequence_after = _u32(fields.get("SEQUENCE_RAW_AFTER"))
    if sequence_before is None or sequence_after is None:
        problems.append("SEQUENCE_RAW_MISSING")
    elif sequence_before != sequence_after or sequence_after & 1:
        problems.append("SEQUENCE_NOT_COHERENT")
    if words[0] != SCHEDULE_MAGIC:
        problems.append("MAGIC_MISMATCH")
    if words[1] != sequence_after:
        problems.append("SEQUENCE_PAYLOAD_MISMATCH")
    state = words[2]
    main_enabled = state & 1
    page = (state >> 8) & 0x3
    enabled_rise = (state >> 16) & 0xFFFF
    if page >= 3:
        problems.append("PAGE_SELECTOR_OUT_OF_RANGE")
    payload = {
        "board": fields.get("BOARD", ""),
        "cycle": _int(fields.get("CYCLE")),
        "elapsed_ms": _int(fields.get("ELAPSED_MS")),
        "host_end_ms": _int(fields.get("HOST_END_MS")),
        "sequence": words[1],
        "main_enabled": main_enabled,
        "page": page,
        "enabled_rise": enabled_rise,
        "enabled_fall": words[3],
        "page_advance": words[4],
        "page_reset": words[5],
        "page2_due": words[6],
        "page2_publish": words[7],
        "words": words,
        "raw_words": [f"0x{word:08X}" for word in words],
    }
    payload["valid"] = not problems
    payload["problems"] = sorted(set(problems))
    return payload


def _max_counter(rows: Sequence[Dict[str, Any]], key: str) -> Optional[int]:
    values = [row.get(key) for row in rows if isinstance(row.get(key), int)]
    return max(values) if values else None


def analyze_text(text: str, source: str = "<text>") -> Dict[str, Any]:
    schedule_rows: List[Dict[str, Any]] = []
    invalid_schedule_rows: List[Dict[str, Any]] = []
    observed_pages: List[int] = []
    done: Dict[str, str] = {}
    config: Dict[str, str] = {}
    cycles: List[Dict[str, str]] = []

    for line in text.splitlines():
        kind, fields = _parse_line(line)
        if kind == "STEP5_F4S_MAIN_SCHEDULE":
            row = _validate_schedule_row(fields)
            if row.get("valid"):
                schedule_rows.append(row)
            else:
                invalid_schedule_rows.append(row)
        elif kind == "STEP5_F4S_MAIN_DIAG":
            page = _int(fields.get("PAGE"))
            if page is not None and 0 <= page < 3 and fields.get("MAIN_F4L_VALID") == "1":
                observed_pages.append(page)
        elif kind == "STEP5_F4S_CYCLE":
            cycles.append(fields)
        elif kind == "STEP5_F4S_CONFIG":
            config = fields
        elif kind == "STEP5_F4S_DONE":
            done = fields

    schedule_rows.sort(key=lambda row: (row.get("host_end_ms") or 0, row.get("sequence") or 0))
    main_enabled_values = sorted({row["main_enabled"] for row in schedule_rows})
    pages = sorted({row["page"] for row in schedule_rows})
    page2_due = _max_counter(schedule_rows, "page2_due") or 0
    page2_publish = _max_counter(schedule_rows, "page2_publish") or 0
    enabled_fall = _max_counter(schedule_rows, "enabled_fall") or 0
    page_advance = _max_counter(schedule_rows, "page_advance") or 0
    page_reset = _max_counter(schedule_rows, "page_reset") or 0

    if not schedule_rows:
        classification = (
            "F4S_SCHEDULE_SCHEMA_INVALID"
            if invalid_schedule_rows
            else "INCONCLUSIVE_NO_SCHEDULE_DATA"
        )
    elif enabled_fall > 0 and page2_due == 0:
        classification = "F4S_MAIN_ENABLE_DISCONTINUITY"
    elif main_enabled_values == [1] and page2_due == 0 and set(pages).issubset({0, 1}):
        classification = "F4S_PAGE2_NOT_SCHEDULED"
    elif page2_due > 0 and page2_publish == 0:
        classification = "F4S_PAGE2_DUE_BUT_NOT_PUBLISHED"
    elif page2_publish > 0 and 2 not in observed_pages:
        classification = "F4S_PAGE2_PUBLISHED_BUT_NOT_OBSERVED"
    elif {0, 1, 2}.issubset(set(observed_pages)) and page2_publish > 0:
        classification = "F4S_FULL_PAGE_ROTATION"
    else:
        classification = "F4S_INCONCLUSIVE"

    causal_classification = classification in {
        "F4S_MAIN_ENABLE_DISCONTINUITY",
        "F4S_PAGE2_NOT_SCHEDULED",
        "F4S_PAGE2_DUE_BUT_NOT_PUBLISHED",
        "F4S_PAGE2_PUBLISHED_BUT_NOT_OBSERVED",
        "F4S_FULL_PAGE_ROTATION",
    }
    last = schedule_rows[-1] if schedule_rows else {}
    result: Dict[str, Any] = {
        "source": source,
        "schema": {
            "magic": f"0x{SCHEDULE_MAGIC:08X}",
            "frame_words": SCHEDULE_WORDS,
            "transport_window": "0x00100BE0..0x00100BFC",
            "non_atomic_with_f4l_frame": True,
        },
        "config": config,
        "done": done,
        "schedule_count": len(schedule_rows),
        "invalid_schedule_count": len(invalid_schedule_rows),
        "invalid_schedule_rows": invalid_schedule_rows,
        "main_enabled_values": main_enabled_values,
        "schedule_pages": pages,
        "observed_f4l_pages": sorted(set(observed_pages)),
        "main_enabled_fall_count": enabled_fall,
        "page_advance_count": page_advance,
        "page_reset_to_summary_count": page_reset,
        "page2_due_count": page2_due,
        "page2_publish_count": page2_publish,
        "last_schedule": last,
        "cycle_count": len(cycles),
        "classification": classification,
        "diagnostic_complete": causal_classification,
        "diagnostic_pass": causal_classification,
        "step5_complete": False,
        "step5_pass": False,
        "merge_approved": False,
    }
    return result


def analyze_file(path: Path) -> Dict[str, Any]:
    return analyze_text(path.read_text(encoding="utf-8", errors="replace"), str(path))


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    result = analyze_file(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "classification": result["classification"],
        "diagnostic_pass": result["diagnostic_pass"],
        "step5_pass": result["step5_pass"],
        "schedule_count": result["schedule_count"],
        "page2_due_count": result["page2_due_count"],
        "page2_publish_count": result["page2_publish_count"],
    }, sort_keys=True))
    return 0 if result["diagnostic_pass"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
