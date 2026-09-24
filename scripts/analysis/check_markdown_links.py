#!/usr/bin/env python3
"""Audit relative Markdown links in project-authored Markdown files."""

from __future__ import annotations

import posixpath
import re
import argparse
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


REPO_ROOT = Path(__file__).resolve().parents[2]
INLINE_LINK = re.compile(r"!?\[[^\]]*\]\((.*?)\)")
REFERENCE = re.compile(r"^\s*\[(?!\^)[^\]]+\]:\s*(\S+|<[^>]+>)")
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
WINDOWS_ABSOLUTE = re.compile(r"^[A-Za-z]:[/\\]")


def markdown_targets(text: str):
    """Yield (line number, raw target) for inline links and definitions."""
    fence_char = None
    fence_len = 0
    for number, line in enumerate(text.splitlines(), 1):
        fence = FENCE.match(line)
        if fence:
            marker = fence.group(1)
            if fence_char is None:
                fence_char, fence_len = marker[0], len(marker)
            elif marker[0] == fence_char and len(marker) >= fence_len:
                fence_char, fence_len = None, 0
            continue
        if fence_char is not None:
            continue

        definition = REFERENCE.match(line)
        if definition:
            yield number, definition.group(1)

        # Inline code is not a rendered Markdown link.
        visible = re.sub(r"(`+).*?\1", "", line)
        for match in INLINE_LINK.finditer(visible):
            spec = match.group(1).strip()
            if spec.startswith("<"):
                end = spec.find(">")
                target = spec[1:end] if end >= 0 else spec
            else:
                target = re.split(r"\s+", spec, maxsplit=1)[0]
            if target:
                yield number, target


def normalized_local_path(markdown_path: str, target: str):
    """Return a normalized repository-relative path, or None for non-local links."""
    target = target.strip()
    if len(target) >= 2 and target[0] == "<" and target[-1] == ">":
        target = target[1:-1]
    if WINDOWS_ABSOLUTE.match(target.replace("\\", "/")):
        return None
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc or target.startswith("/"):
        return None
    raw_path = unquote(parsed.path).replace("\\", "/")
    if not raw_path:
        return None
    normalized = posixpath.normpath(posixpath.join(posixpath.dirname(markdown_path), raw_path))
    if normalized == ".":
        return "."
    return normalized


def repository_paths():
    paths = set()
    for command in (
        ["git", "ls-files", "-z", "--cached"],
        ["git", "ls-files", "-z", "--others", "--exclude-standard"],
    ):
        result = subprocess.run(command, cwd=REPO_ROOT, check=True, stdout=subprocess.PIPE)
        paths.update(item.decode("utf-8") for item in result.stdout.split(b"\0") if item)
    markdown = sorted(path for path in paths if path.lower().endswith(".md"))
    return markdown, paths


def is_vendored_markdown(path: str) -> bool:
    return path.startswith("vendor/") or "/vendor/" in f"/{path}"


def path_exists_case_sensitive(target: str, repo_paths: set[str]) -> bool:
    if target == "." or target in repo_paths:
        return True
    prefix = target.rstrip("/") + "/"
    return any(path.startswith(prefix) for path in repo_paths)


def audit(paths: list[str], repo_paths: set[str]):
    broken = []
    checked = 0
    for markdown_path in paths:
        file_path = REPO_ROOT / Path(markdown_path)
        if not file_path.is_file():
            continue
        try:
            text = file_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for line, raw_target in markdown_targets(text):
            target = normalized_local_path(markdown_path, raw_target)
            if target is None:
                continue
            checked += 1
            if target.startswith("../") or not path_exists_case_sensitive(target, repo_paths):
                broken.append((markdown_path, line, raw_target, target))
    return checked, broken


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--include-vendor-markdown",
        action="store_true",
        help="also audit upstream Markdown copied into vendor/source snapshots",
    )
    args = parser.parse_args()
    all_paths, repo_paths = repository_paths()
    vendor_paths = [path for path in all_paths if is_vendored_markdown(path)]
    paths = all_paths if args.include_vendor_markdown else [
        path for path in all_paths if not is_vendored_markdown(path)
    ]
    checked, broken = audit(paths, repo_paths)
    print(f"MARKDOWN_FILES_CHECKED={len(paths)}")
    print(f"VENDORED_MARKDOWN_SKIPPED={0 if args.include_vendor_markdown else len(vendor_paths)}")
    print(f"LOCAL_LINKS_CHECKED={checked}")
    print(f"BROKEN_LOCAL_LINKS={len(broken)}")
    for source, line, raw, normalized in broken:
        print(f"BROKEN {source}:{line}: {raw} -> {normalized}")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
