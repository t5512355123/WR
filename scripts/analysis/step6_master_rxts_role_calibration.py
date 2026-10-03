#!/usr/bin/env python3
"""Independent exact status/command/scan audit. Never claims the300s goal."""
import argparse
import json
import re
from pathlib import Path


def fields(line):
    return {k: v.strip('{}') for k, v in re.findall(r'(\w+)=(\{[^}]*\}|\S+)', line)}


def status(text):
    a = re.findall(r'RXTS_DIAG active_t24p_ps=(\d+) phase_ps=(-?\d+) ptracker_ready=([01])', text)
    b = re.findall(r'RXTS_SCAN phase_ps=(\d+) rising_state=(\d+) rising_count=(\d+) rising_ps=(-?\d+) falling_state=(\d+) falling_count=(\d+) falling_ps=(-?\d+)', text)
    if len(a) != 1 or len(b) != 1: raise ValueError('missing/duplicate scan status')
    active, phase, ready = map(int, a[0])
    scan, rs, rc, r, fs, fc, f = map(int, b[0])
    if not (0 <= active < 8000 and 0 <= phase < 8000 and 0 <= scan <= 9500
            and scan % 100 == 0 and rs in (0, 1, 2) and fs in (0, 1, 2)
            and 0 <= rc <= 5 and 0 <= fc <= 5): raise ValueError('invalid scan status')
    d = dict(active=active, ready=ready, scan=scan, rising_state=rs, rising_count=rc,
             rising=r, falling_state=fs, falling_count=fc, falling=f)
    return d


def midpoint(d):
    if not (d['rising_state'] == d['falling_state'] == 2 and
            d['rising_count'] == d['falling_count'] == 5 and d['scan'] == 9500 and d['ready']):
        return None
    r, f = d['rising'], d['falling']
    if not (0 <= r < 8000 and 0 <= f < 8000 and r != f): raise ValueError('invalid measured transition')
    f += -4000 if f > r else 4000
    total = r + f
    result = (total // 2 if total >= 0 else -((-total) // 2)) % 8000
    if result != d['active']: raise ValueError('active value differs from measured C midpoint')
    return result


def analyze(path):
    lines = Path(path).read_text().splitlines()
    configs = [fields(s) for s in lines if s.startswith('RXCAL_CONFIG ')]
    dones = [fields(s) for s in lines if s.startswith('RXCAL_DONE ')]
    errors = []
    scans, roles, commands, health = [], [], [], []
    baseline = {}; measured = None
    if len(configs) != 1 or any(configs[0].get(k) != v for k, v in {
            'control': 'role_exchange', 'calibrator': 'builtin', 'same_gateware': '1',
            'calibration_wait_ms': '240000', 'max_actual_ms': '600000', 'parameters_changed': '0'}.items()):
        errors.append('missing/wrong fixed experiment contract')
    if len(dones) != 1:
        errors.append('missing/duplicate completion')
    else:
        try:
            if not (dones[0]['measured'] == dones[0]['restored'] == '1' and
                    dones[0]['goal_pass'] == '0' and 0 <= int(dones[0]['elapsed_ms']) <= 600000):
                errors.append('unqualified measurement/restoration or actual deadline')
        except (KeyError, ValueError): errors.append('malformed completion')
    for line in lines:
        if line.startswith(('RXCAL_FAILURE ', 'RXCAL_RESTORE_FAILURE ')):
            errors.append('operator explicitly failed')
        try:
            if line.startswith('RXCAL_HEALTH '):
                d = fields(line); board = d['board']
                st = int(d['STATUS'], 16)
                if len(d['STATUS']) != 16 or any(not (st >> bit & 1) for bit in (0,1,2,3,6,7,15,32)):
                    raise ValueError('untrusted link/clock word')
                sig = d['RESET']
                if board in baseline and baseline[board] != sig: raise ValueError('boot/reset changed')
                baseline[board] = sig
                if int(d['CALFAIL']) != 0: raise ValueError('built-in calibration failed')
                h, m, p, spll = (int(d[k], 16) for k in ('H', 'M', 'P', 'SPLL'))
                health.append(dict(board=board, mode=(spll >> 16) & 255,
                                   helper=h & 1, main_locked=(m & 14) == 14 and bool(p & 2),
                                   status_raw=d['STATUS'], reset=sig))
            elif line.startswith('RXCAL_REPLY '):
                d = fields(line); command, board = d['command'], d['board']
                if d['status'] != 'OK': raise ValueError('command transport failed')
                text = bytes.fromhex(d['hex']).decode('ascii')
                if re.search(r'unknown (?:sub)?command|unrecognized command|Command "[^"]+": error -?\d+', text, re.I):
                    raise ValueError('firmware command failed')
                if command not in ('ptp master start', 'ptp slave start', 'ptp', 'calibration status'):
                    raise ValueError('nonallowlisted command')
                commands.append((board, command))
                if command == 'calibration status': scans.append((board, status(text)))
                if command == 'ptp':
                    r = re.findall(r'running; e2e (master|slave)(?:\r|\n)', text)
                    if len(r) != 1: raise ValueError('unconfirmed runtime role')
                    roles.append((board, r[0]))
        except (KeyError, ValueError, UnicodeError) as exc:
            errors.append(str(exc))
    master = [b for b in baseline if '1-11.1' in b]
    slave = [b for b in baseline if '1-11.2' in b]
    if len(master) != 1 or len(slave) != 1 or len(baseline) != 2:
        errors.append('physical two-board identity not established')
    else:
        master, slave = master[0], slave[0]
        first_m = next((h for h in health if h['board'] == master), {})
        first_s = next((h for h in health if h['board'] == slave), {})
        if not (first_m.get('mode') == 2 and first_m.get('helper') == 1 and
                first_s.get('mode') == 3 and first_s.get('helper') == 1 and first_s.get('main_locked')):
            errors.append('initial normal-role lock health not established')
        measured_health = [h for h in health if h['board'] == master and h['mode'] == 3
                           and h['helper'] == 1 and h['main_locked']]
        if len(measured_health) < 2: errors.append('no two measured Slave-mode lock confirmations')
        controls = [(b, c) for b, c in commands if c.startswith('ptp ') ]
        if controls != [(slave,'ptp master start'), (master,'ptp slave start'),
                        (master,'ptp master start'), (slave,'ptp slave start')]:
            errors.append('wrong/missing/repeated fixed control sequence')
        if roles != [(slave,'master'),(master,'slave'),(master,'master'),(slave,'slave')]:
            errors.append('wrong/missing role confirmation sequence')
        ms = [d for b,d in scans if b == master]
        if len(ms) < 4 or ms[0]['rising_state'] != 0 or ms[0]['falling_state'] != 0:
            errors.append('no fresh boot scan followed by confirmations and retention')
        else:
            try:
                measured = midpoint(ms[-2])
                if measured is None or ms[-2] != ms[-3] or ms[-1]['active'] != measured:
                    errors.append('no two identical fresh measured scans and retained active value')
            except ValueError as exc: errors.append(str(exc))
    return dict(verdict='QUALIFIED_SCAN_AND_ROLE_RESTORE_DATA_ONLY' if not errors else 'NOT_QUALIFIED',
                measured_t24p_ps=measured, commands=commands, role_confirmations=roles,
                health=health, scan_statuses=scans, errors=sorted(set(errors)),
                goal_pass=False, scope='Measured calibration and role restoration only; no300s TIME_VALID or causal-isolation claim.')


if __name__ == '__main__':
    p = argparse.ArgumentParser(); p.add_argument('log'); args = p.parse_args()
    r = analyze(args.log); print(json.dumps(r, indent=2))
    raise SystemExit(0 if not r['errors'] else 2)
