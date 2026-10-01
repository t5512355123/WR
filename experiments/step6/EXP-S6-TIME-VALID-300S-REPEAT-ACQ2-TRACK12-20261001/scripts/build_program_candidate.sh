#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat PAGER=cat

SCRIPT_DIR=$(dirname "$(realpath "$0")")
EXP_DIR=$(dirname "$SCRIPT_DIR")
ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
MILESTONE_DIR="$ROOT/artifacts/milestones/step6_global_time"
SOURCE_DIR="$MILESTONE_DIR/source"
PATCH="$ROOT/experiments/step6/EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-TWELFTH-20260930/candidate.patch"
RAW_DIR="$EXP_DIR/raw"
EXPECTED_BRANCH=feat/file_cleanup
EXPECTED_SLAVE=dd5d2e72d6fcde92ace62cf51cfd7fc333c5af1d8d8dd4ebfdc8437b3bba701b
EXPECTED_MASTER=2beddef2b481c96d6b94bf195fc3ea3cd87513bc776b6884cc775ee8d08f763b
PROJECT_SOURCE=vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c
SOURCE_PATCH_REL="artifacts/milestones/step6_global_time/source/$PROJECT_SOURCE"
QUARTUS_BIN=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin

if [ "$#" -ne 1 ]; then
  echo "Usage: bash build_program_candidate.sh EXPECTED_COMMIT" >&2
  exit 2
fi
EXPECTED_COMMIT="$1"
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
ALLOWED_RAW_PREFIX="experiments/step6/$(basename "$EXP_DIR")/raw/"

fail() {
  printf 'S6TV_ABORT reason=%s\n' "$*" >&2
  exit 2
}

test "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED_COMMIT" || fail "commit mismatch"
test "$(git -C "$ROOT" branch --show-current)" = "$EXPECTED_BRANCH" || fail "branch mismatch"
test -z "$(git -C "$ROOT" diff --name-only)" || fail "tracked worktree is dirty"
test -z "$(git -C "$ROOT" diff --cached --name-only)" || fail "index is not clean"
test -x "$QUARTUS_BIN/quartus_pgm" || fail "Quartus 17.0 programmer is unavailable"
test -f "$PATCH" || fail "historical /2+/12 candidate patch is missing"

mkdir -p "$RAW_DIR/preflight" "$RAW_DIR/build" "$RAW_DIR/program" "$RAW_DIR/observe"
if [ -e "$RAW_DIR/build/$RUN_TAG-source-diff.patch" ]; then
  fail "run-tag output already exists"
fi
git -C "$ROOT" status --short --branch > "$RAW_DIR/preflight/$RUN_TAG-git-status-before.txt"
git -C "$ROOT" ls-files --others --exclude-standard |
  grep -v -F "$ALLOWED_RAW_PREFIX" > "$RAW_DIR/preflight/$RUN_TAG-untracked-before.txt" || true
date -Is > "$RAW_DIR/preflight/$RUN_TAG-build-start.txt"
git -C "$ROOT" rev-parse HEAD > "$RAW_DIR/preflight/$RUN_TAG-head.txt"

for process in quartus_stp quartus_pgm quartus_sh; do
  if pgrep -x "$process" >/dev/null; then
    ps -C "$process" -o pid=,comm=,args= >&2 || true
    fail "competing Quartus/JTAG process $process is active"
  fi
done

(cd "$SOURCE_DIR" && sha256sum -c SHA256SUMS) \
  > "$RAW_DIR/preflight/$RUN_TAG-source-manifest.log" 2>&1 ||
  fail "frozen source manifest failed"
(cd "$MILESTONE_DIR" && sha256sum -c SHA256SUMS) \
  > "$RAW_DIR/preflight/$RUN_TAG-artifact-manifest.log" 2>&1 ||
  fail "canonical artifact manifest failed"
"$QUARTUS_BIN/quartus_pgm" -l > "$RAW_DIR/preflight/$RUN_TAG-cables.log" 2>&1
grep -Fq 'DE5 [1-11.1]' "$RAW_DIR/preflight/$RUN_TAG-cables.log" ||
  fail "Master JTAG cable is missing"
grep -Fq 'DE5 [1-11.2]' "$RAW_DIR/preflight/$RUN_TAG-cables.log" ||
  fail "Slave JTAG cable is missing"
git -C "$ROOT" apply --check "$PATCH" || fail "historical /2+/12 patch does not apply"

PATCH_APPLIED=0
finish() {
  rc=$?
  trap - EXIT
  set +e
  restore_rc=0
  if [ "$PATCH_APPLIED" -eq 1 ]; then
    git -C "$ROOT" apply -R "$PATCH" \
      > "$RAW_DIR/preflight/$RUN_TAG-source-restore.log" 2>&1
    if [ "$?" -eq 0 ]; then
      echo SOURCE_RESTORE=PASS >> "$RAW_DIR/preflight/$RUN_TAG-source-restore.log"
    else
      echo SOURCE_RESTORE=FAIL >> "$RAW_DIR/preflight/$RUN_TAG-source-restore.log"
      restore_rc=1
    fi
  fi
  if (cd "$SOURCE_DIR" && sha256sum -c SHA256SUMS \
      > "$RAW_DIR/preflight/$RUN_TAG-source-manifest-restored.log" 2>&1); then
    echo SOURCE_MANIFEST_RESTORED=PASS
  else
    echo SOURCE_MANIFEST_RESTORED=FAIL
    restore_rc=1
  fi
  if (cd "$MILESTONE_DIR" && sha256sum -c SHA256SUMS \
      > "$RAW_DIR/preflight/$RUN_TAG-artifact-manifest-restored.log" 2>&1); then
    echo ARTIFACT_MANIFEST_RESTORED=PASS
  else
    echo ARTIFACT_MANIFEST_RESTORED=FAIL
    restore_rc=1
  fi
  git -C "$ROOT" ls-files --others --exclude-standard |
    grep -v -F "$ALLOWED_RAW_PREFIX" > "$RAW_DIR/preflight/$RUN_TAG-untracked-after.txt" || true
  if ! diff -u "$RAW_DIR/preflight/$RUN_TAG-untracked-before.txt" \
      "$RAW_DIR/preflight/$RUN_TAG-untracked-after.txt"; then
    echo EXTERNAL_UNTRACKED_PATHS_PRESERVED=FAIL
    restore_rc=1
  else
    echo EXTERNAL_UNTRACKED_PATHS_PRESERVED=PASS
  fi
  git -C "$ROOT" status --short --branch \
    > "$RAW_DIR/preflight/$RUN_TAG-git-status-after.txt"
  date -Is > "$RAW_DIR/preflight/$RUN_TAG-source-restored-at.txt"
  if [ "$rc" -ne 0 ] || [ "$restore_rc" -ne 0 ]; then
    exit 1
  fi
  exit 0
}
trap finish EXIT

git -C "$ROOT" apply "$PATCH"
PATCH_APPLIED=1
git -C "$ROOT" diff --check -- "$SOURCE_PATCH_REL"
git -C "$ROOT" diff -- "$SOURCE_PATCH_REL" \
  > "$RAW_DIR/build/$RUN_TAG-source-diff.patch"

(cd "$SOURCE_DIR" && bash firmware/scripts/build_master_firmware.sh) \
  2>&1 | tee "$RAW_DIR/build/$RUN_TAG-firmware-master.log"
(cd "$SOURCE_DIR" && bash scripts/build/build_master.sh) \
  2>&1 | tee "$RAW_DIR/build/$RUN_TAG-quartus-master-wrapper.log"
cp "$SOURCE_DIR/build/quartus_master_compile.log" "$RAW_DIR/build/$RUN_TAG-quartus-master-compile.log"
cp "$SOURCE_DIR/build/build_master.log" "$RAW_DIR/build/$RUN_TAG-quartus-master.log"
cp "$SOURCE_DIR/build/build_info_master.txt" "$RAW_DIR/build/$RUN_TAG-build-info-master.txt"

(cd "$SOURCE_DIR" && bash firmware/scripts/build_slave_firmware.sh) \
  2>&1 | tee "$RAW_DIR/build/$RUN_TAG-firmware-slave.log"
(cd "$SOURCE_DIR" && bash scripts/build/build_slave.sh) \
  2>&1 | tee "$RAW_DIR/build/$RUN_TAG-quartus-slave-wrapper.log"
cp "$SOURCE_DIR/build/quartus_slave_compile.log" "$RAW_DIR/build/$RUN_TAG-quartus-slave-compile.log"
cp "$SOURCE_DIR/build/build_slave.log" "$RAW_DIR/build/$RUN_TAG-quartus-slave.log"
cp "$SOURCE_DIR/build/build_info_slave.txt" "$RAW_DIR/build/$RUN_TAG-build-info-slave.txt"

grep -q 'Full Compilation was successful' "$RAW_DIR/build/$RUN_TAG-build-info-master.txt" ||
  fail "Master Quartus compilation failed"
grep -q 'Full Compilation was successful' "$RAW_DIR/build/$RUN_TAG-build-info-slave.txt" ||
  fail "Slave Quartus compilation failed"
(
  cd "$SOURCE_DIR"
  sha256sum quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof \
    quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof
) > "$RAW_DIR/build/$RUN_TAG-candidate-sof-sha256.txt"
grep -Fq "$EXPECTED_SLAVE  quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof" \
  "$RAW_DIR/build/$RUN_TAG-candidate-sof-sha256.txt" ||
  fail "rebuilt Slave SOF hash differs from the proven /2+/12 image"
grep -Fq "$EXPECTED_MASTER  quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof" \
  "$RAW_DIR/build/$RUN_TAG-candidate-sof-sha256.txt" ||
  fail "rebuilt Master SOF hash differs from the proven /2+/12 image"

sudo -v
(cd "$SOURCE_DIR" && CABLE='DE5 [1-11.2]' \
  SOF="$SOURCE_DIR/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof" \
  bash scripts/program/program_slave.sh) \
  2>&1 | tee "$RAW_DIR/program/$RUN_TAG-slave-program.log"
grep -q 'JTAG ID code 0x02E660DD' "$RAW_DIR/program/$RUN_TAG-slave-program.log" ||
  fail "Slave programmer log lacks the expected device ID"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$RAW_DIR/program/$RUN_TAG-slave-program.log" ||
  fail "Slave programming did not report a clean success"

(cd "$SOURCE_DIR" && CABLE='DE5 [1-11.1]' \
  SOF="$SOURCE_DIR/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof" \
  bash scripts/program/program_master.sh) \
  2>&1 | tee "$RAW_DIR/program/$RUN_TAG-master-program.log"
grep -q 'JTAG ID code 0x02E660DD' "$RAW_DIR/program/$RUN_TAG-master-program.log" ||
  fail "Master programmer log lacks the expected device ID"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$RAW_DIR/program/$RUN_TAG-master-program.log" ||
  fail "Master programming did not report a clean success"

printf 'S6TV_BUILD_PROGRAM_COMPLETE run_tag=%s slave_sof=%s master_sof=%s\n' \
  "$RUN_TAG" "$EXPECTED_SLAVE" "$EXPECTED_MASTER"
