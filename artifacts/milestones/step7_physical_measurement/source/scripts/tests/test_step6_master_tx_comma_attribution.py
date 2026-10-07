import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "analysis" / "step6_master_tx_comma_attribution.py"
SPEC = importlib.util.spec_from_file_location("step6_comma", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def local(index: int, ready: int = 1) -> str:
    return (
        "COMMA_LOCAL_SAMPLE BOARD=DE5 [1-11.1] "
        f"SAMPLE={index} ELAPSED_MS={index * 100} READ_VALID=1 "
        "STATUS_RAW=0000000000000001 COUNTER_RAW=0000000000000000 "
        "TX_CONTEXT_RAW=0000000000000000 SI_CONFIG_DONE=1 WR_READY=1 "
        "TX_READY=1 CPU_RESET_N=1 PHY_RST=0 PHY_TX_DISABLE=0 "
        "TX_DATA=188 TX_K=1 TX_ENC_ERR=0 TX_CYCLE_COUNT=100 "
        "TX_K28P5_COUNT=50 BOOT_GENERATION=00000001 "
        "CPU_RESET_COUNT=00000000 WR_CORE_RESET_COUNT=00000000 "
        "SI_CONFIG_DROP_COUNT=00000000 "
        f"LOCAL_READY={ready} READY_STREAK={index + 1}"
    )


def formal(index: int, cycle: int, comma: int) -> str:
    return (
        "COMMA_FORMAL_SAMPLE BOARD=DE5 [1-11.1] "
        f"SAMPLE={index} ELAPSED_MS={index * 100} READ_VALID=1 "
        "STATUS_RAW=0000000000000001 COUNTER_RAW=0000000000000000 "
        "TX_CONTEXT_RAW=0000000000000000 SI_CONFIG_DONE=1 WR_READY=1 "
        "TX_READY=1 CPU_RESET_N=1 PHY_RST=0 PHY_TX_DISABLE=0 "
        "TX_DATA=188 TX_K=1 TX_ENC_ERR=0 "
        f"TX_CYCLE_COUNT={100 + cycle} TX_K28P5_COUNT={50 + comma} "
        f"TX_CYCLE_DELTA={cycle} TX_K28P5_DELTA={comma} "
        "BOOT_GENERATION=00000001 CPU_RESET_COUNT=00000000 "
        "WR_CORE_RESET_COUNT=00000000 SI_CONFIG_DROP_COUNT=00000000 "
        "RESET_CHANGED=0"
    )


def slave(recovered: int = 0) -> str:
    return (
        "COMMA_SLAVE_SAMPLE BOARD=DE5 [1-11.2] SAMPLE=0 ELAPSED_MS=100 "
        "READ_VALID=1 STATUS_RAW=0000000000000000 "
        "CLOCK_ACTIVITY_RAW=0000000000000000 CORE_TM_LINK_UP=0 "
        "CORE_LINK_OK=0 RX_LOCKED_TO_DATA=1 RX_SYNCSTATUS=0 "
        "RX_PATTERN_READY=0 RX_ACTIVITY_COUNT=1 "
        "BOOT_GENERATION=00000001 CPU_RESET_COUNT=00000000 "
        "WR_CORE_RESET_COUNT=00000000 SI_CONFIG_DROP_COUNT=00000000 "
        f"POST_MASTER_REPROGRAM_RECOVERY={recovered}"
    )


def capture(*, cycle: int, comma: int, recovered: int = 0) -> str:
    lines = [local(i) for i in range(3)]
    lines.extend(formal(i, cycle, comma) for i in range(5))
    lines.extend(slave(recovered) for _ in range(5))
    return "\n".join(lines)


def test_k28p5_emission_passes_when_both_counters_advance():
    result = MODULE.analyze_text(capture(cycle=1000, comma=1000))
    assert result["classification"] == "MASTER_TX_K28P5_EMISSION_PASS"
    assert result["master_tx_k28p5_emission"] == "PASS"
    assert result["step6a"] == "NOT_PASS"


def test_missing_comma_is_attributed_to_master_tx_pcs():
    result = MODULE.analyze_text(capture(cycle=1000, comma=0))
    assert result["classification"] == "FAIL_MASTER_TX_PCS_COMMA_GENERATION"


def test_slave_recovery_exception_wins():
    result = MODULE.analyze_text(capture(cycle=1000, comma=1000, recovered=1))
    assert result["classification"] == "POST_MASTER_REPROGRAM_RECOVERY_OBSERVED"


def test_local_ready_failure_stops_before_formal_classification():
    text = "\n".join(local(i, ready=0) for i in range(3))
    result = MODULE.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE_DIAG_IMAGE_STARTUP"
