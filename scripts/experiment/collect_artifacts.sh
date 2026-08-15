#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ID=${1:?usage: collect_artifacts.sh EXP-ID}
DEST="$ROOT/artifacts/$ID"
mkdir -p "$DEST"
cp -f "$ROOT"/build/build_info_*.txt "$DEST/" 2>/dev/null || true
cp -f "$ROOT"/build/build_*.log "$DEST/" 2>/dev/null || true
cp -f "$ROOT"/build/quartus_*_compile.log "$DEST/" 2>/dev/null || true
for f in "$ROOT"/build/firmware/*.mif "$ROOT"/build/firmware/*.elf "$ROOT"/build/firmware/*.bin; do
  test -f "$f" && cp -f "$f" "$DEST/"
done
find "$ROOT/quartus/rs422_uart_diag" -maxdepth 3 -type f \( -name '*.sof' -o -name '*.rpt' -o -name '*.summary' \) -exec cp -f {} "$DEST/" \; 2>/dev/null || true
{
  echo "experiment=$ID"
  echo "date=$(date -Is)"
  echo "host=$(hostname)"
  echo "git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo uncommitted)"
  echo "quartus_bin=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}"
  sha256sum "$DEST"/* 2>/dev/null || true
} > "$DEST/metadata_collected.txt"
echo "Collected artifacts in $DEST"
