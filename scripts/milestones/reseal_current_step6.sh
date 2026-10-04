#!/usr/bin/env bash
# Candidate source is tested inside the milestone; promote only after PASS.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MILESTONE="$ROOT/artifacts/milestones/step6_global_time"
SOURCE="$MILESTONE/source"
EXP=EXP-S6-CURRENT-MILESTONE-RESEAL-REPRO-20261004
RECORD="$ROOT/experiments/step6/$EXP"
MANIFEST=418bb2546c08cb7b67c09309b58ce1de4c4668e39e3ec84dc94a4add850c6e6a
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}

test "$ROOT" = /home/b10504072/04_WR
test "$(realpath "$ROOT")" = "$ROOT"
test "$(realpath "$MILESTONE")" = "$MILESTONE"
test ! -L "$MILESTONE" && test ! -L "$SOURCE"
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Another JTAG reader/programmer is running.' >&2; exit 2
fi
mkdir -p "$RECORD/raw" "$RECORD/analysis"

case "${1:-}" in
prepare)
  cd "$ROOT"
  git diff --quiet HEAD -- firmware vendor quartus quartus_generated
  sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
  test "$(sha256sum output/SOURCE_SHA256SUMS | awk '{print $1}')" = "$MANIFEST"
  sha256sum -c output/SHA256SUMS
  test ! -e "$RECORD/raw/candidate-backup-path.txt"
  "$QUARTUS_STP" -t scripts/jtag/read_step1_6_dashboard.tcl 2000 125000000 \
    > "$RECORD/raw/preprogram-dashboard.log" 2>&1
  STAGE=$(mktemp -d /tmp/wr-current-step6-snapshot.XXXXXX)
  mkdir "$STAGE/source"
  git archive HEAD firmware vendor quartus quartus_generated scripts build output \
    README.md STATUS.md .gitignore .gitattributes | tar -xf - -C "$STAGE/source"
  # This standalone repository must not depend on other frozen milestones.
  awk '$2 ~ /^(build|output)\//' output/PUBLISHED_SHA256SUMS \
    > "$STAGE/source/output/PUBLISHED_SHA256SUMS"
  git rev-parse HEAD > "$STAGE/source/SNAPSHOT_SOURCE_COMMIT"
  printf 'CANDIDATE_NOT_SEALED\n' > "$STAGE/source/.archive-sha256"
  (cd "$STAGE/source"; sha256sum -c output/SOURCE_SHA256SUMS >/dev/null;
    sha256sum -c output/SHA256SUMS;
    sha256sum -c output/PUBLISHED_SHA256SUMS >/dev/null)
  BACKUP_BASE=/home/b10504072/04_WR_step6_package_backups
  BACKUP="$BACKUP_BASE/$(date -u +%Y%m%dT%H%M%SZ)-current-reseal"
  test "$(realpath -m "$BACKUP")" = "$BACKUP"
  case "$BACKUP" in "$BACKUP_BASE"/*) ;; *) exit 2 ;; esac
  mkdir -p "$BACKUP_BASE"
  test ! -e "$BACKUP"
  mkdir "$BACKUP"
  if [ -d "$SOURCE" ]; then
    test "$(realpath "$SOURCE")" = "$SOURCE"
    mv -- "$SOURCE" "$BACKUP/previous-source"
  fi
  test ! -e "$SOURCE"
  mv -- "$STAGE/source" "$SOURCE"
  printf '%s\n' "$BACKUP" > "$RECORD/raw/candidate-backup-path.txt"
  git -C "$SOURCE" init -q
  git -C "$SOURCE" add -f .
  git -C "$SOURCE" -c user.name='WR milestone snapshot' \
    -c user.email='snapshot@localhost' commit -q -m 'Current qualified controls: independent reproduction candidate'
  git -C "$SOURCE" rev-parse HEAD > "$RECORD/raw/independent-source-commit.txt"
  echo "STEP6_CANDIDATE_PREPARED=$SOURCE backup=$BACKUP"
  ;;
reproduce)
  test "$(realpath "$SOURCE")" = "$SOURCE"
  cd "$SOURCE"
  test "$(git rev-parse HEAD)" = "$(cat "$RECORD/raw/independent-source-commit.txt")"
  test ! -e "$RECORD/raw/reproduction-started.txt"
  date -Is > "$RECORD/raw/reproduction-started.txt"
  exec > >(tee "$RECORD/raw/reproduction.log") 2>&1
  trap 'rc=$?; printf "STEP6_REPRODUCTION_EXIT=%s time=%s\n" "$rc" "$(date -Is)"' EXIT
  printf 'STEP6_REPRODUCTION_BEGIN source=%s time=%s\n' "$SOURCE" "$(date -Is)"
  python3 -m unittest scripts.tests.test_current_experiment_source scripts.tests.test_step6_time_valid_300s
  # Existing build scripts replace only these validated candidate work dirs.
  for role in master slave; do
    work="$SOURCE/build/firmware/work/$role"
    test "$(realpath -m "$work")" = "$work"
    test ! -L "$work"
  done
  bash scripts/build/build_current.sh
  bash scripts/build/compile_current.sh
  test "$(sha256sum output/SOURCE_SHA256SUMS | awk '{print $1}')" = "$MANIFEST"
  sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
  cp output/build_info_master.txt output/build_info_slave.txt "$RECORD/raw/"
  cp output/SHA256SUMS "$RECORD/raw/rebuilt-sofs.sha256"
  cp output/SOURCE_COMMIT "$RECORD/raw/compiled-commit.txt"
  bash scripts/program/program_current.sh
  ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$RECORD/raw/dashboard-before.log"
  VERIFY_RC=0
  TIME_VALID_ACQUISITION_TIMEOUT_S=600 bash scripts/monitor/verify_time_valid_300s.sh \
    | tee "$RECORD/raw/verifier.log" || VERIFY_RC=$?
  ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$RECORD/raw/dashboard-after.log"
  if [ "$VERIFY_RC" -ne 0 ]; then
    echo "STANDALONE_TIME_VALID_300S=NOT_ESTABLISHED verifier_rc=$VERIFY_RC"
    exit "$VERIFY_RC"
  fi
  capture=$(sed -n 's/^TIME_VALID_CAPTURE_PATH=//p' "$RECORD/raw/verifier.log")
  result=$(sed -n 's/^TIME_VALID_RESULT_PATH=//p' "$RECORD/raw/verifier.log")
  test -f "$capture" && test -f "$result"
  cp "$capture" "$RECORD/raw/qualified-capture.log"
  cp "$result" "$RECORD/analysis/qualified-result.json"
  python3 scripts/analysis/step6_time_valid_300s.py "$RECORD/raw/qualified-capture.log" \
    --required-duration-ms 300000 --max-sample-gap-ms 1000 \
    --minimum-samples 301 --boards 1-11.1,1-11.2 > "$RECORD/analysis/recomputed-result.json"
  cmp "$RECORD/analysis/qualified-result.json" "$RECORD/analysis/recomputed-result.json"
  echo 'STANDALONE_TIME_VALID_300S=PASS'
  ;;
seal)
  REPORT="$RECORD/REPORT.md"
  test -f "$REPORT"
  grep -Fx 'STANDALONE_TIME_VALID_300S = PASS' "$REPORT" >/dev/null
  grep -Fx 'STANDALONE_TIME_VALID_300S=PASS' "$RECORD/raw/reproduction.log" >/dev/null
  grep -Fx 'CURRENT_PROGRAM=PASS order=slave,master' "$RECORD/raw/reproduction.log" >/dev/null
  test "$(realpath "$SOURCE")" = "$SOURCE"
  cd "$SOURCE"
  sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
  test "$(sha256sum output/SOURCE_SHA256SUMS | awk '{print $1}')" = "$MANIFEST"
  sha256sum -c output/SHA256SUMS
  sha256sum -c output/PUBLISHED_SHA256SUMS >/dev/null
  test "$(cat output/SOURCE_COMMIT)" = "$(cat "$RECORD/raw/independent-source-commit.txt")"
  git diff --quiet "$(cat output/SOURCE_COMMIT)" -- firmware vendor quartus quartus_generated
  python3 scripts/analysis/step6_time_valid_300s.py "$RECORD/raw/qualified-capture.log" \
    --required-duration-ms 300000 --max-sample-gap-ms 1000 \
    --minimum-samples 301 --boards 1-11.1,1-11.2 >/dev/null
  # Laptop independently verified this exact capture before promotion.
  sha256sum -c "$RECORD/analysis/laptop-verified-capture.sha256"
  STAGE=$(mktemp -d /tmp/wr-current-step6-seal.XXXXXX)
  mkdir "$STAGE/source"
  git ls-files -z | tar --null --exclude='.archive-sha256' -T - -cf - \
    | tar -xf - -C "$STAGE/source"
  NEW_RECORD="$STAGE/source/experiments/step6/$EXP"
  mkdir -p "$NEW_RECORD/raw" "$NEW_RECORD/analysis"
  cp "$REPORT" "$NEW_RECORD/REPORT.md"
  cp "$RECORD/raw/qualified-capture.log" "$RECORD/raw/dashboard-after.log" \
    "$RECORD/raw/build_info_master.txt" "$RECORD/raw/build_info_slave.txt" \
    "$RECORD/raw/reproduction.log" "$NEW_RECORD/raw/"
  cp "$RECORD/analysis/qualified-result.json" "$NEW_RECORD/analysis/"
  cp "$ROOT/scripts/milestones/current_step6_reproduced.md" "$STAGE/source/README.md"
  cp "$ROOT/scripts/milestones/current_step6_reproduced.md" \
    "$STAGE/source/scripts/milestones/step6_time_valid_milestone.md"
  (cd "$STAGE/source"; sha256sum -c output/SOURCE_SHA256SUMS >/dev/null;
    sha256sum -c output/SHA256SUMS; sha256sum -c output/PUBLISHED_SHA256SUMS >/dev/null)
  tar -czf "$STAGE/source.tar.gz" -C "$STAGE/source" .
  test "$(stat -c %s "$STAGE/source.tar.gz")" -lt 100000000
  cp output/DE5a_wr_master_jtag.sof "$STAGE/master.sof"
  cp output/DE5a_wr_slave_jtag.sof "$STAGE/slave.sof"
  cp "$ROOT/scripts/milestones/step6_prepare_source.sh" "$STAGE/prepare_source.sh"
  cp "$ROOT/scripts/milestones/current_step6_reproduced.md" "$STAGE/README.md"
  cp "$REPORT" "$STAGE/VERIFICATION.md"
  cp "$RECORD/raw/qualified-capture.log" "$STAGE/verification-capture.log"
  cp "$RECORD/raw/dashboard-after.log" "$STAGE/verification-dashboard.log"
  cp "$RECORD/analysis/qualified-result.json" "$STAGE/verification-result.json"
  (cd "$STAGE"; sha256sum source.tar.gz > ARCHIVE_SHA256SUMS;
    sha256sum master.sof slave.sof > SHA256SUMS;
    sha256sum verification-capture.log verification-dashboard.log \
      verification-result.json VERIFICATION.md > VERIFICATION_SHA256SUMS)
  BACKUP=$(cat "$RECORD/raw/candidate-backup-path.txt")
  case "$BACKUP" in /home/b10504072/04_WR_step6_package_backups/*-current-reseal) ;; *) exit 2 ;; esac
  test "$(realpath "$BACKUP")" = "$BACKUP"
  test ! -e "$BACKUP/previous-package"
  # Recoverable atomic directory replacement, never recursive deletion.
  mv -- "$MILESTONE" "$BACKUP/previous-package"
  mkdir "$MILESTONE"
  for file in source.tar.gz master.sof slave.sof prepare_source.sh README.md \
    VERIFICATION.md verification-capture.log verification-dashboard.log \
    verification-result.json ARCHIVE_SHA256SUMS SHA256SUMS VERIFICATION_SHA256SUMS; do
    cp "$STAGE/$file" "$MILESTONE/$file"
  done
  bash "$MILESTONE/prepare_source.sh"
  (cd "$MILESTONE"; sha256sum -c VERIFICATION_SHA256SUMS;
    cmp master.sof source/output/DE5a_wr_master_jtag.sof;
    cmp slave.sof source/output/DE5a_wr_slave_jtag.sof)
  echo "STEP6_SEALED=PASS backup=$BACKUP staging=$STAGE"
  ;;
restore-failed)
  BACKUP=$(cat "$RECORD/raw/candidate-backup-path.txt")
  case "$BACKUP" in /home/b10504072/04_WR_step6_package_backups/*-current-reseal) ;; *) exit 2 ;; esac
  test "$(realpath "$BACKUP")" = "$BACKUP"
  test "$(realpath "$SOURCE")" = "$SOURCE"
  ! grep -Fxq 'STANDALONE_TIME_VALID_300S=PASS' "$RECORD/raw/reproduction.log"
  test ! -e "$BACKUP/unqualified-source"
  mv -- "$SOURCE" "$BACKUP/unqualified-source"
  test -d "$BACKUP/previous-source"
  mv -- "$BACKUP/previous-source" "$SOURCE"
  (cd "$MILESTONE"; sha256sum -c ARCHIVE_SHA256SUMS; sha256sum -c SHA256SUMS)
  echo "UNQUALIFIED_SOURCE_PRESERVED=$BACKUP/unqualified-source"
  ;;
*) echo 'Usage: reseal_current_step6.sh prepare|reproduce|seal|restore-failed' >&2; exit 2 ;;
esac
