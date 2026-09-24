#!/usr/bin/env python3
"""Audit legacy transfer archives against already-extracted evidence.

The audit is read-only with respect to source evidence.  It writes a TSV
inventory containing each archive/member hash and the exact retained file
that matches it.  No archive is removed by this program.
"""

from __future__ import annotations

import argparse
import collections
import hashlib
import pathlib
import subprocess
import tarfile


ARCHIVE_SUFFIXES = (".tar.gz", ".tgz", ".tar")
OUTPUT_RELATIVE = pathlib.Path(
    "experiments/repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924"
    "/analysis/legacy-archive-dedup.tsv"
)


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def experiment_root(root: pathlib.Path, archive: pathlib.Path) -> pathlib.Path:
    relative = archive.relative_to(root)
    parts = relative.parts
    try:
        legacy_index = parts.index("legacy")
    except ValueError as exc:
        raise RuntimeError(f"archive is outside experiments/legacy: {relative}") from exc
    if len(parts) <= legacy_index + 3:
        raise RuntimeError(f"cannot identify experiment directory: {relative}")
    candidate = root.joinpath(*parts[: legacy_index + 3])
    if not candidate.is_dir():
        raise RuntimeError(f"experiment directory is missing: {candidate}")
    return candidate


def safe_member_name(name: str) -> bool:
    member = pathlib.PurePosixPath(name)
    return not member.is_absolute() and ".." not in member.parts


def audit_archive(
    root: pathlib.Path,
    archive: pathlib.Path,
    tracked_paths: set[str],
    tracked_sofs: dict[tuple[str, str, int], str],
) -> list[dict[str, str]]:
    relative = archive.relative_to(root).as_posix()
    experiment = experiment_root(root, archive)
    available: dict[tuple[str, str, int, bool], collections.deque[str]] = collections.defaultdict(collections.deque)

    for candidate in sorted(experiment.rglob("*")):
        if not candidate.is_file() or candidate.name.endswith(ARCHIVE_SUFFIXES):
            continue
        digest = sha256_file(candidate)
        candidate_relative = candidate.relative_to(root).as_posix()
        is_tracked = candidate_relative in tracked_paths
        key = (candidate.name.casefold(), digest, candidate.stat().st_size, is_tracked)
        available[key].append(candidate_relative)

    archive_digest = sha256_file(archive)
    sidecar = archive.with_name(archive.name + ".sha256")
    sidecar_digest = sha256_file(sidecar) if sidecar.is_file() else ""
    sidecar_text = sidecar.read_text(encoding="ascii", errors="replace").strip() if sidecar.is_file() else ""
    declared_digest = sidecar_text.split()[0].lower() if sidecar_text else ""
    sidecar_status = "MATCH" if not sidecar.is_file() else ("MATCH" if declared_digest == archive_digest else "MISMATCH")

    members: list[dict[str, str]] = []
    nonregular: list[str] = []
    unsafe: list[str] = []
    with tarfile.open(archive, "r:*") as bundle:
        for member in bundle.getmembers():
            if member.isdir():
                continue
            if not member.isfile():
                nonregular.append(member.name)
                continue
            if not safe_member_name(member.name):
                unsafe.append(member.name)
                continue
            stream = bundle.extractfile(member)
            if stream is None:
                members.append({"member": member.name, "hash": "", "size": str(member.size), "match": "", "result": "UNREADABLE"})
                continue
            member_digest = hashlib.sha256()
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                member_digest.update(chunk)
            digest = member_digest.hexdigest()
            base_key = (pathlib.PurePosixPath(member.name).name.casefold(), digest, member.size)
            tracked_matches = available.get((*base_key, True))
            untracked_matches = available.get((*base_key, False))
            if tracked_matches:
                retained_path = tracked_matches.popleft()
                result = "MATCHED_TRACKED"
            elif pathlib.PurePosixPath(member.name).suffix.casefold() == ".sof" and base_key in tracked_sofs:
                retained_path = tracked_sofs[base_key]
                result = "MATCHED_TRACKED"
            elif untracked_matches:
                retained_path = untracked_matches.popleft()
                result = "MATCHED_UNTRACKED"
            else:
                retained_path = ""
                result = "UNMATCHED"
            members.append(
                {
                    "member": member.name,
                    "hash": digest,
                    "size": str(member.size),
                    "match": retained_path,
                    "result": result,
                }
            )

    matched_tracked = sum(row["result"] == "MATCHED_TRACKED" for row in members)
    matched_untracked = sum(row["result"] == "MATCHED_UNTRACKED" for row in members)
    complete = bool(members) and matched_tracked == len(members) and not nonregular and not unsafe and sidecar_status == "MATCH"
    classification = "EXACT_DUPLICATE_EXTRACTED" if complete else "KEEP_UNIQUE_OR_AMBIGUOUS"
    summary = {
        "record_type": "archive",
        "archive_path": relative,
        "archive_sha256": archive_digest,
        "archive_bytes": str(archive.stat().st_size),
        "classification": classification,
        "regular_members": str(len(members)),
        "matched_members": str(matched_tracked),
        "untracked_matches": str(matched_untracked),
        "nonregular_members": ";".join(nonregular),
        "unsafe_members": ";".join(unsafe),
        "sidecar_path": sidecar.relative_to(root).as_posix() if sidecar.is_file() else "",
        "sidecar_sha256": sidecar_digest,
        "sidecar_status": sidecar_status,
        "member_path": "",
        "member_sha256": "",
        "member_bytes": "",
        "retained_path": "",
        "member_result": "",
    }
    rows = [summary]
    for row in members:
        rows.append(
            {
                "record_type": "member",
                "archive_path": relative,
                "archive_sha256": archive_digest,
                "archive_bytes": "",
                "classification": classification,
                "regular_members": "",
                "matched_members": "",
                "untracked_matches": "",
                "nonregular_members": "",
                "unsafe_members": "",
                "sidecar_path": "",
                "sidecar_sha256": "",
                "sidecar_status": "",
                "member_path": row["member"],
                "member_sha256": row["hash"],
                "member_bytes": row["size"],
                "retained_path": row["match"],
                "member_result": row["result"],
            }
        )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, help="write TSV to this path (default: cleanup experiment analysis folder)")
    args = parser.parse_args()

    root = pathlib.Path(__file__).resolve().parents[4]
    archives = sorted(
        path
        for path in (root / "experiments/legacy").rglob("*")
        if path.is_file() and path.name.endswith(ARCHIVE_SUFFIXES)
    )
    tracked_paths = {
        item.decode("utf-8", "surrogateescape")
        for item in subprocess.check_output(["git", "ls-files", "-z"], cwd=root).split(b"\0")
        if item
    }
    tracked_sofs: dict[tuple[str, str, int], str] = {}
    for relative in sorted(path for path in tracked_paths if path.casefold().endswith(".sof")):
        candidate = root / pathlib.PurePosixPath(relative)
        if candidate.is_file():
            key = (candidate.name.casefold(), sha256_file(candidate), candidate.stat().st_size)
            tracked_sofs.setdefault(key, relative)
    rows: list[dict[str, str]] = []
    for archive in archives:
        rows.extend(audit_archive(root, archive, tracked_paths, tracked_sofs))

    columns = (
        "record_type", "archive_path", "archive_sha256", "archive_bytes", "classification",
        "regular_members", "matched_members", "untracked_matches", "nonregular_members", "unsafe_members",
        "sidecar_path", "sidecar_sha256", "sidecar_status", "member_path", "member_sha256",
        "member_bytes", "retained_path", "member_result",
    )
    output = args.output or (root / OUTPUT_RELATIVE)
    if args.output is None and output.exists():
        raise RuntimeError(
            f"refusing to overwrite the preserved audit: {output}; "
            "choose a new path with --output"
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("\t".join(columns) + "\n")
        for row in rows:
            stream.write(
                "\t".join(
                    row[column].replace("\t", " ").replace("\n", " ") or "-"
                    for column in columns
                )
                + "\n"
            )

    summaries = [row for row in rows if row["record_type"] == "archive"]
    counts = collections.Counter(row["classification"] for row in summaries)
    print(f"ARCHIVES_AUDITED={len(summaries)}")
    print(f"EXACT_DUPLICATE_EXTRACTED={counts['EXACT_DUPLICATE_EXTRACTED']}")
    print(f"KEEP_UNIQUE_OR_AMBIGUOUS={counts['KEEP_UNIQUE_OR_AMBIGUOUS']}")
    print(f"MEMBER_RECORDS={sum(int(row['regular_members']) for row in summaries)}")
    print(f"MEMBERS_MATCHED_ONLY_TO_UNTRACKED={sum(int(row['untracked_matches']) for row in summaries)}")
    print(f"AUDIT_TSV={output.relative_to(root).as_posix() if output.is_relative_to(root) else output}")
    return 0 if all(row["classification"] != "KEEP_UNIQUE_OR_AMBIGUOUS" or row["regular_members"] != row["matched_members"] for row in summaries) else 1


if __name__ == "__main__":
    raise SystemExit(main())
