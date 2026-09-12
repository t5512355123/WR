#!/usr/bin/env python3
"""Generate and compare provenance manifests for Step5 experiments."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional


ROOT = Path(__file__).resolve().parents[2]
SOURCE_FILES = [
    "vendor/wrpc-sw/softpll/spll_helper.c",
    "vendor/wrpc-sw/softpll/spll_main.c",
    "vendor/wrpc-sw/softpll/spll_common.c",
    "vendor/wrpc-sw/softpll/softpll_ng.c",
    "vendor/wrpc-sw/lib/task-diags.c",
    "vendor/wrpc-sw/dev/wdiags.c",
    "quartus/jtag_runtime_diag/si5340a_controller_dco.v",
    "quartus/jtag_runtime_diag/i2c_bus_controller_dco.v",
    "quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd",
    "quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd",
    "scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl",
]


def run_git(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, check=check, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace",
    )
    return result.stdout.strip()


def sha256_file(path: Path) -> Optional[str]:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8", errors="replace")


def numeric_assignments(text: str, name: str, operators: Iterable[str] = ("=", "=>", ":=")) -> List[int]:
    operator_pattern = "(?:" + "|".join(re.escape(operator) for operator in operators) + ")"
    values = re.findall(rf"\b{re.escape(name)}\s*{operator_pattern}\s*(-?\d+)", text)
    return [int(value) for value in values]


def last_assignment(text: str, name: str, operators: Iterable[str] = ("=", "=>", ":=")) -> Optional[int]:
    values = numeric_assignments(text, name, operators)
    return values[-1] if values else None


def last_define(text: str, name: str) -> Optional[int]:
    values = re.findall(rf"#define\s+{re.escape(name)}\s+(-?\d+)", text)
    return int(values[-1]) if values else None


def config_node_block(text: str) -> str:
    marker_match = re.search(r"#(?:if|elif) defined\(CONFIG_WR_NODE\)", text)
    if marker_match is None:
        return ""
    remainder = text[marker_match.start():]
    end = remainder.find("#else", len("#elif defined(CONFIG_WR_NODE)"))
    return remainder if end < 0 else remainder[:end]


def config_settings(path: str) -> Dict[str, Any]:
    text = read_text(path)
    node = config_node_block(text)
    settings: Dict[str, Any] = {
        "path": path,
        "sha256": sha256_file(ROOT / path),
        "node_kp": last_assignment(node, "s->pi.kp"),
        "node_ki": last_assignment(node, "s->pi.ki"),
        "integral_decimation": last_define(text, "STEP5_HELPER_PI_INTEGRAL_DECIMATION"),
        "update_decimation": last_define(text, "STEP5_HELPER_PI_UPDATE_DECIMATION"),
        "helper_threshold": last_define(text, "STEP5_HELPER_LOCK_THRESHOLD"),
        "helper_lock_samples": last_define(text, "STEP5_HELPER_LOCK_SAMPLES"),
    }
    # spll_main.c uses assignments to lock-detector fields rather than macros.
    if path.endswith("spll_main.c"):
        frequency_floor = last_define(text, "MPLL_FREQ_DELOCK_FLOOR")
        settings.update({
            "main_kp": last_assignment(node, "s->pi.kp"),
            "main_ki": last_assignment(node, "s->pi.ki"),
            "main_frequency_threshold": last_assignment(text, "s->freq_ld.threshold"),
            "main_frequency_lock_samples": last_assignment(text, "s->freq_ld.lock_samples"),
            "main_frequency_delock_floor": frequency_floor,
            "main_phase_threshold": last_assignment(text, "s->phase_ld.threshold"),
            "main_phase_lock_samples": last_assignment(text, "s->phase_ld.lock_samples"),
            "main_phase_delock_floor": last_assignment(text, "s->phase_ld.delock_samples"),
        })
    return settings


def top_level_settings(path: str, role: str) -> Dict[str, Any]:
    text = read_text(path)
    names = [
        "ENABLE_STEP5_ACTUATOR_IDENTIFICATION",
        "ENABLE_STEP5_HPLL_PLANT_TEST",
        "ENABLE_NORMAL_HPLL_TRACKER",
        "ENABLE_STEP5_BOOTSTRAP",
        "STEP5_BOOTSTRAP_STEPS",
        "STEP5_BOOTSTRAP_REVERSE",
        "HPLL_TRACKER_CODE_PER_PHYSICAL_STEP",
        "DPLL_TRACKER_CODE_PER_PHYSICAL_STEP",
        "JTAG_HPLL_BURST_SIZE",
        "STEP5_NORMAL_HPLL_COOLDOWN_LOADS",
    ]
    return {
        "path": path,
        "role": role,
        "sha256": sha256_file(ROOT / path),
        "values": {name: last_assignment(text, name) for name in names},
    }


def dirty_state() -> Dict[str, Any]:
    diff = subprocess.run(
        ["git", "diff", "--binary", "HEAD"], cwd=ROOT,
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    ).stdout
    status = run_git("status", "--porcelain=v1", "-uno", check=False)
    tracked = []
    for line in status.splitlines():
        if len(line) >= 4:
            tracked.append(line[3:])
    return {"dirty_diff_sha256": sha256_bytes(diff), "dirty_tracked_files": tracked}


def source_hashes() -> Dict[str, Optional[str]]:
    return {path: sha256_file(ROOT / path) for path in SOURCE_FILES}


def build_artifact_manifest() -> Dict[str, Any]:
    artifacts = {
        "master_sof": "quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof",
        "slave_sof": "quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof",
    }
    return {
        name: {"path": path, "sha256_if_present": sha256_file(ROOT / path)}
        for name, path in artifacts.items()
    }


def make_manifest(source_commit: Optional[str]) -> Dict[str, Any]:
    workspace_head = run_git("rev-parse", "HEAD")
    resolved_source = run_git("rev-parse", source_commit or workspace_head)
    helper = config_settings("vendor/wrpc-sw/softpll/spll_helper.c")
    main = config_settings("vendor/wrpc-sw/softpll/spll_main.c")
    return {
        "format": "step5-manifest-v2",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "analysis_scope": "L0_OFFLINE_EVIDENCE_ONLY",
        "workspace_head": workspace_head,
        "source_commit": resolved_source,
        "branch": run_git("branch", "--show-current"),
        **dirty_state(),
        "submodule_status": run_git("submodule", "status", check=False).splitlines(),
        "build_target": "jtag-runtime",
        "roles": {
            "master": {"cable": "DE5 [1-11.1]", "lane": "QSFPA lane 2", "source_role": "reference"},
            "slave": {"cable": "DE5 [1-11.2]", "lane": "QSFPA lane 2", "source_role": "under_test"},
        },
        "source_files": source_hashes(),
        "firmware_policy": {
            "helper": helper,
            "main": main,
            "slave_top_level": top_level_settings(
                "quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd", "slave"
            ),
            "master_top_level": top_level_settings(
                "quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd", "master"
            ),
        },
        "observer": {
            "path": "scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl",
            "sha256": sha256_file(ROOT / "scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl"),
        },
        "artifacts": {"status": "not_built_in_L0", **build_artifact_manifest()},
        "quartus": {"version": None, "fitted_database_identity": None},
        "timing": {"timing_closed": None, "master_wns_ns": None, "slave_wns_ns": None},
        "verdict_policy": {
            "helper_threshold": helper.get("helper_threshold"),
            "helper_lock_samples": helper.get("helper_lock_samples"),
            "band_200_is_quality_statistic_only": True,
            "strict_step5_pass": False,
        },
    }


def compare_manifest(current: Dict[str, Any], expected_path: Path) -> Dict[str, Any]:
    expected = json.loads(expected_path.read_text(encoding="utf-8"))
    checks = {
        "source_commit": (current.get("source_commit"), expected.get("source_commit")),
        "branch": (current.get("branch"), expected.get("branch")),
        "observer_sha256": (
            current.get("observer", {}).get("sha256"),
            expected.get("observer", {}).get("sha256"),
        ),
        "source_files": (current.get("source_files"), expected.get("source_files")),
        "firmware_policy": (current.get("firmware_policy"), expected.get("firmware_policy")),
    }
    mismatches = [name for name, (actual, wanted) in checks.items() if actual != wanted]
    return {"provenance_ok": not mismatches, "mismatches": mismatches}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source-commit")
    parser.add_argument("--compare", type=Path)
    args = parser.parse_args()

    manifest = make_manifest(args.source_commit)
    comparison = compare_manifest(manifest, args.compare) if args.compare else None
    if comparison is not None:
        manifest["comparison"] = comparison
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "comparison": comparison}, ensure_ascii=False))
    return 0 if comparison is None or comparison["provenance_ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
