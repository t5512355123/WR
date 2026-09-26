#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROLE=${1:-}
case "$ROLE" in
  master|slave) ;;
  *) echo "usage: $0 master|slave" >&2; exit 2 ;;
esac

VERSION=$(tr -d '\r\n' < "$ROOT/SOURCE_GIT_VERSION.txt")
test -n "$VERSION"
export MAKEFLAGS="GIT_VER=$VERSION PPSI_VERSION=$VERSION"
bash "$ROOT/firmware/scripts/build_${ROLE}_firmware.sh"
