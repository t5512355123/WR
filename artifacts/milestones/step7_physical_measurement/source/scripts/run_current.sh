#!/usr/bin/env bash
# Edit main code, then one command: firmware -> Quartus -> program -> dashboard.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
source scripts/build/current_experiment.env
POST_PROGRAM_WAIT_S=${POST_PROGRAM_WAIT_S:-0}
case "$POST_PROGRAM_WAIT_S" in ''|*[!0-9]*) echo 'POST_PROGRAM_WAIT_S must be non-negative integer' >&2; exit 2 ;; esac
mkdir -p "$ROOT/build"
exec 9>"$ROOT/build/.current-pipeline.lock"
flock -n 9 || { echo 'Another main-root pipeline is still running.' >&2; exit 2; }
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other JTAG dashboard/reader/programmer first.' >&2; exit 2
fi
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
RECORD="$ROOT/experiments/step6/$CURRENT_EXPERIMENT/raw/pipeline/$RUN_TAG"
mkdir -p "$RECORD"
exec > >(tee "$RECORD/pipeline.log") 2>&1
trap 'rc=$?; printf "CURRENT_PIPELINE_EXIT=%s time=%s\n" "$rc" "$(date -Is)"' EXIT
printf 'CURRENT_PIPELINE_BEGIN root=%s time=%s\n' "$ROOT" "$(date -Is)"
printf 'CURRENT_PIPELINE_RECORD=%s\n' "$RECORD"
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
bash scripts/program/program_current.sh
date -Is > "$RECORD/program-completed.txt"
printf 'CURRENT_PROGRAM_COMPLETED time=%s wait_s=%s\n' "$(date -Is)" "$POST_PROGRAM_WAIT_S"
# Wait only after actual successful programming. No reset, retry or tuning.
SECONDS=0
while [ "$SECONDS" -lt "$POST_PROGRAM_WAIT_S" ]; do
  printf 'POST_PROGRAM_SETTLING elapsed_s=%s/%s time=%s\n' "$SECONDS" "$POST_PROGRAM_WAIT_S" "$(date -Is)"
  remaining=$((POST_PROGRAM_WAIT_S - SECONDS))
  sleep_for=30
  if [ "$remaining" -lt "$sleep_for" ]; then sleep_for=$remaining; fi
  sleep "$sleep_for"
done
printf 'POST_PROGRAM_SETTLING_DONE elapsed_s=%s time=%s\n' "$SECONDS" "$(date -Is)"
bash scripts/monitor/step1_6_dashboard.sh
