#!/usr/bin/env bash
# One fresh root replay of the requested historical /2+/12 controls.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
source scripts/build/current_experiment.env
test "$CURRENT_EXPERIMENT" = EXP-S6-WRH-RESTORE-ACQ2-TRACK12-TIME-VALID-20261004
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Another JTAG owner exists; stop without altering it.' >&2; exit 2
fi
RECORD="$ROOT/experiments/step6/$CURRENT_EXPERIMENT/raw/$(date -u +%Y%m%dT%H%M%SZ)-replay"
mkdir -p "$RECORD"
exec > >(tee "$RECORD/session.log") 2>&1
trap 'rc=$?; printf "RESTORED_REPLAY_EXIT=%s time=%s\n" "$rc" "$(date -Is)"' EXIT
printf 'RESTORED_REPLAY_BEGIN time=%s source=%s\n' "$(date -Is)" "$(git rev-parse HEAD)"
python3 -m unittest scripts.tests.test_current_experiment_source \
  scripts.tests.test_editable_current_workflow scripts.tests.test_step6_time_valid_300s \
  scripts.tests.test_post_settling_cko > "$RECORD/python-tests.log" 2>&1
bash scripts/tests/run_wrh_time_valid_baseline_c.sh | tee "$RECORD/native-c-tests.log"
# Existing main-root workflow. No SHA verification and no programming retry.
POST_PROGRAM_WAIT_S=60 ONCE=1 CLEAR_SCREEN=0 bash scripts/run_current.sh
# Keep other main pipelines out of the read-only qualification interval.
exec 9>"$ROOT/build/.current-pipeline.lock"
flock -n 9 || { echo 'Another main pipeline started; preserve this boot.' >&2; exit 2; }
set +e
TIME_VALID_ACQUISITION_TIMEOUT_S=900 bash scripts/monitor/verify_time_valid_300s.sh \
  2>&1 | tee "$RECORD/time-valid-verifier.log"
VERIFIER_RC=${PIPESTATUS[0]}
set -e
printf 'RESTORED_VERIFIER_EXIT=%s time=%s\n' "$VERIFIER_RC" "$(date -Is)"
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Another JTAG owner exists; skip final dashboard.' >&2
  exit 2
fi
ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$RECORD/dashboard-final.log"
cat "$RECORD/dashboard-final.log"
# Preserve failure even if the final dashboard reader succeeded.
exit "$VERIFIER_RC"
