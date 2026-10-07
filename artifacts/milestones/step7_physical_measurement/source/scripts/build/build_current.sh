#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build/current_experiment.env"
case "${CURRENT_BUILD_POLICY:-pinned}" in pinned|editable) ;; *) echo 'Invalid CURRENT_BUILD_POLICY' >&2; exit 2 ;; esac
# Existing firmware scripts clear their private work dirs; resolve first.
for role in master slave; do
  work="$ROOT/build/firmware/work/$role"
  test "$(realpath -m "$work")" = "$work"
  test ! -L "$work"
done
bash "$ROOT/firmware/scripts/build_master_firmware.sh"
bash "$ROOT/firmware/scripts/build_slave_firmware.sh"
cd "$ROOT"
if [ "${CURRENT_BUILD_POLICY:-pinned}" = pinned ]; then
  printf '%s  %s\n' \
    "$CURRENT_MASTER_MIF_SHA256" build/firmware/master/wrc.mif \
    "$CURRENT_SLAVE_MIF_SHA256" build/firmware/slave/wrc.mif | sha256sum -c -
else
  test -s build/firmware/master/wrc.mif && test -s build/firmware/slave/wrc.mif
  echo 'CURRENT_BUILD_POLICY=editable sha_verification=disabled'
fi
printf 'CURRENT_FIRMWARE_BUILD=PASS experiment=%s\n' "$CURRENT_EXPERIMENT"
