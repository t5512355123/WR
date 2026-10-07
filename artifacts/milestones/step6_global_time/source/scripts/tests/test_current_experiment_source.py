"""Guard the TIME_VALID-only backtrack, not the superseded strict candidate."""
from pathlib import Path
import hashlib
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASELINE = '0bb02c6f91dd4c7a578e1b8cb02a553ce9ce9787'
INERT_ADDITIONS = {
    'vendor/wrpc-sw/include/phase-history.h',
    'vendor/wrpc-sw/include/rxts-diag.h',
    'vendor/wrpc-sw/include/wr-ts-diag.h',
    'vendor/wrpc-sw/include/wrh-fixed-diag.h',
    'vendor/wrpc-sw/lib/phase-history.c',
    'vendor/wrpc-sw/lib/rxts-diag.c',
    'vendor/wrpc-sw/softpll/spll_ptracker_diag.h',
}
CURRENT_HASHES = {
    'vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c':
        '0eb04e6a35dee436d21f81b0b9d5bb493e0299847304fc095e9be1ffa48cd97f',
    'quartus/DE5a_wr_master_jtag.vhd':
        '1cbaf7b40f831bd7d1ba32702dbfc80b1a7dfb3948eca5d7dd8922e57cc880ed',
    'quartus/DE5a_wr_slave_jtag.vhd':
        'cf4db299a18e954fba52b379673717494be22448b47df6a40af4c6845cdb449e',
}

class CurrentSourceTests(unittest.TestCase):
    def test_all_3110_qualified_inputs_match(self):
        paths = ('firmware', 'vendor', 'quartus', 'quartus_generated')
        has_history = subprocess.run(
            ['git', 'cat-file', '-e', BASELINE + '^{commit}'], cwd=ROOT,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
        if not has_history:
            # A prepared standalone milestone intentionally has one independent
            # Git commit, not the parent repo's history. Verify its pinned real
            # qualified production manifest instead of depending on that repo.
            self.assertEqual(ROOT.name, 'source')
            self.assertEqual(ROOT.parent.name, 'step6_global_time')
            self.assertTrue((ROOT / '.archive-sha256').is_file())
            manifest = (ROOT / 'output/SOURCE_SHA256SUMS').read_bytes()
            self.assertEqual(hashlib.sha256(manifest).hexdigest(),
                '418bb2546c08cb7b67c09309b58ce1de4c4668e39e3ec84dc94a4add850c6e6a')
            entries = manifest.decode().splitlines()
            self.assertEqual(len(entries), 3110 + len(INERT_ADDITIONS))
            for entry in entries:
                digest, path = entry.split('  ', 1)
                self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
            return
        historical = subprocess.check_output(
            ['git', 'ls-tree', '-r', '--name-only', BASELINE, '--', *paths],
            cwd=ROOT, text=True).splitlines()
        self.assertEqual(len(historical), 3110)
        diff = subprocess.check_output(
            ['git', 'diff', '--no-ext-diff', '--name-status', BASELINE, '--', *paths],
            cwd=ROOT, text=True).splitlines()
        for line in diff:
            status, path = line.split('\t', 1)
            self.assertEqual(status, 'A', line)
            self.assertIn(path, INERT_ADDITIONS)
        self.assertEqual({line.split('\t', 1)[1] for line in diff}, INERT_ADDITIONS)

    def test_qualified_hashes_and_controller_contract(self):
        for path, expected in CURRENT_HASHES.items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), expected)
        text = (ROOT / 'vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c').read_text()
        self.assertEqual(text.count('s->cur_setpoint_ps += (offset_ps / 2);'), 1)
        self.assertEqual(text.count('s->cur_setpoint_ps += (offset_ps / 12);'), 1)
        self.assertIn('2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD', text)
        self.assertNotIn('invalidate_slave_time', text)
        self.assertNotIn('FIXED_SETP', text)
        self.assertEqual(text.count('enable_timing_output(GLBS(ppi),1)'), 1)
        for path in ('vendor/wrpc-sw/lib/lib.mk', 'vendor/wrpc-sw/lib/net.c',
                     'vendor/wrpc-sw/softpll/spll_ptracker.c'):
            text = (ROOT / path).read_text()
            self.assertNotIn('phase-history', text)
            self.assertNotIn('rxts-diag', text)

    def test_master_controller_generic_map_matches_declared_interface(self):
        source = (ROOT / 'quartus/DE5a_wr_master_jtag.vhd').read_text()
        interface = source.split('component si5340a_controller_dco is', 1)[1].split('port (', 1)[0]
        mapping = source.split('u_si5340a_controller : si5340a_controller_dco', 1)[1].split('port map', 1)[0]
        declared = set(re.findall(r'(\w+)\s*:\s*integer', interface))
        used = set(re.findall(r'(\w+)\s*=>', mapping))
        self.assertTrue(used <= declared, f'undeclared generic(s): {used - declared}')

    def test_firmware_identity_is_pinned_without_fake_checkout_identity(self):
        text = (ROOT / 'scripts/build/current_experiment.env').read_text()
        self.assertIn('CURRENT_MASTER_MIF_SHA256=18a51d784d08acfdc3bc6f24cff768661ea3918d234c6b19a2d360614a0da3ea', text)
        self.assertIn('CURRENT_SLAVE_MIF_SHA256=91c5d7f9629a8a5d2a05116f12efd9515326ad25ee897a85ab97c71fc242c379', text)
        for role in ('master', 'slave'):
            text = (ROOT / f'scripts/build/build_{role}.sh').read_text()
            self.assertIn('git -C "$ROOT" rev-parse HEAD', text)

    def test_wrapper_preserves_failed_verdict_and_unchanged_qualification(self):
        text = (ROOT / 'scripts/monitor/verify_time_valid_300s.sh').read_text()
        self.assertIn('--required-duration-ms 300000 --max-sample-gap-ms 1000', text)
        self.assertIn('--minimum-samples 301 --boards 1-11.1,1-11.2', text)
        self.assertIn('ANALYZER_RC=$?', text)
        self.assertLess(text.index('sha256sum "$RESULT"'), text.index('exit "$ANALYZER_RC"'))

if __name__ == '__main__':
    unittest.main()
