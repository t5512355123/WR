#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
PROJECT_DIR="$ROOT/quartus/jtag_runtime_diag"
PROJECT=DE5a_wr_master_jtag
MIF="$ROOT/build/firmware/master/wrc.mif"
LOG="$ROOT/build/quartus_jtag_master_compile.log"
SOF="$PROJECT_DIR/output_files_master_jtag/$PROJECT.sof"
FIT_SUMMARY="$PROJECT_DIR/output_files_master_jtag/$PROJECT.fit.summary"
STA_RPT="$PROJECT_DIR/output_files_master_jtag/$PROJECT.sta.rpt"

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
test -s "$SOF"
test -s "$FIT_SUMMARY"
test -s "$STA_RPT"
cp "$LOG" "$ROOT/build/build_jtag_master.log"
QUARTUS_VERSION=$("$QUARTUS_BIN/quartus_sh" --version 2>&1 | sed -n 's/.*Version /Version /p' | head -1)
SOF_SHA256=$(sha256sum "$SOF" | awk '{print $1}')
FITTER_STATUS=$(grep -m1 'Fitter Status' "$FIT_SUMMARY" | sed 's/^ *//')
WORST_SETUP_SLACK_NS=$(grep -m1 'Worst-case setup slack is' "$STA_RPT" | awk '{print $NF}')
WORST_HOLD_SLACK_NS=$(grep -m1 'Worst-case hold slack is' "$STA_RPT" | awk '{print $NF}')
WORST_RECOVERY_SLACK_NS=$(grep -m1 'Worst-case recovery slack is' "$STA_RPT" | awk '{print $NF}')
WORST_REMOVAL_SLACK_NS=$(grep -m1 'Worst-case removal slack is' "$STA_RPT" | awk '{print $NF}')
TIMING_CLOSED=$(awk '/Worst-case .* slack is/{if ($NF + 0 < 0) bad=1} END{print bad ? "NO" : "YES"}' "$STA_RPT")
UNCONSTRAINED_CLOCKS=$(awk -F';' '/Unconstrained Clocks/{gsub(/[[:space:]]/,"",$3); print $3; exit}' "$STA_RPT")
UNCONSTRAINED_INPUT_PATHS=$(awk -F';' '/Unconstrained Input Port Paths/{gsub(/[[:space:]]/,"",$3); print $3; exit}' "$STA_RPT")
UNCONSTRAINED_OUTPUT_PATHS=$(awk -F';' '/Unconstrained Output Port Paths/{gsub(/[[:space:]]/,"",$3); print $3; exit}' "$STA_RPT")
cat > "$ROOT/build/build_info_jtag_master.txt" <<EOF
DATE=$(date -Is)
HOST=$(hostname)
GIT_COMMIT=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo uncommitted)
GIT_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo unknown)
QUARTUS_BIN=$QUARTUS_BIN
QUARTUS_VERSION=$QUARTUS_VERSION
PROJECT=$PROJECT
TOP_LEVEL_ENTITY=$PROJECT
QSF_SHA256=$(sha256sum "$PROJECT_DIR/$PROJECT.qsf" | awk '{print $1}')
SDC_SHA256=$(sha256sum "$PROJECT_DIR/$PROJECT.sdc" | awk '{print $1}')
MIF_SHA256=$(sha256sum "$MIF" | awk '{print $1}')
SOF_SHA256=$SOF_SHA256
FITTER_STATUS=$FITTER_STATUS
TIMING_CLOSED=$TIMING_CLOSED
WORST_SETUP_SLACK_NS=$WORST_SETUP_SLACK_NS
WORST_HOLD_SLACK_NS=$WORST_HOLD_SLACK_NS
WORST_RECOVERY_SLACK_NS=$WORST_RECOVERY_SLACK_NS
WORST_REMOVAL_SLACK_NS=$WORST_REMOVAL_SLACK_NS
UNCONSTRAINED_CLOCKS=$UNCONSTRAINED_CLOCKS
UNCONSTRAINED_INPUT_PATHS=$UNCONSTRAINED_INPUT_PATHS
UNCONSTRAINED_OUTPUT_PATHS=$UNCONSTRAINED_OUTPUT_PATHS
COMPILE_RESULT=Full Compilation was successful
EOF
echo "Master Quartus build passed: $SOF (timing_closed=$TIMING_CLOSED)"
