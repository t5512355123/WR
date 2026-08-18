#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ID=${1:?usage: create_experiment.sh EXP-ID}
case "$ID" in
  EXP-*) ;;
  *) echo "experiment id must start with EXP-" >&2; exit 2 ;;
esac

# 實驗紀錄依目前 Git branch 分流，避免不同研究線互相混在一起。
BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || true)
case "$BRANCH" in
  main) EXP_DIR="main" ;;
  exp/*) EXP_DIR="exp-${BRANCH#exp/}" ;;
  "") EXP_DIR="detached" ;;
  *) EXP_DIR="branch-$BRANCH" ;;
esac
EXP_DIR=${EXP_DIR//\//-}
DEST_DIR="$ROOT/docs/experiments/$EXP_DIR"
mkdir -p "$DEST_DIR"
DEST="$DEST_DIR/$ID.md"
test ! -e "$DEST" || { echo "already exists: $DEST" >&2; exit 3; }
sed "s/EXP-XXX/$ID/g" "$ROOT/docs/experiments/EXP-XXX_TEMPLATE.md" > "$DEST"
echo "Created $DEST"
