#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
bash "$ROOT/scripts/build/build_master.sh"
bash "$ROOT/scripts/build/build_slave.sh"
mkdir -p "$ROOT/output"
for role in master slave; do
  cp "$ROOT/quartus/output_files_${role}_jtag/DE5a_wr_${role}_jtag.sof" "$ROOT/output/DE5a_wr_${role}_jtag.sof"
  cp "$ROOT/build/build_info_${role}.txt" "$ROOT/output/build_info_${role}.txt"
done
cd "$ROOT"
sha256sum output/*.sof > output/SHA256SUMS
sha256sum -c output/SHA256SUMS
git rev-parse HEAD > output/SOURCE_COMMIT
printf '%s\n' "$CURRENT_EXPERIMENT" > output/EXPERIMENT
echo 'CURRENT_COMPILE=PASS retained_sofs=output/'
