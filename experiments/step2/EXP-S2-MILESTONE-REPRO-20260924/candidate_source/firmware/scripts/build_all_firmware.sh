#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"$SCRIPT_DIR/build_master_firmware.sh"
"$SCRIPT_DIR/build_slave_firmware.sh"
