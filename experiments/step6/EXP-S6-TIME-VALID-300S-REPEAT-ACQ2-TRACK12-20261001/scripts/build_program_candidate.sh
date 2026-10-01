#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat PAGER=cat

SCRIPT_DIR=$(dirname "$(realpath "$0")")
EXP_DIR=$(dirname "$SCRIPT_DIR")
ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
MILESTONE_REL=artifacts/milestones/step6_global_time
SOURCE_REL="$MILESTONE_REL/source"
PATCH="$ROOT/experiments/step6/EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-TWELFTH-20260930/candidate.patch"
RAW_DIR="$EXP_DIR/raw"
EXPECTED_BRANCH=feat/file_cleanup
EXPECTED_BUILD_COMMIT=4c1adf73ab762506939163d467fb8c6b35bca9b4
EXPECTED_SOURCE_ORIGIN=74dc28862653d306e0450cf437ba6d3a230d979d
EXPECTED_SLAVE_MIF=d6165e93f0a43bc6b2a41db8d568ab696916c1a32c1733b47d7df36b5a692916
EXPECTED_MASTER_MIF=07511e0a1148dd120898b1fc53f644f265b098d52912340314dace2a8b1526f6
EXPECTED_SLAVE_SOF=dd5d2e72d6fcde92ace62cf51cfd7fc333c5af1d8d8dd4ebfdc8437b3bba701b
EXPECTED_MASTER_SOF=2beddef2b481c96d6b94bf195fc3ea3cd87513bc776b6884cc775ee8d08f763b
SOURCE_PATCH_REL="$SOURCE_REL/vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"
QUARTUS_BIN=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin

if [ "$#" -ne 1 ]; then
  echo "Usage: bash build_program_candidate.sh EXPECTED_CURRENT_COMMIT" >&2
  exit 2
fi
EXPECTED_CURRENT_COMMIT="$1"
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
ALLOWED_RAW_PREFIX="experiments/step6/$(basename "$EXP_DIR")/raw/"
BUILD_TMP=
BUILD_ROOT=
BUILD_SOURCE_DIR=
WORKTREE_ADDED=0
PATCH_APPLIED=0

fail() {
  printf 'S6TV_ABORT reason=%s\n' "$*" >&2
  exit 2
}

mkdir -p "$RAW_DIR/preflight" "$RAW_DIR/build" "$RAW_DIR/program" "$RAW_DIR/observe"
if [ -e "$RAW_DIR/build/$RUN_TAG-source-diff.patch" ]; then
  fail "run-tag output already exists"
fi
git -C "$ROOT" status --short --branch > "$RAW_DIR/preflight/$RUN_TAG-git-status-before.txt"
git -C "$ROOT" ls-files --others --exclude-standard |
  grep -v -F "$ALLOWED_RAW_PREFIX" > "$RAW_DIR/preflight/$RUN_TAG-untracked-before.txt" || true
date -Is > "$RAW_DIR/preflight/$RUN_TAG-build-start.txt"
git -C "$ROOT" rev-parse HEAD > "$RAW_DIR/preflight/$RUN_TAG-current-head.txt"

test "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED_CURRENT_COMMIT" || fail "pulled commit mismatch"
test "$(git -C "$ROOT" branch --show-current)" = "$EXPECTED_BRANCH" || fail "branch mismatch"
test -z "$(git -C "$ROOT" diff --name-only)" || fail "tracked worktree is dirty"
test -z "$(git -C "$ROOT" diff --cached --name-only)" || fail "index is not clean"
test -x "$QUARTUS_BIN/quartus_pgm" || fail "Quartus 17.0 programmer is unavailable"
test -f "$PATCH" || fail "historical /2+/12 candidate patch is missing"
git -C "$ROOT" cat-file -e "$EXPECTED_BUILD_COMMIT^{commit}" || fail "historical build commit is unavailable"

for process in quartus_stp quartus_pgm quartus_sh; do
  if pgrep -x "$process" >/dev/null; then
    ps -C "$process" -o pid=,comm=,args= >&2 || true
    fail "competing Quartus/JTAG process $process is active"
  fi
done

"$QUARTUS_BIN/quartus_pgm" -l > "$RAW_DIR/preflight/$RUN_TAG-cables.log" 2>&1
grep -Fq 'DE5 [1-11.1]' "$RAW_DIR/preflight/$RUN_TAG-cables.log" || fail "Master JTAG cable is missing"
grep -Fq 'DE5 [1-11.2]' "$RAW_DIR/preflight/$RUN_TAG-cables.log" || fail "Slave JTAG cable is missing"

finish() {
  rc=$?
  trap - EXIT
  set +e
  restore_rc=0

  if [ "$WORKTREE_ADDED" -eq 1 ]; then
    if [ "$PATCH_APPLIED" -eq 1 ]; then
      if git -C "$BUILD_ROOT" apply -R "$PATCH" \
        > "$RAW_DIR/preflight/$RUN_TAG-historical-source-restore.log" 2>&1; then
        PATCH_APPLIED=0
        echo SOURCE_RESTORE=PASS >> "$RAW_DIR/preflight/$RUN_TAG-historical-source-restore.log"
      else
        echo SOURCE_RESTORE=FAIL >> "$RAW_DIR/preflight/$RUN_TAG-historical-source-restore.log"
        restore_rc=1
      fi
    fi
    if (cd "$BUILD_SOURCE_DIR" && sha256sum -c SHA256SUMS \
        > "$RAW_DIR/preflight/$RUN_TAG-source-manifest-restored.log" 2>&1); then
      echo SOURCE_MANIFEST_RESTORED=PASS
    else
      echo SOURCE_MANIFEST_RESTORED=FAIL
      restore_rc=1
    fi
    if (cd "$BUILD_ROOT/$MILESTONE_REL" && sha256sum -c SHA256SUMS \
        > "$RAW_DIR/preflight/$RUN_TAG-artifact-manifest-restored.log" 2>&1); then
      echo ARTIFACT_MANIFEST_RESTORED=PASS
    else
      echo ARTIFACT_MANIFEST_RESTORED=FAIL
      restore_rc=1
    fi
    if [ "$BUILD_ROOT" != "$BUILD_TMP/checkout" ] || [[ "$BUILD_TMP" != /tmp/wr-s6-time-valid-repeat.* ]]; then
      echo TEMP_WORKTREE_PATH_GUARD=FAIL
      restore_rc=1
    elif git -C "$ROOT" worktree remove --force "$BUILD_ROOT" \
        > "$RAW_DIR/preflight/$RUN_TAG-temp-worktree-remove.log" 2>&1; then
      WORKTREE_ADDED=0
      echo TEMP_WORKTREE_REMOVE=PASS
    else
      echo TEMP_WORKTREE_REMOVE=FAIL
      restore_rc=1
    fi
  fi
  if [ -n "$BUILD_TMP" ] && [ -d "$BUILD_TMP" ]; then
    rmdir "$BUILD_TMP" 2>/dev/null || restore_rc=1
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
  git -C "$ROOT" status --short --branch > "$RAW_DIR/preflight/$RUN_TAG-git-status-after.txt"
  date -Is > "$RAW_DIR/preflight/$RUN_TAG-finished-at.txt"
  if [ "$rc" -ne 0 ]; then
    exit "$rc"
  fi
  if [ "$restore_rc" -ne 0 ]; then
    exit 1
  fi
  exit 0
}
trap finish EXIT

BUILD_TMP=$(mktemp -d /tmp/wr-s6-time-valid-repeat.XXXXXX)
BUILD_ROOT="$BUILD_TMP/checkout"
BUILD_SOURCE_DIR="$BUILD_ROOT/$SOURCE_REL"
printf '%s\n' "$BUILD_ROOT" > "$RAW_DIR/preflight/$RUN_TAG-historical-worktree-path.txt"
git -C "$ROOT" worktree add --detach "$BUILD_ROOT" "$EXPECTED_BUILD_COMMIT" \
  > "$RAW_DIR/preflight/$RUN_TAG-worktree-add.log" 2>&1 || fail "cannot create historical build worktree"
WORKTREE_ADDED=1
test "$(git -C "$BUILD_ROOT" rev-parse HEAD)" = "$EXPECTED_BUILD_COMMIT" || fail "historical worktree commit mismatch"
test -z "$(git -C "$BUILD_ROOT" status --porcelain)" || fail "historical worktree is not clean"
git -C "$BUILD_ROOT" describe --always --dirty > "$RAW_DIR/preflight/$RUN_TAG-historical-git-describe-clean.txt"

(cd "$BUILD_SOURCE_DIR" && sha256sum -c SHA256SUMS) \
  > "$RAW_DIR/preflight/$RUN_TAG-source-manifest.log" 2>&1 || fail "historical frozen source manifest failed"
(cd "$BUILD_ROOT/$MILESTONE_REL" && sha256sum -c SHA256SUMS) \
  > "$RAW_DIR/preflight/$RUN_TAG-artifact-manifest.log" 2>&1 || fail "historical canonical artifact manifest failed"
git -C "$BUILD_ROOT" apply --check "$PATCH" || fail "historical /2+/12 patch does not apply to pinned build source"
git -C "$BUILD_ROOT" apply "$PATCH"
PATCH_APPLIED=1
git -C "$BUILD_ROOT" diff --check -- "$SOURCE_PATCH_REL"
git -C "$BUILD_ROOT" diff -- "$SOURCE_PATCH_REL" \
  > "$RAW_DIR/build/$RUN_TAG-source-diff.patch"
git -C "$BUILD_ROOT" describe --always --dirty > "$RAW_DIR/build/$RUN_TAG-firmware-git-version.txt"

(cd "$BUILD_SOURCE_DIR" && bash firmware/scripts/build_master_firmware.sh) \
  2>&1 | tee "$RAW_DIR/build/$RUN_TAG-firmware-master.log"
(cd "$BUILD_SOURCE_DIR" && bash firmware/scripts/build_slave_firmware.sh) \
  2>&1 | tee "$RAW_DIR/build/$RUN_TAG-firmware-slave.log"
cp "$BUILD_SOURCE_DIR/build/firmware/master/build.log" "$RAW_DIR/build/$RUN_TAG-firmware-master-full.log"
cp "$BUILD_SOURCE_DIR/build/firmware/slave/build.log" "$RAW_DIR/build/$RUN_TAG-firmware-slave-full.log"
grep -q '^CONFIG_DETERMINISTIC_BINARY=y$' "$BUILD_SOURCE_DIR/build/firmware/work/master/.config" || fail "Master deterministic config is not enabled"
grep -q '^CONFIG_DETERMINISTIC_BINARY=y$' "$BUILD_SOURCE_DIR/build/firmware/work/slave/.config" || fail "Slave deterministic config is not enabled"

(
  cd "$BUILD_SOURCE_DIR"
  sha256sum build/firmware/slave/wrc.mif build/firmware/master/wrc.mif
) > "$RAW_DIR/build/$RUN_TAG-candidate-mif-sha256.txt"
grep -Fq "$EXPECTED_SLAVE_MIF  build/firmware/slave/wrc.mif" \
  "$RAW_DIR/build/$RUN_TAG-candidate-mif-sha256.txt" || fail "rebuilt Slave MIF hash differs from proven candidate"
grep -Fq "$EXPECTED_MASTER_MIF  build/firmware/master/wrc.mif" \
  "$RAW_DIR/build/$RUN_TAG-candidate-mif-sha256.txt" || fail "rebuilt Master MIF hash differs from proven candidate"

(cd "$BUILD_SOURCE_DIR" && bash scripts/build/build_master.sh) \
  2>&1 | tee "$RAW_DIR/build/$RUN_TAG-quartus-master-wrapper.log"
cp "$BUILD_SOURCE_DIR/build/quartus_master_compile.log" "$RAW_DIR/build/$RUN_TAG-quartus-master-compile.log"
cp "$BUILD_SOURCE_DIR/build/build_master.log" "$RAW_DIR/build/$RUN_TAG-quartus-master.log"
cp "$BUILD_SOURCE_DIR/build/build_info_master.txt" "$RAW_DIR/build/$RUN_TAG-build-info-master.txt"
(cd "$BUILD_SOURCE_DIR" && bash scripts/build/build_slave.sh) \
  2>&1 | tee "$RAW_DIR/build/$RUN_TAG-quartus-slave-wrapper.log"
cp "$BUILD_SOURCE_DIR/build/quartus_slave_compile.log" "$RAW_DIR/build/$RUN_TAG-quartus-slave-compile.log"
cp "$BUILD_SOURCE_DIR/build/build_slave.log" "$RAW_DIR/build/$RUN_TAG-quartus-slave.log"
cp "$BUILD_SOURCE_DIR/build/build_info_slave.txt" "$RAW_DIR/build/$RUN_TAG-build-info-slave.txt"

grep -Fx "SOURCE_ORIGIN_COMMIT=$EXPECTED_SOURCE_ORIGIN" "$RAW_DIR/build/$RUN_TAG-build-info-master.txt" || fail "Master source-origin commit differs"
grep -Fx "SOURCE_ORIGIN_COMMIT=$EXPECTED_SOURCE_ORIGIN" "$RAW_DIR/build/$RUN_TAG-build-info-slave.txt" || fail "Slave source-origin commit differs"
grep -Fx "REPOSITORY_COMMIT=$EXPECTED_BUILD_COMMIT" "$RAW_DIR/build/$RUN_TAG-build-info-master.txt" || fail "Master build commit differs from pinned historical commit"
grep -Fx "REPOSITORY_COMMIT=$EXPECTED_BUILD_COMMIT" "$RAW_DIR/build/$RUN_TAG-build-info-slave.txt" || fail "Slave build commit differs from pinned historical commit"
grep -q 'Full Compilation was successful' "$RAW_DIR/build/$RUN_TAG-build-info-master.txt" || fail "Master Quartus compilation failed"
grep -q 'Full Compilation was successful' "$RAW_DIR/build/$RUN_TAG-build-info-slave.txt" || fail "Slave Quartus compilation failed"
(
  cd "$BUILD_SOURCE_DIR"
  sha256sum quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof \
    quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof
) > "$RAW_DIR/build/$RUN_TAG-candidate-sof-sha256.txt"
grep -Fq "$EXPECTED_SLAVE_SOF  quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof" \
  "$RAW_DIR/build/$RUN_TAG-candidate-sof-sha256.txt" || fail "rebuilt Slave SOF hash differs from proven candidate"
grep -Fq "$EXPECTED_MASTER_SOF  quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof" \
  "$RAW_DIR/build/$RUN_TAG-candidate-sof-sha256.txt" || fail "rebuilt Master SOF hash differs from proven candidate"

sudo -v
(cd "$BUILD_SOURCE_DIR" && CABLE='DE5 [1-11.2]' \
  SOF="$BUILD_SOURCE_DIR/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof" \
  bash scripts/program/program_slave.sh) \
  2>&1 | tee "$RAW_DIR/program/$RUN_TAG-slave-program.log"
grep -q 'JTAG ID code 0x02E660DD' "$RAW_DIR/program/$RUN_TAG-slave-program.log" || fail "Slave programmer log lacks the expected device ID"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$RAW_DIR/program/$RUN_TAG-slave-program.log" || fail "Slave programming did not report a clean success"

(cd "$BUILD_SOURCE_DIR" && CABLE='DE5 [1-11.1]' \
  SOF="$BUILD_SOURCE_DIR/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof" \
  bash scripts/program/program_master.sh) \
  2>&1 | tee "$RAW_DIR/program/$RUN_TAG-master-program.log"
grep -q 'JTAG ID code 0x02E660DD' "$RAW_DIR/program/$RUN_TAG-master-program.log" || fail "Master programmer log lacks the expected device ID"
grep -q 'Programmer was successful. 0 errors, 0 warnings' \
  "$RAW_DIR/program/$RUN_TAG-master-program.log" || fail "Master programming did not report a clean success"

printf 'S6TV_BUILD_PROGRAM_COMPLETE run_tag=%s build_commit=%s slave_sof=%s master_sof=%s\n' \
  "$RUN_TAG" "$EXPECTED_BUILD_COMMIT" "$EXPECTED_SLAVE_SOF" "$EXPECTED_MASTER_SOF"
