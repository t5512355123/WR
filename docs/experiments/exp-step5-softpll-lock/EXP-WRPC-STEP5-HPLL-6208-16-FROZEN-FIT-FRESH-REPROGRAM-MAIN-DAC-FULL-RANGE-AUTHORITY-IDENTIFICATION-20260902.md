# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-FRESH-REPROGRAM-MAIN-DAC-FULL-RANGE-AUTHORITY-IDENTIFICATION-20260902

## Result

```text
FRESH_REPROGRAM = PASS
FRESH_REPROGRAM_PROGRAM_ORDER = SLAVE_THEN_MASTER
SETTLED_PREFLIGHT_SEQUENCE = PREFLIGHT_4,PREFLIGHT_5,PREFLIGHT_6
SETTLED_PREFLIGHT_SEQUENCE_RESULT = PASS,PASS,PASS
FULL_RANGE_DAC_EXPERIMENT = NOT_EXECUTED
FULL_RANGE_DAC_BLOCKER = HELPER_LOCK_GATE_NOT_REACHED
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The exact previously validated image was freshly programmed to both boards.
Programming succeeded for both cables. After startup settled, three
consecutive preflight captures passed the complete upstream/Step4B gates.

The subsequent event-triggered full-range Main-DAC test ran for the complete
1200-second window, but never reached its required gate:

```text
TRACE_VALID = 1
HELPER_LOCKED = 0
MAIN_ENABLED = 0
MAIN_FREQ_ERROR = 0
MAIN_PI_OUTPUT = 32768
UPDATE_COUNT = 0
gate_streak = 0/10
```

Therefore the test issued no `ptrack vco-freeze` and no `pll sdac` command.
No full-range A/B endpoint or DAC authority gain can be inferred from this
run.

## Controlled scope

The only changed variable was runtime initialization state: aged runtime was
replaced by fresh programming of the exact same image. No rebuild,
recompile, firmware change, parameter change, Main PI change, Helper gain
change, threshold change, or lock-detector change was made.

```text
image = 88604a5 + 7585a06 2s Main trace publication
slave cable = DE5 [1-11.2]
master cable = DE5 [1-11.1]
programming order = Slave -> Master
full-range gate timeout = 1200 s
gate qualification = 10 consecutive valid samples at 250 ms
intended Phase A DAC = 5
intended Phase B DAC = 65531
```

## Exact image evidence

```text
Slave SOF SHA256  = 04c7cb7ecca19be16eb9de022891a9c0143b2c6b62ce364d80db4e56508217fc
Master SOF SHA256 = 23bfdc100fa2b61aff3096754ebd99d61c1e1c1728be99cd5515204415c7dd0d
```

Both programming logs report `Configuration succeeded -- 1 device(s)
configured` and `0 errors, 0 warnings`.

## Fresh-start preflight sequence

The first three immediate post-program captures were not used as settled
passes. They showed Master Step4A passing, but Slave Step2 still reported
`INVALID` because PTP was initially uncalibrated; accordingly they reported
`STEP4B_ALLOWED = NO` and `STEP4B_RESULT = BLOCKED_BY_STEP2`.

After the startup interval, captures 4, 5, and 6 were consecutive settled
passes:

```text
                         preflight-4  preflight-5  preflight-6
Master Step1/Step2/Step3     PASS        PASS        PASS
Master Step4A                PASS        PASS        PASS
Slave Step1/Step2/Step3      PASS        PASS        PASS
Slave Step4B allowed         YES         YES         YES
Slave Step4B result          PASS        PASS        PASS
JTAG path                    TRUSTED     TRUSTED     TRUSTED
preload revalidation         PASS        PASS        PASS
RXERR delta                  0           0           0
CPU reset delta              0           0           0
WR-core reset delta          0           0           0
```

This confirms that fresh programming did not invalidate Step4B. The early
post-program PTP settling interval is recorded as startup behavior, not as a
Step4B functional failure.

## Full-range gate observation

The test was executed on `DE5 [1-11.2]` using the full-range mode, with the
same event-triggered gate used by the aged-runtime experiment. Across the
complete 1200-second window, the gate never became valid. The last samples
continued to show a valid trace but no helper lock, no Main enable, and no
Main update activity.

```text
DAC_ID_GATE elapsed_s = 1200
TRACE_VALID           = 1
HELPER_LOCKED         = 0
MAIN_ENABLED          = 0
FREQ_ERROR            = 0
PI_OUTPUT             = 32768
UPDATE_COUNT          = 0
DAC_ID_GATE_STREAK    = 0/10
DAC_ID_ERROR          = DAC_ID_GATE_TIMEOUT helper_locked/main_enabled gate not reached
```

Because the failure occurred before freeze, recovery unfreeze was not
required and neither DAC endpoint was applied.

## Post-health evidence

The post-health capture remained healthy at the transport and Step4B levels:

```text
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
WDIAGS_RXERR delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SPLL_SEQ_STATE = 4 (SEQ_WAIT_HELPER)
SPLL_TAG_VALID_COUNT delta = 47596
SPLL_TRR_WRITE_COUNT delta = 47597
WDIAGS_HELPER_UPDATE_COUNT delta = 23390
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
PSTAT_locked = 0
```

The counters show that the Step4B event-processing path remains active, but
the Step5 closed-loop lock detector never crossed the Helper-lock boundary.

## Formal handoff

```text
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
FULL_RANGE_DAC_EXPERIMENT = NOT_EXECUTED
FULL_RANGE_DAC_RESULT = UNKNOWN
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This fresh-program run confirms Step4B, but it does not prove Step5 and does
not provide full-range DAC authority evidence. The result is handed to
branch5 for the next diagnosis/experiment decision. No merge is authorized.

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-FRESH-REPROGRAM-MAIN-DAC-FULL-RANGE-AUTHORITY-IDENTIFICATION-20260902/
```

Included files:

```text
sof-sha256.txt
sof-sha256-after-program.txt
program-slave.log
program-master.log
preflight-1.log
preflight-2.log
preflight-3.log
preflight-4.log
preflight-5.log
preflight-6.log
full-range-authority-identification.log
post-health.log
```
