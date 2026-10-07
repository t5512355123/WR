"""Analyze the ec1f25e8-source-rebuild Master-last Step6 capture.

This analyzer distinguishes a real Slave reacquisition from a persistent
sticky PATTERN_READY/link state.  If the Slave was already linked before the
Master program, a fresh sticky drop counter delta is required before the
five-sample recovery streak can pass.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
BASELINE_RE = re.compile(r"^REBUILD_BASELINE_PAIR\s+(?P<body>.*)$")
RECOVERY_RE = re.compile(r"^REBUILD_RECOVERY_PAIR\s+(?P<body>.*)$")
BASELINE_RESULT_RE = re.compile(r"^BASELINE_RESULT=(?P<value>[^\s]+)")
RECOVERY_RESULT_RE = re.compile(r"^REBUILD_RECOVERY_RESULT=(?P<value>[^\s]+)")
SCALAR_RE = re.compile(r"^(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
INVALID = {"", "INVALID", "TIMEOUT", "DECREASED", "NA", "N/A", "UNKNOWN"}


def _value(text: str) -> int | str:
    try:
        if text.lower().startswith("0x"):
            return int(text, 16)
        return int(text, 10)
    except ValueError:
        return text


def _int(row: dict[str, Any], key: str, default: int | None = None) -> int | None:
    value = row.get(key, default)
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if not isinstance(value, str) or value.upper() in INVALID:
        return default
    try:
        return int(value, 0)
    except ValueError:
        try:
            return int(value, 10)
        except ValueError:
            try:
                return int(value, 16)
            except ValueError:
                return default


def _parse(text: str) -> dict[str, Any]:
    baseline: list[dict[str, Any]] = []
    recovery: list[dict[str, Any]] = []
    scalars: dict[str, int | str] = {}
    baseline_result: str | None = None
    recovery_result: str | None = None
    for line in text.splitlines():
        line = line.strip()
        match = BASELINE_RE.match(line)
        if match:
            baseline.append(
                {key.upper(): _value(value) for key, value in FIELD_RE.findall(match.group("body"))}
            )
            continue
        match = RECOVERY_RE.match(line)
        if match:
            recovery.append(
                {key.upper(): _value(value) for key, value in FIELD_RE.findall(match.group("body"))}
            )
            continue
        match = BASELINE_RESULT_RE.match(line)
        if match:
            baseline_result = match.group("value")
            continue
        match = RECOVERY_RESULT_RE.match(line)
        if match:
            recovery_result = match.group("value")
            continue
        match = SCALAR_RE.match(line)
        if match:
            scalars[match.group("key").upper()] = _value(match.group("value"))
    return {
        "baseline": baseline,
        "recovery": recovery,
        "scalars": scalars,
        "baseline_result": baseline_result,
        "recovery_result": recovery_result,
    }


def _parse_scalars(text: str) -> dict[str, int | str]:
    values: dict[str, int | str] = {}
    for line in text.splitlines():
        match = SCALAR_RE.match(line.strip())
        if match:
            values[match.group("key").upper()] = _value(match.group("value"))
    return values


def _max_streak(rows: list[dict[str, Any]], key: str, minimum: int = 1) -> int:
    best = current = 0
    for row in rows:
        if (_int(row, key, 0) or 0) >= minimum:
            current += 1
            best = max(best, current)
        else:
            current = 0
    return best


def _all_valid(rows: list[dict[str, Any]]) -> bool:
    return bool(rows) and all(_int(row, "READ_VALID", 0) == 1 for row in rows)


def analyze_text(
    baseline_text: str,
    recovery_text: str,
    *,
    source: str = "",
    build_manifest_text: str = "",
    sequence_text: str = "",
) -> dict[str, Any]:
    base = _parse(baseline_text)
    rec = _parse(recovery_text)
    baseline = base["baseline"]
    recovery = rec["recovery"]
    scalars = base["scalars"]

    baseline_sample_count = _int(scalars, "BASELINE_SAMPLE_COUNT", len(baseline)) or 0
    link_up_count = _int(scalars, "BASELINE_SLAVE_LINK_UP_COUNT", -1)
    link_mode = scalars.get("BASELINE_SLAVE_LINK_MODE", "UNKNOWN")
    if not isinstance(link_mode, str):
        link_mode = str(link_mode)

    baseline_transport_errors = sum(
        1 for row in baseline if _int(row, "READ_VALID", 0) != 1
    )
    recovery_transport_errors = sum(
        1 for row in recovery if _int(row, "READ_VALID", 0) != 1
    )
    reset_changes = sum(
        1 for row in baseline + recovery if _int(row, "RESET_CHANGED", 0) == 1
    )
    master_ready_max = max(
        (_int(row, "MASTER_READY_STREAK", 0) or 0 for row in recovery),
        default=0,
    )
    recovery_max = max(
        (_int(row, "MAX_RECOVERY_STREAK", 0) or 0 for row in recovery),
        default=0,
    )
    eligible_max = max(
        (_int(row, "SLAVE_RECOVERY_STREAK", 0) or 0 for row in recovery),
        default=0,
    )
    sticky_drop_observed = any(
        _int(row, "STICKY_DROP_OBSERVED", 0) == 1 for row in recovery
    )
    eligible_seen = any(
        _int(row, "SLAVE_RECOVERY_ELIGIBLE", 0) == 1 for row in recovery
    )
    baseline_health_pass = base["baseline_result"] == "PASS"
    master_local_ready = master_ready_max >= 3
    build_manifest_present = bool(build_manifest_text.strip())
    sequence = _parse_scalars(sequence_text)
    observer_start_ms = _int(sequence, "PROGRAM_DONE_TO_OBSERVER_START_MS", -1) or -1
    first_valid_ms = _int(sequence, "PROGRAM_DONE_TO_FIRST_VALID_SAMPLE_MS", -1) or -1

    result = rec["recovery_result"] or "MISSING"
    if not baseline_health_pass:
        classification = "INCONCLUSIVE_PREPROGRAM_SLAVE_HEALTH"
        verdict = "INCONCLUSIVE"
    elif observer_start_ms > 1000 or first_valid_ms > 5000:
        classification = "INCONCLUSIVE_OBSERVER_START_LATE"
        verdict = "INCONCLUSIVE"
    elif not baseline or not recovery:
        classification = "INCONCLUSIVE_CAPTURE_MISSING"
        verdict = "INCONCLUSIVE"
    elif baseline_transport_errors or recovery_transport_errors:
        classification = "INCONCLUSIVE_TRANSPORT"
        verdict = "INCONCLUSIVE"
    elif reset_changes:
        classification = "INCONCLUSIVE_RESET"
        verdict = "INCONCLUSIVE"
    elif not master_local_ready and result == "INCONCLUSIVE_MASTER_LOCAL_READY":
        classification = "INCONCLUSIVE_MASTER_LOCAL_READY"
        verdict = "INCONCLUSIVE"
    elif result == "PASS_REBUILT_MASTER_LAST_RECOVERY" and eligible_max >= 5:
        classification = "PASS_REBUILT_MASTER_LAST_RECOVERY"
        verdict = "PASS"
    elif result == "FAIL_TRANSIENT_RECOVERY" and eligible_seen:
        classification = "FAIL_TRANSIENT_RECOVERY"
        verdict = "FAIL_TRANSIENT"
    elif result == "FAIL_REBUILT_MASTER_LAST_RECOVERY_NOT_REPRODUCED":
        classification = "FAIL_REBUILT_MASTER_LAST_RECOVERY_NOT_REPRODUCED"
        verdict = "FAIL_NOT_REPRODUCED"
    else:
        classification = "INCONCLUSIVE_RECOVERY_CAPTURE"
        verdict = "INCONCLUSIVE"

    return {
        "format": "step6-master-last-ec1f25e8-rebuild-recovery-v1",
        "source": source,
        "baseline_result": base["baseline_result"],
        "recovery_result": result,
        "classification": classification,
        "recovery_verdict": verdict,
        "baseline_samples": len(baseline),
        "baseline_sample_count_declared": baseline_sample_count,
        "recovery_samples": len(recovery),
        "baseline_link_up_count": link_up_count,
        "baseline_link_mode": link_mode,
        "baseline_transport_errors": baseline_transport_errors,
        "recovery_transport_errors": recovery_transport_errors,
        "reset_changes": reset_changes,
        "master_local_ready": master_local_ready,
        "master_ready_max_streak": master_ready_max,
        "recovery_max_streak": max(recovery_max, eligible_max),
        "sticky_drop_observed": sticky_drop_observed,
        "eligible_recovery_seen": eligible_seen,
        "build_manifest_present": build_manifest_present,
        "program_done_to_observer_start_ms": observer_start_ms,
        "program_done_to_first_valid_ms": first_valid_ms,
        "startup_order_sensitivity": (
            "SUPPORTED" if verdict == "PASS" else "NOT_DETERMINED"
        ),
        "step6a": "NOT_PASS",
        "step6b": "NOT_RUN",
        "baseline_rows": baseline,
        "recovery_rows": recovery,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", type=Path)
    parser.add_argument("recovery", type=Path)
    parser.add_argument("--build-manifest", type=Path)
    parser.add_argument("--sequence", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_text(
        args.baseline.read_text(encoding="utf-8", errors="replace"),
        args.recovery.read_text(encoding="utf-8", errors="replace"),
        source=f"{args.baseline};{args.recovery}",
        build_manifest_text=(
            args.build_manifest.read_text(encoding="utf-8", errors="replace")
            if args.build_manifest and args.build_manifest.exists()
            else ""
        ),
        sequence_text=(
            args.sequence.read_text(encoding="utf-8", errors="replace")
            if args.sequence and args.sequence.exists()
            else ""
        ),
    )
    encoded = json.dumps(result, indent=2, ensure_ascii=False)
    if args.json_out:
        args.json_out.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
