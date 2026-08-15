#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
"$ROOT/firmware/scripts/build_slave_firmware.sh"
"$ROOT/scripts/build/build_slave.sh"
