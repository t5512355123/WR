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


def test_f4l_owner_is_enabled_on_both_threshold20_identities() -> None:
    master = ROOT / "firmware" / "configs" / "de5a_master_identity.h"
    slave = ROOT / "firmware" / "configs" / "de5a_slave_identity.h"

    assert _define(master, "DE5A_F4L_MAIN_PHASE_DIAG") == 1
    assert _define(slave, "DE5A_F4L_MAIN_PHASE_DIAG") == 1
    assert _define(slave, "DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE") == 20
    assert _define(master, "DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE") is None


def test_f4l_owner_change_keeps_control_identity_frozen() -> None:
    for name in ("de5a_master_identity.h", "de5a_slave_identity.h"):
        identity = (ROOT / "firmware" / "configs" / name).read_text(
            encoding="utf-8"
        )
        assert "DE5A_MAIN_PI_KP_OVERRIDE 300" in identity
        assert "DE5A_MAIN_PHASE_PI_KI_ZERO 1" in identity
        assert "DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD 1" in identity
