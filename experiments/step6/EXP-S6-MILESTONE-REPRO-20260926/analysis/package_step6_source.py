#!/usr/bin/env python3
"""Package the historical Step 6 hardware source plus current dashboard overlay."""

from __future__ import annotations

import hashlib
import subprocess
import tempfile
from pathlib import Path


SOURCE_COMMIT = "74dc28862653d306e0450cf437ba6d3a230d979d"
OVERLAY_COMMIT = "3b3a8ec52668d0c60550451ef1780539f7c93fd7"
PINNED_SOURCE_GIT_VERSION = "master-diagnostic-baseline-20260817-1318-g74dc2886"
REPO_ROOT = Path(__file__).resolve().parents[4]
STEP4_SOURCE = REPO_ROOT / "artifacts" / "milestones" / "step4_softpll_startup" / "source"
SOURCE_ROOT = REPO_ROOT / "artifacts" / "milestones" / "step6_global_time" / "source"

HISTORICAL_TREES = (
    "quartus/jtag_runtime_diag",
    "generated/work_wrphy_full",
    "firmware",
    "vendor",
    "rtl/clock/si5340_controller",
    "scripts/jtag",
)
OVERLAY_PATHS = (
    "scripts/monitor/step1_6_dashboard.sh",
    "scripts/jtag/read_step1_6_dashboard.tcl",
    "scripts/tests/test_step1_6_dashboard.py",
)
OVERRIDE_OLD_COMMIT_PATHS = {"scripts/jtag/read_step1_6_dashboard.tcl"}
BUILD_WRAPPERS = (
    "scripts/build/build_master.sh",
    "scripts/build/build_slave.sh",
    "scripts/build/clean_build.sh",
    "scripts/program/program_master.sh",
    "scripts/program/program_slave.sh",
)

FIRMWARE_BUILD_WRAPPER = b"""#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname \"${BASH_SOURCE[0]}\")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROLE=${1:-}
case "$ROLE" in
  master|slave) ;;
  *) echo "usage: $0 master|slave" >&2; exit 2 ;;
esac

VERSION=$(tr -d '\\r\\n' < "$ROOT/SOURCE_GIT_VERSION.txt")
test -n "$VERSION"
export MAKEFLAGS="GIT_VER=$VERSION PPSI_VERSION=$VERSION"
bash "$ROOT/firmware/scripts/build_${ROLE}_firmware.sh"
"""


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
    return hashlib.sha1(f"blob {len(data)}\0".encode("ascii") + data).hexdigest()


def mapped_path(old: str) -> Path:
    mappings = (
        ("quartus/jtag_runtime_diag/", "quartus/"),
        ("generated/work_wrphy_full/", "quartus_generated/work_wrphy_full/"),
        ("firmware/", "firmware/"),
        ("vendor/", "vendor/"),
        ("rtl/clock/si5340_controller/", "quartus/si5340_controller/"),
        ("scripts/jtag/", "scripts/jtag/"),
        ("scripts/monitor/", "scripts/monitor/"),
        ("scripts/tests/", "scripts/tests/"),
    )
    for prefix, destination in mappings:
        if old.startswith(prefix):
            return Path(destination) / old[len(prefix) :]
    raise ValueError(f"Unmapped Step 6 source path: {old}")


def transform(old_path: str, data: bytes) -> tuple[bytes, str]:
    if old_path.endswith(".qsf"):
        replacements = (
            (b"../../vendor/", b"../vendor/"),
            (b"../../generated/", b"../quartus_generated/"),
            (b"../../rtl/clock/si5340_controller/", b"si5340_controller/"),
        )
        changed = False
        for before, after in replacements:
            if before in data:
                data = data.replace(before, after)
                changed = True
        if not changed:
            raise ValueError(f"No expected relocation paths found in {old_path}")
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


def tree_entries(commit: str, tree: str) -> list[tuple[str, str]]:
    raw = git("ls-tree", "-r", "-z", "--full-tree", commit, "--", tree)
    entries: list[tuple[str, str]] = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        metadata, encoded_path = record.split(b"\t", 1)
        mode, kind, oid = metadata.decode("ascii").split()
        path = encoded_path.decode("utf-8")
        if kind != "blob" or mode == "120000":
            raise ValueError(f"Unsupported non-regular source input: {path} ({mode})")
        if path not in OVERRIDE_OLD_COMMIT_PATHS:
            entries.append((path, oid))
    return entries


def batch_blob_data(entries: list[tuple[str, str]]):
    with tempfile.TemporaryFile() as queries, tempfile.TemporaryFile() as output:
        for _path, oid in entries:
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
        for path, expected_oid in entries:
            header = output.readline().rstrip(b"\n").split()
            if len(header) != 3 or header[0].decode("ascii") != expected_oid or header[1] != b"blob":
                raise ValueError(f"Unexpected Git blob response for {path}: {header!r}")
            size = int(header[2])
            data = output.read(size)
            if len(data) != size or output.read(1) != b"\n":
                raise ValueError(f"Truncated Git blob data for {path}")
            yield path, expected_oid, data


def write_file(relative: str, data: bytes) -> str:
    destination = SOURCE_ROOT / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


def write_manifest(rows: list[tuple[str, str, str, str, str, str]]) -> None:
    lines = ["origin_commit\torigin_path\tgit_blob\tpackage_path\ttransformation\tsha256"]
    lines.extend("\t".join(row) for row in rows)
    write_file("SOURCE_MANIFEST.tsv", ("\n".join(lines) + "\n").encode("utf-8"))


def make_package() -> None:
    if SOURCE_ROOT.exists() and any(SOURCE_ROOT.iterdir()):
        raise FileExistsError(f"Refusing to overwrite non-empty frozen source: {SOURCE_ROOT}")
    SOURCE_ROOT.mkdir(parents=True, exist_ok=True)
    if not STEP4_SOURCE.is_dir():
        raise FileNotFoundError(f"Validated Step 4 wrapper package is missing: {STEP4_SOURCE}")

    selected = [entry for tree in HISTORICAL_TREES for entry in tree_entries(SOURCE_COMMIT, tree)]
    if len(selected) < 3000:
        raise RuntimeError(f"Unexpectedly small Step 6 source selection: {len(selected)} files")

    manifest: list[tuple[str, str, str, str, str, str]] = []
    seen: set[str] = set()
    for old_path, oid, raw in batch_blob_data(selected):
        relative = mapped_path(old_path).as_posix()
        if relative in seen:
            raise ValueError(f"Duplicate source package path: {relative}")
        seen.add(relative)
        packaged, description = transform(old_path, raw)
        sha256 = write_file(relative, packaged)
        manifest.append((SOURCE_COMMIT, old_path, oid, relative, description, sha256))

    for old_path in OVERLAY_PATHS:
        oid, raw = historical_blob(OVERLAY_COMMIT, old_path)
        relative = mapped_path(old_path).as_posix()
        sha256 = write_file(relative, raw)
        manifest.append((OVERLAY_COMMIT, old_path, oid, relative, "read-only-dashboard-overlay", sha256))

    wrappers: list[tuple[str, str, str, str, str, str]] = []
    for relative in BUILD_WRAPPERS:
        origin = STEP4_SOURCE / relative
        if not origin.is_file():
            raise FileNotFoundError(f"Validated build/program wrapper is missing: {origin}")
        sha256 = write_file(relative, origin.read_bytes())
        wrappers.append(("step4-frozen-package", relative, "-", relative, "reproduction-tooling-byte-copy", sha256))

    version_sha = write_file("SOURCE_GIT_VERSION.txt", (PINNED_SOURCE_GIT_VERSION + "\n").encode("ascii"))
    wrappers.append(("step6-package-tooling", "historical-git-describe", "-", "SOURCE_GIT_VERSION.txt", "pins-firmware-version-metadata", version_sha))
    firmware_wrapper_sha = write_file("scripts/build/build_firmware.sh", FIRMWARE_BUILD_WRAPPER)
    wrappers.append(("step6-package-tooling", "package_step6_source.py", "-", "scripts/build/build_firmware.sh", "firmware-build-wrapper-pins-source-version", firmware_wrapper_sha))
    manifest.extend(wrappers)

    write_file("SOURCE_ORIGIN_COMMIT.txt", (SOURCE_COMMIT + "\n").encode("ascii"))
    write_file("DASHBOARD_OVERLAY_COMMIT.txt", (OVERLAY_COMMIT + "\n").encode("ascii"))
    write_file(
        ".gitignore",
        b"/build/\n/quartus/output_files_master_jtag/\n/quartus/output_files_slave_jtag/\n*.qws\n*.qdf\n*.rpt\n*.summary\n*.sof\n*.pof\n",
    )
    readme = f"""# Frozen Step 6 source candidate

Hardware and firmware source origin: `{SOURCE_COMMIT}`.

Read-only Step 1–6 dashboard overlay: `{OVERLAY_COMMIT}`. It consists only of
the host monitor, JTAG reader, and offline dashboard test; it does not change
RTL, firmware control, or the FPGA image.

Historical Quartus/generated/source paths are relocated into the current
canonical layout. The only source transformations are the QSF relative-path
and top-level firmware-MIF path relocations recorded per file in
`SOURCE_MANIFEST.tsv`. No functional source edits are made by this packager.

Build on Pain from this directory using Quartus Prime Standard 17.0 and the
configured RISC-V toolchain:

```sh
bash scripts/build/build_firmware.sh master
bash scripts/build/build_master.sh
bash scripts/build/build_firmware.sh slave
bash scripts/build/build_slave.sh
```

The resulting SOFs are `quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof`
and `quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`. Program the
reproduction images Slave then Master. `SOURCE_MANIFEST.tsv` ties every
historical blob and tooling overlay to its packaged SHA-256.

The candidate becomes a Step 6 milestone only after independent clean builds,
hardware programming, dashboard validation, the 300-second Step 5 lock check,
Step 6A same-PPS consistency, and Step 6B scheduled digital-trigger validation.
"""
    write_file("README.md", readme.encode("utf-8"))
    write_manifest(manifest)

    sums: list[str] = []
    for path in sorted(p for p in SOURCE_ROOT.rglob("*") if p.is_file() and p.name != "SHA256SUMS"):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        sums.append(f"{digest}  {path.relative_to(SOURCE_ROOT).as_posix()}")
    write_file("SHA256SUMS", ("\n".join(sums) + "\n").encode("ascii"))

    print(f"SOURCE_ROOT={SOURCE_ROOT}")
    print(f"SOURCE_ORIGIN_COMMIT={SOURCE_COMMIT}")
    print(f"DASHBOARD_OVERLAY_COMMIT={OVERLAY_COMMIT}")
    print(f"SOURCE_FILES={len(manifest)}")
    print(f"HISTORICAL_INPUT_FILES={len(selected)}")
    print(f"MANIFEST_ROWS={len(manifest)}")


if __name__ == "__main__":
    make_package()
