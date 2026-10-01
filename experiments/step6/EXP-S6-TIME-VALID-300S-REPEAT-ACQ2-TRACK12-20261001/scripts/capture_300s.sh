#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat PAGER=cat

SCRIPT_DIR=$(dirname "$(realpath "$0")")
EXP_DIR=$(dirname "$SCRIPT_DIR")
ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
RAW_DIR="$EXP_DIR/raw"
EXP_REL="experiments/step6/$(basename "$EXP_DIR")"
OUTPUT_REL="$EXP_REL/output"
QUARTUS_STP=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
EXPECTED_BRANCH=feat/file_cleanup
EXPECTED_BUILD_COMMIT=4c1adf73ab762506939163d467fb8c6b35bca9b4
EXPECTED_SOURCE_ORIGIN=74dc28862653d306e0450cf437ba6d3a230d979d
EXPECTED_MASTER_QSF=fc2f861ad6cf3a2f660ac66184fe054415515ab4006e578542ddce59ab026530
EXPECTED_SLAVE_QSF=d074d47954f13d539d5477615a8a03752622b2b115dfa6684bc51169a3d7275d
EXPECTED_SDC=083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d
EXPECTED_QUARTUS_VERSION='Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition'
EXPECTED_SLAVE_MIF=d6165e93f0a43bc6b2a41db8d568ab696916c1a32c1733b47d7df36b5a692916
EXPECTED_MASTER_MIF=07511e0a1148dd120898b1fc53f644f265b098d52912340314dace2a8b1526f6
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
if [[ ! "$BUILD_RUN_TAG" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
  echo "S6TV_CAPTURE_ABORT reason=invalid-build-run-tag" >&2
  exit 2
fi
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
BUILD_DIR="$RAW_DIR/build"
PROGRAM_DIR="$RAW_DIR/program"
BUILD_HEAD_RECORD="$RAW_DIR/preflight/$BUILD_RUN_TAG-current-head.txt"
PROGRAM_RUN_RECORD="$BUILD_DIR/$BUILD_RUN_TAG-program-run.txt"
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
test -f "$BUILD_HEAD_RECORD" || fail "BUILD checkout identity record is missing"
test "$(tr -d '\r\n' < "$BUILD_HEAD_RECORD")" = "$EXPECTED_COMMIT" || fail "build checkout commit differs"
test -f "$PROGRAM_RUN_RECORD" || fail "verified programming completion record is missing"
test "$(sed -n 's/^BUILD_RUN_TAG=//p' "$PROGRAM_RUN_RECORD")" = "$BUILD_RUN_TAG" || fail "program completion record belongs to another build"
PROGRAM_RUN_TAG=$(sed -n 's/^PROGRAM_RUN_TAG=//p' "$PROGRAM_RUN_RECORD")
test -n "$PROGRAM_RUN_TAG" || fail "program run tag is missing"
test "$(printf '%s\n' "$PROGRAM_RUN_TAG" | wc -l)" -eq 1 || fail "program run tag is ambiguous"
if [[ ! "$PROGRAM_RUN_TAG" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
  fail "program run tag is malformed"
fi
test -f "$BUILD_DIR/$BUILD_RUN_TAG-candidate-sof-sha256.txt" || fail "candidate SOF hash record is missing"

verify_build_info() {
  info_file="$1"
  project_qsf="$2"
  mif_hash="$3"
  sof_path="$4"
  grep -Fx "SOURCE_ORIGIN_COMMIT=$EXPECTED_SOURCE_ORIGIN" "$info_file" >/dev/null || fail "source origin differs in $info_file"
  grep -Fx "REPOSITORY_COMMIT=$EXPECTED_BUILD_COMMIT" "$info_file" >/dev/null || fail "build commit differs in $info_file"
  grep -Fx "QSF_SHA256=$project_qsf" "$info_file" >/dev/null || fail "QSF differs in $info_file"
  grep -Fx "SDC_SHA256=$EXPECTED_SDC" "$info_file" >/dev/null || fail "SDC differs in $info_file"
  grep -Fx "QUARTUS_VERSION=$EXPECTED_QUARTUS_VERSION" "$info_file" >/dev/null || fail "Quartus version differs in $info_file"
  grep -Fx "MIF_SHA256=$mif_hash" "$info_file" >/dev/null || fail "firmware MIF differs in $info_file"
  grep -q '^FITTER_STATUS=Fitter Status : Successful' "$info_file" || fail "Fitter did not succeed in $info_file"
  grep -Fx 'COMPILE_RESULT=Full Compilation was successful' "$info_file" >/dev/null || fail "full compilation did not succeed in $info_file"
  sof_hash=$(sed -n 's/^SOF_SHA256=//p' "$info_file")
  test -n "$sof_hash" || fail "SOF hash is missing in $info_file"
  test "$(printf '%s\n' "$sof_hash" | wc -l)" -eq 1 || fail "SOF hash is ambiguous in $info_file"
  test "$(grep -Fxc "$sof_hash  $sof_path" "$BUILD_DIR/$BUILD_RUN_TAG-candidate-sof-sha256.txt")" -eq 1 || fail "SOF hash record disagrees for $info_file"
  test -s "$ROOT/$sof_path" || fail "retained SOF is missing or empty: $sof_path"
  actual_sof_hash=$(sha256sum "$ROOT/$sof_path" | awk '{print $1}')
  test "$actual_sof_hash" = "$sof_hash" || fail "retained SOF hash differs for $info_file"
}

verify_build_info "$BUILD_DIR/$BUILD_RUN_TAG-build-info-slave.txt" \
  "$EXPECTED_SLAVE_QSF" "$EXPECTED_SLAVE_MIF" \
  "$OUTPUT_REL/$BUILD_RUN_TAG/DE5a_wr_slave_jtag.sof"
verify_build_info "$BUILD_DIR/$BUILD_RUN_TAG-build-info-master.txt" \
  "$EXPECTED_MASTER_QSF" "$EXPECTED_MASTER_MIF" \
  "$OUTPUT_REL/$BUILD_RUN_TAG/DE5a_wr_master_jtag.sof"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$PROGRAM_DIR/$PROGRAM_RUN_TAG-slave-program.log" || fail "Slave programming success is unverified"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$PROGRAM_DIR/$PROGRAM_RUN_TAG-master-program.log" || fail "Master programming success is unverified"

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
