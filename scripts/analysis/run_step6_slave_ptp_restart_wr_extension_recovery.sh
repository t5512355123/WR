#!/usr/bin/env bash
# Run EXP-S6-SLAVE-PTP-RESTART-WR-EXTENSION-RECOVERY-20260922.
#
# No compile, firmware build, programming, reset, or power-cycle is allowed.
# The observer itself sends exactly one Slave "ptp stop" and one "ptp start".
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
if [ "$#" -lt 1 ]; then
  echo "usage: run_step6_slave_ptp_restart_wr_extension_recovery.sh EXP-ID" >&2
  exit 2
fi
EXP_ID="$1"
QUARTUS_STP=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
PYTHON=python3
EXP_DIR="$ROOT/docs/experiments/exp-step6-global-time/$EXP_ID"
CAPTURE="$EXP_DIR/raw/observe/ptp_restart_recovery.log"

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
SLAVE_PTP_RESTART=YES_EXACTLY_ONCE
MODE_COMMAND=NO
FIBER_QSFP_CHANGE=NO
POLARITY_BITSLIP=NO
AUTONEG_CHANGE=NO
SI5340_CHANGE=NO
MDIO_WRITE=NO
PRE_RESTART_PAIRED_SAMPLES=5
REARM_TIMEOUT_MS=10000
TOTAL_TIMEOUT_MS=30000
OBSERVATION=READ_ONLY_EXCEPT_ONE_SLAVE_PTP_STOP_START
EOF
printf 'MASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\nCPU_RESET_COUNT=0\nWR_CORE_RESET_COUNT=0\n' \
  > "$EXP_DIR/raw/program/stop.txt"

set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_slave_ptp_restart_wr_extension_recovery.tcl" \
  "$EXP_ID" 5 250 100 10000 30000 350 > "$CAPTURE" 2>&1
observer_rc=$?
set -e

if ! grep -q '^S6_PTP_RESTART_DONE ' "$CAPTURE"; then
  printf 'RESULT=INCONCLUSIVE_RUNTIME_STATE_CHANGED\nSTOP_REASON=OBSERVER_RESULT_MISSING\nOBSERVER_RC=%s\n' \
    "$observer_rc" > "$EXP_DIR/raw/program/stop.txt"
  exit 3
fi

if command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" \
    "$ROOT/scripts/analysis/step6_slave_ptp_restart_wr_extension_recovery.py" \
    "$CAPTURE" --json-out "$EXP_DIR/analysis/summary.json" \
    > "$EXP_DIR/analysis/analyzer.txt"
fi

printf 'RESULT=OBSERVER_COMPLETE\nOBSERVER_RC=%s\n' "$observer_rc" \
  > "$EXP_DIR/raw/program/stop.txt"
exit "$observer_rc"
