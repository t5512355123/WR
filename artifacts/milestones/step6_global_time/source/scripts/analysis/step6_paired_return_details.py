"""Descriptive decomposition AFTER the unchanged paired provenance gate passes.

No new acceptance gate, filtering, tolerance or Step6 PASS inference.
"""
import argparse
import json
import re
from collections import Counter
from pathlib import Path

from step6_paired_return_provenance import analyze, four, rx


def details(path):
    verdict = analyze(path)
    if verdict['errors']:
        return {'gate': verdict, 'rows': [], 'differences': []}
    text = Path(path).read_text()
    master = {}
    for line in text.splitlines():
        if not line.startswith('RXTS_REPLY '):
            continue
        raw = bytes.fromhex(re.search(r' hex=([0-9a-fA-F]+)$', line)[1]).decode('ascii')
        for _, payload in re.findall(r'^RXTS_V1 idx=(\d+) words=([^\r\n]+)', raw, re.M):
            w = [int(x, 16) for x in payload.split()]
            sec = (w[10] << 32) | w[11]
            scaled = sec * four.SCALED_PER_SEC + rx.signed32(w[12]) * 65536 + rx.signed32(w[13]) * 65536 // 1000
            coarse = ((w[5] << 32) | w[6]) * four.SCALED_PER_SEC + rx.signed32(w[7]) * 65536
            master[(w[1] & 0xffff, (w[1] >> 16) & 255)] = (w, scaled, coarse)
    rows = []
    sid = total = None
    for line in text.splitlines():
        if not line.startswith('TS4_REPLY '):
            continue
        page = int(re.search(r' page=(\d+)', line)[1])
        raw = bytes.fromhex(re.search(r' hex=([0-9a-fA-F]+)$', line)[1]).decode('ascii')
        sid, total, r = four.parse_page(raw, page, sid, total)
        key = (r['delay_seq'], (r['source'][0] >> 16) & 255)
        if key not in master:
            continue
        mw, scaled, coarse = master[key]
        w = [int(x, 16) for x in re.search(r'^TS4_V1 idx=\d+ words=([^\r\n]+)', raw, re.M)[1].split()]
        assert scaled == four.time_value(w, 28)
        coarse_leg = four.ps(coarse - four.time_value(w, 24))
        fine = four.ps(scaled - coarse)
        assert coarse_leg + fine == r['raw_return']
        rows.append({'ucnt': r['ucnt'], 'delay_seq': r['delay_seq'],
            'master_serial': mw[0], 'cko_ps': float(r['cko']),
            'dms_ps': float(r['dms']), 'raw_forward_ps': float(r['raw_forward']),
            'raw_return_ps': float(r['raw_return']), 'coarse_return_ps': float(coarse_leg),
            'linearization_correction_ps': float(fine),
            'master_raw_phase_ps': rx.signed32(mw[8]), 'master_t24p_ps': rx.signed32(mw[9]),
            'ahead': bool(mw[4] & (1 << 17)), 'falling': bool(mw[4] & (1 << 18)),
            'pre_state': r['pre_state'], 'state': r['state'],
            'setp_before_ps': r['setp_before'], 'setp_after_ps': r['setp_after'],
            'phase_write_count': r['writes']})
    differences = []
    for a, b in zip(rows, rows[1:]):
        if (b['ucnt'] - a['ucnt']) & 0xffffffff != 1:
            continue
        delta = {'from_ucnt': a['ucnt'], 'to_ucnt': b['ucnt']}
        for key in ('cko_ps', 'dms_ps', 'raw_forward_ps', 'raw_return_ps',
                    'coarse_return_ps', 'linearization_correction_ps'):
            delta[key] = b[key] - a[key]
        delta['ahead_changed'] = a['ahead'] != b['ahead']
        delta['previous_phase_action_ps'] = a['setp_after_ps'] - a['setp_before_ps']
        delta['current_phase_action_ps'] = b['setp_after_ps'] - b['setp_before_ps']
        differences.append(delta)
    assert len(rows) == verdict['paired_updates']
    assert len(differences) == verdict['consecutive_paired_differences']
    ranges = {key: [min(r[key] for r in rows), max(r[key] for r in rows)]
              for key in ('master_raw_phase_ps', 'cko_ps', 'dms_ps', 'raw_forward_ps',
                          'raw_return_ps', 'coarse_return_ps', 'linearization_correction_ps')}
    return {'gate': verdict, 'ranges': ranges,
        'ahead_counts': dict(Counter(str(int(r['ahead'])) for r in rows)),
        'falling_counts': dict(Counter(str(int(r['falling'])) for r in rows)),
        'rows': rows, 'differences': differences,
        'scope': 'Descriptive same accepted pairs only. Exact full64 gate unchanged. Digital decomposition is not analogue accuracy, causality, calibration validity or strict300s PASS.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('trace')
    result = details(parser.parse_args().trace)
    print(json.dumps(result, indent=2))
    raise SystemExit(bool(result['gate']['errors']))
