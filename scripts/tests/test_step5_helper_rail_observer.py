from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OBSERVER = ROOT / "scripts" / "jtag" / "read_step5_helper_pi_state_rail_audit.tcl"


def test_helper_observer_matches_current_frozen_helper_contract() -> None:
    source = OBSERVER.read_text(encoding="utf-8")
    assert "set PI_KP -2250" in source
    assert "set PI_KI -2" in source
    assert "set PI_SHIFT 12" in source
    assert "set PI_BIAS 5" in source
    assert "set PI_Y_MIN 5" in source
    assert "set PI_Y_MAX 65531" in source
    assert "set PI_LOCK_THRESHOLD 2000" in source
    assert "set PI_LOCK_SAMPLES 1000" in source
    assert "set experiment_name EXP-S5-HELPER-STARTUP-RAIL-DIAGNOSTIC-LANE0-20260919" in source
    assert "control_write=0" in source
    assert "diagnostic_request_writes=1" in source
    assert "kp=-150" not in source
    assert "ki=-1" not in source


def test_only_diagnostic_snapshot_request_registers_are_written() -> None:
    source = OBSERVER.read_text(encoding="utf-8")
    writes = [line.strip() for line in source.splitlines()
              if "wb_write $hardware_name" in line]
    assert writes
    assert all(
        "0x0010042C" in line or "0x00100428" in line
        for line in writes
    )
