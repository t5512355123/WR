#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
QUARTUS_SH=${QUARTUS_SH:-quartus_sh}

bash "$ROOT/firmware/scripts/build_master_firmware.sh"
(
  cd "$ROOT/quartus"
  "$QUARTUS_SH" --clean DE5a_wr_master_jtag.qpf
  "$QUARTUS_SH" --flow compile DE5a_wr_master_jtag.qpf
)

SOF="$ROOT/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof"
test -s "$SOF"
sha256sum "$SOF"
