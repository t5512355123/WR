# EXP-WRPC-STEP5-HPLL-6208-64-COHERENT-CLOSED-LOOP-TRAJECTORY-AUDIT

Date: 2026-08-30  
Branch: `exp/step5-softpll-lock`  
Final evidence commit: `27f530e`

## Purpose

Validate the Step 5 closed-loop trajectory after enabling the normal HPLL tracker, while preserving the fixed 6208-step bootstrap and the existing coherent DMTD measurement publication. The audit must distinguish a valid control trajectory from a real Helper/Main/PSTAT lock.

## Scope and configuration

The only functional change in this experiment is the Slave wrapper generic:

```text
ENABLE_NORMAL_HPLL_TRACKER: 0 -> 1
```

The following values were kept unchanged:

```text
ENABLE_STEP5_BOOTSTRAP = 1
STEP5_BOOTSTRAP_STEPS = 6208
HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 64
A polarity = unchanged
kp = -150
ki = -2
threshold = 200
lock_samples = 10000
```

PHY, DMTD, PTP, reset tree, Main PLL, and the existing static-FSM fix were not changed. The Slave SOF was freshly built and programmed; the recorded checksum was `0x30B42C35`. The paired Master image checksum was `0x30B897E6`.

## Observer method

The JTAG observer reads the coherent WDIAGS seqlock payload, existing position probes, transaction counters, bootstrap state, and Helper/Main/PSTAT status. A candidate is rejected and retried when its epoch or accounting equation is torn by transport timing. Only accepted coherent samples are included in the measurement and position invariants.

The measurement equation checked for every accepted sample is:

```text
expected_delta = tag_delta - expected_applied_absolute
```

## Formal 1800-sample result

Raw evidence:

```text
artifacts/EXP-WRPC-STEP5-HPLL-6208-64-COHERENT-CLOSED-LOOP-TRAJECTORY-AUDIT/raw-20260830-coherent-closed-loop-1800samples-final.txt
```

```text
POST_BOOTSTRAP_BASELINE_SET=1
COHERENT_MEASUREMENT_SNAPSHOTS=1800
REJECTED_EPOCH_SNAPSHOTS=0
REJECTED_ACCOUNTING_CANDIDATES=17
MEASUREMENT_ACCOUNTING_FAILS=0
POSITION_SNAPSHOTS=1800
POSITION_INVARIANT_FAILS=0
TRANSACTION_INVARIANT_FAILS=0
DCO_INVARIANT_FAILS=0
FREQ_ERROR_MEAN=-0.121111111111
FREQ_ERROR_RMS=11.926907022
FREQ_ERROR_MIN=-52
FREQ_ERROR_MAX=45
NORMAL_REQ_DELTA_OBSERVED=6950
NORMAL_COMPLETED_DELTA=6950
FINC_DELTA=3465
FDEC_DELTA=3485
DCO_STEP_DELTA=6950
BOOTSTRAP_DELTA=0
FORCED_COMPLETED_DELTA=0
BOOTSTRAP_COMPLETED_FINAL=6208
BOOTSTRAP_DONE_FINAL=1
HELPER_LOCK_COUNT_MAX=2076
HELPER_LOCK_COUNT_FINAL=100
HELPER_LOCKED_SEEN=0
HELPER_LOCKED_FINAL=0
MAIN_ENABLED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
MAIN_PHASE_LOCKED_FINAL=0
MAIN_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
FULL_CHAIN_MAX_SECONDS=0.000
FULL_CHAIN_300S=0
STEP5_CHAIN_RESULT=NOT_COMPLETE
SPLL_DELOCK_COUNT_FIRST=0
SPLL_DELOCK_COUNT_MAX=0
SPLL_DELOCK_COUNT_FINAL=0
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=PASS
RESET_STABLE=PASS
```

`REJECTED_ACCOUNTING_CANDIDATES=17` are transport-torn candidates explicitly discarded by the observer. They are not counted as accepted samples; all 1800 accepted samples satisfy the accounting equation.

## Settled runtime dashboard

The post-run settled dashboard was captured separately:

```text
artifacts/EXP-WRPC-STEP5-HPLL-6208-64-COHERENT-CLOSED-LOOP-TRAJECTORY-AUDIT/raw-20260830-settled-dashboard-after-trajectory.txt
```

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

## Interpretation

The normal tracker is functionally active: normal requests and completions both advanced by 6950, with balanced `FINC`/`FDEC` activity and no bootstrap or forced completions after the baseline. The coherent frequency error remained close to zero, and the measurement, position, transaction, DCO, and reset invariants passed.

However, this is not a Step 5 lock. Helper lock never asserted, Main/PSTAT never became active, and the required continuous 300-second full-chain lock interval was zero. Therefore the evidence supports:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO (pending branch5 explicit decision)
```

This experiment closes the “tracker does not move” question, but it does not close the Step 5 lock requirement.
