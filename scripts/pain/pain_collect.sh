#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ID=${1:?usage: pain_collect.sh EXP-ID}
DEST="$ROOT/artifacts/$ID"
mkdir -p "$DEST"
for f in "$ROOT"/build/build_info_*.txt "$ROOT"/build/build_*_compile.log "$ROOT"/build/build_*.log; do
  test -f "$f" && cp -f "$f" "$DEST/"
done
find "$ROOT/quartus/rs422_uart_diag" -maxdepth 3 -type f \( -name '*.sof' -o -name '*.rpt' -o -name '*.summary' \) -exec cp -f {} "$DEST/" \; 2>/dev/null || true
find "$ROOT/build/firmware" -type f \( -name '*.mif' -o -name '*.elf' -o -name '*.bin' -o -name '*sha256*' \) -exec cp -f {} "$DEST/" \; 2>/dev/null || true
{
  echo "experiment=$ID"
  date -Is
  echo "host=$(hostname)"
  echo "git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo uncommitted)"
  echo "git_status_count=$(git -C "$ROOT" status --porcelain | wc -l)"
  sha256sum "$DEST"/* 2>/dev/null || true
} > "$DEST/collected_sha256.txt"
echo "Collected evidence in $DEST"
