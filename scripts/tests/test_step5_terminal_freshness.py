from __future__ import annotations

"""Offline regression model for f4g_emit_wr_core terminal freshness.

The Tcl observer owns the actual implementation. This small model mirrors only
the role-dependent terminal state machine so the sticky-failure boundary can be
tested without an FPGA or JTAG session.
"""

from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OBSERVER = ROOT / "scripts" / "jtag" / "read_step5_main_frequency_prelock_observability.tcl"


@dataclass
class FreshnessState:
    candidate_seen: bool = False
    previous_candidate: int = 0
    terminal_streak: int = 0


def emit(role: str, candidate: int, state: FreshnessState) -> dict[str, int | str]:
    """Mirror the Tcl role branch for one already-decoded candidate."""
    passive = role in {"f4l", "f4s", "f4j"}
    mode = "SESSION_EDGE" if passive else "LEGACY"
    state_changed = int(bool(candidate))
    fresh_edge = 0

    if passive:
        if not state.candidate_seen:
            state.candidate_seen = True
            state.previous_candidate = int(bool(candidate))
            state_changed = 0
        else:
            state_changed = int(bool(candidate) != bool(state.previous_candidate))
            if candidate and not state.previous_candidate:
                fresh_edge = 1
            state.previous_candidate = int(bool(candidate))
        terminal = int(bool(candidate) and (fresh_edge or state.terminal_streak > 0))
    else:
        terminal = int(bool(candidate))

    if terminal:
        state.terminal_streak += 1
    else:
        state.terminal_streak = 0

    return {
        "mode": mode,
        "state_changed": state_changed,
        "fresh_edge": fresh_edge,
        "terminal": terminal,
        "streak": state.terminal_streak,
        "session_ended": int(state.terminal_streak >= 2),
    }


def run(role: str, candidates: list[int]) -> list[dict[str, int | str]]:
    state = FreshnessState()
    return [emit(role, candidate, state) for candidate in candidates]


def test_f4j_first_sticky_candidate_is_baseline_only() -> None:
    result = run("f4j", [1])[0]
    assert result == {
        "mode": "SESSION_EDGE",
        "state_changed": 0,
        "fresh_edge": 0,
        "terminal": 0,
        "streak": 0,
        "session_ended": 0,
    }


def test_f4j_sticky_candidate_stays_nonterminal() -> None:
    results = run("f4j", [1, 1])
    assert [item["fresh_edge"] for item in results] == [0, 0]
    assert [item["terminal"] for item in results] == [0, 0]
    assert [item["streak"] for item in results] == [0, 0]


def test_f4j_sticky_candidate_can_clear_without_terminal() -> None:
    results = run("f4j", [1, 0])
    assert results[1]["state_changed"] == 1
    assert results[1]["fresh_edge"] == 0
    assert results[1]["terminal"] == 0
    assert results[1]["streak"] == 0


def test_f4j_fresh_zero_to_one_is_terminal_edge() -> None:
    results = run("f4j", [0, 1])
    assert results[1]["state_changed"] == 1
    assert results[1]["fresh_edge"] == 1
    assert results[1]["terminal"] == 1
    assert results[1]["streak"] == 1


def test_f4j_fresh_edge_persistent_stops_on_streak_two() -> None:
    results = run("f4j", [0, 1, 1])
    assert results[1]["terminal"] == 1
    assert results[2]["fresh_edge"] == 0
    assert results[2]["terminal"] == 1
    assert results[2]["streak"] == 2
    assert results[2]["session_ended"] == 1


def test_f4l_and_f4s_keep_session_edge_behavior() -> None:
    for role in ("f4l", "f4s"):
        results = run(role, [1, 1, 0, 1])
        assert [item["mode"] for item in results] == ["SESSION_EDGE"] * 4
        assert [item["terminal"] for item in results] == [0, 0, 0, 1]
        assert results[3]["fresh_edge"] == 1


def test_f4g_and_f4m_remain_legacy() -> None:
    for role in ("f4g", "f4m"):
        results = run(role, [1, 1])
        assert [item["mode"] for item in results] == ["LEGACY", "LEGACY"]
        assert [item["terminal"] for item in results] == [1, 1]
        assert results[1]["session_ended"] == 1


def test_observer_source_has_only_the_f4j_role_extension() -> None:
    source = OBSERVER.read_text(encoding="utf-8")
    assert 'set terminal_freshness_mode SESSION_EDGE' in source
    assert '$::f4g_run_role eq "f4l"' in source
    assert '$::f4g_run_role eq "f4s"' in source
    assert '$::f4g_run_role eq "f4j"' in source
    assert "F4L/F4S/F4J must not turn historical sticky state" in source
    assert "F4G/F4M retain legacy" in source
