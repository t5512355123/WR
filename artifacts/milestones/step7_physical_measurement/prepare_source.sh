#!/usr/bin/env bash
# Extract into a new external worktree; never write inside the sealed package.
set -euo pipefail
MILESTONE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
test "${#}" -eq 1 || { echo 'Usage: prepare_source.sh /absolute/new/work-directory' >&2; exit 2; }
python3 - "$MILESTONE" "$1" <<'PY'
import pathlib
import sys
import tarfile

milestone = pathlib.Path(sys.argv[1]).resolve()
requested = pathlib.Path(sys.argv[2])
if not requested.is_absolute():
    raise SystemExit('Destination must be absolute.')
if requested.exists() or requested.is_symlink():
    raise SystemExit('Destination must not exist; nothing will be overwritten.')
destination = requested.resolve()
if destination == milestone or milestone in destination.parents:
    raise SystemExit('Destination must be outside the read-only milestone.')
if not destination.parent.is_dir():
    raise SystemExit('Destination parent must already exist.')
with tarfile.open(milestone / 'source.tar.gz', 'r:gz') as archive:
    members = archive.getmembers()
    for member in members:
        path = pathlib.PurePosixPath(member.name)
        if path.is_absolute() or '..' in path.parts or '\\' in member.name:
            raise SystemExit('Unsafe archive member: ' + member.name)
        if not (member.isfile() or member.isdir()):
            raise SystemExit('Links/devices are not allowed: ' + member.name)
        target = (destination / member.name).resolve()
        if target != destination and destination not in target.parents:
            raise SystemExit('Archive member escapes destination.')
    destination.mkdir()
    archive.extractall(destination, members=members)
print('STEP7_SOURCE_EXTRACTED=' + str(destination))
PY
DESTINATION=$(cd "$1" && pwd -P)
# Existing editable build scripts use Git to record their newly compiled inputs.
git -C "$DESTINATION" init -q
git -C "$DESTINATION" add -f .
git -C "$DESTINATION" -c user.name='WR milestone snapshot' \
  -c user.email='snapshot@localhost' commit -q -m 'Step7 standalone snapshot (not a new hardware PASS)'
printf 'STEP7_WORK_DIRECTORY=%s\n' "$DESTINATION"
echo 'No build, programming or JTAG observation was started.'
