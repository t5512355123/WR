from pathlib import Path


SCRIPT = (
    Path(__file__).parents[1]
    / "experiment"
    / "run_step6b_pain_direct_programmer_access_preflight.sh"
)


def test_preflight_is_read_only_and_non_sudo() -> None:
    text = SCRIPT.read_text(encoding="utf-8")
    assert 'sudo "' not in text.lower()
    assert "sudo -s" not in text.lower()
    assert "sudo -n" not in text.lower()
    assert "-o p;" not in text
    assert "FPGA_PROGRAM_COUNT=0" in text
    assert '"$QUARTUS_PGM" -l' in text


def test_preflight_requires_both_named_cables() -> None:
    text = SCRIPT.read_text(encoding="utf-8")
    assert "DE5 [1-11.1]" in text
    assert "DE5 [1-11.2]" in text
    assert "FAIL_REQUIRED_PROGRAMMING_CABLE_NOT_VISIBLE" in text


def test_preflight_requires_fitted_artifact_hashes() -> None:
    text = SCRIPT.read_text(encoding="utf-8")
    for expected in (
        "1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5",
        "66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151",
        "PASS_STEP6B_POSTFIT_TIMING_PROVEN",
    ):
        assert expected in text
