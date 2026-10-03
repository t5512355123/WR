#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_OUT=$(mktemp -d)
trap 'rm -f "$TEST_OUT/test" "$TEST_OUT/ptracker"; rmdir "$TEST_OUT"' EXIT
for test in test ptracker; do
  ${CC:-cc} -std=gnu99 -Wall -Wextra -Werror -fsanitize=undefined -fno-sanitize-recover=all \
    -I "$ROOT/vendor/wrpc-sw/include" \
    -I "$ROOT/vendor/wrpc-sw/ppsi/pp_printf" \
    "$ROOT/scripts/tests/phase_history/$test.c" -o "$TEST_OUT/$test"
  "$TEST_OUT/$test"
done
