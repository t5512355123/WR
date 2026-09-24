#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
QUARTUS_PGM=${QUARTUS_PGM:-quartus_pgm}
CABLE=${JTAG_CABLE:-DE5 [1-11.2]}
SOF="$ROOT/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"

test -s "$SOF"
"$QUARTUS_PGM" -c "$CABLE" -m jtag -o "p;$SOF"
