#!/usr/bin/env python3
"""Build a per-file preservation audit from a Git baseline to the worktree.

The TSV is intentionally conservative: raw evidence without an exact retained
blob, and any deletion not covered by a verified archive/source/SOF manifest,
is reported as UNEXPLAINED for manual recovery.
"""

from __future__ import annotations

import csv
import hashlib
import io
import os
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path


BASELINE = "62182a94b437a7b0b77630f99ec50f788bc8ab7b"
ROOT = Path(__file__).resolve().parents[4]
ARCHIVE_TSV = ROOT / "experiments/repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924/analysis/legacy-archive-dedup.tsv"
SOF_MANIFESTS = (
    ROOT / "experiments/legacy/EXP-PAIN-HOME-ARCHIVE-DEDUP-20260924/nonmilestone-sof-prune-manifest.tsv",
    ROOT / "experiments/legacy/EXP-PAIN-HOME-ARCHIVE-DEDUP-20260924/laptop-nonmilestone-sof-prune-manifest.tsv",
)

SOURCE_DUPLICATES = {
    "experiments/step1/EXP-S1-MILESTONE-REPRO-20260924/candidate_source/": (
        "artifacts/milestones/step1_phy_link/source/",
        "experiments/step1/EXP-S1-MILESTONE-REPRO-20260924/analysis/source-deduplication.md",
    ),
    "experiments/step2/EXP-S2-MILESTONE-REPRO-20260924/candidate_source/": (
        "artifacts/milestones/step2_endpoint_ptp/source/",
        "experiments/step2/EXP-S2-MILESTONE-REPRO-20260924/analysis/source-deduplication.md",
    ),
    "experiments/step5/EXP-S5-MILESTONE-REPRO-20260924/source/": (
        "artifacts/milestones/step5_softpll_lock/source/",
        "experiments/step5/EXP-S5-MILESTONE-REPRO-20260924/analysis/source-deduplication.md",
    ),
}


def git(*args: str, check: bool = True) -> bytes:
    proc = subprocess.run(
        ["git", *args], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    if check and proc.returncode:
        raise RuntimeError(
            f"git {' '.join(args)} failed ({proc.returncode}): "
            f"{proc.stderr.decode(errors='replace')}"
        )
    return proc.stdout


def decode_path(raw: bytes) -> str:
    return os.fsdecode(raw).replace("\\", "/")


def baseline_tree(ref: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for record in git("ls-tree", "-r", "-z", "--full-tree", ref).split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        mode, kind, oid = metadata.decode("ascii").split()
        if kind == "blob":
            result[decode_path(raw_path)] = oid
    return result


def current_worktree_blobs() -> dict[str, set[str]]:
    result: dict[str, set[str]] = defaultdict(set)
    for record in git("ls-files", "--stage", "-z").split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        _mode, oid, stage = metadata.decode("ascii").split()
        if stage == "0":
            result[decode_path(raw_path)].add(oid)

    changed = set(git("diff", "--name-only", "-z").decode("utf-8", "surrogateescape").split("\0"))
    untracked = set(git("ls-files", "--others", "--exclude-standard", "-z").decode("utf-8", "surrogateescape").split("\0"))
    for path in changed | untracked:
        if not path:
            continue
        normalized = path.replace("\\", "/")
        absolute = ROOT / Path(path)
        if not absolute.is_file() or absolute.is_symlink():
            continue
        oid = file_blob_oid(absolute)
        result[normalized].add(oid)
    return result


def file_blob_oid(path: Path) -> str:
    """Compute Git's raw SHA-1 blob id without spawning git once per file."""
    size = path.stat().st_size
    digest = hashlib.sha1()
    digest.update(f"blob {size}\0".encode("ascii"))
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_diff_records(ref: str) -> list[tuple[str, str, str]]:
    raw = git(
        "diff",
        "--name-status",
        "-z",
        "--find-renames=50%",
        "-l30000",
        "--no-ext-diff",
        ref,
    )
    tokens = raw.split(b"\0")
    rows: list[tuple[str, str, str]] = []
    i = 0
    while i < len(tokens) and tokens[i]:
        status = tokens[i].decode("ascii")
        i += 1
        if status.startswith(("R", "C")):
            old_path = decode_path(tokens[i])
            new_path = decode_path(tokens[i + 1])
            i += 2
        else:
            old_path = decode_path(tokens[i])
            new_path = old_path if status == "M" else ""
            i += 1
        if status.startswith("R") or status == "D":
            rows.append((status, old_path, new_path))
    return rows


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_source_duplicate(old_path: str, old_oid: str, current: dict[str, set[str]]) -> tuple[str, str] | None:
    for prefix, (target_root, evidence) in SOURCE_DUPLICATES.items():
        if old_path.startswith(prefix):
            target = target_root + old_path[len(prefix) :]
            if old_oid in current.get(target, set()):
                return target, evidence
            return None
    return None


blob_sha_cache: dict[str, tuple[str, int]] = {}
blob_reader: subprocess.Popen[bytes] | None = None


def blob_sha256(oid: str) -> tuple[str, int]:
    global blob_reader
    if oid not in blob_sha_cache:
        if blob_reader is None:
            blob_reader = subprocess.Popen(
                ["git", "cat-file", "--batch"], cwd=ROOT,
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
        assert blob_reader.stdin is not None and blob_reader.stdout is not None
        blob_reader.stdin.write(oid.encode("ascii") + b"\n")
        blob_reader.stdin.flush()
        header = blob_reader.stdout.readline().split()
        if len(header) != 3 or header[1] != b"blob":
            raise RuntimeError(f"git cat-file --batch could not read blob {oid}")
        size = int(header[2])
        content = blob_reader.stdout.read(size)
        terminator = blob_reader.stdout.read(1)
        if len(content) != size or terminator != b"\n":
            raise RuntimeError(f"truncated git cat-file response for blob {oid}")
        blob_sha_cache[oid] = (hashlib.sha256(content).hexdigest(), len(content))
    return blob_sha_cache[oid]


def close_blob_reader() -> None:
    global blob_reader
    if blob_reader is None:
        return
    assert blob_reader.stdin is not None
    blob_reader.stdin.close()
    if blob_reader.stdout is not None:
        blob_reader.stdout.close()
    stderr = blob_reader.stderr.read() if blob_reader.stderr is not None else b""
    returncode = blob_reader.wait()
    blob_reader = None
    if returncode:
        raise RuntimeError(f"git cat-file --batch exited {returncode}: {stderr.decode(errors='replace')}")


def current_path_matches(path: str, expected_sha: str, expected_bytes: str | None,
                         current: dict[str, set[str]]) -> bool:
    for oid in current.get(path, set()):
        digest, size = blob_sha256(oid)
        if digest.lower() == expected_sha.lower() and (
            expected_bytes in (None, "", "-") or size == int(expected_bytes)
        ):
            return True
    return False


def verified_archives(baseline: dict[str, str], current: dict[str, set[str]]) -> tuple[set[str], set[str]]:
    rows = read_tsv(ARCHIVE_TSV)
    archive_rows = {r.get("archive_path", ""): r for r in rows if r.get("record_type") == "archive"}
    member_rows: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        if row.get("record_type") == "member":
            member_rows[row.get("archive_path", "")].append(row)

    valid_archives: set[str] = set()
    valid_sidecars: set[str] = set()
    for path, row in archive_rows.items():
        oid = baseline.get(path)
        if not oid or row.get("classification") != "EXACT_DUPLICATE_EXTRACTED":
            continue
        digest, size = blob_sha256(oid)
        if digest.lower() != row.get("archive_sha256", "").lower():
            continue
        if str(size) != row.get("archive_bytes", ""):
            continue
        if row.get("sidecar_path") not in ("", "-") and row.get("sidecar_status") != "MATCH":
            continue
        try:
            regular = int(row.get("regular_members", "-1"))
            matched = int(row.get("matched_members", "-1"))
        except ValueError:
            continue
        members = member_rows.get(path, [])
        if regular <= 0 or regular != matched or len(members) != regular:
            continue
        safe = True
        for member in members:
            if member.get("member_result") != "MATCHED_TRACKED":
                safe = False
                break
            retained = member.get("retained_path", "")
            expected_sha = member.get("member_sha256", "")
            expected_bytes = member.get("member_bytes", "")
            if not retained or not expected_sha or not current_path_matches(
                retained, expected_sha, expected_bytes, current
            ):
                safe = False
                break
        if not safe:
            continue
        valid_archives.add(path)
        if row.get("sidecar_path") not in ("", "-"):
            valid_sidecars.add(row["sidecar_path"])
    return valid_archives, valid_sidecars


def sof_prune_manifest() -> dict[str, tuple[str, str]]:
    result: dict[str, tuple[str, str]] = {}
    for manifest in SOF_MANIFESTS:
        for row in read_tsv(manifest):
            path = row.get("relative_path_from_04_WR_root", "").replace("\\", "/")
            digest = row.get("sha256", "")
            action = row.get("action", "")
            if path and digest:
                result[path] = (digest, action)
    return result


def classify(status: str, old_path: str, new_path: str, old_oid: str,
             baseline: dict[str, str], current: dict[str, set[str]],
             blob_paths: dict[str, list[str]], archives: set[str], sidecars: set[str],
             sof_manifest: dict[str, tuple[str, str]]) -> tuple[str, str, str]:
    duplicate = verify_source_duplicate(old_path, old_oid, current)
    if duplicate:
        target, evidence = duplicate
        return "VERIFIED_DUPLICATE_REMOVED", target, evidence

    if old_oid in blob_paths:
        candidates = blob_paths[old_oid]
        target = new_path if new_path and old_oid in current.get(new_path, set()) else candidates[0]
        return "MOVED", target, "exact Git blob retained byte-for-byte"

    if old_path in archives:
        return "ARCHIVE_CONTENT_FULLY_EXTRACTED_AND_VERIFIED", ";".join(
            row for row in [old_path]
        ), "archive SHA-256/size, all regular members, retained-member SHA-256, and sidecar status pass legacy-archive-dedup.tsv"
    if old_path in sidecars:
        return "ARCHIVE_CONTENT_FULLY_EXTRACTED_AND_VERIFIED", old_path, "checksum sidecar validated and recorded by legacy-archive-dedup.tsv; parent archive members verified"

    if old_path in sof_manifest:
        expected, action = sof_manifest[old_path]
        digest, _size = blob_sha256(old_oid)
        if digest.lower() == expected.lower() and "NON_MILESTONE_SOF" in action:
            return "INTENTIONALLY_REMOVED_NON_EVIDENCE", "", f"SHA-256 matches {action} entry in laptop/Pain SOF prune manifest"

    explicit_docs = {
        "CHANGELOG.md": ("experiments/legacy/CHANGELOG-20260920.md", "MODIFIED_PATH_ONLY", "dated historical changelog preserved under experiments/legacy"),
        "docs/experiments/README.md": ("experiments/legacy/EXPERIMENT-INDEX-PRE-RESTRUCTURE-20260920.md", "MODIFIED_TO_FIX_LINKS", "historical index retained with current Step6 links; experiments/README.md is the current index"),
        "archive/README.md": ("experiments/legacy/archive/README.md", "MODIFIED_TO_FIX_LINKS", "historical archive guide retained with path/provenance corrections"),
        "archive/MANIFEST.sha256": ("experiments/legacy/archive/MANIFEST.pain-source.sha256", "MODIFIED_PATH_ONLY", "Pain manifest retained with the archive relocation prefix; current-checkout integrity uses MANIFEST.sha256"),
    }
    if old_path in explicit_docs:
        target, classification, evidence = explicit_docs[old_path]
        return classification, target, evidence

    if status.startswith("R") and new_path:
        if old_path.lower().endswith(".md"):
            return "MODIFIED_TO_FIX_LINKS", new_path, "Git rename pairing; Markdown moved with authored references updated; inspect corresponding migration/report if semantic changes are suspected"
        if new_path.startswith("artifacts/milestones/") and "/source/" in new_path:
            return "MODIFIED_PATH_ONLY", new_path, "frozen source relocation; source/build provenance must identify any path-only transformation"

    if old_path in ("CHANGELOG.md", "docs/experiments/README.md"):
        return "INTENTIONALLY_REMOVED_NON_EVIDENCE", "", "obsolete navigation/changelog superseded by current README/STATUS/MILESTONES and experiment records"
    if old_path.startswith("scripts/pain/pain_build_"):
        return "INTENTIONALLY_REMOVED_NON_EVIDENCE", "scripts/build/ and scripts/program/", "obsolete Pain-specific wrapper; current canonical build/program entrypoints live under scripts/build and scripts/program"

    evidence_suffixes = (".log", ".rpt", ".summary", ".csv", ".json", ".bin", ".elf", ".mif")
    if "/raw/" in f"/{old_path}" or old_path.endswith(evidence_suffixes) or "raw-transfer" in old_path:
        return "UNEXPLAINED", new_path, "no exact retained blob and no verified archive/member manifest mapping"

    if old_path.startswith(("quartus/", "quartus_generated/", "archive/diagnostics/")):
        return "UNEXPLAINED", new_path, "no exact retained blob or verified source-relocation mapping"

    if status.startswith("R") and new_path:
        return "MODIFIED_PATH_ONLY", new_path, "Git similarity rename; review source/report provenance before final audit"

    return "UNEXPLAINED", new_path, "no exact retained blob or explicit preservation/removal evidence"


def main() -> int:
    ref = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else BASELINE
    output_path = None
    if "--output" in sys.argv:
        output_path = ROOT / sys.argv[sys.argv.index("--output") + 1]
    baseline = baseline_tree(ref)
    current = current_worktree_blobs()
    blob_paths: dict[str, list[str]] = defaultdict(list)
    for path, oids in current.items():
        for oid in oids:
            blob_paths[oid].append(path)
    for paths in blob_paths.values():
        paths.sort()
    archives, sidecars = verified_archives(baseline, current)
    sof_manifest = sof_prune_manifest()
    rows = parse_diff_records(ref)

    output = output_path.open("w", encoding="utf-8", newline="") if output_path else sys.stdout
    writer = csv.writer(output, delimiter="\t", lineterminator="\n")
    writer.writerow(("change", "baseline_path", "current_path", "baseline_git_blob", "current_git_blob", "baseline_sha256", "classification", "evidence"))
    counts: Counter[str] = Counter()
    for status, old_path, new_path in rows:
        old_oid = baseline.get(old_path, "")
        if not old_oid:
            classification, target, evidence = "UNEXPLAINED", new_path, "baseline path has no blob entry"
            old_sha = ""
            new_oid = ""
        else:
            classification, target, evidence = classify(
                status, old_path, new_path, old_oid, baseline, current,
                blob_paths, archives, sidecars, sof_manifest
            )
            old_sha, _ = blob_sha256(old_oid)
            target_blobs = current.get(target, set()) if target else set()
            new_oid = next(iter(sorted(target_blobs)), "")
        counts[classification] += 1
        writer.writerow((status, old_path, target, old_oid, new_oid, old_sha, classification, evidence))
    if output_path:
        output.close()

    close_blob_reader()

    print("PRESERVATION_AUDIT_SUMMARY", file=sys.stderr)
    for classification, count in sorted(counts.items()):
        print(f"{classification}\t{count}", file=sys.stderr)
    print(f"UNEXPLAINED\t{counts.get('UNEXPLAINED', 0)}", file=sys.stderr)
    return 0 if counts.get("UNEXPLAINED", 0) == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
