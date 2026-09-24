#!/usr/bin/env bash
# Offline post-fit STA only.  No compile, firmware build, program, reset,
# PTP command, or power cycle is permitted in this experiment.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
QUARTUS_STA="$QUARTUS_BIN/quartus_sta"
PYTHON=${PYTHON:-python3}
EXP_ID=${1:-EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922}
EXP_DIR="$ROOT/experiments/step6/$EXP_ID"
PREV_DIR="$ROOT/experiments/legacy/exp-step6-global-time/EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-20260922"
TIMING_DIR="$EXP_DIR/raw/timing"

mkdir -p "$TIMING_DIR" "$EXP_DIR/raw" "$EXP_DIR/analysis"
cat > "$EXP_DIR/raw/protocol.txt" <<EOF
EXP_ID=$EXP_ID
POSTFIT_SOURCE_COMMIT=c24568e383be3355ac8684b7d13f293115931586
MASTER_COMPILE=NO
SLAVE_COMPILE=NO
FIRMWARE_BUILD=NO
MASTER_PROGRAM=NO
SLAVE_PROGRAM=NO
POWER_CYCLE=NO
RESET=NO
PTP_RESTART=NO
HARDWARE_ACCESS=NO
RTL_CHANGE=NO
SDC_CHANGE=NO
QSF_CHANGE=NO
MIF_CHANGE=NO
STA_ONLY=YES
REQUIRED_GROUPS=9
EOF
printf 'RESULT=NOT_RUN_POSTFIT_PROVENANCE_MISMATCH\nMASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\n' \
  > "$EXP_DIR/raw/stop.txt"

EXPECTED_IDENTITY="$PREV_DIR/raw/build/source_identity.txt"
EXPECTED_BUILD="$PREV_DIR/raw/build/build_result.txt"
if [ ! -f "$EXPECTED_IDENTITY" ] || [ ! -f "$EXPECTED_BUILD" ]; then
  printf 'STOP_REASON=PREVIOUS_BUILD_RECORD_MISSING\n' >> "$EXP_DIR/raw/stop.txt"
  exit 4
fi

expected_file_hash() {
  local base="$1"
  grep -E "[ /]${base}$" "$EXPECTED_IDENTITY" | awk 'NR==1 {print $1}'
}
expected_result_hash() {
  local key="$1"
  sed -n "s/^${key}=//p" "$EXPECTED_BUILD" | tail -1
}
actual_hash() {
  sha256sum "$1" | awk '{print $1}'
}

RUN_HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo UNKNOWN)
{
  echo "RUN_CHECKOUT_HEAD=$RUN_HEAD"
  echo "POSTFIT_SOURCE_COMMIT=c24568e383be3355ac8684b7d13f293115931586"
  echo "EXPECTED_RECORD=$EXPECTED_IDENTITY"
  echo "EXPECTED_BUILD_RECORD=$EXPECTED_BUILD"
  echo "FILE HASH EXPECTED ACTUAL MATCH"
  for spec in \
    "DE5a_wr_master_jtag.vhd|$ROOT/quartus/DE5a_wr_master_jtag.vhd" \
    "DE5a_wr_slave_jtag.vhd|$ROOT/quartus/DE5a_wr_slave_jtag.vhd" \
    "DE5a_wr_master_jtag.qsf|$ROOT/quartus/DE5a_wr_master_jtag.qsf" \
    "DE5a_wr_slave_jtag.qsf|$ROOT/quartus/DE5a_wr_slave_jtag.qsf" \
    "DE5a_wr_master_jtag.sdc|$ROOT/quartus/DE5a_wr_master_jtag.sdc" \
    "DE5a_wr_slave_jtag.sdc|$ROOT/quartus/DE5a_wr_slave_jtag.sdc"; do
    base=${spec%%|*}
    file=${spec#*|}
    expected=$(expected_file_hash "$base")
    actual=$(actual_hash "$file")
    match=NO
    [ -n "$expected" ] && [ "$expected" = "$actual" ] && match=YES
    printf '%s %s %s %s\n' "$base" "$expected" "$actual" "$match"
    if [ "$match" != YES ]; then provenance_ok=0; fi
  done
  for spec in \
    "MASTER_MIF_SHA256|$ROOT/build/firmware/master/wrc.mif|MASTER_MIF_SHA256" \
    "SLAVE_MIF_SHA256|$ROOT/build/firmware/slave/wrc.mif|SLAVE_MIF_SHA256" \
    "MASTER_SOF_SHA256|$ROOT/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof|MASTER_SOF_SHA256" \
    "SLAVE_SOF_SHA256|$ROOT/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof|SLAVE_SOF_SHA256"; do
    IFS='|' read -r label file key <<< "$spec"
    expected=$(expected_result_hash "$key")
    actual=$(actual_hash "$file")
    match=NO
    [ -n "$expected" ] && [ "$expected" = "$actual" ] && match=YES
    printf '%s %s %s %s\n' "$label" "$expected" "$actual" "$match"
    if [ "$match" != YES ]; then provenance_ok=0; fi
  done
  echo "PROVENANCE_CHECK=${provenance_ok:-1}"
} > "$EXP_DIR/raw/provenance.txt"

provenance_ok=1
if grep -q ' NO$' "$EXP_DIR/raw/provenance.txt"; then provenance_ok=0; fi
if [ "$provenance_ok" -ne 1 ]; then
  printf 'RESULT=NOT_RUN_POSTFIT_PROVENANCE_MISMATCH\nSTOP_REASON=HASH_MISMATCH\nMASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\n' \
    > "$EXP_DIR/raw/stop.txt"
  exit 4
fi

set +e
"$QUARTUS_STA" -t "$ROOT/scripts/experiment/check_step6b_timing.tcl" \
  "$ROOT/quartus/DE5a_wr_slave_jtag.qpf" \
  DE5a_wr_slave_jtag "$TIMING_DIR/slave_step6b_timing.txt" \
  > "$TIMING_DIR/slave_quartus_sta.log" 2>&1
slave_rc=$?
"$QUARTUS_STA" -t "$ROOT/scripts/experiment/check_step6b_timing.tcl" \
  "$ROOT/quartus/DE5a_wr_master_jtag.qpf" \
  DE5a_wr_master_jtag "$TIMING_DIR/master_step6b_timing.txt" \
  > "$TIMING_DIR/master_quartus_sta.log" 2>&1
master_rc=$?
set -e

slave_result=$(sed -n 's/^STEP6B_TIMING_RESULT=\([^ ]*\).*/\1/p' "$TIMING_DIR/slave_step6b_timing.txt" | tail -1)
master_result=$(sed -n 's/^STEP6B_TIMING_RESULT=\([^ ]*\).*/\1/p' "$TIMING_DIR/master_step6b_timing.txt" | tail -1)
[ -n "$slave_result" ] || slave_result=NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED
[ -n "$master_result" ] || master_result=NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED

if [ "$slave_result" = PASS_STEP6B_POSTFIT_TIMING_PROVEN ] && \
   [ "$master_result" = PASS_STEP6B_POSTFIT_TIMING_PROVEN ] && \
   [ "$slave_rc" -eq 0 ] && [ "$master_rc" -eq 0 ]; then
  result=PASS_STEP6B_POSTFIT_TIMING_PROVEN
elif grep -q 'STEP6B_TIMING_RESULT=FAIL_STEP6B_POSTFIT_TIMING' \
    "$TIMING_DIR/slave_step6b_timing.txt" "$TIMING_DIR/master_step6b_timing.txt"; then
  result=FAIL_STEP6B_POSTFIT_TIMING
else
  result=NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED
fi

printf 'RESULT=%s\nSLAVE_TIMING_RESULT=%s\nMASTER_TIMING_RESULT=%s\nSLAVE_STA_RC=%s\nMASTER_STA_RC=%s\nMASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\n' \
  "$result" "$slave_result" "$master_result" "$slave_rc" "$master_rc" \
  > "$EXP_DIR/raw/stop.txt"

if command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" "$ROOT/scripts/analysis/step6b_timing_query_boundary_correction.py" \
    "$TIMING_DIR" --json-out "$EXP_DIR/analysis/summary.json" \
    > "$EXP_DIR/analysis/analyzer.txt" || true
fi
exit 0
