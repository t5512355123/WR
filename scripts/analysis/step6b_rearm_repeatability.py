"""Analyze the Step6B digital scheduler re-arm repeatability capture."""

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
    for base in (0, 10, 16):
        try:
            return int(value, base)
        except ValueError:
            pass
    return default


def _text(row: dict[str, Any], key: str, default: str = "") -> str:
    value = row.get(key, default)
    return str(value)


def _result(text: str) -> tuple[str, dict[str, Any]]:
    rows = _rows(text, "S6B_REARM_RESULT")
    row = rows[-1] if rows else {}
    result = "MISSING"
    for line in reversed(text.splitlines()):
        line = line.strip()
        if line.startswith("S6B_REARM_RESULT="):
            result = line.split("=", 1)[1].split()[0]
            break
    return result, row


def _source_writes(text: str) -> list[tuple[str, int | None, int | None, int | None]]:
    rows = _rows(text, "S6B_SOURCE_WRITE")
    result: list[tuple[str, int | None, int | None, int | None]] = []
    for row in rows:
        role = _text(row, "BOARD", _text(row, "ROLE")).upper()
        result.append(
            (
                role,
                _int(row, "INDEX"),
                _int(row, "VALUE"),
                _int(row, "OK"),
            )
        )
    return result


def analyze_text(text: str) -> dict[str, Any]:
    result, row = _result(text)
    writes = _source_writes(text)
    new_target = _int(row, "NEW_TARGET_TAI")
    target_cycles = _int(row, "TARGET_CYCLES")
    source_sequence = [
        {"board": board, "index": index, "value": value, "ok": ok}
        for board, index, value, ok in writes
    ]
    expected_sequence_ok = False
    if len(writes) == 6 and new_target is not None:
        expected = [
            ("MASTER", 68, 0),
            ("SLAVE", 68, 0),
            ("MASTER", 67, new_target),
            ("SLAVE", 67, new_target),
            ("MASTER", 68, 1),
            ("SLAVE", 68, 1),
        ]
        expected_sequence_ok = all(
            (board, index, value) == wanted and ok == 1
            for (board, index, value, ok), wanted in zip(writes, expected)
        )

    pre_pairs = _int(row, "PRE_GATE_PAIRS", 0) or 0
    pre_common = _int(row, "PRE_COMMON_TAI_COUNT", 0) or 0
    post_pairs = _int(row, "POST_DEARM_GATE_PAIRS", 0) or 0
    post_common = _int(row, "POST_DEARM_COMMON_TAI_COUNT", 0) or 0
    coherence = _int(row, "COHERENCE_VIOLATION", 1) or 0
    post_fire = _int(row, "POST_FIRE_SAMPLES", 0) or 0
    master_count = _int(row, "MASTER_FIRE_COUNT")
    slave_count = _int(row, "SLAVE_FIRE_COUNT")
    master_actual_tai = _int(row, "MASTER_ACTUAL_TAI")
    slave_actual_tai = _int(row, "SLAVE_ACTUAL_TAI")
    master_actual_cycles = _int(row, "MASTER_ACTUAL_CYCLES")
    slave_actual_cycles = _int(row, "SLAVE_ACTUAL_CYCLES")
    delta_ticks = _int(row, "SECOND_TRIGGER_DELTA_TICKS")
    formal_pass = (
        result == "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER_REARM_REPEATABILITY"
        and pre_pairs >= 3
        and pre_common >= 2
        and post_pairs >= 2
        and post_common >= 2
        and coherence == 0
        and _text(row, "PRE_GATE_RESULT") == "PASS"
        and _text(row, "INITIAL_RESULT") == "PASS"
        and _text(row, "DEARM_RESULT") == "PASS"
        and _text(row, "POST_DEARM_GATE_RESULT") == "PASS"
        and _text(row, "TARGET_RESULT") == "PASS"
        and _text(row, "ARM_RESULT") == "PASS"
        and expected_sequence_ok
        and post_fire >= 3
        and master_count == 2
        and slave_count == 2
        and new_target is not None
        and target_cycles == 62_500_000
        and master_actual_tai == new_target
        and slave_actual_tai == new_target
        and master_actual_cycles == 62_500_000
        and slave_actual_cycles == 62_500_000
        and delta_ticks == 0
    )

    if formal_pass:
        classification = "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER_REARM_REPEATABILITY"
        verdict = "PASS"
    elif result == "MISSING":
        classification = "INCONCLUSIVE_MISSING_REARM_OBSERVER_RESULT"
        verdict = "INCONCLUSIVE"
    elif result.startswith("FAIL_"):
        classification = result
        verdict = "FAIL"
    elif result.startswith("INCONCLUSIVE_"):
        classification = result
        verdict = "INCONCLUSIVE"
    else:
        classification = "INCONCLUSIVE_REARM_FORMAL_CONTRACT_NOT_MET"
        verdict = "INCONCLUSIVE"

    return {
        "format": "step6b-rearm-repeatability-v1",
        "classification": classification,
        "verdict": verdict,
        "step6a": "PASS" if formal_pass else "NOT_PASS",
        "step6b_1_digital_scheduled_trigger": "PASS" if formal_pass else "NOT_PASS",
        "step6b_physical_edge": "NOT_EVALUATED",
        "observer_result": result,
        "pre_gate_pairs": pre_pairs,
        "pre_common_tai_count": pre_common,
        "post_dearm_gate_pairs": post_pairs,
        "post_dearm_common_tai_count": post_common,
        "coherence_violation": coherence,
        "t0": _int(row, "T0"),
        "new_target_tai": new_target,
        "target_cycles": target_cycles,
        "pre_gate_result": _text(row, "PRE_GATE_RESULT"),
        "initial_result": _text(row, "INITIAL_RESULT"),
        "dearm_result": _text(row, "DEARM_RESULT"),
        "post_dearm_gate_result": _text(row, "POST_DEARM_GATE_RESULT"),
        "target_result": _text(row, "TARGET_RESULT"),
        "arm_result": _text(row, "ARM_RESULT"),
        "source_sequence": source_sequence,
        "source_sequence_ok": expected_sequence_ok,
        "write_count": len(writes),
        "arm0_write_master": _int(row, "ARM0_WRITE_MASTER", 0),
        "arm0_write_slave": _int(row, "ARM0_WRITE_SLAVE", 0),
        "target_write_master": _int(row, "TARGET_WRITE_MASTER", 0),
        "target_write_slave": _int(row, "TARGET_WRITE_SLAVE", 0),
        "arm1_write_master": _int(row, "ARM1_WRITE_MASTER", 0),
        "arm1_write_slave": _int(row, "ARM1_WRITE_SLAVE", 0),
        "capture_samples": _int(row, "CAPTURE_SAMPLES", 0),
        "post_fire_samples": post_fire,
        "master_fire_count": master_count,
        "slave_fire_count": slave_count,
        "master_actual_tai": master_actual_tai,
        "slave_actual_tai": slave_actual_tai,
        "master_actual_cycles": master_actual_cycles,
        "slave_actual_cycles": slave_actual_cycles,
        "second_trigger_delta_ticks": delta_ticks,
        "second_trigger_delta_ns": _int(row, "SECOND_TRIGGER_DELTA_NS"),
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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
