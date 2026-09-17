#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
EXP_ID=${1:?usage: pain_build_portb_step5.sh EXP-ID}
EXP_DIR="$ROOT/docs/experiments/exp-step5-softpll-lock/$EXP_ID"
QUARTUS_SH=${QUARTUS_SH:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh}

mkdir -p "$EXP_DIR/raw/build"

run_logged() {
    local log_file=$1
    shift
    set +e
    "$@" 2>&1 | tee "$log_file"
    local rc=${PIPESTATUS[0]}
    set -e
    return "$rc"
}

run_logged "$EXP_DIR/raw/build/firmware-slave-build.log" \
    "$ROOT/firmware/scripts/build_slave_firmware.sh"
run_logged "$EXP_DIR/raw/build/firmware-master-build.log" \
    "$ROOT/firmware/scripts/build_master_firmware.sh"

{
    date -Is
    printf 'git_commit='
    git -C "$ROOT" rev-parse HEAD
    printf '%s\n' '--- identity/config/MIF hashes ---'
    sha256sum \
        "$ROOT/firmware/configs/de5a_slave_defconfig" \
        "$ROOT/firmware/configs/de5a_slave_identity.h" \
        "$ROOT/build/firmware/slave/wrc.mif" \
        "$ROOT/firmware/configs/de5a_master_defconfig" \
        "$ROOT/firmware/configs/de5a_master_identity.h" \
        "$ROOT/build/firmware/master/wrc.mif"
    printf '%s\n' '--- F4L compile-time identity markers ---'
    grep -En 'DE5A_F4L_MAIN_PHASE_DIAG|DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD|DE5A_MAIN_PI_KP_OVERRIDE' \
        "$ROOT/firmware/configs/de5a_slave_identity.h" \
        "$ROOT/firmware/configs/de5a_master_identity.h"
} | tee "$EXP_DIR/raw/build/firmware-image-manifest.txt"

pushd "$ROOT/quartus/jtag_runtime_diag_portb" >/dev/null
run_logged "$EXP_DIR/raw/build/quartus_slave_portb_compile.log" \
    "$QUARTUS_SH" --flow compile DE5a_wr_slave_portb
run_logged "$EXP_DIR/raw/build/quartus_master_portb_compile.log" \
    "$QUARTUS_SH" --flow compile DE5a_wr_master_portb

{
    date -Is
    printf 'git_commit='
    git -C "$ROOT" rev-parse HEAD
    printf '%s\n' '--- SOF SHA256 ---'
    sha256sum output_files_slave_portb/*.sof output_files_master_portb/*.sof
    printf '%s\n' '--- sizes ---'
    stat -c '%n %s bytes %y' output_files_slave_portb/*.sof output_files_master_portb/*.sof
} | tee "$EXP_DIR/raw/build/sof-manifest.txt"
popd >/dev/null

printf 'PORTB_STEP5_BUILD=PASS\n'
