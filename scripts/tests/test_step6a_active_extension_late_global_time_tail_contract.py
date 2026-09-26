from pathlib import Path
import re


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


def _tcl_proc_body(text: str, proc_name: str) -> str:
    """Return one Tcl proc without accidentally including later procedures."""
    start = re.search(rf"(?m)^proc\s+{re.escape(proc_name)}\s+", text)
    assert start is not None, f"missing Tcl procedure: {proc_name}"
    next_proc = re.search(r"(?m)^proc\s+", text[start.end() :])
    end = start.end() + next_proc.start() if next_proc else len(text)
    return text[start.start() : end]


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
    late_tail = _tcl_proc_body(text, "s6a_late_tail_run")
    assert "s6b_write_source" not in late_tail
    assert "s6b_restart_slave_ptp" not in late_tail
    assert "S6A_TAIL_RESULT" in late_tail


def test_plan_forbids_programming_and_recovery_writes() -> None:
    plan = (
        Path(__file__).parents[2]
        / "experiments"
        / "step6"
        / "EXP-S6A-ACTIVE-EXTENSION-LATE-GLOBAL-TIME-TAIL-20260922"
        / "PLAN.md"
    ).read_text(encoding="utf-8")
    assert "MASTER/SLAVE PROGRAM = NO" in plan
    assert "MASTER/SLAVE PTP RESTART = NO" in plan
    assert "FAIL_ACTIVE_EXTENSION_GLOBAL_TIME_STUCK" in plan
