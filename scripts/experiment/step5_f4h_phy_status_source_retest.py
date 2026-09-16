#!/usr/bin/env python3
"""Replay the F4H retest with an explicit PHY-status source contract.

F4H is intentionally separate from the F4G replay.  It accepts the existing
compact Helper/Main/service records only after proving that the PHY predicate
was decoded from direct JTAG probe 0, not from WDIAGS_CTRL.  Older captures
without the direct source are never backfilled or upgraded.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

from step5_f4g_compact_progress_window import (  # type: ignore
    _flag,
    _num,
    _text,
    analyze_text as analyze_f4g_text,
    parse_wr,
)


REQUIRED_BITS: Tuple[Tuple[str, int], ...] = (
    ("SI_CONFIG_DONE", 0),
    ("WR_READY", 1),
    ("CORE_TM_LINK_UP", 2),
    ("CORE_LINK_OK", 3),
    ("WR_RX_READY", 6),
    ("WR_TX_READY", 7),
)
REQUIRED_MASK = 0xCF
HEX64_RE = re.compile(r"^[0-9A-Fa-f]{1,16}$")
WR_SOURCE_FIELDS = {
    "WDIAGS_CTRL_RAW",
    "WDIAGS_CTRL_VALID",
    "WDIAGS_CTRL_DATA_VALID",
    "WDIAGS_CTRL_DATA_SNAPSHOT",
    "PHY_STATUS_PROBE0_RAW",
    "PHY_STATUS_VALID",
    "PHY_STATUS_SOURCE",
    "PHY_STATUS_SOURCE_ID",
    "PHY_STATUS_INSTANCE",
    "PHY_STATUS_WIDTH_BITS",
    "PHY_GATE_REQUIRED_MASK",
    "PHY_GATE_FAILURE_BITS",
    "PSTAT_LINK",
    "PSTAT_LOCKED",
}


def _raw64(value: Any) -> Optional[int]:
    if not isinstance(value, str):
        return None
    value = value.strip()
    if not HEX64_RE.fullmatch(value):
        return None
    try:
        return int(value, 16)
    except ValueError:
        return None


def _bit(raw: int, bit: int) -> int:
    return (raw >> bit) & 1


def _expected_gate(raw: int) -> Tuple[Dict[str, int], bool, str]:
    decoded = {name: _bit(raw, bit) for name, bit in REQUIRED_BITS}
    failures = [name for name, value in decoded.items() if value != 1]
    return decoded, not failures, "NONE" if not failures else ",".join(failures)


def _config_value(config: Optional[Dict[str, Any]], key: str) -> str:
    return "" if config is None else _text(config, key)


def _source_schema(config: Optional[Dict[str, Any]],
                   wr_rows: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    issues: List[str] = []
    role = _config_value(config, "RUN_ROLE").lower()
    if role != "f4h":
        # This includes F4G legacy raw.  It is a deliberate non-upgrade.
        return {
            "status": "PHY_SOURCE_NOT_CAPTURED",
            "pass": False,
            "issues": ["RUN_ROLE_NOT_F4H"],
            "valid_rows": 0,
            "gate_pass_rows": 0,
            "gate_fail_rows": 0,
            "unknown_rows": 0,
            "role_valid_rows": {},
            "source_fields_missing": sorted(WR_SOURCE_FIELDS),
        }

    expected_config = {
        "PHY_STATUS_SOURCE": "JTAG_PROBE0",
        "PHY_STATUS_INSTANCE": "0",
        "PHY_STATUS_WIDTH_BITS": "64",
        "PHY_REQUIRED_MASK": "000000CF",
        "WDIAGS_CTRL_ADDR": "0X00100A04",
        "PSTAT_ADDR": "0X00100A0C",
    }
    for key, expected in expected_config.items():
        actual = _config_value(config, key).upper()
        if actual != expected:
            issues.append(f"CONFIG_{key}_MISMATCH")

    valid_rows = 0
    gate_pass_rows = 0
    gate_fail_rows = 0
    unknown_rows = 0
    schema_rows = 0
    decoder_mismatches = 0
    role_valid_rows: Dict[str, int] = {}
    role_gate_pass_rows: Dict[str, int] = {}
    role_gate_fail_rows: Dict[str, int] = {}
    stats: Dict[str, Dict[str, int]] = {
        name: {"valid": 0, "asserted": 0, "failed": 0, "unknown": 0}
        for name, _ in REQUIRED_BITS
    }
    decoded_rows: List[Dict[str, Any]] = []

    for row in wr_rows:
        missing = sorted(WR_SOURCE_FIELDS.difference(row))
        if missing:
            issues.append("WR_SOURCE_FIELDS_MISSING")
            unknown_rows += 1
            decoded_rows.append({
                "role": _text(row, "ROLE"),
                "cycle": _text(row, "cycle"),
                "status": "UNKNOWN",
                "failure_bits": "UNKNOWN",
                "missing_fields": ",".join(missing),
            })
            continue
        schema_rows += 1
        row_role = _text(row, "ROLE").upper()
        expected_source_id = f"WR_SYNC_{row_role}"
        if _text(row, "PHY_STATUS_SOURCE").upper() != "JTAG_PROBE0":
            issues.append("PHY_SOURCE_ID_MISMATCH")
        if _text(row, "PHY_STATUS_SOURCE_ID").upper() != expected_source_id:
            issues.append("PHY_ROLE_SOURCE_ID_MISMATCH")
        if _text(row, "PHY_STATUS_INSTANCE") != "0":
            issues.append("PHY_INSTANCE_MISMATCH")
        if _text(row, "PHY_STATUS_WIDTH_BITS") != "64":
            issues.append("PHY_WIDTH_MISMATCH")
        if _text(row, "PHY_GATE_REQUIRED_MASK").upper() != "000000CF":
            issues.append("PHY_MASK_MISMATCH")
        if _flag(row, "WR_CORE_VALID") and _num(row.get("WDIAGS_CTRL_DATA_VALID")) != 1:
            issues.append("CORE_VALID_WITH_INVALID_CTRL")

        raw = _raw64(row.get("PHY_STATUS_PROBE0_RAW"))
        source_valid = _flag(row, "PHY_STATUS_VALID")
        if raw is None or not source_valid:
            unknown_rows += 1
            decoded_rows.append({
                "role": row_role,
                "cycle": _text(row, "cycle"),
                "status": "UNKNOWN",
                "raw": _text(row, "PHY_STATUS_PROBE0_RAW"),
                "failure_bits": "UNKNOWN",
            })
            continue

        valid_rows += 1
        role_valid_rows[row_role] = role_valid_rows.get(row_role, 0) + 1
        decoded, gate_pass, failure_bits = _expected_gate(raw)
        observed_gate = _flag(row, "PHY_LINK_USABLE")
        if observed_gate != gate_pass:
            decoder_mismatches += 1
            issues.append("PHY_DECODER_MISMATCH")
        for name, value in decoded.items():
            stats[name]["valid"] += 1
            if value:
                stats[name]["asserted"] += 1
            else:
                stats[name]["failed"] += 1
        if gate_pass:
            gate_pass_rows += 1
            role_gate_pass_rows[row_role] = role_gate_pass_rows.get(row_role, 0) + 1
        else:
            gate_fail_rows += 1
            role_gate_fail_rows[row_role] = role_gate_fail_rows.get(row_role, 0) + 1
        decoded_rows.append({
            "role": row_role,
            "cycle": _text(row, "cycle"),
            "raw": _text(row, "PHY_STATUS_PROBE0_RAW"),
            "status": "PASS" if gate_pass else "FAIL",
            "failure_bits": failure_bits,
            "observed_phy_link_usable": int(observed_gate),
            **decoded,
        })

    if not wr_rows:
        issues.append("NO_WR_ROWS")
    if schema_rows == 0 and wr_rows:
        issues.append("NO_F4H_SOURCE_ROWS")
    for required_role in ("MASTER", "SLAVE"):
        if role_valid_rows.get(required_role, 0) < 2:
            issues.append(f"{required_role}_SOURCE_SMOKE_INSUFFICIENT")

    unique_issues = sorted(set(issues))
    if any(item in unique_issues for item in (
        "WR_SOURCE_FIELDS_MISSING", "PHY_SOURCE_ID_MISMATCH",
        "PHY_ROLE_SOURCE_ID_MISMATCH", "PHY_INSTANCE_MISMATCH",
        "PHY_WIDTH_MISMATCH", "PHY_MASK_MISMATCH", "PHY_DECODER_MISMATCH",
        "CORE_VALID_WITH_INVALID_CTRL",
        "CONFIG_PHY_STATUS_SOURCE_MISMATCH", "CONFIG_PHY_STATUS_INSTANCE_MISMATCH",
        "CONFIG_PHY_STATUS_WIDTH_BITS_MISMATCH", "CONFIG_PHY_REQUIRED_MASK_MISMATCH",
        "CONFIG_WDIAGS_CTRL_ADDR_MISMATCH", "CONFIG_PSTAT_ADDR_MISMATCH",
    )):
        status = "PHY_SCHEMA_INVALID"
    elif unknown_rows and valid_rows == 0:
        status = "PHY_SOURCE_UNKNOWN"
    elif any("SMOKE_INSUFFICIENT" in item for item in unique_issues):
        status = "PHY_SOURCE_SCHEMA_INSUFFICIENT"
    else:
        status = "PASS"
    return {
        "status": status,
        "pass": status == "PASS",
        "issues": unique_issues,
        "valid_rows": valid_rows,
        "gate_pass_rows": gate_pass_rows,
        "gate_fail_rows": gate_fail_rows,
        "unknown_rows": unknown_rows,
        "schema_rows": schema_rows,
        "decoder_mismatches": decoder_mismatches,
        "role_valid_rows": role_valid_rows,
        "role_gate_pass_rows": role_gate_pass_rows,
        "role_gate_fail_rows": role_gate_fail_rows,
        "per_bit": stats,
        "decoded_rows": decoded_rows,
        "source_fields": sorted(WR_SOURCE_FIELDS),
    }


def _has_true_phy_gate(rows: Sequence[Dict[str, Any]]) -> bool:
    return any(_flag(row, "PHY_STATUS_VALID") and _flag(row, "PHY_LINK_USABLE")
               for row in rows)


def analyze_text(text: str, source: str = "") -> Dict[str, Any]:
    base = analyze_f4g_text(text, source)
    schema = _source_schema(base.get("config"), base.get("wr_records", []))
    result: Dict[str, Any] = dict(base)
    # Keep the raw F4G-derived correlation rows available to the writer, but
    # never let their historical CTRL decoder satisfy the F4H source gate.
    result["format"] = "step5-f4h-phy-status-source-retest-v1"
    result["base_f4g_classification"] = base.get("classification")
    result["source_schema"] = {key: value for key, value in schema.items()
                                if key != "decoded_rows"}
    result["phy_gate_rows"] = schema.get("decoded_rows", [])
    result["phy_source_fix_confirmed"] = bool(schema.get("pass"))
    result["legacy_raw_upgrade_allowed"] = False
    result["step5_complete"] = False
    result["step5_pass"] = False
    result["merge_approved"] = False

    if schema.get("status") != "PASS":
        result["classification"] = schema.get("status", "PHY_SOURCE_UNKNOWN")
        result["diagnostic_pass"] = False
    elif not _has_true_phy_gate(base.get("wr_records", [])):
        result["classification"] = "TRUE_PHY_GATE_NOT_MET"
        result["diagnostic_pass"] = True
    else:
        # Base F4G correlation is valid only after F4H source/schema proof.
        result["classification"] = base.get("classification", "INCONCLUSIVE")
        result["diagnostic_pass"] = result["classification"] in {
            "MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK",
            "MAIN_DEMAND_SERVICE_GAP_SUSPECTED",
            "HELPER_OR_SESSION_REGRESSION",
            "INCONCLUSIVE",
        }
    return result


def _write_csv(path: Path, rows: Iterable[Dict[str, Any]]) -> None:
    materialized = list(rows)
    fields: List[str] = []
    for row in materialized:
        for key in row:
            if key not in fields and not key.startswith("_"):
                fields.append(key)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(materialized)


def write_outputs(result: Dict[str, Any], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    _write_csv(output_dir / "bins.csv", result.get("bins", []))
    _write_csv(output_dir / "counter_support.csv", result.get("counter_support", []))
    _write_csv(output_dir / "phy_gate.csv", result.get("phy_gate_rows", []))
    _write_csv(output_dir / "wr_core.csv", result.get("wr_records", []))
    _write_csv(output_dir / "cycles.csv", result.get("cycle_records", []))
    summary = {key: value for key, value in result.items()
               if not key.endswith("_records") and key != "phy_gate_rows"}
    (output_dir / "verdict.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    text = args.log.read_text(encoding="utf-8", errors="replace")
    result = analyze_text(text, str(args.log))
    if args.output_dir:
        write_outputs(result, args.output_dir)
    print(json.dumps({
        "classification": result["classification"],
        "diagnostic_pass": result["diagnostic_pass"],
        "source_schema": result["source_schema"]["status"],
        "valid_phy_rows": result["source_schema"]["valid_rows"],
        "phy_gate_pass_rows": result["source_schema"]["gate_pass_rows"],
        "phy_gate_fail_rows": result["source_schema"]["gate_fail_rows"],
        "step5_pass": False,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
