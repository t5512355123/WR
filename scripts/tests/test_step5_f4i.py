from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4i_frequency_phase_handoff_audit as audit  # noqa: E402


def _config() -> str:
    return (
        "STEP5_F4I_CONFIG experiment=EXP-S5-F4I-MAIN-FREQUENCY-PHASE-HANDOFF-AUDIT-20260916 "
        "run_role=f4i READ_ONLY_OBSERVER=1 ONE_READER=1 READER_PROCESSES=1 "
        "NO_CONTROL_WRITE=1 NO_HELPER_PI_SNAPSHOT=1 NO_DEBUG_FIFO_DRAIN=1 "
        "PRODUCTION_CONTROL_UNCHANGED=1 SOURCE_CONTRACT_VERIFIED=YES "
        "DYNAMIC_OWNER_VERIFIED=NOT_AVAILABLE target_duration_ms=120000 "
        "hard_duration_ms=130000 phy_status_source=JTAG_PROBE0 "
        "phy_status_instance=0 phy_status_width_bits=64 phy_required_mask=000000CF\n"
    )


def _done(stop: str = "NONE") -> str:
    return (
        "STEP5_F4I_DONE session_elapsed_ms=120000 target_duration_ms=120000 "
        f"hard_duration_ms=130000 stop_reason={stop} single_reader=PASS "
        "step5_complete=NO step5_pass=NO merge_approved=NO\n"
    )


def _wr(role: str, end: int) -> str:
    board = "DE5 [1-11.1]" if role == "MASTER" else "DE5 [1-11.2]"
    return (
        "STEP5_F4I_WR_CORE "
        f"role={role} board={board} cycle=1 host_start_ms={end - 5} host_end_ms={end} "
        "WR_CORE_VALID=1 DIRECT_VALID=1 TRANSPORT_FAILURE=0 ROLE_IDENTITY_VALID=1 "
        "RESET_FIELDS_VALID=1 TERMINAL=0 PHY_LINK_USABLE=1 "
        "PHY_STATUS_SOURCE=JTAG_PROBE0 PHY_STATUS_INSTANCE=0 PHY_STATUS_WIDTH_BITS=64 "
        "PHY_GATE_REQUIRED_MASK=000000CF PHY_STATUS_VALID=1 "
        "PHY_STATUS_PROBE0_RAW=00000000000000CF WDIAGS_CTRL_DATA_VALID=1\n"
    )


def _main(index: int, end: int, state: int, sample_n: int,
          *, pi_x: int = 123, error: int = 60) -> str:
    dref = 100
    dout = dref + error
    epoch = 2 + index * 2
    return (
        "STEP5_F4I_MAIN_TRACE board=DE5 [1-11.2] "
        f"sample={index} host_start_ms={end - 10} host_end_ms={end} elapsed_ms={end} "
        "MAIN_TRACE_VALID=1 PUBLICATION_COHERENT=1 MAIN_TRACE_UNIQUE=1 "
        f"MAIN_TRACE_EPOCH_RAW_BEFORE={epoch:08X} MAIN_TRACE_EPOCH_RAW_AFTER={epoch:08X} "
        f"MAIN_PUBLICATION_EPOCH={epoch} MAIN_PUBLICATION_EPOCH_SAME=1 "
        f"MAIN_DREF_DT={dref} MAIN_DOUT_DT={dout} MAIN_FREQ_ERROR={error} "
        "MAIN_PRELOCK_ERROR=1200 MAIN_PI_UNCLAMPED=10000 MAIN_PI_OUTPUT=10000 "
        "MAIN_PI_CLAMP_SIDE=0 "
        f"MAIN_SAMPLE_N={sample_n} MAIN_SAMPLE_N_ADVANCED=1 MAIN_SAMPLE_N_AMBIGUOUS=0 "
        f"MAIN_STATE={state} MAIN_PI_X={pi_x} MAIN_TRACE_MAGIC=1 "
        f"MAIN_ENABLED=1 MAIN_FREQ_LOCKED={(state >> 1) & 1} "
        f"MAIN_PHASE_LOCKED={(state >> 2) & 1} MAIN_LOCKED={(state >> 3) & 1} "
        f"MAIN_DOMAIN={'PHASE' if state & 2 else 'FREQUENCY'} "
        "PI_X_CLASSIFICATION=UNKNOWN PRODUCER_DOMAIN_COHERENCE=UNPROVEN "
        f"FREQ_ERROR_SIGN={'POSITIVE' if error > 0 else 'NEGATIVE'} "
        "FREQ_ABS_GT_50=1 FREQ_ERROR_PAIR_CHECK=PASS\n"
    )


def _helper(index: int, end: int) -> str:
    return (
        "STEP5_F4G_HELPER_ATTEMPT board=DE5 [1-11.2] "
        f"cycle={index} retry_n=1 host_start_ms={end - 20} host_end_ms={end - 15} "
        "RAW_EPOCH_BEFORE=00000002 RAW_HELPER_ERROR=FFFFFFF0 "
        f"RAW_UPDATE_COUNT={1000 + index:08X} RAW_HELPER_OUTPUT=000003E8 "
        "RAW_EPOCH_AFTER=00000002 EPOCH_BEFORE=2 EPOCH_AFTER=2 "
        "HELPER_ERROR=-16 UPDATE_COUNT=1000 HELPER_OUTPUT=1000 "
        "TRANSPORT_ERROR=0 PARSE_ERROR=0 ODD_OR_SENTINEL=0 EPOCH_CHANGED=0 "
        "RANGE_MISMATCH=0 ACCEPTED=1 OWNER_UNVERIFIED=1 "
        "DYNAMIC_OWNER=NOT_AVAILABLE reason=NONE\n"
    )


def _helper_state(index: int, end: int) -> str:
    return (
        "STEP5_F4G_HELPER_STATE board=DE5 [1-11.2] "
        f"cycle={index} host_start_ms={end - 14} host_end_ms={end - 12} "
        "HELPER_STATE_VALID=1 HELPER_STATE_RAW=03E80001 "
        "HELPER_LIMITS_RAW=03E807D0 HELPER_LOCKED=1 HELPER_LOCK_COUNT=1000 "
        "HELPER_THRESHOLD=2000 HELPER_LOCK_SAMPLES=1000\n"
    )


def _cycle(index: int, end: int) -> str:
    return (
        "STEP5_F4I_CYCLE role=SLAVE board=DE5 [1-11.2] "
        f"cycle={index} host_start_ms={end - 30} host_end_ms={end - 1} "
        "HELPER_CORE_VALID=1 HELPER_CORE_FRESH=1 HELPER_STATE_VALID=1 "
        "HELPER_LOCKED=1 MAIN_CORE_VALID=1 MAIN_TRACE_UNIQUE=1 "
        "MAIN_SAMPLE_N_ADVANCED=1 MAIN_PHASE_LOCKED=0 WR_CORE_VALID=1 "
        "PHY_LINK_USABLE=1 TERMINAL=0 STOP_REASON=NONE\n"
    )


def _long_log(domains: list[int]) -> str:
    lines = [_config(), _done(), _wr("MASTER", 500)]
    for index, state in enumerate(domains):
        end = 1000 + index * 10000
        lines.extend([
            _helper(index + 1, end),
            _helper_state(index + 1, end),
            _main(index + 1, end, state, 100 + index),
            _cycle(index + 1, end),
            _wr("SLAVE", end + 100),
        ])
    return "".join(lines)


def test_trace_domain_and_detector_are_separate() -> None:
    text = _long_log([1, 3, 1, 3])
    text += (
        "STEP5_F4G_MAIN_DETECTOR board=DE5 [1-11.2] cycle=1 "
        "host_start_ms=2000 host_end_ms=2010 MAIN_DETECTOR_VALID=1 "
        "MAIN_FREQ_LOCKED=1 MAIN_PHASE_LOCKED=0\n"
    )
    result = audit.analyze_text(text)
    assert result["main_unique_records"][1]["MAIN_DOMAIN"] == "PHASE"
    assert result["detector"]["frequency_locked_count"] == 1
    assert result["detector"]["phase_locked_count"] == 0


def test_pi_x_does_not_define_domain() -> None:
    result = audit.analyze_text(_long_log([1] * 4).replace(
        "MAIN_PI_X=123", "MAIN_PI_X=-7656"))
    assert result["main_unique_records"][0]["MAIN_DOMAIN"] == "FREQUENCY"
    assert result["pi_x"]["min"] == -7656


def test_duplicate_epoch_and_sample_is_removed_from_unique_stream() -> None:
    first = _main(1, 1000, 1, 100)
    duplicate = _main(2, 2000, 1, 100).replace(
        "MAIN_TRACE_EPOCH_RAW_BEFORE=00000006 MAIN_TRACE_EPOCH_RAW_AFTER=00000006",
        "MAIN_TRACE_EPOCH_RAW_BEFORE=00000004 MAIN_TRACE_EPOCH_RAW_AFTER=00000004",
    ).replace("MAIN_PUBLICATION_EPOCH=6", "MAIN_PUBLICATION_EPOCH=4")
    result = audit.analyze_text(_config() + _done() + _wr("MASTER", 500) +
                                _wr("SLAVE", 600) + first + duplicate)
    assert result["main_trace_count"] == 2
    assert result["main_unique_count"] == 1
    assert result["main_duplicate_count"] == 1


def test_sample_counter_wrap_is_progress_not_ambiguity() -> None:
    text = _config() + _done() + _wr("MASTER", 500) + _wr("SLAVE", 600)
    text += _main(1, 1000, 1, 0xFFFFFFFE)
    text += _main(2, 2000, 1, 2)
    result = audit.analyze_text(text)
    assert result["main_sample_ambiguous_count"] == 0
    assert result["main_unique_records"][1]["MAIN_SAMPLE_N_DELTA"] == 4
    assert result["main_unique_records"][1]["MAIN_SAMPLE_N_ADVANCED"] == 1


def test_reentry_is_observed_and_does_not_stop_capture() -> None:
    result = audit.analyze_text(_long_log([1, 3, 1, 3] * 6))
    assert result["visible_handoff_count"] == 23
    assert result["classification"] == "RESIDUAL_FREQUENCY_WITH_VISIBLE_HANDOFFS"
    assert result["done"]["STOP_REASON"] == "NONE"
    assert result["step5_pass"] is False


def test_short_capture_is_inconclusive() -> None:
    result = audit.analyze_text(_long_log([1, 3]))
    assert result["classification"] == "INCONCLUSIVE"
    assert result["diagnostic_pass"] is False


def test_f4h_baseline_is_not_upgraded_to_f4i() -> None:
    text = (
        "STEP5_F4G_CONFIG run_role=f4h READ_ONLY_OBSERVER=1 ONE_READER=1 "
        "READER_PROCESSES=1 NO_CONTROL_WRITE=1 NO_HELPER_PI_SNAPSHOT=1 "
        "NO_DEBUG_FIFO_DRAIN=1 PRODUCTION_CONTROL_UNCHANGED=1 "
        "SOURCE_CONTRACT_VERIFIED=YES PHY_STATUS_SOURCE=JTAG_PROBE0 "
        "PHY_STATUS_INSTANCE=0 PHY_STATUS_WIDTH_BITS=64 PHY_REQUIRED_MASK=000000CF\n"
        "STEP5_F4G_DONE single_reader=PASS STOP_REASON=NONE\n"
        "STEP5_F4G_MASTER_CORE role=MASTER board=DE5 [1-11.1] "
        "host_start_ms=1 host_end_ms=2 WR_CORE_VALID=1 PHY_LINK_USABLE=1 "
        "ROLE_IDENTITY_VALID=1 RESET_FIELDS_VALID=1 TERMINAL=0 "
        "PHY_STATUS_SOURCE=JTAG_PROBE0 PHY_STATUS_INSTANCE=0 PHY_STATUS_WIDTH_BITS=64 "
        "PHY_GATE_REQUIRED_MASK=000000CF PHY_STATUS_VALID=1 "
        "PHY_STATUS_PROBE0_RAW=00000000000000CF\n"
        "STEP5_F4G_WR_CORE role=SLAVE board=DE5 [1-11.2] "
        "host_start_ms=1 host_end_ms=2 WR_CORE_VALID=1 PHY_LINK_USABLE=1 "
        "ROLE_IDENTITY_VALID=1 RESET_FIELDS_VALID=1 TERMINAL=0 "
        "PHY_STATUS_SOURCE=JTAG_PROBE0 PHY_STATUS_INSTANCE=0 PHY_STATUS_WIDTH_BITS=64 "
        "PHY_GATE_REQUIRED_MASK=000000CF PHY_STATUS_VALID=1 "
        "PHY_STATUS_PROBE0_RAW=00000000000000CF\n"
        + "STEP5_F4G_MAIN_CORE board=DE5 [1-11.2] cycle=1 "
        "host_start_ms=1 host_end_ms=2 MAIN_CORE_VALID=1 MAIN_SAMPLE_N=1 "
        "MAIN_PI_X=1 MAIN_PI_OUTPUT=1 MAIN_PI_CLAMP_SIDE=0 MAIN_STATE=1\n"
    )
    result = audit.analyze_text(text)
    assert result["input_mode"] == "F4H_BASELINE_REPLAY"
    assert result["source_family"] == "F4H"
    assert result["step5_pass"] is False
