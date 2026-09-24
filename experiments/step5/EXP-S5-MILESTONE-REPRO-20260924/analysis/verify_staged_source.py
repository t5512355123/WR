#!/usr/bin/env python3
"""Check that Git's index preserves every frozen-source SHA256 byte-for-byte."""

from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
EXPERIMENT = Path(__file__).resolve().parents[1]
SOURCE = EXPERIMENT / "source"
INDEX_PREFIX = "experiments/step5/EXP-S5-MILESTONE-REPRO-20260924/source"


def run_git(*args: str, **kwargs):
    return subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
        **kwargs,
    ).stdout


def index_entries() -> dict[str, tuple[str, int]]:
    raw = run_git("ls-files", "-s", "-z", "--", INDEX_PREFIX)
    entries: dict[str, tuple[str, int]] = {}
    for record in raw.split(b"\0"):
        if not record:
            continue
        metadata, encoded_path = record.split(b"\t", 1)
        _mode, oid, stage = metadata.decode("ascii").split()
        path = encoded_path.decode("utf-8")
        relative = path.removeprefix(INDEX_PREFIX + "/")
        if relative in entries:
            raise ValueError(f"Duplicate staged path: {relative}")
        entries[relative] = (oid, int(stage))
    return entries


def staged_blob_hashes(items: list[tuple[str, str]]) -> dict[str, str]:
    with tempfile.TemporaryFile() as queries, tempfile.TemporaryFile() as output:
        for _path, oid in items:
            queries.write(oid.encode("ascii") + b"\n")
        queries.seek(0)
        result = subprocess.run(
            ["git", "cat-file", "--batch"],
            cwd=REPO_ROOT,
            stdin=queries,
            stdout=output,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
        output.seek(0)
        hashes: dict[str, str] = {}
        for path, expected_oid in items:
            header = output.readline().rstrip(b"\n").split()
            if len(header) != 3 or header[0].decode("ascii") != expected_oid or header[1] != b"blob":
                raise ValueError(f"Unexpected staged blob response for {path}: {header!r}")
            size = int(header[2])
            data = output.read(size)
            if len(data) != size or output.read(1) != b"\n":
                raise ValueError(f"Truncated staged blob: {path}")
            hashes[path] = hashlib.sha256(data).hexdigest()
        return hashes


def main() -> int:
    expected: dict[str, str] = {}
    for line in (SOURCE / "SHA256SUMS").read_text(encoding="utf-8").splitlines():
        digest, path = line.split("  ", 1)
        expected[path] = digest
    expected["SHA256SUMS"] = hashlib.sha256((SOURCE / "SHA256SUMS").read_bytes()).hexdigest()

    entries = index_entries()
    failures: list[str] = []
    if set(entries) != set(expected):
        missing = sorted(set(expected) - set(entries))[:10]
        extra = sorted(set(entries) - set(expected))[:10]
        failures.append(f"index file-set mismatch missing={missing} extra={extra}")
    for path, (_oid, stage) in entries.items():
        if stage != 0:
            failures.append(f"unmerged index entry: {path} stage={stage}")

    present = [(path, oid) for path, (oid, _stage) in entries.items() if path in expected]
    actual = staged_blob_hashes(present)
    for path, digest in expected.items():
        if path in actual and actual[path] != digest:
            failures.append(f"staged SHA256 mismatch: {path}")

    print(f"FROZEN_SOURCE_INDEX_FILES={len(entries)}")
    print(f"FROZEN_SOURCE_INDEX_SHA256_CHECKED={len(actual)}")
    print(f"FROZEN_SOURCE_INDEX_IDENTITY={'PASS' if not failures else 'FAIL'}")
    for failure in failures:
        print(f"FAIL: {failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
