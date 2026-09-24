#!/usr/bin/env python3
"""Remove only transfer archives proven redundant by the adjacent TSV audit.

Default mode is a read-only preview.  --apply unlinks only the exact audited
archive files and validated checksum sidecars; it never removes directories
or extracted evidence.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import pathlib
import subprocess
import sys


AUDIT_RELATIVE = pathlib.Path(
    "experiments/repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924"
    "/analysis/legacy-archive-dedup.tsv"
)
ARCHIVE_SUFFIXES = (".tar.gz", ".tgz", ".tar")


def digest_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tracked_paths(root: pathlib.Path) -> set[str]:
    output = subprocess.check_output(["git", "ls-files", "-z"], cwd=root)
    return {item.decode("utf-8", "surrogateescape") for item in output.split(b"\0") if item}


def safe_repo_file(root: pathlib.Path, relative: str, required_prefix: str) -> pathlib.Path:
    if not relative.startswith(required_prefix) or ".." in pathlib.PurePosixPath(relative).parts:
        raise RuntimeError(f"out-of-scope path in audit: {relative}")
    candidate = root / pathlib.PurePosixPath(relative)
    if candidate.is_symlink():
        raise RuntimeError(f"refusing symlink: {relative}")
    path = candidate.resolve(strict=True)
    try:
        path.relative_to(root.resolve())
    except ValueError as exc:
        raise RuntimeError(f"resolved path escapes repository: {relative}") from exc
    if not path.is_file():
        raise RuntimeError(f"expected a regular non-symlink file: {relative}")
    return path


def has_markdown_archive_link(root: pathlib.Path, archive_paths: set[str]) -> list[str]:
    sys.path.insert(0, str(root))
    from scripts.analysis.check_markdown_links import markdown_targets, normalized_local_path

    all_paths = set(tracked_paths(root))
    others = subprocess.check_output(
        ["git", "ls-files", "-z", "--others", "--exclude-standard"], cwd=root
    )
    all_paths.update(item.decode("utf-8", "surrogateescape") for item in others.split(b"\0") if item)
    references = []
    for relative in sorted(path for path in all_paths if path.lower().endswith(".md")):
        markdown = root / pathlib.PurePosixPath(relative)
        if not markdown.is_file():
            continue
        text = markdown.read_text(encoding="utf-8", errors="replace")
        for line, target in markdown_targets(text):
            normalized = normalized_local_path(relative, target)
            if normalized in archive_paths:
                references.append(f"{relative}:{line} -> {target}")
    return references


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="unlink the preflight-verified duplicate archives")
    args = parser.parse_args()

    root = pathlib.Path(__file__).resolve().parents[4]
    audit_path = root / AUDIT_RELATIVE
    with audit_path.open("r", encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    summaries = {row["archive_path"]: row for row in rows if row["record_type"] == "archive"}
    members: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        if row["record_type"] == "member":
            members.setdefault(row["archive_path"], []).append(row)

    actual_archives = {
        path.relative_to(root).as_posix()
        for path in (root / "experiments/legacy").rglob("*")
        if path.is_file() and path.name.endswith(ARCHIVE_SUFFIXES)
    }
    if actual_archives != set(summaries):
        raise RuntimeError("the on-disk archive set changed since the audit; regenerate the TSV")

    tracked = tracked_paths(root)
    selected = [row for row in summaries.values() if row["classification"] == "EXACT_DUPLICATE_EXTRACTED"]
    delete_paths: list[tuple[str, pathlib.Path]] = []
    for summary in selected:
        relative = summary["archive_path"]
        if relative not in tracked:
            raise RuntimeError(f"archive is not tracked: {relative}")
        archive = safe_repo_file(root, relative, "experiments/legacy/")
        if archive.stat().st_size != int(summary["archive_bytes"]) or digest_file(archive) != summary["archive_sha256"]:
            raise RuntimeError(f"archive changed since audit: {relative}")

        member_rows = members.get(relative, [])
        if not member_rows or any(row["member_result"] != "MATCHED_TRACKED" for row in member_rows):
            raise RuntimeError(f"not every archive member has a tracked extracted copy: {relative}")
        for member in member_rows:
            retained_relative = member["retained_path"]
            if retained_relative not in tracked:
                raise RuntimeError(f"retained match is not tracked: {retained_relative}")
            retained = safe_repo_file(root, retained_relative, "experiments/")
            if retained.stat().st_size != int(member["member_bytes"]) or digest_file(retained) != member["member_sha256"]:
                raise RuntimeError(f"retained file changed since audit: {retained_relative}")

        delete_paths.append((relative, archive))
        sidecar_relative = summary["sidecar_path"]
        if sidecar_relative:
            expected_sidecar = relative + ".sha256"
            if sidecar_relative != expected_sidecar or sidecar_relative not in tracked:
                raise RuntimeError(f"unexpected or untracked checksum sidecar: {sidecar_relative}")
            sidecar = safe_repo_file(root, sidecar_relative, "experiments/legacy/")
            if digest_file(sidecar) != summary["sidecar_sha256"]:
                raise RuntimeError(f"checksum sidecar changed since audit: {sidecar_relative}")
            declared = sidecar.read_text(encoding="ascii", errors="replace").strip().split()
            if not declared or declared[0].lower() != summary["archive_sha256"]:
                raise RuntimeError(f"checksum sidecar does not match archive: {sidecar_relative}")
            delete_paths.append((sidecar_relative, sidecar))

    deleted_link_targets = {relative for relative, _ in delete_paths}
    references = has_markdown_archive_link(root, deleted_link_targets)
    if references:
        raise RuntimeError("update Markdown links before pruning:\n" + "\n".join(references))

    action = "remove" if args.apply else "would remove"
    for relative, path in delete_paths:
        print(f"{action}\t{relative}")
    print(f"DUPLICATE_ARCHIVES={len(selected)}")
    print(f"FILES_TO_UNLINK={len(delete_paths)}")
    print(f"APPLIED={int(args.apply)}")
    if args.apply:
        for _, path in delete_paths:
            path.unlink()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
