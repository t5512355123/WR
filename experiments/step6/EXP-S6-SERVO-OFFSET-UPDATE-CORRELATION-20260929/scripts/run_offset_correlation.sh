#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ( "$1" != "smoke" && "$1" != "capture" ) ]]; then
  echo "usage: $0 smoke|capture" >&2
  exit 2
fi
MODE="$1"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
EXPERIMENT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
READER="$SCRIPT_DIR/read_slave_offset_update_correlation.tcl"
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
MAX_RETRIES=2
HARD_TIMEOUT=900

if [[ ! -x "$QUARTUS_STP" || ! -f "$READER" ]]; then
  echo "quartus_stp or correlation reader is unavailable" >&2
  exit 2
fi
if [[ -n "$(pgrep -af '[q]uartus_stp|[q]uartus_pgm|[r]un_step1_6_dashboard' || true)" ]]; then
  echo "refusing to compete with an active Quartus/JTAG/dashboard process" >&2
  pgrep -af '[q]uartus_stp|[q]uartus_pgm|[r]un_step1_6_dashboard' >&2 || true
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
  printf 'CORR_CAPTURE_META mode=%s retries=%s hard_timeout_seconds=%s\n' \
    "$MODE" "$MAX_RETRIES" "$HARD_TIMEOUT"
  printf 'CORR_CAPTURE_START_UTC=%s\n' "$(date -u --iso-8601=ns)"
  timeout --signal=INT --kill-after=20s "${HARD_TIMEOUT}s" \
    "$QUARTUS_STP" -t "$READER" "$MODE" "$MAX_RETRIES"
  rc=$?
  printf 'CORR_CAPTURE_END_UTC=%s\n' "$(date -u --iso-8601=ns)"
  printf 'CAPTURE_PROCESS_EXIT=%s\n' "$rc"
  exit "$rc"
} 2>&1 | while IFS= read -r line; do
  printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)" "$line"
done | tee "$LOG"
PIPE_RC=${PIPESTATUS[0]}
set -e

printf 'CORR_CAPTURE_LOG=%s\n' "$LOG"
exit "$PIPE_RC"
