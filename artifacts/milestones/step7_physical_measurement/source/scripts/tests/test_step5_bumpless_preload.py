from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))


def _preload(previous_output: int, phase_error: int, kp: int, ki: int,
             shift: int, bias: int) -> int:
    """Mirror the fixed-point preload before the first pi_update call."""

    return ((previous_output - bias) << shift) - kp * phase_error - ki * phase_error


def _pi_update_from_preload(integrator: int, phase_error: int, kp: int,
                            ki: int, shift: int, bias: int) -> int:
    i_new = integrator + ki * phase_error
    y_preround = i_new + phase_error * kp + (1 << (shift - 1))
    return (y_preround >> shift) + bias


def test_preload_preserves_the_first_phase_output() -> None:
    previous_output = 10479
    phase_error = -6464
    kp = 300
    ki = 1
    shift = 12
    bias = 32768
    integrator = _preload(previous_output, phase_error, kp, ki, shift, bias)
    assert _pi_update_from_preload(
        integrator, phase_error, kp, ki, shift, bias
    ) == previous_output


def test_preload_is_fixed_point_and_not_a_plain_integrator_copy() -> None:
    previous_output = 11540
    phase_error = 5980
    kp = 300
    ki = 1
    shift = 12
    bias = 32768
    preload = _preload(previous_output, phase_error, kp, ki, shift, bias)
    plain_copy_output = _pi_update_from_preload(
        previous_output, phase_error, kp, ki, shift, bias
    )
    assert preload != previous_output
    assert _pi_update_from_preload(
        preload, phase_error, kp, ki, shift, bias
    ) == previous_output
    assert plain_copy_output != previous_output


def test_source_gates_preload_to_main_frequency_to_phase_transition() -> None:
    source = (
        ROOT / "vendor" / "wrpc-sw" / "softpll" / "spll_main.c"
    ).read_text(encoding="utf-8")
    assert "DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD" in source
    assert "s->dac_index == 0 && s->freq_ld.lock_changed" in source
    assert "s->freq_ld.locked" in source
    assert "mpll_preload_phase_integrator(s, err);" in source
    assert "s->pi.y" in source
    assert "s->pi.bias" in source
    assert "s->pi.shift" in source
    assert "s->pi.kp" in source
    assert "s->pi.ki" in source
    for name in ("de5a_master_identity.h", "de5a_slave_identity.h"):
        identity = (ROOT / "firmware" / "configs" / name).read_text(
            encoding="utf-8"
        )
        assert "DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD 1" in identity


if __name__ == "__main__":
    test_preload_preserves_the_first_phase_output()
    test_preload_is_fixed_point_and_not_a_plain_integrator_copy()
    test_source_gates_preload_to_main_frequency_to_phase_transition()
    print("test_step5_bumpless_preload: PASS")
