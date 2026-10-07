from scripts.analysis.step6_master_last_ec1f25e8_postmortem import analyze_text


BASELINE = """\
REBUILD_BASELINE_PAIR SAMPLE=0 READ_VALID=1 SLAVE_CORE_LINK_OK=1 SLAVE_CORE_TM_LINK_UP=1 SLAVE_STICKY46_SYNC_LOSS=10 SLAVE_STICKY47_LOCK_LOSS=20 SLAVE_STICKY47_LINK_DROP=3 SLAVE_STICKY48_TM_LINK_DROP=4 SLAVE_BOOT_GENERATION=00000001
BASELINE_RESULT=PASS
BASELINE_SAMPLE_COUNT=5
BASELINE_SLAVE_LINK_UP_COUNT=5
BASELINE_SLAVE_LINK_MODE=UP
"""


def row(
    sample: int,
    *,
    stable: int = 1,
    link_drop: int = 3,
    tm_drop: int = 4,
    sync: int = 10,
    lock: int = 20,
    reset: int = 0,
) -> str:
    return (
        "POSTMORTEM_PAIR SAMPLE={sample} READ_VALID=1 "
        "LINK_DROP_DELTA={ld} TM_LINK_DROP_DELTA={td} "
        "SYNC_LOSS_DELTA={sd} LOCK_LOSS_DELTA={kd} "
        "LINK_DROP_SEEN={lse} TM_LINK_DROP_SEEN={tse} "
        "STABLE_GOOD={stable} MAX_STABLE_STREAK={streak} RESET_CHANGED={reset} "
        "SLAVE_BOOT_GENERATION=00000001\n"
    ).format(
        sample=sample,
        ld=link_drop - 3,
        td=tm_drop - 4,
        sd=sync - 10,
        kd=lock - 20,
        lse=int(link_drop > 3),
        tse=int(tm_drop > 4),
        stable=stable,
        streak=sample + 1 if stable else 0,
        reset=reset,
    )


def test_pass_requires_drop_and_five_stable_samples() -> None:
    current = "".join(row(i, link_drop=4, tm_drop=4) for i in range(5))
    result = analyze_text(
        BASELINE,
        current + "POSTMORTEM_RESULT=PASS_POSTMORTEM_DROP_AND_REACQUISITION\n",
    )
    assert result["postmortem_verdict"] == "PASS"
    assert result["classification"] == "PASS_POSTMORTEM_DROP_AND_REACQUISITION"


def test_sync_only_is_inconclusive() -> None:
    current = "".join(row(i, sync=11, stable=1) for i in range(5))
    result = analyze_text(
        BASELINE,
        current + "POSTMORTEM_RESULT=INCONCLUSIVE_ONLY_PHY_LOSS_EVIDENCE\n",
    )
    assert result["postmortem_verdict"] == "INCONCLUSIVE"
    assert result["classification"] == "INCONCLUSIVE_ONLY_PHY_LOSS_EVIDENCE"


def test_drop_without_stable_reacquisition_fails() -> None:
    current = "".join(row(i, link_drop=4, stable=0) for i in range(10))
    result = analyze_text(
        BASELINE,
        current + "POSTMORTEM_RESULT=FAIL_STABLE_REACQUISITION_NOT_PRESENT_POSTMORTEM\n",
    )
    assert result["postmortem_verdict"] == "FAIL"
    assert result["classification"] == "FAIL_STABLE_REACQUISITION_NOT_PRESENT_POSTMORTEM"


def test_reset_change_blocks_formal_pass() -> None:
    current = "".join(row(i, link_drop=4, reset=int(i == 2)) for i in range(5))
    result = analyze_text(
        BASELINE,
        current + "POSTMORTEM_RESULT=INCONCLUSIVE_RESET\n",
    )
    assert result["postmortem_verdict"] == "INCONCLUSIVE"
    assert result["classification"] == "INCONCLUSIVE_RESET"
