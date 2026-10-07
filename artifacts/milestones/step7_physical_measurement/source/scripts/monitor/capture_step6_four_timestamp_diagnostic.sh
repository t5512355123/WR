#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other JTAG reader/programmer first.' >&2; exit 2
fi
cd "$ROOT"
sha256sum -c output/SHA256SUMS
sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
BASE="experiments/step6/$CURRENT_EXPERIMENT"
mkdir -p "$BASE/raw/observe" "$BASE/analysis"
LOG="$BASE/raw/observe/$RUN_TAG-four-timestamps.log"
RESULT="$BASE/analysis/$RUN_TAG-four-timestamps.json"
echo "TS4_LOG=$LOG"
set +e
timeout --signal=INT --kill-after=5s 370s "$QUARTUS_STP" -t \
  scripts/jtag/read_step6_four_timestamp_diagnostic.tcl > "$LOG" 2>&1
RC=$?
set -e
sha256sum "$LOG" > "$LOG.sha256"
if [ "$RC" -ne 0 ]; then echo "TS4_CAPTURE_FAILED rc=$RC"; exit 2; fi
set +e
python3 scripts/analysis/step6_four_timestamps.py "$LOG" > "$RESULT"
RC=$?
set -e
cat "$RESULT"
sha256sum "$RESULT" > "$RESULT.sha256"
exit "$RC"
