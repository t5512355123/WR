"""Offline analysis for the Step6A Global Time observability capture.

The hardware capture has two deliberately different evidence paths:

* probe 62/63 is a coherent PPS-boundary snapshot, guarded by a repeated
  sequence read;
* probe 64 is one packed live TAI-low/cycle sample used only to check short
  interval monotonicity and the cycle wrap.

This module never talks to JTAG.  It only parses saved text and is therefore
safe to run before or after a hardware session.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


_SAMPLE_RE = re.compile(r"^GLOBAL_TIME_SAMPLE\s+(?P<body>.*)$")
_FIELD_RE = re.compile(r"(?P<key>[A-Z0-9_]+)=(?P<value>[^\s]+)")
_TAI_MODULUS = 1 << 40
_COUNT_MODULUS = 1 << 16


def _parse_value(value: str) -> int | str:
    try:
        return int(value, 0)
    except ValueError:
        try:
            return int(value, 10)
        except ValueError:
            return value


def parse_samples(text: str) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = _SAMPLE_RE.match(line.strip())
        if not match:
            continue
        fields = {
            key: _parse_value(value)
            for key, value in _FIELD_RE.findall(match.group("body"))
        }
        samples.append(fields)
    return samples


def _int(sample: dict[str, Any], key: str, default: int = 0) -> int:
    value = sample.get(key, default)
    return value if isinstance(value, int) else default


def _mod_delta(current: int, previous: int, modulus: int) -> int:
    return (current - previous) % modulus


def analyze_text(text: str, *, reference_clock_hz: int = 125_000_000) -> dict[str, Any]:
    samples = parse_samples(text)
    stable = [sample for sample in samples if _int(sample, "STABLE") == 1]
    valid = [
        sample
        for sample in stable
        if _int(sample, "SNAPSHOT_VALID") == 1
        and _int(sample, "SNAPSHOT_TIME_VALID") == 1
        and _int(sample, "SNAPSHOT_PPS_VALID") == 1
    ]

    # Keep one record per PPS snapshot sequence.  The observer samples much
    # faster than PPS, so duplicate sequence values are expected.
    events: list[dict[str, int]] = []
    for sample in valid:
        event = {
            "count": _int(sample, "SNAPSHOT_COUNT") & 0xFFFF,
            "tai": _int(sample, "TAI") & (_TAI_MODULUS - 1),
            "cycles": _int(sample, "CYCLES"),
        }
        if not events or event["count"] != events[-1]["count"]:
            events.append(event)

    sequence_deltas: list[int] = []
    tai_deltas: list[int] = []
    for previous, current in zip(events, events[1:]):
        sequence_deltas.append(
            _mod_delta(current["count"], previous["count"], _COUNT_MODULUS)
        )
        tai_deltas.append(
            _mod_delta(current["tai"], previous["tai"], _TAI_MODULUS)
        )

    sequence_pass = len(events) >= 2 and all(delta > 0 for delta in sequence_deltas)
    tai_increment_pass = (
        len(tai_deltas) > 0
        and sequence_pass
        and all(tai_delta == count_delta
                for tai_delta, count_delta in zip(tai_deltas, sequence_deltas))
    )

    # pps_csync is asserted immediately before the reference counter rolls
    # over, so the snapshot normally contains PERIOD-1.  Accept the equivalent
    # post-rollover representation as well to keep the analyzer valid if the
    # implementation is retimed by one reference-clock cycle.
    boundary_window = 16
    boundary_pass = bool(events) and all(
        event["cycles"] <= boundary_window
        or event["cycles"] >= reference_clock_hz - 1 - boundary_window
        for event in events
    )

    live = [
        sample
        for sample in stable
        if _int(sample, "STATUS_TIME_VALID") == 1
        and _int(sample, "STATUS_PPS_VALID") == 1
    ]
    live_wraps = 0
    live_bad_steps = 0
    for previous, current in zip(live, live[1:]):
        previous_cycles = _int(previous, "LIVE_CYCLES")
        current_cycles = _int(current, "LIVE_CYCLES")
        if current_cycles >= previous_cycles:
            continue
        if (previous_cycles >= reference_clock_hz - 1024
                and current_cycles <= 1024):
            live_wraps += 1
        else:
            live_bad_steps += 1
    live_monotonic_pass = len(live) >= 2 and live_bad_steps == 0
    live_wrap_pass = live_wraps >= 1

    if not samples:
        classification = "NO_GLOBAL_TIME_SAMPLES"
    elif not stable:
        classification = "ATOMIC_SNAPSHOT_UNSTABLE"
    elif not valid:
        classification = "GLOBAL_TIME_NOT_VALID"
    elif len(events) < 2:
        classification = "INSUFFICIENT_PPS_SNAPSHOTS"
    elif not tai_increment_pass:
        classification = "TAI_NOT_INCREMENTING_WITH_PPS"
    elif not live_monotonic_pass:
        classification = "LIVE_CYCLES_NOT_MONOTONIC"
    elif not live_wrap_pass:
        classification = "LIVE_CYCLE_WRAP_NOT_OBSERVED"
    else:
        classification = "GLOBAL_TIME_COUNTER_VALID"

    return {
        "classification": classification,
        "sample_count": len(samples),
        "stable_sample_count": len(stable),
        "valid_sample_count": len(valid),
        "pps_event_count": len(events),
        "sequence_deltas": sequence_deltas,
        "tai_deltas": tai_deltas,
        "boundary_cycle_pass": boundary_pass,
        "live_sample_count": len(live),
        "live_wrap_count": live_wraps,
        "live_bad_step_count": live_bad_steps,
        "cycles_monotonic": live_monotonic_pass,
        "cycles_wrap": live_wrap_pass,
        "tai_increment_at_wrap": tai_increment_pass,
        "diagnostic_pass": classification == "GLOBAL_TIME_COUNTER_VALID",
        # This is intentionally not Step6B.  A dual-board same-boundary
        # trigger has not been implemented or evaluated by this analyzer.
        "step6b_trigger_pass": False,
    }


def compare_board_texts(master_text: str, slave_text: str) -> dict[str, Any]:
    """Compare boundary snapshots when the captures share a TAI value.

    Separate JTAG sessions are not treated as same-PPS evidence.  If there is
    no shared TAI boundary, the result is explicitly INCONCLUSIVE instead of
    pretending that sequential host reads were simultaneous.
    """

    master = analyze_text(master_text)
    slave = analyze_text(slave_text)
    master_events = {
        event["tai"]: event
        for event in _events_from_text(master_text)
    }
    slave_events = {
        event["tai"]: event
        for event in _events_from_text(slave_text)
    }
    shared_tai = sorted(set(master_events) & set(slave_events))
    comparisons = [
        {
            "tai": tai,
            "master_cycles": master_events[tai]["cycles"],
            "slave_cycles": slave_events[tai]["cycles"],
            "cycle_delta": abs(
                master_events[tai]["cycles"] - slave_events[tai]["cycles"]
            ),
        }
        for tai in shared_tai
    ]
    return {
        "master": master,
        "slave": slave,
        "shared_tai_boundaries": len(shared_tai),
        "same_boundary_evidence": bool(shared_tai),
        "comparisons": comparisons,
        "classification": (
            "SAME_TAI_BOUNDARY_OBSERVED" if shared_tai else "INCONCLUSIVE_NO_SHARED_TAI"
        ),
    }


def _events_from_text(text: str) -> list[dict[str, int]]:
    samples = parse_samples(text)
    events: list[dict[str, int]] = []
    for sample in samples:
        if not (
            _int(sample, "STABLE") == 1
            and _int(sample, "SNAPSHOT_VALID") == 1
            and _int(sample, "SNAPSHOT_TIME_VALID") == 1
            and _int(sample, "SNAPSHOT_PPS_VALID") == 1
        ):
            continue
        event = {
            "count": _int(sample, "SNAPSHOT_COUNT") & 0xFFFF,
            "tai": _int(sample, "TAI") & (_TAI_MODULUS - 1),
            "cycles": _int(sample, "CYCLES"),
        }
        if not events or event["count"] != events[-1]["count"]:
            events.append(event)
    return events


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("--compare", type=Path)
    args = parser.parse_args()
    first_text = args.capture.read_text(encoding="utf-8")
    if args.compare:
        result = compare_board_texts(first_text, args.compare.read_text(encoding="utf-8"))
    else:
        result = analyze_text(first_text)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
