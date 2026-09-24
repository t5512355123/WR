#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
STEP=${1:?usage: create_experiment.sh stepN EXP-ID}
ID=${2:?usage: create_experiment.sh stepN EXP-ID}
case "$STEP" in
  step[1-7]|repository-cleanup) ;;
  *) echo "step must be step1..step7 or repository-cleanup" >&2; exit 2 ;;
esac
case "$ID" in
  EXP-*) ;;
  *) echo "experiment id must start with EXP-" >&2; exit 2 ;;
esac

DEST_DIR="$ROOT/experiments/$STEP"
mkdir -p "$DEST_DIR"
DEST="$DEST_DIR/$ID"
test ! -e "$DEST" || { echo "already exists: $DEST" >&2; exit 3; }
mkdir -p "$DEST/raw/build" "$DEST/raw/program" "$DEST/raw/observe" "$DEST/analysis"
sed "s/EXP-XXX/$ID/g" "$ROOT/experiments/PLAN_TEMPLATE.md" > "$DEST/PLAN.md"
sed "s/EXP-XXX/$ID/g" "$ROOT/experiments/REPORT_TEMPLATE.md" > "$DEST/REPORT.md"
: > "$DEST/SHA256SUMS"
echo "Created $DEST"
