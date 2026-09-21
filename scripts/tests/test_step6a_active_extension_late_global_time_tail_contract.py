from pathlib import Path


SCRIPT = (
    Path(__file__).parents[1]
    / "experiment"
    / "run_step6a_active_extension_late_global_time_tail.sh"
)
TCL = (
    Path(__file__).parents[1]
    / "jtag"
    / "read_step6b_digital_scheduled_dual_board_trigger.tcl"
)


def test_late_tail_runner_is_read_only() -> None:
    text = SCRIPT.read_text(encoding="utf-8")
    assert "quartus_pgm" not in text
    assert "MASTER_PROGRAM=NO" in text
    assert "SLAVE_PROGRAM=NO" in text
    assert "TARGET_WRITE=NO" in text
    assert "ARM_WRITE=NO" in text
    assert "45000" in text


def test_late_tail_mode_has_no_write_or_restart_path() -> None:
    text = TCL.read_text(encoding="utf-8")
    assert "__S6A_LATE_TAIL__" in text
    assert "proc s6a_late_tail_run" in text
    late_tail = text.split("proc s6a_late_tail_run", 1)[1].split("proc s6b_run", 1)[0]
    assert "s6b_write_source" not in late_tail
    assert "s6b_restart_slave_ptp" not in late_tail
    assert "S6A_TAIL_RESULT" in late_tail


def test_plan_forbids_programming_and_recovery_writes() -> None:
    plan = (
        Path(__file__).parents[2]
        / "docs"
        / "experiments"
        / "exp-step6-global-time"
        / "EXP-S6A-ACTIVE-EXTENSION-LATE-GLOBAL-TIME-TAIL-20260922"
        / "PLAN.md"
    ).read_text(encoding="utf-8")
    assert "MASTER/SLAVE PROGRAM = NO" in plan
    assert "MASTER/SLAVE PTP RESTART = NO" in plan
    assert "FAIL_ACTIVE_EXTENSION_GLOBAL_TIME_STUCK" in plan
