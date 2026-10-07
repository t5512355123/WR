#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
BRANCH=${1:-main}
git -C "$ROOT" fetch --prune origin
git -C "$ROOT" checkout "$BRANCH"
git -C "$ROOT" pull --ff-only origin "$BRANCH"
git -C "$ROOT" status --short --branch
