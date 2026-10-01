#!/usr/bin/env bash
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
EXP_DIR="$ROOT/experiments/step6/EXP-S6-PRETRACK-COHERENT-CKO-SETP-20261001"
RAW_DIR="$EXP_DIR/raw/observe"
TCL_SCRIPT="$ROOT/scripts/jtag/read_step6_servo_interleaved_offset.tcl"
QUARTUS_BIN="/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin"
STP_BIN="$QUARTUS_BIN/quartus_stp"
PGM_BIN="$QUARTUS_BIN/quartus_pgm"
EXPECTED_SOURCE="a62c264dbbfc15b31c316188dd7f851d28ec2a6d"
EXPECTED_SLAVE_SOF="5af7150671dfb293acd82c68f47df9688fc1f23d40cf912ed3c6764467754018"
EXPECTED_MASTER_SOF="9a0f1087c0dd75330c94cd7f24780359d4c3d89dacd7c207d734e29568d721c5"
SLAVE_SOF="$ROOT/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
MASTER_SOF="$ROOT/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof"
RUN_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$RAW_DIR/${RUN_TAG}-pretrack-phase-context.log"

mkdir -p "$RAW_DIR"
if [[ -e "$LOG" ]]; then
  printf 'S6C_ABORT reason=log_path_exists path=%s\n' "$LOG"
  exit 73
fi
: > "$LOG"

abort() {
  printf 'S6C_ABORT reason=%s\n' "$1" | tee -a "$LOG"
  (cd "$RAW_DIR" && sha256sum "$(basename "$LOG")" > "$(basename "$LOG").sha256")
  exit 1
}

printf 'S6C_CONFIG run_tag=%s candidate_source=%s duration_ms=30000 sample_ms=100 board=1-11.2 phase_context=1 read_only=1 no_compile=1 no_program=1 external_watchdog_s=90\n' \
  "$RUN_TAG" "$EXPECTED_SOURCE" | tee -a "$LOG"

if ! grep -Fq "GIT_COMMIT=$EXPECTED_SOURCE" "$ROOT/build/build_info_slave.txt" ||
   ! grep -Fq "GIT_COMMIT=$EXPECTED_SOURCE" "$ROOT/build/build_info_master.txt"; then
  abort build_info_source_mismatch
fi

ACTUAL_SLAVE_SOF="$(sha256sum "$SLAVE_SOF" | awk '{print $1}')"
ACTUAL_MASTER_SOF="$(sha256sum "$MASTER_SOF" | awk '{print $1}')"
printf 'S6C_SOF_PREFLIGHT slave=%s master=%s\n' "$ACTUAL_SLAVE_SOF" "$ACTUAL_MASTER_SOF" | tee -a "$LOG"
if [[ "$ACTUAL_SLAVE_SOF" != "$EXPECTED_SLAVE_SOF" ||
      "$ACTUAL_MASTER_SOF" != "$EXPECTED_MASTER_SOF" ]]; then
  abort sof_hash_mismatch
fi

if pgrep -x quartus_stp >/dev/null 2>&1; then
  abort competing_quartus_stp
fi
if ! command -v timeout >/dev/null 2>&1; then
  abort timeout_command_not_found
fi
if [[ ! -x "$STP_BIN" || ! -x "$PGM_BIN" || ! -f "$TCL_SCRIPT" ]]; then
  abort required_tool_or_script_missing
fi

PGM_OUTPUT="$("$PGM_BIN" -l 2>&1)"
PGM_RC=$?
printf '%s\n' "$PGM_OUTPUT" | tee -a "$LOG"
if [[ $PGM_RC -ne 0 ]]; then
  abort cable_enumeration_failed
fi
if [[ "$PGM_OUTPUT" != *'DE5 [1-11.2]'* ]]; then
  abort slave_cable_missing
fi
if [[ "$PGM_OUTPUT" != *'DE5 [1-11.1]'* ]]; then
  abort master_cable_missing
fi

trap 'printf "S6C_SIGNAL signal=INT run_tag=%s\n" "$RUN_TAG" >> "$LOG"' INT
trap 'printf "S6C_SIGNAL signal=TERM run_tag=%s\n" "$RUN_TAG" >> "$LOG"' TERM
timeout --signal=INT --kill-after=5s 90s "$STP_BIN" -t "$TCL_SCRIPT" \
  30000 100 1-11.2 1 2>&1 | tee -a "$LOG"
PIPELINE_RC=${PIPESTATUS[0]}
printf 'S6C_EXIT run_tag=%s pipeline_rc=%d log=%s\n' \
  "$RUN_TAG" "$PIPELINE_RC" "$LOG" | tee -a "$LOG"
(cd "$RAW_DIR" && sha256sum "$(basename "$LOG")" > "$(basename "$LOG").sha256")
printf 'S6C_CHECKSUM path=%s.sha256\n' "$LOG"
exit "$PIPELINE_RC"
