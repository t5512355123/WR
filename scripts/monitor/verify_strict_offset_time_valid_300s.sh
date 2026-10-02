#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
DURATION_MS=${DURATION_MS:-660000}
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other JTAG reader/programmer first.' >&2; exit 2
fi
cd "$ROOT"
sha256sum -c output/SHA256SUMS
sha256sum -c output/SOURCE_SHA256SUMS > /dev/null
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
BASE="experiments/step6/$CURRENT_EXPERIMENT"
mkdir -p "$BASE/raw/observe" "$BASE/analysis"
LOG="$BASE/raw/observe/$RUN_TAG-strict-offset-validity.log"
RESULT="$BASE/analysis/$RUN_TAG-strict-offset-300s.json"
echo "STRICT_CAPTURE_PATH=$LOG"
echo "STRICT_RESULT_PATH=$RESULT"
# This includes bounded acquisition and dwell. A timeout/ended reader is not PASS.
set +e
timeout --signal=INT --kill-after=5s "$((DURATION_MS/1000+60))s" "$QUARTUS_STP" -t \
  scripts/jtag/read_step6_strict_offset_validity.tcl "$DURATION_MS" 250 1-11.2 > "$LOG" 2>&1
CAPTURE_RC=$?
set -e
sha256sum "$LOG" > "$LOG.sha256"
if [ "$CAPTURE_RC" -ne 0 ]; then
  echo "Strict capture failed rc=$CAPTURE_RC; raw evidence saved: $LOG" >&2; exit 2
fi
set +e
python3 scripts/analysis/step6_strict_offset_300s.py "$LOG" > "$RESULT"
VERDICT_RC=$?
set -e
cat "$RESULT"
sha256sum "$RESULT" > "$RESULT.sha256"
exit "$VERDICT_RC"
