#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat PAGER=cat

SCRIPT_DIR=$(dirname "$(realpath "$0")")
EXP_DIR=$(dirname "$SCRIPT_DIR")
ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
MILESTONE_REL=artifacts/milestones/step6_global_time
SOURCE_DIR="$ROOT/$MILESTONE_REL/source"
RAW_DIR="$EXP_DIR/raw"
BUILD_DIR="$RAW_DIR/build"
PROGRAM_DIR="$RAW_DIR/program"
EXPECTED_BRANCH=feat/file_cleanup
EXPECTED_BUILD_COMMIT=4c1adf73ab762506939163d467fb8c6b35bca9b4
EXPECTED_SOURCE_ORIGIN=74dc28862653d306e0450cf437ba6d3a230d979d
EXPECTED_MASTER_QSF=fc2f861ad6cf3a2f660ac66184fe054415515ab4006e578542ddce59ab026530
EXPECTED_SLAVE_QSF=d074d47954f13d539d5477615a8a03752622b2b115dfa6684bc51169a3d7275d
EXPECTED_SDC=083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d
EXPECTED_QUARTUS_VERSION='Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition'
EXPECTED_SLAVE_MIF=d6165e93f0a43bc6b2a41db8d568ab696916c1a32c1733b47d7df36b5a692916
EXPECTED_MASTER_MIF=07511e0a1148dd120898b1fc53f644f265b098d52912340314dace2a8b1526f6
EXP_REL="experiments/step6/$(basename "$EXP_DIR")"
OUTPUT_REL="$EXP_REL/output"
QUARTUS_BIN=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin

if [ "$#" -ne 2 ]; then
  echo "Usage: bash program_candidate.sh EXPECTED_CURRENT_COMMIT BUILD_RUN_TAG" >&2
  exit 2
fi
EXPECTED_CURRENT_COMMIT="$1"
BUILD_RUN_TAG="$2"
if [[ ! "$BUILD_RUN_TAG" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
  echo "S6TV_PROGRAM_ABORT reason=invalid-build-run-tag" >&2
  exit 2
fi

SLAVE_SOF_REL="$OUTPUT_REL/$BUILD_RUN_TAG/DE5a_wr_slave_jtag.sof"
MASTER_SOF_REL="$OUTPUT_REL/$BUILD_RUN_TAG/DE5a_wr_master_jtag.sof"
SLAVE_SOF="$ROOT/$SLAVE_SOF_REL"
MASTER_SOF="$ROOT/$MASTER_SOF_REL"
SLAVE_INFO="$BUILD_DIR/$BUILD_RUN_TAG-build-info-slave.txt"
MASTER_INFO="$BUILD_DIR/$BUILD_RUN_TAG-build-info-master.txt"
SOF_HASH_FILE="$BUILD_DIR/$BUILD_RUN_TAG-candidate-sof-sha256.txt"
BUILD_HEAD_RECORD="$RAW_DIR/preflight/$BUILD_RUN_TAG-current-head.txt"
PROGRAM_RUN_RECORD="$BUILD_DIR/$BUILD_RUN_TAG-program-run.txt"
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)

fail() {
  printf 'S6TV_PROGRAM_ABORT run_tag=%s reason=%s\n' "$RUN_TAG" "$*" >&2
  exit 2
}

mkdir -p "$PROGRAM_DIR" "$RAW_DIR/preflight"
if [ -e "$PROGRAM_DIR/$RUN_TAG-slave-program.log" ] ||
   [ -e "$PROGRAM_DIR/$RUN_TAG-master-program.log" ]; then
  fail "run-tag output already exists"
fi
if [ -e "$PROGRAM_RUN_RECORD" ]; then
  fail "this build run already has a verified programming completion record"
fi
git -C "$ROOT" status --short --branch > "$RAW_DIR/preflight/$RUN_TAG-program-git-status-before.txt"
git -C "$ROOT" rev-parse HEAD > "$RAW_DIR/preflight/$RUN_TAG-program-current-head.txt"

test "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED_CURRENT_COMMIT" || fail "pulled commit mismatch"
test "$(git -C "$ROOT" branch --show-current)" = "$EXPECTED_BRANCH" || fail "branch mismatch"
test -z "$(git -C "$ROOT" diff --name-only)" || fail "tracked worktree is dirty"
test -z "$(git -C "$ROOT" diff --cached --name-only)" || fail "index is not clean"
test -x "$QUARTUS_BIN/quartus_pgm" || fail "Quartus programmer is unavailable"
test -f "$SLAVE_INFO" || fail "Slave build-info is missing"
test -f "$MASTER_INFO" || fail "Master build-info is missing"
test -f "$SOF_HASH_FILE" || fail "candidate SOF hash record is missing"
test -f "$BUILD_HEAD_RECORD" || fail "build checkout identity record is missing"
test "$(tr -d '\r\n' < "$BUILD_HEAD_RECORD")" = "$EXPECTED_CURRENT_COMMIT" || fail "SOFs were built from a different checkout commit"
test -s "$SLAVE_SOF" || fail "retained Slave SOF is missing or empty"
test -s "$MASTER_SOF" || fail "retained Master SOF is missing or empty"

verify_build_info() {
  info_file="$1"
  project_qsf="$2"
  mif_hash="$3"
  sof_rel="$4"
  expected_hash=$(sed -n 's/^SOF_SHA256=//p' "$info_file")
  test -n "$expected_hash" || fail "SOF hash is missing in $info_file"
  test "$(printf '%s\n' "$expected_hash" | wc -l)" -eq 1 || fail "SOF hash is ambiguous in $info_file"
  grep -Fx "SOURCE_ORIGIN_COMMIT=$EXPECTED_SOURCE_ORIGIN" "$info_file" >/dev/null || fail "source origin differs in $info_file"
  grep -Fx "REPOSITORY_COMMIT=$EXPECTED_BUILD_COMMIT" "$info_file" >/dev/null || fail "build commit differs in $info_file"
  grep -Fx "QSF_SHA256=$project_qsf" "$info_file" >/dev/null || fail "QSF differs in $info_file"
  grep -Fx "SDC_SHA256=$EXPECTED_SDC" "$info_file" >/dev/null || fail "SDC differs in $info_file"
  grep -Fx "QUARTUS_VERSION=$EXPECTED_QUARTUS_VERSION" "$info_file" >/dev/null || fail "Quartus version differs in $info_file"
  grep -Fx "MIF_SHA256=$mif_hash" "$info_file" >/dev/null || fail "firmware MIF differs in $info_file"
  grep -q '^FITTER_STATUS=Fitter Status : Successful' "$info_file" || fail "Fitter did not succeed in $info_file"
  grep -Fx 'COMPILE_RESULT=Full Compilation was successful' "$info_file" >/dev/null || fail "full compilation did not succeed in $info_file"
  test "$(grep -Fxc "$expected_hash  $sof_rel" "$SOF_HASH_FILE")" -eq 1 || fail "SOF manifest differs for $info_file"
  actual_hash=$(sha256sum "$ROOT/$sof_rel" | awk '{print $1}')
  test "$actual_hash" = "$expected_hash" || fail "retained SOF content hash differs for $info_file"
}

verify_build_info "$SLAVE_INFO" "$EXPECTED_SLAVE_QSF" "$EXPECTED_SLAVE_MIF" "$SLAVE_SOF_REL"
verify_build_info "$MASTER_INFO" "$EXPECTED_MASTER_QSF" "$EXPECTED_MASTER_MIF" "$MASTER_SOF_REL"

for process in quartus_stp quartus_pgm quartus_sh; do
  if pgrep -x "$process" >/dev/null; then
    ps -C "$process" -o pid=,comm=,args= >&2 || true
    fail "competing Quartus process $process is active"
  fi
done

"$QUARTUS_BIN/quartus_pgm" -l > "$RAW_DIR/preflight/$RUN_TAG-program-cables.log" 2>&1
grep -Fq 'DE5 [1-11.1]' "$RAW_DIR/preflight/$RUN_TAG-program-cables.log" || fail "Master JTAG cable is missing"
grep -Fq 'DE5 [1-11.2]' "$RAW_DIR/preflight/$RUN_TAG-program-cables.log" || fail "Slave JTAG cable is missing"

sudo -v
(cd "$SOURCE_DIR" && CABLE='DE5 [1-11.2]' SOF="$SLAVE_SOF" \
  bash scripts/program/program_slave.sh) \
  2>&1 | tee "$PROGRAM_DIR/$RUN_TAG-slave-program.log"
grep -q 'JTAG ID code 0x02E660DD' "$PROGRAM_DIR/$RUN_TAG-slave-program.log" || fail "Slave programmer log lacks the expected device ID"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$PROGRAM_DIR/$RUN_TAG-slave-program.log" || fail "Slave programming did not report a clean success"

(cd "$SOURCE_DIR" && CABLE='DE5 [1-11.1]' SOF="$MASTER_SOF" \
  bash scripts/program/program_master.sh) \
  2>&1 | tee "$PROGRAM_DIR/$RUN_TAG-master-program.log"
grep -q 'JTAG ID code 0x02E660DD' "$PROGRAM_DIR/$RUN_TAG-master-program.log" || fail "Master programmer log lacks the expected device ID"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$PROGRAM_DIR/$RUN_TAG-master-program.log" || fail "Master programming did not report a clean success"

test -s "$SLAVE_SOF" && test -s "$MASTER_SOF" || fail "one or both retained SOFs disappeared after programming"
verify_build_info "$SLAVE_INFO" "$EXPECTED_SLAVE_QSF" "$EXPECTED_SLAVE_MIF" "$SLAVE_SOF_REL"
verify_build_info "$MASTER_INFO" "$EXPECTED_MASTER_QSF" "$EXPECTED_MASTER_MIF" "$MASTER_SOF_REL"
printf 'BUILD_RUN_TAG=%s\nPROGRAM_RUN_TAG=%s\nSLAVE_SOF_SHA256=%s\nMASTER_SOF_SHA256=%s\n' \
  "$BUILD_RUN_TAG" "$RUN_TAG" \
  "$(sed -n 's/^SOF_SHA256=//p' "$SLAVE_INFO")" \
  "$(sed -n 's/^SOF_SHA256=//p' "$MASTER_INFO")" > "$PROGRAM_RUN_RECORD"
printf 'S6TV_PROGRAM_COMPLETE program_run_tag=%s build_run_tag=%s slave_sof=%s master_sof=%s\n' \
  "$RUN_TAG" "$BUILD_RUN_TAG" "$SLAVE_SOF" "$MASTER_SOF"
