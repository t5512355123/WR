#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
case "${CURRENT_EXPERIMENT_GROUP:-step6}" in step[1-7]) ;; *) echo 'Invalid CURRENT_EXPERIMENT_GROUP' >&2; exit 2 ;; esac
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
ACQUISITION_TIMEOUT_S=${TIME_VALID_ACQUISITION_TIMEOUT_S:-1800}
case "$ACQUISITION_TIMEOUT_S" in
  ''|*[!0-9]*) echo 'TIME_VALID_ACQUISITION_TIMEOUT_S must be a positive integer' >&2; exit 2 ;;
esac
[ "$ACQUISITION_TIMEOUT_S" -gt 0 ] || { echo 'Acquisition timeout must be positive' >&2; exit 2; }
if pgrep -x quartus_stp >/dev/null; then
  echo 'Stop the other JTAG reader first.' >&2; exit 2
fi
cd "$ROOT"
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
BASE="experiments/${CURRENT_EXPERIMENT_GROUP:-step6}/$CURRENT_EXPERIMENT"
mkdir -p "$BASE/raw/observe" "$BASE/analysis"
LOG="$BASE/raw/observe/$RUN_TAG-current-time-valid-303s.log"
RESULT="$BASE/analysis/$RUN_TAG-current-time-valid-300s.json"
# Wait for acquisition, saving every poll. A timeout is not a PASS.
SECONDS=0
READY=0
while [ "$SECONDS" -lt "$ACQUISITION_TIMEOUT_S" ]; do
  POLL="$BASE/raw/observe/$RUN_TAG-ready-$SECONDS.log"
  timeout --signal=INT --kill-after=3s 25s "$QUARTUS_STP" -t \
    scripts/jtag/read_step6_global_time_observability.tcl 1000 250 "" > "$POLL" 2>&1
  if grep -q '^GLOBAL_TIME_ERROR ' "$POLL"; then
    echo "Readiness transport error: $POLL" >&2; exit 2
  fi
  READY=1
  for board in 1-11.1 1-11.2; do
    rows=$(grep -F "GLOBAL_TIME_SAMPLE board=DE5 [$board]" "$POLL" || true)
    if [ -z "$rows" ] || printf '%s\n' "$rows" | grep -vq 'STATUS_TIME_VALID=1'; then
      READY=0
    fi
    grep -Fq "GLOBAL_TIME_DONE board=DE5 [$board]" "$POLL" || READY=0
  done
  [ "$READY" -eq 1 ] && break
  printf 'TIME_VALID_WAIT elapsed_s=%d/%d poll=%s\n' "$SECONDS" "$ACQUISITION_TIMEOUT_S" "$POLL"
  sleep 10
done
[ "$READY" -eq 1 ] || { echo 'TIME_VALID acquisition timeout; evidence saved.' >&2; exit 1; }
# Boards are observed sequentially; each gets a complete 303-second window.
timeout --signal=INT --kill-after=5s 900s "$QUARTUS_STP" -t \
  scripts/jtag/read_step6_global_time_observability.tcl 303000 250 "" > "$LOG" 2>&1
sha256sum "$LOG" > "$LOG.sha256"
printf 'TIME_VALID_CAPTURE_PATH=%s\nTIME_VALID_RESULT_PATH=%s\n' "$LOG" "$RESULT"
ANALYZER_RC=0
python3 scripts/analysis/step6_time_valid_300s.py "$LOG" \
  --required-duration-ms 300000 --max-sample-gap-ms 1000 \
  --minimum-samples 301 --boards 1-11.1,1-11.2 > "$RESULT" || ANALYZER_RC=$?
cat "$RESULT"
sha256sum "$RESULT" > "$RESULT.sha256"
exit "$ANALYZER_RC"
