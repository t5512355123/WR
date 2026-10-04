#!/usr/bin/env bash
# Continue the completed run_current.sh session, never program again here.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
source scripts/build/current_experiment.env
test "$CURRENT_EXPERIMENT" = EXP-S6-WRH-ACQ24-TRACK24-15MIN-SETTLING-20261004
PIPELINE=$(realpath "${1:?Pass the completed pipeline directory}")
case "$PIPELINE" in "$ROOT/experiments/step6/$CURRENT_EXPERIMENT/raw/pipeline/"*) ;; *) exit 2 ;; esac
grep -q '^CURRENT_PROGRAM_COMPLETED .*wait_s=900$' "$PIPELINE/pipeline.log"
settling_elapsed=$(sed -n 's/^POST_PROGRAM_SETTLING_DONE elapsed_s=\([0-9][0-9]*\) .*/\1/p' "$PIPELINE/pipeline.log")
case "$settling_elapsed" in ''|*[!0-9]*) exit 2 ;; esac
test "$settling_elapsed" -ge 900
grep -q '^CURRENT_PIPELINE_EXIT=0 ' "$PIPELINE/pipeline.log"
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Another JTAG reader/programmer is running.' >&2; exit 2
fi
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
RECORD="$ROOT/experiments/step6/$CURRENT_EXPERIMENT"
test ! -e "$RECORD/raw/after-settling-session.log"
exec > >(tee "$RECORD/raw/after-settling-session.log") 2>&1
trap 'rc=$?; printf "POST_SETTLING_OBSERVATION_EXIT=%s time=%s\n" "$rc" "$(date -Is)"' EXIT
mkdir -p "$RECORD/raw/observe" "$RECORD/analysis"
printf 'POST_SETTLING_OBSERVATION_BEGIN time=%s no_reprogram=1\n' "$(date -Is)"
timeout --signal=INT --kill-after=5s 65s "$QUARTUS_STP" -t \
  scripts/jtag/read_step6_servo_interleaved_offset.tcl 20000 500 1-11.2 1 \
  > "$RECORD/raw/observe/smoke.log" 2>&1
python3 scripts/analysis/step6_post_settling_cko.py "$RECORD/raw/observe/smoke.log" \
  --required-duration-ms 10000 > "$RECORD/analysis/smoke.json"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print("POST_SETTLING_SMOKE="+str(r["capture_complete"])); sys.exit(0 if r["capture_complete"] else 2)' "$RECORD/analysis/smoke.json"
timeout --signal=INT --kill-after=5s 365s "$QUARTUS_STP" -t \
  scripts/jtag/read_step6_servo_interleaved_offset.tcl 303000 500 1-11.2 1 \
  > "$RECORD/raw/observe/cko-303s.log" 2>&1
python3 scripts/analysis/step6_post_settling_cko.py "$RECORD/raw/observe/cko-303s.log" \
  > "$RECORD/analysis/cko-300s.json"
cat "$RECORD/analysis/cko-300s.json"
ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$RECORD/raw/observe/dashboard-after-cko.log"
cat "$RECORD/raw/observe/dashboard-after-cko.log"
# Only attempt TIME_VALID retention if every trusted phase row is already valid.
# No further acquisition retry here: this round already allowed 15 minutes.
if python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["capture_complete"] and r["time_valid_unique_rows"]==r["unique_update_rows"] else 1)' "$RECORD/analysis/cko-300s.json"; then
  TIME_VALID_ACQUISITION_TIMEOUT_S=30 bash scripts/monitor/verify_time_valid_300s.sh \
    | tee "$RECORD/raw/observe/time-valid-verifier.log"
else
  echo 'TIME_VALID_300S=NOT_RUN_NOT_VALID_AFTER_15MIN_AND_CKO_CAPTURE'
fi
echo 'POST_SETTLING_OBSERVATION_DONE no_reprogram=1'
