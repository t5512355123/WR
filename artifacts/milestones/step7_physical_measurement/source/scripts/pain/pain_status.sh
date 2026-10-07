#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
echo "host=$(hostname)"
echo "root=$ROOT"
echo "kernel=$(uname -sr)"
echo "quartus_bin=$QUARTUS_BIN"
if test -x "$QUARTUS_BIN/quartus_sh"; then
  "$QUARTUS_BIN/quartus_sh" --version 2>&1 | head -3
fi
git -C "$ROOT" status --short --branch
git -C "$ROOT" log -1 --oneline 2>/dev/null || true
command -v quartus_pgm >/dev/null 2>&1 && quartus_pgm -l 2>&1 || true
