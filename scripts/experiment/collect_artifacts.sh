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
for role in master slave; do
  for ext in mif elf bin; do
    source_file="$ROOT/build/firmware/$role/wrc.$ext"
    test -f "$source_file" && cp -f "$source_file" "$DEST/${role}.$ext"
  done
done
test -f "$ROOT/quartus/rs422_uart_diag/output_files_master_rs422/DE5a_wr_master_rs422.sof" && \
  cp -f "$ROOT/quartus/rs422_uart_diag/output_files_master_rs422/DE5a_wr_master_rs422.sof" "$DEST/master.sof"
test -f "$ROOT/quartus/rs422_uart_diag/output_files_slave_rs422/DE5a_wr_slave_rs422.sof" && \
  cp -f "$ROOT/quartus/rs422_uart_diag/output_files_slave_rs422/DE5a_wr_slave_rs422.sof" "$DEST/slave.sof"
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
