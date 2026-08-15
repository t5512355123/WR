#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ID=${1:?usage: create_experiment.sh EXP-ID}
case "$ID" in
  EXP-*) ;;
  *) echo "experiment id must start with EXP-" >&2; exit 2 ;;
esac
DEST="$ROOT/docs/experiments/$ID.md"
test ! -e "$DEST" || { echo "already exists: $DEST" >&2; exit 3; }
sed "s/EXP-XXX/$ID/g" "$ROOT/docs/experiments/EXP-XXX_TEMPLATE.md" > "$DEST"
echo "Created $DEST"
