from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "experiment" / "step5_jtag_image_contract.py"
SPEC = importlib.util.spec_from_file_location("jtag_image_contract", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def test_current_jtag_image_contract_passes() -> None:
    result = MODULE.analyze(ROOT)
    assert result["classification"] == "PASS"
    assert result["image_contract_pass"] is True
    assert len(result["checks"]) == 9


def test_missing_mailbox_contract_is_rejected() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        qsf = root / "quartus" / "jtag_runtime_diag"
        qsf.mkdir(parents=True)
        (qsf / "DE5a_wr_master_jtag.qsf").write_text(
            "set_global_assignment -name VHDL_FILE DE5a_wr_master_jtag.vhd\n",
            encoding="utf-8",
        )
        result = MODULE.analyze(root)
        assert result["classification"] == "IMAGE_CONTRACT_INVALID"
        assert result["image_contract_pass"] is False


def test_contract_audit_is_offline_only() -> None:
    result = MODULE.analyze(ROOT)
    assert result["hardware_inspected"] is False
    assert result["production_c_or_rtl_modified"] is False
    assert result["step5_pass"] is False

