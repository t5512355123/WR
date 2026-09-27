#!/usr/bin/env python3
"""Write/check SHA256SUMS for this experiment's plan, analysis, report, and raw files."""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "SHA256SUMS"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_manifest() -> str:
    paths = sorted(
        path
        for path in ROOT.rglob("*")
        if path.is_file() and path != MANIFEST and not path.is_symlink()
    )
    return "".join(
        f"{sha256(path)}  {path.relative_to(ROOT).as_posix()}\n" for path in paths
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = expected_manifest()
    if args.check:
        actual = MANIFEST.read_text(encoding="utf-8") if MANIFEST.exists() else ""
        if actual != expected:
            print("EXPERIMENT_SHA256SUMS=FAIL")
            return 1
        print("EXPERIMENT_SHA256SUMS=PASS")
        return 0
    MANIFEST.write_text(expected, encoding="utf-8", newline="\n")
    print(f"WROTE {MANIFEST.relative_to(ROOT).as_posix()} ({expected.count(chr(10))} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
