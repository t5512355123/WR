from pathlib import Path

from scripts.analysis.step6_digital_milestone_closure import audit


ROOT = Path(__file__).parents[2]


def test_closure_audit_passes_existing_evidence() -> None:
    result = audit(ROOT)
    assert result["result"] == "PASS_STEP6_DIGITAL_MILESTONE_CLOSURE"
    assert result["verdict"] == "PASS"
    assert result["gap_count"] == 0
    assert result["contradiction_count"] == 0
    assert result["step6_physical_pps_baseline"] == "NOT_EVALUATED"
    assert result["step6b_physical_scheduled_trigger_edge"] == "NOT_EVALUATED"


def test_closure_audit_is_read_only_contract() -> None:
    result = audit(ROOT)
    contract = result["hardware_contract"]
    assert all(contract[key] == "NO" for key in ("hardware_access", "compile", "program", "reset", "ptp_restart", "power_cycle", "target_write", "arm_write"))
    assert contract["physical_claim"] == "NOT_EVALUATED"
