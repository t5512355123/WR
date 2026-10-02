#!/usr/bin/env bash
# This script is also copied into the final milestone as prepare_source.sh.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ "$(basename "${BASH_SOURCE[0]}")" = prepare_source.sh ]; then
  DEFAULT=$HERE
else
  DEFAULT=$(cd "$HERE/../.." && pwd)/artifacts/milestones/step6_global_time
fi
MILESTONE=$(cd "${1:-$DEFAULT}" && pwd)
cd "$MILESTONE"
test "$(basename "$MILESTONE")" = step6_global_time
sha256sum -c ARCHIVE_SHA256SUMS
sha256sum -c SHA256SUMS
ARCHIVE_ID=$(sha256sum source.tar.gz | awk '{print $1}')
if [ -L source ]; then
  echo 'Refusing a symlink source directory.' >&2; exit 2
fi
if [ ! -d source ]; then
  stage=$(mktemp -d "$MILESTONE/.source-extract.XXXXXX")
  tar -xzf source.tar.gz -C "$stage"
  printf '%s\n' "$ARCHIVE_ID" > "$stage/.archive-sha256"
  test ! -e source
  mv "$stage" source
fi
if [ "$(cat source/.archive-sha256 2>/dev/null || true)" != "$ARCHIVE_ID" ]; then
  echo 'Existing source is from a different archive; move it to a backup before preparing again.' >&2
  exit 2
fi
cd source
sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
sha256sum -c output/SHA256SUMS
# Original scripts require an independent Git file index for fresh compile
# provenance/export checks, never the moving parent repository's index.
if [ ! -d .git ]; then
  git init -q
fi
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  git add -f .
  git -c user.name='WR milestone snapshot' -c user.email='snapshot@localhost' \
    commit -q -m 'Independent qualified Step6 source snapshot'
fi
test "$(git rev-parse --show-toplevel)" = "$PWD"
printf 'STEP6_SOURCE_READY=%s\n' "$PWD"
