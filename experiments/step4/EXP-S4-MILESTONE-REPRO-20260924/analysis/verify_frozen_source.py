#!/usr/bin/env python3
"""Verify the Step 4 source snapshot against its historical Git blobs."""

from __future__ import annotations

import hashlib
import subprocess
import sys
from pathlib import Path


COMMIT = "a1980bff30231376a3182486fd786d906876c2d4"
REPO_ROOT = Path(__file__).resolve().parents[4]
SOURCE_ROOT = REPO_ROOT / "artifacts" / "milestones" / "step4_softpll_startup" / "source"
BUILD_WRAPPERS = {
    "firmware/scripts/build_all_firmware.sh",
    "firmware/scripts/build_master_firmware.sh",
    "firmware/scripts/build_slave_firmware.sh",
}


def mapped_path(old: str) -> Path | None:
    mappings = (
        ("quartus/jtag_runtime_diag/", SOURCE_ROOT / "quartus"),
        ("generated/work_wrphy_full/", SOURCE_ROOT / "quartus_generated" / "work_wrphy_full"),
        ("firmware/", SOURCE_ROOT / "firmware"),
        ("vendor/", SOURCE_ROOT / "vendor"),
        ("rtl/clock/si5340_controller/", SOURCE_ROOT / "quartus" / "si5340_controller"),
        ("scripts/jtag/", SOURCE_ROOT / "scripts" / "jtag"),
    )
    for prefix, destination in mappings:
        if old.startswith(prefix):
            return destination / old[len(prefix) :]
    return None


def reverse_path_relocation(path: str, data: bytes) -> bytes:
    if path.endswith(".qsf"):
        data = data.replace(b"../vendor/", b"../../vendor/")
        data = data.replace(b"../quartus_generated/", b"../../generated/")
        data = data.replace(
            b"si5340_controller/", b"../../rtl/clock/si5340_controller/"
        )
    elif path.endswith("DE5a_wr_master_jtag.vhd") or path.endswith(
        "DE5a_wr_slave_jtag.vhd"
    ):
        data = data.replace(b"../build/firmware/", b"../../build/firmware/")
    return data


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def main() -> int:
    result = subprocess.run(
        [
            "git",
            "ls-tree",
            "-r",
            "-z",
            "--full-tree",
            COMMIT,
            "--",
            "quartus/jtag_runtime_diag",
            "generated/work_wrphy_full",
            "firmware",
            "vendor",
            "rtl/clock/si5340_controller",
            "scripts/jtag",
        ],
        cwd=REPO_ROOT,
        check=True,
        stdout=subprocess.PIPE,
    )

    checked = 0
    filter_fallbacks = 0
    build_wrappers: list[tuple[str, str, str]] = []
    failures: list[str] = []
    for record in result.stdout.split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        mode, object_type, expected_blob = metadata.decode("ascii").split()
        old_path = raw_path.decode("utf-8")
        if object_type != "blob":
            failures.append(f"unexpected non-blob entry {old_path} ({mode})")
            continue
        destination = mapped_path(old_path)
        if destination is None:
            failures.append(f"unmapped historical input {old_path}")
            continue
        if not destination.is_file():
            failures.append(f"missing snapshot file {destination}")
            continue
        if old_path in BUILD_WRAPPERS:
            current_sha256 = hashlib.sha256(destination.read_bytes()).hexdigest()
            build_wrappers.append((old_path, expected_blob, current_sha256))
            continue
        normalized = reverse_path_relocation(old_path, destination.read_bytes())
        actual = git_blob_sha(normalized)
        # git archive was extracted on Windows with core.autocrlf enabled;
        # Git's text=auto clean filter canonicalizes CRLF in text files but
        # leaves binary payloads (which contain NUL bytes) unchanged.
        if actual != expected_blob and b"\0" not in normalized:
            normalized = normalized.replace(b"\r\n", b"\n")
            actual = git_blob_sha(normalized)
        if actual != expected_blob:
            filtered = subprocess.run(
                ["git", "hash-object", f"--path={old_path}", "--stdin"],
                cwd=REPO_ROOT,
                input=normalized,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout.decode("ascii").strip()
            if filtered == expected_blob:
                actual = filtered
                filter_fallbacks += 1
        checked += 1
        if actual != expected_blob:
            failures.append(f"blob mismatch {old_path}: {actual} != {expected_blob}")

    print(f"SOURCE_ORIGIN_COMMIT={COMMIT}")
    print(f"HISTORICAL_SOURCE_FILES_CHECKED={checked}")
    print(f"HISTORICAL_SOURCE_MISMATCHES={len(failures)}")
    print(f"GIT_FILTER_FALLBACKS={filter_fallbacks}")
    print(f"BUILD_WRAPPER_FILES_CHECKED={len(build_wrappers)}")
    for path, historical_blob, current_sha256 in build_wrappers:
        print(
            f"BUILD_WRAPPER={path} HISTORICAL_GIT_BLOB={historical_blob} "
            f"CURRENT_SHA256={current_sha256}"
        )
    for failure in failures[:50]:
        print(f"FAIL: {failure}")
    print("FROZEN_SOURCE_IDENTITY=" + ("PASS" if checked and not failures else "FAIL"))
    return 0 if checked and not failures else 1


if __name__ == "__main__":
    sys.exit(main())
