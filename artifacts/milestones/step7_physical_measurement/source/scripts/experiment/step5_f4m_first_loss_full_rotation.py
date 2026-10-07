#!/usr/bin/env python3
"""Validate the observer-only F4M page/first-loss closure capture.

F4M uses the existing F4L 34-word wire image and adds reader-side page
sequence records plus passive WRS_S_LOCK samples.  This module deliberately
keeps the F4L frame validator as the source of truth for page payloads, then
adds the F4M correlation gates without treating non-atomic multi-register
samples as one firmware cycle.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional, Sequence, Tuple

from step5_f4l_main_phase_drift_integrator import analyze_text as analyze_f4l
from step5_f4l_main_phase_drift_integrator import _flag, _int  # type: ignore


F4M_EVENT_RE = re.compile(r"^(STEP5_)F4M_(MAIN_DIAG|CYCLE|CONFIG|DONE)\b")
INVALID = {"", "INVALID", "UNKNOWN", "TIMEOUT", "NOT_MEASURED", "NONE"}


def _normalize_for_f4l(text: str) -> str:
    """Let the established F4L frame parser validate F4M's same wire image."""

    return "\n".join(
        F4M_EVENT_RE.sub(r"\1F4L_\2", line) for line in text.splitlines()
    )


def _parse_line(line: str) -> Tuple[str, Dict[str, str]]:
    parts = line.strip().split()
    if not parts:
        return "", {}
    fields: Dict[str, str] = {}
    for token in parts[1:]:
        if "=" in token:
            key, value = token.split("=", 1)
            fields[key.upper()] = value
    return parts[0], fields


def _rows(text: str, kind: str) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for line in text.splitlines():
        event, fields = _parse_line(line)
        if event == kind:
            rows.append(fields)
    return rows


def _count(rows: Sequence[Dict[str, str]], key: str) -> int:
    return sum(1 for row in rows if _flag(row.get(key)))


def analyze_text(text: str, source: str = "<text>") -> Dict[str, Any]:
    normalized = _normalize_for_f4l(text)
    base = analyze_f4l(normalized, source)
    page_rows = _rows(text, "STEP5_F4M_PAGE_OBSERVATION")
    loss_rows = _rows(text, "STEP5_F4M_FIRST_LOSS_SAMPLE")
    cycles = _rows(text, "STEP5_F4M_CYCLE")

    observed_page_counts = {str(page): 0 for page in range(3)}
    observed_page_sequence: List[int] = []
    page_observation_problems: List[str] = []
    for row in page_rows:
        page = _int(row.get("CURRENT_PAGE"))
        if page is None or page not in range(3):
            page_observation_problems.append("CURRENT_PAGE_INVALID")
            continue
        observed_page_counts[str(page)] += 1
        observed_page_sequence.append(page)
        previous = row.get("PREVIOUS_PAGE", "INVALID")
        expected = _int(row.get("EXPECTED_PAGE"))
        if previous not in INVALID and expected is None:
            page_observation_problems.append("EXPECTED_PAGE_MISSING")
        if row.get("SEMANTICS", "").upper() not in {
            "UNIQUE_COHERENT_READER_OBSERVATION",
            "",
        }:
            page_observation_problems.append("PAGE_SEMANTICS_UNEXPECTED")

    page_count_matches = all(
        observed_page_counts[str(page)] == base["page_counts"].get(str(page), 0)
        for page in range(3)
    )
    page_closure = all(observed_page_counts[str(page)] > 0 for page in range(3))

    trace_valid_count = _count(loss_rows, "TRACE_VALID")
    trace_stages = sorted(
        {
            stage
            for stage in (_int(row.get("SLOCK_STAGE")) for row in loss_rows)
            if stage is not None
        }
    )
    terminal_sample_count = sum(
        1
        for row in loss_rows
        if _flag(row.get("WR_TERMINAL"))
        or _int(row.get("SLOCK_STAGE")) == 4
        or _int(row.get("SLOCK_REMAINING_MS")) == 0
    )
    no_first_loss_before_end = terminal_sample_count == 0 and bool(loss_rows)
    first_loss_window_complete = bool(loss_rows) and (
        terminal_sample_count > 0 or no_first_loss_before_end
    )

    helper_valid_cycles = _count(cycles, "HELPER_CORE_VALID")
    main_valid_cycles = _count(cycles, "MAIN_F4L_VALID")
    main_progress_intervals = base.get("main_progress_intervals", 0)
    generation_ok = len(base.get("generations", [])) <= 1
    observer_contract_ok = all(
        _flag(base.get("config", {}).get(key))
        for key in (
            "READ_ONLY_OBSERVER",
            "ONE_READER",
            "NO_CONTROL_WRITE",
            "NO_HELPER_PI_SNAPSHOT",
            "NO_RTL_OR_SDB_CHANGE",
            "CONTROL_PARAMETERS_UNCHANGED",
        )
    )

    closure_ok = bool(
        base.get("diagnostic_complete")
        and page_rows
        and page_closure
        and page_count_matches
        and not page_observation_problems
        and helper_valid_cycles > 0
        and main_valid_cycles > 0
        and main_progress_intervals > 0
        and generation_ok
        and trace_valid_count > 0
        and first_loss_window_complete
        and observer_contract_ok
    )

    done = base.get("done", {})
    stop_reason = str(done.get("STOP_REASON", "NONE")).upper()
    if base.get("invalid_frame_count", 0):
        classification = "FRAME_SCHEMA_INVALID"
    elif not base.get("frame_count"):
        classification = "NO_VALID_F4M_FRAMES"
    elif closure_ok:
        classification = "DIAGNOSTIC_COMPLETE"
    elif stop_reason not in {"", "NONE"}:
        classification = "DIAGNOSTIC_STOPPED_" + stop_reason
    else:
        classification = "INCONCLUSIVE"

    result = dict(base)
    result.update(
        {
            "source": source,
            "schema": dict(base.get("schema", {}), observer_role="F4M"),
            "page_observation_count": len(page_rows),
            "page_observation_sequence": observed_page_sequence,
            "observed_page_counts": observed_page_counts,
            "page_observation_problems": sorted(set(page_observation_problems)),
            "page_count_matches_frame_rows": page_count_matches,
            "page_closure": page_closure,
            "first_loss_sample_count": len(loss_rows),
            "first_loss_trace_valid_count": trace_valid_count,
            "first_loss_trace_stages": trace_stages,
            "terminal_sample_count": terminal_sample_count,
            "no_first_loss_before_end": no_first_loss_before_end,
            "first_loss_window_complete": first_loss_window_complete,
            "helper_valid_cycle_count": helper_valid_cycles,
            "main_valid_cycle_count": main_valid_cycles,
            "observer_contract_ok": observer_contract_ok,
            "diagnostic_complete": closure_ok,
            "diagnostic_pass": closure_ok,
            "classification": classification,
            # This run is deliberately observational; it cannot establish
            # PSTAT.locked or claim Step5 completion.
            "step5_complete": False,
            "step5_pass": False,
            "merge_approved": False,
        }
    )
    return result


def analyze_file(path: Any) -> Dict[str, Any]:
    return analyze_text(path.read_text(encoding="utf-8", errors="replace"), str(path))


if __name__ == "__main__":
    import argparse
    import json
    from pathlib import Path

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = analyze_file(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "classification": result["classification"],
        "diagnostic_pass": result["diagnostic_pass"],
        "step5_pass": result["step5_pass"],
        "page_counts": result["page_counts"],
        "first_loss_sample_count": result["first_loss_sample_count"],
    }, sort_keys=True))
    raise SystemExit(0 if result["diagnostic_pass"] else 2)
