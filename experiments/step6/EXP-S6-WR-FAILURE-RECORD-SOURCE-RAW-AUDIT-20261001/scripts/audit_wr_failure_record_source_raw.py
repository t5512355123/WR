#!/usr/bin/env python3
"""Decode saved WR failure diagnostics against the frozen Step 6 source map."""

from __future__ import annotations

import argparse
from hashlib import sha256
from pathlib import Path
import re
from typing import Any


EXPECTED_RAW_SHA256 = (
    "9fc2da70c44d005e351a721057f26b2f9506e441d752b354fde8338b56197580"
)
EXPECTED_ROWS = 741
REASON_NAMES = {
    0: "UNKNOWN",
    1: "WR_PRESENT_TIMEOUT",
    2: "WR_M_LOCK_TIMEOUT",
    3: "WR_S_LOCK_TIMEOUT",
    4: "WR_LOCKED_TIMEOUT",
    5: "WR_CALIBRATED_TIMEOUT",
    6: "WR_RESP_CALIB_REQ_TIMEOUT",
    7: "NO_WR_PARENT",
}


def parse_fields(line: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for raw_key, value in re.findall(r"([A-Za-z][A-Za-z0-9_]*)=([^\s]+)", line):
        key = raw_key.upper()
        if key in fields and fields[key] != value:
            raise ValueError(f"FIELD_CASE_CONFLICT key={key}")
        fields[key] = value
    return fields


def _number(row: dict[str, str], key: str, *, hexadecimal: bool = False) -> int | None:
    value = row.get(key.upper())
    if value is None or value in {"NA", "INVALID", "TIMEOUT", "SKIPPED"}:
        return None
    try:
        return int(value.removeprefix("0x"), 16) if hexadecimal else int(value, 10)
    except (TypeError, ValueError):
        return None


def decode_failure_word(word: int) -> dict[str, int | None]:
    """Decode WDIAG_SERVO_RESTART_COUNT at byte offset 0x6c."""
    disable_valid = (word >> 11) & 1
    return {
        "counter_low8": word & 0xff,
        "last_failure_state": (word >> 16) & 0xff,
        "last_failure_role": (word >> 24) & 0xff,
        "disable_cause": ((word >> 8) & 0x7) if disable_valid else None,
        "disable_valid": disable_valid,
        # The PTP state bits are meaningful only when the sticky disable record
        # is valid; zero in an invalid record is not an observed PTP state.
        "disable_ptp_state": ((word >> 12) & 0xf) if disable_valid else None,
    }


def decode_lock_result_word(word: int) -> dict[str, int | str]:
    """Decode WDIAG_WR_LOCK_RESULT at byte offset 0x8c."""
    reason = (word >> 9) & 0x7f
    tics = (word >> 16) & 0xffff
    return {
        "result_code": word & 0xff,
        "check_lock": (word >> 8) & 1,
        "failure_reason": reason,
        "failure_reason_name": REASON_NAMES.get(reason, "UNMAPPED"),
        "failure_tics_low16": tics,
        "failure_tics_hex": f"0x{tics:04X}",
    }


def delta16(previous: int | None, current: int | None) -> tuple[int | None, str]:
    """Return modulo delta and note whether a low-word decrease was visible."""
    if previous is None or current is None:
        return None, "MISSING"
    if current >= previous:
        return current - previous, "NONDECREASING_LOWWORD"
    if previous >= 0xF000 and current <= 0x0FFF:
        return (1 << 16) - previous + current, "VISIBLE_LOWWORD_ROLLOVER"
    return None, "DISCONTINUITY"


def decode_wr_state_word(word: int) -> dict[str, int]:
    """Decode fields packed by task-diags.c into WDIAG_TEMP (offset 0x04)."""
    return {
        "wr_mode_on": word & 1,
        "parent_wr_mode_on": (word >> 1) & 1,
        "calibrated": (word >> 2) & 1,
        "parent_is_wr_node": (word >> 3) & 1,
        "parent_calibrated": (word >> 4) & 1,
        "wr_config": (word >> 5) & 0x7,
        "parent_wr_config": (word >> 8) & 0x7,
        "wr_state": (word >> 11) & 0xf,
        "wr_next_state": (word >> 15) & 0xf,
        "parent_detection": (word >> 19) & 0x3,
        "wr_mode": (word >> 21) & 0x7,
    }


def _sample_rows(text: str) -> list[dict[str, str]]:
    return [
        parse_fields(line)
        for line in text.splitlines()
        if line.startswith("S6E_SAMPLE ")
    ]


def analyze_text(text: str) -> dict[str, Any]:
    rows = _sample_rows(text)
    if not rows:
        raise ValueError("NO_S6E_SAMPLE_ROWS")

    for row in rows:
        for key in ("WR_FAILURE_RAW", "LOCK_RESULT_RAW", "WR_STATE_RAW"):
            if _number(row, key, hexadecimal=True) is None:
                raise ValueError(f"MISSING_OR_INVALID_{key}")

    failure_edges: list[dict[str, Any]] = []
    for row in rows:
        delta = _number(row, "WR_FAILURE_DELTA_U8")
        if delta is not None and delta > 0:
            failure_edges.append(row)
    if len(failure_edges) != 1:
        raise ValueError(f"EXPECTED_ONE_FAILURE_EDGE got={len(failure_edges)}")

    edge = failure_edges[0]
    edge_sample = _number(edge, "SAMPLE")
    prior = next(
        (row for row in rows if _number(row, "SAMPLE") == (edge_sample - 1)),
        None,
    )
    if prior is None:
        raise ValueError("MISSING_PRE_FAILURE_ADJACENT_ROW")

    failure_raw = _number(edge, "WR_FAILURE_RAW", hexadecimal=True)
    lock_raw = _number(edge, "LOCK_RESULT_RAW", hexadecimal=True)
    state_raw = _number(edge, "WR_STATE_RAW", hexadecimal=True)
    assert failure_raw is not None and lock_raw is not None and state_raw is not None

    failure = decode_failure_word(failure_raw)
    lock_result = decode_lock_result_word(lock_raw)
    wr_state = decode_wr_state_word(state_raw)
    before_lock = decode_lock_result_word(
        _number(prior, "LOCK_RESULT_RAW", hexadecimal=True) or 0
    )

    post_failure_rows = [
        row
        for row in rows
        if _number(row, "SAMPLE") is not None
        and edge_sample <= _number(row, "SAMPLE") <= edge_sample + 2
    ]
    post_failure_states = [
        row.get("WR_STATE_NAME", "MISSING") for row in post_failure_rows
    ]

    # The Tcl source reads A8C after the reject word and before the poll word.
    # The raw format preserves those neighboring timestamps but omits the
    # dedicated A8C begin/end timestamps, so report a bound, not an exact read.
    lock_read_lower = _number(edge, "REJECT_READ_END_MS")
    lock_read_upper = _number(edge, "POLL_READ_BEGIN_MS")
    if lock_read_lower is None or lock_read_upper is None or lock_read_upper < lock_read_lower:
        raise ValueError("INVALID_LOCK_RESULT_READ_BRACKET")

    result_rows = [
        row
        for row in rows
        if _number(row, "SAMPLE") is not None
        and edge_sample <= _number(row, "SAMPLE") <= edge_sample + 2
    ]
    stable_failure_reason = len(result_rows) == 3 and all(
        decode_lock_result_word(_number(row, "LOCK_RESULT_RAW", hexadecimal=True) or 0)
        ["failure_reason"]
        == lock_result["failure_reason"]
        for row in result_rows
    )
    stable_failure_tics = len(result_rows) == 3 and all(
        decode_lock_result_word(_number(row, "LOCK_RESULT_RAW", hexadecimal=True) or 0)
        ["failure_tics_low16"]
        == lock_result["failure_tics_low16"]
        for row in result_rows
    )

    previous_tics = before_lock["failure_tics_low16"]
    tics_delta, tics_delta_kind = delta16(
        int(previous_tics), int(lock_result["failure_tics_low16"])
    )

    return {
        "sample_count": len(rows),
        "required_valid_rows": sum(
            _number(row, "REQUIRED_ROW_VALID") == 1 for row in rows
        ),
        "failure_edge_sample": edge_sample,
        "failure_edge_elapsed_ms": _number(edge, "ELAPSED_MS"),
        "row_start_ms": _number(edge, "ROW_START_MS"),
        "row_end_ms": _number(edge, "ROW_END_MS"),
        "state_read_begin_ms": _number(edge, "STATE_READ_BEGIN_MS"),
        "state_read_end_ms": _number(edge, "STATE_READ_END_MS"),
        "failure_read_begin_ms": _number(edge, "FAILURE_READ_BEGIN_MS"),
        "failure_read_end_ms": _number(edge, "FAILURE_READ_END_MS"),
        "rx_raw": edge.get("WR_RX_RAW", "MISSING"),
        "rx_id": _number(edge, "WR_RX_ID"),
        "rx_count": _number(edge, "WR_RX_COUNT"),
        "tx_raw": edge.get("WR_TX_RAW", "MISSING"),
        "tx_id": _number(edge, "WR_TX_ID"),
        "tx_count": _number(edge, "WR_TX_COUNT"),
        "failure_counter_before_low8": before_lock_record_counter(prior),
        "failure_counter_after_low8": failure["counter_low8"],
        "failure_word_raw": f"0x{failure_raw:08X}",
        "failure_record": failure,
        "lock_result_word_raw": f"0x{lock_raw:08X}",
        "lock_result": lock_result,
        "lock_result_read_exact_bracket_logged": (
            "LOCK_RESULT_READ_BEGIN_MS" in edge
            and "LOCK_RESULT_READ_END_MS" in edge
        ),
        "lock_result_read_lower_bound_ms": lock_read_lower,
        "lock_result_read_upper_bound_ms": lock_read_upper,
        "lock_result_read_bound_width_ms": lock_read_upper - lock_read_lower,
        "failure_tics_before_low16": previous_tics,
        "failure_tics_delta_low16": tics_delta,
        "failure_tics_delta_kind": tics_delta_kind,
        "failure_tics_is_host_elapsed": False,
        "lock_reason_stable_for_samples_738_740": stable_failure_reason,
        "lock_tics_stable_for_samples_738_740": stable_failure_tics,
        "wr_state_word_raw": f"0x{state_raw:08X}",
        "wr_state": wr_state,
        "failure_fsm_state_name": edge.get("WR_STATE_NAME", "MISSING"),
        "post_failure_state_names": post_failure_states,
        "post_failure_rows_count": len(post_failure_rows),
        "slock_tail_stable": _number(edge, "SLOCK_TAIL_STABLE"),
        "slock_stage_raw": edge.get("SLOCK_STAGE_RAW", "MISSING"),
        "slock_retry_raw": edge.get("SLOCK_RETRY_RAW", "MISSING"),
        "slock_remaining_raw": edge.get("SLOCK_REMAINING_MS_RAW", "MISSING"),
        "slock_tail_seq_before_raw": edge.get("SLOCK_TAIL_SEQ_BEFORE_RAW", "MISSING"),
        "slock_tail_seq_after_raw": edge.get("SLOCK_TAIL_SEQ_AFTER_RAW", "MISSING"),
        "spll_state_raw": edge.get("SPLL_STATE_RAW", "MISSING"),
        "softpll_seq_state": _number(edge, "SPLL_SEQ_STATE"),
        "helper_state_raw": edge.get("HELPER_STATE_RAW", "MISSING"),
        "helper_lock": _number(edge, "HELPER_LOCK"),
        "main_state_raw": edge.get("MAIN_STATE_RAW", "MISSING"),
        "main_enabled": _number(edge, "MAIN_ENABLED"),
        "main_freq_lock": _number(edge, "MAIN_FREQ_LOCK"),
        "main_phase_lock": _number(edge, "MAIN_PHASE_LOCK"),
        "main_lock": _number(edge, "MAIN_LOCK"),
        "pstat_lock": _number(edge, "PSTAT_LOCK"),
        "sstat_raw": edge.get("SSTAT_RAW", "MISSING"),
        "servo_state": _number(edge, "SERVO_STATE"),
        "ucnt_raw": edge.get("UCNT_RAW", "MISSING"),
        "ucnt": _number(edge, "UCNT"),
        "ptp_state_at_failure_captured": "PTP_STATE_AT_FAILURE" in edge,
        "source_event_count": sum(
            row.get("ROW_EVENT_KIND", "NONE") != "NONE" for row in rows
        ),
        "raw_observer_stop_reason": next(
            (
                parse_fields(line).get("REASON", "MISSING")
                for line in reversed(text.splitlines())
                if line.startswith("S6E_STOP ")
            ),
            "MISSING_STOP",
        ),
        "extension_disable_recorded": failure["disable_valid"] == 1,
    }


def before_lock_record_counter(row: dict[str, str]) -> int | None:
    value = _number(row, "WR_FAILURE_RAW", hexadecimal=True)
    return None if value is None else value & 0xff


def audit_file(path: Path) -> dict[str, Any]:
    raw_bytes = path.read_bytes()
    digest = sha256(raw_bytes).hexdigest()
    if digest != EXPECTED_RAW_SHA256:
        raise ValueError(f"RAW_SHA256_MISMATCH expected={EXPECTED_RAW_SHA256} actual={digest}")
    result = analyze_text(raw_bytes.decode("utf-8", errors="replace"))
    if result["sample_count"] != EXPECTED_ROWS:
        raise ValueError(
            f"RAW_ROW_COUNT_MISMATCH expected={EXPECTED_ROWS} "
            f"actual={result['sample_count']}"
        )
    if result["required_valid_rows"] != EXPECTED_ROWS:
        raise ValueError(
            f"REQUIRED_ROW_VALIDITY_MISMATCH expected={EXPECTED_ROWS} "
            f"actual={result['required_valid_rows']}"
        )
    result["raw_sha256"] = digest
    result["raw_path"] = str(path)
    result["expected_rows"] = EXPECTED_ROWS
    result["raw_hash_verified"] = True
    return result


def render(result: dict[str, Any]) -> str:
    failure = result["failure_record"]
    lock = result["lock_result"]
    wr_state = result["wr_state"]
    return "\n".join(
        [
            "AUDIT=PASS_RAW_HASH_AND_DECODE",
            f"RAW_SHA256={result['raw_sha256']}",
            f"SAMPLES={result['sample_count']}/{result['expected_rows']}",
            f"REQUIRED_VALID_ROWS={result['required_valid_rows']}/{result['sample_count']}",
            f"FAILURE_EDGE_SAMPLE={result['failure_edge_sample']}",
            f"FAILURE_EDGE_ELAPSED_MS={result['failure_edge_elapsed_ms']}",
            f"ROW_BRACKET_MS={result['row_start_ms']}..{result['row_end_ms']}",
            f"STATE_READ_BRACKET_MS={result['state_read_begin_ms']}..{result['state_read_end_ms']}",
            f"A6C_READ_BRACKET_MS={result['failure_read_begin_ms']}..{result['failure_read_end_ms']}",
            f"RX_RAW={result['rx_raw']} ID={result['rx_id']} COUNT={result['rx_count']}",
            f"TX_RAW={result['tx_raw']} ID={result['tx_id']} COUNT={result['tx_count']}",
            f"FAILURE_COUNTER_LOW8={result['failure_counter_before_low8']}->{result['failure_counter_after_low8']}",
            f"FAILURE_RAW={result['failure_word_raw']}",
            f"FAILURE_LAST_ROLE={failure['last_failure_role']}",
            f"FAILURE_LAST_WR_STATE={failure['last_failure_state']}",
            f"DISABLE_VALID={failure['disable_valid']}",
            f"DISABLE_CAUSE={'NA_INVALID_RECORD' if failure['disable_valid'] == 0 else failure['disable_cause']}",
            f"DISABLE_PTP_STATE={'NA_INVALID_RECORD' if failure['disable_ptp_state'] is None else failure['disable_ptp_state']}",
            f"LOCK_RESULT_RAW={result['lock_result_word_raw']}",
            f"LOCK_RESULT_CODE={lock['result_code']}",
            f"CHECK_LOCK={lock['check_lock']}",
            f"FAILURE_REASON={lock['failure_reason']}:{lock['failure_reason_name']}",
            f"FAILURE_TICS_LOW16={lock['failure_tics_hex']}",
            f"FAILURE_TICS_DELTA_LOW16={result['failure_tics_delta_low16']}:{result['failure_tics_delta_kind']}",
            "FAILURE_TICS_HOST_ELAPSED=NO; MULTIPLE_HIDDEN_WRAPS_NOT_EXCLUDED",
            f"LOCK_RESULT_EXACT_READ_BRACKET_LOGGED={int(result['lock_result_read_exact_bracket_logged'])}",
            f"LOCK_RESULT_READ_BOUND_MS={result['lock_result_read_lower_bound_ms']}..{result['lock_result_read_upper_bound_ms']}",
            f"LOCK_RESULT_READ_BOUND_WIDTH_MS={result['lock_result_read_bound_width_ms']}",
            f"LOCK_REASON_STABLE_3_ROWS={int(result['lock_reason_stable_for_samples_738_740'])}",
            f"LOCK_TICS_STABLE_3_ROWS={int(result['lock_tics_stable_for_samples_738_740'])}",
            f"WR_STATE_RAW={result['wr_state_word_raw']}",
            f"WR_STATE={wr_state['wr_state']} NEXT={wr_state['wr_next_state']} MODE={wr_state['wr_mode']}",
            f"PARENT_IS_WR={wr_state['parent_is_wr_node']} PARENT_CONFIG={wr_state['parent_wr_config']}",
            f"POST_FAILURE_STATES={','.join(result['post_failure_state_names'])}",
            f"SLOCK_TAIL_STABLE={result['slock_tail_stable']} STAGE={result['slock_stage_raw']} RETRY={result['slock_retry_raw']} REMAINING={result['slock_remaining_raw']} SEQ={result['slock_tail_seq_before_raw']}->{result['slock_tail_seq_after_raw']}",
            f"SPLL_RAW={result['spll_state_raw']} SEQ_STATE={result['softpll_seq_state']}",
            f"HELPER_RAW={result['helper_state_raw']} LOCK={result['helper_lock']}",
            f"MAIN_RAW={result['main_state_raw']} ENABLED={result['main_enabled']} FREQ={result['main_freq_lock']} PHASE={result['main_phase_lock']} LOCK={result['main_lock']}",
            f"PSTAT={result['pstat_lock']} SSTAT_RAW={result['sstat_raw']} SERVO_STATE={result['servo_state']} UCNT_RAW={result['ucnt_raw']} UCNT={result['ucnt']}",
            f"PTP_STATE_AT_FAILURE_CAPTURED={int(result['ptp_state_at_failure_captured'])}",
            f"SOURCE_BACKED_SUCCESS_EVENTS={result['source_event_count']}",
            f"OBSERVER_STOP_REASON_RAW={result['raw_observer_stop_reason']}",
            f"EXTENSION_DISABLE_RECORDED={int(result['extension_disable_recorded'])}",
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("raw_log", type=Path)
    args = parser.parse_args()
    result = audit_file(args.raw_log)
    print(render(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
