#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_OUT=$(mktemp -d)
trap 'rm -f "$TEST_OUT/servo_test"; rmdir "$TEST_OUT"' EXIT
${CC:-cc} -std=gnu99 -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable \
  -fsanitize=undefined -fno-sanitize-recover=all \
  -I "$ROOT/scripts/tests/wrh_strict" \
  "$ROOT/scripts/tests/wrh_strict/servo_test.c" -o "$TEST_OUT/servo_test"
"$TEST_OUT/servo_test"
