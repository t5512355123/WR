"""Offline descriptive comparison, not a causal or sustained-validity test."""
import json
import math
import statistics
import sys
from pathlib import Path


def summarize(path):
    data = json.loads(Path(path).read_text())
    if data['errors'] or data['verdict'] != 'PASS_POST_ACCEPT_PHASE_DATA_ONLY':
        raise ValueError('unvalidated history cannot support comparison')
    rows = data['rows']
    if len(rows) != 32 or any(r['branch'] != 2 for r in rows):
        raise ValueError('comparison requires all32 Main phase-branch rows')
    result = {'rows': len(rows), 'states': data['states'],
              'main_progress_pairs': data['main_progress_pairs'],
              'tracker_progress_pairs': data['tracker_progress_pairs'],
              'ranges': data['ranges'],
              'firmware_window_ms': rows[-1]['ms'] - rows[0]['ms'],
              'main_flags': sorted({r['main_flags'] for r in rows}),
              'sample_n_delta': rows[-1]['sample_n'] - rows[0]['sample_n'],
              'tracker_publication_delta': rows[-1]['tracker_publications'] -
                                           rows[0]['tracker_publications'],
              'freq_error_range': [min(r['freq_error'] for r in rows),
                                   max(r['freq_error'] for r in rows)],
              'no_wr_action_pairs': sum(d['setpoint_action_before_ps'] == 0
                                        for d in data['differences'])}
    for key in ('cko_ps', 'main_error_ps'):
        values = [r[key] for r in rows]
        result[key] = {'mean': statistics.mean(values),
                       'mean_abs': statistics.mean(map(abs, values)),
                       'median_abs': statistics.median(map(abs, values)),
                       'population_stdev': statistics.pstdev(values),
                       'rms': math.sqrt(statistics.mean(v*v for v in values)),
                       'strict_under60_rows': sum(abs(v) < 60 for v in values),
                       'inclusive120_rows': sum(abs(v) <= 120 for v in values)}
    return result


if __name__ == '__main__':
    old, new = map(summarize, sys.argv[1:3])
    print(json.dumps({'baseline_kp300': old, 'candidate_kp600': new,
        'scope': 'Different boots; post-WR independently copied Main/tracker groups. '
                 'Descriptive only, not randomised causal proof, packet-time phase, '
                 'physical skew, or300s TIME_VALID proof.'}, indent=2))
