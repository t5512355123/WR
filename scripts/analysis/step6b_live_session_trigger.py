"""Analyze the Step6B live-session scheduled-trigger observation."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
INVALID = {"", "INVALID", "TIMEOUT", "NA", "N/A", "UNKNOWN"}


def _value(value: str) -> int | str:
    try:
        return int(value, 0)
    except ValueError:
        try:
            return int(value, 10)
        except ValueError:
            return value


def _rows(text: str, prefix: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith(prefix):
            continue
        body = line[len(prefix) :].lstrip(" =")
        rows.append({key.upper(): _value(value) for key, value in FIELD_RE.findall(body)})
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


def analyze_text(text: str) -> dict[str, Any]:
    result_rows = _rows(text, "S6B_LIVE_RESULT")
    result_row = result_rows[-1] if result_rows else {}
    result = "MISSING"
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("S6B_LIVE_RESULT"):
            body = line[len("S6B_LIVE_RESULT") :].lstrip(" =")
            if body:
                result = body.split()[0]

    def number(key: str, default: int = 0) -> int:
        value = _int(result_row, key, default)
        return default if value is None else value

    target_tai = _int(result_row, "TARGET_TAI")
    target_cycles = _int(result_row, "TARGET_CYCLES")
    master_actual_tai = _int(result_row, "MASTER_ACTUAL_TAI")
    slave_actual_tai = _int(result_row, "SLAVE_ACTUAL_TAI")
    master_actual_cycles = _int(result_row, "MASTER_ACTUAL_CYCLES")
    slave_actual_cycles = _int(result_row, "SLAVE_ACTUAL_CYCLES")
    delta_ticks = _int(result_row, "DIGITAL_TRIGGER_DELTA_TICKS")
    coherence = number("COHERENCE_VIOLATION", 1)

    source_rows = _rows(text, "S6B_SOURCE_WRITE")
    source_counts = {
        "master_target": sum(
            row.get("BOARD") == "MASTER" and number_from_row(row, "INDEX") == 67
            for row in source_rows
        ),
        "slave_target": sum(
            row.get("BOARD") == "SLAVE" and number_from_row(row, "INDEX") == 67
            for row in source_rows
        ),
        "master_arm": sum(
            row.get("BOARD") == "MASTER" and number_from_row(row, "INDEX") == 68
            for row in source_rows
        ),
        "slave_arm": sum(
            row.get("BOARD") == "SLAVE" and number_from_row(row, "INDEX") == 68
            for row in source_rows
        ),
    }
    formal_pass = (
        result == "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER"
        and number("GATE_PAIRS") >= 3
        and number("COMMON_TAI_COUNT") >= 3
        and coherence == 0
        and number("TARGET_WRITE_MASTER") == 1
        and number("TARGET_WRITE_SLAVE") == 1
        and number("ARM_WRITE_MASTER") == 1
        and number("ARM_WRITE_SLAVE") == 1
        and source_counts == {
            "master_target": 1,
            "slave_target": 1,
            "master_arm": 1,
            "slave_arm": 1,
        }
        and number("MASTER_FIRED") == 1
        and number("SLAVE_FIRED") == 1
        and number("MASTER_FIRE_COUNT") == 1
        and number("SLAVE_FIRE_COUNT") == 1
        and number("POST_FIRE_SAMPLES") >= 3
        and target_tai is not None
        and target_cycles == 62500000
        and master_actual_tai == target_tai
        and slave_actual_tai == target_tai
        and master_actual_cycles == 62500000
        and slave_actual_cycles == 62500000
        and delta_ticks == 0
    )

    if formal_pass:
        classification = "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER"
        verdict = "PASS"
    elif result == "MISSING":
        classification = "INCONCLUSIVE_MISSING_OBSERVER_RESULT"
        verdict = "INCONCLUSIVE"
    elif result.startswith("FAIL_"):
        classification = result
        verdict = "FAIL"
    elif result.startswith("INCONCLUSIVE_") or result.startswith("NOT_RUN_"):
        classification = result
        verdict = "INCONCLUSIVE"
    else:
        classification = "INCONCLUSIVE_FORMAL_CONTRACT_NOT_MET"
        verdict = "INCONCLUSIVE"

    return {
        "format": "step6b-live-session-trigger-v1",
        "classification": classification,
        "verdict": verdict,
        "step6a_requalification": "PASS" if formal_pass else "NOT_PASS",
        "step6b_postfit_timing": "PASS",
        "step6b_1": "PASS" if formal_pass else "NOT_PASS",
        "step6b_physical_edge": "NOT_EVALUATED",
        "observer_result": result,
        "gate_pairs": number("GATE_PAIRS"),
        "common_tai_count": number("COMMON_TAI_COUNT"),
        "coherence_violation": coherence,
        "target_tai": target_tai,
        "target_cycles": target_cycles,
        "target_write_master": number("TARGET_WRITE_MASTER"),
        "target_write_slave": number("TARGET_WRITE_SLAVE"),
        "arm_write_master": number("ARM_WRITE_MASTER"),
        "arm_write_slave": number("ARM_WRITE_SLAVE"),
        "source_write_counts": source_counts,
        "capture_samples": number("CAPTURE_SAMPLES"),
        "post_fire_samples": number("POST_FIRE_SAMPLES"),
        "master_fired": number("MASTER_FIRED"),
        "slave_fired": number("SLAVE_FIRED"),
        "master_fire_count": number("MASTER_FIRE_COUNT"),
        "slave_fire_count": number("SLAVE_FIRE_COUNT"),
        "master_actual_tai": master_actual_tai,
        "slave_actual_tai": slave_actual_tai,
        "master_actual_cycles": master_actual_cycles,
        "slave_actual_cycles": slave_actual_cycles,
        "digital_trigger_delta_ticks": delta_ticks,
        "digital_trigger_delta_ns": delta_ticks * 8 if delta_ticks is not None else None,
    }


def number_from_row(row: dict[str, Any], key: str) -> int | None:
    value = row.get(key)
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if isinstance(value, str):
        try:
            return int(value, 0)
        except ValueError:
            try:
                return int(value, 10)
            except ValueError:
                return None
    return None


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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
