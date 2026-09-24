#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
QUARTUS_SH=${QUARTUS_SH:-quartus_sh}

bash "$ROOT/firmware/scripts/build_slave_firmware.sh"
(
  cd "$ROOT/quartus"
  "$QUARTUS_SH" --flow compile DE5a_wr_slave_jtag
)

SOF="$ROOT/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
test -s "$SOF"
sha256sum "$SOF"
