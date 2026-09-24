#!/usr/bin/env python3
"""Audit direct file-valued assignments in the two frozen Step 2 QSF files."""

from __future__ import annotations

import collections
import pathlib
import re
import sys


ASSIGNMENT = re.compile(
    r"^\s*set_global_assignment\s+-name\s+"
    r"(VHDL_FILE|VERILOG_FILE|SYSTEMVERILOG_FILE|QIP_FILE|"
    r"SDC_FILE|QSYS_FILE|IP_FILE|SOURCE_FILE|TCL_SCRIPT_FILE)\s+"
    r"(?:\"([^\"]+)\"|'([^']+)'|(\S+))",
    re.IGNORECASE,
)


def main() -> int:
    root = pathlib.Path(sys.argv[1]).resolve()
    projects = (
        ("MASTER", "DE5a_wr_master_jtag", root / "quartus" / "DE5a_wr_master_jtag.qsf"),
        ("SLAVE", "DE5a_wr_slave_jtag", root / "quartus" / "DE5a_wr_slave_jtag.qsf"),
    )
    missing: list[tuple[str, str, str]] = []
    totals: collections.Counter[str] = collections.Counter()

    for role, expected_entity, qsf in projects:
        if not qsf.is_file():
            print(f"QSF_MISSING role={role} path={qsf}")
            return 2
        text = qsf.read_text(encoding="utf-8", errors="strict")
        entity_match = re.search(
            r"^\s*set_global_assignment\s+-name\s+TOP_LEVEL_ENTITY\s+(\S+)",
            text,
            re.MULTILINE | re.IGNORECASE,
        )
        entity = entity_match.group(1) if entity_match else "MISSING"
        print(f"QSF_ENTITY role={role} entity={entity} expected={expected_entity}")
        if entity != expected_entity:
            missing.append((role, "top-level-entity", f"{entity} != {expected_entity}"))
        role_count = 0
        for line_number, line in enumerate(text.splitlines(), 1):
            match = ASSIGNMENT.match(line)
            if not match:
                continue
            kind = match.group(1).upper()
            token = next(group for group in match.groups()[1:] if group is not None)
            totals[kind] += 1
            role_count += 1
            if "$" in token or "[" in token or "]" in token:
                missing.append((role, f"line={line_number}", f"unresolved-token={token}"))
                continue
            resolved = (qsf.parent / token).resolve()
            if not resolved.is_file():
                missing.append((role, f"line={line_number}", f"{token} -> {resolved}"))
        print(f"QSF_AUDIT role={role} file_assignments={role_count}")

    print("QSF_AUDIT_BY_TYPE " + " ".join(f"{key}={totals[key]}" for key in sorted(totals)))
    print(f"QSF_AUDIT_TOTAL file_assignments={sum(totals.values())} missing={len(missing)}")
    for role, location, detail in missing:
        print(f"QSF_MISSING role={role} {location} {detail}")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
