#!/usr/bin/env bash
# Read-only late-tail observation on the currently programmed Step6B V2
# session. This runner must never program, reset, restart PTP, or write a
# target/ARM source.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
QUARTUS_STP="$QUARTUS_BIN/quartus_stp"
PYTHON=${PYTHON:-python3}
EXP_ID=${1:-EXP-S6A-ACTIVE-EXTENSION-LATE-GLOBAL-TIME-TAIL-20260922}
EXP_DIR="$ROOT/docs/experiments/exp-step6-global-time/$EXP_ID"
RAW_DIR="$EXP_DIR/raw"
BUILD_DIR="$RAW_DIR/build"
OBSERVE_DIR="$RAW_DIR/observe"
ANALYSIS_DIR="$EXP_DIR/analysis"
PREV_BUILD_DIR="$ROOT/docs/experiments/exp-step6-global-time/EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-20260922/raw/build"
POSTFIT_TIMING_SUMMARY="$ROOT/docs/experiments/exp-step6-global-time/EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922/analysis/summary.json"
DESIGN_SOURCE_COMMIT="c24568e383be3355ac8684b7d13f293115931586"
MASTER_SOF="$ROOT/quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof"
SLAVE_SOF="$ROOT/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
MASTER_MIF="$ROOT/build/firmware/master/wrc.mif"
SLAVE_MIF="$ROOT/build/firmware/slave/wrc.mif"

mkdir -p "$BUILD_DIR" "$OBSERVE_DIR" "$ANALYSIS_DIR"
cat > "$RAW_DIR/protocol.txt" <<EOF
EXP_ID=$EXP_ID
MASTER_COMPILE=NO
SLAVE_COMPILE=NO
FIRMWARE_BUILD=NO
MASTER_PROGRAM=NO
SLAVE_PROGRAM=NO
MASTER_PTP_RESTART=NO
SLAVE_PTP_RESTART=NO
CPU_RESET=NO
WR_CORE_RESET=NO
PHY_RESET=NO
POWER_CYCLE=NO
TARGET_WRITE=NO
ARM_WRITE=NO
FIBER_QSFP_CHANGE=NO
AUTONEG_CHANGE=NO
SI5340_CHANGE=NO
MDIO_WRITE=NO
WINDOW_MS=45000
CADENCE_REQUEST_MS=300
EOF

actual_hash() {
  if [ -s "$1" ]; then sha256sum "$1" | awk '{print $1}'; else printf 'MISSING'; fi
}

provenance_ok=1
expected_source_commit=$(sed -n 's/^GIT_HEAD=//p' "$PREV_BUILD_DIR/source_identity.txt" 2>/dev/null | head -1)
{
  echo "=== STEP6A LATE TAIL SOURCE IDENTITY ==="
  date -Is
  echo "HOST=$(hostname)"
  echo "ROOT=$ROOT"
  echo "GIT_HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "GIT_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo unknown)"
  git -C "$ROOT" status --short 2>&1 || true
  echo "DESIGN_SOURCE_COMMIT=$DESIGN_SOURCE_COMMIT"
  echo "EXPECTED_FITTED_BUILD_SOURCE_COMMIT=$expected_source_commit"
  if [ "$expected_source_commit" = "$DESIGN_SOURCE_COMMIT" ]; then
    echo "FITTED_BUILD_SOURCE_COMMIT_MATCH=YES"
  else
    echo "FITTED_BUILD_SOURCE_COMMIT_MATCH=NO"
    provenance_ok=0
  fi
  for pair in \
    "MASTER_SOF_SHA256|$MASTER_SOF|1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5" \
    "SLAVE_SOF_SHA256|$SLAVE_SOF|66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151" \
    "MASTER_MIF_SHA256|$MASTER_MIF|8b569afe29d93cfedca84eed484c9c683f1fc58cf10e89943574b7de8d31df7e" \
    "SLAVE_MIF_SHA256|$SLAVE_MIF|eab60d5ceb4af234284f6f241a4595ee850cf3a0184a939d70a30c3d8a5ad26b"; do
    label=${pair%%|*}; rest=${pair#*|}; file=${rest%%|*}; expected=${rest#*|}
    actual=$(actual_hash "$file"); match=NO
    if [ "$actual" = "$expected" ]; then match=YES; else provenance_ok=0; fi
    printf '%s EXPECTED=%s ACTUAL=%s MATCH=%s FILE=%s\n' "$label" "$expected" "$actual" "$match" "$file"
  done
  if grep -q '"classification": "PASS_STEP6B_POSTFIT_TIMING_PROVEN"' "$POSTFIT_TIMING_SUMMARY" 2>/dev/null; then
    echo "POSTFIT_TIMING_PROOF=PASS_STEP6B_POSTFIT_TIMING_PROVEN"
  else
    echo "POSTFIT_TIMING_PROOF=MISSING_OR_MISMATCH"
    provenance_ok=0
  fi
  echo "PROVENANCE_CHECK=$provenance_ok"
} > "$BUILD_DIR/provenance.txt" 2>&1

if [ "$provenance_ok" -ne 1 ]; then
  cat > "$RAW_DIR/stop.txt" <<EOF
RESULT=NOT_RUN_FITTED_ARTIFACT_PROVENANCE_MISMATCH
OBSERVER_RC=0
MASTER_PROGRAM_COUNT=0
SLAVE_PROGRAM_COUNT=0
TARGET_WRITE_COUNT=0
ARM_WRITE_COUNT=0
EOF
  exit 0
fi

set +e
"$QUARTUS_STP" -t "$ROOT/scripts/jtag/read_step6b_digital_scheduled_dual_board_trigger.tcl" \
  "__S6A_LATE_TAIL__" "$EXP_ID" 45000 300 > "$OBSERVE_DIR/observe.log" 2>&1
observer_rc=$?
set -e

if command -v "$PYTHON" >/dev/null 2>&1 && [ -f "$OBSERVE_DIR/observe.log" ]; then
  "$PYTHON" "$ROOT/scripts/analysis/step6a_active_extension_late_global_time_tail.py" \
    "$OBSERVE_DIR/observe.log" --json-out "$ANALYSIS_DIR/summary.json" \
    > "$ANALYSIS_DIR/analyzer.txt" || true
fi

tail_result=$(sed -n 's/^S6A_TAIL_RESULT=\([^ ]*\).*/\1/p' "$OBSERVE_DIR/observe.log" | tail -1)
if [ -z "$tail_result" ]; then tail_result=MISSING; fi
printf 'RESULT=%s\nOBSERVER_RC=%s\nMASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nTARGET_WRITE_COUNT=0\nARM_WRITE_COUNT=0\nPTP_RESTART_COUNT=0\n' \
  "$tail_result" "$observer_rc" > "$RAW_DIR/stop.txt"
exit 0
