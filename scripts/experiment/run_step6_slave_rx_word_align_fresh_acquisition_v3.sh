#!/usr/bin/env bash
# Run the V3 corrected-observer repeat after the Master TX precondition has passed.
# This script programs only the exact Slave SOF and starts the read-only observer
# immediately after programming.  It deliberately performs no compile or reset.
set -eu

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
EXP_ID=${1:?usage: run_step6_slave_rx_word_align_fresh_acquisition_v3.sh EXP-ID}
EXP_DIR="$ROOT/docs/experiments/exp-step6-global-time/$EXP_ID"
QUARTUS_PGM=${QUARTUS_PGM:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm}
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
SLAVE_CABLE=${SLAVE_CABLE:-DE5 [1-11.2]}
SLAVE_SOF="$ROOT/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
EXPECTED_SOF_SHA256=7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e

mkdir -p "$EXP_DIR/raw/program" "$EXP_DIR/raw/word-align"
test -s "$SLAVE_SOF"

actual_sof_sha256=$(sha256sum "$SLAVE_SOF")
actual_sof_sha256=${actual_sof_sha256%% *}
{
    printf 'EXPERIMENT=%s\n' "$EXP_ID"
    printf 'SOURCE_COMMIT=%s\n' "$(git -C "$ROOT" rev-parse HEAD)"
    printf 'SLAVE_CABLE=%s\n' "$SLAVE_CABLE"
    printf 'EXPECTED_SOF_SHA256=%s\n' "$EXPECTED_SOF_SHA256"
    printf 'ACTUAL_SOF_SHA256=%s\n' "$actual_sof_sha256"
    printf 'FULL_COMPILE=0\nMASTER_PROGRAM=0\nPOWER_CYCLE=0\n'
} > "$EXP_DIR/raw/program/metadata.txt"
test "$actual_sof_sha256" = "$EXPECTED_SOF_SHA256"
sha256sum "$SLAVE_SOF" > "$EXP_DIR/raw/program/sof-sha256.txt"

program_start_epoch_ms=$(date +%s%3N)
printf 'SLAVE_PROGRAM_START_EPOCH_MS=%s\nSLAVE_PROGRAM_START=%s\n' \
    "$program_start_epoch_ms" "$(date -Is)" > "$EXP_DIR/raw/program/sequence-times.log"
set +e
"$QUARTUS_PGM" -c "$SLAVE_CABLE" -m jtag -o "p;$SLAVE_SOF" \
    > "$EXP_DIR/raw/program/slave-program.log" 2>&1
program_rc=$?
set -e
program_done_epoch_ms=$(date +%s%3N)
printf 'SLAVE_PROGRAM_RC=%s\nSLAVE_PROGRAM_DONE_EPOCH_MS=%s\nSLAVE_PROGRAM_DONE=%s\n' \
    "$program_rc" "$program_done_epoch_ms" "$(date -Is)" \
    >> "$EXP_DIR/raw/program/sequence-times.log"
test "$program_rc" -eq 0
grep -q 'Successfully performed operation(s)' "$EXP_DIR/raw/program/slave-program.log"

# No sleep or second command is inserted between programmer completion and the
# observer launch.  The observer establishes the local-ready clock itself.
observer_start_epoch_ms=$(date +%s%3N)
printf 'OBSERVER_PROCESS_START_EPOCH_MS=%s\nOBSERVER_PROCESS_START=%s\n' \
    "$observer_start_epoch_ms" "$(date -Is)" \
    >> "$EXP_DIR/raw/program/sequence-times.log"
set +e
"$QUARTUS_STP" -t "$ROOT/scripts/jtag/read_step6_slave_rx_word_align_fresh_acquisition.tcl" \
    "$EXP_ID" 1-11.2 200 100 word-align 10000 \
    > "$EXP_DIR/raw/word-align/slave-word-align.log" 2>&1
observer_rc=$?
set -e
observer_done_epoch_ms=$(date +%s%3N)

first_elapsed_ms=$(sed -n 's/.*WORDALIGN_SAMPLE.*TIMESTAMP_MS=\([0-9][0-9]*\).*/\1/p' \
    "$EXP_DIR/raw/word-align/slave-word-align.log" | head -n 1)
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

exit "$observer_rc"
