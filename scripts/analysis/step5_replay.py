#!/usr/bin/env python3
"""Replay Step5 observer logs without trusting column positions or summaries."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import tarfile
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


KEY_RE = re.compile(r"(?<!\S)([A-Za-z][A-Za-z0-9_]*)=")
SAMPLE_PREFIX = "STEP5_CLOSED_LOOP_SAMPLE"
SUMMARY_PREFIX = "STEP5_GUARDED_HELPER_DYNAMICS_SUMMARY"
INVALID_WORDS = {"INVALID", "UNKNOWN", "NA", "N/A"}

COUNTER_BITS = {
    "LOCK_COUNT": 16,
    "HELPER_LOCK_COUNT": 16,
    "NORMAL_REQ": 16,
    "NORMAL_COMPLETED": 16,
    "DCO_STEP": 16,
    "BOOTSTRAP_COMPLETED": 16,
    "FORCED_COMPLETED": 16,
    "FINC_COMPLETED": 16,
    "FDEC_COMPLETED": 16,
    "COUNTER8": 8,
}


def _convert(value: str) -> Any:
    value = value.strip()
    if value.upper() in INVALID_WORDS:
        return None
    if value.upper() in {"YES", "NO", "PASS", "FAIL", "CANDIDATE", "NOT_COMPLETE"}:
        return value.upper()
    try:
        if re.fullmatch(r"[-+]?\d+", value):
            return int(value, 10)
        if re.fullmatch(r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?", value):
            return float(value)
    except ValueError:
        pass
    return value


def parse_key_values(line: str) -> Dict[str, Any]:
    """Parse key=value pairs while allowing values such as board names to contain spaces."""
    matches = list(KEY_RE.finditer(line))
    result: Dict[str, Any] = {}
    for index, match in enumerate(matches):
        key = match.group(1).upper()
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(line)
        result[key] = _convert(line[start:end])
    return result


def _read_path(path: Path) -> str:
    if path.suffixes[-2:] == [".tar", ".gz"] or path.suffix == ".tgz":
        with tarfile.open(path, "r:gz") as archive:
            candidates = [member for member in archive.getmembers()
                          if member.isfile() and Path(member.name).name.startswith("observer-")
                          and member.name.endswith(".log")]
            if not candidates:
                raise ValueError(f"no observer log found in {path}")
            member = sorted(candidates, key=lambda item: item.name)[-1]
            extracted = archive.extractfile(member)
            if extracted is None:
                raise ValueError(f"cannot extract {member.name} from {path}")
            return extracted.read().decode("utf-8", errors="replace")
    return path.read_text(encoding="utf-8", errors="replace")


def _number(value: Any) -> Optional[float]:
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) else None


def modulo_delta(previous: int, current: int, bits: int) -> int:
    return (current - previous) & ((1 << bits) - 1)


def parse_samples(text: str) -> List[Dict[str, Any]]:
    samples: List[Dict[str, Any]] = []
    for line in text.splitlines():
        if line.startswith(SAMPLE_PREFIX):
            record = parse_key_values(line)
            record["_line"] = line.rstrip("\r\n")
            samples.append(record)
    return samples


def _valid_measurement(record: Dict[str, Any]) -> bool:
    # COHERENT is the measurement seqlock result.  FRAME_VALID is a separate
    # snapshot/transport domain and must not discard an otherwise valid Helper
    # measurement or be silently treated as a zero.
    return (record.get("COHERENT") == 1
            and _number(record.get("HELPER_ERROR")) is not None
            and _number(record.get("HELPER_UPDATE_COUNT")) is not None)


def _valid_position(record: Dict[str, Any]) -> bool:
    if record.get("POSITION_VALID") != 1:
        return False
    required = ("POSITION_EPOCH", "TARGET_CODE", "APPLIED_CODE", "DCO_STEP",
                "NORMAL_REQ", "NORMAL_COMPLETED", "FINC_COMPLETED", "FDEC_COMPLETED")
    return all(_number(record.get(key)) is not None for key in required)


def _valid_chain(record: Dict[str, Any]) -> bool:
    required = ("FRAME_VALID", "COHERENT", "HELPER_LOCKED", "MAIN_ENABLED",
                "MAIN_FREQ_LOCKED", "MAIN_PHASE_LOCKED", "MAIN_LOCKED",
                "PSTAT_LOCKED", "HELPER_UPDATE_COUNT", "EPOCH", "ELAPSED_MS")
    if any(record.get(key) is None for key in required):
        return False
    return all(record.get(key) == 1 for key in
               ("FRAME_VALID", "COHERENT", "HELPER_LOCKED", "MAIN_ENABLED",
                "MAIN_FREQ_LOCKED", "MAIN_PHASE_LOCKED", "MAIN_LOCKED", "PSTAT_LOCKED"))


def _fresh_chain_sample(record: Dict[str, Any], previous: Optional[Dict[str, Any]]) -> Optional[bool]:
    """Return whether a full-chain sample is new, or None if freshness is unavailable."""
    if previous is None:
        return False
    elapsed = _number(record.get("ELAPSED_MS"))
    previous_elapsed = _number(previous.get("ELAPSED_MS"))
    helper_new = (elapsed is not None and previous_elapsed is not None
                  and elapsed > previous_elapsed
                  and record.get("HELPER_UPDATE_COUNT") != previous.get("HELPER_UPDATE_COUNT")
                  and record.get("EPOCH") != previous.get("EPOCH"))
    main_keys_present = "MAIN_UPDATE_SEQ" in record or "MAIN_UPDATE_SEQ" in previous
    if not main_keys_present:
        return helper_new
    current_main = _number(record.get("MAIN_UPDATE_SEQ"))
    previous_main = _number(previous.get("MAIN_UPDATE_SEQ"))
    if current_main is None or previous_main is None:
        return None
    return helper_new and current_main != previous_main


def _rms(values: Iterable[float]) -> Optional[float]:
    values = list(values)
    return math.sqrt(sum(value * value for value in values) / len(values)) if values else None


def _continuous_segments(samples: List[Dict[str, Any]], max_gap_ms: int) -> List[Dict[str, Any]]:
    segments: List[Dict[str, Any]] = []
    active: Optional[Dict[str, Any]] = None
    previous: Optional[Dict[str, Any]] = None
    for record in samples:
        valid = _valid_chain(record)
        elapsed = _number(record.get("ELAPSED_MS"))
        fresh_state = _fresh_chain_sample(record, previous)
        fresh = valid and fresh_state is True
        gap_ok = (previous is not None and elapsed is not None and _number(previous.get("ELAPSED_MS")) is not None and 0 < elapsed - previous["ELAPSED_MS"] <= max_gap_ms)
        generation_ok = previous is None or record.get("BOOT_GENERATION") == previous.get("BOOT_GENERATION")
        if valid and (active is None or (fresh and gap_ok and generation_ok)):
            if active is None:
                active = {"start_ms": elapsed, "end_ms": elapsed, "samples": 1}
            else:
                active["end_ms"] = elapsed
                active["samples"] += 1
        else:
            if active is not None:
                active["duration_ms"] = active["end_ms"] - active["start_ms"]
                segments.append(active)
                active = None
        previous = record
    if active is not None:
        active["duration_ms"] = active["end_ms"] - active["start_ms"]
        segments.append(active)
    return segments


def _counter_accounting(samples: List[Dict[str, Any]], max_gap_ms: int) -> Dict[str, Any]:
    result: Dict[str, Any] = {}
    for key, bits in COUNTER_BITS.items():
        deltas: List[int] = []
        ambiguous = 0
        previous: Optional[Dict[str, Any]] = None
        for record in samples:
            value = record.get(key)
            if value is None or not isinstance(value, int):
                previous = record
                continue
            if previous is not None and isinstance(previous.get(key), int):
                gap = _number(record.get("ELAPSED_MS"))
                old_gap = _number(previous.get("ELAPSED_MS"))
                delta = modulo_delta(previous[key], value, bits)
                if gap is None or old_gap is None or gap <= old_gap or gap - old_gap > max_gap_ms or delta > (1 << (bits - 1)):
                    if delta != 0:
                        ambiguous += 1
                else:
                    deltas.append(delta)
            previous = record
        result[key] = {"delta_sum": sum(deltas), "delta_samples": len(deltas), "ambiguous": ambiguous}
    return result


def analyze_text(text: str, source: str = "", max_gap_ms: int = 250) -> Dict[str, Any]:
    samples = parse_samples(text)
    measurement = [record for record in samples if _valid_measurement(record)]
    position = [record for record in samples if _valid_position(record)]
    helper_errors = [float(record["HELPER_ERROR"]) for record in measurement]
    threshold = 2000
    lock_bit_transitions = 0
    lock_count_increases = 0
    lock_count_decreases = 0
    duplicate_epochs = 0
    generation_changes = 0
    previous: Optional[Dict[str, Any]] = None
    for record in samples:
        if previous is not None:
            if record.get("EPOCH") == previous.get("EPOCH") and record.get("EPOCH") is not None:
                duplicate_epochs += 1
            if record.get("BOOT_GENERATION") != previous.get("BOOT_GENERATION"):
                generation_changes += 1
            if record.get("HELPER_LOCKED") != previous.get("HELPER_LOCKED"):
                lock_bit_transitions += 1
            old_count = previous.get("HELPER_LOCK_COUNT")
            new_count = record.get("HELPER_LOCK_COUNT")
            if isinstance(old_count, int) and isinstance(new_count, int):
                if new_count > old_count:
                    lock_count_increases += 1
                elif new_count < old_count:
                    lock_count_decreases += 1
        previous = record
    segments = _continuous_segments(samples, max_gap_ms)
    full_chain_freshness_unknown = bool(samples) and not all(
        "MAIN_UPDATE_SEQ" in record and _number(record.get("MAIN_UPDATE_SEQ")) is not None
        for record in samples
    )
    stale_full_chain_samples = 0
    for previous, record in zip(samples, samples[1:]):
        if _valid_chain(record) and _valid_chain(previous) and _fresh_chain_sample(record, previous) is False:
            stale_full_chain_samples += 1
    summary: Dict[str, Any] = {
        "source": source,
        "sample_count": len(samples),
        "measurement_valid_samples": len(measurement),
        "frame_valid_samples": sum(record.get("FRAME_VALID") == 1 for record in samples),
        "coherent_measurement_samples": sum(record.get("COHERENT") == 1 for record in samples),
        "position_valid_samples": len(position),
        "helper_error_mean": sum(helper_errors) / len(helper_errors) if helper_errors else None,
        "helper_error_rms": _rms(helper_errors),
        "helper_error_min": min(helper_errors) if helper_errors else None,
        "helper_error_max": max(helper_errors) if helper_errors else None,
        "helper_error_max_abs": max((abs(value) for value in helper_errors), default=None),
        "fraction_abs_error_le_200": sum(abs(value) <= 200 for value in helper_errors) / len(helper_errors) if helper_errors else None,
        "fraction_outside_actual_helper_threshold": sum(abs(value) > threshold for value in helper_errors) / len(helper_errors) if helper_errors else None,
        "actual_helper_threshold": threshold,
        "locked_bit_transitions": lock_bit_transitions,
        "lock_count_increases": lock_count_increases,
        "lock_count_decreases": lock_count_decreases,
        "duplicate_epochs": duplicate_epochs,
        "generation_changes": generation_changes,
        "full_chain_segments": segments,
        "max_continuous_full_chain_ms": max((segment["duration_ms"] for segment in segments), default=0),
        "full_chain_freshness_unknown": full_chain_freshness_unknown,
        "stale_full_chain_samples": stale_full_chain_samples,
        "strict_step5_pass": False,
        "counter_accounting": _counter_accounting(samples, max_gap_ms),
    }
    return summary


def replay(paths: List[Path], max_gap_ms: int = 250) -> List[Dict[str, Any]]:
    return [analyze_text(_read_path(path), str(path), max_gap_ms) for path in paths]


def write_outputs(results: List[Dict[str, Any]], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / "verdict.json").open("w", encoding="utf-8", newline="\n") as handle:
        json.dump({"format": "step5-evidence-v2", "step5_pass": False, "results": results}, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    fields = ["source", "sample_count", "measurement_valid_samples", "frame_valid_samples",
              "coherent_measurement_samples", "position_valid_samples",
              "helper_error_mean", "helper_error_rms", "helper_error_max_abs",
              "fraction_abs_error_le_200", "fraction_outside_actual_helper_threshold",
              "locked_bit_transitions", "lock_count_increases", "lock_count_decreases",
              "duplicate_epochs", "generation_changes", "max_continuous_full_chain_ms",
              "full_chain_freshness_unknown", "strict_step5_pass"]
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
    print(json.dumps({"inputs": len(results), "output_dir": str(args.output_dir), "step5_pass": False}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
