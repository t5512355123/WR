import importlib.util
import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('trial', HERE / 'analyze_trial.py')
trial = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trial)


class DescriptiveTests(unittest.TestCase):
    def test_actual_full_validated_history(self):
        raw = HERE / 'raw/observe/20261003T080841Z-main-timestamp-pair.log'
        result = trial.pair.analyze(raw)
        audit = trial.describe(result)
        self.assertEqual(audit['intervals'], 15)
        self.assertEqual(audit['main_progress_intervals'], 15)
        self.assertEqual(audit['main_update_delta'], 58876)
        self.assertEqual(audit['producer_span_ms'], 15435)
        self.assertEqual(len(audit['large_cko_steps']), 5)
        self.assertEqual(audit['strict60_rows'], 0)
        self.assertEqual(audit['inclusive120_rows'], 0)

    def test_bad_primary_gate_is_not_described(self):
        for bad in ({'errors': ['missing'], 'verdict': 'INCONCLUSIVE'},
                    {'errors': [], 'verdict': 'INCONCLUSIVE'}):
            with self.assertRaises(ValueError):
                trial.describe(bad)

    def test_json_state_keys_are_representation_not_gate_change(self):
        raw = HERE / 'raw/observe/20261003T081852Z-strict-offset-validity.log'
        actual = trial.strict.analyze(raw)
        saved = json.loads((HERE / 'analysis/20261003T081852Z-strict-offset-300s.json').read_text())
        self.assertEqual(json.loads(json.dumps(actual)), saved)
        self.assertEqual(saved['maximum_qualified_span_ms'], 0)
        self.assertEqual(saved['verdict'], 'NOT_ESTABLISHED')

    def test_same_boot_packet_provenance_and_control_action_not_hidden(self):
        import step6_paired_return_details as details
        result = details.details(HERE / 'raw/observe/20261003T083252Z-paired-return.log')
        self.assertEqual(result['gate']['errors'], [])
        self.assertEqual(len(result['rows']), 16)
        self.assertEqual(result['ranges']['coarse_return_ps'], [176000, 176000])
        step = next(d for d in result['differences'] if d['from_ucnt'] == 1816)
        self.assertEqual(step['coarse_return_ps'], 0)
        self.assertEqual(step['previous_phase_action_ps'], -697)
        self.assertEqual(step['raw_return_ps'], step['linearization_correction_ps'])
        self.assertGreater(step['raw_return_ps'], 8500)


if __name__ == '__main__':
    unittest.main()
