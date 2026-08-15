#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
PROJECT_DIR="$ROOT/quartus/rs422_uart_diag"
PROJECT=DE5a_wr_master_rs422
MIF="$ROOT/build/firmware/master/wrc.mif"
LOG="$ROOT/build/quartus_master_compile.log"

test -x "$QUARTUS_BIN/quartus_sh"
test -f "$PROJECT_DIR/$PROJECT.qpf"
test -f "$MIF" || { echo "BUILD FAIL: missing $MIF" >&2; exit 2; }
mkdir -p "$ROOT/build"
rm -f "$LOG"
(
  echo "=== BUILD IDENTITY ==="
  date -Is
  echo "HOST=$(hostname)"
  echo "ROOT=$ROOT"
  echo "GIT_COMMIT=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo uncommitted)"
  echo "GIT_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo unknown)"
  "$QUARTUS_BIN/quartus_sh" --version 2>&1 | head -3
  sha256sum "$PROJECT_DIR/$PROJECT.qsf" "$PROJECT_DIR/$PROJECT.sdc" "$MIF"
  echo "=== QUARTUS COMPILE ==="
  cd "$PROJECT_DIR"
  "$QUARTUS_BIN/quartus_sh" --flow compile "$PROJECT.qpf"
) > "$LOG" 2>&1 || { tail -80 "$LOG"; exit 1; }

grep -q 'Full Compilation was successful' "$LOG"
! grep -qi 'Can.t find Memory Initialization File' "$LOG"
cp "$LOG" "$ROOT/build/build_master.log"
cat > "$ROOT/build/build_info_master.txt" <<EOF
DATE=$(date -Is)
HOST=$(hostname)
GIT_COMMIT=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo uncommitted)
GIT_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo unknown)
QUARTUS_BIN=$QUARTUS_BIN
PROJECT=$PROJECT
QSF_SHA256=$(sha256sum "$PROJECT_DIR/$PROJECT.qsf" | awk '{print $1}')
SDC_SHA256=$(sha256sum "$PROJECT_DIR/$PROJECT.sdc" | awk '{print $1}')
MIF_SHA256=$(sha256sum "$MIF" | awk '{print $1}')
COMPILE_RESULT=Full Compilation was successful
EOF
echo "Master Quartus build passed: $PROJECT_DIR/output_files_master_rs422/$PROJECT.sof"
