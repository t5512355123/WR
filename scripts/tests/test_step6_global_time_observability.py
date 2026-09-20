from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "experiment" / "step6_global_time_observability.py"
SPEC = importlib.util.spec_from_file_location("step6_global_time_observability", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _sample(sample: int, count: int, tai: int, cycles: int,
            live_cycles: int, *, raw_before: int | None = None) -> str:
    if raw_before is None:
        raw_before = 0x1
    raw_after = raw_before
    return (
        "GLOBAL_TIME_SAMPLE board=DE5 sample={sample} elapsed_ms={elapsed} "
        "RAW_LIVE=0 RAW0=0 RAW1_BEFORE={before:X} RAW1_AFTER={after:X} "
        "STABLE=1 SNAPSHOT_VALID=1 SNAPSHOT_TIME_VALID=1 "
        "SNAPSHOT_PPS_VALID=1 SNAPSHOT_COUNT={count} TAI={tai} "
        "CYCLES={cycles} LIVE_TAI_LO={tai} LIVE_CYCLES={live_cycles} "
        "STATUS_RAW=0 STATUS_TIME_VALID=1 STATUS_PPS_VALID=1"
    ).format(
        sample=sample,
        elapsed=sample * 250,
        before=raw_before,
        after=raw_after,
        count=count,
        tai=tai,
        cycles=cycles,
        live_cycles=live_cycles,
    )


def test_valid_global_time_capture_is_pass() -> None:
    period_minus_one = 125_000_000 - 1
    text = "\n".join([
        _sample(0, 1, 100, period_minus_one, 10_000_000),
        _sample(1, 1, 100, period_minus_one, 40_000_000),
        _sample(2, 2, 101, period_minus_one, 80_000_000),
        _sample(3, 2, 101, period_minus_one, 124_999_500),
        _sample(4, 3, 102, period_minus_one, 5),
    ])
    result = MODULE.analyze_text(text)
    assert result["classification"] == "GLOBAL_TIME_COUNTER_VALID"
    assert result["diagnostic_pass"] is True
    assert result["cycles_monotonic"] is True
    assert result["cycles_wrap"] is True
    assert result["tai_increment_at_wrap"] is True


def test_unstable_atomic_read_is_not_accepted() -> None:
    line = _sample(0, 1, 100, 125_000_000 - 1, 1)
    line = line.replace("STABLE=1", "STABLE=0")
    result = MODULE.analyze_text(line)
    assert result["classification"] == "ATOMIC_SNAPSHOT_UNSTABLE"
    assert result["diagnostic_pass"] is False


def test_sequential_boards_without_shared_tai_are_inconclusive() -> None:
    master = "\n".join([
        _sample(0, 1, 100, 125_000_000 - 1, 10_000_000),
        _sample(1, 2, 101, 125_000_000 - 1, 10_000_000),
    ])
    slave = "\n".join([
        _sample(0, 1, 200, 125_000_000 - 1, 10_000_000),
        _sample(1, 2, 201, 125_000_000 - 1, 10_000_000),
    ])
    result = MODULE.compare_board_texts(master, slave)
    assert result["classification"] == "INCONCLUSIVE_NO_SHARED_TAI"
    assert result["same_boundary_evidence"] is False


def test_source_contract_is_observation_only_and_step6b_is_absent() -> None:
    master = (ROOT / "quartus" / "jtag_runtime_diag" / "DE5a_wr_master_jtag.vhd").read_text(
        encoding="utf-8"
    )
    slave = (ROOT / "quartus" / "jtag_runtime_diag" / "DE5a_wr_slave_jtag.vhd").read_text(
        encoding="utf-8"
    )
    for source in (master, slave):
        assert "tm_tai_o                   => open" not in source
        assert "tm_cycles_o                => open" not in source
        assert "pps_csync_o                => open" not in source
        assert "sld_instance_index      => 62" in source
        assert "sld_instance_index      => 63" in source
        assert "sld_instance_index      => 64" in source
        assert "p_global_time_snapshot" in source
        assert "global_time_snapshot_count" in source
    assert "global_time_trigger" not in master.lower()
    assert "global_time_trigger" not in slave.lower()
