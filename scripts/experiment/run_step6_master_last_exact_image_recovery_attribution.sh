#!/usr/bin/env bash
# Run EXP-S6-MASTER-LAST-EXACT-IMAGE-RECOVERY-ATTRIBUTION-20260921.
#
# The exact ec1f25e8 Master artifact is verified and programmed exactly once.
# No compilation, Slave programming, reset, power cycle, or control write is
# performed by this runner.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
EXP_ID=${1:?usage: run_step6_master_last_exact_image_recovery_attribution.sh EXP-ID}
EXP_DIR="$ROOT/docs/experiments/exp-step6-global-time/$EXP_ID"
QUARTUS_PGM=${QUARTUS_PGM:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm}
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
PYTHON=${PYTHON:-python3}
MASTER_CABLE=${MASTER_CABLE:-DE5 [1-11.1]}
MASTER_SOF=${MASTER_SOF:-$ROOT/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof}
EXPECTED_MASTER_SOF_SHA256=568f08c974064bdd3e82f68e3f1ecb0ff6c8a2a8e5705bdcc15b5941d33173a3

mkdir -p "$EXP_DIR/raw/preflight" "$EXP_DIR/raw/program" \
  "$EXP_DIR/raw/recovery" "$EXP_DIR/analysis"

test -s "$MASTER_SOF"
actual_sof_sha256=$(sha256sum "$MASTER_SOF")
actual_sof_sha256=${actual_sof_sha256%% *}
{
  printf 'EXPERIMENT=%s\n' "$EXP_ID"
  printf 'SOURCE_COMMIT=%s\n' "$(git -C "$ROOT" rev-parse HEAD)"
  printf 'MASTER_CABLE=%s\n' "$MASTER_CABLE"
  printf 'MASTER_SOF=%s\n' "$MASTER_SOF"
  printf 'EXPECTED_MASTER_SOF_SHA256=%s\n' "$EXPECTED_MASTER_SOF_SHA256"
  printf 'ACTUAL_MASTER_SOF_SHA256=%s\n' "$actual_sof_sha256"
  printf 'MASTER_FULL_COMPILE=0\nSLAVE_FULL_COMPILE=0\nFIRMWARE_BUILD=0\n'
  printf 'MASTER_PROGRAM_COUNT=1\nSLAVE_PROGRAM_COUNT=0\nPOWER_CYCLE=0\n'
} > "$EXP_DIR/raw/program/metadata.txt"

if [[ "$actual_sof_sha256" != "$EXPECTED_MASTER_SOF_SHA256" ]]; then
  printf 'RUNNER_STOP=MASTER_SOF_SHA256_MISMATCH\n' > "$EXP_DIR/raw/program/stop.txt"
  exit 2
fi
sha256sum "$MASTER_SOF" > "$EXP_DIR/raw/program/master-sof-sha256.txt"

# Five paired read-only preflight samples.  Programming is forbidden until
# the adviser-defined basic health gate passes.
set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_master_last_exact_image_recovery_attribution.tcl" \
  "$EXP_ID" preflight 5 250 \
  > "$EXP_DIR/raw/preflight/preflight.log" 2>&1
preflight_rc=$?
set -e
if [[ "$preflight_rc" -ne 0 ]] || ! grep -q '^PREFLIGHT_RESULT=PASS$' \
  "$EXP_DIR/raw/preflight/preflight.log"; then
  printf 'PREFLIGHT_RC=%s\nRUNNER_STOP=PREFLIGHT_GATE_NOT_PASS\n' "$preflight_rc" \
    > "$EXP_DIR/raw/preflight/stop.txt"
  exit 3
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
printf 'MASTER_PROGRAM_RC=%s\nMASTER_PROGRAM_DONE_EPOCH_MS=%s\nMASTER_PROGRAM_DONE=%s\n' \
  "$program_rc" "$program_done_epoch_ms" "$(date -Is)" \
  >> "$EXP_DIR/raw/program/sequence-times.log"
if [[ "$program_rc" -ne 0 ]] || ! grep -q 'Successfully performed operation(s)' \
  "$EXP_DIR/raw/program/master-program.log"; then
  printf 'PROGRAM_RC=%s\nRUNNER_STOP=MASTER_PROGRAM_FAILURE\n' "$program_rc" \
    > "$EXP_DIR/raw/program/stop.txt"
  exit 4
fi

# Launch the paired observer immediately; no sleep or second programming is
# inserted between quartus_pgm completion and quartus_stp startup.
observer_start_epoch_ms=$(date +%s%3N)
printf 'OBSERVER_PROCESS_START_EPOCH_MS=%s\nOBSERVER_PROCESS_START=%s\n' \
  "$observer_start_epoch_ms" "$(date -Is)" \
  >> "$EXP_DIR/raw/program/sequence-times.log"
set +e
"$QUARTUS_STP" -t \
  "$ROOT/scripts/jtag/read_step6_master_last_exact_image_recovery_attribution.tcl" \
  "$EXP_ID" recovery 480 250 120000 \
  > "$EXP_DIR/raw/recovery/recovery.log" 2>&1
observer_rc=$?
set -e
observer_done_epoch_ms=$(date +%s%3N)

first_elapsed_ms=$(sed -n \
  's/.*RECOVERY_PAIR_SAMPLE.*READ_VALID=1.*ELAPSED_MS=\([0-9][0-9]*\).*/\1/p' \
  "$EXP_DIR/raw/recovery/recovery.log" | head -n 1)
if [[ -z "$first_elapsed_ms" ]]; then
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

if ! grep -q '^RECOVERY_RESULT=' "$EXP_DIR/raw/recovery/recovery.log"; then
  printf 'RUNNER_STOP=RECOVERY_RESULT_MISSING\n' > "$EXP_DIR/raw/recovery/stop.txt"
  exit 5
fi

if command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" "$ROOT/scripts/analysis/step6_master_last_exact_image_recovery_attribution.py" \
    "$EXP_DIR/raw/preflight/preflight.log" \
    "$EXP_DIR/raw/recovery/recovery.log" \
    --json-out "$EXP_DIR/analysis/summary.json" \
    > "$EXP_DIR/analysis/analyzer.txt"
else
  printf 'ANALYZER=NOT_RUN\n' > "$EXP_DIR/analysis/analyzer.txt"
fi

exit "$observer_rc"
