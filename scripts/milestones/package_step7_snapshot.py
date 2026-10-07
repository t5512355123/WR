"""Package committed Step7 source/products without touching other milestones.

Publication metadata is generated mechanically. No hardware actions are run.
"""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / 'artifacts/milestones/step7_physical_measurement'
OBSERVATION = 'experiments/step7/EXP-S7-PHYSICAL-PPS-SMA-OBSERVATION-20261007'
RECOVERY = 'experiments/step7/EXP-S7-SLAVE-BOOTSTRAP512-OPERATING-POINT-20261005'
PATHS = ['firmware', 'vendor', 'quartus', 'quartus_generated', 'scripts',
         'build', 'output', 'README.md', 'STATUS.md', 'MILESTONES.md',
         '.gitignore', '.gitattributes', OBSERVATION, RECOVERY]
HELPERS = ['README.md', 'prepare_source.sh', 'seal_read_only.sh']
EXPECTED_SOFS = {
    'master': '0fd28157e3652dfaa56e5c14f57c66bc4bd2d4d6ae1a6a74576617e76c5319dd',
    'slave': '3565f6b18929341613616e7b03a6aac10a53da0e5953444611ca74e8e3d1e32d',
}


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    if git('branch', '--show-current').decode().strip() != 'step7-physical-measurement':
        raise SystemExit('Must package the requested Step7 branch.')
    if git('status', '--porcelain', '--', *PATHS, str(PACKAGE.relative_to(ROOT))):
        raise SystemExit('Commit the selected snapshot paths before packaging.')
    for name in HELPERS:
        if not (PACKAGE / name).is_file():
            raise SystemExit('Missing package helper: ' + name)
    generated = ['source.tar.gz', 'master.sof', 'slave.sof', 'master-slave-pulse.png',
                 'VERIFICATION.md', 'PACKAGE.json', 'SHA256SUMS']
    if any((PACKAGE / name).exists() for name in generated):
        raise SystemExit('Existing package will not be overwritten.')
    commit = git('rev-parse', 'HEAD').decode().strip()
    compile_commit = (ROOT / 'output/SOURCE_COMMIT').read_text().strip()
    for role, expected in EXPECTED_SOFS.items():
        if digest(ROOT / f'output/DE5a_wr_{role}_jtag.sof') != expected:
            raise SystemExit('Retained SOF does not match recorded build: ' + role)
    with tempfile.TemporaryDirectory(prefix='wr-step7-package-') as temporary:
        original = Path(temporary) / 'committed.tar'
        subprocess.run(['git', '-C', str(ROOT), 'archive', '--format=tar',
                        '--output=' + str(original), commit, '--', *PATHS], check=True)
        with tarfile.open(original, 'r:') as source, tarfile.open(PACKAGE / 'source.tar.gz', 'w:gz') as target:
            for member in source:
                path = PurePosixPath(member.name)
                if path.is_absolute() or '..' in path.parts or not (member.isdir() or member.isfile()):
                    raise SystemExit('Unexpected archive member: ' + member.name)
                data = source.extractfile(member) if member.isfile() else None
                if member.name == 'output/PUBLISHED_SHA256SUMS':
                    lines = data.read().splitlines()
                    # Standalone compile/export must not depend on sibling milestones.
                    filtered = [line for line in lines
                                if line.split(maxsplit=1)[1].startswith((b'build/', b'output/'))]
                    payload = b'\n'.join(filtered) + b'\n'
                    member.size = len(payload)
                    data = io.BytesIO(payload)
                target.addfile(member, data)
            identity = (commit + '\n').encode()
            member = tarfile.TarInfo('SNAPSHOT_SOURCE_COMMIT')
            member.size = len(identity)
            member.mode = 0o644
            target.addfile(member, io.BytesIO(identity))
    for role in EXPECTED_SOFS:
        shutil.copyfile(ROOT / f'output/DE5a_wr_{role}_jtag.sof', PACKAGE / f'{role}.sof')
    shutil.copyfile(ROOT / OBSERVATION / 'raw/observe/master-slave-pulse.png', PACKAGE / 'master-slave-pulse.png')
    shutil.copyfile(ROOT / OBSERVATION / 'REPORT.md', PACKAGE / 'VERIFICATION.md')
    metadata = {
        'schema_version': 1, 'documented_date': '2026-10-07',
        'branch': 'step7-physical-measurement', 'snapshot_commit': commit,
        'retained_compile_source_commit': compile_commit,
        'physical_validation': 'STAGEWISE_NS_ALIGNMENT_OBSERVED',
        'picosecond_accuracy': 'NOT_ESTABLISHED',
        'screenshot_loaded_image_identity': 'NOT_INDEPENDENTLY_VERIFIED',
        'fresh_hardware_reproduction': 'NOT_RUN', 'new_time_valid_300s': 'NOT_RUN',
        'included_paths': PATHS,
        'standalone_manifest_change': 'Only build/output publication entries retained; production bytes unchanged.',
        'files': {name: {'bytes': (PACKAGE / name).stat().st_size, 'sha256': digest(PACKAGE / name)}
                  for name in HELPERS + generated if (PACKAGE / name).is_file()},
    }
    (PACKAGE / 'PACKAGE.json').write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    files = sorted(name for name in HELPERS + generated if name != 'SHA256SUMS')
    for name in files:
        if (PACKAGE / name).stat().st_size >= 100_000_000:
            raise SystemExit('Package file exceeds GitHub regular-file limit: ' + name)
    (PACKAGE / 'SHA256SUMS').write_text(''.join(f'{digest(PACKAGE / name)}  {name}\n' for name in files), encoding='ascii')
    print(json.dumps({'packaged': str(PACKAGE), 'snapshot_commit': commit,
                      'archive_bytes': (PACKAGE / 'source.tar.gz').stat().st_size}, indent=2))


if __name__ == '__main__':
    main()
