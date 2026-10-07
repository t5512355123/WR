#!/usr/bin/env bash
# Sealed top-level evidence stays read-only; published source/ is a build workspace.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
for name in step6_global_time step7_physical_measurement; do
  MILESTONE="$ROOT/artifacts/milestones/$name"
  SOURCE="$MILESTONE/source"
  test ! -L "$MILESTONE" && test ! -L "$SOURCE"
  test "$(cd "$MILESTONE" && pwd -P)" = "$MILESTONE"
  test "$(cd "$SOURCE" && pwd -P)" = "$SOURCE"
  test ! -e "$SOURCE/.git"
  test -z "$(find "$SOURCE" -type l -print -quit)"
  # Never change protected archive contents or executable bits.
  find "$MILESTONE" -maxdepth 1 -type f -exec chmod a-w -- {} +
  find "$SOURCE" -type d -exec chmod u+w -- {} +
  find "$SOURCE" -type f -exec chmod u+w -- {} +
  chmod a-w -- "$MILESTONE"
  printf 'SEALED_EVIDENCE_READ_ONLY=%s SOURCE_BUILD_WRITABLE=%s\n' "$MILESTONE" "$SOURCE"
done
