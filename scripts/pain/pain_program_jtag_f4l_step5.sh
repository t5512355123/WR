#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
EXP_ID=${1:?usage: pain_program_jtag_f4l_step5.sh EXP-ID}
EXP_DIR="$ROOT/docs/experiments/exp-step5-softpll-lock/$EXP_ID"
QUARTUS_PGM=${QUARTUS_PGM:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm}
SLAVE_CABLE=${SLAVE_CABLE:-DE5 [1-11.2]}
MASTER_CABLE=${MASTER_CABLE:-DE5 [1-11.1]}
SLAVE_SOF="$ROOT/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
MASTER_SOF="$ROOT/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof"

mkdir -p "$EXP_DIR/raw/program"
test -s "$SLAVE_SOF"
test -s "$MASTER_SOF"

run_logged() {
    local log_file=$1
    shift
    set +e
    "$@" 2>&1 | tee "$log_file"
    local rc=${PIPESTATUS[0]}
    set -e
    return "$rc"
}

run_logged "$EXP_DIR/raw/program/cable-list.log" "$QUARTUS_PGM" -l
run_logged "$EXP_DIR/raw/program/slave-program.log" \
    "$QUARTUS_PGM" -c "$SLAVE_CABLE" -m jtag -o "p;$SLAVE_SOF"
run_logged "$EXP_DIR/raw/program/master-program.log" \
    "$QUARTUS_PGM" -c "$MASTER_CABLE" -m jtag -o "p;$MASTER_SOF"

{
    date -Is
    printf 'slave_cable=%s\n' "$SLAVE_CABLE"
    printf 'master_cable=%s\n' "$MASTER_CABLE"
    sha256sum "$SLAVE_SOF" "$MASTER_SOF"
    printf 'JTAG_F4L_SCHEDULE_OBSERVABILITY_PROGRAM=PASS\n'
} | tee "$EXP_DIR/raw/program/program-manifest.txt"
