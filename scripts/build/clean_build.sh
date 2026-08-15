#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
rm -rf "$ROOT/build/firmware/work" "$ROOT/build/firmware/master" "$ROOT/build/firmware/slave"
rm -f "$ROOT/build/quartus_master_compile.log" "$ROOT/build/quartus_slave_compile.log" "$ROOT/build/build_master.log" "$ROOT/build/build_slave.log" "$ROOT/build/build_info_master.txt" "$ROOT/build/build_info_slave.txt"
rm -rf "$ROOT/quartus/rs422_uart_diag/output_files_master_rs422" "$ROOT/quartus/rs422_uart_diag/output_files_slave_rs422"
echo "Rebuildable staging outputs removed; source and artifacts were not touched."
