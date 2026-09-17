from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4s_producer_schedule as audit  # noqa: E402


def _u32(value: int) -> str:
    return f"0x{value & 0xFFFFFFFF:08X}"


def _schedule(cycle: int, page: int, *, enabled: int = 1, rise: int = 1,
              fall: int = 0, advance: int = 4, reset: int = 0,
              due: int = 0, publish: int = 0) -> str:
    sequence = 2 * cycle
    words = [
        audit.SCHEDULE_MAGIC,
        sequence,
        (enabled & 1) | ((page & 0x3) << 8) | ((rise & 0xFFFF) << 16),
        fall,
        advance,
        reset,
        due,
        publish,
    ]
    raw = " ".join(f"F4S_W{i:02d}_RAW={_u32(word)}" for i, word in enumerate(words))
    return (
        f"STEP5_F4S_MAIN_SCHEDULE board=DE5_SLAVE cycle={cycle} "
        f"elapsed_ms={cycle * 2000} host_end_ms={cycle * 2000} "
        "SCHEDULE_VALID=1 "
        f"SEQUENCE_RAW_BEFORE={_u32(sequence)} "
        f"SEQUENCE_RAW_AFTER={_u32(sequence)} {raw}"
    )


def _page(cycle: int, page: int) -> str:
    return (
        f"STEP5_F4S_MAIN_DIAG board=DE5_SLAVE cycle={cycle} "
        f"elapsed_ms={cycle * 2000} host_end_ms={cycle * 2000} "
        f"MAIN_F4L_VALID=1 PAGE={page}"
    )


def _log(*, pages: list[int], due: int = 0, publish: int = 0,
         fall: int = 0, reset: int = 0) -> str:
    lines: list[str] = []
    for cycle in range(1, 5):
        page = pages[(cycle - 1) % len(pages)]
        lines.append(_schedule(cycle, page, due=due, publish=publish,
                               fall=fall, reset=reset,
                               advance=cycle))
        lines.append(_page(cycle, page))
    lines.append("STEP5_F4S_CONFIG main_schedule_magic=0x46345331")
    lines.append("STEP5_F4S_DONE STOP_REASON=NONE")
    return "\n".join(lines) + "\n"


def test_main_enable_discontinuity_is_classified() -> None:
    result = audit.analyze_text(_log(pages=[0, 1], fall=1, reset=1))
    assert result["classification"] == "F4S_MAIN_ENABLE_DISCONTINUITY"
    assert result["diagnostic_pass"] is True
    assert result["step5_pass"] is False


def test_page2_not_scheduled_is_classified() -> None:
    result = audit.analyze_text(_log(pages=[0, 1]))
    assert result["classification"] == "F4S_PAGE2_NOT_SCHEDULED"


def test_page2_due_but_not_published_is_classified() -> None:
    result = audit.analyze_text(_log(pages=[0, 1], due=1, publish=0))
    assert result["classification"] == "F4S_PAGE2_DUE_BUT_NOT_PUBLISHED"


def test_page2_published_but_not_observed_is_classified() -> None:
    result = audit.analyze_text(_log(pages=[0, 1], due=1, publish=1))
    assert result["classification"] == "F4S_PAGE2_PUBLISHED_BUT_NOT_OBSERVED"


def test_full_rotation_is_diagnostic_pass_but_not_step5() -> None:
    result = audit.analyze_text(_log(pages=[0, 1, 2], due=1, publish=1))
    assert result["classification"] == "F4S_FULL_PAGE_ROTATION"
    assert result["diagnostic_pass"] is True
    assert result["step5_pass"] is False


def test_source_uses_existing_read_only_schedule_shadow() -> None:
    task_diags = (ROOT / "vendor" / "wrpc-sw" / "lib" / "task-diags.c").read_text(
        encoding="utf-8"
    )
    observer = (
        ROOT / "scripts" / "jtag" /
        "read_step5_main_frequency_prelock_observability.tcl"
    ).read_text(encoding="utf-8")
    assert "wdiags_write_wr_spll_main_f4l_schedule_debug" in task_diags
    assert "F4S_SCHEDULE_SCHEMA_NOT_READY" in observer
    assert "no_rtl_or_sdb_change=1" in observer
