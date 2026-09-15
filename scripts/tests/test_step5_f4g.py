from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4g_compact_progress_window as audit  # noqa: E402


def _config() -> str:
    return (
        "STEP5_F4G_CONFIG experiment=EXP-S5-F4G-COMPACT-HELPER-MAIN-SERVICE-WINDOW-20260915 "
        "READ_ONLY_OBSERVER=1 ONE_READER=1 READER_PROCESSES=1 "
        "NO_CONTROL_WRITE=1 NO_HELPER_PI_SNAPSHOT=1 NO_DEBUG_FIFO_DRAIN=1 "
        "PRODUCTION_CONTROL_UNCHANGED=1 SOURCE_CONTRACT_VERIFIED=YES "
        "DYNAMIC_OWNER_VERIFIED=NOT_AVAILABLE hard_deadline_includes_retries=1 "
        "target_duration_ms=120000 hard_duration_ms=130000\n"
    )


def _done(stop: str = "NONE") -> str:
    return (
        f"STEP5_F4G_DONE session_elapsed_ms=120000 target_duration_ms=120000 "
        f"hard_duration_ms=130000 stop_reason={stop} single_reader=PASS "
        "step5_complete=NO step5_pass=NO merge_approved=NO\n"
    )


def _helper(cycle: int, end: int, update: int, *, accepted: int = 1,
            epoch_before: str = "00000002", epoch_after: str = "00000002",
            extra: str = "") -> str:
    return (
        "STEP5_F4G_HELPER_ATTEMPT board=DE5 [1-11.2] "
        f"cycle={cycle} retry_n=1 host_start_ms={end - 10} host_end_ms={end} "
        f"RAW_EPOCH_BEFORE={epoch_before} RAW_HELPER_ERROR=FFFFFFF0 "
        f"RAW_UPDATE_COUNT={update:08X} RAW_HELPER_OUTPUT=000003E8 "
        f"RAW_EPOCH_AFTER={epoch_after} EPOCH_BEFORE=2 EPOCH_AFTER=2 "
        "HELPER_ERROR=-16 UPDATE_COUNT=" + str(update) +
        f" HELPER_OUTPUT=1000 TRANSPORT_ERROR=0 PARSE_ERROR=0 "
        f"ODD_OR_SENTINEL=0 EPOCH_CHANGED={int(epoch_before != epoch_after)} "
        f"RANGE_MISMATCH=0 ACCEPTED={accepted} OWNER_UNVERIFIED=1 "
        f"DYNAMIC_OWNER=NOT_AVAILABLE reason={'NONE' if accepted else 'EPOCH_CHANGED'} {extra}\n"
    )


def _main(cycle: int, end: int, sample_n: int, *, fresh: int = 1) -> str:
    return (
        "STEP5_F4G_MAIN_CORE board=DE5 [1-11.2] "
        f"cycle={cycle} host_start_ms={end - 20} host_end_ms={end} "
        "MAIN_CORE_VALID=1 MAIN_TRACE_VALID=1 MAIN_EPOCH_RAW_BEFORE=00000002 "
        "MAIN_EPOCH_RAW_AFTER=00000002 MAIN_EPOCH=2 "
        f"MAIN_SAMPLE_N={sample_n} MAIN_SAMPLE_N_DELTA={sample_n - 1} "
        f"MAIN_SAMPLE_N_ADVANCED={fresh} MAIN_SAMPLE_N_AMBIGUOUS=0 "
        "MAIN_FREQ_ERROR=-5 MAIN_PI_X=10 MAIN_PI_OUTPUT=20 MAIN_PI_CLAMP_SIDE=0 "
        "MAIN_STATE=1 MAIN_MAGIC=1 MAIN_TRANSPORT_FAILURE=0\n"
    )


def _cycle(cycle: int, end: int, *, fresh: int = 1,
           phase_qualified: int = 1, phase_locked: int = 0) -> str:
    return (
        "STEP5_F4G_CYCLE role=SLAVE board=DE5 [1-11.2] "
        f"cycle={cycle} host_start_ms={end - 30} host_end_ms={end} "
        f"HELPER_CORE_VALID=1 HELPER_CORE_FRESH={fresh} HELPER_UPDATE_COUNT={100 + cycle} "
        "HELPER_STATE_VALID=1 HELPER_LOCKED=1 "
        f"MAIN_CORE_VALID=1 MAIN_CORE_FRESH={fresh} MAIN_SAMPLE_N={200 + cycle} "
        f"MAIN_DETECTOR_VALID=1 MAIN_ENABLED=1 MAIN_FREQ_LOCKED=1 "
        f"MAIN_PHASE_LOCKED={phase_locked} POSITION_VALID=0 HELPER_RESIDUAL_PRESENT=UNKNOWN "
        "WR_CORE_VALID=1 PHY_LINK_USABLE=1 CURRENT_WR_STATE=2 PSTAT_LOCKED=1 TERMINAL=0 "
        f"PHASE_CURRENT={phase_qualified} PHASE_QUALIFIED={phase_qualified} "
        "PHASE_QUAL_STREAK=2 PHASE_QUALIFIED_SEEN=1 "
        "HELPER_UNLOCK_STREAK=0 HELPER_RAIL_STREAK=0 FREQ_UNLOCK_STREAK=0 STOP_REASON=NONE\n"
    )


def _service(group: str, end: int, main: int, helper: int) -> str:
    return (
        "STEP5_F4G_SERVICE_COUNTER board=DE5 [1-11.2] cycle=1 "
        f"probe=55 COUNTER_GROUP={group} host_start_ms={end - 5} host_end_ms={end} "
        f"RAW_PACKED=00000000 MAIN_RAW={main:08X} HELPER_RAW={helper:08X} "
        f"MAIN_VALUE={main} HELPER_VALUE={helper} VALID=1 COUNTER_WIDTH_BITS=32 "
        "SOURCE_SEMANTICS=VERIFIED READ_ATOMICITY=WORD_ONLY "
        "DELTA_POLICY=SAME_FIELD_TRUSTED_READS_ONLY\n"
    )


def _wr(role: str, end: int) -> str:
    prefix = "STEP5_F4G_MASTER_CORE" if role == "MASTER" else "STEP5_F4G_WR_CORE"
    return (
        f"{prefix} role={role} board=DE5 [1-11.{1 if role == 'MASTER' else 2}] "
        f"cycle=1 host_start_ms={end - 5} host_end_ms={end} "
        "WR_CORE_VALID=1 DIRECT_VALID=1 TRANSPORT_FAILURE=0 ROLE_IDENTITY_VALID=1 "
        "RESET_FIELDS_VALID=1 TERMINAL=0 PHY_LINK_USABLE=1 CURRENT_WR_STATE=2 "
        "PSTAT_LOCKED=1\n"
    )


def _demand(end: int, *, main_pending: int = 0, helper_pending: int = 0) -> str:
    return (
        "STEP5_F4G_SERVICE_DEMAND board=DE5 [1-11.2] cycle=1 "
        f"STATUS_HOST_START_MS={end - 5} STATUS_HOST_END_MS={end} STATUS_RAW=00000000 "
        f"STATUS_VALID=1 PENDING_HOST_START_MS={end - 4} PENDING_HOST_END_MS={end - 1} "
        "PENDING_RAW=00000000 PENDING_VALID=1 "
        f"MAIN_PENDING={main_pending} HELPER_PENDING={helper_pending} TX_ACTIVE=0 "
        "OWNER_MAIN=0 ACK=0 TIMEOUT=0 DCO_ERROR=0 REASON=0 RT_STATE=0 STATUS_TIME=0 "
        "MAIN_PENDING_COUNT=0 HELPER_PENDING_COUNT=0 ADMISSION_ELIGIBLE=UNKNOWN "
        "DEMAND_RESIDUAL_PRESENT=UNKNOWN\n"
    )


def _base_log(bins: int = 3, *, stale: bool = False) -> str:
    lines = [_config(), _done(), _wr("MASTER", 500), _wr("SLAVE", 600)]
    update = 100
    for index in range(bins):
        for offset in (1000, 3000):
            cycle = index * 2 + (1 if offset == 1000 else 2)
            end = index * 10000 + offset
            update = update if stale else update + 1
            lines.append(_helper(cycle, end, update))
            lines.append(_main(cycle, end, 200 + update, fresh=0 if stale else 1))
            lines.append(_cycle(cycle, end, fresh=0 if stale else 1))
        lines.append(_service("COMPLETED", index * 10000 + 1500,
                             100 + index * 2, 200 + index * 2))
        lines.append(_service("COMPLETED", index * 10000 + 2500,
                             101 + index * 2, 201 + index * 2))
        lines.append(_service("START", index * 10000 + 1500,
                             50 + index * 2, 60 + index * 2))
        lines.append(_service("START", index * 10000 + 2500,
                             51 + index * 2, 61 + index * 2))
    return "".join(lines)


def test_core_never_becomes_full_payload() -> None:
    result = audit.analyze_text(_config() + _done() + _helper(1, 1000, 101))
    assert result["core_full_field_contamination"] is False
    assert result["helper_accepted_count"] == 1


def test_source_contract_and_active_reader_gate() -> None:
    result = audit.analyze_text(_base_log(1))
    gate = result["source_gate"]
    assert gate["config_pass"] is True
    assert gate["done_single_reader_pass"] is True
    assert gate["dynamic_owner"] == "NOT_AVAILABLE"
    assert gate["runtime_identity_pass"] is True


def test_epoch_change_is_rejected_and_retained() -> None:
    result = audit.analyze_text(_config() + _done() +
                                _helper(1, 1000, 101, accepted=0,
                                        epoch_before="00000002", epoch_after="00000004"))
    assert result["helper_accepted_count"] == 0
    assert result["helper_records"][0]["EPOCH_CHANGED"] == 1


def test_insufficient_ten_second_bins_is_not_pass() -> None:
    result = audit.analyze_text(_base_log(1))
    assert result["fresh_bin_count"] == 1
    assert result["classification"] != "MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK"


def test_counter_wrap_ambiguity_downgrades_service_window() -> None:
    text = _config() + _done() + _service("COMPLETED", 1000, 0x7FFFFFFF, 1)
    text += _service("COMPLETED", 2000, 0, 2)
    result = audit.analyze_text(text)
    support = [row for row in result["counter_support"]
               if row["counter_group"] == "COMPLETED" and row["side"] == "MAIN"][0]
    assert support["ambiguous"] == 1
    assert support["service_window"] == "UNKNOWN"


def test_master_optional_position_errors_do_not_gate_wr_core() -> None:
    result = audit.analyze_text(_config() + _done() + _wr("MASTER", 1000))
    assert result["source_gate"]["runtime_identity_pass"] is False
    # The WR record itself remains structurally valid; absence of optional
    # position data must not be counted as a WR-core transport failure.
    assert result["wr_core_count"] == 1


def test_three_core_transport_failures_stop_as_data_unresolved() -> None:
    text = _config() + _done("STOP_DATA_UNRESOLVED")
    result = audit.analyze_text(text)
    assert result["classification"] == "DATA_UNRESOLVED"


def test_stale_producer_has_no_fresh_progress_window() -> None:
    result = audit.analyze_text(_base_log(3, stale=True))
    assert result["fresh_bin_count"] == 0
    assert result["classification"] == "INCONCLUSIVE"


def test_deadline_includes_retry_time() -> None:
    result = audit.analyze_text(_base_log(1))
    config = result["config"]
    assert config["HARD_DEADLINE_INCLUDES_RETRIES"] == 1
    assert config["TARGET_DURATION_MS"] == 120000
    assert config["HARD_DURATION_MS"] == 130000


def test_progress_without_phase_lock_requires_multiple_qualified_bins() -> None:
    result = audit.analyze_text(_base_log(3))
    assert result["classification"] == "MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK"
    assert result["diagnostic_pass"] is True
    assert result["step5_pass"] is False
