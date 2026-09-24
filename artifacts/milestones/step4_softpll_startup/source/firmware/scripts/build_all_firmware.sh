#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bash "$SCRIPT_DIR/build_master_firmware.sh"
bash "$SCRIPT_DIR/build_slave_firmware.sh"
