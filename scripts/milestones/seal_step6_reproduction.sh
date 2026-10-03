#!/usr/bin/env bash
# Seal only the newly verified independent build. Does not program hardware.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MILESTONE="$ROOT/artifacts/milestones/step6_global_time"
SOURCE="$MILESTONE/source"
REPORT="$ROOT/experiments/step6/EXP-S6-MILESTONE-MAIN-ROOT-TIME-VALID-300S-REPRO-20261003/REPORT.md"
test "$(realpath "$SOURCE")" = "$SOURCE"
test ! -L "$MILESTONE" && test ! -L "$SOURCE"
test -f "$REPORT"
grep -Fx 'STANDALONE_TIME_VALID_300S = PASS' "$REPORT" >/dev/null
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other JTAG reader/programmer before sealing.' >&2; exit 2
fi
cd "$SOURCE"
source scripts/build/current_experiment.env
test "$CURRENT_EXPERIMENT" = EXP-S6-MAIN-ROOT-TIME-VALID-300S-BACKTRACK-20261003
sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
test "$(sha256sum output/SOURCE_SHA256SUMS | awk '{print $1}')" = \
  418bb2546c08cb7b67c09309b58ce1de4c4668e39e3ec84dc94a4add850c6e6a
sha256sum -c output/SHA256SUMS
sha256sum -c output/PUBLISHED_SHA256SUMS >/dev/null
git diff --quiet "$(cat output/SOURCE_COMMIT)" -- firmware vendor quartus quartus_generated
printf '%s  %s\n' "$CURRENT_MASTER_MIF_SHA256" build/firmware/master/wrc.mif \
  "$CURRENT_SLAVE_MIF_SHA256" build/firmware/slave/wrc.mif | sha256sum -c -
mapfile -t CAPTURES < <(find "experiments/step6/$CURRENT_EXPERIMENT/raw/cycles" \
  -name qualified-capture.log -type f)
test "${#CAPTURES[@]}" -eq 1
CYCLE=${CAPTURES[0]%/qualified-capture.log}
grep -q '^CYCLE_END .*result=TIME_VALID_CAPTURE_PASSED ' "$CYCLE/cycle.log"
grep -Fx 'CURRENT_PROGRAM=PASS order=slave,master' "$CYCLE/cycle.log" >/dev/null
cmp "$CYCLE/master.sof" output/DE5a_wr_master_jtag.sof
cmp "$CYCLE/slave.sof" output/DE5a_wr_slave_jtag.sof
python3 scripts/analysis/step6_time_valid_300s.py "${CAPTURES[0]}" \
  --required-duration-ms 300000 --max-sample-gap-ms 1000 \
  --minimum-samples 301 --boards 1-11.1,1-11.2 >/dev/null

STAGE=$(mktemp -d /tmp/wr-step6-seal.XXXXXX)
git ls-files -z > "$STAGE/files"
find "experiments/step6/$CURRENT_EXPERIMENT" -type f \
  ! -path '*/raw/prechange-output/*' ! -name TRANSFER_SHA256SUMS \
  -print0 >> "$STAGE/files"
sort -zu "$STAGE/files" -o "$STAGE/files"
mkdir "$STAGE/source"
tar --null --exclude='.archive-sha256' -T "$STAGE/files" -cf - \
  | tar -xf - -C "$STAGE/source"
cp "$REPORT" "$STAGE/source/REPRODUCTION_REPORT.md"
cp "$ROOT/scripts/milestones/step6_time_valid_milestone.md" "$STAGE/source/README.md"
cp "$ROOT/scripts/milestones/step6_time_valid_milestone.md" \
  "$STAGE/source/scripts/milestones/step6_time_valid_milestone.md"
cp "$ROOT/scripts/milestones/seal_step6_reproduction.sh" \
  "$STAGE/source/scripts/milestones/seal_step6_reproduction.sh"
cp "$ROOT/scripts/experiments/continue_step6_reproduction_capture.sh" \
  "$STAGE/source/scripts/experiments/continue_step6_reproduction_capture.sh"
(cd "$STAGE/source"; sha256sum -c output/SOURCE_SHA256SUMS >/dev/null; \
  sha256sum -c output/SHA256SUMS; sha256sum -c output/PUBLISHED_SHA256SUMS >/dev/null)
tar -czf "$STAGE/source.tar.gz" -C "$STAGE/source" .
test "$(stat -c %s "$STAGE/source.tar.gz")" -lt 100000000
cp "$STAGE/source.tar.gz" "$MILESTONE/source.tar.gz"
cp output/DE5a_wr_master_jtag.sof "$MILESTONE/master.sof"
cp output/DE5a_wr_slave_jtag.sof "$MILESTONE/slave.sof"
cp "$ROOT/scripts/milestones/step6_time_valid_milestone.md" "$MILESTONE/README.md"
cp "$REPORT" "$MILESTONE/VERIFICATION.md"
cp "$CYCLE/dashboard-after.log" "$MILESTONE/verification-dashboard.log"
cp "$CYCLE/qualified-result.json" "$MILESTONE/verification-result.json"
cp "$CYCLE/qualified-capture.log" "$MILESTONE/verification-capture.log"
cd "$MILESTONE"
sha256sum source.tar.gz > ARCHIVE_SHA256SUMS
sha256sum master.sof slave.sof > SHA256SUMS
sha256sum verification-capture.log verification-result.json \
  verification-dashboard.log VERIFICATION.md > VERIFICATION_SHA256SUMS
sha256sum -c ARCHIVE_SHA256SUMS
sha256sum -c SHA256SUMS
sha256sum -c VERIFICATION_SHA256SUMS
# Update the existing extracted package marker without changing its actual
# compile Git identity. The archive retains exactly these verified products.
awk '{print $1}' ARCHIVE_SHA256SUMS > source/.archive-sha256
cp README.md source/README.md
cp "$REPORT" source/REPRODUCTION_REPORT.md
cp "$ROOT/scripts/milestones/step6_time_valid_milestone.md" \
  source/scripts/milestones/step6_time_valid_milestone.md
cp "$ROOT/scripts/milestones/seal_step6_reproduction.sh" \
  source/scripts/milestones/seal_step6_reproduction.sh
cp "$ROOT/scripts/experiments/continue_step6_reproduction_capture.sh" \
  source/scripts/experiments/continue_step6_reproduction_capture.sh
cmp master.sof source/output/DE5a_wr_master_jtag.sof
cmp slave.sof source/output/DE5a_wr_slave_jtag.sof
printf 'STEP6_SEALED=PASS standalone_compile=%s staging=%s\n' \
  "$(cat source/output/SOURCE_COMMIT)" "$STAGE"
