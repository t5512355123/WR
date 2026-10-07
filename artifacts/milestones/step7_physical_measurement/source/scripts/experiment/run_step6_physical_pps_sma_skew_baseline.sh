#!/usr/bin/env bash
# Run the read-only current-session gate for the physical PPS/SMA baseline.
# The oscilloscope acquisition is deliberately external and is not automated
# by this script. No compile, programming, reset, PTP command, or power-cycle.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
if [ "$#" -lt 2 ]; then
  echo "usage: run_step6_physical_pps_sma_skew_baseline.sh EXP-ID pre|post" >&2
  exit 2
fi
EXP_ID="$1"
PHASE="$2"
case "$PHASE" in
  pre|post) ;;
  *) echo "phase must be pre or post" >&2; exit 2 ;;
esac

QUARTUS_STP=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
PYTHON=python3
EXP_DIR="$ROOT/experiments/step6/$EXP_ID"
RAW_DIR="$EXP_DIR/raw/$PHASE"
CAPTURE="$RAW_DIR/gate.log"
SUMMARY="$EXP_DIR/analysis/${PHASE}-gate.json"
ANALYZER="$ROOT/scripts/analysis/step6_physical_pps_sma_gate.py"

mkdir -p "$RAW_DIR" "$EXP_DIR/analysis"
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
TARGET_WRITE=NO
ARM_WRITE=NO
FIBER_QSFP_CHANGE=NO
AUTONEG_CHANGE=NO
SI5340_CHANGE=NO
MDIO_WRITE=NO
SMA_LOGIC_CHANGE=NO
OBSERVATION=READ_ONLY_PHYSICAL_PPS_PRE_POST_GATE
GATE_SAMPLES=3
REQUIRED_COMMON_TAI_LABELS=2
EOF

set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_same_pps_global_time_consistency.tcl" \
  "${EXP_ID}-${PHASE}-gate" 3 350 1 0 > "$CAPTURE" 2>&1
observer_rc=$?
set -e

set +e
"$PYTHON" "$ANALYZER" "$CAPTURE" --json-out "$SUMMARY" \
  > "$EXP_DIR/analysis/${PHASE}-gate-analyzer.txt"
analysis_rc=$?
set -e

if grep -q '"verdict": "PASS"' "$SUMMARY"; then
  result=PASS_PHYSICAL_PPS_PRECONDITION
else
  if [ "$PHASE" = "pre" ]; then
    result=INCONCLUSIVE_PHYSICAL_PPS_PRECONDITION_CHANGED
  else
    result=INCONCLUSIVE_STEP6A_STATE_CHANGED_DURING_PHYSICAL_MEASUREMENT
  fi
fi
cat > "$EXP_DIR/raw/${PHASE}-stop.txt" <<EOF
RESULT=$result
OBSERVER_RC=$observer_rc
ANALYZER_RC=$analysis_rc
TARGET_WRITE_COUNT=0
ARM_WRITE_COUNT=0
PROGRAM_COUNT=0
POWER_CYCLE=0
EOF
exit "$analysis_rc"
