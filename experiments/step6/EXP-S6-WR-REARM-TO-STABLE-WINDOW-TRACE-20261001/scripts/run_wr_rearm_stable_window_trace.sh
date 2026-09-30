#!/usr/bin/env bash
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
EXP_DIR="$ROOT/experiments/step6/EXP-S6-WR-REARM-TO-STABLE-WINDOW-TRACE-20261001"
RAW_DIR="$EXP_DIR/raw/observe"
TCL_SCRIPT="$EXP_DIR/scripts/read_step6_wr_rearm_to_stable_window.tcl"
RUN_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$RAW_DIR/${RUN_TAG}-wr-rearm-stable-window.log"

mkdir -p "$RAW_DIR"
if [[ -e "$LOG" ]]; then
  printf 'S6R_WRAPPER_ABORT reason=log_path_exists path=%s\n' "$LOG"
  exit 73
fi
: > "$LOG"

trap 'printf "S6R_WRAPPER_SIGNAL signal=INT run_tag=%s\n" "$RUN_TAG" >> "$LOG"' INT
trap 'printf "S6R_WRAPPER_SIGNAL signal=TERM run_tag=%s\n" "$RUN_TAG" >> "$LOG"' TERM

printf 'S6R_WRAPPER_CONFIG run_tag=%s log=%s admission_limit_s=600 stable_window_s=300 total_capture_s=900 external_watchdog_s=930 sample_delay_ms=100 read_only=1 compile=0 program=0 auto_retry=0 raw_persistent=1\n' \
  "$RUN_TAG" "$LOG" | tee -a "$LOG"

STP_BIN="/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp"
if [[ ! -x "$STP_BIN" ]]; then
  STP_BIN="$(command -v quartus_stp || true)"
fi
if [[ -z "$STP_BIN" || ! -x "$STP_BIN" ]]; then
  printf 'S6R_WRAPPER_ABORT reason=quartus_stp_not_found\n' | tee -a "$LOG"
  exit 127
fi
if ! command -v timeout >/dev/null 2>&1; then
  printf 'S6R_WRAPPER_ABORT reason=timeout_command_not_found\n' | tee -a "$LOG"
  exit 127
fi

timeout --signal=INT --kill-after=5s 930s "$STP_BIN" -t "$TCL_SCRIPT" 2>&1 | tee -a "$LOG"
PIPELINE_RC=$?
printf 'S6R_WRAPPER_EXIT run_tag=%s pipeline_rc=%d log=%s\n' \
  "$RUN_TAG" "$PIPELINE_RC" "$LOG" | tee -a "$LOG"
LOG_BASE="$(basename "$LOG")"
(cd "$RAW_DIR" && sha256sum "$LOG_BASE" > "$LOG_BASE.sha256")
printf 'S6R_WRAPPER_CHECKSUM path=%s.sha256\n' "$LOG"
exit "$PIPELINE_RC"
