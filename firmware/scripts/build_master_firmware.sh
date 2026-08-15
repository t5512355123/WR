#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
WRPC_SRC="$ROOT/vendor/wrpc-sw"
CONFIG="$ROOT/firmware/configs/de5a_master_defconfig"
OUT="$ROOT/build/firmware/master"
WORK="$ROOT/build/firmware/work/master"
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}

test -d "$WRPC_SRC"
test -f "$CONFIG"
mkdir -p "$OUT"
rm -rf "$WORK"
mkdir -p "$WORK"
cp -a "$WRPC_SRC/." "$WORK/"
cp "$CONFIG" "$WORK/configs/de5a_master_defconfig"

# Windows round-trips preserve source text but may lose executable bits. The
# WRPC makefiles execute these helper scripts during Kconfig generation.
find "$WORK" -type f -name '*.sh' -exec chmod +x {} +

# pain provides a RISC-V 64-bit GNU toolchain whose compiler accepts the
# firmware's RV32IM/ilp32 flags. Provide private RV32 tool aliases only for
# this build workspace; the vendored source is not changed.
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
  echo "=== WRPC MASTER BUILD ==="
  date -Is
  hostname
  git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "GIT_COMMIT=uncommitted"
  sha256sum "$CONFIG"
  make -C "$WORK" de5a_master_defconfig
  make -C "$WORK" -j"$JOBS"
} > "$OUT/build.log" 2>&1

test ! grep -qiE '(^|[[:space:]])error:' "$OUT/build.log"
test -s "$WORK/wrc.elf"
test -s "$WORK/wrc.bin"
test -s "$WORK/wrc.mif"
cp "$WORK/wrc.elf" "$OUT/wrc.elf"
cp "$WORK/wrc.bin" "$OUT/wrc.bin"
cp "$WORK/wrc.mif" "$OUT/wrc.mif"
sha256sum "$OUT/wrc.elf" "$OUT/wrc.bin" "$OUT/wrc.mif" "$CONFIG" > "$OUT/build_hashes.sha256"
echo "WRPC master MIF: $OUT/wrc.mif"
