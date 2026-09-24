#!/usr/bin/env bash
# Run the approved Step6B scheduler re-arm repeatability experiment.
#
# This runner deliberately never compiles, programs, resets, restarts PTP, or
# power-cycles.  The Tcl observer performs only the six writes approved for
# this experiment on the already-live post-fire session.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
QUARTUS_STP="$QUARTUS_BIN/quartus_stp"
PYTHON=${PYTHON:-python3}
EXP_ID=${1:-EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-REARM-REPEATABILITY-20260922}
EXP_DIR="$ROOT/experiments/step6/$EXP_ID"
RAW_DIR="$EXP_DIR/raw"
OBSERVE_DIR="$RAW_DIR/observe"
ANALYSIS_DIR="$EXP_DIR/analysis"

mkdir -p "$OBSERVE_DIR" "$ANALYSIS_DIR"
cat > "$RAW_DIR/protocol.txt" <<EOF
EXP_ID=$EXP_ID
SESSION=EXISTING_POST_FIRE_STEP6B_LIVE_SESSION
COMPILE=NO
FIRMWARE_BUILD=NO
MASTER_PROGRAM=NO
SLAVE_PROGRAM=NO
MASTER_PTP_RESTART=NO
SLAVE_PTP_RESTART=NO
CPU_RESET=NO
WR_CORE_RESET=NO
PHY_RESET=NO
POWER_CYCLE=NO
FIBER_QSFP_CHANGE=NO
SI5340_MDIO_WRITE=NO
FUNCTIONAL_WRITE_COUNT_MAX=6
ARM0_WRITE_ORDER=MASTER_ONCE_THEN_SLAVE_ONCE
TARGET_WRITE_ORDER=MASTER_ONCE_THEN_SLAVE_ONCE
ARM1_WRITE_ORDER=MASTER_ONCE_THEN_SLAVE_ONCE
TARGET_CYCLES=62500000
PREVIOUS_TARGET_TAI=3433
PRE_GATE_TIMEOUT_MS=10000
CAPTURE_TIMEOUT_MS=40000
EOF

set +e
"$QUARTUS_STP" -t "$ROOT/scripts/jtag/read_step6b_rearm_repeatability.tcl" \
  "$EXP_ID" 10000 300 300 40000 > "$OBSERVE_DIR/observe.log" 2>&1
observer_rc=$?
set -e

if command -v "$PYTHON" >/dev/null 2>&1 && [ -f "$OBSERVE_DIR/observe.log" ]; then
  "$PYTHON" "$ROOT/scripts/analysis/step6b_rearm_repeatability.py" \
    "$OBSERVE_DIR/observe.log" --json-out "$ANALYSIS_DIR/summary.json" \
    > "$ANALYSIS_DIR/analyzer.txt" || true
fi

result=$(sed -n 's/^S6B_REARM_RESULT=\([^ ]*\).*/\1/p' \
  "$OBSERVE_DIR/observe.log" | tail -1)
if [ -z "$result" ]; then result=MISSING; fi
count_write() {
  grep -c "S6B_SOURCE_WRITE BOARD=$1 ROLE=$1 INDEX=$2 VALUE=$3 OK=1" \
    "$OBSERVE_DIR/observe.log" 2>/dev/null || true
}
arm0_master=$(count_write MASTER 68 0)
arm0_slave=$(count_write SLAVE 68 0)
target_master=$(grep -c "S6B_SOURCE_WRITE BOARD=MASTER ROLE=MASTER INDEX=67 .* OK=1" "$OBSERVE_DIR/observe.log" 2>/dev/null || true)
target_slave=$(grep -c "S6B_SOURCE_WRITE BOARD=SLAVE ROLE=SLAVE INDEX=67 .* OK=1" "$OBSERVE_DIR/observe.log" 2>/dev/null || true)
arm1_master=$(count_write MASTER 68 1)
arm1_slave=$(count_write SLAVE 68 1)
printf 'RESULT=%s\nOBSERVER_RC=%s\nMASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nMASTER_ARM0_WRITE_COUNT=%s\nSLAVE_ARM0_WRITE_COUNT=%s\nMASTER_TARGET_WRITE_COUNT=%s\nSLAVE_TARGET_WRITE_COUNT=%s\nMASTER_ARM1_WRITE_COUNT=%s\nSLAVE_ARM1_WRITE_COUNT=%s\n' \
  "$result" "$observer_rc" "$arm0_master" "$arm0_slave" \
  "$target_master" "$target_slave" "$arm1_master" "$arm1_slave" \
  > "$RAW_DIR/stop.txt"
exit 0
