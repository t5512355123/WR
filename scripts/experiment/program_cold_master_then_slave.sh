#!/usr/bin/env bash
# Invoke only after the user confirms both boards were physically power-cycled.
# This runner preserves the exact frozen-fit images and records each operation.
set -euo pipefail
if [[ $# -ne 2 || $1 != --cold-cycle-confirmed ]]; then
  printf 'Usage: %s --cold-cycle-confirmed NEW_OUTPUT_DIRECTORY\n' "$0" >&2
  exit 2
fi
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$script_dir/../.." && pwd)
raw=$2
stage="$repo/artifacts/exp-step5-frozen-fit-20260902/staging-88604a5-maintrace-run-20260902/quartus/jtag_runtime_diag"
master="$stage/output_files_master_jtag/DE5a_wr_master_jtag.sof"
slave="$stage/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
pgm=/mnt/ds1515/opt/intelFPGA_pro/21.3/quartus/bin/quartus_pgm
[[ -x $pgm && -f $master && -f $slave ]]
[[ $(sha256sum "$master" | cut -d ' ' -f1) == 23bfdc100fa2b61aff3096754ebd99d61c1e1c1728be99cd5515204415c7dd0d ]]
[[ $(sha256sum "$slave" | cut -d ' ' -f1) == 04c7cb7ecca19be16eb9de022891a9c0143b2c6b62ce364d80db4e56508217fc ]]
sudo -n -v
mkdir "$raw"
{
  printf 'EXPERIMENT=EXP-WRPC-COLD-BOOT-PROGRAM-ORDER-MASTER-THEN-SLAVE-UPSTREAM-RECOVERY-20260904\n'
  printf 'COLD_POWER_CYCLE=CONFIRMED_BY_USER\n'
  printf 'RECORDED_AT=%s\n' "$(date -Is)"
  printf 'OBSERVER_COMMIT=%s\n' "$(git -C "$repo" rev-parse HEAD)"
  printf 'PROGRAM_ORDER=MASTER_THEN_SLAVE\n'
  printf 'INTER_PROGRAM_GAP_SECONDS=46\n'
  printf 'SLAVE_HELPER_KP=-300\n'
} > "$raw/metadata.txt"
sha256sum "$master" "$slave" > "$raw/sof-sha256.txt"
date -Is >> "$raw/program-timeline.log"
sudo -n "$pgm" -c 'DE5 [1-11.1]' -m jtag -o "p;$master" > "$raw/program-master.log" 2>&1
grep -q 'Successfully performed operation(s)' "$raw/program-master.log"
printf 'MASTER_PROGRAM_SUCCESS=%s\n' "$(date -Is)" >> "$raw/program-timeline.log"
# Prior run: first configuration ended 11:01:45; second started 11:02:31.
sleep 46
sudo -n "$pgm" -c 'DE5 [1-11.2]' -m jtag -o "p;$slave" > "$raw/program-slave.log" 2>&1
grep -q 'Successfully performed operation(s)' "$raw/program-slave.log"
printf 'SLAVE_PROGRAM_SUCCESS=%s\n' "$(date -Is)" >> "$raw/program-timeline.log"
printf 'PROGRAMMING_COMPLETE raw=%s\n' "$raw"
