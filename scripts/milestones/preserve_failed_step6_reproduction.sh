#!/usr/bin/env bash
# Keep unqualified fresh products OUTSIDE the canonical qualified package.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MILESTONE="$ROOT/artifacts/milestones/step6_global_time"
SOURCE="$MILESTONE/source"
OUTER="$ROOT/experiments/step6/EXP-S6-MILESTONE-MAIN-ROOT-TIME-VALID-300S-REPRO-20261003"
test "$(realpath "$SOURCE")" = "$SOURCE"
test ! -L "$MILESTONE" && test ! -L "$SOURCE"
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Another JTAG owner is running.' >&2; exit 2
fi
grep -Fx 'TIME_VALID acquisition timeout; evidence saved.' "$OUTER/raw/standalone-cycle.log" >/dev/null
grep -Fx 'TIME_VALID acquisition timeout; evidence saved.' "$OUTER/raw/standalone-continuation.log" >/dev/null
cd "$SOURCE"
source scripts/build/current_experiment.env
test "$CURRENT_EXPERIMENT" = EXP-S6-MAIN-ROOT-TIME-VALID-300S-BACKTRACK-20261003
test ! -f "experiments/step6/$CURRENT_EXPERIMENT/raw/cycles/20261003T160449Z-cycle1/qualified-result.json"
sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
sha256sum -c output/SHA256SUMS
DIAG="$OUTER/raw/configuration-comparison"
cmp "$DIAG/root_master.rbf" "$DIAG/rebuilt_master.rbf"
cmp "$DIAG/root_slave.rbf" "$DIAG/rebuilt_slave.rbf"
sha256sum "$DIAG"/*.rbf > "$DIAG/SHA256SUMS"
mkdir -p "$OUTER/raw/independent-rebuild" "$OUTER/raw/rebuilt-products"
cp -a "experiments/step6/$CURRENT_EXPERIMENT/raw/cycles/20261003T160449Z-cycle1" \
  "$OUTER/raw/independent-rebuild/cycle"
cp -a "experiments/step6/$CURRENT_EXPERIMENT/raw/build/20261003T162103Z-current.t5fT47" \
  "$OUTER/raw/independent-rebuild/build"
mkdir "$OUTER/raw/independent-rebuild/observe" "$OUTER/raw/independent-rebuild/program"
find "experiments/step6/$CURRENT_EXPERIMENT/raw/observe" -maxdepth 1 -type f \
  -name '20261003T16*' -exec cp -t "$OUTER/raw/independent-rebuild/observe" {} +
find "experiments/step6/$CURRENT_EXPERIMENT/raw/program" -maxdepth 1 -type f \
  -name '20261003T162103Z-*' -exec cp -t "$OUTER/raw/independent-rebuild/program" {} +
while IFS= read -r -d '' path; do
  cp --parents "$path" "$OUTER/raw/rebuilt-products/"
done < <(git ls-files -z build output)

BACKUP_BASE=/home/b10504072/04_WR_step6_package_backups
BACKUP="$BACKUP_BASE/$(date -u +%Y%m%dT%H%M%SZ)-unqualified-rebuild"
test "$(realpath -m "$BACKUP")" = "$BACKUP"
case "$BACKUP" in "$BACKUP_BASE"/*) ;; *) exit 2 ;; esac
test ! -e "$BACKUP"
mkdir -p "$BACKUP"
cd "$ROOT"
mv -- "$SOURCE" "$BACKUP/source"
# The archive and alias SOFs are still the qualified main-root pair. Verify
# them and extract that exact archived state, not the failed new products.
bash "$MILESTONE/prepare_source.sh"
cd "$MILESTONE/source"
cmp output/DE5a_wr_master_jtag.sof ../master.sof
cmp output/DE5a_wr_slave_jtag.sof ../slave.sof
python3 -m unittest scripts.tests.test_current_experiment_source scripts.tests.test_step6_time_valid_300s
printf 'UNQUALIFIED_REBUILD_BACKUP=%s\nCANONICAL_PACKAGE=QUALIFIED_ROOT_ONLY\nSTANDALONE_REPRODUCTION=NOT_ESTABLISHED\n' "$BACKUP"
