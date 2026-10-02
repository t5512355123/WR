#!/usr/bin/env bash
set -euo pipefail
MILESTONE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$MILESTONE"
sha256sum -c CURRENT_ARCHIVE_SHA256SUMS
if [ ! -d current ]; then
  stage=$(mktemp -d "$MILESTONE/.current-extract.XXXXXX")
  tar -xzf current-source.tar.gz -C "$stage"
  mv "$stage" "$MILESTONE/current"
fi
cd current
sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
sha256sum -c output/SHA256SUMS
# The unchanged build/export scripts need a local Git identity and file index.
# This is an independent frozen repository, never the moving parent checkout.
if [ ! -d .git ]; then
  git init -q
  git add -f .
  git -c user.name='WR milestone snapshot' -c user.email='snapshot@localhost' \
    commit -q -m 'Frozen Step6 TIME_VALID snapshot from 1c9aea5b'
fi
printf 'STEP6_CURRENT_READY=%s\n' "$PWD"
