import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/analysis'))
from step6_paired_return_details import details

spec = importlib.util.spec_from_file_location('paired_fixture', ROOT / 'scripts/tests/test_step6_paired_return.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class DetailsTests(unittest.TestCase):
    def result(self, text):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'trace.log'
            path.write_text(text)
            return details(path)

    def test_exact_all_pairs_and_eight_ns_decomposition(self):
        result = self.result(fixture.fixture())
        self.assertEqual(result['gate']['errors'], [])
        self.assertEqual(len(result['rows']), 16)
        self.assertEqual(len(result['differences']), 15)
        step = result['differences'][0]
        self.assertEqual(step['linearization_correction_ps'], 8000)
        self.assertEqual(step['coarse_return_ps'], 0)
        self.assertEqual(step['raw_return_ps'], 8000)
        self.assertEqual(step['cko_ps'], 4000)
        self.assertTrue(step['ahead_changed'])

    def test_high_tai_and_partial_overlap_do_not_create_missing_pairs(self):
        result = self.result(fixture.fixture(
            lambda j,w: w.__setitem__(1,w[1]+100) if j<24 else None, tai=2**39+55))
        self.assertEqual(result['gate']['errors'], [])
        self.assertEqual(len(result['rows']), 8)
        self.assertEqual(len(result['differences']), 7)

    def test_refuses_unvalidated_data(self):
        result = self.result(fixture.fixture().replace('master_records=32', 'master_records=31'))
        self.assertEqual(result['gate']['verdict'], 'INCONCLUSIVE')
        self.assertEqual(result['rows'], [])
        self.assertEqual(result['differences'], [])


if __name__ == '__main__':
    unittest.main()
