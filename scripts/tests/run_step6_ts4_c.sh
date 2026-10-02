#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_OUT=$(mktemp -d)
trap 'rm -f "$TEST_OUT/test"; rmdir "$TEST_OUT"' EXIT
${CC:-cc} -std=gnu99 -Wall -Wextra -Werror -Wno-unused-parameter \
  -fsanitize=undefined -fno-sanitize-recover=all \
  -I "$ROOT/scripts/tests/ts4" "$ROOT/scripts/tests/ts4/test.c" -o "$TEST_OUT/test"
"$TEST_OUT/test"
