#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
WRPC_SRC="$ROOT/vendor/wrpc-sw"
CONFIG="$ROOT/firmware/configs/de5a_slave_defconfig"
IDENTITY="$ROOT/firmware/configs/de5a_slave_identity.h"
OUT="$ROOT/build/firmware/slave"
WORK="$ROOT/build/firmware/work/slave"
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}

test -d "$WRPC_SRC"
test -f "$CONFIG"
test -f "$IDENTITY"
mkdir -p "$OUT"
rm -rf "$WORK"
mkdir -p "$WORK"
cp -a "$WRPC_SRC/." "$WORK/"
cp "$CONFIG" "$WORK/configs/de5a_slave_defconfig"
cp "$IDENTITY" "$WORK/boards/generic/de5a-identity.h"

# Keep the build independent of executable-bit loss during source transfer.
find "$WORK" -type f -name '*.sh' -exec chmod +x {} +

# Use pain's compatible RV64 GNU tools through private RV32 command aliases.
TOOLBIN="$WORK/.toolchain"
mkdir -p "$TOOLBIN"
for tool in gcc g++ as ld objcopy objdump ar ranlib strip nm size; do
  if ! command -v "riscv32-elf-$tool" >/dev/null 2>&1; then
    candidate=$(command -v "riscv64-unknown-elf-$tool" 2>/dev/null || true)
    test -n "$candidate" && ln -sf "$candidate" "$TOOLBIN/riscv32-elf-$tool"
  fi
done
export PATH="$TOOLBIN:$PATH"

{
  echo "=== WRPC SLAVE BUILD ==="
  date -Is
  hostname
  git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "GIT_COMMIT=uncommitted"
  sha256sum "$CONFIG" "$IDENTITY"
  make -C "$WORK" de5a_slave_defconfig
  make -C "$WORK" -j"$JOBS"
} > "$OUT/build.log" 2>&1

! grep -qiE '(^|[[:space:]])error:' "$OUT/build.log"
test -s "$WORK/wrc.elf"
test -s "$WORK/wrc.bin"
test -s "$WORK/wrc.mif"
cp "$WORK/wrc.elf" "$OUT/wrc.elf"
cp "$WORK/wrc.bin" "$OUT/wrc.bin"
cp "$WORK/wrc.mif" "$OUT/wrc.mif"
sha256sum "$OUT/wrc.elf" "$OUT/wrc.bin" "$OUT/wrc.mif" "$CONFIG" "$IDENTITY" > "$OUT/build_hashes.sha256"
echo "WRPC slave MIF: $OUT/wrc.mif"
