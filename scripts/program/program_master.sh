#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
CABLE=${CABLE:-DE5 [1-11.1]}
SOF=${SOF:-$ROOT/quartus/rs422_uart_diag/output_files_master_rs422/DE5a_wr_master_rs422.sof}
test -f "$SOF"
sudo "$QUARTUS_BIN/quartus_pgm" -c "$CABLE" -m jtag -o "p;$SOF"
