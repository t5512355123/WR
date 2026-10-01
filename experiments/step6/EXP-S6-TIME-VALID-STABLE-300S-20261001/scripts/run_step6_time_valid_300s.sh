#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
EXP_DIR="$ROOT/experiments/step6/EXP-S6-TIME-VALID-STABLE-300S-20261001"
RAW_DIR="$EXP_DIR/raw"
MILESTONE_DIR="$ROOT/artifacts/milestones/step6_global_time"
SOURCE_DIR="$MILESTONE_DIR/source"
QUARTUS_BIN="${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}"
STP_BIN="$QUARTUS_BIN/quartus_stp"
PGM_BIN="$QUARTUS_BIN/quartus_pgm"
DURATION_MS=302000
SAMPLE_MS=250
EXPECTED_MASTER="ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901"
EXPECTED_SLAVE="6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450"
RUN_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
BUILD_DIR="$RAW_DIR/build/$RUN_TAG"
PROGRAM_DIR="$RAW_DIR/program/$RUN_TAG"
OBSERVE_DIR="$RAW_DIR/observe"
LOG="$OBSERVE_DIR/${RUN_TAG}-time-valid-300s.log"
ANALYSIS="$RAW_DIR/analysis/${RUN_TAG}-time-valid-300s.json"

for path in "$BUILD_DIR" "$PROGRAM_DIR" "$LOG" "$ANALYSIS"; do
  if [[ -e "$path" ]]; then
    printf 'S6TV_ABORT reason=output_exists path=%s\n' "$path" >&2
    exit 73
  fi
done
CURRENT_BRANCH="$(git -C "$ROOT" branch --show-current)"
if [[ "$CURRENT_BRANCH" != "feat/file_cleanup" ]]; then
  printf 'S6TV_ABORT reason=wrong_branch expected=feat/file_cleanup actual=%s\n' \
    "$CURRENT_BRANCH" >&2
  exit 74
fi
ACTIVE_STP="$(pgrep -x quartus_stp || true)"
if [[ -n "$ACTIVE_STP" ]]; then
  printf 'S6TV_ABORT reason=existing_quartus_stp_reader pids=%s\n' \
    "${ACTIVE_STP//$'\n'/,}" >&2
  exit 75
fi
mkdir -p "$BUILD_DIR" "$PROGRAM_DIR" "$OBSERVE_DIR" "$(dirname "$ANALYSIS")"

run_logged() {
  local name="$1"
  shift
  printf 'S6TV_STEP name=%s start=1\n' "$name"
  if "$@" 2>&1 | tee "$BUILD_DIR/$name.log"; then
    printf 'S6TV_STEP name=%s result=PASS\n' "$name"
  else
    local result=$?
    printf 'S6TV_STEP name=%s result=FAIL rc=%d\n' "$name" "$result" >&2
    exit "$result"
  fi
}

test -x "$STP_BIN"
test -x "$PGM_BIN"
test -f "$SOURCE_DIR/SHA256SUMS"
test -f "$ROOT/scripts/analysis/step6_time_valid_300s.py"

printf 'S6TV_CONFIG run_tag=%s branch=%s frozen_source_origin=74dc28862653d306e0450cf437ba6d3a230d979d duration_ms=%d sample_ms=%d board_filter=1-11.2 read_only_observation=1\n' \
  "$RUN_TAG" "$CURRENT_BRANCH" "$DURATION_MS" "$SAMPLE_MS"

cd "$SOURCE_DIR"
sha256sum -c SHA256SUMS | tee "$BUILD_DIR/frozen-source-check.log"
run_logged master_firmware bash firmware/scripts/build_master_firmware.sh
run_logged master_quartus bash scripts/build/build_master.sh
run_logged slave_firmware bash firmware/scripts/build_slave_firmware.sh
run_logged slave_quartus bash scripts/build/build_slave.sh

MASTER_SOF="$SOURCE_DIR/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof"
SLAVE_SOF="$SOURCE_DIR/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
test -f "$MASTER_SOF"
test -f "$SLAVE_SOF"
ACTUAL_MASTER="$(sha256sum "$MASTER_SOF" | awk '{print $1}')"
ACTUAL_SLAVE="$(sha256sum "$SLAVE_SOF" | awk '{print $1}')"
printf 'S6TV_BUILD_HASH master=%s slave=%s\n' "$ACTUAL_MASTER" "$ACTUAL_SLAVE" | tee "$BUILD_DIR/sof-hashes.log"
if [[ "$ACTUAL_MASTER" != "$EXPECTED_MASTER" || "$ACTUAL_SLAVE" != "$EXPECTED_SLAVE" ]]; then
  printf 'S6TV_ABORT reason=frozen_sof_hash_mismatch\n' | tee -a "$BUILD_DIR/sof-hashes.log"
  exit 2
fi

PGM_LIST="$("$PGM_BIN" -l 2>&1)"
printf '%s\n' "$PGM_LIST" | tee "$PROGRAM_DIR/cables.log"
[[ "$PGM_LIST" == *'DE5 [1-11.2]'* ]]
[[ "$PGM_LIST" == *'DE5 [1-11.1]'* ]]

if SOF="$SLAVE_SOF" CABLE='DE5 [1-11.2]' bash scripts/program/program_slave.sh 2>&1 | tee "$PROGRAM_DIR/program-slave.log"; then
  printf 'S6TV_PROGRAM board=slave result=PASS sha256=%s\n' "$ACTUAL_SLAVE" | tee -a "$PROGRAM_DIR/program-slave.log"
else
  result=$?
  printf 'S6TV_PROGRAM board=slave result=FAIL rc=%d\n' "$result" | tee -a "$PROGRAM_DIR/program-slave.log"
  exit "$result"
fi
if SOF="$MASTER_SOF" CABLE='DE5 [1-11.1]' bash scripts/program/program_master.sh 2>&1 | tee "$PROGRAM_DIR/program-master.log"; then
  printf 'S6TV_PROGRAM board=master result=PASS sha256=%s\n' "$ACTUAL_MASTER" | tee -a "$PROGRAM_DIR/program-master.log"
else
  result=$?
  printf 'S6TV_PROGRAM board=master result=FAIL rc=%d\n' "$result" | tee -a "$PROGRAM_DIR/program-master.log"
  exit "$result"
fi

cd "$ROOT"
trap 'printf "S6TV_SIGNAL signal=INT run_tag=%s\n" "$RUN_TAG" >> "$LOG"' INT
trap 'printf "S6TV_SIGNAL signal=TERM run_tag=%s\n" "$RUN_TAG" >> "$LOG"' TERM
set +e
timeout --signal=INT --kill-after=5s 430s "$STP_BIN" -t scripts/jtag/read_step6_global_time_observability.tcl \
  "$DURATION_MS" "$SAMPLE_MS" 1-11.2 2>&1 | tee "$LOG"
OBSERVER_RC=${PIPESTATUS[0]}
set -e
printf 'S6TV_OBSERVER_EXIT run_tag=%s rc=%d\n' "$RUN_TAG" "$OBSERVER_RC" | tee -a "$LOG"
sha256sum "$LOG" > "$LOG.sha256"

set +e
python3 scripts/analysis/step6_time_valid_300s.py "$LOG" --required-duration-ms 300000 \
  --max-sample-gap-ms 1000 --minimum-samples 301 > "$ANALYSIS"
ANALYSIS_RC=$?
set -e
cat "$ANALYSIS"
sha256sum "$ANALYSIS" > "$ANALYSIS.sha256"
if [[ "$OBSERVER_RC" -ne 0 ]]; then
  exit "$OBSERVER_RC"
fi
exit "$ANALYSIS_RC"
