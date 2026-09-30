#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
EXP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
SOURCE_DIR="$ROOT/artifacts/milestones/step6_global_time/source"
PATCH="$EXP_DIR/candidate.patch"
RAW_DIR="$EXP_DIR/raw"
EXPECTED_COMMIT=${1:?usage: bash build_program_candidate.sh EXPECTED_COMMIT}
EXPECTED_BRANCH=feat/file_cleanup
PROJECT_SOURCE=vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c
SOURCE_PATCH_REL="artifacts/milestones/step6_global_time/source/$PROJECT_SOURCE"
PATCH_APPLIED=0

fail() {
  printf 'STOP: %s\n' "$*" >&2
  exit 2
}

test "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED_COMMIT" || \
  fail "repository commit mismatch; expected $EXPECTED_COMMIT"
test "$(git -C "$ROOT" branch --show-current)" = "$EXPECTED_BRANCH" || \
  fail "branch is not $EXPECTED_BRANCH"
test -z "$(git -C "$ROOT" diff --name-only)" || \
  fail "tracked worktree has unstaged changes"
test -z "$(git -C "$ROOT" diff --cached --name-only)" || \
  fail "index has staged changes"

mkdir -p "$RAW_DIR/preflight" "$RAW_DIR/build" "$RAW_DIR/program" "$RAW_DIR/observe"
ALLOWED_RAW_PREFIX="experiments/step6/$(basename "$EXP_DIR")/raw/"
while IFS= read -r path; do
  case "$path" in
    "$ALLOWED_RAW_PREFIX"*) ;;
    *) fail "unexpected untracked path: $path" ;;
  esac
done < <(git -C "$ROOT" ls-files --others --exclude-standard)

for process in quartus_stp quartus_pgm quartus_sh; do
  if pgrep -x "$process" >/dev/null; then
    ps -C "$process" -o pid=,comm=,args= >&2 || true
    fail "active Quartus/JTAG process: $process"
  fi
done

git -C "$ROOT" rev-parse HEAD > "$RAW_DIR/preflight/runner-head.txt"
git -C "$ROOT" status --short --branch > "$RAW_DIR/preflight/runner-git-status-before-build.txt"
date -Is > "$RAW_DIR/preflight/runner-build-start.txt"
(cd "$SOURCE_DIR" && sha256sum -c SHA256SUMS) \
  > "$RAW_DIR/preflight/runner-source-manifest.log" 2>&1
(cd "$ROOT/artifacts/milestones/step6_global_time" && sha256sum -c SHA256SUMS) \
  > "$RAW_DIR/preflight/runner-artifact-manifest.log" 2>&1
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm -l \
  > "$RAW_DIR/preflight/runner-cables.log" 2>&1
grep -Fq 'DE5 [1-11.1]' "$RAW_DIR/preflight/runner-cables.log" || \
  fail 'Master JTAG cable is missing'
grep -Fq 'DE5 [1-11.2]' "$RAW_DIR/preflight/runner-cables.log" || \
  fail 'Slave JTAG cable is missing'
git -C "$ROOT" apply --check "$PATCH" || fail 'candidate patch does not apply'

finish() {
  rc=$?
  trap - EXIT
  set +e
  restore_rc=0
  if [ "$PATCH_APPLIED" -eq 1 ]; then
    git -C "$ROOT" apply -R "$PATCH" \
      > "$RAW_DIR/preflight/runner-source-restore.log" 2>&1
    if [ $? -eq 0 ]; then
      echo SOURCE_RESTORE=PASS >> "$RAW_DIR/preflight/runner-source-restore.log"
    else
      echo SOURCE_RESTORE=FAIL >> "$RAW_DIR/preflight/runner-source-restore.log"
      restore_rc=1
    fi
  fi
  if (cd "$SOURCE_DIR" && sha256sum -c SHA256SUMS \
      > "$RAW_DIR/preflight/runner-source-manifest-restored.log" 2>&1); then
    echo SOURCE_MANIFEST_RESTORED=PASS
  else
    echo SOURCE_MANIFEST_RESTORED=FAIL
    restore_rc=1
  fi
  if (cd "$ROOT/artifacts/milestones/step6_global_time" && sha256sum -c SHA256SUMS \
      > "$RAW_DIR/preflight/runner-artifact-manifest-restored.log" 2>&1); then
    echo ARTIFACT_MANIFEST_RESTORED=PASS
  else
    echo ARTIFACT_MANIFEST_RESTORED=FAIL
    restore_rc=1
  fi
  date -Is > "$RAW_DIR/preflight/runner-source-restored-at.txt"
  git -C "$ROOT" status --short --branch \
    > "$RAW_DIR/preflight/runner-git-status-post-restore.txt"
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
  > "$RAW_DIR/build/runner-source-diff.patch"

(cd "$SOURCE_DIR" && ./firmware/scripts/build_master_firmware.sh) \
  2>&1 | tee "$RAW_DIR/build/runner-firmware-master.log"
(cd "$SOURCE_DIR" && ./scripts/build/build_master.sh) \
  2>&1 | tee "$RAW_DIR/build/runner-quartus-master-wrapper.log"
cp "$SOURCE_DIR/build/quartus_master_compile.log" \
  "$RAW_DIR/build/runner-quartus-master-compile.log"
cp "$SOURCE_DIR/build/build_master.log" "$RAW_DIR/build/runner-quartus-master.log"
cp "$SOURCE_DIR/build/build_info_master.txt" "$RAW_DIR/build/runner-build-info-master.txt"

(cd "$SOURCE_DIR" && ./firmware/scripts/build_slave_firmware.sh) \
  2>&1 | tee "$RAW_DIR/build/runner-firmware-slave.log"
(cd "$SOURCE_DIR" && ./scripts/build/build_slave.sh) \
  2>&1 | tee "$RAW_DIR/build/runner-quartus-slave-wrapper.log"
cp "$SOURCE_DIR/build/quartus_slave_compile.log" \
  "$RAW_DIR/build/runner-quartus-slave-compile.log"
cp "$SOURCE_DIR/build/build_slave.log" "$RAW_DIR/build/runner-quartus-slave.log"
cp "$SOURCE_DIR/build/build_info_slave.txt" "$RAW_DIR/build/runner-build-info-slave.txt"

grep -q 'Full Compilation was successful' "$RAW_DIR/build/runner-build-info-master.txt"
grep -q 'Full Compilation was successful' "$RAW_DIR/build/runner-build-info-slave.txt"
sha256sum \
  "$SOURCE_DIR/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof" \
  "$SOURCE_DIR/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof" \
  > "$RAW_DIR/build/runner-candidate-sof-sha256.txt"
cat "$RAW_DIR/build/runner-candidate-sof-sha256.txt"

sudo -v
(cd "$SOURCE_DIR" && ./scripts/pain/pain_program_slave.sh) \
  2>&1 | tee "$RAW_DIR/program/runner-slave-program.log"
(cd "$SOURCE_DIR" && ./scripts/pain/pain_program_master.sh) \
  2>&1 | tee "$RAW_DIR/program/runner-master-program.log"

echo BUILD_AND_PROGRAM_COMPLETE
