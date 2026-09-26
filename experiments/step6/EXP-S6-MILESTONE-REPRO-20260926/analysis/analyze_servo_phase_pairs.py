#!/usr/bin/env python3
"""Summarize source-mapped, counter-bracketed Step 6 servo observations."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


SAMPLE_PREFIX = "S6_SERVO_PAIR_SAMPLE "
F4L_PREFIX = "S6_F4L_PHASE_SAMPLE "
FIELD_RE = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*)=([^\s]+)")


def parse_rows(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with path.open("r", encoding="utf-8", errors="replace") as stream:
        for line in stream:
            if line.startswith(SAMPLE_PREFIX):
                rows.append(dict(FIELD_RE.findall(line)))
    return rows


def parse_f4l_rows(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with path.open("r", encoding="utf-8", errors="replace") as stream:
        for line in stream:
            if line.startswith(F4L_PREFIX):
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


def hex_u64_fields(row: dict[str, str], high_key: str, low_key: str) -> int | None:
    high = hex_field(row, high_key)
    low = hex_field(row, low_key)
    if high is None or low is None:
        return None
    return (high << 32) | low


def signed32_delta(new_value: int, old_value: int) -> int:
    delta = (new_value - old_value) & 0xFFFFFFFF
    return delta - 0x100000000 if delta >= 0x80000000 else delta


def summarize(path: Path) -> dict[str, object]:
    rows = parse_rows(path)
    f4l_rows = parse_f4l_rows(path)
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
    mu_values: list[int] = []
    dms_values: list[int] = []
    asym_values: list[int] = []
    dms_vs_raw_mean_deltas: list[int] = []
    inferred_timestamp_deltas: list[int] = []
    for row in coherent:
        mu = hex_u64_fields(row, "MU_HI", "MU_LO")
        dms = hex_u64_fields(row, "DMS_HI", "DMS_LO")
        asym = int_field(row, "ASYM_PS")
        cko = int_field(row, "CKO_PS")
        if None not in (mu, dms, asym):
            assert mu is not None and dms is not None and asym is not None
            mu_values.append(mu)
            dms_values.append(dms)
            asym_values.append(asym)
            # MU is rawDelayMM; DMS is corrected delayMS. Their difference
            # includes timestamp-calibration effects and is not an identity.
            dms_vs_raw_mean_deltas.append(dms - ((mu >> 1) + asym))
            if cko is not None:
                # Source equation: CKO = (t1 - t2) + DMS. This inferred
                # timestamp difference is descriptive, not an atomic pair.
                inferred_timestamp_deltas.append(cko - dms)

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
    valid_f4l = [row for row in f4l_rows if row.get("FRAME_VALID") == "1"]
    same_servo_update: list[dict[str, str]] = []
    for row in valid_f4l:
        before = hex_field(row, "SERVO_UCNT_BEFORE")
        after = hex_field(row, "SERVO_UCNT_AFTER")
        pair = int_field(row, "PAIR_UCNT")
        if (
            row.get("SERVO_UPDATE_MATCH") == "1"
            and before is not None
            and before == after == pair
        ):
            same_servo_update.append(row)
    servo_by_sample = {row.get("sample"): row for row in rows}
    f4l_setpoint_deltas: list[int] = []
    f4l_joined_rows: list[dict[str, object]] = []
    for f4l_row in same_servo_update:
        servo_row = servo_by_sample.get(f4l_row.get("sample"))
        if not servo_row or servo_row.get("COHERENT") != "1":
            continue
        # PAIR_UCNT is emitted by Tcl as a decimal integer (the parsed u1),
        # whereas UCNT_AFTER preserves the raw Wishbone word as hexadecimal.
        if int_field(f4l_row, "PAIR_UCNT") != hex_field(servo_row, "UCNT_AFTER"):
            continue
        current_ps = int_field(f4l_row, "PHASE_SHIFT_CURRENT_PS")
        setpoint_ps = int_field(servo_row, "SETP_PS")
        branch_id = int_field(f4l_row, "F4L_BRANCH_ID")
        flags = hex_field(f4l_row, "F4L_FLAGS")
        clamp_code = int_field(f4l_row, "F4L_CLAMP_CODE")
        joined = {
            "sample": f4l_row.get("sample"),
            "host_elapsed_ms": int_field(f4l_row, "host_elapsed_ms"),
            "servo_update_count": int_field(f4l_row, "PAIR_UCNT"),
            "f4l_update_id": hex_field(f4l_row, "F4L_UPDATE_ID"),
            "branch_id": branch_id,
            "flags": flags,
            "clamp_code": clamp_code,
            "branch_error": int_field(f4l_row, "F4L_BRANCH_ERROR"),
            "frequency_error": int_field(f4l_row, "F4L_FREQ_ERROR"),
            "pi_x": int_field(f4l_row, "F4L_PI_X"),
            "pi_output": int_field(f4l_row, "F4L_PI_OUTPUT"),
            "phase_shift_current_ps": current_ps,
            "servo_setpoint_ps": setpoint_ps,
            "cko_ps": int_field(servo_row, "CKO_PS"),
            "servo_state": int_field(servo_row, "SERVO_STATE"),
            "time_valid": int_field(servo_row, "STATUS_TIME_VALID"),
        }
        f4l_joined_rows.append(joined)
        if current_ps is not None and setpoint_ps is not None:
            f4l_setpoint_deltas.append(current_ps - setpoint_ps)
    f4l_phase_rows = [
        row for row in f4l_joined_rows if row["branch_id"] == 2
    ]
    f4l_phase_flags = [
        flags for row in f4l_phase_rows if (flags := row["flags"]) is not None
    ]
    f4l_phase_errors = [
        value
        for row in f4l_phase_rows
        if (value := row["branch_error"]) is not None
    ]
    f4l_phase_pi_x = [
        value for row in f4l_phase_rows if (value := row["pi_x"]) is not None
    ]
    f4l_phase_pi_output = [
        value
        for row in f4l_phase_rows
        if (value := row["pi_output"]) is not None
    ]
    f4l_branch_counts = {
        str(branch): sum(row["branch_id"] == branch for row in f4l_joined_rows)
        for branch in sorted(
            {row["branch_id"] for row in f4l_joined_rows if row["branch_id"] is not None}
        )
    }
    f4l_current_ps = [
        value
        for row in valid_f4l
        if (value := int_field(row, "PHASE_SHIFT_CURRENT_PS")) is not None
    ]
    f4l_current_units = [
        value
        for row in valid_f4l
        if (value := int_field(row, "PHASE_SHIFT_CURRENT_UNITS")) is not None
    ]

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
        "mu_ps_min": min(mu_values) if mu_values else None,
        "mu_ps_max": max(mu_values) if mu_values else None,
        "dms_ps_min": min(dms_values) if dms_values else None,
        "dms_ps_max": max(dms_values) if dms_values else None,
        "asym_ps_min": min(asym_values) if asym_values else None,
        "asym_ps_max": max(asym_values) if asym_values else None,
        "dms_vs_raw_mean_rows": len(dms_vs_raw_mean_deltas),
        "dms_vs_raw_mean_min_ps": min(dms_vs_raw_mean_deltas) if dms_vs_raw_mean_deltas else None,
        "dms_vs_raw_mean_max_ps": max(dms_vs_raw_mean_deltas) if dms_vs_raw_mean_deltas else None,
        "dms_vs_raw_mean_values_ps": dms_vs_raw_mean_deltas,
        "inferred_t1_minus_t2_rows": len(inferred_timestamp_deltas),
        "inferred_t1_minus_t2_min_ps": min(inferred_timestamp_deltas) if inferred_timestamp_deltas else None,
        "inferred_t1_minus_t2_max_ps": max(inferred_timestamp_deltas) if inferred_timestamp_deltas else None,
        "cko_abs_lt_60ps_rows": sum(abs(value) < 60 for value in cko_values),
        "time_valid_rows": len(time_valid),
        "reset_changed_rows": len(reset_changed),
        "f4l_phase_samples": len(f4l_rows),
        "f4l_phase_frames_valid": len(valid_f4l),
        "f4l_same_servo_update_matches": len(same_servo_update),
        "f4l_joined_servo_rows": len(f4l_joined_rows),
        "f4l_branch_id_counts": f4l_branch_counts,
        "f4l_phase_branch_rows": len(f4l_phase_rows),
        "f4l_phase_detector_called_rows": sum(bool(flags & (1 << 5)) for flags in f4l_phase_flags),
        "f4l_phase_in_band_rows": sum(bool(flags & (1 << 6)) for flags in f4l_phase_flags),
        "f4l_phase_out_of_band_rows": sum(bool(flags & (1 << 7)) for flags in f4l_phase_flags),
        "f4l_phase_locked_before_rows": sum(bool(flags & (1 << 3)) for flags in f4l_phase_flags),
        "f4l_phase_locked_after_rows": sum(bool(flags & (1 << 4)) for flags in f4l_phase_flags),
        "f4l_dac_write_rows": sum(bool(flags & (1 << 8)) for flags in f4l_phase_flags),
        "f4l_vco_freeze_rows": sum(bool(flags & (1 << 9)) for flags in f4l_phase_flags),
        "f4l_clamped_rows": sum(
            row["clamp_code"] not in (None, 0) for row in f4l_phase_rows
        ),
        "f4l_phase_error_min": min(f4l_phase_errors) if f4l_phase_errors else None,
        "f4l_phase_error_max": max(f4l_phase_errors) if f4l_phase_errors else None,
        "f4l_phase_error_values": f4l_phase_errors,
        "f4l_phase_pi_x_min": min(f4l_phase_pi_x) if f4l_phase_pi_x else None,
        "f4l_phase_pi_x_max": max(f4l_phase_pi_x) if f4l_phase_pi_x else None,
        "f4l_phase_pi_input_values": f4l_phase_pi_x,
        "f4l_phase_pi_output_min": min(f4l_phase_pi_output) if f4l_phase_pi_output else None,
        "f4l_phase_pi_output_max": max(f4l_phase_pi_output) if f4l_phase_pi_output else None,
        "f4l_phase_pi_output_values": f4l_phase_pi_output,
        "f4l_joined_rows": f4l_joined_rows,
        "f4l_current_setpoint_comparison_rows": len(f4l_setpoint_deltas),
        "f4l_current_minus_setpoint_ps": f4l_setpoint_deltas,
        "f4l_phase_current_units_min": min(f4l_current_units) if f4l_current_units else None,
        "f4l_phase_current_units_max": max(f4l_current_units) if f4l_current_units else None,
        "f4l_phase_current_ps_min": min(f4l_current_ps) if f4l_current_ps else None,
        "f4l_phase_current_ps_max": max(f4l_current_ps) if f4l_current_ps else None,
        "verdict": verdict,
        "scope_note": (
            "F4L frames are publication-coherent; an equal servo update counter "
            "is only a temporal association, not an atomic cross-domain pair. "
            "Descriptive evidence, not Step 6A or Step 6 acceptance."
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
