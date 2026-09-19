from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _define(path: Path, name: str) -> int | None:
    match = re.search(
        rf"^#define\s+{re.escape(name)}\s+(-?\d+)\s*$",
        path.read_text(encoding="utf-8"),
        re.MULTILINE,
    )
    return int(match.group(1)) if match else None


def test_threshold20_is_slave_identity_only() -> None:
    slave = ROOT / "firmware" / "configs" / "de5a_slave_identity.h"
    master = ROOT / "firmware" / "configs" / "de5a_master_identity.h"
    assert _define(slave, "DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE") == 20
    assert _define(master, "DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE") is None


def test_threshold20_is_scoped_to_slave_main_and_default_stays_50() -> None:
    source = (ROOT / "vendor" / "wrpc-sw" / "softpll" / "spll_main.c").read_text(
        encoding="utf-8"
    )
    assert "s->freq_ld.threshold = 50;" in source
    assert "#if defined(CONFIG_WR_NODE) && defined(DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE)" in source
    assert "if (s->dac_index == 0)" in source
    assert "s->freq_ld.threshold = DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE;" in source
    assert "DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE must be in the range 1..50" in source


def test_threshold20_does_not_change_other_frozen_identity_values() -> None:
    identity = (ROOT / "firmware" / "configs" / "de5a_slave_identity.h").read_text(
        encoding="utf-8"
    )
    assert "DE5A_MAIN_PI_KP_OVERRIDE 300" in identity
    assert "DE5A_MAIN_PHASE_PI_KI_ZERO 1" in identity
    assert "DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD 1" in identity
    assert "DE5A_F4L_MAIN_PHASE_DIAG 0" in identity
