#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
cd "$ROOT"
case "${CURRENT_BUILD_POLICY:-pinned}" in
  pinned)
    sha256sum -c output/SHA256SUMS
    sha256sum -c output/SOURCE_SHA256SUMS > /dev/null
    for role in master slave; do
      actual=$(sha256sum "build/firmware/$role/wrc.mif" | awk '{print $1}')
      grep -Fx "MIF_SHA256=$actual" "output/build_info_$role.txt" > /dev/null
    done ;;
  editable)
    test -s output/DE5a_wr_master_jtag.sof
    test -s output/DE5a_wr_slave_jtag.sof
    echo 'CURRENT_BUILD_POLICY=editable sha_verification=disabled' ;;
  *) echo 'Invalid CURRENT_BUILD_POLICY' >&2; exit 2 ;;
esac
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other JTAG reader/programmer first.' >&2
  exit 2
fi
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
LOG_DIR="$ROOT/experiments/step6/$CURRENT_EXPERIMENT/raw/program"
mkdir -p "$LOG_DIR"
SOF="$ROOT/output/DE5a_wr_slave_jtag.sof" bash scripts/program/program_slave.sh 2>&1 | tee "$LOG_DIR/$RUN_TAG-current-slave.log"
SOF="$ROOT/output/DE5a_wr_master_jtag.sof" bash scripts/program/program_master.sh 2>&1 | tee "$LOG_DIR/$RUN_TAG-current-master.log"
grep -q 'Programmer was successful' "$LOG_DIR/$RUN_TAG-current-slave.log"
grep -q 'Programmer was successful' "$LOG_DIR/$RUN_TAG-current-master.log"
echo 'CURRENT_PROGRAM=PASS order=slave,master'
