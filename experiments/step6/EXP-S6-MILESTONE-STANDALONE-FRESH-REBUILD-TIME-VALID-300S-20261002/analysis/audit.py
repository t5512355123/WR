"""Offline audit of the single fresh milestone run, not a main-root cycle."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
EXP = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    'common', ROOT / 'scripts/analysis/step6_reproduction_pair.py')
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit():
    record = EXP / 'raw/cycle'
    rebuilt = EXP / 'raw/rebuilt'
    text = (record / 'cycle.log').read_text()
    begin = re.findall(r'^CYCLE_BEGIN cycle=(\S+) root=(\S+) source=(\S+) time=(\S+)$', text, re.M)
    end = re.findall(r'^CYCLE_END cycle=(\S+) result=TIME_VALID_CAPTURE_PASSED time=(\S+)$', text, re.M)
    require(len(begin) == len(end) == 1, 'Incomplete or duplicate cycle')
    label, root, commit, start = begin[0]
    require(label == end[0][0] == 'cycle1', 'Wrong standalone cycle label')
    require(root == '/home/b10504072/04_WR/artifacts/milestones/step6_global_time/source',
            'Not an independent milestone-directory run')
    require(start < end[0][1], 'Invalid cycle times')
    for marker in ('CURRENT_FIRMWARE_BUILD=PASS', 'Master Quartus build passed:',
                   'Slave Quartus build passed:', 'CURRENT_COMPILE=PASS',
                   'CURRENT_PROGRAM=PASS order=slave,master'):
        require(text.count(marker) == 1, 'Missing/duplicate pipeline stage: ' + marker)
    require((record / 'compiled-commit.txt').read_text().strip() == commit,
            'Compile identity mismatch')
    inputs = common.manifest((record / 'compile-inputs.sha256').read_text())
    require(len(inputs) == 3110, 'Wrong production input count')
    require(inputs == common.manifest((ROOT / 'output/SOURCE_SHA256SUMS').read_text()),
            'Production inputs differ from qualified main source')
    checks = (EXP / 'raw/identity/input-after-build.log').read_text().splitlines()
    require(len(checks) == 3110 and all(line.endswith(': OK') for line in checks),
            'Post-build production inputs failed checksum verification')
    images = {}
    golden_mifs = {
        'master': '18a51d784d08acfdc3bc6f24cff768661ea3918d234c6b19a2d360614a0da3ea',
        'slave': '91c5d7f9629a8a5d2a05116f12efd9515326ad25ee897a85ab97c71fc242c379',
    }
    for role in ('master', 'slave'):
        info = dict(line.split('=', 1) for line in
                    (record / f'build_info_{role}.txt').read_text().splitlines() if '=' in line)
        require(info['GIT_COMMIT'] == commit, 'Board compile identity mismatch')
        require(info['COMPILE_RESULT'] == 'Full Compilation was successful', 'Compile failed')
        actual = digest(record / f'{role}.sof')
        require(actual == info['SOF_SHA256'] == digest(rebuilt / f'output/DE5a_wr_{role}_jtag.sof'),
                'Actual retained SOF differs from compile identity')
        require(digest(rebuilt / f'build/firmware/{role}/wrc.mif') == info['MIF_SHA256'],
                'Actual firmware differs from compile identity')
        require(info['MIF_SHA256'] == golden_mifs[role], 'Firmware differs from pinned qualification')
        program = (EXP / f'raw/program/20261002T121941Z-current-{role}.log').read_text()
        require('Programmer was successful. 0 errors, 0 warnings' in program, 'Program failed')
        require(f'{root}/output/DE5a_wr_{role}_jtag.sof' in program, 'Program used another image')
        images[role] = {'sof_sha256': actual, 'mif_sha256': info['MIF_SHA256']}
    capture = common.gate.analyze_file(record / 'qualified-capture.log')
    require(capture['verdict'] == 'PASS_TIME_VALID_300S', 'Raw 300-second capture failed')
    require(digest(ROOT / 'artifacts/milestones/step6_global_time/source.tar.gz') ==
            '54950148ab09c0a5367f9779e59eaf993fcbef66877b8e7e461d642f8c7e2598',
            'Frozen archive changed')
    for role, expected in {
        'master': '9f66cef3f06697085325916126e6da61d76ace7138e7203af068df1a69d30036',
        'slave': 'b92e3356580691814e113e8c3278f1044bee621e2808d207541c9efc3ba59727',
    }.items():
        require(digest(ROOT / f'artifacts/milestones/step6_global_time/{role}.sof') == expected,
                'Original milestone SOF alias changed')
    return {'verdict': 'PASS_FRESH_STANDALONE_MILESTONE_REPRODUCTION',
            'root': root, 'source_commit': commit, 'start': start, 'end': end[0][1],
            'production_input_count': len(inputs), 'images': images,
            'time_valid': capture, 'frozen_archive_unchanged': True}


if __name__ == '__main__':
    print(json.dumps(audit(), indent=2, sort_keys=True))
