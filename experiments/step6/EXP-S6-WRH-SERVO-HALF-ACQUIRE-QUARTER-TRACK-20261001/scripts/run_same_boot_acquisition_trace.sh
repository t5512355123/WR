#!/usr/bin/env bash
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
TCL_SCRIPT="$ROOT/scripts/jtag/read_step6_servo_acquisition_context.tcl"
SMOKE_TCL="$ROOT/scripts/jtag/read_step6_servo_interleaved_offset.tcl"
CANDIDATE_SOURCE_COMMIT="ba9514c555edc672dff4eea9cfa5690d614a20a4"
RAW_DIR="${S6_ACQ_RAW_DIR:-/tmp/wr-s6-half-acquire-quarter-track-20261001}"
RUN_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$RAW_DIR/$RUN_TAG-acquisition.log"

mkdir -p "$RAW_DIR"
if [[ -e "$LOG" ]]; then
  printf 'S6_ACQ_WRAPPER_ABORT reason=log_path_exists path=%s\n' "$LOG"
  exit 73
fi
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

abort() {
  printf 'S6_ACQ_WRAPPER_ABORT reason=%s\n' "$1"
  exit "${2:-1}"
}

branch="$(git -C "$ROOT" branch --show-current)"
head="$(git -C "$ROOT" rev-parse HEAD)"
[[ "$branch" == "feat/file_cleanup" ]] || abort "unexpected_branch_$branch" 65
git -C "$ROOT" merge-base --is-ancestor "$CANDIDATE_SOURCE_COMMIT" HEAD || \
  abort "candidate_source_not_in_head" 66
git -C "$ROOT" diff --quiet "$CANDIDATE_SOURCE_COMMIT" HEAD -- \
  vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c || \
  abort "candidate_servo_source_changed_since_program" 67
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || abort "worktree_not_clean" 68

command -v pgrep >/dev/null 2>&1 || abort "pgrep_not_found" 127
for process_name in quartus_stp quartus_pgm quartus_pgmw; do
  if pgrep -x "$process_name" >/dev/null 2>&1; then
    abort "concurrent_$process_name" 69
  fi
done

STP_BIN="/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp"
if [[ ! -x "$STP_BIN" ]]; then
  STP_BIN="$(command -v quartus_stp || true)"
fi
[[ -n "$STP_BIN" && -x "$STP_BIN" ]] || abort "quartus_stp_not_found" 127
command -v timeout >/dev/null 2>&1 || abort "timeout_command_not_found" 127

printf 'S6_ACQ_WRAPPER_CONFIG run_tag=%s\n' "$RUN_TAG"
printf 'S6_ACQ_WRAPPER_CONFIG log=%s branch=%s head=%s candidate_image_source=%s\n' \
  "$LOG" "$branch" "$head" "$CANDIDATE_SOURCE_COMMIT"
printf 'S6_ACQ_WRAPPER_CONFIG mode=read_only_same_boot reset=0 fpga_program=0 compile=0\n'
printf 'S6_ACQ_WRAPPER_CONFIG arming_timeout_ms=300000 requested_duration_ms=600000 external_watchdog_s=905 raw_persistent=1\n'
printf 'S6_ACQ_WRAPPER_CONFIG observer_sha256=%s\n' "$(sha256sum "$TCL_SCRIPT" | awk '{print $1}')"

timeout --signal=INT --kill-after=2s 905s "$STP_BIN" -t "$TCL_SCRIPT"
STP_RC=${PIPESTATUS[0]}
printf 'S6_ACQ_WRAPPER_EXIT action=acquisition rc=%d\n' "$STP_RC"
FINAL_RC="$STP_RC"

STOP_REASON="$(sed -n 's/.*STOP_REASON=\([^ ]*\).*/\1/p' "$LOG" | tail -n 1)"
if [[ "$STP_RC" -eq 0 && ( "$STOP_REASON" == "TRACK_PHASE_REACHED_DURING_ARMING_HEALTH_READY" ||
      "$STOP_REASON" == "TRACK_PHASE_REACHED" ) ]]; then
  printf 'S6_ACQ_FOLLOW_ON action=phase_context_smoke timeout_s=20 same_boot=1 reset=0 reprogram=0 stop_reason=%s\n' \
    "$STOP_REASON"
  timeout --signal=INT --kill-after=2s 20s "$STP_BIN" -t "$SMOKE_TCL" \
    15000 500 1-11.2 2
  SMOKE_RC=${PIPESTATUS[0]}
  printf 'S6_ACQ_FOLLOW_ON_EXIT action=phase_context_smoke rc=%d\n' "$SMOKE_RC"
  if [[ "$SMOKE_RC" -ne 0 ]]; then FINAL_RC="$SMOKE_RC"; fi
fi

printf 'S6_ACQ_WRAPPER_DONE run_tag=%s stop_reason=%s final_rc=%s raw_log=%s checksum_file=%s.sha256\n' \
  "$RUN_TAG" "${STOP_REASON:-MISSING_STOP_RECORD}" "$FINAL_RC" "$LOG" "$LOG"
sha256sum "$LOG" > "$LOG.sha256"
exit "$FINAL_RC"
