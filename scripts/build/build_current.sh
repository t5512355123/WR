#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
bash "$ROOT/firmware/scripts/build_master_firmware.sh"
bash "$ROOT/firmware/scripts/build_slave_firmware.sh"
cd "$ROOT"
printf '%s  %s\n' \
  07511e0a1148dd120898b1fc53f644f265b098d52912340314dace2a8b1526f6 build/firmware/master/wrc.mif \
  d6165e93f0a43bc6b2a41db8d568ab696916c1a32c1733b47d7df36b5a692916 build/firmware/slave/wrc.mif | sha256sum -c -
printf 'CURRENT_FIRMWARE_BUILD=PASS experiment=%s\n' "$CURRENT_EXPERIMENT"
