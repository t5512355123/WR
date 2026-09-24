#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
QUARTUS_PGM=${QUARTUS_PGM:-quartus_pgm}
CABLE=${JTAG_CABLE:-DE5 [1-11.1]}
SOF="$ROOT/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof"

test -s "$SOF"
"$QUARTUS_PGM" -c "$CABLE" -m jtag -o "p;$SOF"
