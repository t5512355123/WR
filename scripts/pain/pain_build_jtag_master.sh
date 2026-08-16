#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
"$ROOT/firmware/scripts/build_master_firmware.sh"
"$ROOT/scripts/build/build_jtag_master.sh"
