#!/usr/bin/env python3
"""Create and verify the standalone Step 5 historical source candidate."""

from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path


SOURCE_COMMIT = "26e138fdc0bfc8426704b397141d563cf4d580a2"
OBSERVER_COMMIT = "47d9a394e53eda31476c82de2a85ad82573494ed"
PINNED_SOURCE_GIT_VERSION = "master-diagnostic-baseline-20260817-1175-g26e138fd"
REPO_ROOT = Path(__file__).resolve().parents[4]
EXPERIMENT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = EXPERIMENT / "source"
STEP4_SOURCE = REPO_ROOT / "artifacts" / "milestones" / "step4_softpll_startup" / "source"

HISTORICAL_TREES = (
    "quartus/jtag_runtime_diag",
    "generated/work_wrphy_full",
    "firmware",
    "vendor",
    "rtl/clock/si5340_controller",
    "scripts/jtag",
    "scripts/experiment/step5_f4l_main_phase_drift_integrator.py",
    "scripts/tests/test_step5_f4l_threshold20_owner.py",
    "scripts/tests/test_step5_threshold20.py",
)
OBSERVER_OVERLAYS = (
    "scripts/jtag/read_step5_main_frequency_prelock_observability.tcl",
    "scripts/tests/test_step5_f4l.py",
)
BUILD_WRAPPERS = (
    "scripts/build/build_master.sh",
    "scripts/build/build_slave.sh",
    "scripts/build/clean_build.sh",
    "scripts/program/program_master.sh",
    "scripts/program/program_slave.sh",
)
OVERRIDE_OLD_COMMIT_PATHS = set(OBSERVER_OVERLAYS)
FIRMWARE_BUILD_WRAPPER = b"""#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROLE=${1:-}
case "$ROLE" in
  master|slave) ;;
  *) echo "usage: $0 master|slave" >&2; exit 2 ;;
esac

VERSION=$(tr -d '\\r\\n' < "$ROOT/SOURCE_GIT_VERSION.txt")
test -n "$VERSION"
# The source package can live inside a different repository checkout. Pin the
# two upstream Git-description variables so generated firmware reflects the
# frozen source origin, not the parent checkout's current HEAD.
export MAKEFLAGS="GIT_VER=$VERSION PPSI_VERSION=$VERSION"
bash "$ROOT/firmware/scripts/build_${ROLE}_firmware.sh"
"""
GENERATED_TOOLING = {
    "SOURCE_GIT_VERSION.txt": "frozen-source-git-description",
    "scripts/build/build_firmware.sh": "build-wrapper-pins-firmware-metadata",
}


def git(*args: str, data: bytes | None = None) -> bytes:
    return subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        input=data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    ).stdout


def historical_blob(commit: str, path: str) -> tuple[str, bytes]:
    oid = git("rev-parse", f"{commit}:{path}").decode("ascii").strip()
    return oid, git("cat-file", "blob", oid)


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def mapped_path(old: str) -> Path:
    mappings = (
        ("quartus/jtag_runtime_diag/", "quartus/"),
        ("generated/work_wrphy_full/", "quartus_generated/work_wrphy_full/"),
        ("firmware/", "firmware/"),
        ("vendor/", "vendor/"),
        ("rtl/clock/si5340_controller/", "quartus/si5340_controller/"),
        ("scripts/jtag/", "scripts/jtag/"),
        ("scripts/experiment/", "scripts/experiment/"),
        ("scripts/tests/", "scripts/tests/"),
    )
    for prefix, destination in mappings:
        if old.startswith(prefix):
            return Path(destination) / old[len(prefix) :]
    raise ValueError(f"Unmapped historical source path: {old}")


def transform(old_path: str, data: bytes) -> tuple[bytes, str]:
    if old_path.endswith(".qsf"):
        replacements = (
            (b"../../vendor/", b"../vendor/"),
            (b"../../generated/", b"../quartus_generated/"),
            (b"../../rtl/clock/si5340_controller/", b"si5340_controller/"),
        )
        for before, after in replacements:
            if before not in data:
                raise ValueError(f"Expected path {before!r} not found in {old_path}")
            data = data.replace(before, after)
        return data, "quartus-relative-path-relocation-only"
    if old_path in {
        "quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd",
        "quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd",
    }:
        before = b"../../build/firmware/"
        if before not in data:
            raise ValueError(f"Expected firmware MIF path not found in {old_path}")
        return data.replace(before, b"../build/firmware/"), "firmware-mif-path-relocation-only"
    return data, "byte-identical"


def tree_entries(commit: str, tree: str) -> list[tuple[str, str, str]]:
    raw = git("ls-tree", "-r", "-z", "--full-tree", commit, "--", tree)
    entries: list[tuple[str, str, str]] = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        metadata, encoded_path = record.split(b"\t", 1)
        mode, kind, oid = metadata.decode("ascii").split()
        old_path = encoded_path.decode("utf-8")
        if kind != "blob" or mode == "120000":
            raise ValueError(f"Non-regular historical input is unsupported: {old_path} ({mode})")
        if old_path in OVERRIDE_OLD_COMMIT_PATHS:
            continue
        entries.append((commit, old_path, oid))
    return entries


def batch_blob_data(entries: list[tuple[str, str, str]]):
    """Yield historical blobs from one streamed `git cat-file --batch` run."""
    with tempfile.TemporaryFile() as queries, tempfile.TemporaryFile() as output:
        for _commit, _path, oid in entries:
            queries.write(oid.encode("ascii") + b"\n")
        queries.seek(0)
        completed = subprocess.run(
            ["git", "cat-file", "--batch"],
            cwd=REPO_ROOT,
            stdin=queries,
            stdout=output,
            stderr=subprocess.PIPE,
            check=False,
        )
        if completed.returncode:
            raise RuntimeError(completed.stderr.decode("utf-8", errors="replace"))
        output.seek(0)
        for _commit, path, expected_oid in entries:
            header = output.readline().rstrip(b"\n").split()
            if len(header) != 3 or header[0].decode("ascii") != expected_oid or header[1] != b"blob":
                raise ValueError(f"Unexpected cat-file batch response for {path}: {header!r}")
            size = int(header[2])
            data = output.read(size)
            if len(data) != size or output.read(1) != b"\n":
                raise ValueError(f"Truncated cat-file batch response for {path}")
            yield path, expected_oid, data


def write_file(relative: str, data: bytes) -> str:
    destination = SOURCE_ROOT / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


def make_package() -> None:
    if SOURCE_ROOT.exists():
        if not SOURCE_ROOT.is_dir() or any(SOURCE_ROOT.iterdir()):
            raise FileExistsError(f"Refusing to overwrite existing frozen source: {SOURCE_ROOT}")
    else:
        SOURCE_ROOT.mkdir(parents=True)
    if not STEP4_SOURCE.is_dir():
        raise FileNotFoundError(f"Validated Step 4 wrapper source is missing: {STEP4_SOURCE}")

    manifest: list[tuple[str, str, str, str, str, str]] = []
    selected = [entry for tree in HISTORICAL_TREES for entry in tree_entries(SOURCE_COMMIT, tree)]
    if len(selected) < 3000:
        raise RuntimeError(f"Unexpectedly small historical source selection: {len(selected)} files")

    seen: set[str] = set()
    for old_path, oid, raw in batch_blob_data(selected):
        commit = SOURCE_COMMIT
        relative = mapped_path(old_path).as_posix()
        if relative in seen:
            raise ValueError(f"Duplicate mapped package path: {relative}")
        seen.add(relative)
        packaged, description = transform(old_path, raw)
        sha256 = write_file(relative, packaged)
        manifest.append((commit, old_path, oid, relative, description, sha256))

    for old_path in OBSERVER_OVERLAYS:
        oid, raw = historical_blob(OBSERVER_COMMIT, old_path)
        relative = mapped_path(old_path).as_posix()
        sha256 = write_file(relative, raw)
        manifest.append((OBSERVER_COMMIT, old_path, oid, relative, "observer-only-contract-overlay", sha256))

    wrapper_rows: list[tuple[str, str, str, str, str, str]] = []
    for relative in BUILD_WRAPPERS:
        original = STEP4_SOURCE / relative
        if not original.is_file():
            raise FileNotFoundError(f"Step 4 build/program wrapper missing: {original}")
        raw = original.read_bytes()
        sha256 = write_file(relative, raw)
        wrapper_rows.append(("step4-frozen-package", relative, "-", relative, "reproduction-tooling-byte-copy", sha256))

    version_sha = write_file("SOURCE_GIT_VERSION.txt", (PINNED_SOURCE_GIT_VERSION + "\n").encode("ascii"))
    wrapper_rows.append(("step5-reproduction-tooling", "historical-source-git-description", "-", "SOURCE_GIT_VERSION.txt", GENERATED_TOOLING["SOURCE_GIT_VERSION.txt"], version_sha))
    wrapper_sha = write_file("scripts/build/build_firmware.sh", FIRMWARE_BUILD_WRAPPER)
    wrapper_rows.append(("step5-reproduction-tooling", "analysis/package_step5_source.py", "-", "scripts/build/build_firmware.sh", GENERATED_TOOLING["scripts/build/build_firmware.sh"], wrapper_sha))

    write_file("SOURCE_ORIGIN_COMMIT.txt", (SOURCE_COMMIT + "\n").encode("ascii"))
    write_file("OBSERVER_CONTRACT_COMMIT.txt", (OBSERVER_COMMIT + "\n").encode("ascii"))
    write_file(
        ".gitignore",
        b"/build/\n/quartus/output_files_master_jtag/\n/quartus/output_files_slave_jtag/\n*.qws\n*.qdf\n*.rpt\n*.summary\n*.sof\n*.pof\n",
    )
    readme = f"""# Frozen Step 5 reproduction source candidate

This standalone source tree reproduces historical Step 5 source commit
`{SOURCE_COMMIT}`. The only later source overlay is the read-only F4L observer
and matching offline test from `{OBSERVER_COMMIT}`, which corrected the
300-second observer contract without changing firmware or RTL.

The old repository paths were relocated into the current layout. Only QSF and
top-level VHDL relative paths were changed in historical source. A separate
build wrapper pins the firmware's embedded Git-description metadata to the
frozen source commit; it does not modify firmware or RTL. `SOURCE_MANIFEST.tsv`
records each historical Git blob, package path, transformation, and packaged
SHA-256.
`../analysis/package_step5_source.py` verifies the source identity.

The JTAG build/program wrappers were copied byte-for-byte from the validated
Step 4 frozen package and are explicitly tooling, not Step 5 historical source.
Use `scripts/build/build_firmware.sh master|slave` to retain the historical
source-version marker during a standalone firmware build. Build products are
generated under this package's ignored `build/` and
`quartus/output_files_*_jtag/` directories.

This is a candidate only. It becomes a formal Step 5 milestone only after
clean Master/Slave builds, programming both DE5a boards, and the required
continuous 300-second four-lock runtime validation.
""".encode("utf-8")
    write_file("README.md", readme)

    header = "origin_commit\torigin_path	git_blob	package_path	transformation	sha256\n"
    rows = manifest + wrapper_rows
    rows.sort(key=lambda row: (row[3], row[0]))
    write_file(
        "SOURCE_MANIFEST.tsv",
        (header + "".join("\t".join(row) + "\n" for row in rows)).encode("utf-8"),
    )
    write_hashes()


def reverse_transform(origin_path: str, data: bytes) -> bytes:
    if origin_path.endswith(".qsf"):
        data = data.replace(b"../vendor/", b"../../vendor/")
        data = data.replace(b"../quartus_generated/", b"../../generated/")
        data = data.replace(b"si5340_controller/", b"../../rtl/clock/si5340_controller/")
    elif origin_path in {
        "quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd",
        "quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd",
    }:
        data = data.replace(b"../build/firmware/", b"../../build/firmware/")
    return data


def read_manifest() -> list[dict[str, str]]:
    lines = (SOURCE_ROOT / "SOURCE_MANIFEST.tsv").read_text(encoding="utf-8").splitlines()
    header = lines[0].split("\t")
    return [dict(zip(header, line.split("\t"), strict=True)) for line in lines[1:]]


def refresh_generated_tooling_rows() -> None:
    manifest_path = SOURCE_ROOT / "SOURCE_MANIFEST.tsv"
    rows = [row for row in read_manifest() if row["package_path"] not in GENERATED_TOOLING]
    for package_path, transformation in GENERATED_TOOLING.items():
        data = (SOURCE_ROOT / package_path).read_bytes()
        rows.append(
            {
                "origin_commit": "step5-reproduction-tooling",
                "origin_path": "historical-source-git-description" if package_path == "SOURCE_GIT_VERSION.txt" else "analysis/package_step5_source.py",
                "git_blob": "-",
                "package_path": package_path,
                "transformation": transformation,
                "sha256": hashlib.sha256(data).hexdigest(),
            }
        )
    rows.sort(key=lambda row: (row["package_path"], row["origin_commit"]))
    header = "origin_commit\torigin_path\tgit_blob\tpackage_path\ttransformation\tsha256\n"
    content = header + "".join(
        "\t".join(row[key] for key in ("origin_commit", "origin_path", "git_blob", "package_path", "transformation", "sha256")) + "\n"
        for row in rows
    )
    manifest_path.write_text(content, encoding="utf-8", newline="\n")


def is_generated_path(path: Path) -> bool:
    relative = path.relative_to(SOURCE_ROOT)
    parts = relative.parts
    if "__pycache__" in parts or relative.suffix == ".pyc":
        return True
    if parts and parts[0] == "build":
        return True
    if any(part in {"db", "incremental_db", "output_files", "simulation"} for part in parts):
        return True
    if any(part.startswith("output_files_") for part in parts):
        return True
    return relative.suffix in {".rpt", ".summary", ".qws", ".qdf", ".sof", ".pof", ".jdi"}


def verify_package() -> int:
    failures: list[str] = []
    version_marker = SOURCE_ROOT / "SOURCE_GIT_VERSION.txt"
    firmware_wrapper = SOURCE_ROOT / "scripts" / "build" / "build_firmware.sh"
    historical_description = git("describe", "--always", SOURCE_COMMIT).decode("ascii").strip()
    if historical_description != PINNED_SOURCE_GIT_VERSION:
        failures.append(f"pinned Git description mismatch: {historical_description}")
    if not version_marker.is_file() or version_marker.read_text(encoding="ascii").strip() != PINNED_SOURCE_GIT_VERSION:
        failures.append("frozen firmware Git-description marker mismatch")
    if not firmware_wrapper.is_file() or firmware_wrapper.read_bytes() != FIRMWARE_BUILD_WRAPPER:
        failures.append("frozen firmware build wrapper differs from the audited recipe")
    rows = read_manifest()
    historical_checked = 0
    tooling_checked = 0
    for row in rows:
        path = SOURCE_ROOT / row["package_path"]
        if not path.is_file():
            failures.append(f"missing package file: {row['package_path']}")
            continue
        data = path.read_bytes()
        actual_sha = hashlib.sha256(data).hexdigest()
        if actual_sha != row["sha256"]:
            failures.append(f"SHA256 mismatch: {row['package_path']}")
        if row["git_blob"] == "-":
            tooling_checked += 1
            continue
        normalized = reverse_transform(row["origin_path"], data)
        actual_blob = git_blob_sha(normalized)
        if actual_blob != row["git_blob"]:
            failures.append(f"Git blob mismatch: {row['origin_path']} ({actual_blob})")
        historical_checked += 1

    sums_path = SOURCE_ROOT / "SHA256SUMS"
    if sums_path.exists():
        expected: dict[str, str] = {}
        for line in sums_path.read_text(encoding="utf-8").splitlines():
            digest, relative = line.split("  ", 1)
            expected[relative] = digest
        actual_files = {
            path.relative_to(SOURCE_ROOT).as_posix()
            for path in SOURCE_ROOT.rglob("*")
            if path.is_file() and path.name != "SHA256SUMS" and not is_generated_path(path)
        }
        if set(expected) != actual_files:
            failures.append("SHA256SUMS file-set mismatch")
        for relative, digest in expected.items():
            actual = hashlib.sha256((SOURCE_ROOT / relative).read_bytes()).hexdigest()
            if actual != digest:
                failures.append(f"SHA256SUMS mismatch: {relative}")
    else:
        failures.append("missing source SHA256SUMS")

    print(f"SOURCE_COMMIT={SOURCE_COMMIT}")
    print(f"OBSERVER_CONTRACT_COMMIT={OBSERVER_COMMIT}")
    print(f"HISTORICAL_GIT_BLOBS_VERIFIED={historical_checked}")
    print(f"REPRODUCTION_TOOL_WRAPPERS_VERIFIED={tooling_checked}")
    print(f"SOURCE_IDENTITY={'PASS' if not failures else 'FAIL'}")
    for failure in failures:
        print(f"FAIL: {failure}")
    return 1 if failures else 0


def write_hashes() -> None:
    rows: list[str] = []
    for path in sorted(SOURCE_ROOT.rglob("*")):
        if not path.is_file() or path.name == "SHA256SUMS" or is_generated_path(path):
            continue
        relative = path.relative_to(SOURCE_ROOT).as_posix()
        rows.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {relative}")
    (SOURCE_ROOT / "SHA256SUMS").write_text("\n".join(rows) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--verify":
        return verify_package()
    if len(sys.argv) > 1 and sys.argv[1] == "--refresh-hashes":
        refresh_generated_tooling_rows()
        write_hashes()
        return verify_package()
    make_package()
    return verify_package()


if __name__ == "__main__":
    sys.exit(main())
