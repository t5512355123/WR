#!/usr/bin/env python3
"""Create a deterministic SHA256SUMS for a frozen source candidate."""

from __future__ import annotations

import hashlib
import pathlib
import sys


EXCLUDED_DIRS = {
    "db",
    "incremental_db",
    "output_files",
    "simulation",
    "__pycache__",
}
EXCLUDED_SUFFIXES = {
    ".pyc",
    ".qdb",
    ".qws",
    ".qmsg",
    ".srf",
    ".done",
    ".jdi",
    ".smsg",
    ".rpt",
    ".summary",
    ".log",
}


def included(path: pathlib.Path, root: pathlib.Path) -> bool:
    relative = path.relative_to(root)
    parts = relative.parts
    if relative.as_posix() == "vendor/wr-cores/ip_cores/etherbone-core/api/labview/LabVIEW/LV2009/lvEtherbone/test/myEtherbone.log":
        return True
    if not parts or parts[0] == "build":
        return False
    if any(part in EXCLUDED_DIRS or part.startswith("output_files_") for part in parts):
        return False
    if path.name == "SHA256SUMS" or path.suffix.lower() in EXCLUDED_SUFFIXES:
        return False
    return True


def main() -> int:
    root = pathlib.Path(sys.argv[1]).resolve()
    manifest = root / "SHA256SUMS"
    lines: list[str] = []
    files = sorted(path for path in root.rglob("*") if path.is_file())
    excluded = [path for path in files if path.name != "SHA256SUMS" and not included(path, root)]
    for path in files:
        if not path.is_file() or not included(path, root):
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        relative = path.relative_to(root).as_posix()
        lines.append(f"{digest}  {relative}")
    manifest.write_text("\n".join(lines) + "\n", encoding="ascii", newline="\n")
    print(f"SOURCE_MANIFEST entries={len(lines)} sha256={hashlib.sha256(manifest.read_bytes()).hexdigest()}")
    for path in excluded:
        print(f"SOURCE_MANIFEST_EXCLUDED {path.relative_to(root).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
