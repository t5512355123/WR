#!/usr/bin/env bash
# Run EXP-S6-WR-EXTENSION-FALLBACK-TERMINAL-LIVENESS-20260922.
#
# This experiment is read-only by contract: no compile, firmware build,
# programming, reset, PTP restart, mode command, or power-cycle.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
if [ "$#" -lt 1 ]; then
  echo "usage: run_step6_wr_extension_fallback_terminal_liveness.sh EXP-ID" >&2
  exit 2
fi
EXP_ID="$1"
QUARTUS_STP=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
PYTHON=python3
EXP_DIR="$ROOT/experiments/step6/$EXP_ID"
CAPTURE="$EXP_DIR/raw/observe/fallback_liveness.log"

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
OBSERVATION_DURATION_MS=15000
CAPTURE_GAP_MS=350
EOF
printf 'MASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\nRESET_COUNT=0\n' > "$EXP_DIR/raw/program/stop.txt"

set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_wr_extension_fallback_terminal_liveness.tcl" \
  "$EXP_ID" 5 250 15000 350 > "$CAPTURE" 2>&1
observer_rc=$?
set -e

if ! grep -q '^WR_FALLBACK_LIVENESS_DONE ' "$CAPTURE"; then
  printf 'RESULT=INCONCLUSIVE_RUNTIME_STATE_CHANGED\nSTOP_REASON=OBSERVER_RESULT_MISSING\nOBSERVER_RC=%s\n' "$observer_rc" > "$EXP_DIR/raw/program/stop.txt"
  exit 3
fi

if command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" \
    "$ROOT/scripts/analysis/step6_wr_extension_fallback_terminal_liveness.py" \
    "$CAPTURE" --json-out "$EXP_DIR/analysis/summary.json" \
    > "$EXP_DIR/analysis/analyzer.txt"
fi

printf 'RESULT=OBSERVER_COMPLETE\nOBSERVER_RC=%s\n' "$observer_rc" > "$EXP_DIR/raw/program/stop.txt"
exit "$observer_rc"
