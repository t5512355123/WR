# EXP-S5-MAIN-PHASE-KI0-DIRECT-GATE-20260919

## Verdict

```text
HELPER_ACQUISITION              = PASS
MAIN_START                      = PASS
MAIN_ENABLED                    = 1
DIRECT_RUNTIME_GATE             = PARTIAL_NOT_PASS
WR_FAILURE_REASON               = 3 (WR_S_LOCK_TIMEOUT, historical shadow)
PHASE_KI0_MECHANISM             = NOT_EVALUATED
F4L_KI0_SMOKE                   = NOT_RUN
STEP5_RESULT                    = NO
STOP_REASON                     = NONZERO_HISTORICAL_WR_FAILURE_REASON
```

The read proves that Helper remained locked and the Main sequence reached `MAIN_ENABLED=1`. It does not prove the Ki=0 mechanism or Step5 lock. The advisor's complete gate explicitly requires `WR_FAILURE_REASON=0`; the captured lock-result shadow still reports reason 3, so this round is stopped before F4L.

## Provenance

```text
experiment                         EXP-S5-MAIN-PHASE-KI0-DIRECT-GATE-20260919
source commit                      db7e0be12fcf1268059b916be6a21437da286fdd
prior Helper report commit         d4b64f1b
session                            same freshly programmed Ki=0 session
Slave SOF SHA256                   fa5de2430152190f61eb54c63506103a7ce7f676b0e0945f02a1957baa65ae60
Master SOF SHA256                  7e5ef99bc74d9f8e65d147a68d28a2c47985800d7422e84eb224632034b32dee
command                            quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
remote start/end                   2026-09-19 22:27:32 / 22:27:47 (Pain)
```

## Slave result (`DE5 [1-11.2]`)

### Upstream and Step4B

```text
SI_CONFIG_DONE       = 1
CORE_TM_LINK_UP      = 1
CORE_LINK_OK         = 1
PHY_LINK_USABLE      = 1
PSTAT_LINK           = 1
Step 1                = PASS
Step 2                = PASS (PTP state 9 SLAVE; RX/TX/RXERR deltas healthy)
Step 3                = PASS
STEP4B_ALLOWED        = YES
STEP4B_RESULT         = PASS
SPLL_SEQ_STATE        = 6 (SEQ_WAIT_MAIN)
```

### Helper and Main start

```text
HELPER_STATE before/after = 03E80001 / 03E80001
HELPER_LOCKED             = 1
HELPER_LOCK_COUNT         = 1000/1000
MAIN_ENABLED              = 1
MAIN_FREQ_LOCKED          = 1
MAIN_PHASE_LOCKED         = 0
MAIN_FREQ_COUNT           = 50/50
MAIN_PHASE_COUNT          = 152/1000
PSTAT_LOCKED              = 0
```

The Helper remained locked while Main was enabled. Main was still in frequency acquisition / not phase-locked; that is an observation, not a Ki=0 mechanism result.

### Stability

```text
BOOT_GENERATION delta      = 0
CPU_RESET_COUNT delta      = 0
WR_CORE_RESET_COUNT delta  = 0
SI_CONFIG_DROP_COUNT delta = 0
RXERR delta                = 0
JTAG/WB transport         = trusted; 352/352 matches, timeout=0, invalid=0
```

## Failure-shadow boundary

The direct output reported:

```text
WR_FAILURE_DEBUG = TIMEOUT last_fail_state=WRS_S_LOCK failure_count=35329
lock_result      = 6D500601
wr_failure       = 02028A01
```

The source audit in `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/wr-constants.h` defines the lock-result attribution field as bits 9–15, and `WR_FAIL_REASON_WR_S_LOCK_TIMEOUT=3`. Decoding `0x6D500601` therefore gives:

```text
WR_FAILURE_REASON = 3
```

The runtime script treats this as a post-Step3 historical timeout and still reports Step3/Step4B as passing; it is not evidence that the current link or Helper is down. However, the advisor's direct-gate contract explicitly required the reason to be zero. Consequently the complete direct gate is not declared PASS, and no F4L sample was taken.

## Interpretation boundary

```text
Helper acquisition/hold          PASS
SoftPLL sequence reached Main    PASS
Main phase branch execution      NOT OBSERVED
Main phase lock                  NOT LOCKED
Ki=0 mechanism                   NOT EVALUATED
Step5                            NOT PASS
```

This is not a negative causal result for phase Ki=0. The experiment stopped at the nonzero historical WR failure-reason gate before the allowed F4L mechanism smoke.

## Next action gate

Report this exact result to the phase-lock advisor and wait at least 10 minutes for a new instruction before any further hardware operation. Do not run F4L or reprogram until the advisor resolves whether the stale reason must be cleared/qualified or whether the source-backed direct gate should treat it as historical-only.
