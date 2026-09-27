#!/usr/bin/env python3
"""Audit the Step 6 legacy-to-current promotion against the task start commit."""

from __future__ import annotations

import csv
import os
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path


BASELINE = "c55e32a3b477a6c3bced43a346fdca8e5bece4b0"
SOURCE_PREFIX = "experiments/legacy/exp-step6-global-time/"
CURRENT_PREFIX = "experiments/step6/"
ARCHIVE_PREFIX = "experiments/legacy/preserved-baseline/objects/"
ROOT = Path(__file__).resolve().parents[4]
OUTPUT = (
    ROOT
    / "experiments/repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924/analysis/step6-promotion-audit.tsv"
)


def git_tree(revision: str, *prefixes: str) -> dict[str, str]:
    output = subprocess.check_output(
        ["git", "ls-tree", "-r", "-z", "--full-tree", revision, "--", *prefixes],
        cwd=ROOT,
    )
    tree: dict[str, str] = {}
    for record in output.split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        _mode, kind, oid = metadata.decode("ascii").split()
        if kind == "blob":
            tree[os.fsdecode(raw_path).replace("\\", "/")] = oid
    return tree


def main() -> int:
    baseline = git_tree(BASELINE, SOURCE_PREFIX.rstrip("/"))
    current = git_tree("HEAD", CURRENT_PREFIX.rstrip("/"), ARCHIVE_PREFIX.rstrip("/"))
    current_step6 = {path: oid for path, oid in current.items() if path.startswith(CURRENT_PREFIX)}
    preserved = {path: oid for path, oid in current.items() if path.startswith(ARCHIVE_PREFIX)}

    step6_paths_by_blob: dict[str, list[str]] = defaultdict(list)
    preserved_paths_by_blob: dict[str, list[str]] = defaultdict(list)
    for path, oid in current_step6.items():
        step6_paths_by_blob[oid].append(path)
    for path, oid in preserved.items():
        preserved_paths_by_blob[oid].append(path)

    rows: list[dict[str, str]] = []
    counts: Counter[str] = Counter()
    for old_path, old_oid in sorted(baseline.items()):
        relative = old_path[len(SOURCE_PREFIX) :]
        expected_path = CURRENT_PREFIX + relative
        actual_oid = current_step6.get(expected_path, "")
        if actual_oid == old_oid:
            status = "MOVED_EXACT"
            destination = expected_path
            reason = "same relative path and exact Git blob"
        elif actual_oid:
            archive_matches = preserved_paths_by_blob.get(old_oid, [])
            if archive_matches:
                status = "MODIFIED_WITH_EXACT_BASELINE_SNAPSHOT"
                destination = expected_path
                reason = "current file changed; original Git blob retained in baseline archive"
            elif step6_paths_by_blob.get(old_oid):
                status = "MODIFIED_WITH_EXACT_STEP6_COPY"
                destination = expected_path
                reason = "current file changed; original Git blob retained at another Step 6 path"
            else:
                status = "UNEXPLAINED"
                destination = expected_path
                reason = "destination content differs and original blob was not found"
        elif step6_paths_by_blob.get(old_oid):
            status = "MOVED_REPATH"
            destination = ";".join(sorted(step6_paths_by_blob[old_oid]))
            reason = "exact Git blob retained elsewhere under current Step 6"
        elif preserved_paths_by_blob.get(old_oid):
            status = "ARCHIVED_EXACT_ONLY"
            destination = ";".join(sorted(preserved_paths_by_blob[old_oid]))
            reason = "exact Git blob preserved, but not promoted under experiments/step6"
        else:
            status = "UNEXPLAINED"
            destination = ""
            reason = "baseline Step 6 Git blob absent from current Step 6 and preservation archive"

        counts[status] += 1
        rows.append(
            {
                "baseline_path": old_path,
                "baseline_git_blob": old_oid,
                "status": status,
                "current_path": destination,
                "current_git_blob": actual_oid,
                "evidence": reason,
            }
        )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=(
                "baseline_path",
                "baseline_git_blob",
                "status",
                "current_path",
                "current_git_blob",
                "evidence",
            ),
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"BASELINE_STEP6_FILES={len(baseline)}")
    print(f"CURRENT_STEP6_FILES={len(current_step6)}")
    for status in sorted(counts):
        print(f"{status}={counts[status]}")
    print(f"STEP6_PROMOTION_AUDIT={OUTPUT.relative_to(ROOT).as_posix()}")
    return 1 if counts["UNEXPLAINED"] else 0


if __name__ == "__main__":
    sys.exit(main())
