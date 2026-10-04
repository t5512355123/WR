#!/usr/bin/env bash
# One read-only CKO diagnostic; no firmware build/program/reset/control writes.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
source scripts/build/current_experiment.env
test "$CURRENT_EXPERIMENT" = EXP-S6-WRH-NO-PHASE-CORRECTION-CKO-OBSERVATION-20261004
DURATION_MS=${DURATION_MS:-303000}
SAMPLE_MS=${SAMPLE_MS:-500}
case "$DURATION_MS:$SAMPLE_MS" in *[!0-9:]*|:*|*:) echo 'Duration/sample must be positive integers' >&2; exit 2;; esac
test "$DURATION_MS" -ge 10000 && test "$DURATION_MS" -le 900000 && test "$SAMPLE_MS" -gt 0
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other dashboard/JTAG reader first; no process will be terminated.' >&2; exit 2
fi
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
test -x "$QUARTUS_STP"
TAG=$(date -u +%Y%m%dT%H%M%SZ)
BASE="experiments/step6/$CURRENT_EXPERIMENT"
mkdir -p "$BASE/raw/observe" "$BASE/analysis"
LOG="$BASE/raw/observe/$TAG-cko.log"
RESULT="$BASE/analysis/$TAG-cko.json"
echo "CKO_DIAGNOSTIC_REQUESTED=no_WR_phase_correction loaded_mode_not_automatically_verified=1 source=$(git rev-parse HEAD)"
echo 'Use only after successful fresh build/compile/program; this script cannot identify loaded firmware by itself.'
LIMIT_S=$(( (DURATION_MS + 999)/1000 + 60 ))
READER_RC=0
timeout --signal=INT --kill-after=5s "${LIMIT_S}s" "$QUARTUS_STP" -t \
  scripts/jtag/read_step6_servo_interleaved_offset.tcl "$DURATION_MS" "$SAMPLE_MS" 1-11.2 2 \
  > "$LOG" 2>&1 || READER_RC=$?
# Always preserve and analyze a stopped/failed capture; never label it PASS.
REQUIRED_MS=$((DURATION_MS - 3000))
python3 scripts/analysis/step6_post_settling_cko.py "$LOG" --required-duration-ms "$REQUIRED_MS" > "$RESULT"
printf 'CKO_READER_EXIT=%s\nCKO_RAW=%s\nCKO_RESULT=%s\n' "$READER_RC" "$LOG" "$RESULT"
cat "$RESULT"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); n=r["unique_update_rows"]; fixed=n>0 and r["setp_min_ps"]==r["setp_max_ps"]; fine=n>0 and set(r["state_counts"]) <= {"SYNC_PHASE","TRACK_PHASE","WAIT_OFFSET_STABLE"}; print("SAMPLED_SETP_CONSTANT="+str(fixed)+" ALL_ACCEPTED_STATES_FINE="+str(fine)+" PHYSICAL_JITTER_NOT_MEASURED=1"); sys.exit(0 if r["diagnostic_capture_complete"] and fixed and r["healthy_unique_rows"]==n else 2)' "$RESULT" || exit 2
exit "$READER_RC"
