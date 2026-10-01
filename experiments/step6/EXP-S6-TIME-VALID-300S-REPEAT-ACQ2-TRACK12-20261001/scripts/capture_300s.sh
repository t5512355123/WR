#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat PAGER=cat

SCRIPT_DIR=$(dirname "$(realpath "$0")")
EXP_DIR=$(dirname "$SCRIPT_DIR")
ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
RAW_DIR="$EXP_DIR/raw"
QUARTUS_STP=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
EXPECTED_BRANCH=feat/file_cleanup
EXPECTED_SLAVE=dd5d2e72d6fcde92ace62cf51cfd7fc333c5af1d8d8dd4ebfdc8437b3bba701b
EXPECTED_MASTER=2beddef2b481c96d6b94bf195fc3ea3cd87513bc776b6884cc775ee8d08f763b
CAPTURE_DURATION_MS=303000
SAMPLE_MS=250
REQUIRED_DURATION_MS=300000
MAX_GAP_MS=1000
MINIMUM_SAMPLES=301
READY_LIMIT_SECONDS=1800
CAPTURE_LIMIT_SECONDS=900

if [ "$#" -ne 2 ]; then
  echo "Usage: bash capture_300s.sh EXPECTED_COMMIT BUILD_RUN_TAG" >&2
  exit 2
fi
EXPECTED_COMMIT="$1"
BUILD_RUN_TAG="$2"
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
BUILD_DIR="$RAW_DIR/build/$BUILD_RUN_TAG"
OBSERVE_DIR="$RAW_DIR/observe"
ANALYSIS_DIR="$RAW_DIR/analysis"
READINESS_LOG="$OBSERVE_DIR/$RUN_TAG-readiness"
CAPTURE_LOG="$OBSERVE_DIR/$RUN_TAG-time-valid-303s.log"
ANALYSIS_JSON="$ANALYSIS_DIR/$RUN_TAG-time-valid-303s.json"

fail() {
  printf 'S6TV_CAPTURE_ABORT reason=%s\n' "$*" >&2
  exit 2
}

test "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED_COMMIT" || fail "commit mismatch"
test "$(git -C "$ROOT" branch --show-current)" = "$EXPECTED_BRANCH" || fail "branch mismatch"
test -z "$(git -C "$ROOT" diff --name-only)" || fail "tracked worktree is dirty"
test -z "$(git -C "$ROOT" diff --cached --name-only)" || fail "index is not clean"
test -x "$QUARTUS_STP" || fail "Quartus SignalTap executable is unavailable"
test -f "$BUILD_DIR/$BUILD_RUN_TAG-candidate-sof-sha256.txt" || fail "candidate SOF hash record is missing"
grep -Fq "$EXPECTED_SLAVE  quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof" \
  "$BUILD_DIR/$BUILD_RUN_TAG-candidate-sof-sha256.txt" || fail "Slave candidate hash mismatch"
grep -Fq "$EXPECTED_MASTER  quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof" \
  "$BUILD_DIR/$BUILD_RUN_TAG-candidate-sof-sha256.txt" || fail "Master candidate hash mismatch"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$RAW_DIR/program/$BUILD_RUN_TAG-slave-program.log" || fail "Slave programming success is unverified"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$RAW_DIR/program/$BUILD_RUN_TAG-master-program.log" || fail "Master programming success is unverified"

mkdir -p "$OBSERVE_DIR" "$ANALYSIS_DIR"
if [ -e "$CAPTURE_LOG" ] || [ -e "$ANALYSIS_JSON" ]; then
  fail "capture output already exists for this run tag"
fi
if pgrep -x quartus_stp >/dev/null; then
  ps -C quartus_stp -o pid=,comm=,args= >&2 || true
  fail "another JTAG reader is active"
fi

board_valid_in_poll() {
  board_id="$1"
  poll_path="$2"
  board_rows=$(grep -F "GLOBAL_TIME_SAMPLE board=DE5 [$board_id]" "$poll_path" || true)
  test -n "$board_rows" || return 1
  if printf '%s\n' "$board_rows" | grep -vq 'STATUS_TIME_VALID=1'; then
    return 1
  fi
  grep -Fq "GLOBAL_TIME_DONE board=DE5 [$board_id]" "$poll_path"
}

SECONDS=0
POLL=0
READY=0
while [ "$SECONDS" -lt "$READY_LIMIT_SECONDS" ]; do
  if pgrep -x quartus_stp >/dev/null; then
    ps -C quartus_stp -o pid=,comm=,args= >&2 || true
    fail "competing JTAG reader appeared during readiness polling"
  fi
  POLL=$((POLL + 1))
  POLL_PATH=$(printf '%s-%03d.log' "$READINESS_LOG" "$POLL")
  if [ -e "$POLL_PATH" ]; then
    fail "readiness poll output already exists"
  fi
  set +e
  timeout --signal=INT --kill-after=3s 25s "$QUARTUS_STP" -t \
    scripts/jtag/read_step6_global_time_observability.tcl 1000 250 "" \
    > "$POLL_PATH" 2>&1
  POLL_RC=$?
  set -e
  if [ "$POLL_RC" -ne 0 ] || grep -q '^GLOBAL_TIME_ERROR ' "$POLL_PATH"; then
    printf 'S6TV_READY_POLL_ERROR poll=%d rc=%d log=%s\n' "$POLL" "$POLL_RC" "$POLL_PATH"
    exit 2
  fi
  MASTER_OK=0
  SLAVE_OK=0
  board_valid_in_poll 1-11.1 "$POLL_PATH" && MASTER_OK=1 || true
  board_valid_in_poll 1-11.2 "$POLL_PATH" && SLAVE_OK=1 || true
  if [ "$MASTER_OK" -eq 1 ] && [ "$SLAVE_OK" -eq 1 ]; then
    READY=1
    printf 'S6TV_READY result=PASS poll=%d elapsed_s=%d\n' "$POLL" "$SECONDS"
    break
  fi
  printf 'S6TV_WAIT elapsed_s=%d/%d master_valid=%d slave_valid=%d poll_log=%s\n' \
    "$SECONDS" "$READY_LIMIT_SECONDS" "$MASTER_OK" "$SLAVE_OK" "$POLL_PATH"
  sleep 10
done
if [ "$READY" -ne 1 ]; then
  echo "S6TV_READY result=TIMEOUT; preserve readiness logs; no 300-second capture started"
  exit 1
fi

if pgrep -x quartus_stp >/dev/null; then
  ps -C quartus_stp -o pid=,comm=,args= >&2 || true
  fail "another JTAG reader is active before long capture"
fi
printf 'S6TV_CAPTURE_CONFIG run_tag=%s duration_ms=%d sample_ms=%d board_filter=empty read_only=1 deadline_s=%d\n' \
  "$RUN_TAG" "$CAPTURE_DURATION_MS" "$SAMPLE_MS" "$CAPTURE_LIMIT_SECONDS"
set +e
timeout --signal=INT --kill-after=5s "$CAPTURE_LIMIT_SECONDS"s "$QUARTUS_STP" -t \
  scripts/jtag/read_step6_global_time_observability.tcl \
  "$CAPTURE_DURATION_MS" "$SAMPLE_MS" "" 2>&1 | tee "$CAPTURE_LOG"
OBSERVER_RC=$?
set -e
printf 'S6TV_OBSERVER_EXIT run_tag=%s rc=%d\n' "$RUN_TAG" "$OBSERVER_RC" | tee -a "$CAPTURE_LOG"
sha256sum "$CAPTURE_LOG" > "$CAPTURE_LOG.sha256"

set +e
python3 scripts/analysis/step6_time_valid_300s.py "$CAPTURE_LOG" \
  --required-duration-ms "$REQUIRED_DURATION_MS" \
  --max-sample-gap-ms "$MAX_GAP_MS" \
  --minimum-samples "$MINIMUM_SAMPLES" \
  --boards 1-11.1,1-11.2 > "$ANALYSIS_JSON"
ANALYSIS_RC=$?
set -e
cat "$ANALYSIS_JSON"
sha256sum "$ANALYSIS_JSON" > "$ANALYSIS_JSON.sha256"
printf 'S6TV_RESULT observer_rc=%d analyzer_rc=%d capture=%s analysis=%s\n' \
  "$OBSERVER_RC" "$ANALYSIS_RC" "$CAPTURE_LOG" "$ANALYSIS_JSON"
if [ "$OBSERVER_RC" -ne 0 ]; then
  exit "$OBSERVER_RC"
fi
exit "$ANALYSIS_RC"
