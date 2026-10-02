#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
bash "$ROOT/scripts/build/build_master.sh"
bash "$ROOT/scripts/build/build_slave.sh"
bash "$ROOT/scripts/build/export_current_outputs.sh"
echo 'CURRENT_COMPILE=PASS retained_sofs=output/'
