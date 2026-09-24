#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
EXP_ID=${1:?usage: pain_build_jtag_f4l_step5.sh EXP-ID}
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
    printf 'git_branch='
    git -C "$ROOT" branch --show-current
    printf '%s\n' '--- identity/config/MIF hashes ---'
    sha256sum \
        "$ROOT/firmware/configs/de5a_slave_defconfig" \
        "$ROOT/firmware/configs/de5a_slave_identity.h" \
        "$ROOT/build/firmware/slave/wrc.mif" \
        "$ROOT/firmware/configs/de5a_master_defconfig" \
        "$ROOT/firmware/configs/de5a_master_identity.h" \
        "$ROOT/build/firmware/master/wrc.mif"
    printf '%s\n' '--- F4L source/observer hashes ---'
    sha256sum \
        "$ROOT/vendor/wrpc-sw/softpll/spll_main.c" \
        "$ROOT/vendor/wrpc-sw/softpll/spll_main_f4l_diag.h" \
        "$ROOT/vendor/wrpc-sw/dev/wdiags.c" \
        "$ROOT/vendor/wrpc-sw/include/dev/wdiags.h" \
        "$ROOT/vendor/wrpc-sw/include/hw/wrc_diags_regs.h" \
        "$ROOT/vendor/wrpc-sw/lib/task-diags.c" \
        "$ROOT/scripts/jtag/read_step5_main_frequency_prelock_observability.tcl" \
        "$ROOT/scripts/experiment/step5_f4s_producer_schedule.py"
    printf '%s\n' '--- F4L compile-time identity markers ---'
    grep -En 'DE5A_F4L_MAIN_PHASE_DIAG|DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD|DE5A_MAIN_PI_KP_OVERRIDE' \
        "$ROOT/firmware/configs/de5a_slave_identity.h" \
        "$ROOT/firmware/configs/de5a_master_identity.h"
    printf '%s\n' '--- observer contract markers ---'
    grep -En 'EXP-S5-F4L-PRODUCER-SCHEDULE-OBSERVABILITY-20260917|set no_valid_timeout_ms 10000|set smoke_duration 10000|0x46345331|no_control_write=1|no_rtl_or_sdb_change=1' \
        "$ROOT/scripts/jtag/read_step5_main_frequency_prelock_observability.tcl"
} | tee "$EXP_DIR/raw/build/firmware-image-manifest.txt"

pushd "$ROOT/quartus" >/dev/null
run_logged "$EXP_DIR/raw/build/quartus_slave_jtag_compile.log" \
    "$QUARTUS_SH" --flow compile DE5a_wr_slave_jtag
run_logged "$EXP_DIR/raw/build/quartus_master_jtag_compile.log" \
    "$QUARTUS_SH" --flow compile DE5a_wr_master_jtag

{
    date -Is
    printf 'git_commit='
    git -C "$ROOT" rev-parse HEAD
    printf '%s\n' '--- JTAG SOF SHA256 ---'
    sha256sum output_files_slave_jtag/DE5a_wr_slave_jtag.sof \
        output_files_master_jtag/DE5a_wr_master_jtag.sof
    printf '%s\n' '--- JTAG SOF sizes ---'
    stat -c '%n %s bytes %y' output_files_slave_jtag/DE5a_wr_slave_jtag.sof \
        output_files_master_jtag/DE5a_wr_master_jtag.sof
    printf '%s\n' '--- timing summary ---'
    grep -H -m1 -E 'Fitter Status|Worst-case setup slack is|Worst-case hold slack is|Worst-case recovery slack is|Worst-case removal slack is' \
        output_files_slave_jtag/DE5a_wr_slave_jtag.fit.summary \
        output_files_slave_jtag/DE5a_wr_slave_jtag.sta.rpt \
        output_files_master_jtag/DE5a_wr_master_jtag.fit.summary \
        output_files_master_jtag/DE5a_wr_master_jtag.sta.rpt || true
} | tee "$EXP_DIR/raw/build/sof-manifest.txt"
popd >/dev/null

printf 'JTAG_F4L_STEP5_BUILD=PASS\n'
