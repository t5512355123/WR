#!/usr/bin/env bash
# Git does not store write-protection. Apply it only to this exact Step7 package.
set -euo pipefail
MILESTONE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO=$(git -C "$MILESTONE" rev-parse --show-toplevel)
REPO=$(cd "$REPO" && pwd -P)
test "$MILESTONE" = "$REPO/artifacts/milestones/step7_physical_measurement"
test ! -L "$REPO/artifacts" && test ! -L "$REPO/artifacts/milestones"
test ! -L "$REPO/artifacts/milestones/step7_physical_measurement"
test -s "$MILESTONE/source.tar.gz"
test -s "$MILESTONE/master.sof" && test -s "$MILESTONE/slave.sof"
test -s "$MILESTONE/PACKAGE.json"
test -z "$(find "$MILESTONE" -type l -print -quit)"
chmod -R a-w -- "$MILESTONE"
test -z "$(find "$MILESTONE" -perm /222 -print -quit)"
printf 'STEP7_READ_ONLY=%s\n' "$MILESTONE"
