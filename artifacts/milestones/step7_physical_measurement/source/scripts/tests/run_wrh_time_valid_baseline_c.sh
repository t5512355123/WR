#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_OUT=$(mktemp -d)
trap 'rm -f "$TEST_OUT/servo_test"; rmdir "$TEST_OUT"' EXIT
${CC:-cc} -std=gnu99 -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable \
  -fsanitize=undefined -fno-sanitize-recover=all \
  -DWRH_PHASE_CORRECTION_ENABLED=1 -I "$ROOT/scripts/tests/wrh_strict" \
  "$ROOT/scripts/tests/wrh_strict/time_valid_baseline_test.c" -o "$TEST_OUT/servo_test"
"$TEST_OUT/servo_test"
