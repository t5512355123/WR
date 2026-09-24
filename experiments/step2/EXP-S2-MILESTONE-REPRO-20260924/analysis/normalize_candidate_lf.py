#!/usr/bin/env python3
"""Normalize auto-detected text files in the frozen candidate to LF only."""

from __future__ import annotations

import pathlib
import sys


BINARY_SUFFIXES = {
    ".a",
    ".bin",
    ".elf",
    ".mif",
    ".o",
    ".pof",
    ".so",
    ".sof",
}


def main() -> int:
    root = pathlib.Path(sys.argv[1]).resolve()
    changed = 0
    bytes_removed = 0
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() in BINARY_SUFFIXES:
            continue
        data = path.read_bytes()
        if b"\0" in data or b"\r\n" not in data:
            continue
        normalized = data.replace(b"\r\n", b"\n")
        bytes_removed += len(data) - len(normalized)
        path.write_bytes(normalized)
        changed += 1
    print(f"LINE_ENDING_NORMALIZATION files_changed={changed} cr_bytes_removed={bytes_removed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
