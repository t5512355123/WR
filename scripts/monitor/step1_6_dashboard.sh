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

field_from_line() {
  local key="$1"
  local line="$2"
  local token
  for token in $line; do
    if [[ "$token" == "$key="* ]]; then
      printf '%s' "${token#*=}"
      return 0
    fi
  done
  printf 'N/A'
}

format_board() {
  local line="$1"
  local -A field=()
  local token key value
  for token in ${line#DASHBOARD_BOARD }; do
    [[ "$token" == "|" ]] && continue
    key="${token%%=*}"
    value="${token#*=}"
    field["$key"]="$value"
  done

  local board="${field[board]:-N/A}"
  local role="${field[role]:-UNKNOWN}"
  local time_valid="${field[TIME_VALID]:-0}"
  local pps_valid="${field[PPS_VALID]:-0}"
  local snapshot_valid="${field[SNAPSHOT_VALID]:-0}"
  local snapshot_stable="${field[SNAPSHOT_STABLE]:-0}"
  local global_state="WAITING"
  local global_reason="TIME_VALID=${time_valid}, PPS_VALID=${pps_valid}"
  if [[ "$time_valid" == "1" && "$pps_valid" == "1" &&
        "$snapshot_valid" == "1" && "$snapshot_stable" == "1" ]]; then
    global_state="VALID"
    global_reason="PPS snapshot valid and stable"
  fi

  printf '%s\n' '+------------------------------------------------------------+'
  printf '| %-8s %-47s |\n' "$role" "$board"
  printf '%s\n' '+------------------------------------------------------------+'
  printf '| %-28s %-27s |\n' "Step 1  PHY / Link" "${field[Step1]:-N/A}"
  printf '| %-28s %-27s |\n' "Step 2  Endpoint / PTP" "${field[Step2]:-N/A}"
  printf '| %-28s %-27s |\n' "Step 3  WR Handshake" "${field[Step3]:-N/A}"
  printf '| %-28s %-27s |\n' "Step 4  SoftPLL Startup" "${field[Step4]:-N/A}"
  printf '| %-28s %-27s |\n' "Step 5  Closed-loop Lock" "${field[Step5]:-N/A}"
  printf '| %-28s %-27s |\n' "Step 6  Global Time" "$global_state"
  printf '%s\n' '+------------------------------------------------------------+'
  printf '| %-28s Link=%s  TM=%s  RX=%s  TX=%s |\n' "Link health" \
    "${field[Link]:-N/A}" "${field[TM]:-N/A}" "${field[RX]:-N/A}" "${field[TX]:-N/A}"
  printf '| %-28s Helper=%s  MainFreq=%s  MainPhase=%s |\n' "Lock signals" \
    "${field[HelperLock]:-N/A}" "${field[MainFreq]:-N/A}" "${field[MainPhase]:-N/A}"
  printf '| %-28s MainLock=%s  PSTAT=%s             |\n' "" \
    "${field[MainLock]:-N/A}" "${field[PSTAT]:-N/A}"
  printf '| %-28s %-27s |\n' "Global-Time reason" "$global_reason"
  printf '| %-28s snapshot=%s stable=%s count=%s |\n' "Snapshot" \
    "${field[SNAPSHOT_VALID]:-N/A}" "${field[SNAPSHOT_STABLE]:-N/A}" \
    "${field[SNAPSHOT_COUNT]:-N/A}"
  printf '| %-28s %-27s |\n' "PPS registers" \
    "CR=${field[PPS_CR]:-N/A} EN=${field[PPS_CR_ENABLE]:-N/A} ESCR=${field[PPS_ESCR]:-N/A}"
  printf '| %-28s %-27s |\n' "PPS register validity" \
    "TM=${field[ESCR_TM_VALID]:-N/A} PPS=${field[ESCR_PPS_VALID]:-N/A}"
  printf '| %-28s %-27s |\n' "Step5 result" "${field[Step5Result]:-N/A}"
  printf '%s\n' '+------------------------------------------------------------+'
}

format_global_time_summary() {
  local line board role tai cycles time_valid pps_valid
  printf '\nGlobal Time summary (125 MHz reference; 1 cycle = 8 ns)\n'
  printf '%s\n' '------------------------------------------------------------'
  for line in "$@"; do
    board=$(field_from_line board "$line")
    role=$(field_from_line role "$line")
    tai=$(field_from_line TAI "$line")
    cycles=$(field_from_line CYCLES "$line")
    time_valid=$(field_from_line TIME_VALID "$line")
    pps_valid=$(field_from_line PPS_VALID "$line")
    if [[ "$time_valid" != "1" || "$pps_valid" != "1" ||
          "$tai" == "INVALID" || "$cycles" == "INVALID" ]]; then
      tai='--'
      cycles='--'
      printf '  %-7s (%s)\n' "$role" "$board"
      printf '    TAI=%-12s CYCLES=%-12s WAITING (%s, %s)\n' \
        "$tai" "$cycles" "TIME_VALID=$time_valid" "PPS_VALID=$pps_valid"
    else
      printf '  %-7s (%s)\n' "$role" "$board"
      printf '    TAI=%-12s CYCLES=%-12s VALID\n' "$tai" "$cycles"
    fi
  done
  printf '%s\n' '------------------------------------------------------------'
}

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
  board_lines=()
  while IFS= read -r line; do
    board_lines+=("$line")
  done < <(grep '^DASHBOARD_BOARD ' "$raw" || true)

  if [ "${#board_lines[@]}" -gt 0 ]; then
    for line in "${board_lines[@]}"; do
      format_board "$line"
    done
    format_global_time_summary "${board_lines[@]}"
    printf 'Dashboard read complete.\n'
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
