from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4e_acquisition_audit as audit  # noqa: E402


def _sample(
    elapsed: int,
    sample_n: int,
    *,
    role: str = "SLAVE",
    advanced: int = 1,
    phase_locked: int = 0,
    residual: int = 1,
    helper_start: int = 200,
    helper_completed: int = 200,
    main_start: int = 300,
    main_completed: int = 300,
    generation: int = 1,
) -> str:
    values = {
        "run_role": "acquisition",
        "role": role,
        "board": "DE5 [1-11.2]" if role == "SLAVE" else "DE5 [1-11.1]",
        "sample": elapsed // 1000 + 1,
        "observer_sample_n": elapsed // 1000 + 1,
        "elapsed_ms": elapsed,
        "read_start_ms": 100000 + elapsed,
        "read_end_ms": 100100 + elapsed,
        "frame_valid": 1,
        "core_frame_valid": 1,
        "transport_valid": 1,
        "role_identity_valid": 1,
        "phy_link_usable": 1,
        "si_config_done": 1,
        "wr_ready": 1,
        "core_tm_link_up": 1,
        "core_link_ok": 1,
        "wr_rx_ready": 1,
        "wr_tx_ready": 1,
        "ptp_state": 8 if role == "SLAVE" else 6,
        "pd_state": 3,
        "ext_state": 1,
        "wrc_mode": 3 if role == "SLAVE" else 2,
        "wr_state": 2 if role == "SLAVE" else 3,
        "wr_disable_valid": 0,
        "wr_failure_reason": 0,
        "boot_generation": generation,
        "cpu_reset_count": 1,
        "wr_core_reset_count": 1,
        "si_config_drop_count": 1,
        "reset_fields_valid": 1,
        "reset_stable": 1,
        "main_core_valid": 1 if role == "SLAVE" else 0,
        "main_trace_valid": 1 if role == "SLAVE" else 0,
        "main_detector_valid": 1 if role == "SLAVE" else 0,
        "main_detector_stable": 1 if role == "SLAVE" else 0,
        "main_detector_enabled": 1 if role == "SLAVE" else 0,
        "main_detector_freq_locked": 1 if role == "SLAVE" else 0,
        "main_detector_phase_locked": phase_locked,
        "main_detector_locked": 0,
        "main_freq_lock_count": 50,
        "main_phase_lock_count": 100,
        "main_freq_threshold": 50,
        "main_phase_threshold": 1200,
        "main_phase_input_domain": "PHASE" if role == "SLAVE" else "FREQUENCY",
        "main_phase_inband": 1,
        "main_pi_x": 25,
        "main_sample_n": sample_n,
        "main_update_count": sample_n,
        "main_sample_n_delta": 1 if advanced else 0,
        "main_sample_n_delta_ambiguous": 0,
        "main_sample_n_advanced": advanced,
        "main_publication_epoch": 2 + elapsed // 1000 * 2,
        "main_trace_publication_epoch_before_raw": f"0x{2 + elapsed // 1000 * 2:08X}",
        "main_trace_publication_epoch_after_raw": f"0x{2 + elapsed // 1000 * 2:08X}",
        "helper_measurement_ok": 1,
        "helper_locked": 1,
        "helper_error": 10,
        "helper_output": 52000,
        "helper_target_code": 1234,
        "helper_applied_code": 1230,
        "helper_residual_present": residual,
        "helper_measurement_residual_present": residual,
        "position_ok": 1,
        "l2_valid": 1,
        "l2_main_pending": 0,
        "l2_helper_pending": 0,
        "l2_main_pending_count": 0,
        "l2_helper_pending_count": 10,
        "l2_main_start_count": main_start,
        "l2_helper_start_count": helper_start,
        "l2_main_completed_count": main_completed,
        "l2_helper_completed_count": helper_completed,
        "l2_main_failed_count": 0,
        "l2_helper_failed_count": 0,
        "acquisition_diagnostic_allowed": 1 if role == "SLAVE" else 0,
        "entry_class": "ELIGIBLE" if role == "SLAVE" else "MASTER_BACKGROUND",
        "stop_reason": "NONE",
    }
    return "STEP5_F4E_SAMPLE " + " ".join(f"{key}={value}" for key, value in values.items())


def _header(done: str = "TARGET_REACHED") -> str:
    return (
        "STEP5_F4E_CONFIG experiment=EXP-S5-F4E-ACQUISITION-MAIN-PHASE-PROGRESS-20260915 "
        "run_role=acquisition target_duration_ms=120000 hard_duration_ms=130000\n"
        f"STEP5_F4E_DONE session_elapsed_ms=21000 run_end_reason={done} stop_reason=NONE "
        "single_reader=PASS step5_complete=NO merge_approved=NO\n"
    )


def test_phase_progress_is_diagnostic_only() -> None:
    lines = [_sample(0, 100, advanced=0, helper_start=200,
                     helper_completed=200, main_start=300, main_completed=300)]
    lines.extend(_sample(index * 1000, 100 + index, helper_start=200 + index,
                         helper_completed=200 + index, main_start=300 + index,
                         main_completed=300 + index) for index in range(1, 21))
    result = audit.analyze_text(_header() + "\n".join(lines))
    slave = result["roles"]["SLAVE"]
    assert result["overall_result"] == "PHASE_CONVERGENCE_NOT_REACHED"
    assert result["overall_pass"] is True
    assert slave["fresh_main_producer_samples"] == 20
    assert slave["best_segment"]["duration_ms"] == 20000
    assert result["step5_pass"] is False
    assert result["merge_approved"] is False


def test_phase_lock_observed_still_does_not_close_step5() -> None:
    lines = [_sample(index * 1000, 200 + index, advanced=index > 0, phase_locked=1)
             for index in range(21)]
    for index, line in enumerate(lines):
        # Rebuild each fixture with advancing service counters so this test
        # exercises phase status rather than the separate admission heuristic.
        lines[index] = _sample(index * 1000, 200 + index, advanced=index > 0,
                                phase_locked=1, helper_start=500 + index,
                                helper_completed=500 + index, main_start=600 + index,
                                main_completed=600 + index)
    result = audit.analyze_text(_header() + "\n".join(lines))
    assert result["overall_result"] == "LOCK_OBSERVED_NOT_CLOSED"
    assert result["step5_complete"] is False
    assert result["step5_pass"] is False


def test_helper_demand_without_helper_service_is_separate_from_main_progress() -> None:
    lines = [_sample(index * 1000, 300 + index, advanced=index > 0,
                     helper_start=500, helper_completed=500,
                     main_start=600 + index, main_completed=600 + index)
             for index in range(5)]
    result = audit.analyze_text(_header() + "\n".join(lines))
    slave = result["roles"]["SLAVE"]
    assert slave["main_progress_samples"] == 4
    assert slave["helper_service_stalled_window_count"] == 4
    assert result["overall_result"] == "HELPER_ADMISSION_SUSPECTED"


def test_main_service_block_requires_demand_and_no_main_counter_progress() -> None:
    lines = [_sample(index * 1000, 400, advanced=0,
                     main_start=700, main_completed=700)
             for index in range(5)]
    result = audit.analyze_text(_header() + "\n".join(lines))
    assert result["overall_result"] == "MAIN_SERVICE_BLOCKED_SUSPECTED"


def test_no_entry_is_not_a_step5_pass() -> None:
    lines = [_sample(index * 1000, 500 + index, role="MASTER", advanced=index > 0)
             for index in range(3)]
    result = audit.analyze_text(_header() + "\n".join(lines))
    assert result["overall_result"] == "NO_ELIGIBLE_ACQUISITION_WINDOW"
    assert result["step5_pass"] is False


def test_generation_change_invalidates_the_segment() -> None:
    lines = [_sample(0, 600, advanced=0), _sample(1000, 601, generation=2)]
    result = audit.analyze_text(_header() + "\n".join(lines))
    assert result["overall_result"] == "DETECTOR_CONSISTENCY_UNRESOLVED"
