# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V4-EXCLUSIVE-PI-BANK-OWNERSHIP-DOUBLE-READ-SMOKE-100SAMPLES-20260901

## Purpose and scope

This experiment executes the branch5-requested V4 exclusive PI-bank
ownership smoke on Slave `DE5 [1-11.2]`. It verifies that one atomic snapshot
request freezes one PI bank and that Pass A and Pass B read that same bank
word-for-word through the corrected JTAG/Wishbone transport.

The observer was changed only to use the read/write protocol:

```text
preload complete request with current completion toggle
wait 2 ms
commit identical request by changing only the toggle
wait for completion
require three identical full 64-bit probe reads
```

No RTL, firmware, PI equation, PI parameter, control state machine, build
output, or FPGA programming image was changed. No rebuild or reprogramming
was performed for this smoke.

Branch:

```text
exp/step5-softpll-lock
```

Final observer commit:

```text
8c01ddd
```

Hardware and controls:

```text
Slave = DE5 [1-11.2]
QSFPA lane = 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
samples = 100
gap_ms = 100
```

Raw log captured on pain:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V4-EXCLUSIVE-PI-BANK-OWNERSHIP-DOUBLE-READ-SMOKE-100SAMPLES-20260901.log
```

## Preflight gate

Immediately before the V4 smoke, the corrected runtime observer was run once
with `--raw`. The required gate passed:

```text
Master: Step1 PASS, Step2 PASS, Step4A PASS
Slave:  Step1 PASS, Step2 PASS, Step3 PASS, Step4B PASS
WB_TRANSPORT_PROTOCOL = PRELOAD_THEN_TOGGLE_COMMIT
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
RXERR delta = 0
BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta = 0
SPLL_INIT_COUNT stable
```

## V4 result

The 100-sample V4 smoke completed successfully:

```text
SAMPLES = 100
DOUBLE_READ_TRANSACTIONS_VALID = 100
DOUBLE_READ_TRANSACTIONS_INVALID = 0
BANK_WORD_FOR_WORD_MATCH_COUNT = 100
BANK_WORD_FOR_WORD_MISMATCH_COUNT = 0
PASS_A_PI_MATH_VALID = 100
PASS_B_PI_MATH_VALID = 100
ACK_TIMEOUT = 0
ACK_MISMATCH = 0
EPOCH_GENERATION_MISMATCH = 0
EPOCH_CHANGED_DURING_READ = 0
PI_SNAPSHOT_TRANSPORT = PASS
V4_SMOKE = PASS
```

The corrected WB transport remained clean across the complete V4 observer:

```text
WB_REQUEST_COUNT = 9317
PRELOAD_COUNT = 9317
COMMIT_COUNT = 9317
WB_PROBE_READ_COUNT = 46585
PRELOAD_UNEXPECTED_TRIGGER_COUNT = 0
PROBE_3WAY_MATCH_COUNT = 9317
STABLE_RESPONSE_WRONG_COUNT = 0
ADDRESS_CROSS_CONTAMINATION_COUNT = 0
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
STALE_A5A5_COUNT = 0
UNSTABLE_TRANSACTION_COUNT = 0
WB_TRANSPORT_PROTOCOL = PRELOAD_THEN_TOGGLE_COMMIT
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

Additional coherence evidence was clean:

```text
VALID_FRAMES = 100
INVALID_FRAMES = 0
PI_TRACE_PRESENT = 100
PI_ACCOUNTING_FAILS = 0
PI_OUTPUT_MISMATCH_FAILS = 0
ANTI_WINDUP_VIOLATIONS = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
RESET_STABLE = PASS
```

## Interpretation

V4 is a PASS for the specific transport and exclusive frozen-PI-bank
ownership question. The previous Pass A/Pass B mismatches were not
reproduced after every WB transaction was changed to the preload/commit
protocol with stable full-probe completion checking.

This does not establish Step5 closed-loop lock. During all 100 samples:

```text
HELPER_LOCKED = 0
PSTAT_LOCKED = 0
HELPER_ERROR = 150000
LOW_RAIL_SAMPLES = 100
LOW_RAIL_SATURATION = CONFIRMED
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = CONFIRMED
```

Therefore the current milestone state is:

```text
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED_BY_LATEST_PREFLIGHT = YES
V4_SMOKE = PASS
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The V4 result authorizes the next Step5 dynamics experiment only after
branch5 reviews this record; it does not authorize a merge.
