from pathlib import Path


SCRIPT = (
    Path(__file__).parents[1]
    / "experiment"
    / "run_step6b_digital_scheduled_dual_board_trigger.sh"
)


def test_v2_uses_direct_programming_only() -> None:
    text = SCRIPT.read_text(encoding="utf-8").lower()
    assert "sudo " not in text
    assert "program_method=direct_non_sudo" in text
    assert '"$quartus_pgm" -c \'de5 [1-11.2]\'' in text
    assert '"$quartus_pgm" -c \'de5 [1-11.1]\'' in text


def test_v2_requires_slave_then_master_success_signatures() -> None:
    text = SCRIPT.read_text(encoding="utf-8")
    assert "Using programming cable" in text
    assert "Configuration succeeded" in text
    assert "1 device(s) configured" in text
    assert "Successfully performed operation(s)" in text
    assert "MASTER_PROGRAM_COUNT=0" in text
    assert "SLAVE_PROGRAM_COUNT=1" in text


def test_v2_keeps_exact_fitted_artifact_gate() -> None:
    text = SCRIPT.read_text(encoding="utf-8")
    assert "EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-HARDWARE-RUN-V2-20260922" in text
    assert "c24568e383be3355ac8684b7d13f293115931586" in text
    assert "PASS_STEP6B_POSTFIT_TIMING_PROVEN" in text
