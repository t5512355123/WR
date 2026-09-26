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
# When non-zero, a one-shot/read cycle waits for every visible board to expose
# a coherent, valid Global-Time snapshot before printing the final dashboard.
# This is deliberately a read-only presentation gate; it does not reset,
# program, or write to either FPGA.
WAIT_FOR_GLOBAL_TIME_SECONDS=${WAIT_FOR_GLOBAL_TIME_SECONDS:-0}
WAIT_FOR_GLOBAL_TIME_POLL_SECONDS=${WAIT_FOR_GLOBAL_TIME_POLL_SECONDS:-5}

test -x "$QUARTUS_STP"
case "$INTERVAL_SECONDS" in
  ''|*[!0-9]*) echo "INTERVAL_SECONDS must be a non-negative integer" >&2; exit 2 ;;
esac
case "$OBS_GAP_MS" in
  ''|*[!0-9]*) echo "OBS_GAP_MS must be a non-negative integer" >&2; exit 2 ;;
esac
case "$WAIT_FOR_GLOBAL_TIME_SECONDS" in
  ''|*[!0-9]*) echo "WAIT_FOR_GLOBAL_TIME_SECONDS must be a non-negative integer" >&2; exit 2 ;;
esac
case "$WAIT_FOR_GLOBAL_TIME_POLL_SECONDS" in
  ''|*[!0-9]*) echo "WAIT_FOR_GLOBAL_TIME_POLL_SECONDS must be a non-negative integer" >&2; exit 2 ;;
esac
if [ "$WAIT_FOR_GLOBAL_TIME_SECONDS" -gt 0 ] &&
   [ "$WAIT_FOR_GLOBAL_TIME_POLL_SECONDS" -eq 0 ]; then
  echo "WAIT_FOR_GLOBAL_TIME_POLL_SECONDS must be > 0 when waiting is enabled" >&2
  exit 2
fi

# Continuous monitoring is for showing the current state, not gating it.
# Restrict the optional readiness wait to explicit one-shot checks so an
# inherited WAIT_FOR_GLOBAL_TIME_SECONDS cannot hide the live dashboard.
if [ "$ONCE" != "1" ] && [ "$WAIT_FOR_GLOBAL_TIME_SECONDS" -gt 0 ]; then
  printf 'DASHBOARD_NOTE live sampling is immediate; ignoring host-side wait=%ss (use ONCE=1 for a one-shot readiness gate)\n' \
    "$WAIT_FOR_GLOBAL_TIME_SECONDS" >&2
  WAIT_FOR_GLOBAL_TIME_SECONDS=0
fi

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
  local step1_gate="${field[Step1]:-INFO}"
  local step6_gate="${field[Step6]:-INFO}"
  local link="${field[Link]:-0}"
  local tm="${field[TM]:-0}"
  local wr_servo_state="${field[WR_SERVO_STATE]:-N/A}"
  local wr_servo_offset_ps="${field[WR_SERVO_OFFSET_PS]:-N/A}"
  local wr_servo_offset_display="$wr_servo_offset_ps ps"
  local global_state="WAITING"
  local global_reason="TIME_VALID=${time_valid}, PPS_VALID=${pps_valid}"
  if [[ "$wr_servo_state" == "WAIT_OFFSET_STABLE" &&
        "$wr_servo_offset_ps" =~ ^-?[0-9]+$ ]]; then
    wr_servo_offset_display="${wr_servo_offset_ps} ps (target <60 ps)"
    if [[ "$time_valid" != "1" ]]; then
      global_reason="PTP servo offset not yet <60 ps"
    fi
  fi
  if [[ "$step1_gate" == "PASS" && "$step6_gate" == "PASS" ]]; then
    global_state="VALID"
    global_reason="PPS snapshot valid; Step6 gate passed"
  elif [[ "$link" != "1" || "$tm" != "1" ]]; then
    global_state="LINK DOWN"
    global_reason="WR link gate failed (Link=${link}, TM=${tm})"
  elif [[ "$step1_gate" != "PASS" ]]; then
    global_state="STEP1 BLOCKED"
    global_reason="Step1 gate=${step1_gate}; Step6 gate=${step6_gate}"
  elif [[ "$time_valid" == "1" && "$pps_valid" == "1" &&
          "$snapshot_valid" == "1" && "$snapshot_stable" == "1" ]]; then
    global_state="NOT QUALIFIED"
    global_reason="snapshot valid; Step6 gate=${step6_gate}"
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
  printf '| %-28s %-27s |\n' "WR PTP servo state" "$wr_servo_state"
  printf '| %-28s %-27s |\n' "WR phase offset" "$wr_servo_offset_display"
  printf '| %-28s TIME_VALID=%s PPS_VALID=%s     |\n' "Global-Time validity" \
    "$time_valid" "$pps_valid"
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
  local line board role tai cycles time_valid pps_valid snapshot_valid snapshot_stable
  local step1_gate step6_gate link tm
  printf '\nGlobal Time summary (125 MHz reference; 1 cycle = 8 ns)\n'
  printf '%s\n' '------------------------------------------------------------'
  for line in "$@"; do
    board=$(field_from_line board "$line")
    role=$(field_from_line role "$line")
    tai=$(field_from_line TAI "$line")
    cycles=$(field_from_line CYCLES "$line")
    time_valid=$(field_from_line TIME_VALID "$line")
    pps_valid=$(field_from_line PPS_VALID "$line")
    snapshot_valid=$(field_from_line SNAPSHOT_VALID "$line")
    snapshot_stable=$(field_from_line SNAPSHOT_STABLE "$line")
    step1_gate=$(field_from_line Step1 "$line")
    step6_gate=$(field_from_line Step6 "$line")
    link=$(field_from_line Link "$line")
    tm=$(field_from_line TM "$line")
    if [[ "$time_valid" != "1" || "$pps_valid" != "1" ||
          "$snapshot_valid" != "1" || "$snapshot_stable" != "1" ||
          "$tai" == "INVALID" || "$cycles" == "INVALID" ]]; then
      tai='--'
      cycles='--'
      printf '  %-7s (%s)\n' "$role" "$board"
      printf '    TAI=%-12s CYCLES=%-12s WAITING (%s, %s)\n' \
        "$tai" "$cycles" "TIME_VALID=$time_valid" "PPS_VALID=$pps_valid"
    elif [[ "$step1_gate" != "PASS" || "$step6_gate" != "PASS" ]]; then
      printf '  %-7s (%s)\n' "$role" "$board"
      printf '    TAI=%-12s CYCLES=%-12s SNAPSHOT VALID; Step1=%s Step6=%s Link=%s TM=%s\n' \
        "$tai" "$cycles" "$step1_gate" "$step6_gate" "$link" "$tm"
    else
      printf '  %-7s (%s)\n' "$role" "$board"
      printf '    TAI=%-12s CYCLES=%-12s VALID\n' "$tai" "$cycles"
    fi
  done
  printf '%s\n' '------------------------------------------------------------'
}

all_boards_have_valid_global_time() {
  local line time_valid pps_valid snapshot_valid snapshot_stable tai cycles step1_gate step6_gate
  local board_count=0
  for line in "$@"; do
    board_count=$((board_count + 1))
    time_valid=$(field_from_line TIME_VALID "$line")
    pps_valid=$(field_from_line PPS_VALID "$line")
    snapshot_valid=$(field_from_line SNAPSHOT_VALID "$line")
    snapshot_stable=$(field_from_line SNAPSHOT_STABLE "$line")
    tai=$(field_from_line TAI "$line")
    cycles=$(field_from_line CYCLES "$line")
    step1_gate=$(field_from_line Step1 "$line")
    step6_gate=$(field_from_line Step6 "$line")
    if [[ "$time_valid" != "1" || "$pps_valid" != "1" ||
          "$snapshot_valid" != "1" || "$snapshot_stable" != "1" ||
          "$tai" == "INVALID" || "$cycles" == "INVALID" ||
          "$step1_gate" != "PASS" || "$step6_gate" != "PASS" ]]; then
      return 1
    fi
  done
  [[ "$board_count" -gt 0 ]]
}

global_time_wait_pending() {
  local line board role step1_gate step2_gate step3_gate step4_gate step5_gate
  local step5_result step6_gate link tm time_valid pps_valid snapshot_valid
  local snapshot_stable tai cycles
  local -a pending=()
  for line in "$@"; do
    if all_boards_have_valid_global_time "$line"; then
      continue
    fi
    board=$(field_from_line board "$line")
    role=$(field_from_line role "$line")
    step1_gate=$(field_from_line Step1 "$line")
    step2_gate=$(field_from_line Step2 "$line")
    step3_gate=$(field_from_line Step3 "$line")
    step4_gate=$(field_from_line Step4 "$line")
    step5_gate=$(field_from_line Step5 "$line")
    step5_result=$(field_from_line Step5Result "$line")
    step6_gate=$(field_from_line Step6 "$line")
    link=$(field_from_line Link "$line")
    tm=$(field_from_line TM "$line")
    time_valid=$(field_from_line TIME_VALID "$line")
    pps_valid=$(field_from_line PPS_VALID "$line")
    snapshot_valid=$(field_from_line SNAPSHOT_VALID "$line")
    snapshot_stable=$(field_from_line SNAPSHOT_STABLE "$line")
    tai=$(field_from_line TAI "$line")
    cycles=$(field_from_line CYCLES "$line")
    pending+=("${board}/${role}[S1=${step1_gate},S2=${step2_gate},S3=${step3_gate},S4=${step4_gate},S5=${step5_gate}/${step5_result},S6=${step6_gate},Link=${link},TM=${tm},TIME_VALID=${time_valid},PPS_VALID=${pps_valid},Snapshot=${snapshot_valid}/${snapshot_stable},TAI=${tai},Cycles=${cycles}]")
  done
  if [ "${#pending[@]}" -eq 0 ]; then
    printf '%s' 'no-board-frames'
  else
    local IFS=';'
    printf '%s' "${pending[*]}"
  fi
}

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/wr-step1-6-dashboard.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

while :; do
  wait_deadline=0
  if [ "$WAIT_FOR_GLOBAL_TIME_SECONDS" -gt 0 ]; then
    wait_deadline=$(( $(date +%s) + WAIT_FOR_GLOBAL_TIME_SECONDS ))
  fi

  while :; do
    cycle_start=$(date +%s)
    raw="$TMP_DIR/capture.log"
    set +e
    "$QUARTUS_STP" -t "$ROOT/scripts/jtag/read_step1_6_dashboard.tcl" \
      "$OBS_GAP_MS" >"$raw" 2>&1
    quartus_rc=$?
    set -e

    board_lines=()
    while IFS= read -r line; do
      board_lines+=("$line")
    done < <(grep '^DASHBOARD_BOARD ' "$raw" || true)

    global_time_valid=0
    if all_boards_have_valid_global_time "${board_lines[@]}"; then
      global_time_valid=1
    fi
    now=$(date +%s)
    if [ "$WAIT_FOR_GLOBAL_TIME_SECONDS" -gt 0 ] &&
       [ "$quartus_rc" -eq 0 ] &&
       [ "$global_time_valid" -eq 0 ] &&
       [ "$now" -ge "$wait_deadline" ]; then
      elapsed=$((now - (wait_deadline - WAIT_FOR_GLOBAL_TIME_SECONDS)))
      printf 'GLOBAL_TIME_WAIT_INCOMPLETE elapsed=%ss/%ss boards=%s reason=host-side-max pending=%s\n' \
        "$elapsed" "$WAIT_FOR_GLOBAL_TIME_SECONDS" \
        "${#board_lines[@]}" "$(global_time_wait_pending "${board_lines[@]}")" >&2
      break
    fi

    if [ "$WAIT_FOR_GLOBAL_TIME_SECONDS" -eq 0 ] ||
       [ "$quartus_rc" -ne 0 ] ||
       [ "$global_time_valid" -eq 1 ] ||
       [ "$now" -ge "$wait_deadline" ]; then
      break
    fi

    printf 'GLOBAL_TIME_WAIT elapsed=%ss/%ss boards=%s reason=host-side-max pending=%s\n' \
      "$(( $(date +%s) - (wait_deadline - WAIT_FOR_GLOBAL_TIME_SECONDS) ))" \
      "$WAIT_FOR_GLOBAL_TIME_SECONDS" "${#board_lines[@]}" \
      "$(global_time_wait_pending "${board_lines[@]}")" >&2
    remaining=$((wait_deadline - $(date +%s)))
    sleep_for=$WAIT_FOR_GLOBAL_TIME_POLL_SECONDS
    if [ "$remaining" -lt "$sleep_for" ]; then sleep_for=$remaining; fi
    if [ "$sleep_for" -gt 0 ]; then sleep "$sleep_for"; fi
  done

  if [ "$CLEAR_SCREEN" = "1" ] && [ -t 1 ]; then
    printf '\033[2J\033[H'
  fi
  printf 'White Rabbit Step 1-6 dashboard  %s  (read-only)\n' "$(date -Is)"
  printf 'Sampling interval: %ss; per-board comparison window: %sms\n\n' \
    "$INTERVAL_SECONDS" "$OBS_GAP_MS"
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
    if [ "$WAIT_FOR_GLOBAL_TIME_SECONDS" -gt 0 ] &&
       ! all_boards_have_valid_global_time "${board_lines[@]}"; then
      printf 'DASHBOARD_GLOBAL_TIME_WAIT_INCOMPLETE seconds=%s scope=host-only; hardware state is shown above\n' \
        "$WAIT_FOR_GLOBAL_TIME_SECONDS"
      exit 3
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
