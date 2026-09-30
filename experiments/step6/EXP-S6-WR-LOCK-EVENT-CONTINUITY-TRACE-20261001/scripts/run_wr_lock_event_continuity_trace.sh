#!/usr/bin/env bash
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
EXP_DIR="$ROOT/experiments/step6/EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001"
RAW_DIR="$EXP_DIR/raw/observe"
TCL_SCRIPT="$ROOT/scripts/jtag/read_step6_wr_lock_event_continuity_trace.tcl"
RUN_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$RAW_DIR/${RUN_TAG}-wr-lock-event-continuity.log"

mkdir -p "$RAW_DIR"
if [[ -e "$LOG" ]]; then
  printf 'S6E_WRAPPER_ABORT reason=log_path_exists path=%s\n' "$LOG"
  exit 73
fi
: > "$LOG"

trap 'printf "S6E_WRAPPER_SIGNAL signal=INT run_tag=%s\n" "$RUN_TAG" >> "$LOG"' INT
trap 'printf "S6E_WRAPPER_SIGNAL signal=TERM run_tag=%s\n" "$RUN_TAG" >> "$LOG"' TERM

printf 'S6E_WRAPPER_CONFIG run_tag=%s log=%s pretrigger_ms=300000 post_event_ms=5000 artificial_delay_ms=0 external_watchdog_s=330 raw_persistent=1 cleanup_deletes_raw=0 follow_on_smoke=0\n' \
  "$RUN_TAG" "$LOG" | tee -a "$LOG"

STP_BIN="/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp"
if [[ ! -x "$STP_BIN" ]]; then
  STP_BIN="$(command -v quartus_stp || true)"
fi
if [[ -z "$STP_BIN" || ! -x "$STP_BIN" ]]; then
  printf 'S6E_WRAPPER_ABORT reason=quartus_stp_not_found\n' | tee -a "$LOG"
  exit 127
fi
if ! command -v timeout >/dev/null 2>&1; then
  printf 'S6E_WRAPPER_ABORT reason=timeout_command_not_found\n' | tee -a "$LOG"
  exit 127
fi

timeout --signal=INT --kill-after=5s 330s "$STP_BIN" -t "$TCL_SCRIPT" 2>&1 | tee -a "$LOG"
PIPELINE_RC=$?
printf 'S6E_WRAPPER_EXIT run_tag=%s pipeline_rc=%d log=%s\n' \
  "$RUN_TAG" "$PIPELINE_RC" "$LOG" | tee -a "$LOG"
LOG_BASE="$(basename "$LOG")"
(cd "$RAW_DIR" && sha256sum "$LOG_BASE" > "$LOG_BASE.sha256")
printf 'S6E_WRAPPER_CHECKSUM path=%s.sha256\n' "$LOG"
exit "$PIPELINE_RC"
