"""Analyze the offline Step6B post-fit timing boundary correction."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FIELD_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
RESULT_RE = re.compile(r"^STEP6B_TIMING_RESULT=(?P<value>[^\s]+)")
GROUPS = {
    "target_meta_to_sync",
    "target_sync_to_latched",
    "arm_meta_to_sync",
    "arm_sync_to_prev",
    "refclk_to_armed",
    "refclk_to_fired",
    "refclk_to_fire_count",
    "refclk_to_actual_tai",
    "refclk_to_actual_cycles",
}


def _number(value: str) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _parse_file(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace")
    result_match = next(
        (match for line in text.splitlines() if (match := RESULT_RE.match(line.strip()))),
        None,
    )
    result = result_match.group("value") if result_match else "MISSING"
    paths: dict[tuple[str, str], dict[str, Any]] = {}
    errors: list[str] = []
    for line in text.splitlines():
        if not line.startswith("STEP6B_TIMING_PATH "):
            continue
        fields = {
            key: value for key, value in FIELD_RE.findall(line)
        }
        name = fields.get("name", "")
        kind = fields.get("type", "")
        paths[(name, kind)] = fields
        if name not in GROUPS:
            errors.append(f"unexpected_group:{name}")
    return {"path": str(path), "result": result, "paths": paths, "errors": errors}


def _group_pass(row: dict[str, Any] | None) -> bool:
    if row is None or row.get("status") != "PASS":
        return False
    try:
        count = int(row.get("count", "0"), 0)
    except ValueError:
        return False
    slack = _number(row.get("slack_ns", ""))
    query_from_clock = row.get("query_from_clock", "")
    query_to_clock = row.get("query_to_clock", "")
    if query_from_clock or query_to_clock:
        domain_ok = (
            "qsfp_ref_125m" in query_from_clock
            and "qsfp_ref_125m" in query_to_clock
        )
    else:
        # Backward-compatible parsing for synthetic/earlier reports whose
        # path objects themselves exposed the public clock name.
        domain_ok = (
            "qsfp_ref_125m" in row.get("from_clock", "")
            and "qsfp_ref_125m" in row.get("to_clock", "")
        )
    return (
        count > 0
        and slack is not None
        and slack >= 0
        and domain_ok
    )


def analyze_directory(directory: Path) -> dict[str, Any]:
    reports = {
        role: _parse_file(directory / f"{role}_step6b_timing.txt")
        for role in ("slave", "master")
        if (directory / f"{role}_step6b_timing.txt").exists()
    }
    missing_roles = sorted({"slave", "master"} - set(reports))
    group_status: dict[str, dict[str, bool]] = {}
    for group in sorted(GROUPS):
        group_status[group] = {}
        for role, report in reports.items():
            group_status[group][role] = _group_pass(report["paths"].get((group, "setup"))) and _group_pass(
                report["paths"].get((group, "hold"))
            )

    all_groups_pass = (
        not missing_roles
        and all(all(role_status.values()) for role_status in group_status.values())
    )
    if all_groups_pass and all(
        report["result"] == "PASS_STEP6B_POSTFIT_TIMING_PROVEN"
        for report in reports.values()
    ):
        classification = "PASS_STEP6B_POSTFIT_TIMING_PROVEN"
        verdict = "PASS"
    elif any("FAIL_STEP6B_POSTFIT_TIMING" == report["result"] for report in reports.values()):
        classification = "FAIL_STEP6B_POSTFIT_TIMING"
        verdict = "FAIL"
    else:
        classification = "NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED"
        verdict = "INCONCLUSIVE"
    serializable_reports = {}
    for role, report in reports.items():
        copied = dict(report)
        copied["paths"] = {
            f"{key[0]}::{key[1]}": value
            for key, value in report["paths"].items()
        }
        serializable_reports[role] = copied
    return {
        "format": "step6b-timing-query-boundary-correction-v1",
        "classification": classification,
        "verdict": verdict,
        "slave_result": reports.get("slave", {}).get("result", "MISSING"),
        "master_result": reports.get("master", {}).get("result", "MISSING"),
        "missing_roles": missing_roles,
        "group_status": group_status,
        "all_groups_pass": all_groups_pass,
        "reports": serializable_reports,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = analyze_directory(args.directory)
    output = json.dumps(result, indent=2, sort_keys=True)
    print(output)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(output + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
