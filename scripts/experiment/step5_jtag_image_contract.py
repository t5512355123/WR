#!/usr/bin/env python3
"""Audit the bitstream/source-probe contract required by Step5 observers.

This is an offline source audit. It does not inspect hardware and never infers
Step5 lock from the presence of a debug image.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_FILES = (
    (
        "quartus/jtag_runtime_diag/DE5a_wr_master_jtag.qsf",
        "VHDL_FILE wr_jtag_wb_mailbox.vhd",
        "Master JTAG QSF includes the mailbox source",
    ),
    (
        "quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.qsf",
        "VHDL_FILE wr_jtag_wb_mailbox.vhd",
        "Slave JTAG QSF includes the mailbox source",
    ),
    (
        "quartus/jtag_runtime_diag/wr_jtag_wb_mailbox.vhd",
        "sld_instance_index      => 1",
        "Mailbox is pinned to source/probe instance 1",
    ),
    (
        "quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd",
        "u_jtag_wb_mailbox",
        "Master top instantiates the mailbox",
    ),
    (
        "quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd",
        "u_jtag_wb_mailbox",
        "Slave top instantiates the mailbox",
    ),
    (
        "scripts/build/build_jtag_master.sh",
        'PROJECT_DIR="$ROOT/quartus/jtag_runtime_diag"',
        "Master build selects the JTAG runtime project",
    ),
    (
        "scripts/build/build_jtag_slave.sh",
        'PROJECT_DIR="$ROOT/quartus/jtag_runtime_diag"',
        "Slave build selects the JTAG runtime project",
    ),
    (
        "scripts/program/program_jtag_master.sh",
        "jtag_runtime_diag/output_files_master_jtag",
        "Master programmer selects the JTAG runtime SOF",
    ),
    (
        "scripts/program/program_jtag_slave.sh",
        "jtag_runtime_diag/output_files_slave_jtag",
        "Slave programmer selects the JTAG runtime SOF",
    ),
)


def analyze(root: Path) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []
    for relative, needle, description in REQUIRED_FILES:
        path = root / relative
        present = path.is_file() and needle in path.read_text(
            encoding="utf-8", errors="replace"
        )
        checks.append(
            {
                "path": relative,
                "requirement": description,
                "needle": needle,
                "present": present,
            }
        )

    passed = all(check["present"] for check in checks)
    return {
        "source_root": str(root),
        "classification": "PASS" if passed else "IMAGE_CONTRACT_INVALID",
        "image_contract_pass": passed,
        "required_probe_indices": [0, 1],
        "production_c_or_rtl_modified": False,
        "hardware_inspected": False,
        "step5_complete": False,
        "step5_pass": False,
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    result = analyze(args.root.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {
                "classification": result["classification"],
                "image_contract_pass": result["image_contract_pass"],
                "check_count": len(result["checks"]),
            },
            ensure_ascii=False,
        )
    )
    return 0 if result["image_contract_pass"] else 2


if __name__ == "__main__":
    sys.exit(main())

