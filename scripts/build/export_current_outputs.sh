#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
COMPILED_COMMIT=$(sed -n 's/^GIT_COMMIT=//p' "$ROOT/build/build_info_master.txt")
case "${CURRENT_BUILD_POLICY:-pinned}" in pinned|editable) ;; *) echo 'Invalid CURRENT_BUILD_POLICY' >&2; exit 2 ;; esac
# Export may be repeated after documentation changes, but never after changing
# any firmware, HDL, generated-IP or Quartus input used by the compiler.
if [ "${CURRENT_BUILD_POLICY:-pinned}" = pinned ]; then
  git -C "$ROOT" cat-file -e "$COMPILED_COMMIT^{commit}"
  grep -Fx "GIT_COMMIT=$COMPILED_COMMIT" "$ROOT/build/build_info_slave.txt" > /dev/null
  git -C "$ROOT" diff --quiet "$COMPILED_COMMIT" -- firmware vendor quartus quartus_generated || {
    echo 'Compile inputs changed; rebuild both boards before exporting.' >&2; exit 2;
  }
else
  echo 'CURRENT_EXPORT_POLICY=editable local_edits_allowed=1 sha_verification=disabled'
fi
mkdir -p "$ROOT/output"
for role in master slave; do
  sof="$ROOT/quartus/output_files_${role}_jtag/DE5a_wr_${role}_jtag.sof"
  test -s "$sof"
  if [ "${CURRENT_BUILD_POLICY:-pinned}" = pinned ]; then
    actual=$(sha256sum "$sof" | awk '{print $1}')
    grep -Fx "SOF_SHA256=$actual" "$ROOT/build/build_info_${role}.txt" > /dev/null
  fi
  grep -Fx 'COMPILE_RESULT=Full Compilation was successful' "$ROOT/build/build_info_${role}.txt" > /dev/null
  cp "$sof" "$ROOT/output/DE5a_wr_${role}_jtag.sof"
  cp "$ROOT/build/build_info_${role}.txt" "$ROOT/output/build_info_${role}.txt"
  mkdir -p "$ROOT/output/$role"
  find "$ROOT/quartus/output_files_${role}_jtag" -maxdepth 1 -type f ! -name '*.sof' \
    -exec cp -t "$ROOT/output/$role" {} +
done
cd "$ROOT"
sha256sum output/*.sof > output/SHA256SUMS
git ls-files -z firmware vendor quartus quartus_generated | xargs -0 sha256sum > output/SOURCE_SHA256SUMS
if [ "${CURRENT_BUILD_POLICY:-pinned}" = pinned ]; then sha256sum -c output/SHA256SUMS; fi
# Preserve actual compile identities, not the metadata-only export commit.
sed -n 's/^GIT_COMMIT=//p' build/build_info_master.txt > output/SOURCE_COMMIT
printf '%s\n' "$CURRENT_EXPERIMENT" > output/EXPERIMENT
# Refresh the established publication list after every real build. This reads
# the frozen milestone SOFs but never edits them. Do not publish stale checksum
# entries for newly compiled root products.
test -s output/PUBLISHED_SHA256SUMS
PUBLISHED_TMP=$(mktemp "$ROOT/output/.published-sha.XXXXXX")
trap 'rm -f "$PUBLISHED_TMP"' EXIT
while read -r old_hash published_path; do
  case "$published_path" in
    output/PUBLISHED_SHA256SUMS) echo 'Self-referential publication manifest' >&2; exit 2 ;;
    build/*|output/*|artifacts/milestones/*/*.sof) ;;
    *) echo "Unexpected publication target: $published_path" >&2; exit 2 ;;
  esac
  test -f "$published_path"
  sha256sum -- "$published_path"
done < output/PUBLISHED_SHA256SUMS > "$PUBLISHED_TMP"
mv "$PUBLISHED_TMP" output/PUBLISHED_SHA256SUMS
if [ "${CURRENT_BUILD_POLICY:-pinned}" = pinned ]; then sha256sum -c output/PUBLISHED_SHA256SUMS >/dev/null; fi
# Record uncommitted production edits without rejecting a legitimate fresh build.
git diff --binary -- firmware vendor quartus quartus_generated > output/LOCAL_SOURCE_CHANGES.patch
git status --porcelain -- firmware vendor quartus quartus_generated > output/LOCAL_SOURCE_STATUS.txt
RECORD_BASE="$ROOT/experiments/step6/$CURRENT_EXPERIMENT/raw/build"
mkdir -p "$RECORD_BASE"
RECORD=$(mktemp -d "$RECORD_BASE/$(date -u +%Y%m%dT%H%M%SZ)-current.XXXXXX")
for role in master slave; do
  cp "$ROOT/build/build_info_${role}.txt" "$RECORD/$role-build-info.txt"
  cp "$ROOT/build/quartus_${role}_compile.log" "$RECORD/$role-compile.log"
  cp "$ROOT/build/firmware/$role/build.log" "$RECORD/$role-firmware.log"
  cp "$ROOT/build/firmware/$role/build_hashes.sha256" "$RECORD/$role-firmware.sha256"
done
cp "$ROOT/output/SHA256SUMS" "$RECORD/sof.sha256"
cp "$ROOT/output/SOURCE_COMMIT" "$RECORD/source-commit.txt"
printf 'CURRENT_BUILD_RECORD=%s\n' "$RECORD"
echo 'CURRENT_OUTPUT_EXPORT=PASS retained_sofs=output/'
