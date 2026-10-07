#!/usr/bin/env python3
"""Replay the F4J Main producer-handoff snapshot audit.

F4J is a diagnostic experiment, not a Step5 pass test.  It accepts a Main
frame only when the WDIAGS publication epoch and the producer epoch are both
coherent, the explicit F4J schema is present, and the frame identifies Main
DAC 0.  Frequency-branch arithmetic is checked exactly; phase error is
accepted only as the signed value captured by the producer, never rebuilt
from a sparse host-side trace.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts" / "analysis"))

from step5_replay import parse_key_values  # noqa: E402


F4J_CONFIG = "STEP5_F4J_CONFIG"
F4J_DONE = "STEP5_F4J_DONE"
F4J_MAIN = "STEP5_F4J_MAIN_PRODUCER"
F4J_CYCLE = "STEP5_F4J_CYCLE"
F4J_WR = "STEP5_F4J_WR_CORE"
F4J_MASTER = "STEP5_F4J_MASTER_SAMPLE"
F4J_ERROR = "STEP5_F4J_CONTEXT_ERROR"
MAGIC = 0x4D50344A
VERSION = 1
FRAME_WORDS = 30
UINT32 = 1 << 32
UINT32_MASK = UINT32 - 1
HALF32 = 1 << 31
INVALID = {"", "INVALID", "UNKNOWN", "NEVER", "NA", "N/A", "TIMEOUT",
           "NOT_MEASURED"}
HEX_RE = re.compile(r"^(?:0x)?[0-9A-Fa-f]+$")


def _records(text: str, prefix: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for line in text.splitlines():
        if line.startswith(prefix + " "):
            row = parse_key_values(line)
            row["_line"] = line.rstrip("\r\n")
            rows.append(row)
    return rows


def _first(rows: Sequence[Dict[str, Any]], last: bool = False) -> Optional[Dict[str, Any]]:
    if not rows:
        return None
    return rows[-1] if last else rows[0]


def _int(value: Any) -> Optional[int]:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    text = str(value).strip()
    if text.upper() in INVALID:
        return None
    try:
        return int(text, 0)
    except ValueError:
        try:
            return int(text, 10)
        except ValueError:
            return None


def _raw_int(value: Any) -> Optional[int]:
    """Parse a raw word, which the observer emits with a 0x prefix."""
    if value is None:
        return None
    if isinstance(value, int) and not isinstance(value, bool):
        return value & UINT32_MASK
    text = str(value).strip()
    if text.upper() in INVALID or not HEX_RE.fullmatch(text):
        return None
    try:
        return int(text, 16) & UINT32_MASK
    except ValueError:
        return None


def _flag(row: Dict[str, Any], key: str) -> bool:
    value = row.get(key)
    if isinstance(value, bool):
        return value
    return str(value).strip().upper() in {"1", "YES", "TRUE", "PASS"}


def _text(row: Dict[str, Any], key: str, default: str = "") -> str:
    value = row.get(key, default)
    return default if value is None else str(value)


def _counter_delta(previous: Optional[int], current: Optional[int]) -> Tuple[Optional[int], bool]:
    if previous is None or current is None:
        return None, False
    delta = (current - previous) & UINT32_MASK
    if delta > HALF32:
        return None, True
    return delta, False


def _host_end(row: Dict[str, Any]) -> Optional[int]:
    return _int(row.get("HOST_END_MS"))


def _host_start(row: Dict[str, Any]) -> Optional[int]:
    return _int(row.get("HOST_START_MS"))


def parse_config(text: str) -> Optional[Dict[str, Any]]:
    return _first(_records(text, F4J_CONFIG))


def parse_done(text: str) -> Optional[Dict[str, Any]]:
    return _first(_records(text, F4J_DONE), last=True)


def parse_main(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4J_MAIN)


def parse_cycles(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4J_CYCLE)


def parse_wr(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4J_WR)


def parse_errors(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4J_ERROR)


def _normalize_main(row: Dict[str, Any]) -> Tuple[Dict[str, Any], List[str]]:
    errors: List[str] = []
    normalized: Dict[str, Any] = {
        "BOARD": _text(row, "BOARD"),
        "CYCLE": _int(row.get("CYCLE")),
        "HOST_START_MS": _host_start(row),
        "HOST_END_MS": _host_end(row),
        "MAIN_PRODUCER_VALID": int(_flag(row, "MAIN_PRODUCER_VALID")),
        "PUBLICATION_COHERENT": int(_flag(row, "PUBLICATION_COHERENT")),
        "PUBLICATION_EPOCH": _int(row.get("PUBLICATION_EPOCH")),
        "PRODUCER_EPOCH": _int(row.get("PRODUCER_EPOCH")),
        "UPDATE_ID": _int(row.get("UPDATE_ID")),
        "INIT_GENERATION": _int(row.get("INIT_GENERATION")),
        "PRODUCER_IDENTITY": _int(row.get("PRODUCER_IDENTITY")),
        "FREQ_ERROR": _int(row.get("FREQ_ERROR")),
        "BRANCH_ID": _int(row.get("BRANCH_ID")),
        "BRANCH_ERROR": _int(row.get("BRANCH_ERROR")),
        "PI_X": _int(row.get("PI_X")),
        "PI_OUTPUT": _int(row.get("PI_OUTPUT")),
        "PI_CLAMP_SIDE": _int(row.get("PI_CLAMP_SIDE")),
        "FLAGS": _int(row.get("FLAGS")),
        "FREQ_COUNT_BEFORE": _int(row.get("FREQ_COUNT_BEFORE")),
        "FREQ_COUNT_AFTER": _int(row.get("FREQ_COUNT_AFTER")),
        "PHASE_COUNT_BEFORE": _int(row.get("PHASE_COUNT_BEFORE")),
        "PHASE_COUNT_AFTER": _int(row.get("PHASE_COUNT_AFTER")),
        "SAMPLE_N": _int(row.get("SAMPLE_N")),
        "SOURCE_IDS": _int(row.get("SOURCE_IDS")),
        "TOTAL_UPDATES": _int(row.get("TOTAL_UPDATES")),
        "FREQ_UPDATES": _int(row.get("FREQ_UPDATES")),
        "PHASE_UPDATES": _int(row.get("PHASE_UPDATES")),
        "FREQ_TO_PHASE": _int(row.get("FREQ_TO_PHASE")),
        "PHASE_TO_FREQ": _int(row.get("PHASE_TO_FREQ")),
        "PHASE_DETECTOR": _int(row.get("PHASE_DETECTOR")),
        "PHASE_IN_BAND": _int(row.get("PHASE_IN_BAND")),
        "PHASE_OUT_BAND": _int(row.get("PHASE_OUT_BAND")),
        "LAST_TRANSITION_UPDATE": _int(row.get("LAST_TRANSITION_UPDATE")),
        "LAST_TRANSITION": _int(row.get("LAST_TRANSITION")),
        "STATUS": _int(row.get("STATUS")),
        "LAST_FREQ_UPDATE": _int(row.get("LAST_FREQ_UPDATE")),
        "LAST_PHASE_UPDATE": _int(row.get("LAST_PHASE_UPDATE")),
        "FRAME_WORDS": _int(row.get("FRAME_WORDS")),
        "SCHEMA_VERSION": _int(row.get("SCHEMA_VERSION")),
        "MAGIC": _int(row.get("MAGIC")),
        "TRANSPORT_FAILURE": int(_flag(row, "TRANSPORT_FAILURE")),
        "_line": row.get("_line", ""),
    }
    raw_before = _raw_int(row.get("PUBLICATION_EPOCH_RAW_BEFORE"))
    raw_after = _raw_int(row.get("PUBLICATION_EPOCH_RAW_AFTER"))
    normalized["PUBLICATION_EPOCH_RAW_BEFORE"] = raw_before
    normalized["PUBLICATION_EPOCH_RAW_AFTER"] = raw_after
    raw_names = [
        "PRODUCER_EPOCH", "UPDATE_ID", "INIT_GENERATION", "PRODUCER_IDENTITY",
        "FREQ_ERROR", "BRANCH_ID", "BRANCH_ERROR", "PI_X", "PI_OUTPUT",
        "PI_CLAMP_SIDE", "FLAGS", "FREQ_COUNT_BEFORE", "FREQ_COUNT_AFTER",
        "PHASE_COUNT_BEFORE", "PHASE_COUNT_AFTER", "SAMPLE_N", "SOURCE_IDS",
        "TOTAL_UPDATES", "FREQ_UPDATES", "PHASE_UPDATES", "FREQ_TO_PHASE",
        "PHASE_TO_FREQ", "PHASE_DETECTOR", "PHASE_IN_BAND", "PHASE_OUT_BAND",
        "LAST_TRANSITION_UPDATE", "LAST_TRANSITION", "STATUS", "LAST_FREQ_UPDATE",
        "LAST_PHASE_UPDATE", "FRAME_WORDS", "VERSION", "MAGIC",
    ]
    raw_missing = []
    for name in raw_names:
        key = name + "_RAW"
        value = _raw_int(row.get(key))
        normalized[key] = value
        if value is None:
            raw_missing.append(key)
        else:
            normalized_name = "SCHEMA_VERSION" if name == "VERSION" else name
            expected = normalized.get(normalized_name)
            if expected is not None and value != (expected & UINT32_MASK):
                errors.append("RAW_VALUE_MISMATCH:" + key)
    if raw_missing:
        errors.append("RAW_FIELDS_MISSING:" + ",".join(raw_missing))

    required = [
        "BOARD", "HOST_END_MS", "MAIN_PRODUCER_VALID", "PUBLICATION_COHERENT",
        "PUBLICATION_EPOCH", "PRODUCER_EPOCH", "UPDATE_ID", "INIT_GENERATION",
        "PRODUCER_IDENTITY", "FREQ_ERROR", "BRANCH_ID", "BRANCH_ERROR", "PI_X",
        "PI_OUTPUT", "PI_CLAMP_SIDE", "FLAGS", "FREQ_COUNT_BEFORE",
        "FREQ_COUNT_AFTER", "PHASE_COUNT_BEFORE", "PHASE_COUNT_AFTER", "SAMPLE_N",
        "SOURCE_IDS", "TOTAL_UPDATES", "PHASE_DETECTOR", "STATUS", "FRAME_WORDS",
        "SCHEMA_VERSION", "MAGIC",
    ]
    missing = [key for key in required if normalized.get(key) is None]
    if missing:
        errors.append("FIELDS_MISSING:" + ",".join(missing))
    if normalized["MAIN_PRODUCER_VALID"] != 1:
        errors.append("PRODUCER_FRAME_INVALID")
    if normalized["PUBLICATION_COHERENT"] != 1:
        errors.append("PUBLICATION_NOT_COHERENT")
    if raw_before is None or raw_after is None or raw_before != raw_after or raw_after & 1:
        errors.append("PUBLICATION_EPOCH_RAW_MISMATCH")
    if normalized["PUBLICATION_EPOCH"] is not None and raw_after is not None \
            and normalized["PUBLICATION_EPOCH"] != raw_after:
        errors.append("PUBLICATION_EPOCH_VALUE_MISMATCH")
    if normalized["PRODUCER_EPOCH"] is not None:
        if normalized["PRODUCER_EPOCH"] & 1:
            errors.append("PRODUCER_EPOCH_ODD")
    if normalized["SCHEMA_VERSION"] != VERSION:
        errors.append("SCHEMA_VERSION_MISMATCH")
    if normalized["MAGIC"] != MAGIC:
        errors.append("SCHEMA_MAGIC_MISMATCH")
    if normalized["FRAME_WORDS"] != FRAME_WORDS:
        errors.append("FRAME_WORD_COUNT_MISMATCH")
    identity = normalized["PRODUCER_IDENTITY"]
    source_ids = normalized["SOURCE_IDS"]
    if identity is not None:
        if identity & 0xff:
            errors.append("NON_MAIN_DAC_IDENTITY")
        expected_source_ids = ((identity >> 8) & 0xff) | (((identity >> 16) & 0xff) << 8)
        if source_ids != expected_source_ids:
            errors.append("SOURCE_IDENTITY_MISMATCH")
    branch = normalized["BRANCH_ID"]
    freq_error = normalized["FREQ_ERROR"]
    branch_error = normalized["BRANCH_ERROR"]
    flags = normalized["FLAGS"] or 0
    if branch not in {1, 2}:
        errors.append("BRANCH_ID_INVALID")
    elif branch == 1:
        if freq_error is not None and branch_error is not None \
                and branch_error != -20 * freq_error:
            errors.append("FREQUENCY_BRANCH_FORMULA_MISMATCH")
        if flags & (1 << 5):
            errors.append("FREQUENCY_BRANCH_PHASE_CALL_FLAG")
    elif not (flags & (1 << 5)):
        errors.append("PHASE_BRANCH_WITHOUT_DETECTOR_CALL")
    if branch_error is not None and normalized["PI_X"] is not None \
            and branch_error != normalized["PI_X"]:
        errors.append("PI_INPUT_NOT_BRANCH_ERROR")
    if not (flags & 1):
        errors.append("FRAME_VALID_FLAG_MISSING")
    phase_detector = normalized["PHASE_DETECTOR"]
    phase_updates = normalized["PHASE_UPDATES"]
    phase_in = normalized["PHASE_IN_BAND"]
    phase_out = normalized["PHASE_OUT_BAND"]
    if phase_detector is not None and phase_updates is not None and phase_detector != phase_updates:
        errors.append("PHASE_DETECTOR_COUNTER_MISMATCH")
    if phase_detector is not None and phase_in is not None and phase_out is not None \
            and phase_in + phase_out != phase_detector:
        errors.append("PHASE_BAND_COUNTER_MISMATCH")
    return normalized, sorted(set(errors))


def _dedup(rows: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    valid = [row for row in rows if not row.get("_frame_errors")]
    valid.sort(key=lambda row: (_host_end(row) is None, _host_end(row) or 0))
    seen: set[Tuple[str, Optional[int], Optional[int], Optional[int]]] = set()
    unique: List[Dict[str, Any]] = []
    duplicate_count = 0
    for row in valid:
        key = (str(row.get("BOARD", "")), row.get("INIT_GENERATION"),
               row.get("UPDATE_ID"), row.get("PRODUCER_EPOCH"))
        if key in seen:
            row["PRODUCER_DEDUP_SKIPPED"] = 1
            duplicate_count += 1
        else:
            row["PRODUCER_DEDUP_SKIPPED"] = 0
            row["PRODUCER_UNIQUE"] = 1
            seen.add(key)
            unique.append(row)
    for row in rows:
        row.setdefault("PRODUCER_UNIQUE", 0)
        row.setdefault("PRODUCER_DEDUP_SKIPPED", 0)
    return {"unique": unique, "duplicate_count": duplicate_count}


def _source_gate(config: Optional[Dict[str, Any]], done: Optional[Dict[str, Any]],
                 wr_rows: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    required = {
        "READ_ONLY_OBSERVER": "1",
        "ONE_READER": "1",
        "READER_PROCESSES": "1",
        "NO_CONTROL_WRITE": "1",
        "NO_HELPER_PI_SNAPSHOT": "1",
        "NO_DEBUG_FIFO_DRAIN": "1",
        "PRODUCTION_CONTROL_UNCHANGED": "1",
        "SOURCE_CONTRACT_VERIFIED": "YES",
    }
    config_pass = bool(config) and all(
        str(config.get(key, "")).upper() == expected.upper()
        for key, expected in required.items()
    )
    done_pass = bool(done) and str(done.get("SINGLE_READER", "")).upper() == "PASS"
    valid_wr = [row for row in wr_rows if _flag(row, "WR_CORE_VALID")]
    roles = sorted({str(row.get("ROLE", "")).upper() for row in valid_wr})
    identity_pass = bool(valid_wr) and all(
        _flag(row, "ROLE_IDENTITY_VALID") and _flag(row, "RESET_FIELDS_VALID")
        for row in valid_wr
    )
    phy_schema_rows = 0
    phy_valid_rows = 0
    phy_mismatch = 0
    for row in valid_wr:
        source = str(row.get("PHY_STATUS_SOURCE", "")).upper()
        instance = str(row.get("PHY_STATUS_INSTANCE", ""))
        width = str(row.get("PHY_STATUS_WIDTH_BITS", ""))
        mask = str(row.get("PHY_GATE_REQUIRED_MASK", "")).upper()
        raw = _raw_int(row.get("PHY_STATUS_PROBE0_RAW"))
        if source == "JTAG_PROBE0" and instance == "0" and width == "64" \
                and mask == "000000CF":
            phy_schema_rows += 1
        if raw is None or not _flag(row, "PHY_STATUS_VALID"):
            continue
        phy_valid_rows += 1
        expected = (raw & 0xCF) == 0xCF
        if expected != _flag(row, "PHY_LINK_USABLE"):
            phy_mismatch += 1
    schema_pass = bool(valid_wr) and phy_schema_rows == len(valid_wr) \
        and phy_valid_rows == len(valid_wr) and phy_mismatch == 0
    return {
        "config_pass": config_pass,
        "done_single_reader_pass": done_pass,
        "runtime_identity_pass": identity_pass and set(roles).issuperset({"MASTER", "SLAVE"}),
        "runtime_identity_roles": roles,
        "phy_source_schema_pass": schema_pass,
        "phy_schema_rows": phy_schema_rows,
        "phy_valid_rows": phy_valid_rows,
        "phy_decoder_mismatches": phy_mismatch,
        "limited_source_backed_observation": config_pass and done_pass and schema_pass,
    }


def _bins(rows: Sequence[Dict[str, Any]], cycles: Sequence[Dict[str, Any]],
          base: Optional[int], width: int = 10000) -> List[Dict[str, Any]]:
    if base is None:
        return []
    times = [_host_end(row) for row in rows if _host_end(row) is not None]
    if not times:
        return []
    last = max(times)
    count = max(1, (last - base) // width + 1)
    output: List[Dict[str, Any]] = []
    for index in range(count):
        start = base + index * width
        end = start + width
        main = [row for row in rows if _host_end(row) is not None and start <= _host_end(row) < end]
        crows = [row for row in cycles if _host_end(row) is not None and start <= _host_end(row) < end]
        background = any(
            _flag(row, "HELPER_STATE_VALID") and _flag(row, "HELPER_LOCKED") and
            _flag(row, "WR_CORE_VALID") and _flag(row, "PHY_LINK_USABLE") and
            not _flag(row, "TERMINAL")
            for row in crows
        )
        output.append({
            "BIN_INDEX": index,
            "BIN_START_MS": start - base,
            "BIN_END_MS": end - base,
            "MAIN_UNIQUE_COUNT": len(main),
            "BACKGROUND_VALID": int(background),
        })
    return output


def _classify(result: Dict[str, Any]) -> str:
    if result["shape_errors"]:
        return "DIAGNOSTIC_IMPLEMENTATION_LIMITED"
    gate = result["source_gate"]
    if not gate["config_pass"] or not gate["done_single_reader_pass"] \
            or not gate["phy_source_schema_pass"]:
        return "DIAGNOSTIC_IMPLEMENTATION_LIMITED"
    if result["publication_context_mismatch_count"]:
        return "PUBLICATION_CONTEXT_MISPAIR_CONFIRMED"
    if result["frame_error_count"]:
        return "DIAGNOSTIC_IMPLEMENTATION_LIMITED"
    if result["unique_count"] < 20 or result["unique_span_ms"] < 30000 \
            or result["valid_background_bin_count"] < 3:
        return "INCONCLUSIVE"
    if result["phase_branch_count"] > 0:
        return "PRODUCER_HANDOFF_CONFIRMED"
    return "DIAGNOSTIC_IMPLEMENTATION_LIMITED"


def analyze_text(text: str, source: str = "") -> Dict[str, Any]:
    config = parse_config(text)
    done = parse_done(text)
    raw_main = parse_main(text)
    cycles = parse_cycles(text)
    wr = parse_wr(text)
    errors = parse_errors(text)
    shape_errors: List[str] = []
    if config is None:
        shape_errors.append("CONFIG_MISSING")
    if done is None:
        shape_errors.append("DONE_MISSING")
    for row in raw_main:
        if "BOARD" not in row or "HOST_END_MS" not in row:
            shape_errors.append("MAIN_FIELDS_MISSING")
    for row in wr:
        for key in ("ROLE", "WR_CORE_VALID", "PHY_LINK_USABLE", "ROLE_IDENTITY_VALID",
                    "RESET_FIELDS_VALID", "TERMINAL"):
            if key not in row:
                shape_errors.append("WR_FIELDS_MISSING:" + key)
    normalized: List[Dict[str, Any]] = []
    frame_errors: List[str] = []
    for row in raw_main:
        item, row_errors = _normalize_main(row)
        item["_frame_errors"] = row_errors
        normalized.append(item)
        frame_errors.extend(row_errors)
    dedup = _dedup(normalized)
    unique = dedup["unique"]
    times = [_host_end(row) for row in unique if _host_end(row) is not None]
    first = min(times) if times else None
    last = max(times) if times else None
    span = (last - first) if first is not None and last is not None else 0
    publication_context_mismatch = sum(
        "PUBLICATION_EPOCH_RAW_MISMATCH" in row.get("_frame_errors", []) or
        "PRODUCER_PUBLICATION_EPOCH_MISMATCH" in row.get("_frame_errors", [])
        for row in normalized
    )
    base_times = [
        _host_end(row) for group in (normalized, cycles, wr)
        for row in group if _host_end(row) is not None
    ]
    base = min(base_times) if base_times else None
    bins = _bins(unique, cycles, base)
    valid_bins = [item for item in bins if item["BACKGROUND_VALID"]]
    phase_branch_count = sum(row.get("BRANCH_ID") == 2 for row in unique)
    frequency_branch_count = sum(row.get("BRANCH_ID") == 1 for row in unique)
    update_progress = 0
    sample_progress = 0
    by_board: Dict[str, List[Dict[str, Any]]] = {}
    for row in unique:
        by_board.setdefault(str(row.get("BOARD", "")), []).append(row)
    for board_rows in by_board.values():
        board_rows.sort(key=lambda row: (_host_end(row) is None, _host_end(row) or 0))
        for previous, current in zip(board_rows, board_rows[1:]):
            update_delta, update_ambiguous = _counter_delta(previous.get("UPDATE_ID"), current.get("UPDATE_ID"))
            sample_delta, sample_ambiguous = _counter_delta(previous.get("SAMPLE_N"), current.get("SAMPLE_N"))
            if update_delta is not None and update_delta > 0 and not update_ambiguous:
                update_progress += 1
            if sample_delta is not None and sample_delta > 0 and not sample_ambiguous:
                sample_progress += 1
    step5_runtime_ready = bool(done) and _int(done.get("SESSION_ELAPSED_MS")) is not None \
        and _int(done.get("SESSION_ELAPSED_MS")) >= 120000 \
        and str(done.get("STOP_REASON", "NONE")).upper() == "NONE"
    result: Dict[str, Any] = {
        "format": "step5-f4j-main-producer-handoff-audit-v1",
        "source": source,
        "input_mode": "F4J_HARDWARE_CAPTURE",
        "config": config,
        "done": done,
        "source_gate": _source_gate(config, done, wr),
        "shape_errors": sorted(set(shape_errors)),
        "observed_stop_reasons": sorted({
            reason for row in cycles for reason in str(row.get("STOP_REASON", "NONE")).split(",")
            if reason and reason.upper() != "NONE"
        } | {str(row.get("ERROR", "")) for row in errors if row.get("ERROR")}),
        "raw_main_count": len(raw_main),
        "valid_frame_count": sum(not row.get("_frame_errors") for row in normalized),
        "frame_error_count": len(frame_errors),
        "frame_error_kinds": dict(Counter(frame_errors)),
        "publication_context_mismatch_count": publication_context_mismatch,
        "unique_count": len(unique),
        "duplicate_count": dedup["duplicate_count"],
        "unique_first_ms": first,
        "unique_last_ms": last,
        "unique_span_ms": span,
        "frequency_branch_count": frequency_branch_count,
        "phase_branch_count": phase_branch_count,
        "update_progress_count": update_progress,
        "sample_progress_count": sample_progress,
        "valid_background_bin_count": len(valid_bins),
        "bin_records": bins,
        "required_unique_count": 20,
        "required_span_ms": 30000,
        "required_background_bins": 3,
        "coverage_pass": bool(len(unique) >= 20 and span >= 30000 and len(valid_bins) >= 3),
        "step5_runtime_ready": step5_runtime_ready,
        "main_records": normalized,
        "unique_records": unique,
        "cycle_records": cycles,
        "wr_records": wr,
        "error_records": errors,
        "step5_complete": False,
        "step5_pass": False,
        "merge_approved": False,
    }
    result["classification"] = _classify(result)
    result["diagnostic_pass"] = result["classification"] in {
        "PRODUCER_HANDOFF_CONFIRMED",
        "PUBLICATION_CONTEXT_MISPAIR_CONFIRMED",
        "PHASE_CAPTURE_ERROR_PERSISTS",
    }
    # F4J never grants Step5 by itself: it only establishes whether the
    # producer/publication evidence is trustworthy enough for the next test.
    result["step5_pass"] = False
    return result


def _write_csv(path: Path, rows: Iterable[Dict[str, Any]]) -> None:
    materialized = list(rows)
    fields: List[str] = []
    for row in materialized:
        for key in row:
            if key not in fields and not key.startswith("_"):
                fields.append(key)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(materialized)


def write_outputs(result: Dict[str, Any], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    _write_csv(output_dir / "main_producer.csv", result["main_records"])
    _write_csv(output_dir / "main_producer_unique.csv", result["unique_records"])
    _write_csv(output_dir / "bins.csv", result["bin_records"])
    _write_csv(output_dir / "cycles.csv", result["cycle_records"])
    _write_csv(output_dir / "wr_core.csv", result["wr_records"])
    compact = {key: value for key, value in result.items()
               if not key.endswith("_records")}
    (output_dir / "verdict.json").write_text(
        json.dumps(compact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    text = args.log.read_text(encoding="utf-8", errors="replace")
    result = analyze_text(text, str(args.log))
    if args.output_dir:
        write_outputs(result, args.output_dir)
    print(json.dumps({
        "classification": result["classification"],
        "diagnostic_pass": result["diagnostic_pass"],
        "unique": result["unique_count"],
        "span_ms": result["unique_span_ms"],
        "valid_background_bins": result["valid_background_bin_count"],
        "producer_handoff": result["classification"] == "PRODUCER_HANDOFF_CONFIRMED",
        "step5_pass": False,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
