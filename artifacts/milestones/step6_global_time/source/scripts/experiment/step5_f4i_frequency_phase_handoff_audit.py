#!/usr/bin/env python3
"""Replay the F4I Main frequency/phase handoff audit.

F4I is intentionally conservative.  It keeps the published Main trace and
the Main detector stream separate, deduplicates the trace by
(publication_epoch, sample_n), and never treats PI_X or a sparse modulo phase
sample as proof of the producer's control branch.  The same analyzer can
replay the previous F4H capture as an offline baseline, but that baseline is
never upgraded into an F4I hardware result.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from statistics import mean, median
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts" / "analysis"))
sys.path.insert(0, str(REPO_ROOT / "scripts" / "experiment"))

from step5_replay import parse_key_values  # noqa: E402
from step5_f4g_compact_progress_window import (  # noqa: E402
    _flag,
    _num,
    _text,
    parse_cycles as parse_f4g_cycles,
    parse_detector as parse_f4g_detector,
    parse_demand as parse_f4g_demand,
    parse_helper as parse_f4g_helper,
    parse_helper_state as parse_f4g_helper_state,
    parse_l2 as parse_f4g_l2,
    parse_main as parse_f4g_main,
    parse_master_samples as parse_f4g_master,
    parse_position as parse_f4g_position,
    parse_service as parse_f4g_service,
    parse_wr as parse_f4g_wr,
)


F4I_CONFIG = "STEP5_F4I_CONFIG"
F4I_DONE = "STEP5_F4I_DONE"
F4I_MAIN = "STEP5_F4I_MAIN_TRACE"
F4I_METADATA = "STEP5_F4I_MAIN_METADATA"
F4I_SERVICE = "STEP5_F4I_SERVICE_COUNTER"
F4I_CYCLE = "STEP5_F4I_CYCLE"
F4I_WR = "STEP5_F4I_WR_CORE"
F4I_MASTER = "STEP5_F4I_MASTER_SAMPLE"
F4I_ROLE = "STEP5_F4I_ROLE_SUMMARY"
F4I_ERROR = "STEP5_F4I_CONTEXT_ERROR"

INVALID = {"", "INVALID", "UNKNOWN", "NEVER", "NA", "N/A", "TIMEOUT",
           "NOT_MEASURED"}
HEX_RE = re.compile(r"^[0-9A-Fa-f]+$")
UINT32 = 1 << 32
UINT32_MASK = UINT32 - 1
HALF32 = 1 << 31


def _records(text: str, prefix: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for line in text.splitlines():
        if line.startswith(prefix + " "):
            row = parse_key_values(line)
            row["_line"] = line.rstrip("\r\n")
            rows.append(row)
    return rows


def _first_or_last(rows: Sequence[Dict[str, Any]], last: bool = False) -> Optional[Dict[str, Any]]:
    if not rows:
        return None
    return rows[-1] if last else rows[0]


def _host_end(row: Dict[str, Any]) -> Optional[int]:
    return _num(row.get("HOST_END_MS"))


def _host_start(row: Dict[str, Any]) -> Optional[int]:
    return _num(row.get("HOST_START_MS"))


def _int(value: Any) -> Optional[int]:
    return _num(value)


def _hex_int(value: Any) -> Optional[int]:
    if not isinstance(value, str):
        return None
    value = value.strip()
    if not HEX_RE.fullmatch(value):
        return None
    try:
        return int(value, 16)
    except ValueError:
        return None


def _state_bit(state: Optional[int], bit: int) -> Optional[int]:
    return None if state is None else (state >> bit) & 1


def _domain_from_state(state: Optional[int]) -> str:
    bit = _state_bit(state, 1)
    if bit is None:
        return "UNKNOWN"
    return "PHASE" if bit else "FREQUENCY"


def _sign(value: Optional[int]) -> str:
    if value is None:
        return "UNKNOWN"
    if value > 0:
        return "POSITIVE"
    if value < 0:
        return "NEGATIVE"
    return "ZERO"


def _counter_delta(previous: Optional[int], current: Optional[int]) -> Tuple[Optional[int], bool]:
    if previous is None or current is None:
        return None, False
    delta = (current - previous) & UINT32_MASK
    if delta > HALF32:
        return None, True
    return delta, False


def parse_f4i_config(text: str) -> Optional[Dict[str, Any]]:
    return _first_or_last(_records(text, F4I_CONFIG))


def parse_f4i_done(text: str) -> Optional[Dict[str, Any]]:
    return _first_or_last(_records(text, F4I_DONE), last=True)


def parse_f4i_main(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4I_MAIN)


def parse_f4i_metadata(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4I_METADATA)


def parse_f4i_service(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4I_SERVICE)


def parse_f4i_cycles(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4I_CYCLE)


def parse_f4i_wr(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4I_WR)


def parse_f4i_master(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4I_MASTER)


def parse_f4i_errors(text: str) -> List[Dict[str, Any]]:
    return _records(text, F4I_ERROR)


def _normalize_main(row: Dict[str, Any], source_family: str) -> Dict[str, Any]:
    """Normalize F4I and F4H Main rows without merging detector state."""
    if source_family == "F4I":
        epoch_before = _hex_int(row.get("MAIN_TRACE_EPOCH_RAW_BEFORE"))
        epoch_after = _hex_int(row.get("MAIN_TRACE_EPOCH_RAW_AFTER"))
        epoch = _int(row.get("MAIN_PUBLICATION_EPOCH"))
        sample_n = _int(row.get("MAIN_SAMPLE_N"))
        publication_coherent = _flag(row, "PUBLICATION_COHERENT")
        trace_valid = _flag(row, "MAIN_TRACE_VALID") and publication_coherent
        main_state = _int(row.get("MAIN_STATE"))
        dref = _int(row.get("MAIN_DREF_DT"))
        dout = _int(row.get("MAIN_DOUT_DT"))
        freq_error = _int(row.get("MAIN_FREQ_ERROR"))
        prelock_error = _int(row.get("MAIN_PRELOCK_ERROR"))
        pi_x = _int(row.get("MAIN_PI_X"))
        pi_output = _int(row.get("MAIN_PI_OUTPUT"))
        clamp_side = _int(row.get("MAIN_PI_CLAMP_SIDE"))
        magic = _int(row.get("MAIN_TRACE_MAGIC"))
        raw_pair = _text(row, "FREQ_ERROR_PAIR_CHECK").upper()
        pair_check = raw_pair if raw_pair in {"PASS", "FAIL"} else None
    else:
        epoch_before = _hex_int(row.get("MAIN_EPOCH_RAW_BEFORE"))
        epoch_after = _hex_int(row.get("MAIN_EPOCH_RAW_AFTER"))
        epoch = _int(row.get("MAIN_EPOCH"))
        sample_n = _int(row.get("MAIN_SAMPLE_N"))
        publication_coherent = bool(
            epoch_before is not None
            and epoch_after is not None
            and epoch_before == epoch_after
            and epoch_after % 2 == 0
            and _flag(row, "MAIN_CORE_VALID")
        )
        trace_valid = _flag(row, "MAIN_CORE_VALID") and publication_coherent
        main_state = _int(row.get("MAIN_STATE"))
        dref = _int(row.get("MAIN_DREF_DT"))
        dout = _int(row.get("MAIN_DOUT_DT"))
        freq_error = _int(row.get("MAIN_FREQ_ERROR"))
        prelock_error = None
        pi_x = _int(row.get("MAIN_PI_X"))
        pi_output = _int(row.get("MAIN_PI_OUTPUT"))
        clamp_side = _int(row.get("MAIN_PI_CLAMP_SIDE"))
        magic = _int(row.get("MAIN_MAGIC"))
        pair_check = None

    if dref is not None and dout is not None and freq_error is not None:
        pair_check = "PASS" if freq_error == dout - dref else "FAIL"

    normalized: Dict[str, Any] = {
        "SOURCE_FAMILY": source_family,
        "BOARD": _text(row, "BOARD"),
        "CYCLE": _int(row.get("CYCLE")),
        "HOST_START_MS": _host_start(row),
        "HOST_END_MS": _host_end(row),
        "MAIN_TRACE_VALID": int(trace_valid),
        "PUBLICATION_COHERENT": int(publication_coherent),
        "MAIN_TRACE_EPOCH_RAW_BEFORE": epoch_before,
        "MAIN_TRACE_EPOCH_RAW_AFTER": epoch_after,
        "MAIN_PUBLICATION_EPOCH": epoch,
        "MAIN_SAMPLE_N": sample_n,
        "MAIN_STATE": main_state,
        "MAIN_ENABLED": _state_bit(main_state, 0),
        "MAIN_FREQ_LOCKED": _state_bit(main_state, 1),
        "MAIN_PHASE_LOCKED": _state_bit(main_state, 2),
        "MAIN_LOCKED": _state_bit(main_state, 3),
        "MAIN_DOMAIN": _domain_from_state(main_state),
        "MAIN_DREF_DT": dref,
        "MAIN_DOUT_DT": dout,
        "MAIN_FREQ_ERROR": freq_error,
        "MAIN_PRELOCK_ERROR": prelock_error,
        "MAIN_PI_X": pi_x,
        "MAIN_PI_OUTPUT": pi_output,
        "MAIN_PI_CLAMP_SIDE": clamp_side,
        "MAIN_TRACE_MAGIC": magic,
        "FREQ_ERROR_SIGN": _sign(freq_error),
        "FREQ_ERROR_PAIR_CHECK": pair_check or "UNKNOWN",
        "PRODUCER_DOMAIN_COHERENCE": "UNPROVEN",
        "MAIN_TRACE_UNIQUE": 0,
        "TRACE_DEDUP_SKIPPED": 0,
        "MAIN_SAMPLE_N_DELTA": None,
        "MAIN_SAMPLE_N_ADVANCED": 0,
        "MAIN_SAMPLE_N_AMBIGUOUS": 0,
        "MAIN_PUBLICATION_STALE": 0,
        "_line": row.get("_line", ""),
    }
    if source_family == "F4I":
        normalized["MAIN_PRELOCK_ERROR"] = prelock_error
    return normalized


def _dedup_main(rows: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    indexed = list(enumerate(rows))
    indexed.sort(key=lambda item: (
        _host_end(item[1]) is None,
        _host_end(item[1]) if _host_end(item[1]) is not None else item[0],
        item[0],
    ))
    last_key: Dict[str, Tuple[int, int]] = {}
    last_sample: Dict[str, int] = {}
    last_epoch: Dict[str, int] = {}
    unique: List[Dict[str, Any]] = []
    duplicate_count = 0
    stale_count = 0
    ambiguous_count = 0
    for _, row in indexed:
        board = str(row.get("BOARD", ""))
        if not row.get("MAIN_TRACE_VALID") or not row.get("PUBLICATION_COHERENT"):
            continue
        epoch = row.get("MAIN_PUBLICATION_EPOCH")
        sample_n = row.get("MAIN_SAMPLE_N")
        if not isinstance(epoch, int) or not isinstance(sample_n, int):
            continue
        key = (epoch, sample_n)
        if last_key.get(board) == key:
            row["TRACE_DEDUP_SKIPPED"] = 1
            duplicate_count += 1
            continue
        row["MAIN_TRACE_UNIQUE"] = 1
        if board in last_sample:
            delta, ambiguous = _counter_delta(last_sample[board], sample_n)
            if ambiguous:
                row["MAIN_SAMPLE_N_AMBIGUOUS"] = 1
                ambiguous_count += 1
            elif delta is not None:
                row["MAIN_SAMPLE_N_DELTA"] = delta
                row["MAIN_SAMPLE_N_ADVANCED"] = int(delta > 0)
            if sample_n == last_sample[board] and epoch != last_epoch[board]:
                row["MAIN_PUBLICATION_STALE"] = 1
                stale_count += 1
        last_key[board] = key
        last_sample[board] = sample_n
        last_epoch[board] = epoch
        unique.append(row)
    return {
        "all_rows": list(rows),
        "unique_rows": unique,
        "duplicate_count": duplicate_count,
        "stale_count": stale_count,
        "ambiguous_count": ambiguous_count,
    }


def _percentile(values: Sequence[int], fraction: float) -> Optional[float]:
    if not values:
        return None
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * weight


def _numeric_stats(rows: Sequence[Dict[str, Any]], key: str,
                   *, absolute_gt: Optional[int] = None) -> Dict[str, Any]:
    values = [value for value in (_int(row.get(key)) for row in rows)
              if value is not None]
    positive = sum(value > 0 for value in values)
    negative = sum(value < 0 for value in values)
    zero = sum(value == 0 for value in values)
    result: Dict[str, Any] = {
        "count": len(values),
        "min": min(values) if values else None,
        "max": max(values) if values else None,
        "mean": mean(values) if values else None,
        "median": median(values) if values else None,
        "p25": _percentile(values, 0.25),
        "p75": _percentile(values, 0.75),
        "positive_count": positive,
        "negative_count": negative,
        "zero_count": zero,
        "positive_ratio": positive / len(values) if values else None,
        "negative_ratio": negative / len(values) if values else None,
        "zero_ratio": zero / len(values) if values else None,
    }
    if absolute_gt is not None:
        count = sum(abs(value) > absolute_gt for value in values)
        result["absolute_gt_threshold"] = absolute_gt
        result["absolute_gt_count"] = count
        result["absolute_gt_ratio"] = count / len(values) if values else None
    return result


def _domain_transitions(rows: Sequence[Dict[str, Any]]) -> List[Dict[str, Any]]:
    transitions: List[Dict[str, Any]] = []
    by_board: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for row in rows:
        by_board[str(row.get("BOARD", ""))].append(row)
    for board, board_rows in by_board.items():
        board_rows.sort(key=lambda row: (_host_end(row) is None,
                                         _host_end(row) or 0))
        previous: Optional[Dict[str, Any]] = None
        for row in board_rows:
            domain = row.get("MAIN_DOMAIN")
            if previous is not None and domain in {"PHASE", "FREQUENCY"} \
                    and previous.get("MAIN_DOMAIN") in {"PHASE", "FREQUENCY"} \
                    and domain != previous.get("MAIN_DOMAIN"):
                transitions.append({
                    "BOARD": board,
                    "FROM_DOMAIN": previous.get("MAIN_DOMAIN"),
                    "TO_DOMAIN": domain,
                    "HOST_END_MS": _host_end(row),
                    "FROM_HOST_END_MS": _host_end(previous),
                    "MAIN_PUBLICATION_EPOCH": row.get("MAIN_PUBLICATION_EPOCH"),
                    "MAIN_SAMPLE_N": row.get("MAIN_SAMPLE_N"),
                    "MAIN_FREQ_ERROR": row.get("MAIN_FREQ_ERROR"),
                    "PI_X_CLASSIFICATION": (
                        "PHASE_CONTEXT_OBSERVED" if domain == "PHASE"
                        else "FREQUENCY_CONTEXT_OBSERVED"
                    ),
                })
            previous = row
    return transitions


def _detector_summary(rows: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    valid = [row for row in rows if _flag(row, "MAIN_DETECTOR_VALID")]
    freq_locked = sum(_flag(row, "MAIN_FREQ_LOCKED") for row in valid)
    phase_locked = sum(_flag(row, "MAIN_PHASE_LOCKED") for row in valid)
    return {
        "row_count": len(rows),
        "valid_count": len(valid),
        "frequency_locked_count": freq_locked,
        "phase_locked_count": phase_locked,
        "frequency_locked_ratio": freq_locked / len(valid) if valid else None,
        "phase_locked_ratio": phase_locked / len(valid) if valid else None,
        "host_start_ms": min((_host_start(row) for row in valid
                               if _host_start(row) is not None), default=None),
        "host_end_ms": max((_host_end(row) for row in valid
                             if _host_end(row) is not None), default=None),
    }


def _service_delta(rows: Sequence[Dict[str, Any]], key: str) -> Dict[str, Any]:
    values = sorted(((_host_end(row), _int(row.get(key))) for row in rows
                     if _host_end(row) is not None and _int(row.get(key)) is not None),
                    key=lambda item: item[0])
    deltas: List[int] = []
    ambiguous = 0
    for previous, current in zip(values, values[1:]):
        if current[0] <= previous[0]:
            continue
        delta, is_ambiguous = _counter_delta(previous[1], current[1])
        if is_ambiguous:
            ambiguous += 1
        elif delta is not None:
            deltas.append(delta)
    return {
        "samples": len(values),
        "delta_samples": len(deltas),
        "delta_sum": sum(deltas),
        "ambiguous": ambiguous,
        "window": "TRUSTED" if deltas and not ambiguous else "UNKNOWN",
    }


def _source_gate(config: Optional[Dict[str, Any]], done: Optional[Dict[str, Any]],
                 wr_rows: Sequence[Dict[str, Any]], input_mode: str) -> Dict[str, Any]:
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
    phy_gate_pass_rows = 0
    phy_gate_fail_rows = 0
    phy_unknown_rows = 0
    decoder_mismatches = 0
    for row in valid_wr:
        source = str(row.get("PHY_STATUS_SOURCE", "")).upper()
        instance = str(row.get("PHY_STATUS_INSTANCE", ""))
        width = str(row.get("PHY_STATUS_WIDTH_BITS", ""))
        mask = str(row.get("PHY_GATE_REQUIRED_MASK", "")).upper()
        raw = _hex_int(row.get("PHY_STATUS_PROBE0_RAW"))
        schema_ok = source == "JTAG_PROBE0" and instance == "0" \
            and width == "64" and mask == "000000CF"
        if schema_ok:
            phy_schema_rows += 1
        if raw is None or not _flag(row, "PHY_STATUS_VALID"):
            phy_unknown_rows += 1
            continue
        phy_valid_rows += 1
        expected_gate = (raw & 0xCF) == 0xCF
        observed_gate = _flag(row, "PHY_LINK_USABLE")
        if expected_gate:
            phy_gate_pass_rows += 1
        else:
            phy_gate_fail_rows += 1
        if expected_gate != observed_gate:
            decoder_mismatches += 1
    source_schema_pass = bool(valid_wr) and phy_schema_rows == len(valid_wr) \
        and phy_valid_rows == len(valid_wr) and decoder_mismatches == 0
    return {
        "input_mode": input_mode,
        "config_pass": config_pass,
        "done_single_reader_pass": done_pass,
        "source_contract_verified": bool(
            config and str(config.get("SOURCE_CONTRACT_VERIFIED", "")).upper() == "YES"
        ),
        "runtime_identity_pass": identity_pass and set(roles).issuperset({"MASTER", "SLAVE"}),
        "runtime_identity_roles": roles,
        "phy_source_schema_pass": source_schema_pass,
        "phy_schema_rows": phy_schema_rows,
        "phy_valid_rows": phy_valid_rows,
        "phy_gate_pass_rows": phy_gate_pass_rows,
        "phy_gate_fail_rows": phy_gate_fail_rows,
        "phy_unknown_rows": phy_unknown_rows,
        "phy_decoder_mismatches": decoder_mismatches,
        "limited_source_backed_observation": config_pass and done_pass and source_schema_pass,
    }


def _relative_rows(rows: Sequence[Dict[str, Any]], base: int,
                   start: int, end: int) -> List[Dict[str, Any]]:
    output: List[Dict[str, Any]] = []
    for row in rows:
        timestamp = _host_end(row)
        if timestamp is not None and start <= timestamp - base < end:
            output.append(row)
    return output


def _make_bins(main_unique: Sequence[Dict[str, Any]], detector: Sequence[Dict[str, Any]],
               helper: Sequence[Dict[str, Any]], helper_state: Sequence[Dict[str, Any]],
               position: Sequence[Dict[str, Any]], demand: Sequence[Dict[str, Any]],
               service: Sequence[Dict[str, Any]], cycles: Sequence[Dict[str, Any]],
               wr: Sequence[Dict[str, Any]], base: int, width: int = 10000) -> List[Dict[str, Any]]:
    all_rows: List[Dict[str, Any]] = []
    for group in (main_unique, detector, helper, helper_state, position,
                  demand, service, cycles, wr):
        all_rows.extend(group)
    timestamps = [_host_end(row) for row in all_rows if _host_end(row) is not None]
    if not timestamps:
        return []
    last = max(timestamps)
    count = max(1, (last - base) // width + 1)
    output: List[Dict[str, Any]] = []
    for index in range(count):
        start = index * width
        end = (index + 1) * width
        m_rows = _relative_rows(main_unique, base, start, end)
        d_rows = _relative_rows(detector, base, start, end)
        h_rows = _relative_rows(helper, base, start, end)
        hs_rows = _relative_rows(helper_state, base, start, end)
        p_rows = _relative_rows(position, base, start, end)
        q_rows = _relative_rows(demand, base, start, end)
        s_rows = _relative_rows(service, base, start, end)
        c_rows = _relative_rows(cycles, base, start, end)
        w_rows = _relative_rows(wr, base, start, end)
        completed = [row for row in s_rows
                     if str(row.get("COUNTER_GROUP", "")).upper() == "COMPLETED"]
        started = [row for row in s_rows
                   if str(row.get("COUNTER_GROUP", "")).upper() == "START"]
        completed_main = _service_delta(completed, "MAIN_VALUE")
        completed_helper = _service_delta(completed, "HELPER_VALUE")
        started_main = _service_delta(started, "MAIN_VALUE")
        started_helper = _service_delta(started, "HELPER_VALUE")
        helper_locked = sum(_flag(row, "HELPER_LOCKED") for row in hs_rows)
        helper_valid = sum(_flag(row, "HELPER_STATE_VALID") for row in hs_rows)
        helper_core_valid = sum(_flag(row, "ACCEPTED") for row in h_rows)
        if c_rows:
            helper_core_valid = sum(_flag(row, "HELPER_CORE_VALID") for row in c_rows)
        wr_valid = sum(_flag(row, "WR_CORE_VALID") and
                       _flag(row, "PHY_LINK_USABLE") and
                       not _flag(row, "TERMINAL") for row in w_rows)
        phase_rows = [row for row in m_rows if row.get("MAIN_DOMAIN") == "PHASE"]
        frequency_rows = [row for row in m_rows if row.get("MAIN_DOMAIN") == "FREQUENCY"]
        phase_locked = sum(row.get("MAIN_PHASE_LOCKED") == 1 for row in m_rows)
        progress = sum(row.get("MAIN_SAMPLE_N_ADVANCED") == 1 for row in m_rows)
        residual_present = sum(_flag(row, "HELPER_RESIDUAL_PRESENT") for row in p_rows)
        helper_pending = sum(_flag(row, "HELPER_PENDING") for row in q_rows)
        main_pending = sum(_flag(row, "MAIN_PENDING") for row in q_rows)
        stop_rows = [str(row.get("STOP_REASON", "NONE")) for row in c_rows]
        terminal = sum(_flag(row, "TERMINAL") for row in w_rows)
        background_valid = int(bool(m_rows and helper_core_valid and helper_valid and
                                    helper_locked and wr_valid and not terminal))
        output.append({
            "BIN_INDEX": index,
            "BIN_START_MS": start,
            "BIN_END_MS": end,
            "MAIN_UNIQUE_COUNT": len(m_rows),
            "MAIN_PROGRESS_COUNT": progress,
            "MAIN_PHASE_DOMAIN_COUNT": len(phase_rows),
            "MAIN_FREQUENCY_DOMAIN_COUNT": len(frequency_rows),
            "MAIN_PHASE_LOCKED_COUNT": phase_locked,
            "DETECTOR_ROW_COUNT": len(d_rows),
            "HELPER_CORE_VALID_COUNT": helper_core_valid,
            "HELPER_STATE_VALID_COUNT": helper_valid,
            "HELPER_LOCKED_COUNT": helper_locked,
            "HELPER_RESIDUAL_PRESENT_COUNT": residual_present,
            "HELPER_PENDING_COUNT": helper_pending,
            "MAIN_PENDING_COUNT": main_pending,
            "WR_PHY_VALID_COUNT": wr_valid,
            "TERMINAL_COUNT": terminal,
            "SERVICE_ROW_COUNT": len(s_rows),
            "MAIN_COMPLETED_DELTA": completed_main["delta_sum"],
            "HELPER_COMPLETED_DELTA": completed_helper["delta_sum"],
            "MAIN_START_DELTA": started_main["delta_sum"],
            "HELPER_START_DELTA": started_helper["delta_sum"],
            "MAIN_COMPLETED_SERVICE_WINDOW": completed_main["window"],
            "HELPER_COMPLETED_SERVICE_WINDOW": completed_helper["window"],
            "SERVICE_AMBIGUOUS_COUNT": completed_main["ambiguous"] + completed_helper["ambiguous"] +
            started_main["ambiguous"] + started_helper["ambiguous"],
            "STOP_REASON_OBSERVED": ",".join(sorted(set(stop_rows))) if stop_rows else "NONE",
            "BACKGROUND_VALID": background_valid,
        })
    return output


def _shape_errors(source_family: str, main: Sequence[Dict[str, Any]],
                  wr: Sequence[Dict[str, Any]], config: Optional[Dict[str, Any]],
                  done: Optional[Dict[str, Any]]) -> List[str]:
    issues: List[str] = []
    required_main = {"BOARD", "HOST_END_MS", "MAIN_TRACE_VALID",
                     "PUBLICATION_COHERENT", "MAIN_PUBLICATION_EPOCH",
                     "MAIN_SAMPLE_N", "MAIN_STATE", "MAIN_DOMAIN",
                     "MAIN_FREQ_ERROR", "MAIN_PI_X", "MAIN_PI_OUTPUT"}
    for row in main:
        missing = sorted(key for key in required_main if key not in row)
        if missing:
            issues.append("MAIN_FIELDS_MISSING:" + ",".join(missing))
    required_wr = {"BOARD", "ROLE", "WR_CORE_VALID", "PHY_LINK_USABLE",
                   "ROLE_IDENTITY_VALID", "RESET_FIELDS_VALID", "TERMINAL"}
    for row in wr:
        missing = sorted(key for key in required_wr if key not in row)
        if missing:
            issues.append("WR_FIELDS_MISSING:" + ",".join(missing))
    if config is None:
        issues.append("CONFIG_MISSING")
    if done is None:
        issues.append("DONE_MISSING")
    if source_family not in {"F4I", "F4H"}:
        issues.append("SOURCE_FAMILY_UNKNOWN")
    return sorted(set(issues))


def _classify(result: Dict[str, Any]) -> str:
    done = result.get("done") or {}
    stop = str(done.get("STOP_REASON", "NONE")).upper()
    observed_stops = " ".join(str(item) for item in result.get("observed_stop_reasons", []))
    all_stops = f"{stop} {observed_stops}"
    if "RESET_OR_GENERATION_CHANGE" in all_stops:
        return "RESET_OR_GENERATION_CHANGE"
    if "WR_SESSION_ENDED" in all_stops:
        return "WR_SESSION_ENDED"
    if "HELPER_REGRESSION" in all_stops:
        return "HELPER_REGRESSION"
    if "DATA_UNRESOLVED" in all_stops:
        return "DATA_UNRESOLVED"
    if result["shape_errors"]:
        return "SOURCE_COHERENCE_LIMITED"
    gate = result["source_gate"]
    if not gate["config_pass"] or not gate["done_single_reader_pass"]:
        return "SOURCE_COHERENCE_LIMITED"
    if not gate["phy_source_schema_pass"]:
        return "SOURCE_COHERENCE_LIMITED"
    # The legacy F4H core record did not publish dref/dout.  Its frequency
    # error can be re-counted as a baseline, but it cannot satisfy this
    # experiment's producer-pair check and must not be upgraded into an F4I
    # handoff claim.
    if result["source_family"] == "F4H" and result["pair_check"]["unknown_count"]:
        return "SOURCE_COHERENCE_LIMITED"
    if result["pair_check"]["fail_count"]:
        return "SOURCE_COHERENCE_LIMITED"
    if result["main_unique_count"] < 20 or result["main_unique_span_ms"] < 30000:
        return "INCONCLUSIVE"
    if result["valid_background_bin_count"] < 3:
        return "INCONCLUSIVE"
    if (result["visible_handoff_count"] >= 2 and
            result["frequency_error_nonzero_ratio"] is not None and
            result["frequency_error_nonzero_ratio"] >= 0.8 and
            result["main_phase_locked_count"] == 0):
        return "RESIDUAL_FREQUENCY_WITH_VISIBLE_HANDOFFS"
    if (result["main_phase_domain_ratio"] is not None and
            result["main_phase_domain_ratio"] >= 0.8 and
            result["main_phase_locked_count"] == 0):
        return "PHASE_CONTEXT_PERSISTENT_WITHOUT_LOCK"
    return "INCONCLUSIVE"


def analyze_text(text: str, source: str = "") -> Dict[str, Any]:
    f4i_config = parse_f4i_config(text)
    f4i_done = parse_f4i_done(text)
    f4i_main = parse_f4i_main(text)
    f4i_metadata = parse_f4i_metadata(text)
    f4i_service = parse_f4i_service(text)
    f4i_cycles = parse_f4i_cycles(text)
    f4i_wr = parse_f4i_wr(text)
    f4i_master = parse_f4i_master(text)
    f4i_errors = parse_f4i_errors(text)

    source_family = "F4I" if f4i_main or f4i_config else "F4H"
    if source_family == "F4I":
        config = f4i_config
        done = f4i_done
        raw_main = f4i_main
        wr = f4i_wr
        cycles = f4i_cycles
        master = f4i_master
        input_mode = "F4I_HARDWARE_CAPTURE"
    else:
        f4g_config = _first_or_last(_records(text, "STEP5_F4G_CONFIG"))
        f4g_done = _first_or_last(_records(text, "STEP5_F4G_DONE"), last=True)
        config = f4g_config
        done = f4g_done
        raw_main = parse_f4g_main(text)
        wr = parse_f4g_wr(text)
        cycles = parse_f4g_cycles(text)
        master = parse_f4g_master(text)
        input_mode = "F4H_BASELINE_REPLAY"

    main = [_normalize_main(row, source_family) for row in raw_main]
    dedup = _dedup_main(main)
    unique_main = dedup["unique_rows"]

    # F4I reuses the audited F4G Helper/position/L2 record format.  F4I
    # service rows are added to that stream, without mixing detector rows into
    # the Main trace.
    helper = parse_f4g_helper(text)
    helper_state = parse_f4g_helper_state(text)
    position = parse_f4g_position(text)
    demand = parse_f4g_demand(text)
    l2 = parse_f4g_l2(text)
    service = parse_f4g_service(text) + f4i_service
    detector = parse_f4g_detector(text)
    errors = f4i_errors

    # Avoid counting an accidentally duplicated service line twice, while
    # retaining all unique raw observations for inspection.
    seen_service: set[Tuple[str, str, str, str, str]] = set()
    service_unique: List[Dict[str, Any]] = []
    for row in service:
        key = (str(row.get("BOARD", "")), str(row.get("COUNTER_GROUP", "")),
               str(row.get("HOST_END_MS", "")), str(row.get("MAIN_VALUE", "")),
               str(row.get("HELPER_VALUE", "")))
        if key in seen_service:
            continue
        seen_service.add(key)
        service_unique.append(row)
    service = service_unique

    all_rows = []
    for group in (main, detector, helper, helper_state, position, demand,
                  l2, service, wr, cycles, master, errors):
        all_rows.extend(group)
    timestamps = [_host_end(row) for row in all_rows if _host_end(row) is not None]
    host_base = min(timestamps) if timestamps else None
    host_last = max(timestamps) if timestamps else None
    main_times = [_host_end(row) for row in unique_main if _host_end(row) is not None]
    main_first = min(main_times) if main_times else None
    main_last = max(main_times) if main_times else None
    main_span = (main_last - main_first) if main_first is not None and main_last is not None else 0

    transitions = _domain_transitions(unique_main)
    visible_handoffs = sum(
        {row.get("FROM_DOMAIN"), row.get("TO_DOMAIN")} == {"PHASE", "FREQUENCY"}
        for row in transitions
    )
    freq_stats = _numeric_stats(unique_main, "MAIN_FREQ_ERROR", absolute_gt=50)
    pair_pass = sum(row.get("FREQ_ERROR_PAIR_CHECK") == "PASS" for row in unique_main)
    pair_fail = sum(row.get("FREQ_ERROR_PAIR_CHECK") == "FAIL" for row in unique_main)
    pair_unknown = len(unique_main) - pair_pass - pair_fail
    nonzero = sum((_int(row.get("MAIN_FREQ_ERROR")) is not None and
                   _int(row.get("MAIN_FREQ_ERROR")) != 0) for row in unique_main)
    valid_freq_count = sum(_int(row.get("MAIN_FREQ_ERROR")) is not None for row in unique_main)
    phase_domain_count = sum(row.get("MAIN_DOMAIN") == "PHASE" for row in unique_main)
    phase_locked_count = sum(row.get("MAIN_PHASE_LOCKED") == 1 for row in unique_main)
    progress_count = sum(row.get("MAIN_SAMPLE_N_ADVANCED") == 1 for row in unique_main)
    valid_background_rows = []
    base_for_bins = host_base if host_base is not None else 0
    bins = _make_bins(unique_main, detector, helper, helper_state, position,
                      demand, service, cycles, wr, base_for_bins)
    valid_background_rows = [row for row in bins if row["BACKGROUND_VALID"]]
    observed_stop_reasons = sorted({
        reason for row in cycles for reason in str(row.get("STOP_REASON", "NONE")).split(",")
        if reason and reason != "NONE"
    } | {
        reason for row in errors for reason in str(row.get("ERROR", "")).split(",")
        if reason
    })

    result: Dict[str, Any] = {
        "format": "step5-f4i-frequency-phase-handoff-audit-v1",
        "source": source,
        "input_mode": input_mode,
        "source_family": source_family,
        "config": config,
        "done": done,
        "metadata_records": f4i_metadata,
        "source_gate": _source_gate(config, done, wr, input_mode),
        "shape_errors": _shape_errors(source_family, main, wr, config, done),
        "observed_stop_reasons": observed_stop_reasons,
        "main_trace_count": len(main),
        "main_trace_valid_count": sum(_flag(row, "MAIN_TRACE_VALID") for row in main),
        "main_unique_count": len(unique_main),
        "main_duplicate_count": dedup["duplicate_count"],
        "main_stale_publication_count": dedup["stale_count"],
        "main_sample_ambiguous_count": dedup["ambiguous_count"],
        "main_unique_first_ms": main_first,
        "main_unique_last_ms": main_last,
        "main_unique_span_ms": main_span,
        "host_base_ms": host_base,
        "host_last_ms": host_last,
        "host_span_ms": (host_last - host_base) if host_base is not None and host_last is not None else 0,
        "main_progress_count": progress_count,
        "main_domain_counts": {
            "PHASE": phase_domain_count,
            "FREQUENCY": sum(row.get("MAIN_DOMAIN") == "FREQUENCY" for row in unique_main),
            "UNKNOWN": sum(row.get("MAIN_DOMAIN") == "UNKNOWN" for row in unique_main),
        },
        "main_phase_domain_ratio": phase_domain_count / len(unique_main) if unique_main else None,
        "main_phase_locked_count": phase_locked_count,
        "main_phase_locked_ratio": phase_locked_count / len(unique_main) if unique_main else None,
        "visible_handoff_count": int(visible_handoffs),
        "domain_transition_count": len(transitions),
        "frequency_error": freq_stats,
        "frequency_error_nonzero_ratio": nonzero / valid_freq_count if valid_freq_count else None,
        "pi_x": _numeric_stats(unique_main, "MAIN_PI_X"),
        "pi_output": _numeric_stats(unique_main, "MAIN_PI_OUTPUT"),
        "prelock_error": _numeric_stats(unique_main, "MAIN_PRELOCK_ERROR"),
        "clamp_side": _numeric_stats(unique_main, "MAIN_PI_CLAMP_SIDE"),
        "pair_check": {"pass_count": pair_pass, "fail_count": pair_fail,
                        "unknown_count": pair_unknown},
        "detector": _detector_summary(detector),
        "valid_background_bin_count": len(valid_background_rows),
        "required_unique_main_count": 20,
        "required_main_span_ms": 30000,
        "required_background_bin_count": 3,
        "background_coverage_pass": bool(len(unique_main) >= 20 and main_span >= 30000
                                           and len(valid_background_rows) >= 3),
        "producer_domain_coherence": "UNPROVEN",
        "phase_unwrap_or_slip_fit": "NOT_PERFORMED",
        "service_counter_count": len(service),
        "helper_record_count": len(helper),
        "helper_state_count": len(helper_state),
        "helper_position_count": len(position),
        "service_demand_count": len(demand),
        "l2_word_count": len(l2),
        "wr_core_count": len(wr),
        "cycle_count": len(cycles),
        "master_sample_count": len(master),
        "main_records": main,
        "main_unique_records": unique_main,
        "detector_records": detector,
        "helper_records": helper,
        "helper_state_records": helper_state,
        "position_records": position,
        "demand_records": demand,
        "l2_records": l2,
        "service_records": service,
        "wr_records": wr,
        "cycle_records": cycles,
        "master_records": master,
        "transition_records": transitions,
        "bin_records": bins,
        "errors": errors,
        "classification": "INCONCLUSIVE",
        "diagnostic_pass": False,
        "step5_complete": False,
        "step5_pass": False,
        "merge_approved": False,
    }
    result["classification"] = _classify(result)
    result["diagnostic_pass"] = result["classification"] in {
        "RESIDUAL_FREQUENCY_WITH_VISIBLE_HANDOFFS",
        "PHASE_CONTEXT_PERSISTENT_WITHOUT_LOCK",
    }
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
    _write_csv(output_dir / "main_trace.csv", result["main_records"])
    _write_csv(output_dir / "main_dedup.csv", result["main_unique_records"])
    _write_csv(output_dir / "main_domain_transitions.csv", result["transition_records"])
    _write_csv(output_dir / "detector_state.csv", result["detector_records"])
    _write_csv(output_dir / "bins.csv", result["bin_records"])
    _write_csv(output_dir / "service.csv", result["service_records"])
    _write_csv(output_dir / "wr_core.csv", result["wr_records"])
    _write_csv(output_dir / "helper_state.csv", result["helper_state_records"])
    _write_csv(output_dir / "helper_position.csv", result["position_records"])
    _write_csv(output_dir / "service_demand.csv", result["demand_records"])
    _write_csv(output_dir / "l2_words.csv", result["l2_records"])
    compact = {key: value for key, value in result.items()
               if not key.endswith("_records") and key != "metadata_records"}
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
        "input_mode": result["input_mode"],
        "main_unique": result["main_unique_count"],
        "main_span_ms": result["main_unique_span_ms"],
        "valid_background_bins": result["valid_background_bin_count"],
        "domain_transitions": result["domain_transition_count"],
        "step5_pass": False,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
