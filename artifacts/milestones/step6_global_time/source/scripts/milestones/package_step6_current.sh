#!/usr/bin/env bash
# Package exactly the qualified main-root production version. No JTAG writes.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
cd "$ROOT"
MILESTONE="$ROOT/artifacts/milestones/step6_global_time"
RECORD="experiments/step6/$CURRENT_EXPERIMENT"
test "$CURRENT_EXPERIMENT" = EXP-S6-MAIN-ROOT-TIME-VALID-300S-BACKTRACK-20261003
test "$(realpath -m "$MILESTONE")" = "$ROOT/artifacts/milestones/step6_global_time"
test ! -L "$MILESTONE"
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other JTAG reader/programmer before replacing the package.' >&2; exit 2
fi
sha256sum -c output/SHA256SUMS
sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
test "$(sha256sum output/SOURCE_SHA256SUMS | awk '{print $1}')" = \
  418bb2546c08cb7b67c09309b58ce1de4c4668e39e3ec84dc94a4add850c6e6a
COMPILED=$(cat output/SOURCE_COMMIT)
git diff --quiet "$COMPILED" -- firmware vendor quartus quartus_generated
grep -Fx 'TIME_VALID_300S_STAGE=PASS' "$RECORD/raw/cycle.log" >/dev/null
grep -Fx 'CURRENT_PROGRAM=PASS order=slave,master' "$RECORD/raw/cycle.log" >/dev/null
CAPTURE=$(sed -n 's/^TIME_VALID_CAPTURE_PATH=//p' "$RECORD/raw/observe/qualification.log")
test -f "$CAPTURE"
python3 scripts/analysis/step6_time_valid_300s.py "$CAPTURE" \
  --required-duration-ms 300000 --max-sample-gap-ms 1000 \
  --minimum-samples 301 --boards 1-11.1,1-11.2 >/dev/null
python3 -m unittest scripts.tests.test_current_experiment_source scripts.tests.test_step6_time_valid_300s

STAGE=$(mktemp -d /tmp/wr-step6-package.XXXXXX)
LIST="$STAGE/files"
git ls-files -z firmware vendor quartus quartus_generated scripts build output \
  README.md STATUS.md .gitignore .gitattributes > "$LIST"
# Only successful current qualification evidence enters the operational bundle.
# Failed prior images/evidence remain in main-root experiments and Git history.
find "$RECORD" -type f ! -path '*/raw/prechange-output/*' \
  ! -name TRANSFER_SHA256SUMS -print0 >> "$LIST"
mkdir "$STAGE/source"
tar --null -T "$LIST" -cf - | tar -xf - -C "$STAGE/source"
# A standalone source does not embed other milestones. Keep its publication
# list self-contained; this is packaging metadata, not a production input.
awk '$2 ~ /^(build|output)\//' output/PUBLISHED_SHA256SUMS \
  > "$STAGE/source/output/PUBLISHED_SHA256SUMS"
git rev-parse HEAD > "$STAGE/source/SNAPSHOT_SOURCE_COMMIT"
(cd "$STAGE/source"; sha256sum -c output/SOURCE_SHA256SUMS >/dev/null; \
  sha256sum -c output/SHA256SUMS; sha256sum -c output/PUBLISHED_SHA256SUMS >/dev/null)
tar -czf "$STAGE/source.tar.gz" -C "$STAGE/source" .

# Preserve the ENTIRE previous package, including its extracted independent
# repository, outside the canonical milestone. Never touch the protected archive.
BACKUP_BASE=/home/b10504072/04_WR_step6_package_backups
BACKUP="$BACKUP_BASE/$(date -u +%Y%m%dT%H%M%SZ)"
test "$(realpath -m "$BACKUP")" = "$BACKUP"
case "$BACKUP" in "$BACKUP_BASE"/*) ;; *) exit 2 ;; esac
mkdir -p "$BACKUP_BASE"
test ! -e "$BACKUP"
mkdir "$BACKUP"
if [ -d "$MILESTONE" ]; then
  mv -- "$MILESTONE" "$BACKUP/step6_global_time"
fi
mkdir -p "$MILESTONE"
cp "$STAGE/source.tar.gz" "$MILESTONE/source.tar.gz"
cp output/DE5a_wr_master_jtag.sof "$MILESTONE/master.sof"
cp output/DE5a_wr_slave_jtag.sof "$MILESTONE/slave.sof"
cp scripts/milestones/step6_prepare_source.sh "$MILESTONE/prepare_source.sh"
cp scripts/milestones/step6_time_valid_milestone.md "$MILESTONE/README.md"
(cd "$MILESTONE"; sha256sum source.tar.gz > ARCHIVE_SHA256SUMS; \
  sha256sum master.sof slave.sof > SHA256SUMS; \
  sha256sum -c ARCHIVE_SHA256SUMS; sha256sum -c SHA256SUMS)
printf 'STEP6_PACKAGE=QUALIFIED_ROOT_ONLY\nSTEP6_PREVIOUS_PACKAGE_BACKUP=%s\n' "$BACKUP"
printf 'STEP6_PACKAGE_STAGE=%s\n' "$STAGE"
