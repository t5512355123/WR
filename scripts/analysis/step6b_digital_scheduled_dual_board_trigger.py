"""Analyze the Step6B-1 digital scheduled dual-board trigger capture."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
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
    for base in (0, 10, 16):
        try:
            return int(value, base)
        except ValueError:
            pass
    return default


def _rows(text: str, prefix: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith(prefix):
            continue
        body = line[len(prefix) :].lstrip(" =")
        rows.append(
            {
                key.upper(): _value(value)
                for key, value in FIELD_RE.findall(body)
            }
        )
    return rows


def _scalar(text: str, prefix: str) -> str | None:
    result: str | None = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith(prefix):
            body = line[len(prefix) :].lstrip(" =")
            result = body.split()[0] if body else None
    return result


def _board(rows: list[dict[str, Any]], role: str) -> list[dict[str, Any]]:
    return [row for row in rows if str(row.get("ROLE", row.get("BOARD", ""))).upper() == role]


def _latest(rows: list[dict[str, Any]], role: str) -> dict[str, Any] | None:
    matches = _board(rows, role)
    return matches[-1] if matches else None


def _healthy(row: dict[str, Any] | None, slave: bool = False) -> bool:
    if row is None:
        return False
    required = (
        _int(row, "READ_VALID") == 1
        and _int(row, "RESET_CHANGED") == 0
        and _int(row, "CAPTURE_HEALTHY") == 1
        and _int(row, "LINK_HEALTHY") == 1
        and _int(row, "STATUS_TIME_VALID") == 1
        and _int(row, "STATUS_PPS_VALID") == 1
        and _int(row, "SNAPSHOT_ACCEPTED") == 1
        and _int(row, "STEP6B_FIXED_TARGET_CYCLES") == 62_500_000
    )
    if slave:
        required = required and _int(row, "PLL_READY") == 1
    return required


def _runtime_invalid(rows: list[dict[str, Any]]) -> bool:
    for row in rows:
        if (
            _int(row, "READ_VALID", 0) != 1
            or _int(row, "RESET_CHANGED", 0) != 0
            or _int(row, "CAPTURE_HEALTHY", 0) != 1
            or _int(row, "LINK_HEALTHY", 0) != 1
            or _int(row, "STATUS_TIME_VALID", 0) != 1
            or _int(row, "STATUS_LINK_OK", 0) != 1
            or _int(row, "STATUS_TM_LINK_UP", 0) != 1
            or (
                str(row.get("ROLE", "")).upper() == "SLAVE"
                and (_int(row, "PLL_READY", 0) != 1 or _int(row, "RX_PATTERN_READY", 0) != 1)
            )
        ):
            return True
    return False


def analyze_text(text: str) -> dict[str, Any]:
    config = _rows(text, "S6B_CONFIG")
    prearm = _rows(text, "S6B_PREARM_SAMPLE")
    prearm_pairs = _rows(text, "S6B_PREARM_PAIR")
    target_verify = _rows(text, "S6B_TARGET_VERIFY")
    arm_verify = _rows(text, "S6B_ARM_VERIFY")
    samples = _rows(text, "S6B_SAMPLE")
    post_loss = _rows(text, "S6B_POST_LOSS_SAMPLE")
    source_writes = _rows(text, "S6B_SOURCE_WRITE")
    target_setup_rows = _rows(text, "S6B_TARGET_SETUP_RESULT")
    arm_result_rows = _rows(text, "S6B_ARM_RESULT")
    gate_result = _scalar(text, "S6B_GATE_RESULT") or "MISSING"
    setup_result = _scalar(text, "S6B_TARGET_SETUP_RESULT") or "MISSING"
    arm_result = _scalar(text, "S6B_ARM_RESULT") or "MISSING"
    capture_rows = _rows(text, "S6B_CAPTURE_RESULT")
    capture_result = _scalar(text, "S6B_CAPTURE_RESULT") or "MISSING"
    done_result = _scalar(text, "S6B_DONE") or capture_result

    master_samples = _board(samples, "MASTER")
    slave_samples = _board(samples, "SLAVE")
    final_master = _latest(samples, "MASTER")
    final_slave = _latest(samples, "SLAVE")
    gate_row = prearm_pairs[-1] if prearm_pairs else {}
    target_tai = _int(gate_row, "TARGET_TAI")
    if target_tai is None:
        for row in (target_setup_rows, arm_result_rows, target_verify, arm_verify, samples):
            if row:
                target_tai = _int(row[-1], "TARGET_TAI")
                if target_tai is not None:
                    break
    target_tai = target_tai if target_tai is not None else -1
    target_cycles = 62_500_000
    for row in (config, samples):
        if row:
            target_cycles = _int(row[-1], "TARGET_CYCLES", target_cycles) or target_cycles
            break

    paired_healthy = max(
        (_int(row, "PAIRED_HEALTHY", 0) or 0 for row in prearm_pairs),
        default=0,
    )
    common_tai_count = max(
        (_int(row, "COMMON_TAI_COUNT", 0) or 0 for row in prearm_pairs),
        default=0,
    )
    prearm_pass = gate_result == "PASS" and paired_healthy >= 5 and common_tai_count >= 3
    setup_pass = setup_result == "PASS"
    arm_pass = arm_result == "PASS"
    runtime_invalid = _runtime_invalid(master_samples + slave_samples)
    stability_loss = (
        capture_result == "INCONCLUSIVE_STEP6A_STABILITY_LOST_BEFORE_TARGET"
        or bool(post_loss)
    )

    master_fire_count = _int(final_master, "STEP6B_FIRE_COUNT") if final_master else None
    slave_fire_count = _int(final_slave, "STEP6B_FIRE_COUNT") if final_slave else None
    master_fired = _int(final_master, "STEP6B_FIRED", 0) if final_master else 0
    slave_fired = _int(final_slave, "STEP6B_FIRED", 0) if final_slave else 0
    master_actual_tai = _int(final_master, "STEP6B_ACTUAL_TAI") if final_master else None
    slave_actual_tai = _int(final_slave, "STEP6B_ACTUAL_TAI") if final_slave else None
    master_actual_cycles = _int(final_master, "STEP6B_ACTUAL_CYCLES") if final_master else None
    slave_actual_cycles = _int(final_slave, "STEP6B_ACTUAL_CYCLES") if final_slave else None
    post_fire_samples = _int(capture_rows[-1], "POST_FIRE_SAMPLES", -1) if capture_rows else -1
    timestamp_delta_ticks: int | None = None
    if None not in (master_actual_tai, slave_actual_tai, master_actual_cycles, slave_actual_cycles):
        timestamp_delta_ticks = (
            (slave_actual_tai - master_actual_tai) * 125_000_000
            + slave_actual_cycles
            - master_actual_cycles
        )
    capture_delta = _int(_rows(text, "S6B_CAPTURE_RESULT")[-1], "DIGITAL_TRIGGER_DELTA_TICKS") if _rows(text, "S6B_CAPTURE_RESULT") else None
    if timestamp_delta_ticks is None and capture_delta is not None:
        timestamp_delta_ticks = capture_delta
    timestamp_delta_ns = timestamp_delta_ticks * 8 if timestamp_delta_ticks is not None else None

    formal_pass = (
        prearm_pass
        and setup_pass
        and arm_pass
        and not runtime_invalid
        and not stability_loss
        and master_fired == 1
        and slave_fired == 1
        and master_fire_count == 1
        and slave_fire_count == 1
        and master_actual_tai == target_tai
        and slave_actual_tai == target_tai
        and master_actual_cycles == target_cycles
        and slave_actual_cycles == target_cycles
        and timestamp_delta_ticks == 0
        and post_fire_samples >= 3
    )

    if not prearm_pass:
        classification = gate_result if gate_result != "MISSING" else "INCONCLUSIVE_STEP6A_PRECONDITION_NOT_RECOVERED"
        verdict = "INCONCLUSIVE"
    elif not setup_pass:
        classification = setup_result
        verdict = "INCONCLUSIVE"
    elif not arm_pass:
        classification = arm_result
        verdict = "INCONCLUSIVE"
    elif formal_pass:
        classification = "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER"
        verdict = "PASS"
    elif runtime_invalid or stability_loss:
        classification = (
            "INCONCLUSIVE_STEP6A_STABILITY_LOST_BEFORE_TARGET"
            if stability_loss
            else "INCONCLUSIVE_RUNTIME_STATE_CHANGED"
        )
        verdict = "INCONCLUSIVE"
    elif master_fire_count is not None and master_fire_count > 1 or slave_fire_count is not None and slave_fire_count > 1:
        classification = "FAIL_TRIGGER_ONE_SHOT_VIOLATION"
        verdict = "FAIL"
    elif master_fired != slave_fired:
        classification = "FAIL_ONE_SIDED_SCHEDULED_TRIGGER"
        verdict = "FAIL"
    elif master_fired == 1 and slave_fired == 1 and timestamp_delta_ticks != 0:
        classification = "FAIL_SCHEDULED_TRIGGER_TIMESTAMP_MISMATCH"
        verdict = "FAIL"
    elif (
        master_fired == 1
        and slave_fired == 1
        and (
            master_actual_tai != target_tai
            or slave_actual_tai != target_tai
            or master_actual_cycles != target_cycles
            or slave_actual_cycles != target_cycles
        )
    ):
        classification = "FAIL_COMMON_TRIGGER_TARGET_MISS"
        verdict = "FAIL"
    else:
        classification = capture_result if capture_result != "MISSING" else "FAIL_COMMON_TRIGGER_TARGET_MISS"
        verdict = "FAIL" if classification.startswith("FAIL_") else "INCONCLUSIVE"

    return {
        "format": "step6b-digital-scheduled-dual-board-trigger-v1",
        "classification": classification,
        "verdict": verdict,
        "result": classification,
        "step6a": "PASS" if prearm_pass else "NOT_PASS",
        "step6b_1_digital_scheduled_trigger": "PASS" if formal_pass else "NOT_PASS",
        "step6b_physical_edge": "NOT_EVALUATED",
        "gate_result": gate_result,
        "target_setup_result": setup_result,
        "arm_result": arm_result,
        "capture_result": capture_result,
        "done_result": done_result,
        "paired_healthy": paired_healthy,
        "common_tai_count": common_tai_count,
        "target_tai": target_tai,
        "target_cycles": target_cycles,
        "master_fire_count": master_fire_count,
        "slave_fire_count": slave_fire_count,
        "master_fired": master_fired,
        "slave_fired": slave_fired,
        "master_actual_tai": master_actual_tai,
        "slave_actual_tai": slave_actual_tai,
        "master_actual_cycles": master_actual_cycles,
        "slave_actual_cycles": slave_actual_cycles,
        "target_match": "PASS" if formal_pass else "FAIL",
        "digital_trigger_delta_ticks": timestamp_delta_ticks,
        "digital_trigger_delta_ns": timestamp_delta_ns,
        "post_fire_samples": post_fire_samples,
        "runtime_invalid": runtime_invalid,
        "stability_loss": stability_loss,
        "program_source_write_count": len(source_writes),
        "prearm_sample_count": len(prearm),
        "prearm_pair_count": len(prearm_pairs),
        "target_verify_count": len(target_verify),
        "arm_verify_count": len(arm_verify),
        "sample_count": len(samples),
        "post_loss_sample_count": len(post_loss),
        "master_samples": master_samples,
        "slave_samples": slave_samples,
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
