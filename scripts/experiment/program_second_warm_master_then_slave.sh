#!/usr/bin/env bash
# Run once from the preserved failed first post-cold configuration.
# Do not power-cycle, rebuild, change MIFs, or manipulate cables first.
set -euo pipefail
if [[ $# -ne 2 || $1 != --preserved-cold-failed-state ]]; then
  printf 'Usage: %s --preserved-cold-failed-state NEW_OUTPUT_DIRECTORY\n' "$0" >&2
  exit 2
fi
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$script_dir/../.." && pwd)
raw=$2
stage="$repo/artifacts/exp-step5-frozen-fit-20260902/staging-88604a5-maintrace-run-20260902/quartus/jtag_runtime_diag"
master="$stage/output_files_master_jtag/DE5a_wr_master_jtag.sof"
slave="$stage/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
pgm=/mnt/ds1515/opt/intelFPGA_pro/21.3/quartus/bin/quartus_pgm
stp=/mnt/ds1515/opt/intelFPGA_pro/21.3/quartus/bin/quartus_stp
[[ -x $pgm && -x $stp && -f $master && -f $slave ]]
[[ $(sha256sum "$master" | cut -d ' ' -f1) == 23bfdc100fa2b61aff3096754ebd99d61c1e1c1728be99cd5515204415c7dd0d ]]
[[ $(sha256sum "$slave" | cut -d ' ' -f1) == 04c7cb7ecca19be16eb9de022891a9c0143b2c6b62ce364d80db4e56508217fc ]]
sudo -n -v
mkdir "$raw"
{
  printf 'EXPERIMENT=EXP-WRPC-COLD-FAILED-STATE-SECOND-WARM-REPROGRAM-UPSTREAM-RECOVERY-20260905\n'
  printf 'RECORDED_AT=%s\n' "$(date -Is)"
  printf 'OBSERVER_COMMIT=%s\n' "$(git -C "$repo" rev-parse HEAD)"
  printf 'FIRST_CONFIGURATION_EVIDENCE_COMMIT=be4839ce7991e8e0085c0434c28bff76013236f9\n'
  printf 'CONFIGURATION_GENERATION=SECOND_WARM_AFTER_FIRST_COLD_FAILED\n'
  printf 'POWER_CYCLE_BETWEEN_CONFIGURATIONS=NO_AGENT_ACTION\n'
  printf 'PROGRAM_ORDER=MASTER_THEN_SLAVE\n'
  printf 'INTER_PROGRAM_GAP_SECONDS=46\n'
  printf 'INITIAL_SETTLE_SECONDS=24\n'
  printf 'INTER_PREFLIGHT_SETTLE_SECONDS=30\n'
  printf 'SLAVE_HELPER_KP=-300\n'
  printf 'HELPER_600S=NOT_RUN_BY_DESIGN\n'
} > "$raw/metadata.txt"
sha256sum "$master" "$slave" > "$raw/sof-sha256.txt"
date -Is >> "$raw/program-timeline.log"
sudo -n "$pgm" -c 'DE5 [1-11.1]' -m jtag -o "p;$master" > "$raw/program-master.log" 2>&1
grep -q 'Successfully performed operation(s)' "$raw/program-master.log"
printf 'MASTER_PROGRAM_SUCCESS=%s\n' "$(date -Is)" >> "$raw/program-timeline.log"
sleep 46
sudo -n "$pgm" -c 'DE5 [1-11.2]' -m jtag -o "p;$slave" > "$raw/program-slave.log" 2>&1
grep -q 'Successfully performed operation(s)' "$raw/program-slave.log"
printf 'SLAVE_PROGRAM_SUCCESS=%s\n' "$(date -Is)" >> "$raw/program-timeline.log"
printf 'PROGRAMMING_COMPLETE raw=%s\n' "$raw"
sleep 24
for preflight in 1 2 3 4 5; do
  sudo -n "$stp" -t "$repo/scripts/jtag/read_wb_runtime.tcl" --raw > "$raw/preflight-$preflight.log" 2>&1
  grep -q 'Quartus Prime Signal Tap was successful' "$raw/preflight-$preflight.log"
  printf 'PREFLIGHT_%s_COMPLETE=%s\n' "$preflight" "$(date -Is)"
  if [[ $preflight -lt 5 ]]; then sleep 30; fi
done
