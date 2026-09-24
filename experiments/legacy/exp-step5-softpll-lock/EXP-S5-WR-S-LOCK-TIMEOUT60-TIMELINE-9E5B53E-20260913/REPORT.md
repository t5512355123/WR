# EXP-S5-WR-S-LOCK-TIMEOUT60-TIMELINE-9E5B53E-20260913

## Verdict

```text
EXPERIMENT_CLASSIFICATION = VALID_PARTIAL_STEP5_LOCK_BUT_WR_EXTENSION_UPSTREAM_FAILURE
STEP4_SOFTPLL_STARTUP     = PARTIAL_ONLY_NOT_PASS
STEP4B_WR_EXTENSION       = BLOCKED_BY_WR_EXTENSION_FAILURE
STEP5_CLOSED_LOOP_LOCK    = NOT_COMPLETE
MERGE_TO_MAIN             = NOT_REQUESTED / NOT_ALLOWED
```

This experiment is **not a Step5 pass**. The Slave SoftPLL eventually reached its internal ready and lock indications, but the WR extension had already failed and fallen back to ordinary PTP. The internal lock was also not continuously stable when first acquired.

## Objective

Test whether extending the normal-target White Rabbit Slave lock timeout from 15 s to 60 s allows the WR Slave handshake and SoftPLL to complete, while keeping the rest of the design unchanged.

## Source change

Baseline branch:

```text
branch = exp/step5-softpll-lock
commit = 9e5b53ee5ac9fc29c2111188c6e9893c0930980e
```

Only `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/wr-constants.h` was changed:

```diff
-#define WR_S_LOCK_TIMEOUT_MS        15000
+#define WR_S_LOCK_TIMEOUT_MS        60000
```

The special-target value was also changed from 30000 ms to 60000 ms. No SoftPLL PI, DMTD, DAC, PHY, reset, or arbiter logic was changed in this experiment.

## Execution record

The requested laptop-to-Pain loop was completed for this iteration:

1. The source change was committed and pushed from the laptop.
2. Pain pulled the exact commit `9e5b53e`.
3. Master and Slave full Quartus compilations completed successfully.
4. Master was programmed on `DE5 [1-11.1]`; Slave was programmed on `DE5 [1-11.2]`; both operations succeeded with zero errors and zero warnings.
5. The read-only startup timeline observer ran for 300000 ms.
6. All build, programming, and observer logs were copied into `raw/`.

Build facts:

```text
Quartus = 17.0.0 Build 595
Master timing closed = NO, WNS = -0.058 ns
Slave  timing closed = NO, WNS = +0.015 ns
Master MIF SHA256 = 1fa5e5a9103466841a5928115550672b20b8434049c0643b22f79dd73437f912
Master SOF SHA256 = 6ca238f3c10d266b7e7a703a28f289928109d3512b7dea136df457abab96ec18
Slave  MIF SHA256 = 72037f8f1deb23f37241c843069b121449111a4f698352dbe21d6b4230570e00
Slave  SOF SHA256 = ae3acf6249b4d605e4ae69ca76222814279837d83f4acd7eed9532113929e2ac
```

## Observed timeline

The observer's first-event summary was:

```text
FIRST_CORE_TM_LINK_UP_MS     = 463
FIRST_CORE_LINK_OK_MS        = 463
FIRST_PTP_RX_ACTIVITY_MS     = 463
FIRST_PTP_TX_ACTIVITY_MS     = 463
FIRST_DMTD_ACCEPT_MS         = 463
FIRST_PTP_SLAVE_MS           = 50239
FIRST_PDSTATE_PDETECTED_MS   = 463
FIRST_PDSTATE_FAILURE_MS     = 50239
FIRST_EXTSTATE_ACTIVE_MS     = 463
FIRST_EXTSTATE_PTP_MS        = 50239
FIRST_PARENT_WR_CALIBRATED_MS= 463
FIRST_LOCK_ENABLE_MS         = 463
FIRST_HELPER_LOCKED_MS       = 63431
FIRST_MAIN_ENABLED_MS        = 63431
FIRST_MAIN_PHASE_LOCKED_MS   = 72225
FIRST_SPLL_READY_MS          = 287740
FIRST_MAIN_FREQ_LOCKED_MS    = 287740
FIRST_MAIN_LOCKED_MS         = 287740
FIRST_PSTAT_LOCKED_MS        = 287740
FIRST_INACTIVE_BOUNDARY      = WR_EXTENSION_FAILURE
UNCLASSIFIED                 = 0
```

The important state samples are:

### 50.239 s: WR extension fails before SoftPLL completion

```text
PTP_STATE=9(SLAVE)
PPSI_PDSTATE=4(FAILURE)
PPSI_EXTSTATE=2(PTP)
WR_STATE=WRS_IDLE
WR_FAILURE=02020001
SPLL_SEQ_STATE=4(SEQ_WAIT_HELPER)
PSTAT_LOCKED=0
```

`WR_FAILURE=02020001` decodes to role `WR_SLAVE`, last failure state `WRS_S_LOCK`, failure count 1. This is a real upstream WR-extension failure, not a missing JTAG sample. The extension has already been disabled by this point.

### 63.431–72.225 s: SoftPLL progresses internally

```text
63.431 s: SPLL_SEQ_STATE=6(SEQ_WAIT_MAIN), helper_locked=1, main_enabled=1
72.225 s: main_phase_locked=1, but frequency lock is not yet complete
```

These events show that the runtime DMTD/TAG/TRR/IRQ/helper path is alive and the SoftPLL is making progress even after the WR extension has fallen back.

### 287.740 s: internal lock is eventually reached

```text
PTP_STATE=9(SLAVE)
PPSI_PDSTATE=4(FAILURE)
PPSI_EXTSTATE=2(PTP)
WR_STATE=WRS_IDLE
WR_FAILURE=02020003
WR_LOCK_RESULT=00000101 (check_lock=1)
SPLL_SEQ_STATE=8(SEQ_READY)
SPLL_HELPER_STATE=03E80001 (locked=1)
SPLL_MAIN_STATE=3E80320F (enabled=1,freq_locked=1,phase_locked=1,locked=1)
PSTAT=00000003
PSTAT_LOCKED=1
```

This is strong evidence that the **internal SoftPLL can converge in this image**, but it is not a valid WR Step5 result because `PPSI_EXTSTATE` is already `PTP`, `PPSI_PDSTATE` is `FAILURE`, `WR_STATE` is `WRS_IDLE`, and the WR failure count has reached 3.

### 289.939 s: first lock indication is not stable

The observer recorded the dynamic Main lock fields dropping from 1 to 0 while the sequence/PSTAT shadow still reported ready/locked in that sample:

```text
main_enabled: 1 -> 0
main_freq_locked: 1 -> 0
main_phase_locked: 1 -> 0
main_locked: 1 -> 0
```

At 292.137 s the fields recovered, and at 294.336 s a coherent sample again showed `SEQ_READY` and all Main lock bits equal to 1. The first lock therefore was not sustained across the observation window. The observer reads the dynamic WDIAGS fields separately, so impossible transient values in the log are treated as torn snapshots; the stable samples above are the authoritative evidence.

## Interpretation

The timeout change produced a useful partial causal result:

```text
timeout extension -> SoftPLL eventually reaches SEQ_READY/PSTAT_LOCKED
timeout extension -/-> WR extension remains active
timeout extension -/-> sustained Step5 closed-loop lock
```

The experiment separates two layers that were previously easy to conflate:

1. The SoftPLL/DMTD event-processing path is alive and can eventually reach its internal lock condition.
2. The WR protocol extension fails much earlier, transitions to ordinary PTP, and is not held active through the lock/calibration completion boundary.

There is also a timer-semantics discrepancy that must be resolved before trying another timeout number. The source defines `WR_STATE_RETRY=3`; `wr_s_lock()` arms `PP_TO_WR_EXT_0` with `WR_S_LOCK_TIMEOUT_MS*(WR_STATE_RETRY+1)`, which is 240 s for this image. Nevertheless, the recorded WR Slave `WRS_S_LOCK` failure occurs at 50.239 s. The next investigation must verify the timeout clock units, the actual timer reset/rename path, and that the programmed firmware is executing this exact state-machine path. Blindly increasing the constant again would not be evidence-based.

## Step assessment

```text
Step 1 PHY / Link          = link and traffic observed, but not a clean sustained PASS
Step 2 Endpoint / PTP      = partial; Slave state observed, then PD failure/fallback
Step 3 WR Handshake        = FAIL; WR extension failure at 50.239 s
Step 4 SoftPLL Startup     = partial internal startup only; not valid system PASS
Step 5 Closed-loop Lock    = NOT PASS; no sustained valid WR lock
Step 6 Global Time         = NA
```

No merge request or merge to `main` is justified by this result.

## Required next experiment (not executed in this iteration)

The next experiment should be a single, low-perturbation timer/handshake audit before another functional tuning change:

1. Add sticky, persistent telemetry at `WRS_S_LOCK` entry and at every retry/failure boundary: entry timestamp, configured timeout, retry counter, remaining timeout, timeout clock source/unit, and failure timestamp.
2. Audit `pp_timeout_set_rename()`, `pp_next_delay_1()`, and the target `calc_timeout()` implementation as one complete path.
3. Keep the SoftPLL constants and PI parameters unchanged.
4. Re-run a fresh-program observation and require the WR extension to remain `ACTIVE` without `PDSTATE=FAILURE` before judging Step5.
5. Only after that boundary is fixed, validate `SEQ_READY`, `PSTAT_LOCKED`, and all Main lock bits continuously for at least 60 s, followed by the project’s long stability window.

This iteration is intentionally stopped here as requested.

