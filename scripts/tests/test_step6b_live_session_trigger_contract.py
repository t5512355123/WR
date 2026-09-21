from pathlib import Path


TCL = Path(__file__).parents[1] / "jtag" / "read_step6b_digital_scheduled_dual_board_trigger.tcl"
RUNNER = (
    Path(__file__).parents[1]
    / "experiment"
    / "run_step6b_digital_scheduled_dual_board_trigger_live_session.sh"
)
PLAN = (
    Path(__file__).parents[2]
    / "docs"
    / "experiments"
    / "exp-step6-global-time"
    / "EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-LIVE-SESSION-20260922"
    / "PLAN.md"
)
HARNESS = Path(__file__).with_name("step6b_live_session_tcl_parse_harness.tcl")


def test_runner_does_not_program_or_compile() -> None:
    text = RUNNER.read_text(encoding="utf-8")
    assert "quartus_pgm" not in text
    assert "MASTER_PROGRAM=NO" in text
    assert "SLAVE_PROGRAM=NO" in text
    assert "__S6B_LIVE_SESSION__" in text


def test_live_tcl_has_exact_write_order_and_no_recovery_path() -> None:
    text = TCL.read_text(encoding="utf-8")
    live = text.split("proc s6b_live_session_run", 1)[1].split("proc s6b_run", 1)[0]
    assert "s6b_restart_slave_ptp" not in live
    assert "s6b_write_source $master_hardware MASTER 67" in live
    assert "s6b_write_source $slave_hardware SLAVE 67" in live
    assert "s6b_write_source $master_hardware MASTER 68" in live
    assert "s6b_write_source $slave_hardware SLAVE 68" in live
    assert live.index("s6b_write_source $master_hardware MASTER 67") < live.index(
        "s6b_write_source $slave_hardware SLAVE 67"
    )
    assert live.index("s6b_write_source $slave_hardware SLAVE 67") < live.index(
        "s6b_write_source $master_hardware MASTER 68"
    )
    assert live.index("s6b_write_source $master_hardware MASTER 68") < live.index(
        "s6b_write_source $slave_hardware SLAVE 68"
    )
    assert "s6b_live_emit_result" in live
    assert "S6B_LIVE_DONE" in text


def test_plan_requires_no_program_and_exact_target_cycles() -> None:
    text = PLAN.read_text(encoding="utf-8")
    assert "MASTER/SLAVE PROGRAM = NO" in text
    assert "TARGET_CYCLES = 62500000" in text
    assert "PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER" in text


def test_quartus_parse_harness_is_present() -> None:
    text = HARNESS.read_text(encoding="utf-8")
    assert "__S6B_LIVE_SESSION__" in text
    assert "STEP6B_LIVE_TCL_PARSE=PASS" in text
