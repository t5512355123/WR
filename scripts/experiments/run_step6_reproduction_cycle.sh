#!/usr/bin/env bash
# One complete independent root build -> compile -> program -> qualification.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
case "${1:-}" in cycle1|cycle2) cycle=$1 ;; *) echo 'Usage: run_step6_reproduction_cycle.sh cycle1|cycle2' >&2; exit 2 ;; esac
cd "$ROOT"
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Another JTAG reader/programmer is running; stop it first.' >&2; exit 2
fi
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
RECORD="experiments/step6/$CURRENT_EXPERIMENT/raw/cycles/$RUN_TAG-$cycle"
mkdir -p "$RECORD"
exec > >(tee "$RECORD/cycle.log") 2>&1
printf 'CYCLE_BEGIN cycle=%s root=%s source=%s time=%s\n' "$cycle" "$ROOT" "$(git rev-parse HEAD)" "$(date -Is)"
git rev-parse HEAD > "$RECORD/source-commit.txt"
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
cp output/SHA256SUMS "$RECORD/sof.sha256"
cp output/SOURCE_COMMIT "$RECORD/compiled-commit.txt"
cp output/SOURCE_SHA256SUMS "$RECORD/compile-inputs.sha256"
cp output/build_info_master.txt output/build_info_slave.txt "$RECORD/"
cp output/DE5a_wr_master_jtag.sof "$RECORD/master.sof"
cp output/DE5a_wr_slave_jtag.sof "$RECORD/slave.sof"
bash scripts/program/program_current.sh
ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$RECORD/dashboard-before.log"
cat "$RECORD/dashboard-before.log"
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
"$QUARTUS_STP" -t scripts/jtag/read_step6_helper_passive.tcl 3 250 > "$RECORD/helper-before.log" 2>&1
bash scripts/monitor/verify_time_valid_300s.sh | tee "$RECORD/time-valid-verifier.log"
capture=$(sed -n 's/^TIME_VALID_CAPTURE_PATH=//p' "$RECORD/time-valid-verifier.log")
result=$(sed -n 's/^TIME_VALID_RESULT_PATH=//p' "$RECORD/time-valid-verifier.log")
test -f "$capture" && test -f "$result"
cp "$capture" "$RECORD/qualified-capture.log"
cp "$result" "$RECORD/qualified-result.json"
ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$RECORD/dashboard-after.log"
cat "$RECORD/dashboard-after.log"
"$QUARTUS_STP" -t scripts/jtag/read_step6_helper_passive.tcl 3 250 > "$RECORD/helper-after.log" 2>&1
printf 'CYCLE_END cycle=%s result=TIME_VALID_CAPTURE_PASSED time=%s\n' "$cycle" "$(date -Is)"
# Do not claim two-cycle success here: both records need an independent audit.
