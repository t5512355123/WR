#!/usr/bin/env bash
# Run EXP-S6-MASTER-LAST-EC1F25E8-REBUILD-RECOVERY-ATTRIBUTION-20260921.
# Build only the Master in a clean ec1f25e8 worktree, program it once, and
# leave the current Slave completely untouched.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
if [ "$#" -lt 1 ]; then
  echo "usage: run_step6_master_last_ec1f25e8_rebuild_recovery.sh EXP-ID" >&2
  exit 2
fi
EXP_ID="$1"
SOURCE_COMMIT=ec1f25e81e0eb8c2caee796d13a225eaae81e5f2
EXP_DIR="$ROOT/experiments/step6/$EXP_ID"
QUARTUS_PGM=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm
QUARTUS_STP=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
PYTHON=python3
MASTER_CABLE='DE5 [1-11.1]'
BUILD_ROOT="/tmp/wr-step6-rebuild-$EXP_ID-$(date +%s)"
SOURCE_TREE="$BUILD_ROOT/source"
BUILD_MANIFEST="$EXP_DIR/raw/build/build-manifest.txt"
BASELINE_LOG="$EXP_DIR/raw/baseline/baseline.log"
RECOVERY_LOG="$EXP_DIR/raw/recovery/recovery.log"

mkdir -p "$EXP_DIR/raw/build" "$EXP_DIR/raw/baseline" \
  "$EXP_DIR/raw/program" "$EXP_DIR/raw/recovery" "$EXP_DIR/analysis"

write_stop() {
  local result="$1"
  local reason="$2"
  printf 'RESULT=%s\nSTOP_REASON=%s\nMASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\n' \
    "$result" "$reason" > "$EXP_DIR/raw/program/stop.txt"
}

if [ -e "$SOURCE_TREE" ]; then
  write_stop NOT_RUN_BUILD_PREREQUISITE_FAIL BUILD_TREE_ALREADY_EXISTS
  exit 2
fi
mkdir -p "$BUILD_ROOT"

if ! git -C "$ROOT" worktree add --detach "$SOURCE_TREE" "$SOURCE_COMMIT" \
    > "$EXP_DIR/raw/build/worktree.log" 2>&1; then
  write_stop NOT_RUN_BUILD_PREREQUISITE_FAIL CLEAN_EC1F25E8_WORKTREE_CREATE_FAILED
  exit 2
fi

source_head=$(git -C "$SOURCE_TREE" rev-parse HEAD 2>/dev/null || true)
source_dirty=$(git -C "$SOURCE_TREE" status --porcelain 2>/dev/null || true)
if [ "$source_head" != "$SOURCE_COMMIT" ] || [ -n "$source_dirty" ]; then
  write_stop NOT_RUN_BUILD_PREREQUISITE_FAIL WRONG_OR_DIRTY_SOURCE_TREE
  exit 2
fi

MASTER_PROJECT_DIR="$SOURCE_TREE/quartus/jtag_runtime_diag"
# This nested project path is correct for SOURCE_COMMIT (before the current
# repository flattening). The detached worktree is intentional; do not rewrite
# this path to the current root-level quartus/ layout.
MASTER_SOF="$MASTER_PROJECT_DIR/output_files_master_jtag/DE5a_wr_master_jtag.sof"
MASTER_MIF="$SOURCE_TREE/build/firmware/master/wrc.mif"
{
  printf 'SOURCE_COMMIT=%s\n' "$source_head"
  printf 'SOURCE_STATUS_CLEAN=1\n'
  printf 'MASTER_VHDL_SHA256='
  sha256sum "$MASTER_PROJECT_DIR/DE5a_wr_master_jtag.vhd" | awk '{print $1}'
  printf 'MASTER_QSF_SHA256='
  sha256sum "$MASTER_PROJECT_DIR/DE5a_wr_master_jtag.qsf" | awk '{print $1}'
  printf 'MASTER_SDC_SHA256='
  sha256sum "$MASTER_PROJECT_DIR/DE5a_wr_master_jtag.sdc" | awk '{print $1}'
  printf 'SOURCE_CONFIG_SHA256='
  sha256sum "$SOURCE_TREE/firmware/configs/de5a_master_defconfig" | awk '{print $1}'
  printf 'SOURCE_IDENTITY_SHA256='
  sha256sum "$SOURCE_TREE/firmware/configs/de5a_master_identity.h" | awk '{print $1}'
} > "$BUILD_MANIFEST"

set +e
"$SOURCE_TREE/firmware/scripts/build_master_firmware.sh" \
  > "$EXP_DIR/raw/build/firmware-master-build.log" 2>&1
firmware_rc=$?
set -e
if [ "$firmware_rc" -ne 0 ] || [ ! -s "$MASTER_MIF" ]; then
  write_stop NOT_RUN_BUILD_PREREQUISITE_FAIL MASTER_FIRMWARE_BUILD_FAILED
  exit 3
fi
printf 'MASTER_MIF_SHA256=' >> "$BUILD_MANIFEST"
sha256sum "$MASTER_MIF" | awk '{print $1}' >> "$BUILD_MANIFEST"

set +e
"$SOURCE_TREE/scripts/build/build_jtag_master.sh" \
  > "$EXP_DIR/raw/build/quartus-master-compile.log" 2>&1
quartus_rc=$?
set -e
QUARTUS_FULL_LOG="$SOURCE_TREE/build/quartus_jtag_master_compile.log"
if [ -s "$QUARTUS_FULL_LOG" ]; then
  cp "$QUARTUS_FULL_LOG" "$EXP_DIR/raw/build/quartus-master-compile.log"
fi
if [ "$quartus_rc" -ne 0 ] || [ ! -s "$MASTER_SOF" ] || \
   [ ! -s "$MASTER_PROJECT_DIR/output_files_master_jtag/DE5a_wr_master_jtag.fit.summary" ] || \
   [ ! -s "$MASTER_PROJECT_DIR/output_files_master_jtag/DE5a_wr_master_jtag.sta.rpt" ]; then
  write_stop NOT_RUN_BUILD_PREREQUISITE_FAIL MASTER_FULL_COMPILE_FAILED
  exit 3
fi
if ! grep -q 'Full Compilation was successful' \
    "$EXP_DIR/raw/build/quartus-master-compile.log"; then
  write_stop NOT_RUN_BUILD_PREREQUISITE_FAIL MASTER_FULL_COMPILE_MARKER_MISSING
  exit 3
fi

sof_sha256=$(sha256sum "$MASTER_SOF" | awk '{print $1}')
quartus_checksum=$(grep -m1 -E 'Checksum|checksum' \
  "$EXP_DIR/raw/build/quartus-master-compile.log" | head -1 || true)
{
  printf 'MASTER_SOF_SHA256=%s\n' "$sof_sha256"
  if [ "$sof_sha256" = "568f08c974064bdd3e82f68e3f1ecb0ff6c8a2a8e5705bdcc15b5941d33173a3" ]; then
    echo 'REBUILD_MATCHES_ORIGINAL_EXACT=YES'
  else
    echo 'REBUILD_MATCHES_ORIGINAL_EXACT=NO'
  fi
  printf 'QUARTUS_CHECKSUM_LINE=%s\n' "$quartus_checksum"
  if [ -f "$SOURCE_TREE/build/build_info_jtag_master.txt" ]; then
    cat "$SOURCE_TREE/build/build_info_jtag_master.txt"
  fi
} >> "$BUILD_MANIFEST"
sha256sum "$MASTER_SOF" > "$EXP_DIR/raw/build/master-sof-sha256.txt"
printf 'EXPERIMENT=%s\nSOURCE_COMMIT=%s\nSOURCE_TREE=%s\nMASTER_SOF_SHA256=%s\nMASTER_FULL_COMPILE=1\nSLAVE_FULL_COMPILE=0\nFIRMWARE_BUILD_MASTER=1\nMASTER_PROGRAM_COUNT=0\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\n' \
  "$EXP_ID" "$source_head" "$SOURCE_TREE" "$sof_sha256" > "$EXP_DIR/raw/program/metadata.txt"

set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_master_last_ec1f25e8_rebuild_recovery.tcl" \
  "$EXP_ID" baseline 5 250 > "$BASELINE_LOG" 2>&1
baseline_rc=$?
set -e
if [ "$baseline_rc" -ne 0 ] || ! grep -q '^BASELINE_RESULT=PASS$' "$BASELINE_LOG"; then
  write_stop INCONCLUSIVE_PREPROGRAM_SLAVE_HEALTH BASELINE_GATE_NOT_PASS
  exit 4
fi

program_start_epoch_ms=$(date +%s%3N)
printf 'MASTER_PROGRAM_START_EPOCH_MS=%s\nMASTER_PROGRAM_START=%s\n' \
  "$program_start_epoch_ms" "$(date -Is)" \
  > "$EXP_DIR/raw/program/sequence-times.log"
set +e
"$QUARTUS_PGM" -c "$MASTER_CABLE" -m jtag -o "p;$MASTER_SOF" \
  > "$EXP_DIR/raw/program/master-program.log" 2>&1
program_rc=$?
set -e
program_done_epoch_ms=$(date +%s%3N)
sed -i 's/^MASTER_PROGRAM_COUNT=0$/MASTER_PROGRAM_COUNT=1/' \
  "$EXP_DIR/raw/program/metadata.txt"
printf 'MASTER_PROGRAM_RC=%s\nMASTER_PROGRAM_DONE_EPOCH_MS=%s\nMASTER_PROGRAM_DONE=%s\n' \
  "$program_rc" "$program_done_epoch_ms" "$(date -Is)" \
  >> "$EXP_DIR/raw/program/sequence-times.log"
if [ "$program_rc" -ne 0 ] || \
   ! grep -q 'Successfully performed operation(s)' \
     "$EXP_DIR/raw/program/master-program.log"; then
  printf 'RESULT=INCONCLUSIVE_MASTER_PROGRAM_FAIL\nSTOP_REASON=MASTER_PROGRAM_FAILURE\nMASTER_PROGRAM_COUNT=1\nSLAVE_PROGRAM_COUNT=0\n' \
    > "$EXP_DIR/raw/program/stop.txt"
  exit 5
fi

observer_start_epoch_ms=$(date +%s%3N)
printf 'OBSERVER_PROCESS_START_EPOCH_MS=%s\nOBSERVER_PROCESS_START=%s\n' \
  "$observer_start_epoch_ms" "$(date -Is)" \
  >> "$EXP_DIR/raw/program/sequence-times.log"
set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_master_last_ec1f25e8_rebuild_recovery.tcl" \
  "$EXP_ID" recovery 480 250 120000 "$BASELINE_LOG" \
  > "$RECOVERY_LOG" 2>&1
observer_rc=$?
set -e
observer_done_epoch_ms=$(date +%s%3N)

first_elapsed_ms=$(sed -n \
  's/.*REBUILD_RECOVERY_PAIR.*READ_VALID=1.*ELAPSED_MS=\([0-9][0-9]*\).*/\1/p' \
  "$RECOVERY_LOG" | head -n 1)
if [ -z "$first_elapsed_ms" ]; then
  first_elapsed_ms=-1
  first_valid_epoch_ms=-1
  program_to_first_valid_ms=-1
else
  first_valid_epoch_ms=$((observer_start_epoch_ms + first_elapsed_ms))
  program_to_first_valid_ms=$((first_valid_epoch_ms - program_done_epoch_ms))
fi
program_to_observer_start_ms=$((observer_start_epoch_ms - program_done_epoch_ms))
printf 'OBSERVER_RC=%s\nOBSERVER_DONE_EPOCH_MS=%s\nOBSERVER_DONE=%s\n' \
  "$observer_rc" "$observer_done_epoch_ms" "$(date -Is)" \
  >> "$EXP_DIR/raw/program/sequence-times.log"
printf 'FIRST_VALID_SAMPLE_ELAPSED_MS=%s\nFIRST_VALID_SAMPLE_EPOCH_MS=%s\n' \
  "$first_elapsed_ms" "$first_valid_epoch_ms" \
  >> "$EXP_DIR/raw/program/sequence-times.log"
printf 'PROGRAM_DONE_TO_OBSERVER_START_MS=%s\nPROGRAM_DONE_TO_FIRST_VALID_SAMPLE_MS=%s\n' \
  "$program_to_observer_start_ms" "$program_to_first_valid_ms" \
  >> "$EXP_DIR/raw/program/sequence-times.log"

if ! grep -q '^REBUILD_RECOVERY_RESULT=' "$RECOVERY_LOG"; then
  printf 'RESULT=INCONCLUSIVE\nSTOP_REASON=RECOVERY_RESULT_MISSING\nMASTER_PROGRAM_COUNT=1\nSLAVE_PROGRAM_COUNT=0\n' \
    > "$EXP_DIR/raw/program/stop.txt"
  exit 6
fi

if command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" "$ROOT/scripts/analysis/step6_master_last_ec1f25e8_rebuild_recovery.py" \
    "$BASELINE_LOG" "$RECOVERY_LOG" \
    --build-manifest "$BUILD_MANIFEST" \
    --sequence "$EXP_DIR/raw/program/sequence-times.log" \
    --json-out "$EXP_DIR/analysis/summary.json" \
    > "$EXP_DIR/analysis/analyzer.txt"
fi

exit "$observer_rc"
