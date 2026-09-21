from __future__ import annotations

import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "analysis" / "step6b_timing_query_boundary_correction.py"
SPEC = importlib.util.spec_from_file_location("step6b_timing_analyzer", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


GROUPS = sorted(MODULE.GROUPS)


def _report(path: Path, result: str = "PASS_STEP6B_POSTFIT_TIMING_PROVEN", negative: bool = False) -> None:
    lines = []
    for group in GROUPS:
        for kind in ("setup", "hold"):
            slack = "-0.125" if negative and kind == "setup" else "0.125"
            lines.append(
                f"STEP6B_TIMING_PATH name={group} type={kind} status=PASS count=1 "
                f"slack_ns={slack} from=launch to=destination "
                "from_clock=qsfp_ref_125m to_clock=qsfp_ref_125m path_type=setup error="
            )
    lines.append(f"STEP6B_TIMING_RESULT={result} REASON=")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def test_all_nine_groups_on_both_boards_pass(tmp_path: Path) -> None:
    timing = tmp_path / "timing"
    timing.mkdir()
    _report(timing / "slave_step6b_timing.txt")
    _report(timing / "master_step6b_timing.txt")
    result = MODULE.analyze_directory(timing)
    assert result["classification"] == "PASS_STEP6B_POSTFIT_TIMING_PROVEN"
    assert result["verdict"] == "PASS"


def test_negative_slack_is_not_proven_pass(tmp_path: Path) -> None:
    timing = tmp_path / "timing"
    timing.mkdir()
    _report(timing / "slave_step6b_timing.txt", negative=True)
    _report(timing / "master_step6b_timing.txt")
    result = MODULE.analyze_directory(timing)
    assert result["classification"] == "NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED"


def test_missing_group_is_unresolved(tmp_path: Path) -> None:
    timing = tmp_path / "timing"
    timing.mkdir()
    _report(timing / "slave_step6b_timing.txt")
    _report(timing / "master_step6b_timing.txt")
    text = (timing / "master_step6b_timing.txt").read_text(encoding="utf-8")
    text = "\n".join(line for line in text.splitlines() if "refclk_to_fired" not in line) + "\n"
    (timing / "master_step6b_timing.txt").write_text(text, encoding="utf-8")
    result = MODULE.analyze_directory(timing)
    assert result["classification"] == "NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED"
