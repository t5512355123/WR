#!/usr/bin/env python3
"""Offline model check for the DE5a WR-servo phase acquisition step."""

import unittest


class Step6ServoHalfGainTests(unittest.TestCase):
    # Coherent adjacent-update pairs from the unchanged firmware, captured on
    # 2026-09-29.  Each tuple is (offset before action, offset after action,
    # setpoint delta); all values are picoseconds.
    OBSERVED_PAIRS = (
        (-2757, 2654, -2757),
        (2617, -2639, 2617),
    )

    def test_observed_full_step_reverses_offset_at_about_two_to_one(self):
        for before, after, setpoint_delta in self.OBSERVED_PAIRS:
            measured_delta = after - before
            gain = measured_delta / setpoint_delta
            self.assertLess(gain, -1.9)
            self.assertGreater(gain, -2.1)

    def test_half_gain_step_predicts_residual_inside_60ps_gate(self):
        for before, after, setpoint_delta in self.OBSERVED_PAIRS:
            measured_gain = (after - before) / setpoint_delta
            # C integer division in the firmware truncates toward zero.
            correction = int(before / 2)
            predicted = before + measured_gain * correction
            self.assertLessEqual(abs(predicted), 60)


if __name__ == "__main__":
    unittest.main()
