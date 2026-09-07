#!/usr/bin/env bash
# Run after laptop commit/push and pain pull. Never edit sources on pain.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
run="$repo/artifacts/EXP-WRPC-DCO-PAGE-ISOLATION-20260907"
mkdir "$run"
commit=$(git -C "$repo" rev-parse HEAD)
printf 'SOURCE_COMMIT=%s\nSTARTED=%s\n' "$commit" "$(date -Is)" > "$run/identity.txt"
git -C "$repo" worktree add --detach "$run/source" "$commit"
stage="$run/source"
mkdir -p "$stage/build"
export IVERILOG_ROOT="$repo/build/tools/iverilog-package/runtime"
bash "$stage/scripts/experiment/run_dco_page_contract.sh" +fixed > "$run/simulation.log" 2>&1
grep -q 'PAGE_CONTRACT_TEST=PASS expected_fixed=1' "$run/simulation.log"
# These existing builders only clean their new, isolated worktree outputs.
export JOBS=8
bash "$stage/firmware/scripts/build_master_firmware.sh" > "$run/firmware-master.log" 2>&1
bash "$stage/firmware/scripts/build_slave_firmware.sh" > "$run/firmware-slave.log" 2>&1
bash "$stage/scripts/build/build_jtag_master.sh" > "$run/compile-master.log" 2>&1
bash "$stage/scripts/build/build_jtag_slave.sh" > "$run/compile-slave.log" 2>&1
cp "$stage/build/build_info_jtag_master.txt" "$stage/build/build_info_jtag_slave.txt" "$run/"
sha256sum "$stage/quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof" \
  "$stage/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof" > "$run/sof-sha256.txt"
printf 'BUILD_COMPLETED=%s\n' "$(date -Is)" >> "$run/identity.txt"
printf 'BUILD_SUCCESS run=%s\n' "$run"
# Programming is deliberately separate: inspect simulation/build/timing first.
