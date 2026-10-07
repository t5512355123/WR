"""Expand the two sealed archives without modifying their existing contents.

No embedded Git repository is created: source/ is tracked by the WR repository.
Existing source folders are verified, never replaced or silently overwritten.
"""
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile
from concurrent.futures import ThreadPoolExecutor


ROOT = Path(__file__).resolve().parents[2]
MILESTONES = ('step6_global_time', 'step7_physical_measurement')


def digest(stream):
    value = hashlib.sha256()
    while chunk := stream.read(1024 * 1024):
        value.update(chunk)
    return value.hexdigest()


def main():
    results = {}
    for name in MILESTONES:
        milestone = ROOT / 'artifacts/milestones' / name
        destination = milestone / 'source'
        if milestone.resolve() != milestone or destination.is_symlink():
            raise SystemExit('Refusing redirected milestone path: ' + str(milestone))
        with tarfile.open(milestone / 'source.tar.gz', 'r:gz') as archive:
            members = archive.getmembers()
            files = {}
            for member in members:
                path = PurePosixPath(member.name)
                if (path.is_absolute() or '..' in path.parts or '.git' in path.parts
                        or '\\' in member.name or not (member.isdir() or member.isfile())):
                    raise SystemExit('Unsafe archive member: ' + member.name)
                target = destination / str(path)
                if target.resolve() != target:
                    raise SystemExit('Refusing a redirected extraction target.')
                if member.isfile():
                    files[str(path)] = digest(archive.extractfile(member))
            if destination.exists():
                present = {str(path.relative_to(destination).as_posix())
                           for path in destination.rglob('*') if path.is_file()}
                if present != set(files):
                    raise SystemExit('Existing source differs; preserve it instead of overwriting.')
            else:
                destination.mkdir()
                archive.extractall(destination, members=members)
            def verify_file(item):
                relative, expected = item
                with (destination / relative).open('rb') as stream:
                    if digest(stream) != expected:
                        raise SystemExit('Extracted source differs: ' + relative)
            # Cloud-backed folders have high per-file latency; bounded concurrent
            # read-only checks preserve the exact byte comparison.
            with ThreadPoolExecutor(max_workers=16) as workers:
                list(workers.map(verify_file, files.items()))
            results[name] = {'files': len(files), 'archive_content_match': 'PASS',
                             'embedded_git_directory': False,
                             'build_compile_program_or_jtag_started': False}
            print('SOURCE_READY=' + name, flush=True)
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
