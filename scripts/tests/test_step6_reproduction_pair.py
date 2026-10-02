import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / 'analysis/step6_reproduction_pair.py'
spec = importlib.util.spec_from_file_location('pair_audit', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PairAuditTests(unittest.TestCase):
    def records(self):
        a = {'start': '2026-10-02T10:00:00+08:00', 'end': '2026-10-02T11:00:00+08:00',
             'capture_sha256': 'a'}
        b = {'start': '2026-10-02T12:00:00+08:00', 'end': '2026-10-02T13:00:00+08:00',
             'capture_sha256': 'b'}
        return a, b

    def test_accepts_two_distinct_nonoverlapping_cycles(self):
        a, b = self.records()
        with patch.object(module, 'audit_cycle', side_effect=[(a, {'x': 'y'}), (b, {'x': 'y'})]):
            self.assertEqual(module.audit_pair(Path('a'), Path('b'))['verdict'],
                             'PASS_TWO_INDEPENDENT_ROOT_CYCLES')

    def test_rejects_changed_compile_inputs(self):
        a, b = self.records()
        with patch.object(module, 'audit_cycle', side_effect=[(a, {'x': 'y'}), (b, {'x': 'z'})]):
            with self.assertRaisesRegex(ValueError, 'inputs differ'):
                module.audit_pair(Path('a'), Path('b'))

    def test_rejects_overlapping_cycles(self):
        a, b = self.records()
        b['start'] = a['start']
        with patch.object(module, 'audit_cycle', side_effect=[(a, {}), (b, {})]):
            with self.assertRaisesRegex(ValueError, 'non-overlapping'):
                module.audit_pair(Path('a'), Path('b'))

    def test_rejects_reused_capture(self):
        a, b = self.records()
        b['capture_sha256'] = a['capture_sha256']
        with patch.object(module, 'audit_cycle', side_effect=[(a, {}), (b, {})]):
            with self.assertRaisesRegex(ValueError, 'reused'):
                module.audit_pair(Path('a'), Path('b'))

    def test_rejects_duplicate_manifest_paths(self):
        line = '0' * 64 + '  firmware/example.c\n'
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            module.manifest(line + line)

    def test_manifest_keeps_all_path_components(self):
        self.assertEqual(module.manifest('a' * 64 + '  folder/file name.v'),
                         {'folder/file name.v': 'a' * 64})
