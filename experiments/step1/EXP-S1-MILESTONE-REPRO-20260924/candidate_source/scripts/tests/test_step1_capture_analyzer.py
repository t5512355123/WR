import unittest

from scripts.analysis.analyze_step1_capture import analyze


GOOD_WORD = (1 << 15) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 6) | (1 << 7) | (1 << 32)


def make_capture(master_word=GOOD_WORD, slave_word=GOOD_WORD):
    lines = []
    for board, word in (("DE5 [1-11.1]", master_word), ("DE5 [1-11.2]", slave_word)):
        for n in range(1, 302):
            lines.append(
                f'STEP1_SAMPLE board="{board}" n={n:04d} '
                f"elapsed_ms={(n - 1) * 101} read_ok=1 raw={word:016X}"
            )
    return "\n".join(lines)


class Step1CaptureAnalyzerTests(unittest.TestCase):
    def test_two_healthy_boards_pass(self):
        verdict, lines = analyze(make_capture())
        self.assertEqual(verdict, "PASS")
        self.assertEqual(sum("verdict=PASS" in line for line in lines), 2)

    def test_missing_core_link_fails(self):
        verdict, lines = analyze(make_capture(slave_word=GOOD_WORD & ~(1 << 3)))
        self.assertEqual(verdict, "FAIL")
        self.assertTrue(any("role=SLAVE" in line and "CORE_LINK_OK:301" in line for line in lines))

    def test_short_transient_encoding_error_is_reported_but_not_persistent(self):
        lines = make_capture().splitlines()
        lines[20] = lines[20].replace(f"raw={GOOD_WORD:016X}", f"raw={(GOOD_WORD | (1 << 34)):016X}")
        verdict, summary = analyze("\n".join(lines))
        self.assertEqual(verdict, "PASS")
        self.assertTrue(any("transient_error_samples=1" in line for line in summary))

    def test_persistent_encoding_error_fails(self):
        lines = make_capture().splitlines()
        for index in range(301, 307):
            lines[index] = lines[index].replace(f"raw={GOOD_WORD:016X}", f"raw={(GOOD_WORD | (1 << 35)):016X}")
        verdict, summary = analyze("\n".join(lines))
        self.assertEqual(verdict, "FAIL")
        self.assertTrue(any("max_consecutive_error_samples=6" in line for line in summary))

    def test_too_short_capture_is_inconclusive(self):
        lines = []
        for board in ("DE5 [1-11.1]", "DE5 [1-11.2]"):
            for n in range(1, 50):
                lines.append(
                    f'STEP1_SAMPLE board="{board}" n={n:04d} '
                    f"elapsed_ms={(n - 1) * 100} read_ok=1 raw={GOOD_WORD:016X}"
                )
        verdict, _ = analyze("\n".join(lines))
        self.assertEqual(verdict, "INCONCLUSIVE")


if __name__ == "__main__":
    unittest.main()
