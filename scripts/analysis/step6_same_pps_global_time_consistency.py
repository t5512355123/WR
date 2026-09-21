"""Analyze Step6A-2 same-PPS Global-Time consistency by shared TAI labels."""

from __future__ import annotations

import argparse
import collections
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
GATE_RE = re.compile(r"^S6A2_GATE_PAIR\s+(?P<body>.*)$")
SAMPLE_RE = re.compile(r"^S6A2_SAMPLE\s+(?P<body>.*)$")
GATE_RESULT_RE = re.compile(r"^S6A2_GATE_RESULT=(?P<value>[^\s]+)")
CAPTURE_RESULT_RE = re.compile(r"^S6A2_CAPTURE_RESULT=(?P<value>[^\s]+)")
INVALID = {"", "INVALID", "TIMEOUT", "NA", "N/A", "UNKNOWN"}


def _value(text: str) -> int | str:
    try:
        if text.lower().startswith("0x"):
            return int(text, 16)
        return int(text, 10)
    except ValueError:
        return text


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
            try:
                return int(value, 16)
            except ValueError:
                return default


def _parse_rows(text: str, pattern: re.Pattern[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = pattern.match(line.strip())
        if not match:
            continue
        rows.append(
            {
                key.upper(): _value(value)
                for key, value in FIELD_RE.findall(match.group("body"))
            }
        )
    return rows


def _scalar(text: str, pattern: re.Pattern[str]) -> str | None:
    result: str | None = None
    for line in text.splitlines():
        match = pattern.match(line.strip())
        if match:
            result = match.group("value")
    return result


def _board_rows(rows: list[dict[str, Any]], role: str) -> list[dict[str, Any]]:
    return [
        row for row in rows if str(row.get("BOARD", "")).upper() == role
    ]


def _accepted(row: dict[str, Any]) -> bool:
    return (
        _int(row, "READ_VALID") == 1
        and _int(row, "CAPTURE_HEALTHY") == 1
        and _int(row, "SNAPSHOT_ACCEPTED") == 1
        and _int(row, "SNAPSHOT_VALID") == 1
        and _int(row, "SNAPSHOT_TIME_VALID") == 1
        and _int(row, "SNAPSHOT_PPS_VALID") == 1
        and (_int(row, "SNAPSHOT_CYCLES") is not None)
        and 0 <= _int(row, "SNAPSHOT_CYCLES") <= 124_999_999
    )


def _runtime_invalid(rows: list[dict[str, Any]]) -> bool:
    return any(
        _int(row, "READ_VALID", 0) != 1
        or _int(row, "CAPTURE_HEALTHY", 0) != 1
        or _int(row, "RESET_CHANGED", 0) == 1
        or _int(row, "STATUS_TM_LINK_UP", 0) != 1
        or _int(row, "STATUS_LINK_OK", 0) != 1
        or (
            str(row.get("BOARD", "")).upper() == "SLAVE"
            and _int(row, "RX_PATTERN_READY", 0) != 1
        )
        for row in rows
    )


def _map_snapshots(rows: list[dict[str, Any]]) -> tuple[dict[int, int], bool]:
    result: dict[int, int] = {}
    coherence_violation = False
    for row in rows:
        if not _accepted(row):
            continue
        tai = _int(row, "SNAPSHOT_TAI")
        cycles = _int(row, "SNAPSHOT_CYCLES")
        if tai is None or cycles is None:
            continue
        previous = result.get(tai)
        if previous is not None and previous != cycles:
            coherence_violation = True
        result[tai] = cycles
    return result, coherence_violation


def _tai_offset(master: dict[int, int], slave: dict[int, int]) -> int | None:
    if not master or not slave or set(master) & set(slave):
        return None
    candidates = collections.Counter(
        slave_tai - master_tai
        for master_tai in master
        for slave_tai in slave
        if abs(slave_tai - master_tai) <= 2
    )
    if not candidates:
        return None
    offset, count = candidates.most_common(1)[0]
    if offset in (-1, 1) and count >= min(3, len(master), len(slave)):
        return offset
    return None


def analyze_text(text: str) -> dict[str, Any]:
    gates = _parse_rows(text, GATE_RE)
    samples = _parse_rows(text, SAMPLE_RE)
    gate_result = _scalar(text, GATE_RESULT_RE) or "MISSING"
    capture_result = _scalar(text, CAPTURE_RESULT_RE) or "MISSING"
    master_rows = _board_rows(samples, "MASTER")
    slave_rows = _board_rows(samples, "SLAVE")
    master_map, master_coherence = _map_snapshots(master_rows)
    slave_map, slave_coherence = _map_snapshots(slave_rows)
    common_tai = sorted(set(master_map) & set(slave_map))
    pairs = {
        str(tai): {
            "master_cycles": master_map[tai],
            "slave_cycles": slave_map[tai],
            "delta_ticks": slave_map[tai] - master_map[tai],
            "delta_ns": (slave_map[tai] - master_map[tai]) * 8,
        }
        for tai in common_tai
    }
    deltas = [pair["delta_ticks"] for pair in pairs.values()]
    exact_count = sum(delta == 0 for delta in deltas)
    max_abs_delta = max((abs(delta) for delta in deltas), default=0)
    runtime_invalid = _runtime_invalid(samples) or not master_rows or not slave_rows
    stability_loss = any(
        _int(row, "STATUS_TIME_VALID", 1) != 1
        or _int(row, "SNAPSHOT_VALID", 1) != 1
        for row in samples
    )
    coherence_violation = master_coherence or slave_coherence
    tai_offset = _tai_offset(master_map, slave_map)
    mismatch_confirmed = sum(delta != 0 for delta in deltas) >= 3

    if gate_result != "PASS":
        classification = (
            gate_result
            if gate_result != "MISSING"
            else "INCONCLUSIVE_STEP6A2_PRECONDITION_CHANGED"
        )
        verdict = "INCONCLUSIVE"
        failure_class = "STEP6A2_PRECONDITION_NOT_STABLE"
        step6a1 = "NOT_EVALUATED"
        step6a2 = "NOT_EVALUATED"
    elif runtime_invalid:
        classification = "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
        verdict = "INCONCLUSIVE"
        failure_class = "RUNTIME_LINK_RESET_OR_TRANSPORT_INVALID"
        step6a1 = "NOT_PASS"
        step6a2 = "NOT_EVALUATED"
    elif coherence_violation:
        classification = "INCONCLUSIVE_SNAPSHOT_COHERENCE_VIOLATION"
        verdict = "INCONCLUSIVE"
        failure_class = "SAME_TAI_REPORTED_WITH_DIFFERENT_CYCLES_ON_ONE_BOARD"
        step6a1 = "PASS"
        step6a2 = "NOT_EVALUATED"
    elif stability_loss:
        classification = "FAIL_STEP6A1_STABILITY_REGRESSION_DURING_STEP6A2"
        verdict = "FAIL"
        failure_class = "GLOBAL_TIME_VALIDITY_LOST_DURING_SAME_PPS_CAPTURE"
        step6a1 = "FAIL"
        step6a2 = "FAIL"
    elif len(common_tai) >= 5 and exact_count == len(common_tai):
        classification = "PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY"
        verdict = "PASS"
        failure_class = ""
        step6a1 = "PASS"
        step6a2 = "PASS"
    elif mismatch_confirmed:
        classification = "FAIL_SAME_PPS_GLOBAL_TIME_OFFSET"
        verdict = "FAIL"
        failure_class = "MASTER_SLAVE_SNAPSHOT_CYCLE_MISMATCH"
        step6a1 = "PASS"
        step6a2 = "FAIL"
    elif tai_offset is not None and not common_tai:
        classification = "FAIL_GLOBAL_TIME_TAI_EPOCH_OFFSET"
        verdict = "FAIL"
        failure_class = "MASTER_SLAVE_TAI_LABEL_OFFSET"
        step6a1 = "PASS"
        step6a2 = "FAIL"
    elif len(common_tai) < 5:
        classification = "INCONCLUSIVE_INSUFFICIENT_COMMON_PPS_LABELS"
        verdict = "INCONCLUSIVE"
        failure_class = "COMMON_TAI_LABEL_COUNT_BELOW_FIVE"
        step6a1 = "PASS"
        step6a2 = "NOT_EVALUATED"
    else:
        classification = capture_result if capture_result != "MISSING" else "INCONCLUSIVE_SAME_PPS_NOT_CONFIRMED"
        verdict = "INCONCLUSIVE"
        failure_class = "SAME_PPS_MATCH_GATE_NOT_CONFIRMED"
        step6a1 = "PASS"
        step6a2 = "NOT_EVALUATED"

    passed = classification == "PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY"
    return {
        "format": "step6-same-pps-global-time-consistency-v1",
        "gate_result": gate_result,
        "capture_result": capture_result,
        "classification": classification,
        "verdict": verdict,
        "failure_class": failure_class,
        "step6a_1": step6a1,
        "step6a_2": step6a2,
        "step6a_global_time": "PASS" if passed else "NOT_PASS",
        "step6b": "NOT_RUN",
        "gate_pair_count": len(gates),
        "sample_count": len(samples),
        "runtime_invalid": runtime_invalid,
        "stability_loss": stability_loss,
        "coherence_violation": coherence_violation,
        "master_label_count": len(master_map),
        "slave_label_count": len(slave_map),
        "common_tai_count": len(common_tai),
        "common_tai_labels": common_tai,
        "pairs": pairs,
        "exact_match_count": exact_count,
        "unique_delta_ticks": sorted(set(deltas)),
        "max_abs_delta_ticks": max_abs_delta,
        "max_abs_delta_ns": max_abs_delta * 8,
        "tai_offset": tai_offset,
        "master": {"rows": master_rows},
        "slave": {"rows": slave_rows},
        "rows": samples,
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
