#!/usr/bin/env python3
"""Read-only content audit for non-milestone files under artifacts/."""

from __future__ import annotations

import collections
import hashlib
import pathlib
import subprocess
import tarfile


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def repo_root() -> pathlib.Path:
    for parent in pathlib.Path(__file__).resolve().parents:
        if (parent / ".git").exists():
            return parent
    raise RuntimeError("could not locate repository root")


def indexed_paths(root: pathlib.Path) -> list[tuple[str, str]]:
    output = subprocess.check_output(
        ["git", "ls-files", "--stage", "-z"], cwd=root
    )
    rows = []
    for record in output.split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        _, object_id, _ = metadata.decode("ascii").split()
        rows.append((object_id, raw_path.decode("utf-8", errors="surrogateescape")))
    return rows


def experiment_id(archive_name: str) -> str:
    suffixes = (
        "-recovery-raw-transfer.tgz",
        "-raw-transfer-valid.tgz",
        "-raw-transfer.tgz",
        "-raw-v2.tgz",
        "-raw.tgz",
        ".tar.gz",
        ".tgz",
    )
    for suffix in suffixes:
        if archive_name.endswith(suffix):
            return archive_name[: -len(suffix)]
    return archive_name


def candidate_experiment_dirs(root: pathlib.Path, exp_id: str) -> list[pathlib.Path]:
    base = root / "experiments" / "legacy" / "exp-step5-softpll-lock"
    variants = [exp_id]
    for suffix in ("-recovery", "-raw-v2", "-valid"):
        if exp_id.endswith(suffix):
            variants.append(exp_id[: -len(suffix)])
    found = []
    for variant in variants:
        found.extend(p for p in base.rglob(variant) if p.is_dir() and p.name == variant)
    return sorted(set(found), key=lambda p: (len(p.parts), p.as_posix()))


def file_hashes(directory: pathlib.Path) -> set[str]:
    hashes = set()
    for path in directory.rglob("*"):
        if path.is_file():
            hashes.add(sha256(path.read_bytes()))
    return hashes


def proposed_destination(root: pathlib.Path, source: str) -> str:
    parts = pathlib.PurePosixPath(source).parts
    if "milestones" in parts:
        return source
    group = parts[1] if len(parts) > 1 else "root"
    if group.startswith("EXP-BASELINE-RS422"):
        base = "experiments/legacy/rejected-rs422-step1-candidate"
    elif group.startswith("EXP-STEP4B"):
        base = "experiments/legacy/exp-step4b-slave-softpll-startup/artifact-import"
    elif group.startswith("EXP-S6-"):
        base = "experiments/legacy/exp-step6-global-time/artifact-import"
    elif group.startswith(("EXP-S5-", "EXP-WRPC-STEP5-", "exp-step5-")):
        base = "experiments/legacy/exp-step5-softpll-lock/artifact-import"
    else:
        base = "experiments/legacy/artifact-import"
    relative = pathlib.PurePosixPath(*parts[1:])
    return (pathlib.PurePosixPath(base) / relative).as_posix()


def archive_coverage(path: pathlib.Path, candidate: pathlib.Path) -> tuple[int, int]:
    with tarfile.open(path, "r:*") as archive:
        members = [member for member in archive.getmembers() if member.isfile()]
        known = file_hashes(candidate)
        matches = 0
        for member in members:
            stream = archive.extractfile(member)
            if stream is not None and sha256(stream.read()) in known:
                matches += 1
        return matches, len(members)


def main() -> None:
    root = repo_root()
    rows = indexed_paths(root)
    experiment_blobs: dict[str, list[str]] = collections.defaultdict(list)
    for object_id, path in rows:
        if path.startswith("experiments/"):
            experiment_blobs[object_id].append(path)

    candidates = [
        (object_id, path)
        for object_id, path in rows
        if path.startswith("artifacts/")
        and not path.startswith("artifacts/milestones/")
        and path != "artifacts/README.md"
    ]
    output = [
        "source_path\tbytes\tsha256\tgit_blob\tclassification\t"
        "retained_or_matching_path\ttar_files\ttar_files_content_matched\tchecksum_sidecar"
    ]
    totals = collections.Counter()
    for object_id, source in candidates:
        source_path = root / pathlib.PurePosixPath(source)
        data_hash = sha256(source_path.read_bytes())
        size = source_path.stat().st_size
        matching = sorted(experiment_blobs.get(object_id, []))
        package_path = None
        if source.endswith((".tgz", ".tar.gz")):
            package_path = source_path

        if matching:
            classification = "exact-git-blob-duplicate"
            destination = matching[0]
            total_files = matched_files = ""
            totals[classification] += 1
        elif package_path is not None:
            exp_id = experiment_id(package_path.name)
            dirs = candidate_experiment_dirs(root, exp_id)
            if dirs:
                matched_files_int, total_files_int = archive_coverage(package_path, dirs[0])
                total_files, matched_files = str(total_files_int), str(matched_files_int)
                if matched_files_int == total_files_int:
                    classification = "archive-contents-already-present"
                else:
                    classification = "archive-has-unique-members"
                destination = dirs[0].relative_to(root).as_posix()
            else:
                classification = "archive-no-experiment-directory"
                destination = "experiments/legacy/step5-transfer-archives/"
                total_files = matched_files = ""
            totals[classification] += 1
        elif source.endswith(".sha256"):
            archive_source = source[: -len(".sha256")]
            archive_path = root / pathlib.PurePosixPath(archive_source)
            if archive_path.is_file():
                recorded = source_path.read_text(encoding="ascii", errors="replace").split()[0]
                actual = sha256(archive_path.read_bytes())
                if recorded.lower() == actual:
                    classification = "valid-sidecar-for-transfer-archive"
                    destination = f"sidecar verifies {archive_source}"
                else:
                    classification = "sidecar-hash-mismatch"
                    destination = archive_source
            else:
                classification = "unpaired-checksum-sidecar"
                destination = "experiments/legacy/artifact-inventory/"
            total_files = matched_files = ""
            totals[classification] += 1
        else:
            classification = "unique-file-to-preserve"
            parts = pathlib.PurePosixPath(source).parts
            if len(parts) > 2 and parts[1].startswith("EXP-"):
                exp_id = parts[1]
                report_root = root / "experiments/legacy/exp-step5-softpll-lock"
                report_exists = any(report_root.glob(f"{exp_id}*.md"))
                relative = pathlib.PurePosixPath(*parts[2:])
                if report_exists:
                    destination = (
                        pathlib.PurePosixPath(
                            "experiments/legacy/exp-step5-softpll-lock/raw", exp_id,
                            "artifact-import",
                        )
                        / relative
                    ).as_posix()
                else:
                    destination = (
                        pathlib.PurePosixPath(
                            "experiments/legacy/artifact-import", exp_id
                        )
                        / relative
                    ).as_posix()
            else:
                destination = (
                    pathlib.PurePosixPath("experiments/legacy/artifact-inventory")
                    / pathlib.PurePosixPath(*parts[1:])
                ).as_posix()
            total_files = matched_files = ""
            totals[classification] += 1

        checksum_sidecar = ""
        if package_path is not None:
            sidecar = root / "artifacts" / (package_path.name + ".sha256")
            if sidecar.is_file():
                checksum_sidecar = "present"

        output.append(
            "\t".join(
                (
                    source,
                    str(size),
                    data_hash,
                    object_id,
                    classification,
                    destination,
                    total_files,
                    matched_files,
                    checksum_sidecar,
                )
            ).rstrip("\t")
        )

    target = (
        root
        / "experiments/repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924"
        / "analysis/artifact-migration-audit.tsv"
    )
    target.write_text("\n".join(output) + "\n", encoding="utf-8", newline="\n")

    tracked_paths = {path for _, path in rows}
    physical_paths = [path for path in (root / "artifacts").rglob("*") if path.is_file()]
    candidate_paths = [
        path
        for search_root in (root / "experiments", root / "artifacts/milestones", root / "artifacts")
        for path in search_root.rglob("*")
        if path.is_file()
    ]
    candidates_by_size: dict[int, list[pathlib.Path]] = collections.defaultdict(list)
    for path in candidate_paths:
        relative = path.relative_to(root).as_posix()
        if relative in tracked_paths:
            candidates_by_size[path.stat().st_size].append(path)

    physical_rows = [
        "source_path\tbytes\tsha256\tclassification\tmatching_path\tproposed_destination"
    ]
    physical_totals = collections.Counter()
    for path in physical_paths:
        source = path.relative_to(root).as_posix()
        if source in tracked_paths:
            continue
        data = path.read_bytes()
        digest = sha256(data)
        matches = []
        for candidate in candidates_by_size.get(len(data), []):
            if candidate == path:
                continue
            if sha256(candidate.read_bytes()) == digest:
                matches.append(candidate.relative_to(root).as_posix())
        if "artifacts/milestones/" in source:
            classification = "milestone-payload-to-track"
        elif matches:
            classification = "byte-identical-copy-already-retained"
        else:
            classification = "unique-ignored-payload-to-preserve"
        physical_totals[classification] += 1
        physical_rows.append(
            "\t".join(
                (
                    source,
                    str(len(data)),
                    digest,
                    classification,
                    sorted(matches)[0] if matches else "",
                    proposed_destination(root, source),
                )
            )
        )
    physical_target = target.with_name("untracked-artifact-audit.tsv")
    physical_target.write_text(
        "\n".join(physical_rows) + "\n", encoding="utf-8", newline="\n"
    )
    print(f"audited_nonmilestone_artifacts={len(candidates)}")
    for classification, count in sorted(totals.items()):
        print(f"{classification}={count}")
    print(f"audit={target.relative_to(root).as_posix()}")
    print(f"audited_untracked_artifact_files={len(physical_rows) - 1}")
    for classification, count in sorted(physical_totals.items()):
        print(f"{classification}={count}")
    print(f"untracked_audit={physical_target.relative_to(root).as_posix()}")


if __name__ == "__main__":
    main()
