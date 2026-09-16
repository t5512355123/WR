from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4m_first_loss_full_rotation as audit  # noqa: E402


def _u32(value: int) -> str:
    return f"0x{value & 0xFFFFFFFF:08X}"


def _frame(page: int, sample: int) -> list[int]:
    phase_updates = 100 + sample
    words = [0] * 34
    words[0] = 2000 + sample * 2
    words[1] = 0x46344C31
    words[2] = 1 | (page << 8)
    words[3] = 4000 + sample * 2
    words[4] = 8000 + sample
    words[5] = 1
    words[6] = 0x00010000
    words[7] = 2 | ((1 | (1 << 5) | (1 << 6)) << 8)
    words[8] = 10 + sample
    words[9] = (-3) & 0xFFFFFFFF
    words[10] = 20 + sample
    words[11] = 30000
    words[12] = 0
    words[13] = 1000 + sample
    words[14] = 50 + sample
    words[15] = phase_updates
    words[16] = 0x0100
    if page == 0:
        words[17] = phase_updates
        words[18] = phase_updates
        words[19] = 0
        words[20] = phase_updates - 1
        words[27] = phase_updates
    elif page == 1:
        words[25] = words[14]
        words[26] = words[15]
        words[17] = 500 + sample
        words[19] = -100 - sample
        words[21] = 500 + sample
        words[23] = -100 - sample
    else:
        words[17] = phase_updates
    return words


def _main_line(page: int, sample: int) -> str:
    words = _frame(page, sample)
    raw = " ".join(f"F4L_W{i:02d}_RAW={_u32(word)}" for i, word in enumerate(words))
    return (
        "STEP5_F4M_MAIN_DIAG board=DE5_SLAVE cycle={} elapsed_ms={} "
        "host_end_ms={} MAIN_F4L_VALID=1 PUBLICATION_EPOCH_RAW_BEFORE={} "
        "PUBLICATION_EPOCH_RAW_AFTER={} {}"
    ).format(sample * 3 + page, sample * 1500 + page, sample * 1500 + page,
             _u32(words[0]), _u32(words[0]), raw)


def _page_line(page: int, sample: int, counts: list[int]) -> str:
    previous = "INVALID" if sample == 0 and page == 0 else (page - 1) % 3
    expected = page
    return (
        "STEP5_F4M_PAGE_OBSERVATION board=DE5_SLAVE elapsed_ms={} "
        "current_page={} previous_page={} expected_page={} "
        "page_publish_count_0={} page_publish_count_1={} page_publish_count_2={} "
        "page_due_count_0=8 page_due_count_1=8 page_due_count_2=8 "
        "page_skip_count_0=0 page_skip_count_1=0 page_skip_count_2=0 "
        "page2_due_count=8 page2_skip_count=0 page_rotation_count={} "
        "source_epoch={} update_id={} init_generation=1 "
        "semantics=UNIQUE_COHERENT_READER_OBSERVATION"
    ).format(sample * 1500 + page, page, previous, expected, *counts,
             max(0, sample * 3 + page), 4000 + sample * 2,
             8000 + sample)


def _complete_log() -> str:
    lines: list[str] = []
    counts = [0, 0, 0]
    rotation = 0
    for sample in range(24):
        for page in range(3):
            counts[page] += 1
            if sample or page:
                rotation += 1
            lines.append(_main_line(page, sample))
            lines.append(_page_line(page, sample, counts))
        lines.append(
            "STEP5_F4M_CYCLE board=DE5_SLAVE cycle={} elapsed_ms={} "
            "MAIN_F4L_VALID=1 MAIN_F4L_UPDATE_ID={} HELPER_CORE_VALID=1 "
            "HELPER_LOCKED=1 HELPER_RESIDUAL_PRESENT=1".format(
                sample + 1, sample * 1500, 8000 + sample
            )
        )
    lines.append(
        "STEP5_F4M_FIRST_LOSS_SAMPLE role=SLAVE board=DE5_SLAVE cycle=24 "
        "elapsed_ms=36000 trace_valid=1 SLOCK_STAGE=4 SLOCK_REMAINING_MS=0 "
        "SLOCK_MAGIC_RAW=5752534C MAIN_F4L_VALID=1 MAIN_F4L_UPDATE_ID=8023 "
        "HELPER_LOCKED=1 WR_TERMINAL=1 L2_FIRST_LOSS_VALID=1"
    )
    lines.append(
        "STEP5_F4M_CONFIG read_only_observer=1 one_reader=1 no_control_write=1 "
        "no_helper_pi_snapshot=1 no_rtl_or_sdb_change=1 "
        "control_parameters_unchanged=1"
    )
    lines.append(
        "STEP5_F4M_DONE session_elapsed_ms=36000 STOP_REASON=WR_SESSION_ENDED"
    )
    return "\n".join(lines) + "\n"


def test_full_rotation_and_first_loss_is_diagnostic_pass_only() -> None:
    result = audit.analyze_text(_complete_log())
    assert result["classification"] == "DIAGNOSTIC_COMPLETE"
    assert result["diagnostic_pass"] is True
    assert result["step5_pass"] is False
    assert result["page_closure"] is True
    assert result["first_loss_trace_valid_count"] == 1
    assert result["page_count_matches_frame_rows"] is True


def test_missing_page2_is_inconclusive_even_with_first_loss() -> None:
    text = "\n".join(
        line for line in _complete_log().splitlines()
        if not ("STEP5_F4M_MAIN_DIAG" in line and "PAGE=2" in line)
    )
    # The raw payload carries the page in F4L_W02; remove the actual page-2
    # rows explicitly because the fixture line does not repeat PAGE=2.
    lines = []
    for line in text.splitlines():
        if "STEP5_F4M_MAIN_DIAG" in line and "F4L_W02_RAW=0x00000201" in line:
            continue
        if "STEP5_F4M_PAGE_OBSERVATION" in line and "current_page=2" in line:
            continue
        lines.append(line)
    result = audit.analyze_text("\n".join(lines) + "\n")
    assert result["diagnostic_pass"] is False
    assert result["page_closure"] is False


def test_observer_contract_is_required() -> None:
    result = audit.analyze_text(_complete_log().replace(
        "no_control_write=1", "no_control_write=0", 1
    ))
    assert result["observer_contract_ok"] is False
    assert result["diagnostic_pass"] is False
