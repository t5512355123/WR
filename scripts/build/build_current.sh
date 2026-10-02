#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
bash "$ROOT/firmware/scripts/build_master_firmware.sh"
bash "$ROOT/firmware/scripts/build_slave_firmware.sh"
cd "$ROOT"
printf '%s  %s\n' \
  "$CURRENT_MASTER_MIF_SHA256" build/firmware/master/wrc.mif \
  "$CURRENT_SLAVE_MIF_SHA256" build/firmware/slave/wrc.mif | sha256sum -c -
printf 'CURRENT_FIRMWARE_BUILD=PASS experiment=%s\n' "$CURRENT_EXPERIMENT"
