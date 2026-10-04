#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_OUT=$(mktemp -d)
trap 'rm -f "$TEST_OUT/servo_test"; rmdir "$TEST_OUT"' EXIT
${CC:-cc} -std=gnu99 -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable \
  -fsanitize=undefined -fno-sanitize-recover=all \
  -I "$ROOT/scripts/tests/wrh_strict" \
  "$ROOT/scripts/tests/wrh_strict/no_phase_correction_test.c" -o "$TEST_OUT/servo_test"
"$TEST_OUT/servo_test"
# The preserved reference branch still has exactly its original arithmetic.
bash "$ROOT/scripts/tests/run_wrh_time_valid_baseline_c.sh"
