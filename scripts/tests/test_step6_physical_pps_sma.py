from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _load(name: str, relative: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


GATE = _load("gate", "scripts/analysis/step6_physical_pps_sma_gate.py")
SKEW = _load("skew", "scripts/analysis/step6_physical_pps_sma_skew.py")


def _gate_text() -> str:
    lines = ["S6A2_GATE_RESULT=PASS SAMPLES=3"]
    for sample, tai in enumerate((100, 101, 102)):
        for role in ("MASTER", "SLAVE"):
            lines.append(
                "S6A2_GATE_SAMPLE "
                f"ROLE={role} BOARD={role} SAMPLE={sample} READ_VALID=1 "
                "LINK_HEALTHY=1 CAPTURE_HEALTHY=1 RESET_CHANGED=0 "
                "STATUS_TIME_VALID=1 STATUS_PPS_VALID=1 SNAPSHOT_STABLE=1 "
                "SNAPSHOT_ACCEPTED=1 SNAPSHOT_VALID=1 SNAPSHOT_TIME_VALID=1 "
                "SNAPSHOT_PPS_VALID=1 STATUS_TM_LINK_UP=1 STATUS_LINK_OK=1 "
                "RX_PATTERN_READY=1 SNAPSHOT_CYCLES=10 "
                "BOOT_GENERATION=1 CPU_RESET_COUNT=1 WR_CORE_RESET_COUNT=1 "
                "SI_CONFIG_DROP_COUNT=1"
            )
        lines.append(
            f"S6A2_GATE_PAIR SAMPLE={sample} READ_VALID=1 MASTER_GATE=1 "
            f"SLAVE_GATE=1 MASTER_TAI={tai} SLAVE_TAI={tai} "
            "MASTER_CYCLES=10 SLAVE_CYCLES=10"
        )
    return "\n".join(lines)


def test_gate_requires_two_common_labels() -> None:
    result = GATE.analyze_text(_gate_text())
    assert result["verdict"] == "PASS"
    assert result["common_tai_count"] == 3


def test_gate_fails_without_common_labels() -> None:
    text = _gate_text()
    for tai in (100, 101, 102):
        text = text.replace(f"SLAVE_TAI={tai}", "SLAVE_TAI=999")
    result = GATE.analyze_text(text)
    assert result["verdict"] == "INCONCLUSIVE"


def test_scope_passes_one_tick() -> None:
    import tempfile

    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "scope.csv"
        path.write_text(
            "edge_index,delta_ns\n"
            + "\n".join(f"{index},{(index % 3) - 1}" for index in range(20))
            + "\n",
            encoding="utf-8",
        )
        result = SKEW.analyze_csv(path)
    assert result["verdict"] == "PASS"
    assert result["max_abs_delta_ns"] < 8


def test_scope_rejects_eight_ns_boundary() -> None:
    import tempfile

    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "scope.csv"
        path.write_text(
            "edge_index,delta_ns\n"
            + "\n".join(f"{index},8" for index in range(20))
            + "\n",
            encoding="utf-8",
        )
        result = SKEW.analyze_csv(path)
    assert result["verdict"] == "FAIL"
