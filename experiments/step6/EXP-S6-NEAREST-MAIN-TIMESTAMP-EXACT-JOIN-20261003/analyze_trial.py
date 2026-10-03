"""Independent return audit; descriptive results never replace formal gates."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / 'scripts/analysis'))
import step6_main_timestamp_pair as pair
import step6_strict_offset_300s as strict


def describe(result):
    if result['errors'] or result['verdict'] != 'PASS_EXACT_UPDATE_JOIN_DATA_ONLY':
        raise ValueError('Do not interpret unvalidated paired history')
    rows = result['rows']
    steps = result['differences']
    jumps = [s for s in steps if abs(s['cko_ps']) >= 1000]
    return {
        'ucnt_first': rows[0]['ucnt'], 'ucnt_last': rows[-1]['ucnt'],
        'producer_span_ms': rows[-1]['ms'] - rows[0]['ms'],
        'main_update_delta': sum(s['main_updates'] for s in steps),
        'main_progress_intervals': sum(s['main_updates'] > 0 for s in steps),
        'tracker_progress_intervals': sum(s['tracker_publications'] > 0 for s in steps),
        'intervals': len(steps), 'large_cko_steps': jumps,
        'strict60_rows': sum(abs(r['cko_ps']) < 60 for r in rows),
        'inclusive120_rows': sum(abs(r['cko_ps']) <= 120 for r in rows),
        'scope': 'Full source-validated history, no row selection in formal gates. '
                 'Main/tracker copied post-accept, not simultaneous with packet RX. '
                 'Action-free WR steps are not frozen physical PLL/DAC outputs. '
                 'No causal or 300s PASS claim.'}


def main():
    verified = []
    for raw in sorted((HERE / 'raw/observe').glob('*strict-offset-validity.log')):
        result = strict.analyze(raw)
        remote = HERE / 'analysis' / raw.name.replace('strict-offset-validity.log', 'strict-offset-300s.json')
        # The formal analyzer has integer state-map keys; JSON object keys
        # are strings. Compare the exact serialized values, not dict types.
        assert json.loads(json.dumps(result)) == json.loads(remote.read_text()), raw
        verified.append(str(raw.relative_to(HERE)))
    captures = list((HERE / 'raw/observe').glob('*main-timestamp-pair.log'))
    assert len(captures) == 1 and len(verified) == 3
    result = pair.analyze(captures[0])
    assert result == json.loads((HERE / 'analysis' / (captures[0].stem + '.json')).read_text())
    verified.append(str(captures[0].relative_to(HERE)))
    report = {'independent_json_equality': verified, 'descriptive': describe(result)}
    destination = HERE / 'analysis/laptop-independent-audit.json'
    destination.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
