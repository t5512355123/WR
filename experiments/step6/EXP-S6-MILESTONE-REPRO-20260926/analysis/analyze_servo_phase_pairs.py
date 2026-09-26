#!/usr/bin/env python3
"""Summarize source-mapped, counter-bracketed Step 6 servo observations."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


SAMPLE_PREFIX = "S6_SERVO_PAIR_SAMPLE "
FIELD_RE = re.compile(r"\b([A-Z][A-Z0-9_]*)=([^\s]+)")


def parse_rows(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with path.open("r", encoding="utf-8", errors="replace") as stream:
        for line in stream:
            if line.startswith(SAMPLE_PREFIX):
                rows.append(dict(FIELD_RE.findall(line)))
    return rows


def int_field(row: dict[str, str], key: str) -> int | None:
    value = row.get(key, "")
    if value in {"", "NA", "INVALID", "TIMEOUT"}:
        return None
    try:
        return int(value, 10)
    except ValueError:
        return None


def summarize(path: Path) -> dict[str, object]:
    rows = parse_rows(path)
    coherent = [row for row in rows if row.get("UCNT_BRACKET_STABLE") == "1"]
    pairs = [row for row in rows if row.get("PAIR_VALID") == "1"]
    match_tests = [row for row in pairs if row.get("SETPOINT_CKO_MATCH") in {"0", "1"}]
    matches = [row for row in match_tests if row.get("SETPOINT_CKO_MATCH") == "1"]
    post_action = [row for row in pairs if row.get("POST_ACTION_RESPONSE") == "1"]
    cko_values = [
        value
        for row in coherent
        if (value := int_field(row, "CKO_PS")) is not None
    ]
    cko_deltas = [
        value
        for row in post_action
        if (value := int_field(row, "CKO_DELTA_PS")) is not None
    ]
    valid = [row for row in rows if row.get("READS_VALID") == "1"]
    time_valid = [row for row in rows if row.get("STATUS_TIME_VALID") == "1"]
    reset_changed = [row for row in rows if row.get("RESET_CHANGED") == "1"]

    if len(coherent) < 3:
        verdict = "INCONCLUSIVE_TOO_FEW_COUNTER_STABLE_ROWS"
    elif not pairs:
        verdict = "INCONCLUSIVE_NO_ADJACENT_UPDATE_PAIRS"
    else:
        verdict = "DESCRIPTIVE_ONLY_NO_STEP6_PASS_CLAIM"

    return {
        "source_log": str(path),
        "sample_rows": len(rows),
        "reads_valid": len(valid),
        "counter_stable_rows": len(coherent),
        "adjacent_update_pairs": len(pairs),
        "setpoint_offset_match_tests": len(match_tests),
        "setpoint_offset_matches": len(matches),
        "post_action_offset_samples": len(post_action),
        "post_action_offset_delta_ps": cko_deltas,
        "cko_ps_min": min(cko_values) if cko_values else None,
        "cko_ps_max": max(cko_values) if cko_values else None,
        "cko_abs_lt_60ps_rows": sum(abs(value) < 60 for value in cko_values),
        "time_valid_rows": len(time_valid),
        "reset_changed_rows": len(reset_changed),
        "verdict": verdict,
        "scope_note": (
            "Counter-stable diagnostic pairs only; descriptive servo evidence, "
            "not Step 6A or Step 6 milestone acceptance."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    result = summarize(args.log)
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.json:
        args.json.write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    return 0 if result["sample_rows"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
