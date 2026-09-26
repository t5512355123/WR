#!/usr/bin/env python3
"""Preserve every exact baseline blob still marked UNEXPLAINED by the audit."""

from __future__ import annotations

import csv
import hashlib
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
AUDIT = ROOT / "experiments/repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924/analysis/preservation-audit.tsv"
DEST = ROOT / "experiments/legacy/preserved-baseline/objects"
MANIFEST = ROOT / "experiments/legacy/preserved-baseline/MANIFEST.tsv"


def git_blob(oid: str) -> bytes:
    proc = subprocess.run(
        ["git", "cat-file", "blob", oid], cwd=ROOT,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    )
    return proc.stdout


def main() -> None:
    with AUDIT.open("r", encoding="utf-8-sig", newline="") as source:
        rows = [row for row in csv.DictReader(source, delimiter="\t")
                if row.get("classification") in {
                    "UNEXPLAINED", "MODIFIED_TO_FIX_LINKS", "MODIFIED_PATH_ONLY"
                }]

    manifest_by_path: dict[str, dict[str, str]] = {}
    if MANIFEST.exists():
        with MANIFEST.open("r", encoding="utf-8-sig", newline="") as existing:
            for row in csv.DictReader(existing, delimiter="\t"):
                preserved = ROOT / row["preserved_path"]
                digest = hashlib.sha256(preserved.read_bytes()).hexdigest()
                if digest.lower() != row["sha256"].lower():
                    raise ValueError(f"existing retained blob failed SHA-256: {preserved}")
                manifest_by_path[row["baseline_path"]] = row

    DEST.mkdir(parents=True, exist_ok=True)
    for row in rows:
        oid = row["baseline_git_blob"]
        if not re.fullmatch(r"[0-9a-f]{40}", oid):
            raise ValueError(f"invalid baseline blob id for {row['baseline_path']}")
        content = git_blob(oid)
        digest = hashlib.sha256(content).hexdigest()
        if digest.lower() != row["baseline_sha256"].lower():
            raise ValueError(f"baseline SHA-256 mismatch for {row['baseline_path']}")

        basename = Path(row["baseline_path"]).name
        if len(basename) > 100:
            suffix = "".join(Path(basename).suffixes)[-16:]
            stem = Path(basename).name[:-len(suffix)] if suffix else basename
            basename = stem[:70] + suffix
        target = DEST / f"{oid}--{basename}"
        if target.exists():
            if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                raise FileExistsError(f"refusing to overwrite mismatched {target}")
        else:
            target.write_bytes(content)
        manifest_by_path[row["baseline_path"]] = {
            "baseline_path": row["baseline_path"],
            "preserved_path": target.relative_to(ROOT).as_posix(),
            "baseline_git_blob": oid,
            "sha256": digest,
            "bytes": str(len(content)),
            "reason": (
                "exact baseline blob restored because the audit found no retained copy or verified archive mapping"
                if row["classification"] == "UNEXPLAINED" else
                f"exact pre-migration snapshot retained; audit classified the relocated version as {row['classification']}"
            ),
        }

    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    with MANIFEST.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=(
            "baseline_path", "preserved_path", "baseline_git_blob", "sha256", "bytes", "reason"
        ), delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(manifest_by_path[path] for path in sorted(manifest_by_path))
    print(f"PRESERVED_EXACT_BASELINE_BLOBS={len(manifest_by_path)}")
    print(f"MANIFEST={MANIFEST.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
