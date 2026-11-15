#!/usr/bin/env bash
# Read-only Slave CKO capture + strict hold analysis (entry <60 ps, retain <=120 ps).
# Usage: DURATION_MS=300000 bash scripts/monitor/capture_cko_hold.sh
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
source scripts/build/current_experiment.env
DURATION_MS=${DURATION_MS:-300000}
SAMPLE_MS=${SAMPLE_MS:-250}
HOLD_S=${HOLD_S:-120}
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Another JTAG owner is active.' >&2; exit 2
fi
TAG=$(date -u +%Y%m%dT%H%M%SZ)
BASE="experiments/${CURRENT_EXPERIMENT_GROUP:-step7}/$CURRENT_EXPERIMENT"
mkdir -p "$BASE/raw/cko" "$BASE/analysis"
LOG="$BASE/raw/cko/$TAG-cko.log"; RESULT="$BASE/analysis/$TAG-cko-hold.json"
LIMIT_S=$(( (DURATION_MS + 999)/1000 + 90 ))
RC=0
timeout --signal=INT --kill-after=5s "${LIMIT_S}s" "$QUARTUS_STP" -t \
  scripts/jtag/read_step6_servo_interleaved_offset.tcl "$DURATION_MS" "$SAMPLE_MS" 1-11.2 2 > "$LOG" 2>&1 || RC=$?
sha256sum "$LOG" > "$LOG.sha256"
ARC=0
python3 scripts/analysis/cko_hold.py "$LOG" --hold-s "$HOLD_S" > "$RESULT" || ARC=$?
sha256sum "$RESULT" > "$RESULT.sha256"
cat "$RESULT"
printf 'CKO_READER_EXIT=%s CKO_RAW=%s CKO_RESULT=%s\n' "$RC" "$LOG" "$RESULT"
exit "$ARC"
