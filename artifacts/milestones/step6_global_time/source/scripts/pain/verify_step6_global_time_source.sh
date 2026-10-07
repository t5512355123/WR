#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

EXPECTED_COMMIT=${1:-}
MASTER_VHDL="$ROOT/quartus/DE5a_wr_master_jtag.vhd"
SLAVE_VHDL="$ROOT/quartus/DE5a_wr_slave_jtag.vhd"
MASTER_SDC="$ROOT/quartus/DE5a_wr_master_jtag.sdc"
SLAVE_SDC="$ROOT/quartus/DE5a_wr_slave_jtag.sdc"

test -s "$MASTER_VHDL"
test -s "$SLAVE_VHDL"
test -s "$MASTER_SDC"
test -s "$SLAVE_SDC"

COMMIT=$(git -C "$ROOT" rev-parse HEAD)
BRANCH=$(git -C "$ROOT" symbolic-ref --short -q HEAD || printf 'DETACHED')

if [[ -n "$EXPECTED_COMMIT" && "$COMMIT" != "$EXPECTED_COMMIT" ]]; then
    printf 'SOURCE_CHECK=FAIL\n'
    printf 'reason=commit_mismatch\nexpected_commit=%s\nactual_commit=%s\n' \
        "$EXPECTED_COMMIT" "$COMMIT"
    exit 1
fi

# These markers are the minimum source identity of the known-good Step6
# fitted design.  This check is intentionally non-functional: it prevents
# compiling an older detached Step5 worktree that silently lacks the
# Global-Time snapshot and scheduler wiring.
grep -q 'global_time_snapshot_tai' "$MASTER_VHDL"
grep -q 'global_time_snapshot_tai' "$SLAVE_VHDL"
grep -q 'tm_tai_o[[:space:]]*=>[[:space:]]*core_tm_tai' "$MASTER_VHDL"
grep -q 'tm_tai_o[[:space:]]*=>[[:space:]]*core_tm_tai' "$SLAVE_VHDL"
grep -q 'g_pcs_16bit[[:space:]]*=>[[:space:]]*false' "$MASTER_VHDL"
grep -q 'g_pcs_16bit[[:space:]]*=>[[:space:]]*false' "$SLAVE_VHDL"

printf 'SOURCE_CHECK=PASS\n'
printf 'source_root=%s\nbranch=%s\ncommit=%s\n' "$ROOT" "$BRANCH" "$COMMIT"
printf 'global_time_snapshot=present\n'
printf 'tm_tai_and_125mhz_reference=present\n'
