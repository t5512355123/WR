# EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT

## Verdict

```text
STEP4B_COMPLETE = YES
STEP4B_RESULT = PASS
VIRTUAL_PHYSICAL_POSITION_ACCOUNTING = PASS
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The fresh-program Slave gate passed Step 1, Step 2, Step 3, and Step4B. The
new read-only audit proves that the virtual tracker position agrees with the
completed normal FINC/FDEC direction accounting. It does not produce a
valid Helper/Main/PSTAT lock chain, so Step5 is not complete and this branch
must not be merged into `main`.

## Source and scope

```text
Branch = exp/step5-softpll-lock
Source commit = dec242d
Experiment = EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT
Board = DE5 [1-11.2]
Bootstrap physical steps = 6208
Normal tracker code per physical step = 64
Polarity = A
kp = -150
ki = -2
Helper threshold = 200
Helper lock samples = 10000
```

The functional control configuration was unchanged from the preceding
6208+64 run. This change added only read-only observability:

```text
Probe 43: target, virtual applied code, normal FINC completed, normal FDEC completed
Probe 44: normal completed, total DCO completed, bootstrap completed, completion epoch
```

Probe 44 brackets probe 43 with a completion epoch. A position sample is
accepted only when the epoch is unchanged, avoiding cross-probe temporal
skew while a physical transaction is completing. No tracker, PI, DMTD, PTP,
PHY, I2C, reset, or lock-control behavior was changed.

## Build, program, and fresh gate

The coherent Slave image built and programmed successfully:

```text
Slave FITTER = Successful
TIMING_CLOSED = NO
Slave SOF checksum = 0x30B42C35
Programming errors = 0
Programming warnings = 0
```

The fresh-program gate reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED                = YES
STEP4B_RESULT                 = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

The previously displayed `Step 1 error` was not reproduced by the fresh
gate. The latest raw gate reports `Step 1 pass`.

## From-reset signed-position audit

To cover the startup transition, the same image was programmed again and the
audit was started immediately after programming, without an intervening
dashboard read. The observer completed:

```text
SAMPLES = 600
VALID_FRAMES = 598
INVALID_FRAMES = 2
WINDOW_SECONDS = 59.900
```

The startup sequence was directly visible:

```text
sample 1:  bootstrap=3804, bootstrap_done=0, normal_completed=0
sample 14: bootstrap=6172, bootstrap_done=0, normal_completed=0
sample 15: bootstrap=6208, bootstrap_done=1, normal_completed=155,
           FINC=155, FDEC=0
```

At the end of the 60-second window:

```text
NORMAL_REQ_DELTA = 9567
NORMAL_COMPLETED_DELTA = 9567
DCO_STEP_DELTA = 11971
BOOTSTRAP_COMPLETED_DELTA = 2404
FINC_DELTA = 4859
FDEC_DELTA = 4708
SIGNED_NORMAL_NET = 151
APPLIED_FINAL = 9669
EXPECTED_APPLIED_FROM_NET = 9669
```

The coherent audit counters were error-free:

```text
POSITION_MATCH_SAMPLES = 596
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
```

This proves the required accounting identities for the observed window:

```text
NORMAL_FINC_COMPLETED + NORMAL_FDEC_COMPLETED = NORMAL_COMPLETED
APPLIED_CODE = 5 + 64 * (FINC - FDEC)
DCO_STEP = BOOTSTRAP_COMPLETED + NORMAL_COMPLETED
```

The reset counters remained unchanged:

```text
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## Rail and instantaneous frequency evidence

The first output-rail event occurred at sample 71. Representative rail
samples showed a positive instantaneous frequency error:

```text
sample 71: HELPER_OUTPUT=5, HELPER_ERROR=31078,
           TAG_DELTA=16634, EXPECTED_DELTA=16384,
           FREQ_ERROR=+250
sample 72: HELPER_OUTPUT=5, HELPER_ERROR=117803,
           TAG_DELTA=16610, EXPECTED_DELTA=16384,
           FREQ_ERROR=+226
sample 73: HELPER_OUTPUT=5, HELPER_ERROR=150000,
           TAG_DELTA=16532, EXPECTED_DELTA=16384,
           FREQ_ERROR=+148
```

Within the 59.9-second window:

```text
RAIL5_SAMPLES = 24 / 598 = 4.013%
PLUS150000_SAMPLES = 14 / 598 = 2.341%
HELPER_LOCKED_FINAL = 0
HELPER_LOCK_COUNT_FINAL = 179 / 10000
HELPER_ERROR_FINAL = +49
HELPER_OUTPUT_FINAL = 9666
```

The positive `FREQ_ERROR` at the lower rail classifies the rail event as
insufficient lower-side correction headroom, not as a virtual-to-physical
position accounting bug. The short from-reset window can temporarily return
to the middle output range, while the separate 1800-second 6208 run still
ended at `HELPER_ERROR=+150000`, `HELPER_OUTPUT=5`, and no valid lock. This
trajectory dependence is why Step5 cannot be declared complete from the
short window.

The final paired dashboard after the from-reset audit reported:

```text
HELPER locked = 0
HELPER count = 229 / 10000
HELPER error = -965
HELPER output = 8022
MAIN enabled = 0
MAIN locked = 0
PSTAT_locked = 0
STEP5_RESULT = NEVER_LOCKED
```

## Step5 and merge decision

```text
STEP4B_COMPLETE = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The required chain was not observed:

```text
HELPER locked=1, count=10000
→ MAIN enabled=1
→ MAIN frequency locked=1
→ MAIN phase locked=1
→ MAIN locked=1
→ PSTAT_locked=1 for at least 300 s without delock/reset/re-entry
```

Therefore no merge is authorized. The next control change must wait for the
branch5 reviewer to specify the next single-variable experiment after this
signed-position audit.

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT/build_slave.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT/program_slave.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT/dashboard_gate.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT/position_audit_60s.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT/from_reset_program_slave.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT/from_reset_position_audit_60s.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-64-SIGNED-PHYSICAL-POSITION-AUDIT/from_reset_dashboard_after.log
```
