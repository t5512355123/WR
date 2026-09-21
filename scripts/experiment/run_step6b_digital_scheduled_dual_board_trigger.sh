#!/usr/bin/env bash
# Build, timing-gate, program, and observe EXP-S6B-DIGITAL-SCHEDULED-
# DUAL-BOARD-TRIGGER-20260922.  This is a single controlled run: Slave is
# programmed once, Master once and last, and the observer never re-arms or
# reprograms after a hard stop.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
QUARTUS_STP="$QUARTUS_BIN/quartus_stp"
QUARTUS_STA="$QUARTUS_BIN/quartus_sta"
QUARTUS_PGM="$QUARTUS_BIN/quartus_pgm"
PYTHON=${PYTHON:-python3}
EXP_ID=${1:-EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-20260922}
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

mkdir -p "$BUILD_DIR" "$TIMING_DIR" "$PROGRAM_DIR" "$OBSERVE_DIR" "$ANALYSIS_DIR"

cat > "$EXP_DIR/raw/protocol.txt" <<EOF
EXP_ID=$EXP_ID
MASTER_COMPILE=YES
SLAVE_COMPILE=YES
FIRMWARE_BUILD=NO
MASTER_PROGRAM=YES_ONCE_LAST
SLAVE_PROGRAM=YES_ONCE_FIRST
POWER_CYCLE=NO
CPU_RESET=NO
WR_CORE_RESET=NO
PTP_RESTART=NO
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
TIMING_GATE=STEP6B_PATHS_ONLY
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

if [ ! -f "$MASTER_MIF" ] || [ ! -f "$SLAVE_MIF" ]; then
  printf 'RESULT=NOT_RUN_BUILD_FAIL\nSTOP_REASON=MIF_MISSING\nPROGRAM_COUNT=0\n' \
    > "$PROGRAM_DIR/stop.txt"
  exit 3
fi

MASTER_MIF_BEFORE=$(sha256sum "$MASTER_MIF" | awk '{print $1}')
SLAVE_MIF_BEFORE=$(sha256sum "$SLAVE_MIF" | awk '{print $1}')

set +e
"$ROOT/scripts/build/build_jtag_slave.sh" > "$BUILD_DIR/slave_compile.log" 2>&1
slave_build_rc=$?
"$ROOT/scripts/build/build_jtag_master.sh" > "$BUILD_DIR/master_compile.log" 2>&1
master_build_rc=$?
set -e

if [ "$slave_build_rc" -ne 0 ] || [ "$master_build_rc" -ne 0 ] || \
   [ ! -s "$SLAVE_SOF" ] || [ ! -s "$MASTER_SOF" ]; then
  printf 'RESULT=NOT_RUN_BUILD_FAIL\nSTOP_REASON=FULL_COMPILE_OR_SOF_FAILURE\nSLAVE_BUILD_RC=%s\nMASTER_BUILD_RC=%s\nPROGRAM_COUNT=0\n' \
    "$slave_build_rc" "$master_build_rc" > "$PROGRAM_DIR/stop.txt"
  exit 3
fi

MASTER_MIF_AFTER=$(sha256sum "$MASTER_MIF" | awk '{print $1}')
SLAVE_MIF_AFTER=$(sha256sum "$SLAVE_MIF" | awk '{print $1}')
if [ "$MASTER_MIF_BEFORE" != "$MASTER_MIF_AFTER" ] || \
   [ "$SLAVE_MIF_BEFORE" != "$SLAVE_MIF_AFTER" ]; then
  printf 'RESULT=NOT_RUN_BUILD_FAIL\nSTOP_REASON=MIF_CHANGED\nPROGRAM_COUNT=0\n' \
    > "$PROGRAM_DIR/stop.txt"
  exit 3
fi

{
  echo "MASTER_SOF_SHA256=$(sha256sum "$MASTER_SOF" | awk '{print $1}')"
  echo "SLAVE_SOF_SHA256=$(sha256sum "$SLAVE_SOF" | awk '{print $1}')"
  echo "MASTER_MIF_SHA256=$MASTER_MIF_AFTER"
  echo "SLAVE_MIF_SHA256=$SLAVE_MIF_AFTER"
  echo "MIF_UNCHANGED=YES"
  echo "SLAVE_BUILD_RC=$slave_build_rc"
  echo "MASTER_BUILD_RC=$master_build_rc"
} > "$BUILD_DIR/build_result.txt"

set +e
"$QUARTUS_STA" -t "$ROOT/scripts/experiment/check_step6b_timing.tcl" \
  "$SLAVE_PROJECT" "$SLAVE_REVISION" "$TIMING_DIR/slave_step6b_timing.txt" \
  > "$TIMING_DIR/slave_quartus_sta.log" 2>&1
slave_timing_rc=$?
"$QUARTUS_STA" -t "$ROOT/scripts/experiment/check_step6b_timing.tcl" \
  "$MASTER_PROJECT" "$MASTER_REVISION" "$TIMING_DIR/master_step6b_timing.txt" \
  > "$TIMING_DIR/master_quartus_sta.log" 2>&1
master_timing_rc=$?
set -e

slave_timing_pass=0
master_timing_pass=0
grep -q '^STEP6B_TIMING_RESULT=PASS ' "$TIMING_DIR/slave_step6b_timing.txt" 2>/dev/null && slave_timing_pass=1
grep -q '^STEP6B_TIMING_RESULT=PASS ' "$TIMING_DIR/master_step6b_timing.txt" 2>/dev/null && master_timing_pass=1
if [ "$slave_timing_rc" -ne 0 ] || [ "$master_timing_rc" -ne 0 ] || \
   [ "$slave_timing_pass" -ne 1 ] || [ "$master_timing_pass" -ne 1 ]; then
  printf 'RESULT=NOT_RUN_STEP6B_TIMING_NOT_PROVEN\nSTOP_REASON=STEP6B_PATH_TIMING_GATE_FAILED\nSLAVE_TIMING_RC=%s\nMASTER_TIMING_RC=%s\nPROGRAM_COUNT=0\n' \
    "$slave_timing_rc" "$master_timing_rc" > "$PROGRAM_DIR/stop.txt"
  exit 4
fi

printf 'TIMING_GATE=PASS\nSLAVE_TIMING_RC=%s\nMASTER_TIMING_RC=%s\n' \
  "$slave_timing_rc" "$master_timing_rc" > "$TIMING_DIR/gate.txt"

set +e
sudo "$QUARTUS_PGM" -c 'DE5 [1-11.2]' -m jtag -o "p;$SLAVE_SOF" \
  > "$PROGRAM_DIR/slave_program.log" 2>&1
slave_program_rc=$?
set -e
if [ "$slave_program_rc" -ne 0 ]; then
  printf 'RESULT=INCONCLUSIVE_PROGRAM_FAILURE\nSTOP_REASON=SLAVE_PROGRAM_FAILURE\nSLAVE_PROGRAM_COUNT=1\nMASTER_PROGRAM_COUNT=0\n' \
    > "$PROGRAM_DIR/stop.txt"
  exit 5
fi
printf 'SLAVE_PROGRAM_COUNT=1\nSLAVE_PROGRAM_RC=%s\n' "$slave_program_rc" \
  > "$PROGRAM_DIR/slave_program_result.txt"

set +e
sudo "$QUARTUS_PGM" -c 'DE5 [1-11.1]' -m jtag -o "p;$MASTER_SOF" \
  > "$PROGRAM_DIR/master_program.log" 2>&1
master_program_rc=$?
set -e
if [ "$master_program_rc" -ne 0 ]; then
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
