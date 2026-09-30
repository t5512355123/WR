from __future__ import annotations

import unittest

from analyze_startup_admission_trace import analyze_text, counter_delta32, first_inactive_boundary


def group_line(name: str, **values: str) -> str:
    common = f"S6S_GROUP board=DE5_1-11.2 sample=0000 group={name} valid=1"
    return common + " " + " ".join(f"{key}={value}" for key, value in values.items())


def event_group(**values: str) -> str:
    return group_line("EVENTS", **values)


def row_line(state: int = 1, ready: int = 0) -> str:
    return (
        "S6S_ROW board=DE5_1-11.2 sample=0000 STRUCTURALLY_TRUSTED_ROW=1 "
        f"SERVO_STATE={state} STEP1_GATE=1 HELPER_LOCK={ready} "
        f"MAIN_FREQ_LOCK={ready} MAIN_PHASE_LOCK={ready} MAIN_LOCK={ready} PSTAT_LOCK={ready} "
        f"READY_STREAK_ROWS={10 if ready else 0} READY_STREAK_MS={10000 if ready else 0} "
        "ROW_SPACING_MS=700"
    )


def admission(**values: str) -> str:
    return group_line("ADMISSION", **values)


def spll(**values: str) -> str:
    return group_line("SPLL", **values)


def chain_values(**overrides: str) -> dict[str, str]:
    values = {
        "DMTD_REF_ACCEPT_COUNT_RAW": "00000010",
        "DMTD_FB_ACCEPT_COUNT_RAW": "00000010",
        "DMTD_REF_EVENT_COUNT_RAW": "00000010",
        "DMTD_FB_EVENT_COUNT_RAW": "00000010",
        "TAG_VALID_COUNT_RAW": "00000010",
        "TRR_WRITE_COUNT_RAW": "00000010",
        "TRR_POP_COUNT_RAW": "00000010",
        "IRQ_COUNT_RAW": "00000010",
        "HELPER_UPDATE_COUNT_RAW": "00000010",
    }
    values.update(overrides)
    return values


def all_baseline_groups(first: bool, event_overrides: dict[str, str] | None = None) -> list[str]:
    low = "00000000" if first else "00000001"
    event_values = {key: ("00000000" if first else value) for key, value in chain_values().items()}
    if event_overrides:
        event_values.update(event_overrides)
    return [
        admission(
            LOCK_ENABLE_COUNT_RAW=low,
            WR_LOCK_POLL_COUNT_RAW=low,
            WR_LOCK_CALIB_FAIL_COUNT_RAW=low,
            LOCK_UNLOCKED_COUNT_RAW=low,
            PTP_RX_COUNT_RAW=low,
            PTP_TX_COUNT_RAW=low,
            ETH_RX_COUNT_RAW=low,
            ETH_TX_COUNT_RAW=low,
        ),
        spll(
            SPLL_STATE_TRANSITIONS_RAW=low,
            SPLL_INIT_COUNT_RAW=low,
            SPLL_STATE_VISIT_MASK_RAW=low,
            SPLL_CLEAR_DACS_COUNT_RAW=low,
            SPLL_LAST_INIT_TICS_RAW=low,
        ),
        event_group(**event_values),
    ]


class StartupAdmissionTraceTests(unittest.TestCase):
    def test_counter_wrap_is_accepted_only_near_uint32_edges(self) -> None:
        self.assertEqual(counter_delta32(0xFFFFFFFE, 2), (4, "ROLLOVER"))
        self.assertEqual(counter_delta32(20, 2), (None, "DISCONTINUITY"))

    def test_no_lock_or_sequencer_progress_is_only_a_boundary_candidate(self) -> None:
        # Two valid observations are required to compute deltas; identical
        # records model a covered window with no observed progress.
        groups = all_baseline_groups(True) * 2
        from analyze_startup_admission_trace import parse_fields

        parsed = [parse_fields(line) for line in groups]
        self.assertEqual(
            first_inactive_boundary(parsed),
            "WR_LOCK_ADMISSION_NO_OBSERVED_PROGRESS",
        )

    def test_lock_poll_progress_without_spll_progress_stops_at_startup_boundary(self) -> None:
        first = all_baseline_groups(True)
        last = all_baseline_groups(False)
        last[1] = spll(
            SPLL_STATE_TRANSITIONS_RAW="00000000",
            SPLL_INIT_COUNT_RAW="00000000",
            SPLL_STATE_VISIT_MASK_RAW="00000000",
            SPLL_CLEAR_DACS_COUNT_RAW="00000000",
            SPLL_LAST_INIT_TICS_RAW="00000000",
        )
        from analyze_startup_admission_trace import parse_fields

        parsed = [parse_fields(line) for line in first + last]
        self.assertEqual(
            first_inactive_boundary(parsed),
            "WR_LOCK_TO_SPLL_STARTUP_NO_OBSERVED_PROGRESS",
        )

    def test_first_zero_chain_counter_is_reported_without_claiming_cause(self) -> None:
        first = all_baseline_groups(True)
        last_events = chain_values(TRR_WRITE_COUNT_RAW="00000000")
        last = all_baseline_groups(False, last_events)
        from analyze_startup_admission_trace import parse_fields

        parsed = [parse_fields(line) for line in first + last]
        self.assertEqual(
            first_inactive_boundary(parsed), "TAG_TO_TRR_WRITE_NO_OBSERVED_PROGRESS"
        )

    def test_phase_state_boundary_is_not_a_step6_pass(self) -> None:
        groups = []
        for name in ("HEALTH", "ADMISSION", "SPLL", "EVENTS"):
            groups.extend([group_line(name), group_line(name)])
        text = "\n".join(
            groups
            + [row_line(state=4), "S6S_STOP duration_ms=300000 elapsed_ms=800 stop_reason=PHASE_STATE_BOUNDARY"]
        )
        summary = analyze_text(text)
        self.assertEqual(summary["result"], "PHASE_STATE_REACHED_BOUNDARY_STOPPED")
        self.assertTrue(summary["phase_boundary_seen"])

    def test_readiness_stop_is_startup_recovery_not_lock_acceptance(self) -> None:
        groups = []
        for name in ("HEALTH", "ADMISSION", "SPLL", "EVENTS"):
            groups.extend([group_line(name), group_line(name)])
        text = "\n".join(
            groups
            + [row_line(ready=1), "S6S_STOP duration_ms=300000 elapsed_ms=10000 stop_reason=READINESS_REACHED"]
        )
        summary = analyze_text(text)
        self.assertEqual(summary["result"], "STARTUP_RECOVERED_BOUNDARY_STOPPED")

    def test_counter_discontinuity_is_not_a_negative_delta(self) -> None:
        records = [
            {"group": "EVENTS", "valid": "1", "COUNT_RAW": "00000020"},
            {"group": "EVENTS", "valid": "1", "COUNT_RAW": "00000002"},
        ]
        from analyze_startup_admission_trace import _counter_delta

        self.assertEqual(_counter_delta(records, "EVENTS", "COUNT_RAW"), (None, "DISCONTINUITY"))

    def test_complete_window_needs_all_group_coverage(self) -> None:
        rows = [row_line(), row_line()]
        groups = []
        for name in ("HEALTH", "ADMISSION", "SPLL", "EVENTS"):
            groups.extend([group_line(name), group_line(name)])
        text = "\n".join(rows + groups + ["S6S_STOP duration_ms=300000 elapsed_ms=300100 stop_reason=DURATION_LIMIT"])
        self.assertEqual(analyze_text(text)["result"], "READ_ONLY_STARTUP_TRACE_COMPLETE")


if __name__ == "__main__":
    unittest.main()
