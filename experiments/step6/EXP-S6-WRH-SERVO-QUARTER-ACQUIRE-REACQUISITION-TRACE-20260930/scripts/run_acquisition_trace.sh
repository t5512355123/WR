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

printf 'S6_ACQ_WRAPPER_CONFIG run_tag=%s log=%s arming_timeout_ms=300000 requested_duration_ms=600000 external_watchdog_s=905 raw_persistent=1 cleanup_deletes_raw=0\n' \
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

timeout --signal=INT --kill-after=2s 905s "$STP_BIN" -t "$TCL_SCRIPT" 2>&1 | tee -a "$LOG"
PIPELINE_RC=$?
printf 'S6_ACQ_WRAPPER_EXIT run_tag=%s pipeline_rc=%d log=%s\n' \
  "$RUN_TAG" "$PIPELINE_RC" "$LOG" | tee -a "$LOG"

STOP_REASON="$(grep '^S6_ACQ_STOP ' "$LOG" | tail -n 1 | sed -n 's/.*STOP_REASON=\([^ ]*\).*/\1/p')"
if [[ "$STOP_REASON" == "TRACK_PHASE_REACHED_DURING_ARMING_HEALTH_READY" ||
      "$STOP_REASON" == "TRACK_PHASE_REACHED" ]]; then
  SMOKE_TCL="$ROOT/scripts/jtag/read_step6_servo_interleaved_offset.tcl"
  printf 'S6_ACQ_FOLLOW_ON action=phase_context_smoke timeout_s=20 same_boot=1 reset=0 reprogram=0 stop_reason=%s\n' \
    "$STOP_REASON" | tee -a "$LOG"
  timeout --signal=INT --kill-after=2s 20s "$STP_BIN" -t "$SMOKE_TCL" \
    15000 1 1-11.2 2 2>&1 | tee -a "$LOG"
  SMOKE_RC=$?
  printf 'S6_ACQ_FOLLOW_ON_EXIT action=phase_context_smoke pipeline_rc=%d\n' \
    "$SMOKE_RC" | tee -a "$LOG"
fi
exit "$PIPELINE_RC"
