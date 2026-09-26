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


def hex_field(row: dict[str, str], key: str) -> int | None:
    value = row.get(key, "")
    if value in {"", "NA", "INVALID", "TIMEOUT"}:
        return None
    try:
        return int(value, 16)
    except ValueError:
        return None


def signed32_delta(new_value: int, old_value: int) -> int:
    delta = (new_value - old_value) & 0xFFFFFFFF
    return delta - 0x100000000 if delta >= 0x80000000 else delta


def summarize(path: Path) -> dict[str, object]:
    rows = parse_rows(path)
    coherent = [
        row
        for row in rows
        if row.get("COHERENT", row.get("UCNT_BRACKET_STABLE")) == "1"
        and row.get("READS_VALID", "1") == "1"
    ]
    cko_values = [
        value
        for row in coherent
        if (value := int_field(row, "CKO_PS")) is not None
    ]

    # Reconstruct unique published updates from counter identity so repeated
    # host samples do not erase the preceding action or inflate pair counts.
    adjacent_pairs = 0
    update_gaps = 0
    payload_conflicts = 0
    match_tests = 0
    matches = 0
    post_action_deltas: list[int] = []
    previous: tuple[int, int, int, int] | None = None
    previous_action = False
    for row in coherent:
        count = hex_field(row, "UCNT_AFTER")
        cko = int_field(row, "CKO_PS")
        setp = int_field(row, "SETP_PS")
        state = int_field(row, "SERVO_STATE")
        if None in (count, cko, setp, state):
            continue
        assert count is not None and cko is not None and setp is not None and state is not None
        current = (count, state, cko, setp)
        action = False
        if previous is not None:
            prior_count, _prior_state, prior_cko, prior_setp = previous
            update_delta = (count - prior_count) & 0xFFFFFFFF
            if update_delta == 0:
                if current[1:] != previous[1:]:
                    payload_conflicts += 1
                continue
            if update_delta == 1:
                adjacent_pairs += 1
                setp_delta = signed32_delta(setp, prior_setp)
                cko_delta = signed32_delta(cko, prior_cko)
                if state == 5:
                    match_tests += 1
                    action = abs(setp_delta - cko) <= 1
                    if action:
                        matches += 1
                if previous_action:
                    post_action_deltas.append(cko_delta)
            else:
                update_gaps += update_delta - 1
        previous = current
        previous_action = action

    valid = [row for row in rows if row.get("READS_VALID") == "1"]
    time_valid = [row for row in rows if row.get("STATUS_TIME_VALID") == "1"]
    reset_changed = [row for row in rows if row.get("RESET_CHANGED") == "1"]

    if len(coherent) < 3:
        verdict = "INCONCLUSIVE_TOO_FEW_COUNTER_STABLE_ROWS"
    elif not adjacent_pairs:
        verdict = "INCONCLUSIVE_NO_ADJACENT_UPDATE_PAIRS"
    else:
        verdict = "DESCRIPTIVE_ONLY_NO_STEP6_PASS_CLAIM"

    return {
        "source_log": str(path),
        "sample_rows": len(rows),
        "reads_valid": len(valid),
        "counter_stable_rows": len(coherent),
        "adjacent_update_pairs": adjacent_pairs,
        "skipped_servo_updates": update_gaps,
        "same_counter_payload_conflicts": payload_conflicts,
        "setpoint_offset_match_tests": match_tests,
        "setpoint_offset_matches": matches,
        "post_action_offset_samples": len(post_action_deltas),
        "post_action_offset_delta_ps": post_action_deltas,
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
