#!/usr/bin/env bash
# One bounded read-only continuation of the SAME freshly programmed session.
# Keep the original acquisition timeout; never reclassify it as a first-run PASS.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
source scripts/build/current_experiment.env
test "$(basename "$ROOT")" = source
test "$(basename "$(dirname "$ROOT")")" = step6_global_time
CYCLE=$(realpath "${1:?Pass the timed-out cycle directory}")
case "$CYCLE" in "$ROOT/experiments/step6/$CURRENT_EXPERIMENT/raw/cycles/"*) ;; *) exit 2 ;; esac
grep -Fx 'CURRENT_PROGRAM=PASS order=slave,master' "$CYCLE/cycle.log" >/dev/null
grep -Fx 'TIME_VALID acquisition timeout; evidence saved.' "$CYCLE/cycle.log" >/dev/null
! grep -q '^CYCLE_END ' "$CYCLE/cycle.log"
sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
sha256sum -c output/SHA256SUMS
cmp "$CYCLE/master.sof" output/DE5a_wr_master_jtag.sof
cmp "$CYCLE/slave.sof" output/DE5a_wr_slave_jtag.sof
git diff --quiet "$(cat output/SOURCE_COMMIT)" -- firmware vendor quartus quartus_generated
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Another JTAG owner is running.' >&2; exit 2
fi
exec > >(tee -a "$CYCLE/cycle.log") 2>&1
printf 'CYCLE_CONTINUATION initial_acquisition=TIMEOUT unchanged_program=1 time=%s\n' "$(date -Is)"
TIME_VALID_ACQUISITION_TIMEOUT_S=600 bash scripts/monitor/verify_time_valid_300s.sh \
  | tee "$CYCLE/continuation-verifier.log"
capture=$(sed -n 's/^TIME_VALID_CAPTURE_PATH=//p' "$CYCLE/continuation-verifier.log")
result=$(sed -n 's/^TIME_VALID_RESULT_PATH=//p' "$CYCLE/continuation-verifier.log")
test -f "$capture" && test -f "$result"
cp "$capture" "$CYCLE/qualified-capture.log"
cp "$result" "$CYCLE/qualified-result.json"
ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$CYCLE/dashboard-after.log"
cat "$CYCLE/dashboard-after.log"
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
"$QUARTUS_STP" -t scripts/jtag/read_step6_helper_passive.tcl 3 250 > "$CYCLE/helper-after.log" 2>&1
printf 'CYCLE_END cycle=cycle1 result=TIME_VALID_CAPTURE_PASSED initial_acquisition=TIMEOUT continuation=PASS time=%s\n' "$(date -Is)"
