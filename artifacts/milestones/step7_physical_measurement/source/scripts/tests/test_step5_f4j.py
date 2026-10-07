from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4j_main_producer_handoff_audit as audit  # noqa: E402


RAW_NAMES = [
    "PRODUCER_EPOCH", "UPDATE_ID", "INIT_GENERATION", "PRODUCER_IDENTITY",
    "FREQ_ERROR", "BRANCH_ID", "BRANCH_ERROR", "PI_X", "PI_OUTPUT",
    "PI_CLAMP_SIDE", "FLAGS", "FREQ_COUNT_BEFORE", "FREQ_COUNT_AFTER",
    "PHASE_COUNT_BEFORE", "PHASE_COUNT_AFTER", "SAMPLE_N", "SOURCE_IDS",
    "TOTAL_UPDATES", "FREQ_UPDATES", "PHASE_UPDATES", "FREQ_TO_PHASE",
    "PHASE_TO_FREQ", "PHASE_DETECTOR", "PHASE_IN_BAND", "PHASE_OUT_BAND",
    "LAST_TRANSITION_UPDATE", "LAST_TRANSITION", "STATUS", "LAST_FREQ_UPDATE",
    "LAST_PHASE_UPDATE", "FRAME_WORDS", "VERSION", "MAGIC",
]


def _u32(value: int) -> str:
    return f"0x{value & 0xFFFFFFFF:08X}"


def _main(index: int, *, bad_formula: bool = False, bad_publication: bool = False) -> str:
    phase = index % 2 == 0
    update_id = index
    publication = 2 * index
    producer_epoch = 1000 + 2 * index
    branch = 2 if phase else 1
    freq_error = 30 + index
    branch_error = 120 + index if phase else -20 * freq_error
    if bad_formula and not phase:
        branch_error += 1
    flags = 1 | (1 << 5) | (1 << 6) if phase else 1
    phase_count = (index + 1) // 2
    values = [
        producer_epoch,
        update_id,
        1,
        0x00010000,
        freq_error,
        branch,
        branch_error,
        branch_error,
        32768,
        0,
        flags,
        0 if phase else index,
        0 if phase else index + 1,
        phase_count - (1 if phase else 0),
        phase_count,
        index,
        0x00000100,
        index,
        index - phase_count,
        phase_count,
        phase_count - (1 if phase else 0),
        0,
        phase_count,
        phase_count,
        0,
        index if phase else 0,
        0x0102 if phase else 0,
        1,
        index - phase_count,
        phase_count,
        30,
        1,
        audit.MAGIC,
    ]
    before = publication
    after = publication + (1 if bad_publication else 0)
    parts = [
        "STEP5_F4J_MAIN_PRODUCER",
        "board=DE5 [1-11.2]",
        f"cycle={index}",
        f"host_start_ms={1000 + index * 5000 - 1}",
        f"host_end_ms={1000 + index * 5000}",
        f"elapsed_ms={index * 5000}",
        "READ_DURATION_MS=1",
        "MAIN_PRODUCER_VALID=1",
        f"PUBLICATION_COHERENT={0 if bad_publication else 1}",
        f"PUBLICATION_EPOCH_RAW_BEFORE={_u32(before)}",
        f"PUBLICATION_EPOCH_RAW_AFTER={_u32(after)}",
        f"PUBLICATION_EPOCH={publication}",
    ]
    for name, value in zip(RAW_NAMES, values):
        parts.append(f"{name}={value}")
        parts.append(f"{name}_RAW={_u32(value)}")
    parts.extend([
        "SCHEMA_VERSION=1",
        "SCHEMA_MAGIC_EXPECTED=4D50344A",
        "PRODUCER_SOURCE=MAIN_MPLL_UPDATE_DAC0",
        "DYNAMIC_OWNER=F4J_MAIN_PRODUCER",
        "TRANSPORT_FAILURE=0",
        "ATTEMPTS=1",
    ])
    return " ".join(parts) + "\n"


def _wr(role: str, end: int) -> str:
    board = "DE5 [1-11.1]" if role == "MASTER" else "DE5 [1-11.2]"
    return (
        "STEP5_F4J_WR_CORE "
        f"role={role} board={board} cycle=1 host_start_ms={end - 1} host_end_ms={end} "
        "WR_CORE_VALID=1 DIRECT_VALID=1 TRANSPORT_FAILURE=0 ROLE_IDENTITY_VALID=1 "
        "RESET_FIELDS_VALID=1 TERMINAL=0 PHY_LINK_USABLE=1 "
        "PHY_STATUS_SOURCE=JTAG_PROBE0 PHY_STATUS_INSTANCE=0 PHY_STATUS_WIDTH_BITS=64 "
        "PHY_GATE_REQUIRED_MASK=000000CF PHY_STATUS_VALID=1 "
        "PHY_STATUS_PROBE0_RAW=0x00000000000000CF WDIAGS_CTRL_DATA_VALID=1\n"
    )


def _cycle(index: int) -> str:
    end = 1000 + index * 5000
    return (
        "STEP5_F4J_CYCLE role=SLAVE board=DE5 [1-11.2] "
        f"cycle={index} host_start_ms={end - 5} host_end_ms={end} elapsed_ms={index * 5000} "
        "HELPER_CORE_VALID=1 HELPER_STATE_VALID=1 HELPER_LOCKED=1 "
        "MAIN_PRODUCER_VALID=1 MAIN_UPDATE_ADVANCED=1 WR_CORE_VALID=1 "
        "PHY_LINK_USABLE=1 TERMINAL=0 STOP_REASON=NONE\n"
    )


def _log(count: int = 20, **main_kwargs: bool) -> str:
    lines = [
        "STEP5_F4J_CONFIG experiment=EXP-S5-F4J-MAIN-PRODUCER-HANDOFF-SNAPSHOT-20260916 "
        "run_role=f4j READ_ONLY_OBSERVER=1 ONE_READER=1 READER_PROCESSES=1 "
        "NO_CONTROL_WRITE=1 NO_HELPER_PI_SNAPSHOT=1 NO_DEBUG_FIFO_DRAIN=1 "
        "PRODUCTION_CONTROL_UNCHANGED=1 SOURCE_CONTRACT_VERIFIED=YES "
        "target_duration_ms=120000 hard_duration_ms=130000 phy_status_source=JTAG_PROBE0\n",
        "STEP5_F4J_DONE session_elapsed_ms=120000 target_duration_ms=120000 "
        "hard_duration_ms=130000 stop_reason=NONE single_reader=PASS "
        "step5_complete=NO step5_pass=NO merge_approved=NO\n",
        _wr("MASTER", 500),
    ]
    for index in range(1, count + 1):
        lines.append(_main(index, **main_kwargs))
        lines.append(_cycle(index))
        lines.append(_wr("SLAVE", 1000 + index * 5000 + 10))
    return "".join(lines)


def test_valid_formal_capture_confirms_producer_handoff_but_not_step5() -> None:
    result = audit.analyze_text(_log())
    assert result["classification"] == "PRODUCER_HANDOFF_CONFIRMED"
    assert result["diagnostic_pass"] is True
    assert result["step5_pass"] is False
    assert result["unique_count"] == 20
    assert result["unique_span_ms"] >= 30000


def test_frequency_formula_is_checked_exactly() -> None:
    result = audit.analyze_text(_log(bad_formula=True))
    assert result["classification"] == "DIAGNOSTIC_IMPLEMENTATION_LIMITED"
    assert "FREQUENCY_BRANCH_FORMULA_MISMATCH" in result["frame_error_kinds"]


def test_publication_context_mismatch_is_not_joined() -> None:
    result = audit.analyze_text(_log(bad_publication=True))
    assert result["publication_context_mismatch_count"] == 20
    assert result["classification"] == "PUBLICATION_CONTEXT_MISPAIR_CONFIRMED"
    assert result["unique_count"] == 0


def test_short_capture_is_inconclusive() -> None:
    result = audit.analyze_text(_log(count=4))
    assert result["classification"] == "INCONCLUSIVE"
    assert result["diagnostic_pass"] is False


def test_old_or_missing_schema_cannot_be_upgraded() -> None:
    result = audit.analyze_text(
        "STEP5_F4I_MAIN_TRACE MAIN_TRACE_VALID=1 MAIN_PUBLICATION_EPOCH=2\n"
    )
    assert result["classification"] == "DIAGNOSTIC_IMPLEMENTATION_LIMITED"
    assert result["step5_pass"] is False


def _run_control_trace(events: list[dict[str, int]], instrumented: bool) -> tuple[list[tuple], list[dict]]:
    """Small replay of the unchanged mpll_update boundaries.

    The diagnostic branch only records values; it is deliberately not allowed
    to feed a value back into this production-state model.  The event trace
    includes disabled/incomplete-pair returns, the frequency/phase handoff,
    a wrapped phase error, gain-stage re-entry, and DAC freeze.
    """
    enabled = True
    frequency_locked = False
    phase_locked = False
    frequency_count = 0
    phase_count = 0
    sample_n = 0
    dac = 32768
    records: list[dict] = []
    outputs: list[tuple] = []
    for event in events:
        if event.get("disabled"):
            outputs.append(("LOCKED", dac, frequency_locked, phase_locked, sample_n))
            continue
        if not event.get("pair"):
            outputs.append(("LOCKING", dac, frequency_locked, phase_locked, sample_n))
            continue
        freq_error = event.get("freq_error", 0)
        if not frequency_locked:
            branch = 1
            error = -20 * freq_error
            frequency_count = min(50, frequency_count + (abs(freq_error) <= 50))
            if frequency_count == 50:
                frequency_locked = True
        else:
            branch = 2
            error = event["phase_error"]
            phase_count = min(event.get("phase_limit", 1000),
                              phase_count + (abs(error) <= 1200))
            if phase_count == event.get("phase_limit", 1000):
                phase_locked = True
        if not event.get("freeze"):
            dac = max(5, min(65531, 32768 + error))
        sample_n = (sample_n + 1) & 0xFFFFFFFF
        result = "LOCKED" if phase_locked else "LOCKING"
        outputs.append((result, dac, frequency_locked, phase_locked, sample_n))
        if instrumented:
            records.append({"branch": branch, "error": error, "sample_n": sample_n,
                            "dac_write": int(not event.get("freeze"))})
    return outputs, records


def test_instrumentation_does_not_change_control_outputs_on_same_trace() -> None:
    events = [
        {"disabled": 1, "pair": 1},
        {"pair": 0},
        *({"pair": 1, "freq_error": 1} for _ in range(50)),
        {"pair": 1, "phase_error": 0x10000 - 12, "phase_limit": 3},
        {"pair": 1, "phase_error": 12, "phase_limit": 3, "freeze": 1},
        {"pair": 1, "phase_error": 10, "phase_limit": 3},
    ]
    plain, plain_records = _run_control_trace(events, instrumented=False)
    instrumented, diagnostic_records = _run_control_trace(events, instrumented=True)
    assert plain == instrumented
    assert plain_records == []
    assert len(diagnostic_records) == len([event for event in events if event.get("pair") and not event.get("disabled")])
    assert diagnostic_records[-2]["dac_write"] == 0
