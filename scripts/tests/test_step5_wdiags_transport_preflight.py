from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "experiment" / "step5_wdiags_transport_preflight.py"
SPEC = importlib.util.spec_from_file_location("wdiags_preflight", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def _write(tmp_path: Path, text: str) -> Path:
    path = tmp_path / "preflight.log"
    path.write_text(text, encoding="utf-8")
    return path


def _sample(board: str, label: str, valid: int = 1) -> str:
    return (
        "WDIAGS_MAP_SAMPLE "
        f"board={board} label={label} attempt=1 valid={valid} "
        "status=00000001 MAGIC_A=A5A5122C MAGIC_B=A5A51330 "
        "COUNTER=00000010 INVERSE=0000FFEF MODE_META=03010309 PTP=00000009"
    )


def test_pass_requires_both_boards_and_begin_end(tmp_path: Path) -> None:
    log = "\n".join(
        [
            "WDIAGS_MAP_CONFIG gap_ms=1000",
            _sample("DE5 [1-11.1]", "BEGIN"),
            _sample("DE5 [1-11.1]", "END"),
            "WDIAGS_MAP_RESULT board=DE5 [1-11.1] begin_valid=1 end_valid=1",
            _sample("DE5 [1-11.2]", "BEGIN"),
            _sample("DE5 [1-11.2]", "END"),
            "WDIAGS_MAP_RESULT board=DE5 [1-11.2] begin_valid=1 end_valid=1",
            "WDIAGS_MAP_DONE",
        ]
    )
    verdict = MODULE.analyze(_write(tmp_path, log))
    assert verdict["classification"] == "PASS"
    assert verdict["preflight_pass"] is True
    assert verdict["board_count"] == 2


def test_timeout_is_not_mapping_failure(tmp_path: Path) -> None:
    log = "\n".join(
        [
            "WDIAGS_MAP_SAMPLE board=DE5 [1-11.2] label=BEGIN attempt=1 valid=0 "
            "status=TIMEOUT MAGIC_A=TIMEOUT MAGIC_B=TIMEOUT COUNTER=TIMEOUT INVERSE=TIMEOUT",
            "WDIAGS_MAP_RESULT board=DE5 [1-11.2] begin_valid=0 end_valid=0",
        ]
    )
    verdict = MODULE.analyze(_write(tmp_path, log))
    assert verdict["classification"] == "TRANSPORT_TIMEOUT"
    assert verdict["preflight_pass"] is False


def test_completed_but_wrong_mapping_is_separate(tmp_path: Path) -> None:
    log = _sample("DE5 [1-11.2]", "BEGIN", valid=0) + "\nWDIAGS_MAP_DONE\n"
    log = log.replace("MAGIC_A=A5A5122C", "MAGIC_A=00000000")
    verdict = MODULE.analyze(_write(tmp_path, log))
    assert verdict["classification"] == "MAP_SEMANTICS_INVALID"
    assert verdict["transport_complete_rows"] == 1
    assert verdict["mapping_valid_rows"] == 0


def test_source_contract_mentions_established_selftest() -> None:
    observer = (ROOT / "scripts" / "jtag" / "read_wdiags_mapping_selftest.tcl").read_text(
        encoding="utf-8"
    )
    assert "proc wb_read" in observer
    assert "A5A5122C" in observer
    assert "A5A51330" in observer
    assert "WDIAGS_MAP_RESULT" in observer
