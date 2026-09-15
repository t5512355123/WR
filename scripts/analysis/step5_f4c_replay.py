#!/usr/bin/env python3
"""Replay the F4C Main phase/service audit without trusting summary lines.

The F4C observer deliberately samples several independently published groups.
This module keeps those groups separate, uses only adjacent samples for delta
accounting, and never turns an F4C diagnostic result into a Step5 pass.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

from step5_replay import _number, modulo_delta, parse_key_values


SAMPLE_PREFIX = "STEP5_F4C_MAIN_PHASE_SAMPLE"
SUMMARY_PREFIX = "STEP5_F4C_SUMMARY"
GATE_PREFIX = "STEP5_F4C_TRANSPORT_GATE"
CONFIG_PREFIX = "STEP5_F4C_CONFIG"
INVALID = {"INVALID", "UNKNOWN", "NA", "N/A"}
KEY_RE = re.compile(r"(?<!\S)([A-Za-z][A-Za-z0-9_]*)=")


def parse_f4c_samples(text: str) -> List[Dict[str, Any]]:
    """Parse only F4C sample records, preserving each original line."""
    samples: List[Dict[str, Any]] = []
    for line in text.splitlines():
        if line.startswith(SAMPLE_PREFIX):
            record = parse_key_values(line)
            record["_line"] = line.rstrip("\r\n")
            samples.append(record)
    return samples


def parse_f4c_summary(text: str) -> Optional[Dict[str, Any]]:
    for line in text.splitlines():
        if line.startswith(SUMMARY_PREFIX):
            return parse_key_values(line)
    return None


def parse_f4c_gate(text: str) -> Optional[Dict[str, Any]]:
    for line in text.splitlines():
        if line.startswith(GATE_PREFIX):
            return parse_key_values(line)
    return None


def parse_f4c_config(text: str) -> Optional[Dict[str, Any]]:
    for line in text.splitlines():
        if line.startswith(CONFIG_PREFIX):
            return parse_key_values(line)
    return None


def _int(record: Dict[str, Any], key: str) -> Optional[int]:
    value = record.get(key)
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _same_generation(previous: Dict[str, Any], current: Dict[str, Any]) -> bool:
    old = _int(previous, "BOOT_GENERATION")
    new = _int(current, "BOOT_GENERATION")
    return old is not None and new is not None and old == new


def _elapsed_gap(previous: Dict[str, Any], current: Dict[str, Any]) -> Optional[int]:
    old = _number(previous.get("ELAPSED_MS"))
    new = _number(current.get("ELAPSED_MS"))
    if old is None or new is None:
        return None
    return int(new - old)


def _adjacent_delta_records(
    samples: Sequence[Dict[str, Any]],
    key: str,
    bits: int = 32,
    max_gap_ms: int = 250,
) -> Dict[str, Any]:
    """Account a counter only across adjacent valid samples in one window."""
    deltas: List[int] = []
    ambiguous = 0
    interrupted = 0
    for previous, current in zip(samples, samples[1:]):
        old = _int(previous, key)
        new = _int(current, key)
        gap = _elapsed_gap(previous, current)
        if old is None or new is None:
            interrupted += 1
            continue
        if gap is None or gap <= 0 or gap > max_gap_ms:
            interrupted += 1
            continue
        if previous.get("L2_VALID") != 1 or current.get("L2_VALID") != 1:
            interrupted += 1
            continue
        if not _same_generation(previous, current):
            interrupted += 1
            continue
        delta = modulo_delta(old, new, bits)
        if delta > (1 << (bits - 1)):
            ambiguous += 1
        else:
            deltas.append(delta)
    return {
        "delta_sum": sum(deltas),
        "delta_samples": len(deltas),
        "positive_delta_samples": sum(delta > 0 for delta in deltas),
        "zero_delta_samples": sum(delta == 0 for delta in deltas),
        "ambiguous": ambiguous,
        "interrupted": interrupted,
    }


def _rms(values: Iterable[float]) -> Optional[float]:
    values = list(values)
    return math.sqrt(sum(value * value for value in values) / len(values)) if values else None


def _fraction(count: int, total: int) -> Optional[float]:
    return float(count) / float(total) if total else None


def _max_consecutive(values: Iterable[bool]) -> int:
    current = 0
    maximum = 0
    for value in values:
        current = current + 1 if value else 0
        maximum = max(maximum, current)
    return maximum


def _phase_count_stats(samples: Sequence[Dict[str, Any]], max_gap_ms: int) -> Dict[str, Any]:
    valid_records = []
    for record in samples:
        value = _int(record, "MAIN_PHASE_LOCK_COUNT")
        if record.get("MAIN_DETECTOR_VALID") == 1 and value is not None:
            valid_records.append((record, value))
    counts = [value for _, value in valid_records]
    increase_events = 0
    decrease_events = 0
    for previous_record, current_record in zip(samples, samples[1:]):
        if previous_record.get("MAIN_DETECTOR_VALID") != 1 or current_record.get("MAIN_DETECTOR_VALID") != 1:
            continue
        old = _int(previous_record, "MAIN_PHASE_LOCK_COUNT")
        new = _int(current_record, "MAIN_PHASE_LOCK_COUNT")
        if old is None or new is None:
            continue
        gap = _elapsed_gap(previous_record, current_record)
        if gap is None or gap <= 0 or gap > max_gap_ms or not _same_generation(previous_record, current_record):
            continue
        if new > old:
            increase_events += 1
        elif new < old:
            decrease_events += 1
    return {
        "valid_samples": len(counts),
        "min": min(counts) if counts else None,
        "max": max(counts) if counts else None,
        "first": counts[0] if counts else None,
        "final": counts[-1] if counts else None,
        "increase_events": increase_events,
        "decrease_events": decrease_events,
    }


def analyze_text(text: str, source: str = "", max_gap_ms: int = 250) -> Dict[str, Any]:
    samples = parse_f4c_samples(text)
    summary_line = parse_f4c_summary(text)
    gate_line = parse_f4c_gate(text)
    config_line = parse_f4c_config(text)
    total = len(samples)

    core_valid = [record.get("MAIN_CORE_VALID") == 1 for record in samples]
    detector_valid = [record.get("MAIN_DETECTOR_VALID") == 1 for record in samples]
    detector_stable = [record.get("MAIN_DETECTOR_STABLE") == 1 for record in samples]
    core_valid_count = sum(core_valid)
    detector_valid_count = sum(detector_valid)
    detector_stable_count = sum(detector_stable)

    sample_n_values = [_int(record, "MAIN_SAMPLE_N") for record in samples]
    sample_n_deltas: List[int] = []
    sample_n_ambiguous = 0
    sample_n_interrupted = 0
    publication_new_producer_stale = 0
    update_advanced_samples = 0
    for previous, current in zip(samples, samples[1:]):
        old = _int(previous, "MAIN_SAMPLE_N")
        new = _int(current, "MAIN_SAMPLE_N")
        gap = _elapsed_gap(previous, current)
        if (current.get("MAIN_TRACE_UNIQUE") == 1 and old is not None and
                new is not None and old == new):
            publication_new_producer_stale += 1
        if (old is None or new is None or gap is None or gap <= 0 or gap > max_gap_ms or
                previous.get("MAIN_TRACE_VALID") != 1 or current.get("MAIN_TRACE_VALID") != 1):
            sample_n_interrupted += 1
            continue
        delta = modulo_delta(old, new, 32)
        if delta > (1 << 31):
            sample_n_ambiguous += 1
            continue
        sample_n_deltas.append(delta)
        if delta > 0:
            update_advanced_samples += 1

    progress_flags = [record.get("MAIN_SAMPLE_N_ADVANCED") == 1 for record in samples]
    progress_samples_reported = sum(progress_flags)
    enabled = [record.get("MAIN_DETECTOR_ENABLED") == 1 for record in samples]
    last_progress_ms: Optional[float] = None
    max_stall_ms = 0.0
    stall_samples = 0
    for record, advanced, is_enabled in zip(samples, progress_flags, enabled):
        elapsed = _number(record.get("ELAPSED_MS"))
        if not is_enabled or elapsed is None:
            continue
        if advanced:
            if last_progress_ms is not None:
                max_stall_ms = max(max_stall_ms, elapsed - last_progress_ms)
            last_progress_ms = elapsed
        elif last_progress_ms is not None:
            max_stall_ms = max(max_stall_ms, elapsed - last_progress_ms)
            stall_samples += 1

    phase_domain = [record.get("MAIN_PHASE_INPUT_DOMAIN") == "PHASE" for record in samples]
    phase_inband = [record.get("MAIN_PHASE_INBAND") == 1 for record in samples]
    phase_domain_count = sum(phase_domain)
    phase_inband_count = sum(domain and inband for domain, inband in zip(phase_domain, phase_inband))
    phase_outband_count = sum(domain and record.get("MAIN_PHASE_INBAND") == 0
                              for domain, record in zip(phase_domain, samples))
    phase_count_stats = _phase_count_stats(samples, max_gap_ms)

    reset_values = []
    generation_changes = 0
    reset_changes = 0
    for previous, current in zip(samples, samples[1:]):
        if previous.get("BOOT_GENERATION") != current.get("BOOT_GENERATION"):
            generation_changes += 1
        reset_keys = ("CPU_RESET", "WR_CORE_RESET", "SI_CONFIG_DROP")
        if any(previous.get(key) != current.get(key) for key in reset_keys):
            reset_changes += 1
    for record in samples:
        values = tuple(record.get(key) for key in
                       ("BOOT_GENERATION", "CPU_RESET", "WR_CORE_RESET", "SI_CONFIG_DROP"))
        if all(value is not None for value in values):
            reset_values.append(values)

    helper_unlock = [
        record.get("HELPER_MEASUREMENT_OK") == 1 and record.get("HELPER_LOCKED") == 0
        for record in samples
    ]
    helper_output = [_number(record.get("HELPER_OUTPUT")) for record in samples]
    helper_rail = [
        value is not None and (value <= 5 or value >= 65531)
        for value in helper_output
    ]
    helper_residual = [record.get("HELPER_RESIDUAL_PRESENT") == 1 for record in samples]
    residual_without_pending = [
        residual and record.get("L2_HELPER_PENDING") == 0
        for residual, record in zip(helper_residual, samples)
    ]
    residual_without_pending_and_progress = [
        residual and record.get("L2_HELPER_PENDING") == 0 and record.get("MAIN_SAMPLE_N_ADVANCED") == 1
        for residual, record in zip(helper_residual, samples)
    ]

    l2_counter_keys = (
        "L2_MAIN_PENDING_COUNT", "L2_HELPER_PENDING_COUNT",
        "L2_MAIN_START_COUNT", "L2_HELPER_START_COUNT",
        "L2_MAIN_COMPLETED_COUNT", "L2_HELPER_COMPLETED_COUNT",
        "L2_MAIN_FAILED", "L2_HELPER_FAILED",
    )
    l2_accounting = {
        key: _adjacent_delta_records(samples, key, 32, max_gap_ms)
        for key in l2_counter_keys
    }

    pi_x = [_number(record.get("MAIN_PI_X")) for record in samples]
    pi_output = [_number(record.get("MAIN_PI_OUTPUT")) for record in samples]
    clamp_values = [record.get("MAIN_PI_CLAMP_SIDE") for record in samples]
    pi_x_values = [float(value) for value in pi_x if value is not None]
    pi_output_values = [float(value) for value in pi_output if value is not None]

    observer_stop_reasons = [record.get("STOP_REASON") for record in samples
                             if record.get("STOP_REASON") not in (None, "NONE")]
    stop_reason = observer_stop_reasons[-1] if observer_stop_reasons else "NONE"
    if summary_line is not None and summary_line.get("STOP_REASON") is not None:
        stop_reason = summary_line["STOP_REASON"]
    run_end_reason = summary_line.get("RUN_END_REASON") if summary_line else None
    elapsed_values = [_number(record.get("ELAPSED_MS")) for record in samples]
    elapsed_values = [value for value in elapsed_values if value is not None]
    elapsed_ms = max(elapsed_values) if elapsed_values else None

    gate_valid = None
    if gate_line is not None:
        gate_valid = gate_line.get("VALID") == 1
    elif summary_line is not None:
        gate_valid = summary_line.get("TRANSPORT_GATE_VALID") == 1

    reset_stable = generation_changes == 0 and reset_changes == 0 and bool(reset_values)
    data_quality = "INCONCLUSIVE"
    core_fraction = _fraction(core_valid_count, total)
    detector_fraction = _fraction(detector_valid_count, total)
    if (gate_valid is True and core_fraction is not None and core_fraction >= 0.95 and
            detector_fraction is not None and detector_fraction >= 0.95 and
            len(sample_n_deltas) >= 3 and update_advanced_samples >= 2 and
            sample_n_ambiguous == 0 and reset_stable):
        data_quality = "PASS"

    terminal = run_end_reason == "TARGET_REACHED" or stop_reason in {
        "MAIN_NOT_PROGRESSING", "HELPER_UNLOCK_REGRESSION", "HELPER_RAIL_REGRESSION",
    }
    diagnostic_result = "PASS" if data_quality == "PASS" and terminal else "INCONCLUSIVE"
    summary_diagnostic = summary_line.get("F4C_DIAGNOSTIC_RESULT") if summary_line else None
    if summary_diagnostic in {"PASS", "INCONCLUSIVE"}:
        diagnostic_result = summary_diagnostic

    return {
        "format": "step5-f4c-evidence-v1",
        "source": source,
        "sample_count": total,
        "elapsed_ms": elapsed_ms,
        "run_end_reason": run_end_reason,
        "stop_reason": stop_reason,
        "run_role": summary_line.get("RUN_ROLE") if summary_line else None,
        "target_duration_ms": summary_line.get("TARGET_DURATION_MS") if summary_line else None,
        "hard_duration_ms": summary_line.get("HARD_DURATION_MS") if summary_line else None,
        "transport_gate_valid": gate_valid,
        "main_core_valid_count": core_valid_count,
        "main_core_valid_fraction": core_fraction,
        "main_detector_valid_count": detector_valid_count,
        "main_detector_valid_fraction": detector_fraction,
        "main_detector_stable_count": detector_stable_count,
        "main_detector_stable_fraction": _fraction(detector_stable_count, total),
        "main_sample_n_first": sample_n_values[0] if sample_n_values else None,
        "main_sample_n_final": sample_n_values[-1] if sample_n_values else None,
        "main_sample_n_delta_sum": sum(sample_n_deltas),
        "main_sample_n_delta_samples": len(sample_n_deltas),
        "main_sample_n_positive_delta_samples": update_advanced_samples,
        "main_sample_n_delta_ambiguous": sample_n_ambiguous,
        "main_sample_n_delta_interrupted": sample_n_interrupted,
        "main_sample_n_advanced_samples_reported": progress_samples_reported,
        "publication_new_producer_stale": publication_new_producer_stale,
        "main_max_stall_ms_replay": max_stall_ms,
        "main_stall_samples_replay": stall_samples,
        "main_phase_domain_samples": phase_domain_count,
        "main_phase_inband_count": phase_inband_count,
        "main_phase_outband_count": phase_outband_count,
        "main_phase_inband_fraction": _fraction(phase_inband_count, phase_domain_count),
        "main_phase_count": phase_count_stats,
        "main_pi_x_min": min(pi_x_values) if pi_x_values else None,
        "main_pi_x_max": max(pi_x_values) if pi_x_values else None,
        "main_pi_x_rms": _rms(pi_x_values),
        "main_pi_output_min": min(pi_output_values) if pi_output_values else None,
        "main_pi_output_max": max(pi_output_values) if pi_output_values else None,
        "main_pi_clamp_samples": sum(value in {-1, 1} for value in clamp_values),
        "helper_residual_samples": sum(helper_residual),
        "residual_without_pending_samples": sum(residual_without_pending),
        "residual_without_pending_main_progress_samples": sum(residual_without_pending_and_progress),
        "helper_unlock_samples": sum(helper_unlock),
        "helper_unlock_max_consecutive": _max_consecutive(helper_unlock),
        "helper_rail_samples": sum(helper_rail),
        "helper_rail_max_consecutive": _max_consecutive(helper_rail),
        "l2_accounting": l2_accounting,
        "generation_changes": generation_changes,
        "reset_changes": reset_changes,
        "reset_stable": reset_stable,
        "f4c_data_quality": data_quality,
        "f4c_diagnostic_result": diagnostic_result,
        # F4C is an audit stage; it cannot satisfy the strict Step5 closure.
        "step5_pass": False,
        "config_present": config_line is not None,
    }


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def replay(paths: Sequence[Path], max_gap_ms: int = 250) -> List[Dict[str, Any]]:
    return [analyze_text(_read_text(path), str(path), max_gap_ms) for path in paths]


def write_outputs(results: Sequence[Dict[str, Any]], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / "verdict.json").open("w", encoding="utf-8", newline="\n") as handle:
        json.dump({"format": "step5-f4c-evidence-v1", "step5_pass": False,
                   "results": list(results)}, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    fields = [
        "source", "sample_count", "elapsed_ms", "run_role", "run_end_reason", "stop_reason",
        "transport_gate_valid", "main_core_valid_fraction", "main_detector_valid_fraction",
        "main_sample_n_first", "main_sample_n_final", "main_sample_n_delta_sum",
        "main_sample_n_delta_samples", "main_sample_n_positive_delta_samples",
        "publication_new_producer_stale", "main_max_stall_ms_replay",
        "main_phase_domain_samples", "main_phase_inband_count", "main_phase_outband_count",
        "main_phase_inband_fraction", "helper_residual_samples",
        "residual_without_pending_samples", "residual_without_pending_main_progress_samples",
        "helper_unlock_max_consecutive", "helper_rail_max_consecutive",
        "generation_changes", "reset_changes", "reset_stable", "f4c_data_quality",
        "f4c_diagnostic_result", "step5_pass",
    ]
    with (output_dir / "comparison.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for result in results:
            writer.writerow({field: result.get(field) for field in fields})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", action="append", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--max-gap-ms", type=int, default=250)
    args = parser.parse_args()
    results = replay(args.input, args.max_gap_ms)
    write_outputs(results, args.output_dir)
    print(json.dumps({"inputs": len(results), "output_dir": str(args.output_dir),
                      "step5_pass": False}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
