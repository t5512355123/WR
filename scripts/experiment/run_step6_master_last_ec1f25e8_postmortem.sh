#!/usr/bin/env bash
# Run the read-only postmortem for the already-completed Master-last rebuild.
# This script intentionally does not compile, program, reset, or power-cycle.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
if [ "$#" -lt 1 ]; then
  echo "usage: run_step6_master_last_ec1f25e8_postmortem.sh EXP-ID" >&2
  exit 2
fi
EXP_ID="$1"
QUARTUS_STP=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
PYTHON=python3
EXP_DIR="$ROOT/experiments/step6/$EXP_ID"
BASELINE_LOG="$ROOT/experiments/legacy/exp-step6-global-time/EXP-S6-MASTER-LAST-EC1F25E8-REBUILD-RECOVERY-ATTRIBUTION-20260921/raw/baseline/baseline.log"
POSTMORTEM_LOG="$EXP_DIR/raw/current/postmortem.log"

mkdir -p "$EXP_DIR/raw/current" "$EXP_DIR/raw/program" "$EXP_DIR/analysis"
cat > "$EXP_DIR/raw/protocol.txt" <<'EOF'
MASTER_COMPILE=NO
MASTER_PROGRAM=NO
SLAVE_COMPILE=NO
SLAVE_PROGRAM=NO
FIRMWARE_BUILD=NO
POWER_CYCLE=NO
PHY_RESET=NO
PTP_RESTART=NO
MODE_COMMAND=NO
FIBER_QSFP=NO
POLARITY_BITSLIP=NO
AUTONEG_SI5340_MDIO=NO
OBSERVATION=READ_ONLY
SAMPLE_COUNT=10
GAP_MS=250
EOF
printf 'RESULT=NOT_RUN\nMASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\n' \
  > "$EXP_DIR/raw/program/stop.txt"

if [ ! -s "$BASELINE_LOG" ]; then
  printf 'RESULT=INCONCLUSIVE\nSTOP_REASON=BASELINE_LOG_MISSING\n' \
    > "$EXP_DIR/raw/program/stop.txt"
  exit 3
fi

set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_master_last_ec1f25e8_rebuild_recovery.tcl" \
  "$EXP_ID" postmortem 10 250 10000 "$BASELINE_LOG" \
  > "$POSTMORTEM_LOG" 2>&1
observer_rc=$?
set -e

if ! grep -q '^POSTMORTEM_RESULT=' "$POSTMORTEM_LOG"; then
  printf 'RESULT=INCONCLUSIVE\nSTOP_REASON=POSTMORTEM_RESULT_MISSING\nOBSERVER_RC=%s\n' \
    "$observer_rc" > "$EXP_DIR/raw/program/stop.txt"
  exit 4
fi

if command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" "$ROOT/scripts/analysis/step6_master_last_ec1f25e8_postmortem.py" \
    "$BASELINE_LOG" "$POSTMORTEM_LOG" \
    --json-out "$EXP_DIR/analysis/summary.json" \
    > "$EXP_DIR/analysis/analyzer.txt"
fi

printf 'RESULT=OBSERVER_COMPLETE\nOBSERVER_RC=%s\n' "$observer_rc" \
  > "$EXP_DIR/raw/program/stop.txt"
exit "$observer_rc"
