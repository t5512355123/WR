import unittest
from scripts.analysis.step6_acquisition_attribution import analyze, trunc_div


def row(sample, count, state, cko, setp, **overrides):
    data = dict(sample=str(sample), elapsed_ms=str(sample * 300),
        UCNT=f'{count:08X}', PHASE_CONTEXT_UCNT=f'{count:08X}',
        SERVO_STATE=str(state), CKO_PS=str(cko), SETP_PS=str(setp), DMS_PS='100000',
        STATUS_TIME_VALID='0', READS_VALID='1', PHASE_OBSERVATION_VALID='1',
        DIAG_FRAME_VALID='1', PHASE_CONTEXT_FRAME_VALID='1',
        PHASE_CONTEXT_MATCH='1', RESET_CHANGED='0')
    data.update(overrides)
    return 'S6_INTERLEAVED_SAMPLE board=DE5 [1-11.2] ' + ' '.join(f'{k}={v}' for k,v in data.items())


class AttributionTests(unittest.TestCase):
    def test_negative_truncation(self):
        self.assertEqual(trunc_div(-5, 2), -2)
        self.assertEqual(trunc_div(-13, 12), -1)

    def test_half_acquisition(self):
        result = analyze(row(0, 10, 3, 100, 1000) + '\n' + row(1, 11, 5, -5, 998))
        self.assertTrue(result['adjacent_arithmetic_pairs'][0]['matches'])

    def test_twelfth_tracking(self):
        result = analyze(row(0, 10, 4, 5, 1000) + '\n' + row(1, 11, 4, -13, 999))
        self.assertTrue(result['adjacent_arithmetic_pairs'][0]['matches'])

    def test_skip_is_not_a_pair(self):
        result = analyze(row(0, 10, 3, 100, 1000) + '\n' + row(1, 12, 5, -5, 998))
        self.assertEqual(result['adjacent_arithmetic_pairs'], [])
        self.assertEqual(result['skipped_update_intervals'], 1)

    def test_torn_context_rejected(self):
        result = analyze(row(0, 10, 5, 100, 1000, PHASE_CONTEXT_MATCH='0'))
        self.assertEqual(result['accepted_rows'], 0)

    def test_mismatched_context_identity_rejected(self):
        result = analyze(row(0, 10, 5, 100, 1000, PHASE_CONTEXT_UCNT='0000000B'))
        self.assertEqual(result['accepted_rows'], 0)

    def test_same_counter_conflict_rejected(self):
        result = analyze(row(0, 10, 5, 100, 1000) + '\n' + row(1, 10, 5, 101, 1000))
        self.assertEqual(result['same_ucnt_payload_conflicts'], 1)

    def test_bad_row_breaks_pair(self):
        result = analyze('\n'.join([row(0, 10, 3, 100, 1000),
            row(1, 10, 3, 100, 1000, DIAG_FRAME_VALID='0'), row(2, 11, 5, -5, 998)]))
        self.assertEqual(result['adjacent_arithmetic_pairs'], [])

    def test_valid_not_used_as_phase_guard(self):
        result = analyze(row(0, 10, 5, 2400, 1000))
        self.assertEqual(result['accepted_rows'], 1)
        self.assertEqual(result['time_valid_accepted_rows'], 0)

    def test_valid_outside_band_is_not_precision_pass(self):
        result = analyze(row(0, 10, 5, 2400, 1000, STATUS_TIME_VALID='1'))
        self.assertEqual(result['valid_with_abs_cko_gt120_observations'], 1)
        self.assertNotIn('PASS', result.values())


if __name__ == '__main__':
    unittest.main()
