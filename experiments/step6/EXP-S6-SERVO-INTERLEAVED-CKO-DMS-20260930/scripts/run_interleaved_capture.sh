#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ( "$1" != "smoke" && "$1" != "capture" ) ]]; then
  echo "usage: $0 smoke|capture" >&2
  exit 2
fi
MODE="$1"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
EXPERIMENT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
ROOT=$(cd "$SCRIPT_DIR/../../../.." && pwd)
READER="$ROOT/scripts/jtag/read_step6_servo_interleaved_offset.tcl"
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
SAMPLE_MS=${SAMPLE_MS:-500}
HARD_TIMEOUT=${HARD_TIMEOUT:-900}
if [[ "$MODE" == "smoke" ]]; then
  DURATION_MS=${DURATION_MS:-15000}
else
  DURATION_MS=${DURATION_MS:-300000}
fi

if [[ ! -x "$QUARTUS_STP" || ! -f "$READER" ]]; then
  echo "quartus_stp or interleaved observer is unavailable" >&2
  exit 2
fi
if [[ -n "$(pgrep -af '[q]uartus_stp|[q]uartus_pgm|[s]tep1_6_dashboard.sh' || true)" ]]; then
  echo "refusing to compete with an active Quartus/JTAG/dashboard process" >&2
  pgrep -af '[q]uartus_stp|[q]uartus_pgm|[s]tep1_6_dashboard.sh' >&2 || true
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
  printf 'S6_INTERLEAVED_RUN mode=%s duration_ms=%s sample_ms=%s hard_timeout_seconds=%s board=DE5_1-11.2\n' \
    "$MODE" "$DURATION_MS" "$SAMPLE_MS" "$HARD_TIMEOUT"
  printf 'CAPTURE_START_UTC=%s\n' "$(date -u --iso-8601=ns)"
  timeout --signal=INT --kill-after=20s "${HARD_TIMEOUT}s" \
    "$QUARTUS_STP" -t "$READER" "$DURATION_MS" "$SAMPLE_MS" '1-11.2'
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
