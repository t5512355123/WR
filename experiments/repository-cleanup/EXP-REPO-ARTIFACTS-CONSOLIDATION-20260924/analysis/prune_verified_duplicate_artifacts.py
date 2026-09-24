#!/usr/bin/env python3
"""Remove only byte-identical ignored copies listed in the audit TSV."""

from __future__ import annotations

import argparse
import csv
import hashlib
import pathlib
import subprocess
import sys


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def repository_root(script: pathlib.Path) -> pathlib.Path:
    for parent in script.resolve().parents:
        if (parent / ".git").exists():
            return parent
    raise RuntimeError("cannot locate repository root")


def is_tracked(root: pathlib.Path, relative: str) -> bool:
    return subprocess.run(
        ["git", "ls-files", "--error-unmatch", "--", relative],
        cwd=root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="unlink verified duplicate files")
    args = parser.parse_args()

    script = pathlib.Path(__file__)
    root = repository_root(script)
    audit = script.with_name("untracked-artifact-audit.tsv")
    artifacts = (root / "artifacts").resolve()
    selected: list[tuple[str, pathlib.Path, bool]] = []

    with audit.open("r", encoding="utf-8", newline="") as stream:
        for row in csv.DictReader(stream, delimiter="\t"):
            if row["classification"] != "byte-identical-copy-already-retained":
                continue
            source_rel = row["source_path"]
            retained_rel = row["matching_path"]
            if not source_rel.startswith("artifacts/") or source_rel.startswith("artifacts/milestones/"):
                raise RuntimeError(f"refusing out-of-scope source: {source_rel}")
            if not (retained_rel.startswith("experiments/") or retained_rel.startswith("artifacts/milestones/")):
                raise RuntimeError(f"retained copy is outside evidence: {retained_rel}")

            source = (root / pathlib.PurePosixPath(source_rel)).resolve(strict=False)
            retained = (root / pathlib.PurePosixPath(retained_rel)).resolve(strict=True)
            try:
                source.relative_to(artifacts)
            except ValueError as exc:
                raise RuntimeError(f"resolved source escaped artifacts/: {source_rel}") from exc
            if not retained.is_file():
                raise RuntimeError(f"retained copy is not a regular file: {retained_rel}")
            expected = row["sha256"].lower()
            if sha256(retained) != expected:
                raise RuntimeError(f"retained copy changed since audit: {retained_rel}")
            if not source.exists():
                selected.append((source_rel, source, False))
                continue
            if not source.is_file():
                raise RuntimeError(f"source is not a regular file: {source_rel}")
            if is_tracked(root, source_rel):
                raise RuntimeError(f"refusing to unlink tracked file: {source_rel}")
            if sha256(source) != expected:
                raise RuntimeError(f"content changed since audit: {source_rel}")
            selected.append((source_rel, source, True))

    mode = "remove" if args.apply else "would remove"
    for relative, source, source_exists in selected:
        print(f"{mode if source_exists else 'already removed'}\t{relative}")
        if args.apply and source_exists:
            source.unlink()
    print(f"verified_duplicate_files={len(selected)}")
    print(f"applied={int(args.apply)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # fail closed before any unlink loop completes
        print(f"ERROR: {error}", file=sys.stderr)
        raise
