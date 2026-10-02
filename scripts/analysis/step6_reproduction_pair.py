#!/usr/bin/env python3
"""Audit two complete independent root reproduction cycles, not two dashboards."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

spec = importlib.util.spec_from_file_location(
    'time_valid_gate', Path(__file__).with_name('step6_time_valid_300s.py'))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def manifest(text):
    result = {}
    for line in text.splitlines():
        digest, path = line.split(None, 1)
        path = path.lstrip('* ')
        if not re.fullmatch('[0-9a-f]{64}', digest) or path in result:
            raise ValueError('Invalid/duplicate checksum manifest entry')
        result[path] = digest
    return result


def audit_cycle(record, expected_label):
    log = (record / 'cycle.log').read_text()
    begin = re.findall(r'^CYCLE_BEGIN cycle=(\S+) root=(\S+) source=(\S+) time=(\S+)$', log, re.M)
    end = re.findall(r'^CYCLE_END cycle=(\S+) result=TIME_VALID_CAPTURE_PASSED time=(\S+)$', log, re.M)
    if len(begin) != 1 or len(end) != 1:
        raise ValueError('Cycle is incomplete or contains multiple begin/end records')
    label, root, source, start = begin[0]
    if label != expected_label or end[0][0] != label or root != '/home/b10504072/04_WR':
        raise ValueError('Wrong cycle identity or not a main-root run')
    for marker in ['CURRENT_FIRMWARE_BUILD=PASS', 'Master Quartus build passed:',
                   'Slave Quartus build passed:', 'CURRENT_COMPILE=PASS', 'CURRENT_PROGRAM=PASS order=slave,master']:
        if log.count(marker) != 1:
            raise ValueError('Missing/duplicate full-cycle stage: ' + marker)
    compiled = (record / 'compiled-commit.txt').read_text().strip()
    if compiled != source:
        raise ValueError('Cycle source/compile identity differs')
    sofs = manifest((record / 'sof.sha256').read_text())
    mifs = {}
    for role in ['master', 'slave']:
        info = dict(line.split('=', 1) for line in
                    (record / f'build_info_{role}.txt').read_text().splitlines() if '=' in line)
        if info.get('GIT_COMMIT') != compiled or info.get('SOF_SHA256') != sofs.get(f'output/DE5a_wr_{role}_jtag.sof'):
            raise ValueError('Board build identity/SOF checksum mismatch')
        if info.get('COMPILE_RESULT') != 'Full Compilation was successful':
            raise ValueError('Board compile did not complete')
        if hashlib.sha256((record / f'{role}.sof').read_bytes()).hexdigest() != info['SOF_SHA256']:
            raise ValueError('Retained actual SOF differs from board build identity')
        mifs[role] = info.get('MIF_SHA256')
        if not re.fullmatch('[0-9a-f]{64}', mifs[role] or ''):
            raise ValueError('Missing board firmware identity')
    capture = record / 'qualified-capture.log'
    verdict = gate.analyze_file(capture, required_duration_ms=300000,
                               max_sample_gap_ms=1000, minimum_samples=301,
                               required_boards=('1-11.1', '1-11.2'))
    if verdict['verdict'] != 'PASS_TIME_VALID_300S':
        raise ValueError('Raw capture did not independently pass the 300-second gate')
    inputs = manifest((record / 'compile-inputs.sha256').read_text())
    if len(inputs) < 2500:
        raise ValueError('Compile input manifest is incomplete')
    return {'cycle': label, 'start': start, 'end': end[0][1], 'compiled_commit': compiled,
            'sofs': sofs, 'mifs': mifs, 'capture_sha256': hashlib.sha256(capture.read_bytes()).hexdigest(),
            'time_valid': verdict}, inputs


def audit_pair(first, second):
    a, ai = audit_cycle(first, 'cycle1')
    b, bi = audit_cycle(second, 'cycle2')
    if ai != bi:
        raise ValueError('Production compile inputs differ between cycles')
    if a['mifs'] != b['mifs']:
        raise ValueError('Firmware products differ between cycles')
    if not a['start'] < a['end'] < b['start'] < b['end']:
        raise ValueError('Cycles are not two consecutive non-overlapping runs')
    if a['capture_sha256'] == b['capture_sha256']:
        raise ValueError('The same capture was reused for both cycles')
    return {'verdict': 'PASS_TWO_INDEPENDENT_ROOT_CYCLES',
            'compile_input_count': len(ai), 'production_inputs_identical': True,
            'cycles': [a, b], 'accuracy_and_universal_startup_repeatability_not_claimed': True}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('cycle1', type=Path)
    p.add_argument('cycle2', type=Path)
    args = p.parse_args()
    try:
        print(json.dumps(audit_pair(args.cycle1, args.cycle2), indent=2, sort_keys=True))
    except (ValueError, OSError, KeyError) as error:
        print(json.dumps({'verdict': 'TWO_CYCLES_NOT_ESTABLISHED', 'reason': str(error)}))
        raise SystemExit(1)
