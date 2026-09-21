#!/usr/bin/env bash
# Run EXP-S6-GLOBAL-TIME-RECOVERED-LINK-REVALIDATION-20260922.
# Read-only observer: no compile, firmware build, programming, reset, or
# power-cycle is permitted by the experiment contract.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
if [ "$#" -lt 1 ]; then
  echo "usage: run_step6_global_time_recovered_link_revalidation.sh EXP-ID" >&2
  exit 2
fi
EXP_ID="$1"
QUARTUS_STP=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
PYTHON=python3
EXP_DIR="$ROOT/docs/experiments/exp-step6-global-time/$EXP_ID"
CAPTURE="$EXP_DIR/raw/observe/revalidation.log"

mkdir -p "$EXP_DIR/raw/observe" "$EXP_DIR/raw/program" "$EXP_DIR/analysis"
cat > "$EXP_DIR/raw/protocol.txt" <<'EOF'
MASTER_COMPILE=NO
SLAVE_COMPILE=NO
FIRMWARE_BUILD=NO
MASTER_PROGRAM=NO
SLAVE_PROGRAM=NO
POWER_CYCLE=NO
PHY_RESET=NO
PTP_RESTART=NO
MODE_COMMAND=NO
FIBER_QSFP=NO
POLARITY_BITSLIP=NO
AUTONEG_SI5340_MDIO=NO
OBSERVATION=READ_ONLY
PREFLIGHT_PAIRED_SAMPLES=5
OBSERVATION_DURATION_MS=8000
GAP_MS=250
EOF
printf 'MASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\n' > "$EXP_DIR/raw/program/stop.txt"

set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_global_time_recovered_link_revalidation.tcl" \
  "$EXP_ID" 5 250 8000 > "$CAPTURE" 2>&1
observer_rc=$?
set -e

if ! grep -q '^GLOBAL_TIME_REVALIDATION_DONE ' "$CAPTURE"; then
  printf 'RESULT=INCONCLUSIVE_RUNTIME_STATE_CHANGED\nSTOP_REASON=OBSERVER_RESULT_MISSING\nOBSERVER_RC=%s\n' "$observer_rc" > "$EXP_DIR/raw/program/stop.txt"
  exit 3
fi

if command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" \
    "$ROOT/scripts/analysis/step6_global_time_recovered_link_revalidation.py" \
    "$CAPTURE" --json-out "$EXP_DIR/analysis/summary.json" \
    > "$EXP_DIR/analysis/analyzer.txt"
fi

printf 'RESULT=OBSERVER_COMPLETE\nOBSERVER_RC=%s\n' "$observer_rc" > "$EXP_DIR/raw/program/stop.txt"
exit "$observer_rc"
