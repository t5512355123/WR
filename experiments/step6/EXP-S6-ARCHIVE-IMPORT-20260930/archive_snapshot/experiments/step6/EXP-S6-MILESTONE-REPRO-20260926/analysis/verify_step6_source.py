#!/usr/bin/env python3
"""Verify Step 6 frozen-source manifest, Git provenance, and SHA256SUMS."""

from __future__ import annotations

import csv
import hashlib
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
SOURCE_ROOT = REPO_ROOT / "artifacts" / "milestones" / "step6_global_time" / "source"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(f"blob {len(data)}\0".encode("ascii") + data).hexdigest()


def main() -> int:
    manifest_path = SOURCE_ROOT / "SOURCE_MANIFEST.tsv"
    with manifest_path.open("r", encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    if not rows:
        raise SystemExit("SOURCE_MANIFEST.tsv has no rows")

    missing: list[str] = []
    hash_mismatch: list[str] = []
    git_blob_mismatch: list[str] = []
    transform_mismatch: list[str] = []
    for row in rows:
        package_path = SOURCE_ROOT / row["package_path"]
        if not package_path.is_file():
            missing.append(row["package_path"])
            continue
        data = package_path.read_bytes()
        if hashlib.sha256(data).hexdigest() != row["sha256"]:
            hash_mismatch.append(row["package_path"])
        if row["git_blob"] == "-":
            continue
        if row["transformation"] in {"byte-identical", "read-only-dashboard-overlay"}:
            if git_blob_sha(data) != row["git_blob"]:
                git_blob_mismatch.append(row["package_path"])
            continue
        original = subprocess.run(
            ["git", "cat-file", "blob", row["git_blob"]],
            cwd=REPO_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        ).stdout
        if row["transformation"] == "quartus-relative-path-relocation-only":
            for before, after in (
                (b"../../vendor/", b"../vendor/"),
                (b"../../generated/", b"../quartus_generated/"),
                (b"../../rtl/clock/si5340_controller/", b"si5340_controller/"),
            ):
                original = original.replace(before, after)
            expected = original
        elif row["transformation"] == "firmware-mif-path-relocation-only":
            expected = original.replace(b"../../build/firmware/", b"../build/firmware/")
        else:
            transform_mismatch.append(row["package_path"])
            continue
        if data != expected:
            transform_mismatch.append(row["package_path"])

    sums_path = SOURCE_ROOT / "SHA256SUMS"
    sum_mismatch: list[str] = []
    for line in sums_path.read_text(encoding="ascii").splitlines():
        expected, relative = line.split("  ", 1)
        candidate = SOURCE_ROOT / relative
        if not candidate.is_file() or sha256(candidate) != expected:
            sum_mismatch.append(relative)

    required = (
        "quartus/DE5a_wr_master_jtag.qpf",
        "quartus/DE5a_wr_master_jtag.qsf",
        "quartus/DE5a_wr_master_jtag.sdc",
        "quartus/DE5a_wr_slave_jtag.qpf",
        "quartus/DE5a_wr_slave_jtag.qsf",
        "quartus/DE5a_wr_slave_jtag.sdc",
        "quartus/DE5a_wr_master_jtag.vhd",
        "quartus/DE5a_wr_slave_jtag.vhd",
        "quartus_generated/work_wrphy_full",
        "firmware/scripts/build_master_firmware.sh",
        "firmware/scripts/build_slave_firmware.sh",
        "vendor/wrpc-sw",
        "scripts/monitor/step1_6_dashboard.sh",
        "scripts/jtag/read_step1_6_dashboard.tcl",
        "scripts/tests/test_step1_6_dashboard.py",
    )
    missing_required = [
        relative for relative in required if not (SOURCE_ROOT / relative).exists()
    ]
    print(f"MANIFEST_ROWS={len(rows)}")
    print(f"MANIFEST_MISSING={len(missing)}")
    print(f"MANIFEST_SHA256_MISMATCH={len(hash_mismatch)}")
    print(f"GIT_BLOB_MISMATCH={len(git_blob_mismatch)}")
    print(f"TRANSFORM_MISMATCH={len(transform_mismatch)}")
    print(f"PACKAGE_SHA256SUMS_MISMATCH={len(sum_mismatch)}")
    print(f"REQUIRED_INPUTS_MISSING={len(missing_required)}")
    if missing or hash_mismatch or git_blob_mismatch or transform_mismatch or sum_mismatch or missing_required:
        for group, paths in (
            ("MANIFEST_MISSING_PATH", missing),
            ("MANIFEST_SHA256_BAD", hash_mismatch),
            ("GIT_BLOB_BAD", git_blob_mismatch),
            ("TRANSFORM_BAD", transform_mismatch),
            ("PACKAGE_SHA256SUMS_BAD", sum_mismatch),
            ("REQUIRED_INPUT_MISSING", missing_required),
        ):
            for path in paths:
                print(f"{group}={path}")
        print("SOURCE_PACKAGE=FAIL")
        return 1
    print("SOURCE_PACKAGE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
