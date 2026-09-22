#!/usr/bin/env bash
set -euo pipefail

# Continuously display the read-only Step 1..6 dashboard for every DE5a JTAG
# target visible to Quartus.  No FPGA, Wishbone, target, or ARM writes occur.
#
# Usage:
#   ./scripts/monitor/step1_6_dashboard.sh
#   INTERVAL_SECONDS=5 OBS_GAP_MS=1000 ./scripts/monitor/step1_6_dashboard.sh
#   ONCE=1 ./scripts/monitor/step1_6_dashboard.sh

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
INTERVAL_SECONDS=${INTERVAL_SECONDS:-10}
OBS_GAP_MS=${OBS_GAP_MS:-2000}
ONCE=${ONCE:-0}
CLEAR_SCREEN=${CLEAR_SCREEN:-1}

test -x "$QUARTUS_STP"
case "$INTERVAL_SECONDS" in
  ''|*[!0-9]*) echo "INTERVAL_SECONDS must be a non-negative integer" >&2; exit 2 ;;
esac
case "$OBS_GAP_MS" in
  ''|*[!0-9]*) echo "OBS_GAP_MS must be a non-negative integer" >&2; exit 2 ;;
esac

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/wr-step1-6-dashboard.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

while :; do
  cycle_start=$(date +%s)
  raw="$TMP_DIR/capture.log"
  set +e
  "$QUARTUS_STP" -t "$ROOT/scripts/jtag/read_step1_6_dashboard.tcl" \
    "$OBS_GAP_MS" >"$raw" 2>&1
  quartus_rc=$?
  set -e

  if [ "$CLEAR_SCREEN" = "1" ] && [ -t 1 ]; then
    printf '\033[2J\033[H'
  fi
  printf 'White Rabbit Step 1-6 dashboard  %s  (read-only)\n' "$(date -Is)"
  printf 'Sampling interval: %ss; per-board comparison window: %sms\n\n' \
    "$INTERVAL_SECONDS" "$OBS_GAP_MS"
  if grep -q '^DASHBOARD_' "$raw"; then
    grep '^DASHBOARD_' "$raw"
  else
    printf 'DASHBOARD_ERROR quartus_stp_rc=%s\n' "$quartus_rc"
    tail -20 "$raw"
  fi

  if [ "$ONCE" = "1" ]; then
    if [ "$quartus_rc" -ne 0 ]; then
      exit "$quartus_rc"
    fi
    exit 0
  fi

  cycle_now=$(date +%s)
  elapsed=$((cycle_now - cycle_start))
  sleep_for=$((INTERVAL_SECONDS - elapsed))
  if [ "$sleep_for" -gt 0 ]; then
    sleep "$sleep_for"
  fi
done
