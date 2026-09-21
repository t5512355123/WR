#!/usr/bin/env bash
# Verify the already fitted Step6B artifacts, program, and observe
# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-HARDWARE-RUN-V2-20260922.
# This is a single controlled run: there is no compile or timing refit;
# Slave is programmed once directly, Master once directly and last, and the
# observer never re-arms or reprograms after a hard stop.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
QUARTUS_STP="$QUARTUS_BIN/quartus_stp"
QUARTUS_STA="$QUARTUS_BIN/quartus_sta"
QUARTUS_PGM="$QUARTUS_BIN/quartus_pgm"
PYTHON=${PYTHON:-python3}
EXP_ID=${1:-EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-HARDWARE-RUN-V2-20260922}
EXP_DIR="$ROOT/docs/experiments/exp-step6-global-time/$EXP_ID"
BUILD_DIR="$EXP_DIR/raw/build"
TIMING_DIR="$EXP_DIR/raw/timing"
PROGRAM_DIR="$EXP_DIR/raw/program"
OBSERVE_DIR="$EXP_DIR/raw/observe"
ANALYSIS_DIR="$EXP_DIR/analysis"
MASTER_PROJECT="$ROOT/quartus/jtag_runtime_diag/DE5a_wr_master_jtag.qpf"
SLAVE_PROJECT="$ROOT/quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.qpf"
MASTER_REVISION=DE5a_wr_master_jtag
SLAVE_REVISION=DE5a_wr_slave_jtag
MASTER_SOF="$ROOT/quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof"
SLAVE_SOF="$ROOT/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
MASTER_MIF="$ROOT/build/firmware/master/wrc.mif"
SLAVE_MIF="$ROOT/build/firmware/slave/wrc.mif"
PREV_BUILD_DIR="$ROOT/docs/experiments/exp-step6-global-time/EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-20260922/raw/build"
POSTFIT_TIMING_SUMMARY="$ROOT/docs/experiments/exp-step6-global-time/EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922/analysis/summary.json"
DESIGN_SOURCE_COMMIT="c24568e383be3355ac8684b7d13f293115931586"

mkdir -p "$BUILD_DIR" "$TIMING_DIR" "$PROGRAM_DIR" "$OBSERVE_DIR" "$ANALYSIS_DIR"

cat > "$EXP_DIR/raw/protocol.txt" <<EOF
EXP_ID=$EXP_ID
PROGRAM_METHOD=DIRECT_NON_SUDO
MASTER_COMPILE=NO
SLAVE_COMPILE=NO
FIRMWARE_BUILD=NO
MASTER_PROGRAM=YES_ONCE_LAST
SLAVE_PROGRAM=YES_ONCE_FIRST
POWER_CYCLE=NO
CPU_RESET=NO
WR_CORE_RESET=NO
PTP_RESTART=CONDITIONAL_SLAVE_ONLY
SMA_CLKOUT_CHANGED=NO
SDC_CHANGED=NO
TARGET_CYCLES=62500000
PREARM_HEALTHY_PAIRED_SAMPLES=5
PREARM_COMMON_TAI_LABELS=3
PREARM_TIMEOUT_MS=60000
TARGET_TAI_OFFSET_SECONDS=20
TARGET_SETTLE_MS=150
ARM_SETTLE_MS=120
OBSERVE_CADENCE_MS=250
OBSERVE_MAX_MS=25000
TIMING_GATE=EXTERNAL_POSTFIT_TIMING_PROVEN
POSTFIT_TIMING_SUMMARY=$POSTFIT_TIMING_SUMMARY
DESIGN_SOURCE_COMMIT=$DESIGN_SOURCE_COMMIT
EOF

printf 'MASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\n' \
  > "$PROGRAM_DIR/stop.txt"

{
  echo "=== STEP6B SOURCE IDENTITY ==="
  date -Is
  echo "HOST=$(hostname)"
  echo "ROOT=$ROOT"
  echo "GIT_HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "GIT_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo unknown)"
  echo "GIT_STATUS_BEGIN"
  git -C "$ROOT" status --short 2>&1 || true
  echo "GIT_STATUS_END"
  echo "QUARTUS_VERSION_BEGIN"
  "$QUARTUS_BIN/quartus_sh" --version 2>&1 || true
  echo "QUARTUS_VERSION_END"
  for file in \
    "$ROOT/quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd" \
    "$ROOT/quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd" \
    "$ROOT/quartus/jtag_runtime_diag/DE5a_wr_master_jtag.qsf" \
    "$ROOT/quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.qsf" \
    "$ROOT/quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc" \
    "$ROOT/quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc" \
    "$MASTER_MIF" "$SLAVE_MIF"; do
    if [ -f "$file" ]; then sha256sum "$file"; else echo "MISSING $file"; fi
  done
} > "$BUILD_DIR/source_identity.txt" 2>&1

if [ ! -f "$MASTER_MIF" ] || [ ! -f "$SLAVE_MIF" ] || \
   [ ! -s "$MASTER_SOF" ] || [ ! -s "$SLAVE_SOF" ] || \
   [ ! -f "$PREV_BUILD_DIR/source_identity.txt" ] || \
   [ ! -f "$PREV_BUILD_DIR/build_result.txt" ] || \
   [ ! -f "$POSTFIT_TIMING_SUMMARY" ]; then
  printf 'RESULT=NOT_RUN_FITTED_ARTIFACT_PROVENANCE_MISMATCH\nSTOP_REASON=REQUIRED_RECORD_OR_ARTIFACT_MISSING\nPROGRAM_COUNT=0\n' \
    > "$PROGRAM_DIR/stop.txt"
  exit 4
fi

expected_file_hash() {
  local base="$1"
  awk -v base="$base" '$2 ~ ("/" base "$") {print $1; exit}' \
    "$PREV_BUILD_DIR/source_identity.txt"
}
expected_build_hash() {
  local key="$1"
  sed -n "s/^${key}=//p" "$PREV_BUILD_DIR/build_result.txt" | tail -1
}
actual_hash() { sha256sum "$1" | awk '{print $1}'; }

provenance_ok=1
expected_source_commit=$(sed -n 's/^GIT_HEAD=//p' "$PREV_BUILD_DIR/source_identity.txt" | head -1)
{
  echo "DESIGN_SOURCE_COMMIT=$DESIGN_SOURCE_COMMIT"
  echo "EXPECTED_BUILD_SOURCE_COMMIT=$expected_source_commit"
  if [ "$expected_source_commit" = "$DESIGN_SOURCE_COMMIT" ]; then
    echo 'BUILD_SOURCE_COMMIT_MATCH=YES'
  else
    echo 'BUILD_SOURCE_COMMIT_MATCH=NO'
    provenance_ok=0
  fi
  echo "POSTFIT_TIMING_PROOF=PASS_STEP6B_POSTFIT_TIMING_PROVEN"
  echo "FILE HASH EXPECTED ACTUAL MATCH"
  for spec in \
    "DE5a_wr_master_jtag.vhd|$ROOT/quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd" \
    "DE5a_wr_slave_jtag.vhd|$ROOT/quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd" \
    "DE5a_wr_master_jtag.qsf|$ROOT/quartus/jtag_runtime_diag/DE5a_wr_master_jtag.qsf" \
    "DE5a_wr_slave_jtag.qsf|$ROOT/quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.qsf" \
    "DE5a_wr_master_jtag.sdc|$ROOT/quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc" \
    "DE5a_wr_slave_jtag.sdc|$ROOT/quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc"; do
    base=${spec%%|*}
    file=${spec#*|}
    expected=$(expected_file_hash "$base")
    actual=$(actual_hash "$file")
    match=NO
    [ -n "$expected" ] && [ "$expected" = "$actual" ] && match=YES
    printf '%s %s %s %s\n' "$base" "$expected" "$actual" "$match"
    [ "$match" = YES ] || provenance_ok=0
  done
  for spec in \
    "MASTER_MIF_SHA256|$MASTER_MIF" \
    "SLAVE_MIF_SHA256|$SLAVE_MIF" \
    "MASTER_SOF_SHA256|$MASTER_SOF" \
    "SLAVE_SOF_SHA256|$SLAVE_SOF"; do
    label=${spec%%|*}
    file=${spec#*|}
    expected=$(expected_build_hash "$label")
    actual=$(actual_hash "$file")
    match=NO
    [ -n "$expected" ] && [ "$expected" = "$actual" ] && match=YES
    printf '%s %s %s %s\n' "$label" "$expected" "$actual" "$match"
    [ "$match" = YES ] || provenance_ok=0
  done
  if grep -q '"classification": "PASS_STEP6B_POSTFIT_TIMING_PROVEN"' \
      "$POSTFIT_TIMING_SUMMARY"; then
    echo 'POSTFIT_TIMING_SUMMARY_MATCH=YES'
  else
    echo 'POSTFIT_TIMING_SUMMARY_MATCH=NO'
    provenance_ok=0
  fi
  echo "PROVENANCE_CHECK=$provenance_ok"
} > "$BUILD_DIR/provenance.txt"

if [ "$provenance_ok" -ne 1 ]; then
  printf 'RESULT=NOT_RUN_FITTED_ARTIFACT_PROVENANCE_MISMATCH\nSTOP_REASON=HASH_OR_POSTFIT_PROOF_MISMATCH\nMASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\n' \
    > "$PROGRAM_DIR/stop.txt"
  exit 4
fi

{
  echo "MASTER_SOF_SHA256=$(actual_hash "$MASTER_SOF")"
  echo "SLAVE_SOF_SHA256=$(actual_hash "$SLAVE_SOF")"
  echo "MASTER_MIF_SHA256=$(actual_hash "$MASTER_MIF")"
  echo "SLAVE_MIF_SHA256=$(actual_hash "$SLAVE_MIF")"
  echo "MIF_UNCHANGED=YES"
  echo "MASTER_COMPILE=NO"
  echo "SLAVE_COMPILE=NO"
} > "$BUILD_DIR/build_result.txt"

printf 'TIMING_GATE=EXTERNAL_POSTFIT_TIMING_PROVEN\nCOMPILE=NOT_PERFORMED\n' \
  > "$TIMING_DIR/gate.txt"

set +e
echo "PROGRAM_METHOD=DIRECT_NON_SUDO" > "$PROGRAM_DIR/slave_program.log"
echo "PROGRAM_CABLE=DE5 [1-11.2]" >> "$PROGRAM_DIR/slave_program.log"
echo "SOF_SHA256=$(actual_hash "$SLAVE_SOF")" >> "$PROGRAM_DIR/slave_program.log"
echo "SLAVE_PROGRAM_START=$(date -Is)" >> "$PROGRAM_DIR/slave_program.log"
"$QUARTUS_PGM" -c 'DE5 [1-11.2]' -m jtag -o "p;$SLAVE_SOF" \
  >> "$PROGRAM_DIR/slave_program.log" 2>&1
slave_program_rc=$?
echo "SLAVE_PROGRAM_DONE=$(date -Is)" >> "$PROGRAM_DIR/slave_program.log"
set -e
program_log_ok() {
  local log_file="$1"
  local cable="$2"
  grep -Fq "Using programming cable \"$cable\"" "$log_file" &&
    grep -Fq 'Configuration succeeded' "$log_file" &&
    grep -Fq '1 device(s) configured' "$log_file" &&
    grep -Fq 'Successfully performed operation(s)' "$log_file" &&
    grep -Eiq '0 errors([, ]|$)' "$log_file"
}
if [ "$slave_program_rc" -ne 0 ] || \
   ! program_log_ok "$PROGRAM_DIR/slave_program.log" 'DE5 [1-11.2]'; then
  printf 'RESULT=INCONCLUSIVE_PROGRAM_FAILURE\nSTOP_REASON=SLAVE_PROGRAM_FAILURE\nSLAVE_PROGRAM_COUNT=1\nMASTER_PROGRAM_COUNT=0\n' \
    > "$PROGRAM_DIR/stop.txt"
  exit 5
fi
printf 'SLAVE_PROGRAM_COUNT=1\nSLAVE_PROGRAM_RC=%s\n' "$slave_program_rc" \
  > "$PROGRAM_DIR/slave_program_result.txt"

set +e
echo "PROGRAM_METHOD=DIRECT_NON_SUDO" > "$PROGRAM_DIR/master_program.log"
echo "PROGRAM_CABLE=DE5 [1-11.1]" >> "$PROGRAM_DIR/master_program.log"
echo "SOF_SHA256=$(actual_hash "$MASTER_SOF")" >> "$PROGRAM_DIR/master_program.log"
echo "MASTER_PROGRAM_START=$(date -Is)" >> "$PROGRAM_DIR/master_program.log"
"$QUARTUS_PGM" -c 'DE5 [1-11.1]' -m jtag -o "p;$MASTER_SOF" \
  >> "$PROGRAM_DIR/master_program.log" 2>&1
master_program_rc=$?
echo "MASTER_PROGRAM_DONE=$(date -Is)" >> "$PROGRAM_DIR/master_program.log"
set -e
if [ "$master_program_rc" -ne 0 ] || \
   ! program_log_ok "$PROGRAM_DIR/master_program.log" 'DE5 [1-11.1]'; then
  printf 'RESULT=INCONCLUSIVE_PROGRAM_FAILURE\nSTOP_REASON=MASTER_PROGRAM_FAILURE\nSLAVE_PROGRAM_COUNT=1\nMASTER_PROGRAM_COUNT=1\n' \
    > "$PROGRAM_DIR/stop.txt"
  exit 5
fi
printf 'SLAVE_PROGRAM_COUNT=1\nMASTER_PROGRAM_COUNT=1\nMASTER_PROGRAM_RC=%s\n' "$master_program_rc" \
  > "$PROGRAM_DIR/master_program_result.txt"

set +e
"$QUARTUS_STP" -t "$ROOT/scripts/jtag/read_step6b_digital_scheduled_dual_board_trigger.tcl" \
  "$EXP_ID" 60000 350 250 > "$OBSERVE_DIR/observe.log" 2>&1
observer_rc=$?
set -e

if command -v "$PYTHON" >/dev/null 2>&1 && [ -f "$OBSERVE_DIR/observe.log" ]; then
  "$PYTHON" "$ROOT/scripts/analysis/step6b_digital_scheduled_dual_board_trigger.py" \
    "$OBSERVE_DIR/observe.log" --json-out "$ANALYSIS_DIR/summary.json" \
    > "$ANALYSIS_DIR/analyzer.txt" || true
fi

capture_result=$(sed -n 's/^S6B_CAPTURE_RESULT=\([^ ]*\).*/\1/p' "$OBSERVE_DIR/observe.log" | tail -1)
gate_result=$(sed -n 's/^S6B_GATE_RESULT=\([^ ]*\).*/\1/p' "$OBSERVE_DIR/observe.log" | tail -1)
if [ -z "$capture_result" ]; then capture_result="MISSING"; fi
if [ -z "$gate_result" ]; then gate_result="MISSING"; fi
printf 'RESULT=%s\nGATE_RESULT=%s\nOBSERVER_RC=%s\nSLAVE_PROGRAM_COUNT=1\nMASTER_PROGRAM_COUNT=1\nPOWER_CYCLE=0\n' \
  "$capture_result" "$gate_result" "$observer_rc" > "$PROGRAM_DIR/stop.txt"

# The hardware run itself completed even when the observer classified the
# scheduled trigger as a controlled failure/inconclusive result.  The report
# and adviser review decide the next experiment; this script never retries.
exit 0
