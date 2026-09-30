#!/usr/bin/env bash
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
EXP_DIR="$ROOT/experiments/step6/EXP-S6-WRH-SERVO-QUARTER-ACQUIRE-REACQUISITION-TRACE-20260930"
RAW_DIR="$EXP_DIR/raw/observe"
TCL_SCRIPT="$ROOT/scripts/jtag/read_step6_servo_acquisition_context.tcl"
RUN_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$RAW_DIR/$RUN_TAG-acquisition.log"

mkdir -p "$RAW_DIR"
if [[ -e "$LOG" ]]; then
  printf 'S6_ACQ_WRAPPER_ABORT reason=log_path_exists path=%s\n' "$LOG"
  exit 73
fi
: > "$LOG"

trap 'printf "S6_ACQ_WRAPPER_SIGNAL signal=INT run_tag=%s\n" "$RUN_TAG" >> "$LOG"' INT
trap 'printf "S6_ACQ_WRAPPER_SIGNAL signal=TERM run_tag=%s\n" "$RUN_TAG" >> "$LOG"' TERM

printf 'S6_ACQ_WRAPPER_CONFIG run_tag=%s log=%s requested_duration_ms=600000 external_watchdog_s=605 raw_persistent=1 cleanup_deletes_raw=0\n' \
  "$RUN_TAG" "$LOG" | tee -a "$LOG"

STP_BIN="/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp"
if [[ ! -x "$STP_BIN" ]]; then
  STP_BIN="$(command -v quartus_stp || true)"
fi
if [[ -z "$STP_BIN" || ! -x "$STP_BIN" ]]; then
  printf 'S6_ACQ_WRAPPER_ABORT reason=quartus_stp_not_found\n' | tee -a "$LOG"
  exit 127
fi
if ! command -v timeout >/dev/null 2>&1; then
  printf 'S6_ACQ_WRAPPER_ABORT reason=timeout_command_not_found\n' | tee -a "$LOG"
  exit 127
fi

timeout --signal=INT --kill-after=2s 605s "$STP_BIN" -t "$TCL_SCRIPT" 2>&1 | tee -a "$LOG"
PIPELINE_RC=$?
printf 'S6_ACQ_WRAPPER_EXIT run_tag=%s pipeline_rc=%d log=%s\n' \
  "$RUN_TAG" "$PIPELINE_RC" "$LOG" | tee -a "$LOG"
exit "$PIPELINE_RC"
