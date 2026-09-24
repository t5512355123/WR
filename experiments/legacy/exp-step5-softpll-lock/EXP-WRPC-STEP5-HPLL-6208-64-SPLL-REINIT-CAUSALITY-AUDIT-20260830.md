# EXP-WRPC-STEP5-HPLL-6208-64-SPLL-REINIT-CAUSALITY-AUDIT

Date: 2026-08-30 (Asia/Taipei)
Branch: `exp/step5-softpll-lock`
Source commit: `adee4b8` (`fix: bracket reinit counter snapshot`)

## Objective

Determine whether the Helper measurement/epoch resets observed in the previous
Step 5 runs are caused by a repeated `spll_init()` call, and attribute the
re-initialization to an exact source callsite. This experiment is
observability-only; it does not tune the PI loop or change the runtime control
path.

## Fixed configuration

The previously accepted Step 5 configuration was kept unchanged:

```text
BOOTSTRAP_STEPS = 6208
ENABLE_NORMAL_HPLL_TRACKER = 1
CODE_PER_PHYSICAL_STEP = 64
polarity = A
kp = -150
ki = -2
threshold = 200
lock_samples = 10000
```

## Instrumentation

Every actual non-host `spll_init()` callsite was tagged with a named reason.
The observer captured the init count, last init metadata, per-reason counters,
SoftPLL state, Helper epoch/update/lock state, PTP/WR state, and reset probes.

The four reason-counter words use four 8-bit counters per 32-bit word. The
diagnostic window `0x1e0..0x1fc` is a read-only attribution overlay for this
experiment; no SDB/diagnostic-space extension was made. The existing shell
microtrace mirror is disabled while this attribution overlay is active so that
the two observability windows do not alias.

## Build and programming provenance

Final images were built successfully on pain from `adee4b8`:

```text
Slave: GIT_COMMIT=adee4b83f16afecd18a225e95f4211e3db701877
       MIF_SHA256=78ac8962a022f6e5863be26df9f2a8ddb0c3ec9ff34760615482c63c49d48097
       SOF_SHA256=fba77089c0bfeae8ea111d56793405ad96b4402b5181bfdda8187778be938ae9
       COMPILE_RESULT=Full Compilation was successful

Master: GIT_COMMIT=adee4b83f16afecd18a225e95f4211e3db701877
        MIF_SHA256=3e585a6741f2224d20d5a5b04d6f659d9d2a50171ffae01eea4660bed139ee78
        SOF_SHA256=4b22aae07f3ef6fd9a416fba7f1495478c4e124ee9d3e4690968b7eb13d850df
        COMPILE_RESULT=Full Compilation was successful
```

The final fresh Slave image was programmed successfully immediately before
the audit. The valid raw observer log is:

```text
artifacts/EXP-WRPC-STEP5-HPLL-6208-64-SPLL-REINIT-CAUSALITY-AUDIT/raw-20260830/reinit-causality-slave-1800samples-final-valid.log
```

Earlier RS-422-mapped and pre-final-image observer logs are not evidence for
this result and are excluded from the conclusion.

## Final observer result

The observer completed successfully with 1800 samples:

```text
SAMPLES=1800
COHERENT_MEASUREMENT_SNAPSHOTS=1800
MEASUREMENT_ACCOUNTING_FAILS=0
ACCOUNTING_REJECTED=23

SPLL_INIT_COUNT_FIRST=1
SPLL_INIT_COUNT_FINAL=4
SPLL_INIT_COUNT_DELTA=3
REINIT_EVENTS=32

HELPER_EPOCH_FIRST=72094
HELPER_EPOCH_FINAL=2776002
HELPER_UPDATE_FIRST=336047
HELPER_UPDATE_FINAL=1388001
HELPER_EPOCH_OR_UPDATE_RESET_ALIGNED=5

EXACTLY_ONE_REASON_CHANGED=4
LAST_REASON=1
LAST_REASON_NAME=WRPC_LOCKING_ENABLE
REASON_INDEX=1
REASON_DELTA=4

SPLL_REINIT_DURING_LOCK_ATTEMPT=CONFIRMED
SPLL_REINIT_CAUSE=WRPC_LOCKING_ENABLE

RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
RESET_STABLE=PASS
MEASUREMENT_COHERENCE=PASS
```

The 23 rejected accounting candidates did not reduce the coherent snapshot
count: all 1800 accepted observer snapshots were coherent and the accounting
failure count remained zero.

## Interpretation

This experiment confirms the previously suspected causality:

```text
wrpc_spll_locking_enable()
  -> spll_init()
  -> Helper epoch/update counters restart
```

The attribution is specific because the init count increased, the Helper
epoch/update reset was time-aligned, and exactly one named reason counter
changed. The reset probes remained stable, so this is not a board/CPU/WR-core
reset masquerading as a SoftPLL re-init.

However, this is not a Step 5 completion result. The final run still showed:

```text
HELPER_LOCKED=0
MAIN_ENABLED=0
MAIN_LOCKED=0
PSTAT_LOCKED=0
```

Therefore the current status is:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Next action requested from branch5

Branch5 should now review this causality evidence and specify the minimal
functional fix or controlled experiment needed to stop the repeated
`WRPC_LOCKING_ENABLE` re-initialization before any PI tuning. This branch must
not be merged to `main` unless branch5 explicitly returns both:

```text
STEP5_COMPLETE = YES
MERGE_APPROVED = YES
```
