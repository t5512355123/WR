#!/usr/bin/env python3
"""Guarded WR acquisition observations; not an accuracy or 300s verifier."""
from collections import Counter
from pathlib import Path
import argparse
import json

STATE_NAMES = {0: 'UNINITIALIZED', 1: 'SYNC_TAI', 2: 'SYNC_NSEC',
               3: 'SYNC_PHASE', 4: 'TRACK_PHASE', 5: 'WAIT_OFFSET_STABLE'}


def trunc_div(value, divisor):
    return (-1 if value < 0 else 1) * (abs(value) // divisor)


def fields(line):
    return dict(token.split('=', 1) for token in line.split() if '=' in token)


def analyze(text):
    raw_rows = [fields(line) for line in text.splitlines()
                if line.startswith('S6_INTERLEAVED_SAMPLE ')]
    rejected = Counter()
    accepted = []
    prior = None
    arithmetic = []
    conflicts = 0
    skipped = 0
    duplicates = 0
    for row in raw_rows:
        try:
            if any(row.get(key) != '1' for key in (
                    'READS_VALID', 'PHASE_OBSERVATION_VALID', 'DIAG_FRAME_VALID',
                    'PHASE_CONTEXT_FRAME_VALID', 'PHASE_CONTEXT_MATCH')):
                rejected['frame_or_context_guard'] += 1
                prior = None
                continue
            if row.get('RESET_CHANGED') != '0':
                rejected['reset_changed'] += 1
                prior = None
                continue
            count = int(row['UCNT'], 16)
            if count != int(row['PHASE_CONTEXT_UCNT'], 16):
                rejected['context_ucnt_mismatch'] += 1
                prior = None
                continue
            item = {key: int(row[key]) for key in (
                'sample', 'elapsed_ms', 'SERVO_STATE', 'CKO_PS', 'SETP_PS', 'DMS_PS',
                'STATUS_TIME_VALID')}
            item['ucnt'] = count
            signature = tuple(item[key] for key in (
                'SERVO_STATE', 'CKO_PS', 'SETP_PS', 'DMS_PS'))
            item['signature'] = signature
        except (KeyError, ValueError):
            rejected['missing_or_bad_value'] += 1
            prior = None
            continue
        if prior is not None:
            delta = (count - prior['ucnt']) & 0xffffffff
            if delta == 0:
                if signature != prior['signature']:
                    conflicts += 1
                    rejected['same_ucnt_conflicting_payload'] += 1
                    prior = None
                    continue
                duplicates += 1
            elif delta != 1:
                skipped += 1
            else:
                divisor = None
                if prior['SERVO_STATE'] == 3 and item['SERVO_STATE'] == 5:
                    divisor = 2
                elif prior['SERVO_STATE'] == 4 and item['SERVO_STATE'] == 4:
                    divisor = 12
                if divisor is not None:
                    actual = item['SETP_PS'] - prior['SETP_PS']
                    expected = trunc_div(item['CKO_PS'], divisor)
                    arithmetic.append({'sample': item['sample'], 'ucnt': count,
                        'state_before': prior['SERVO_STATE'],
                        'state_after': item['SERVO_STATE'], 'divisor': divisor,
                        'setpoint_delta': actual, 'expected_delta': expected,
                        'matches': actual == expected})
        accepted.append(item)
        # Keep an earlier unique update across repeated observations, but never
        # bridge a rejected observation to manufacture an adjacent causal pair.
        if prior is None or prior['ucnt'] != count:
            prior = item
    unique = {}
    for item in accepted:
        unique.setdefault(item['ucnt'], item)
    states = Counter(STATE_NAMES.get(item['SERVO_STATE'], 'UNKNOWN') for item in unique.values())
    values = list(unique.values())

    def bounds(key):
        data = [item[key] for item in values]
        return {'min': min(data), 'max': max(data)} if data else None

    return {
        'scope': 'guarded_phase_context_diagnostic_only',
        'rows': len(raw_rows), 'accepted_rows': len(accepted),
        'rejected': dict(rejected), 'unique_updates': len(values),
        'duplicate_rows': duplicates, 'skipped_update_intervals': skipped,
        'same_ucnt_payload_conflicts': conflicts,
        'state_unique_update_counts': dict(states),
        'cko_ps': bounds('CKO_PS'), 'setpoint_ps': bounds('SETP_PS'),
        'dms_ps': bounds('DMS_PS'),
        'time_valid_accepted_rows': sum(item['STATUS_TIME_VALID'] == 1 for item in accepted),
        'valid_with_abs_cko_gt120_observations': sum(
            item['STATUS_TIME_VALID'] == 1 and abs(item['CKO_PS']) > 120 for item in accepted),
        'adjacent_arithmetic_pairs': arithmetic,
        'software_arithmetic_match_does_not_prove_actuator_response': True,
        'health_and_phase_groups_are_not_atomic': True,
        'has_reader_done': 'S6_INTERLEAVED_DONE' in text.splitlines(),
        'reader_error_lines': [line for line in text.splitlines()
            if line.startswith(('S6_INTERLEAVED_ERROR ', 'S6_INTERLEAVED_STOP '))],
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze(args.capture.read_text()), indent=2, sort_keys=True))
