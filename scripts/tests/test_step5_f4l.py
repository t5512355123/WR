from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

import step5_f4l_main_phase_drift_integrator as audit  # noqa: E402


def _u32(value: int) -> str:
    return f"0x{value & 0xFFFFFFFF:08X}"


def _frame(page: int, sample: int, *, bad_magic: bool = False,
           bad_histogram: bool = False) -> list[int]:
    phase_updates = 100 + sample
    flags = 1 | (1 << 5) | (1 << 6)
    words = [0] * audit.FRAME_WORDS
    words[0] = 2000 + 2 * sample
    words[1] = 0xDEADBEEF if bad_magic else audit.MAGIC
    words[2] = audit.VERSION | (page << 8)
    words[3] = 4000 + 2 * sample
    words[4] = 8000 + sample
    words[5] = 1
    words[6] = 0x00010000  # DAC0, reference 0, output 1
    words[7] = 2 | (flags << 8)
    words[8] = 32 + sample
    words[9] = -3 & 0xFFFFFFFF
    words[10] = 32 + sample
    words[11] = 32768
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
        words[21] = 1
        words[27] = phase_updates
        words[30] = -5 & 0xFFFFFFFF
        words[31] = 5
    elif page == 1:
        words[25] = words[14]
        words[26] = words[15]
        words[17] = 500 + sample
        words[19] = -100 - sample
        words[21] = 500 + sample
        words[23] = -100 - sample
    else:
        words[17 + 8] = 0 if bad_histogram else phase_updates
    return words


def _line(page: int, sample: int, **kwargs: object) -> str:
    words = _frame(page, sample, **kwargs)
    elapsed = sample * 3000 + page * 1000
    raw = " ".join(f"F4L_W{i:02d}_RAW={_u32(word)}" for i, word in enumerate(words))
    return (
        "STEP5_F4L_MAIN_DIAG board=DE5_SLAVE cycle={} elapsed_ms={} "
        "host_end_ms={} MAIN_F4L_VALID=1 "
        "PUBLICATION_EPOCH_RAW_BEFORE={} PUBLICATION_EPOCH_RAW_AFTER={} {}"
    ).format(sample * 3 + page, elapsed, elapsed, _u32(words[0]), _u32(words[0]), raw)


def _complete_log() -> str:
    lines: list[str] = []
    for sample in range(12):
        for page in range(3):
            lines.append(_line(page, sample))
        lines.append(
            "STEP5_F4L_CYCLE board=DE5_SLAVE cycle={} elapsed_ms={} "
            "MAIN_F4L_VALID=1 MAIN_F4L_UPDATE_ID={} HELPER_LOCKED=1 "
            "HELPER_RESIDUAL_PRESENT=0".format(sample + 1, sample * 3000, 8000 + sample)
        )
    lines.append(
        "STEP5_F4L_CONFIG read_only_observer=1 one_reader=1 "
        "no_control_write=1 control_parameters_unchanged=1"
    )
    lines.append(
        "STEP5_F4L_DONE SESSION_ELAPSED_MS=36000 STOP_REASON=NONE"
    )
    return "\n".join(lines) + "\n"


def test_complete_paged_capture_is_diagnostic_pass_but_not_step5() -> None:
    result = audit.analyze_text(_complete_log())
    assert result["classification"] == "DIAGNOSTIC_COMPLETE"
    assert result["diagnostic_pass"] is True
    assert result["step5_pass"] is False
    assert result["page_counts"] == {"0": 12, "1": 12, "2": 12}
    assert result["helper_unlocked_with_main_valid"] == 0


def test_wrong_magic_is_rejected() -> None:
    text = _complete_log().replace(
        "F4L_W01_RAW=0x46344C31", "F4L_W01_RAW=0xDEADBEEF", 1
    )
    result = audit.analyze_text(text)
    assert result["classification"] == "FRAME_SCHEMA_INVALID"
    assert result["diagnostic_pass"] is False
    assert result["invalid_frame_count"] >= 1


def test_histogram_mismatch_is_rejected_without_mixing_pages() -> None:
    text = _complete_log().replace(
        "F4L_W25_RAW=0x00000064", "F4L_W25_RAW=0x00000000", 1
    )
    result = audit.analyze_text(text)
    assert result["classification"] == "FRAME_SCHEMA_INVALID"
    assert "HISTOGRAM_PHASE_COUNT_MISMATCH" in result["invalid_frames"][0]["problems"]


def test_short_capture_is_inconclusive() -> None:
    result = audit.analyze_text("\n".join(_line(page, 0) for page in range(3)))
    assert result["classification"] == "INCONCLUSIVE"
    assert result["diagnostic_pass"] is False


def test_source_declares_f4l_without_control_parameter_changes() -> None:
    source = (ROOT / "vendor" / "wrpc-sw" / "softpll" / "spll_main.c").read_text(
        encoding="utf-8"
    )
    task_diags = (ROOT / "vendor" / "wrpc-sw" / "lib" / "task-diags.c").read_text(
        encoding="utf-8"
    )
    assert "spll_main_f4l_diag_record" in source
    assert "wdiags_write_wr_spll_main_f4l_debug" in task_diags
    identity = (
        ROOT / "firmware" / "configs" / "de5a_slave_identity.h"
    ).read_text(encoding="utf-8")
    assert "DE5A_F4L_MAIN_PHASE_DIAG " in identity
    assert "DE5A_MAIN_PI_KP_OVERRIDE 300" in identity
    assert "DE5A_MAIN_PHASE_PI_KI_ZERO 1" in identity
    observer = (
        ROOT / "scripts" / "jtag" /
        "read_step5_main_frequency_prelock_observability.tcl"
    ).read_text(encoding="utf-8")
    assert "if {$::f4m_enabled}" in observer
    assert "set no_valid_timeout_ms 10000" in observer
    assert "set smoke_duration 10000" in observer
    assert "set no_valid_timeout_ms 30000" in observer
    assert "set smoke_duration 60000" in observer
