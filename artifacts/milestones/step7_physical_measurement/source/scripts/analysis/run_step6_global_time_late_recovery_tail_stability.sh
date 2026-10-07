#!/usr/bin/env bash
# Run EXP-S6-GLOBAL-TIME-LATE-RECOVERY-TAIL-STABILITY-20260922.
# Pure read-only tail validation: no compile, program, reset, PTP command, or
# power-cycle is allowed.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
if [ "$#" -lt 1 ]; then
  echo "usage: run_step6_global_time_late_recovery_tail_stability.sh EXP-ID" >&2
  exit 2
fi
EXP_ID="$1"
QUARTUS_STP=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
PYTHON=python3
EXP_DIR="$ROOT/experiments/step6/$EXP_ID"
CAPTURE="$EXP_DIR/raw/observe/late_recovery_tail.log"

mkdir -p "$EXP_DIR/raw/observe" "$EXP_DIR/raw/program" "$EXP_DIR/analysis"
cat > "$EXP_DIR/raw/protocol.txt" <<'EOF'
MASTER_COMPILE=NO
SLAVE_COMPILE=NO
FIRMWARE_BUILD=NO
MASTER_PROGRAM=NO
SLAVE_PROGRAM=NO
POWER_CYCLE=NO
CPU_RESET=NO
WR_CORE_RESET=NO
PHY_RESET=NO
MASTER_PTP_RESTART=NO
SLAVE_PTP_RESTART=NO
MODE_COMMAND=NO
FIBER_QSFP_CHANGE=NO
POLARITY_BITSLIP=NO
AUTONEG_CHANGE=NO
SI5340_CHANGE=NO
MDIO_WRITE=NO
OBSERVATION=READ_ONLY_TAIL
GATE_PAIRED_SAMPLES=3
TAIL_DURATION_MS=15000
CAPTURE_GAP_MS=400
EOF
printf 'MASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\nCPU_RESET_COUNT=0\nWR_CORE_RESET_COUNT=0\n' \
  > "$EXP_DIR/raw/program/stop.txt"

set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_global_time_late_recovery_tail_stability.tcl" \
  "$EXP_ID" 3 350 15000 400 > "$CAPTURE" 2>&1
observer_rc=$?
set -e

if ! grep -q '^S6_TAIL_DONE ' "$CAPTURE"; then
  printf 'RESULT=INCONCLUSIVE_RUNTIME_STATE_CHANGED\nSTOP_REASON=OBSERVER_RESULT_MISSING\nOBSERVER_RC=%s\n' \
    "$observer_rc" > "$EXP_DIR/raw/program/stop.txt"
  exit 3
fi

if command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" \
    "$ROOT/scripts/analysis/step6_global_time_late_recovery_tail_stability.py" \
    "$CAPTURE" --json-out "$EXP_DIR/analysis/summary.json" \
    > "$EXP_DIR/analysis/analyzer.txt"
fi

printf 'RESULT=OBSERVER_COMPLETE\nOBSERVER_RC=%s\n' "$observer_rc" \
  > "$EXP_DIR/raw/program/stop.txt"
exit "$observer_rc"
