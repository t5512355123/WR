from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _define(path: Path, name: str) -> int | None:
    match = re.search(rf"^#define\s+{re.escape(name)}\s+(-?\d+)\s*$",
                      path.read_text(encoding="utf-8"), re.MULTILINE)
    return int(match.group(1)) if match else None


class F4KConfigurationTests(unittest.TestCase):
    def test_identity_headers_keep_legacy_candidate_disabled(self) -> None:
        for name in ("de5a_master_identity.h", "de5a_slave_identity.h"):
            value = _define(ROOT / "firmware" / "configs" / name,
                            "DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE")
            self.assertEqual(value, 0, name)

    def test_identity_kp_is_an_approved_arm_value(self) -> None:
        master = _define(ROOT / "firmware" / "configs" / "de5a_master_identity.h",
                         "DE5A_MAIN_PI_KP_OVERRIDE")
        slave = _define(ROOT / "firmware" / "configs" / "de5a_slave_identity.h",
                        "DE5A_MAIN_PI_KP_OVERRIDE")
        self.assertEqual(master, 300)
        self.assertIn(slave, (300, 600))

    def test_main_control_uses_only_the_independent_kp_override(self) -> None:
        source = (ROOT / "vendor" / "wrpc-sw" / "softpll" / "spll_main.c").read_text(
            encoding="utf-8"
        )
        self.assertIn("s->pi.kp = DE5A_MAIN_PI_KP_OVERRIDE;", source)
        self.assertIn("s->pi.ki = 1;", source)
        self.assertIn("#define MPLL_FREQ_PRELOCK_GAIN_BOOST 20", source)
        self.assertIn("F4K Main Kp override cannot be combined", source)
        self.assertIn("s->pi.ki = 1;", source.split("#elif defined(CONFIG_WR_NODE)", 1)[1])

    def test_f4j_arm_metadata_does_not_change_reader_schema(self) -> None:
        observer = (ROOT / "scripts" / "jtag" /
                    "read_step5_main_frequency_prelock_observability.tcl").read_text(
                        encoding="utf-8"
                    )
        self.assertIn("f4k_arm", observer)
        self.assertIn("functional_experiment_scope", observer)
        self.assertIn("main_producer_window=0x00100B58..0x00100BDC", observer)
        self.assertIn("no_helper_pi_snapshot=1", observer)
        self.assertIn("no_debug_fifo_drain=1", observer)


if __name__ == "__main__":
    unittest.main()
