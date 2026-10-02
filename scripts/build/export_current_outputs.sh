#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
mkdir -p "$ROOT/output"
for role in master slave; do
  sof="$ROOT/quartus/output_files_${role}_jtag/DE5a_wr_${role}_jtag.sof"
  actual=$(sha256sum "$sof" | awk '{print $1}')
  grep -Fx "SOF_SHA256=$actual" "$ROOT/build/build_info_${role}.txt" > /dev/null
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
sha256sum -c output/SHA256SUMS
# Preserve actual compile identities, not the metadata-only export commit.
sed -n 's/^GIT_COMMIT=//p' build/build_info_master.txt > output/SOURCE_COMMIT
printf '%s\n' "$CURRENT_EXPERIMENT" > output/EXPERIMENT
echo 'CURRENT_OUTPUT_EXPORT=PASS retained_sofs=output/'
