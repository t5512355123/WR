"""Audit the existing Step6 digital evidence without touching hardware.

The closure audit deliberately consumes only committed experiment artifacts.
It never invokes Quartus, JTAG, programming, reset, PTP, or any functional
write.  A PASS therefore means that the existing raw records and summaries
are mutually consistent with the adviser-approved digital Step6 contract.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


STEP6_ROOT = Path("experiments/legacy/exp-step6-global-time")
E = {
    "same_pps": STEP6_ROOT / "EXP-S6-SAME-PPS-GLOBAL-TIME-CONSISTENCY-20260922",
    "late_tail": STEP6_ROOT / "EXP-S6A-ACTIVE-EXTENSION-LATE-GLOBAL-TIME-TAIL-20260922",
    "timing": STEP6_ROOT / "EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922",
    "first_trigger": STEP6_ROOT / "EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-LIVE-SESSION-20260922",
    "rearm": STEP6_ROOT / "EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-REARM-REPEATABILITY-20260922",
}

KV_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")
NO_WRITE_KEYS = {
    "COMPILE",
    "MASTER_COMPILE",
    "SLAVE_COMPILE",
    "FIRMWARE_BUILD",
    "MASTER_PROGRAM",
    "SLAVE_PROGRAM",
    "POWER_CYCLE",
    "CPU_RESET",
    "WR_CORE_RESET",
    "PHY_RESET",
    "RESET",
    "MASTER_PTP_RESTART",
    "SLAVE_PTP_RESTART",
    "PTP_RESTART",
    "TARGET_WRITE",
    "ARM_WRITE",
    "FIBER_QSFP_CHANGE",
    "AUTONEG_CHANGE",
    "SI5340_CHANGE",
    "SI5340_MDIO_WRITE",
    "MDIO_WRITE",
    "SMA_CLKOUT_CHANGE",
    "HARDWARE_ACCESS",
    "RTL_CHANGE",
    "SDC_CHANGE",
    "QSF_CHANGE",
    "MIF_CHANGE",
}


def _kv(line: str) -> dict[str, str]:
    return {key.upper(): value for key, value in KV_RE.findall(line)}


def _int(value: Any) -> int | None:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if value is None:
        return None
    text = str(value)
    for base in (0, 10, 16):
        try:
            return int(text, base)
        except ValueError:
            pass
    return None


def _text(value: Any) -> str:
    return "" if value is None else str(value)


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def _json(path: Path) -> dict[str, Any]:
    return json.loads(_read(path))


def _lines(text: str, prefix: str) -> list[str]:
    return [line.strip() for line in text.splitlines() if line.strip().startswith(prefix)]


def _last_line(text: str, prefix: str) -> str | None:
    rows = _lines(text, prefix)
    return rows[-1] if rows else None


def _rows(text: str, prefix: str) -> list[dict[str, str]]:
    return [_kv(line) for line in _lines(text, prefix)]


def _assert(
    checks: list[dict[str, Any]],
    condition: bool,
    name: str,
    detail: str,
    *,
    contradiction: bool = False,
) -> None:
    status = "PASS" if condition else ("CONTRADICTION" if contradiction else "GAP")
    checks.append({"name": name, "status": status, "detail": detail})


def _compare_reset(rows: list[dict[str, str]], checks: list[dict[str, Any]], name: str) -> None:
    keys = ("BOOT_GENERATION", "CPU_RESET_COUNT", "WR_CORE_RESET_COUNT", "SI_CONFIG_DROP_COUNT")
    values = {key: {row.get(key) for row in rows} for key in keys}
    stable = all(len(items) == 1 and None not in items for items in values.values())
    _assert(checks, stable, f"{name}.reset_signature_stable", str(values), contradiction=not stable)


def _audit_no_write_protocols(checks: list[dict[str, Any]]) -> None:
    for name, root in E.items():
        path = root / "raw" / "protocol.txt"
        if not path.exists():
            _assert(checks, False, f"{name}.protocol_present", str(path))
            continue
        values = _kv(_read(path).replace("\n", " "))
        bad = {
            key: values[key]
            for key in NO_WRITE_KEYS
            if key in values and values[key].upper() not in {"NO", "0", "FALSE"}
        }
        _assert(checks, not bad, f"{name}.no_hardware_mutation", str(bad), contradiction=bool(bad))


def _audit_same_pps(checks: list[dict[str, Any]], hashes: dict[str, str]) -> None:
    root = E["same_pps"]
    summary_path = root / "analysis" / "summary.json"
    raw_path = root / "raw" / "observe" / "same_pps_consistency.log"
    for path in (summary_path, raw_path, root / "REPORT.md", root / "raw" / "protocol.txt"):
        _assert(checks, path.exists(), f"same_pps.file.{path.name}", str(path))
    if not summary_path.exists() or not raw_path.exists():
        return
    hashes[str(summary_path)] = hashlib.sha256(summary_path.read_bytes()).hexdigest()
    hashes[str(raw_path)] = hashlib.sha256(raw_path.read_bytes()).hexdigest()
    summary = _json(summary_path)
    text = _read(raw_path)
    result_line = _last_line(text, "S6A2_CAPTURE_RESULT=")
    result = _kv(result_line or "")
    _assert(checks, summary.get("classification") == "PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY", "same_pps.summary.pass", str(summary.get("classification")), contradiction=True)
    _assert(checks, summary.get("common_tai_count") == 5 and summary.get("exact_match_count") == 5, "same_pps.summary.five_exact", str(summary), contradiction=True)
    _assert(checks, result.get("S6A2_CAPTURE_RESULT") == "PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY", "same_pps.raw.result", str(result), contradiction=True)
    _assert(checks, _int(result.get("COMMON_TAI_COUNT")) == 5 and _int(result.get("EXACT_MATCH_COUNT")) == 5, "same_pps.raw.five_exact", str(result), contradiction=True)
    _assert(checks, _int(result.get("MAX_ABS_DELTA_TICKS")) == 0 and _int(result.get("MISMATCH_LABELS")) == 0, "same_pps.raw.zero_delta", str(result), contradiction=True)
    rows = _rows(text, "S6A2_SAMPLE ROLE=")
    good_flags = all(
        row.get("READ_VALID") == "1"
        and row.get("SNAPSHOT_VALID") == "1"
        and row.get("SNAPSHOT_TIME_VALID") == "1"
        and row.get("SNAPSHOT_PPS_VALID") == "1"
        and row.get("SNAPSHOT_STABLE") == "1"
        and row.get("STATUS_TIME_VALID") == "1"
        and row.get("STATUS_PPS_VALID") == "1"
        for row in rows
    )
    _assert(checks, len(rows) >= 10 and good_flags, "same_pps.raw.valid_rows", f"rows={len(rows)} flags={good_flags}", contradiction=not good_flags)
    by_label: dict[str, dict[str, set[str]]] = {}
    for row in rows:
        label = row.get("SNAPSHOT_TAI")
        role = row.get("ROLE")
        cycles = row.get("SNAPSHOT_CYCLES")
        if label and role and cycles:
            by_label.setdefault(label, {}).setdefault(role, set()).add(cycles)
    common = {
        label: roles
        for label, roles in by_label.items()
        if "MASTER" in roles and "SLAVE" in roles
    }
    exact = all(len(roles["MASTER"]) == 1 and roles["MASTER"] == roles["SLAVE"] for roles in common.values())
    _assert(checks, len(common) >= 5 and exact, "same_pps.raw.common_labels", f"common={len(common)} exact={exact}", contradiction=not exact)
    _compare_reset(rows, checks, "same_pps")


def _audit_late_tail(checks: list[dict[str, Any]], hashes: dict[str, str]) -> None:
    root = E["late_tail"]
    summary_path = root / "analysis" / "summary.json"
    raw_path = root / "raw" / "observe" / "observe.log"
    for path in (summary_path, raw_path, root / "REPORT.md", root / "raw" / "protocol.txt", root / "raw" / "stop.txt"):
        _assert(checks, path.exists(), f"late_tail.file.{path.name}", str(path))
    if not summary_path.exists() or not raw_path.exists():
        return
    hashes[str(summary_path)] = hashlib.sha256(summary_path.read_bytes()).hexdigest()
    hashes[str(raw_path)] = hashlib.sha256(raw_path.read_bytes()).hexdigest()
    summary = _json(summary_path)
    text = _read(raw_path)
    result = _kv(_last_line(text, "S6A_TAIL_RESULT=") or "")
    _assert(checks, summary.get("classification") == "PASS_ACTIVE_EXTENSION_LATE_GLOBAL_TIME_RECOVERY" and summary.get("verdict") == "PASS", "late_tail.summary.pass", str(summary.get("classification")), contradiction=True)
    _assert(checks, result.get("S6A_TAIL_RESULT") == "PASS_ACTIVE_EXTENSION_LATE_GLOBAL_TIME_RECOVERY", "late_tail.raw.result", str(result), contradiction=True)
    expected = {"GATE_PAIRS": 3, "TAIL_SAMPLES": 61, "VALID_SAMPLES": 61, "MAX_VALID_STREAK": 61, "SNAPSHOT_DELTA": 45, "COMMON_TAI_COUNT": 45, "MAX_ABS_DELTA_TICKS": 0, "COHERENCE_VIOLATION": 0}
    for key, wanted in expected.items():
        _assert(checks, _int(result.get(key)) == wanted, f"late_tail.raw.{key.lower()}", f"got={result.get(key)} wanted={wanted}", contradiction=True)
    rows = _rows(text, "S6A_TAIL_SAMPLE ROLE=")
    slave_rows = [row for row in rows if row.get("ROLE") == "SLAVE"]
    all_valid = all(
        row.get("READ_VALID") == "1"
        and row.get("LINK_HEALTHY") == "1"
        and row.get("PREARM_HEALTHY") == "1"
        and row.get("TERMINAL_FALLBACK") == "0"
        and row.get("STATUS_TIME_VALID") == "1"
        and row.get("STATUS_PPS_VALID") == "1"
        and row.get("SNAPSHOT_VALID") == "1"
        and row.get("SNAPSHOT_TIME_VALID") == "1"
        and row.get("SNAPSHOT_PPS_VALID") == "1"
        for row in rows
    )
    slave_ready = all(
        row.get("SPLL_SEQ_STATE") == "8"
        and row.get("PSTAT_LOCKED") == "1"
        and row.get("MAIN_LOCKED") == "1"
        and row.get("PTP_STATE") == "9"
        and row.get("PD_STATE") == "3"
        and row.get("EXT_STATE") == "1"
        for row in slave_rows
    )
    _assert(checks, len(rows) >= 122 and len(slave_rows) >= 61 and all_valid and slave_ready, f"late_tail.raw.healthy_tail", f"rows={len(rows)} slave={len(slave_rows)} valid={all_valid} slave_ready={slave_ready}", contradiction=not (all_valid and slave_ready))
    by_label: dict[str, dict[str, set[str]]] = {}
    for row in rows:
        label = row.get("SNAPSHOT_TAI")
        role = row.get("ROLE")
        cycles = row.get("SNAPSHOT_CYCLES")
        if label and role and cycles:
            by_label.setdefault(label, {}).setdefault(role, set()).add(cycles)
    common = {label: roles for label, roles in by_label.items() if "MASTER" in roles and "SLAVE" in roles}
    exact = all(len(roles["MASTER"]) == 1 and roles["MASTER"] == roles["SLAVE"] for roles in common.values())
    _assert(checks, len(common) >= 45 and exact, "late_tail.raw.common_labels", f"common={len(common)} exact={exact}", contradiction=not exact)
    _compare_reset(rows, checks, "late_tail")


def _audit_timing(checks: list[dict[str, Any]], hashes: dict[str, str]) -> None:
    root = E["timing"]
    summary_path = root / "analysis" / "summary.json"
    _assert(checks, summary_path.exists(), "timing.summary.present", str(summary_path))
    if not summary_path.exists():
        return
    hashes[str(summary_path)] = hashlib.sha256(summary_path.read_bytes()).hexdigest()
    summary = _json(summary_path)
    groups = {
        "target_meta_to_sync", "target_sync_to_latched", "arm_meta_to_sync", "arm_sync_to_prev",
        "refclk_to_armed", "refclk_to_fired", "refclk_to_fire_count", "refclk_to_actual_tai", "refclk_to_actual_cycles",
    }
    path_ok = True
    details: list[str] = []
    for role in ("master", "slave"):
        role_data = summary.get("reports", {}).get(role, {})
        path_ok = path_ok and summary.get(f"{role}_result") == "PASS_STEP6B_POSTFIT_TIMING_PROVEN"
        paths = role_data.get("paths", {})
        for group in groups:
            for kind in ("setup", "hold"):
                item = paths.get(f"{group}::{kind}", {})
                slack = item.get("slack_ns")
                ok = item.get("status") == "PASS" and (_int(item.get("count")) or 0) > 0 and slack is not None and float(slack) >= 0
                path_ok = path_ok and ok
                if not ok:
                    details.append(f"{role}:{group}:{kind}:{item}")
    reports = list((root / "raw" / "timing").glob("*.rpt"))
    _assert(checks, path_ok, "timing.summary.all_36_paths", "; ".join(details) or "36 setup/hold groups have non-negative slack", contradiction=not path_ok)
    _assert(checks, len(reports) >= 36, "timing.raw.path_reports", f"reports={len(reports)}")
    for path in (root / "REPORT.md", root / "raw" / "protocol.txt", root / "raw" / "provenance.txt", root / "raw" / "stop.txt"):
        _assert(checks, path.exists(), f"timing.file.{path.name}", str(path))
    for path in (root / "raw" / "timing" / "master_step6b_timing.txt", root / "raw" / "timing" / "slave_step6b_timing.txt"):
        _assert(checks, path.exists() and "PASS_STEP6B_POSTFIT_TIMING_PROVEN" in _read(path), f"timing.raw.{path.name}", str(path), contradiction=True)


def _audit_first_trigger(checks: list[dict[str, Any]], hashes: dict[str, str]) -> None:
    root = E["first_trigger"]
    summary_path = root / "analysis" / "summary.json"
    raw_path = root / "raw" / "observe" / "observe.log"
    for path in (summary_path, raw_path, root / "REPORT.md", root / "raw" / "protocol.txt", root / "raw" / "stop.txt"):
        _assert(checks, path.exists(), f"first_trigger.file.{path.name}", str(path))
    if not summary_path.exists() or not raw_path.exists():
        return
    hashes[str(summary_path)] = hashlib.sha256(summary_path.read_bytes()).hexdigest()
    hashes[str(raw_path)] = hashlib.sha256(raw_path.read_bytes()).hexdigest()
    summary = _json(summary_path)
    text = _read(raw_path)
    result = _kv(_last_line(text, "S6B_LIVE_RESULT=") or "")
    expected = {
        "S6B_LIVE_RESULT": "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER",
        "TARGET_TAI": "3433",
        "TARGET_CYCLES": "62500000",
        "COMMON_TAI_COUNT": "3",
        "COHERENCE_VIOLATION": "0",
        "CAPTURE_SAMPLES": "27",
        "POST_FIRE_SAMPLES": "3",
        "MASTER_FIRED": "1",
        "SLAVE_FIRED": "1",
        "MASTER_FIRE_COUNT": "1",
        "SLAVE_FIRE_COUNT": "1",
        "MASTER_ACTUAL_TAI": "3433",
        "SLAVE_ACTUAL_TAI": "3433",
        "MASTER_ACTUAL_CYCLES": "62500000",
        "SLAVE_ACTUAL_CYCLES": "62500000",
        "DIGITAL_TRIGGER_DELTA_TICKS": "0",
        "DIGITAL_TRIGGER_DELTA_NS": "0",
    }
    for key, wanted in expected.items():
        _assert(checks, result.get(key) == wanted, f"first_trigger.raw.{key.lower()}", f"got={result.get(key)} wanted={wanted}", contradiction=True)
    _assert(checks, summary.get("verdict") == "PASS" and summary.get("step6b_1") == "PASS", "first_trigger.summary.pass", str(summary), contradiction=True)
    writes = _rows(text, "S6B_SOURCE_WRITE BOARD=")
    sequence = [(row.get("BOARD"), row.get("INDEX"), row.get("VALUE"), row.get("OK")) for row in writes]
    expected_sequence = [("MASTER", "67", "0000000D69", "1"), ("SLAVE", "67", "0000000D69", "1"), ("MASTER", "68", "1", "1"), ("SLAVE", "68", "1", "1")]
    _assert(checks, sequence == expected_sequence, "first_trigger.raw.write_sequence", str(sequence), contradiction=sequence != expected_sequence)
    capture_rows = _rows(text, "S6B_LIVE_CAPTURE_SAMPLE ROLE=")
    fired_rows = [row for row in capture_rows if row.get("STEP6B_FIRED") == "1" and row.get("STEP6B_FIRE_COUNT") == "1"]
    _assert(checks, len(capture_rows) >= 54 and len(fired_rows) >= 6, "first_trigger.raw.post_fire_rows", f"capture={len(capture_rows)} fired={len(fired_rows)}")
    _compare_reset(capture_rows, checks, "first_trigger")


def _audit_rearm(checks: list[dict[str, Any]], hashes: dict[str, str]) -> None:
    root = E["rearm"]
    summary_path = root / "analysis" / "summary.json"
    raw_path = root / "raw" / "observe" / "observe.log"
    for path in (summary_path, raw_path, root / "REPORT.md", root / "raw" / "protocol.txt", root / "raw" / "stop.txt"):
        _assert(checks, path.exists(), f"rearm.file.{path.name}", str(path))
    if not summary_path.exists() or not raw_path.exists():
        return
    hashes[str(summary_path)] = hashlib.sha256(summary_path.read_bytes()).hexdigest()
    hashes[str(raw_path)] = hashlib.sha256(raw_path.read_bytes()).hexdigest()
    summary = _json(summary_path)
    text = _read(raw_path)
    result = _kv(_last_line(text, "S6B_REARM_RESULT=") or "")
    expected = {
        "S6B_REARM_RESULT": "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER_REARM_REPEATABILITY",
        "PRE_GATE_PAIRS": "3",
        "PRE_COMMON_TAI_COUNT": "2",
        "POST_DEARM_GATE_PAIRS": "3",
        "POST_DEARM_COMMON_TAI_COUNT": "2",
        "COHERENCE_VIOLATION": "0",
        "T0": "6771",
        "NEW_TARGET_TAI": "6791",
        "TARGET_CYCLES": "62500000",
        "PRE_GATE_RESULT": "PASS",
        "INITIAL_RESULT": "PASS",
        "DEARM_RESULT": "PASS",
        "POST_DEARM_GATE_RESULT": "PASS",
        "TARGET_RESULT": "PASS",
        "ARM_RESULT": "PASS",
        "CAPTURE_SAMPLES": "27",
        "POST_FIRE_SAMPLES": "3",
        "ARM0_WRITE_MASTER": "1",
        "ARM0_WRITE_SLAVE": "1",
        "TARGET_WRITE_MASTER": "1",
        "TARGET_WRITE_SLAVE": "1",
        "ARM1_WRITE_MASTER": "1",
        "ARM1_WRITE_SLAVE": "1",
        "MASTER_FIRE_COUNT": "2",
        "SLAVE_FIRE_COUNT": "2",
        "MASTER_ACTUAL_TAI": "6791",
        "SLAVE_ACTUAL_TAI": "6791",
        "MASTER_ACTUAL_CYCLES": "62500000",
        "SLAVE_ACTUAL_CYCLES": "62500000",
        "SECOND_TRIGGER_DELTA_TICKS": "0",
        "SECOND_TRIGGER_DELTA_NS": "0",
    }
    for key, wanted in expected.items():
        _assert(checks, result.get(key) == wanted, f"rearm.raw.{key.lower()}", f"got={result.get(key)} wanted={wanted}", contradiction=True)
    _assert(checks, summary.get("verdict") == "PASS" and summary.get("source_sequence_ok") is True, "rearm.summary.pass", str(summary), contradiction=True)
    writes = _rows(text, "S6B_SOURCE_WRITE BOARD=")
    sequence = [(row.get("BOARD"), row.get("INDEX"), row.get("VALUE"), row.get("OK")) for row in writes]
    expected_sequence = [
        ("MASTER", "68", "0", "1"),
        ("SLAVE", "68", "0", "1"),
        ("MASTER", "67", "0000001A87", "1"),
        ("SLAVE", "67", "0000001A87", "1"),
        ("MASTER", "68", "1", "1"),
        ("SLAVE", "68", "1", "1"),
    ]
    # The observer may print target values as decimal or zero-padded hex;
    # compare the target numerically while preserving the six-write order.
    normalized = [(board, index, _int(value), ok) for board, index, value, ok in sequence]
    expected_normalized = [("MASTER", "68", 0, "1"), ("SLAVE", "68", 0, "1"), ("MASTER", "67", 6791, "1"), ("SLAVE", "67", 6791, "1"), ("MASTER", "68", 1, "1"), ("SLAVE", "68", 1, "1")]
    _assert(checks, len(writes) == 6 and normalized == expected_normalized, "rearm.raw.write_sequence", str(sequence), contradiction=len(writes) != 6 or normalized != expected_normalized)
    capture_rows = _rows(text, "S6B_REARM_CAPTURE_SAMPLE ROLE=")
    fired_rows = [row for row in capture_rows if row.get("STEP6B_FIRED") == "1" and row.get("STEP6B_FIRE_COUNT") == "2"]
    _assert(checks, len(capture_rows) >= 54 and len(fired_rows) >= 6, "rearm.raw.post_fire_rows", f"capture={len(capture_rows)} fired={len(fired_rows)}")
    _compare_reset(capture_rows, checks, "rearm")


def audit(repo_root: Path) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []
    hashes: dict[str, str] = {}
    _audit_no_write_protocols(checks)
    _audit_same_pps(checks, hashes)
    _audit_late_tail(checks, hashes)
    _audit_timing(checks, hashes)
    _audit_first_trigger(checks, hashes)
    _audit_rearm(checks, hashes)
    gaps = [item for item in checks if item["status"] == "GAP"]
    contradictions = [item for item in checks if item["status"] == "CONTRADICTION"]
    if contradictions:
        result = "FAIL_STEP6_DIGITAL_MILESTONE_EVIDENCE_CONTRADICTION"
        verdict = "FAIL"
    elif gaps:
        result = "INCONCLUSIVE_STEP6_DIGITAL_MILESTONE_EVIDENCE_INCOMPLETE"
        verdict = "INCONCLUSIVE"
    else:
        result = "PASS_STEP6_DIGITAL_MILESTONE_CLOSURE"
        verdict = "PASS"
    return {
        "format": "step6-digital-milestone-closure-v1",
        "result": result,
        "verdict": verdict,
        "step6a_1_global_time_validity": "PASS" if verdict == "PASS" else "NOT_PASS",
        "step6a_2_same_pps_consistency": "PASS" if verdict == "PASS" else "NOT_PASS",
        "step6a_requalification": "PASS" if verdict == "PASS" else "NOT_PASS",
        "step6b_postfit_timing": "PASS" if verdict == "PASS" else "NOT_PASS",
        "step6b_first_trigger": "PASS" if verdict == "PASS" else "NOT_PASS",
        "step6b_rearm_repeatability": "PASS" if verdict == "PASS" else "NOT_PASS",
        "step6_physical_pps_baseline": "NOT_EVALUATED",
        "step6b_physical_scheduled_trigger_edge": "NOT_EVALUATED",
        "digital_timestamp_delta_ticks": 0 if verdict == "PASS" else None,
        "digital_timestamp_label_delta_ns": 0 if verdict == "PASS" else None,
        "checks": checks,
        "gap_count": len(gaps),
        "contradiction_count": len(contradictions),
        "evidence_sha256": hashes,
        "hardware_contract": {
            "hardware_access": "NO",
            "compile": "NO",
            "program": "NO",
            "reset": "NO",
            "ptp_restart": "NO",
            "power_cycle": "NO",
            "target_write": "NO",
            "arm_write": "NO",
            "physical_claim": "NOT_EVALUATED",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--text-out", type=Path)
    args = parser.parse_args()
    result = audit(args.repo_root)
    output = json.dumps(result, indent=2, sort_keys=True)
    print(output)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(output + "\n", encoding="utf-8")
    if args.text_out:
        args.text_out.parent.mkdir(parents=True, exist_ok=True)
        lines = [f"{item['status']} {item['name']}: {item['detail']}" for item in result["checks"]]
        args.text_out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
