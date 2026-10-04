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

    def test_acquisition_reader_uses_structural_guard(self):
        text = row(0, 10, 5, 2400, 1000).replace('S6_INTERLEAVED_SAMPLE', 'S6_ACQ_SAMPLE')
        text = text.replace('PHASE_OBSERVATION_VALID=1', 'STRUCTURALLY_TRUSTED_ROW=1')
        result = analyze(text + '\nS6_ACQ_DONE')
        self.assertEqual(result['accepted_rows'], 1)
        self.assertTrue(result['has_reader_done'])

    def test_invalid_acquisition_frame_is_not_accepted(self):
        text = row(0, 10, 5, 2400, 1000).replace('S6_INTERLEAVED_SAMPLE', 'S6_ACQ_SAMPLE')
        text = text.replace('PHASE_OBSERVATION_VALID=1', 'STRUCTURALLY_TRUSTED_ROW=0')
        self.assertEqual(analyze(text)['accepted_rows'], 0)

    def test_coarse_time_not_used_as_fine_phase_distribution(self):
        result = analyze(row(0, 10, 1, 987654321, 1000))
        self.assertEqual(result['before_time_valid']['unique_phase_labelled_updates'], 0)

    def test_pre_and_post_valid_are_distinct(self):
        result = analyze(row(0, 10, 5, 2400, 1000) + '\n' +
                         row(1, 11, 4, 30, 1000, STATUS_TIME_VALID='1'))
        self.assertEqual(result['before_time_valid']['cko_min_ps'], 2400)
        self.assertEqual(result['after_time_valid']['strict_lt60_updates'], 1)
        self.assertEqual(result['first_accepted_time_valid_elapsed_ms'], 300)

    def test_normal_duration_stop_preserved_separately_from_errors(self):
        result = analyze('S6_ACQ_STOP STOP_REASON=DURATION_LIMIT\nS6_ACQ_DONE')
        self.assertEqual(len(result['acquisition_stop_lines']), 1)
        self.assertEqual(result['reader_error_lines'], [])

    def test_negative_converter_boundary_is_only_a_risk_flag(self):
        result = analyze(row(0, 10, 5, 2400, -131071) + '\n' +
                         row(1, 11, 5, 2400, -131072))
        self.assertEqual(result['negative_setpoint_signed32_product_overflow_updates'], 1)
        self.assertNotIn('root_cause', result)

    def test_observer_elapsed_not_confused_with_boot_or_total_elapsed(self):
        result = analyze(row(0, 10, 4, 30, 1000, STATUS_TIME_VALID='1',
                             TOTAL_ELAPSED_MS='159381', OBSERVER_PHASE='ACQUISITION'))
        self.assertEqual(result['first_accepted_time_valid_total_elapsed_ms'], 159381)
        self.assertEqual(result['first_accepted_time_valid_elapsed_ms'], 0)

    def test_phase_label_not_proof_coarse_adjustment_finished(self):
        result = analyze(row(0, 10, 3, 1070173867, 1000))
        self.assertTrue(result['phase_label_does_not_establish_coarse_time_settled'])
        self.assertIsNone(result['after_health_arming_phase_cko_ps']['min'])


if __name__ == '__main__':
    unittest.main()
