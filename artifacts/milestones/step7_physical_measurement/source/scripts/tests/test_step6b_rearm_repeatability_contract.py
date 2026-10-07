from pathlib import Path


ROOT = Path(__file__).parents[2]
TCL = ROOT / "scripts" / "jtag" / "read_step6b_rearm_repeatability.tcl"
RUNNER = ROOT / "scripts" / "experiment" / "run_step6b_rearm_repeatability.sh"
PLAN = (
    ROOT
    / "experiments"
    / "step6"
    / "EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-REARM-REPEATABILITY-20260922"
    / "PLAN.md"
)
HARNESS = ROOT / "scripts" / "tests" / "step6b_rearm_tcl_parse_harness.tcl"


def test_rearm_observer_and_runner_exist() -> None:
    assert TCL.exists()
    assert RUNNER.exists()
    assert PLAN.exists()
    assert HARNESS.exists()


def test_only_six_writes_are_encoded_in_order() -> None:
    text = TCL.read_text(encoding="utf-8")
    assert "s6b_write_source $master_hardware MASTER 68 0 1" in text
    assert "s6b_write_source $slave_hardware SLAVE 68 0 1" in text
    assert "s6b_write_source $master_hardware MASTER 67" in text
    assert "s6b_write_source $slave_hardware SLAVE 67" in text
    assert "s6b_write_source $master_hardware MASTER 68 1 1" in text
    assert "s6b_write_source $slave_hardware SLAVE 68 1 1" in text
    assert "ptp stop" not in TCL.read_text(encoding="utf-8")
    assert "quartus_pgm" not in RUNNER.read_text(encoding="utf-8")


def test_runner_contract_forbids_programming_and_power_cycle() -> None:
    text = RUNNER.read_text(encoding="utf-8")
    assert "MASTER_PROGRAM=NO" in text
    assert "SLAVE_PROGRAM=NO" in text
    assert "POWER_CYCLE=NO" in text
    assert "FUNCTIONAL_WRITE_COUNT_MAX=6" in text


def test_parse_harness_stops_before_hardware_access() -> None:
    text = HARNESS.read_text(encoding="utf-8")
    assert "proc get_hardware_names {} { return {} }" in text
    assert "STEP6B_REARM_TCL_PARSE=PASS" in text
