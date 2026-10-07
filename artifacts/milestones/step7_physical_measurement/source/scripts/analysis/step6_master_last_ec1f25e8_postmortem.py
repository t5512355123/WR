"""Analyze the read-only postmortem after the ec1f25e8 Master rebuild.

Formal evidence requires a current sticky LINK_DROP or TM_LINK_DROP delta and
five consecutive valid stable-UP paired samples. PHY SYNC/LOCK deltas alone
are intentionally insufficient.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
BASELINE_RE = re.compile(r"^REBUILD_BASELINE_PAIR\s+(?P<body>.*)$")
POSTMORTEM_RE = re.compile(r"^POSTMORTEM_PAIR\s+(?P<body>.*)$")
BASELINE_RESULT_RE = re.compile(r"^BASELINE_RESULT=(?P<value>[^\s]+)")
POSTMORTEM_RESULT_RE = re.compile(r"^POSTMORTEM_RESULT=(?P<value>[^\s]+)")
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


def _rows(text: str, marker: re.Pattern[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = marker.match(line.strip())
        if match:
            rows.append(
                {key.upper(): _value(value) for key, value in FIELD_RE.findall(match.group("body"))}
            )
    return rows


def _scalars(text: str) -> dict[str, int | str]:
    values: dict[str, int | str] = {}
    for line in text.splitlines():
        match = SCALAR_RE.match(line.strip())
        if match:
            values[match.group("key").upper()] = _value(match.group("value"))
    return values


def _result(text: str) -> str | None:
    value: str | None = None
    for line in text.splitlines():
        match = POSTMORTEM_RESULT_RE.match(line.strip())
        if match:
            value = match.group("value")
    return value


def _max_streak(rows: list[dict[str, Any]], key: str = "STABLE_GOOD") -> int:
    current = best = 0
    for row in rows:
        if _int(row, key, 0) == 1:
            current += 1
            best = max(best, current)
        else:
            current = 0
    return best


def analyze_text(
    baseline_text: str,
    postmortem_text: str,
    *,
    source: str = "",
) -> dict[str, Any]:
    baseline = _rows(baseline_text, BASELINE_RE)
    current = _rows(postmortem_text, POSTMORTEM_RE)
    baseline_scalars = _scalars(baseline_text)
    postmortem_result = _result(postmortem_text) or "MISSING"
    baseline_result = next(
        (line.split("=", 1)[1].split()[0] for line in baseline_text.splitlines()
         if BASELINE_RESULT_RE.match(line.strip())),
        None,
    )
    baseline_link_mode = baseline_scalars.get("BASELINE_SLAVE_LINK_MODE", "UNKNOWN")
    if not isinstance(baseline_link_mode, str):
        baseline_link_mode = str(baseline_link_mode)

    transport_errors = sum(1 for row in current if _int(row, "READ_VALID", 0) != 1)
    reset_changes = sum(1 for row in current if _int(row, "RESET_CHANGED", 0) == 1)
    link_drop_evidence = any(
        (_int(row, "LINK_DROP_DELTA", -1) or -1) > 0 for row in current
    ) or any(_int(row, "LINK_DROP_SEEN", 0) == 1 for row in current)
    tm_link_drop_evidence = any(
        (_int(row, "TM_LINK_DROP_DELTA", -1) or -1) > 0 for row in current
    ) or any(_int(row, "TM_LINK_DROP_SEEN", 0) == 1 for row in current)
    sync_loss_evidence = any(
        (_int(row, "SYNC_LOSS_DELTA", -1) or -1) > 0 for row in current
    )
    lock_loss_evidence = any(
        (_int(row, "LOCK_LOSS_DELTA", -1) or -1) > 0 for row in current
    )
    stable_max = max(
        max((_int(row, "MAX_STABLE_STREAK", 0) or 0 for row in current), default=0),
        _max_streak(current),
    )
    valid_current = bool(current) and transport_errors == 0
    formal_link_evidence = link_drop_evidence or tm_link_drop_evidence
    stable_reacquisition = stable_max >= 5

    if baseline_result != "PASS" or baseline_link_mode != "UP":
        classification = "INCONCLUSIVE_PREPROGRAM_SLAVE_HEALTH"
        verdict = "INCONCLUSIVE"
    elif not current or postmortem_result == "MISSING":
        classification = "INCONCLUSIVE_CAPTURE_MISSING"
        verdict = "INCONCLUSIVE"
    elif not valid_current:
        classification = "INCONCLUSIVE_TRANSPORT"
        verdict = "INCONCLUSIVE"
    elif reset_changes:
        classification = "INCONCLUSIVE_RESET"
        verdict = "INCONCLUSIVE"
    elif formal_link_evidence and stable_reacquisition:
        classification = "PASS_POSTMORTEM_DROP_AND_REACQUISITION"
        verdict = "PASS"
    elif formal_link_evidence:
        classification = "FAIL_STABLE_REACQUISITION_NOT_PRESENT_POSTMORTEM"
        verdict = "FAIL"
    elif sync_loss_evidence or lock_loss_evidence:
        classification = "INCONCLUSIVE_ONLY_PHY_LOSS_EVIDENCE"
        verdict = "INCONCLUSIVE"
    else:
        classification = "INCONCLUSIVE_POSTMORTEM_NO_LINK_DROP_EVIDENCE"
        verdict = "INCONCLUSIVE"

    return {
        "format": "step6-master-last-ec1f25e8-postmortem-v1",
        "source": source,
        "baseline_result": baseline_result,
        "baseline_link_mode": baseline_link_mode,
        "preprogram_slave_link": "UP" if baseline_result == "PASS" and baseline_link_mode == "UP" else "UNKNOWN",
        "postmortem_result": postmortem_result,
        "classification": classification,
        "postmortem_verdict": verdict,
        "baseline_samples": len(baseline),
        "current_samples": len(current),
        "current_transport_errors": transport_errors,
        "reset_changes": reset_changes,
        "link_drop_evidence": link_drop_evidence,
        "tm_link_drop_evidence": tm_link_drop_evidence,
        "sync_loss_evidence": sync_loss_evidence,
        "lock_loss_evidence": lock_loss_evidence,
        "max_stable_reacquisition_streak": stable_max,
        "stable_reacquisition": "PASS" if stable_reacquisition else "NOT_PROVEN",
        "postprogram_link_interruption": "OBSERVED_BY_STICKY_COUNTER" if formal_link_evidence else "NOT_PROVEN",
        "ec1f25e8_source_rebuild_master_last_recovery": "SUPPORTED_POSTMORTEM" if verdict == "PASS" else "NOT_SUPPORTED",
        "startup_order_sensitivity": "SUPPORTED" if verdict == "PASS" else "NOT_DETERMINED",
        "recovery_latency": "UNAVAILABLE_DUE_TO_ORIGINAL_OBSERVER_FAILURE",
        "s_lock": "NOT_EVALUATED",
        "step6a": "NOT_PASS",
        "step6b": "NOT_RUN",
        "baseline_rows": baseline,
        "current_rows": current,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", type=Path)
    parser.add_argument("postmortem", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_text(
        args.baseline.read_text(encoding="utf-8", errors="replace"),
        args.postmortem.read_text(encoding="utf-8", errors="replace"),
        source=f"{args.baseline};{args.postmortem}",
    )
    encoded = json.dumps(result, indent=2, ensure_ascii=False)
    if args.json_out:
        args.json_out.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
