#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 smoke|capture" >&2
  exit 2
fi

MODE="$1"
if [[ "$MODE" != "smoke" && "$MODE" != "capture" ]]; then
  echo "usage: $0 smoke|capture" >&2
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../../../" && pwd)
EXPERIMENT_DIR="$SCRIPT_DIR/.."
READER="$REPO_ROOT/artifacts/milestones/step6_global_time/source/scripts/jtag/read_wb_timeseries_session.tcl"
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
HARD_TIMEOUT=1800
MAX_RETRIES=2

if [[ "$MODE" == "smoke" ]]; then
  SAMPLES=5
else
  SAMPLES=60
fi

if [[ ! -x "$QUARTUS_STP" ]]; then
  echo "quartus_stp is not executable: $QUARTUS_STP" >&2
  exit 2
fi
if [[ ! -f "$READER" ]]; then
  echo "frozen reader is missing: $READER" >&2
  exit 2
fi

mkdir -p "$EXPERIMENT_DIR/raw/observe"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
LOG="$EXPERIMENT_DIR/raw/observe/${MODE}_${STAMP}.log"
if [[ -e "$LOG" ]]; then
  echo "refusing to overwrite existing evidence: $LOG" >&2
  exit 2
fi

set +e
{
  printf 'CAPTURE_META mode=%s samples_per_board=%s gap_ms=0 retries=%s hard_timeout_seconds=%s\n' \
    "$MODE" "$SAMPLES" "$MAX_RETRIES" "$HARD_TIMEOUT"
  printf 'CAPTURE_START_UTC=%s\n' "$(date -u --iso-8601=ns)"
  timeout --signal=INT --kill-after=20s "${HARD_TIMEOUT}s" \
    "$QUARTUS_STP" -t "$READER" "$SAMPLES" 0 "$MAX_RETRIES"
  rc=$?
  printf 'CAPTURE_END_UTC=%s\n' "$(date -u --iso-8601=ns)"
  printf 'CAPTURE_PROCESS_EXIT=%s\n' "$rc"
  exit "$rc"
} 2>&1 | while IFS= read -r line; do
  printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)" "$line"
done | tee "$LOG"
PIPE_RC=${PIPESTATUS[0]}
set -e

printf 'CAPTURE_LOG=%s\n' "$LOG"
exit "$PIPE_RC"
