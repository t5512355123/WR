#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
bash "$ROOT/firmware/scripts/build_master_firmware.sh"
bash "$ROOT/firmware/scripts/build_slave_firmware.sh"
cd "$ROOT"
printf '%s  %s\n' \
  18a51d784d08acfdc3bc6f24cff768661ea3918d234c6b19a2d360614a0da3ea build/firmware/master/wrc.mif \
  91c5d7f9629a8a5d2a05116f12efd9515326ad25ee897a85ab97c71fc242c379 build/firmware/slave/wrc.mif | sha256sum -c -
printf 'CURRENT_FIRMWARE_BUILD=PASS experiment=%s\n' "$CURRENT_EXPERIMENT"
