#!/usr/bin/env bash
# Explicit role CONTROL diagnostic; never invoked by the normal dashboard.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
if [ "$#" -ne 0 ]; then echo 'No options: fixed bounded diagnostic.' >&2; exit 2; fi
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other JTAG reader/programmer first.' >&2; exit 2
fi
cd "$ROOT"
sha256sum -c output/SHA256SUMS
sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
RUN_TAG=$(date -u +%Y%m%dT%H%M%SZ)
BASE="experiments/step6/$CURRENT_EXPERIMENT"
mkdir -p "$BASE/raw/observe"
LOG="$BASE/raw/observe/$RUN_TAG-master-rxts-role-calibration.log"
echo "RXCAL_LOG=$LOG"
set +e
timeout --signal=INT --kill-after=5s 615s "$QUARTUS_STP" -t \
  scripts/jtag/run_step6_master_rxts_role_calibration.tcl > "$LOG" 2>&1
RC=$?
set -e
sha256sum "$LOG" > "$LOG.sha256"
echo "RXCAL_CAPTURE_RC=$RC"
# Failure/timeout is not calibration success; inspect raw restoration evidence.
exit "$RC"
