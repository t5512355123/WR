# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MAIN-DAC-EVENT-TRIGGERED-DIRECTION-AUTHORITY-IDENTIFICATION-1200S-GATE-20260902

## Result

```text
DAC_DIRECTION_EXPERIMENT = PASS
DAC_DIRECTION_RESULT = POSITIVE
APPROX_MAIN_DAC_GAIN = 0.0048828125 frequency-error-units/code
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This run completed the requested event-triggered Main-DAC plant-direction
identification. Increasing the forced Main DAC code moved the measured Main
frequency error toward zero, but the Main frequency-lock condition was still
not reached.

## Controlled scope

The already-programmed image was reused. No rebuild, reprogram, controller
gain change, lock-threshold change, or functional-source change was made.

```text
image = 88604a5 + 7585a06 2s Main trace publication
board = DE5 [1-11.2]
gate timeout = 1200 s maximum
gate qualification = 10 consecutive valid samples at 250 ms
phase samples = 20 per phase at 500 ms
only runtime control variable = forced Main DAC code
```

The gate was reached after 10 consecutive valid samples, with
`HELPER_LOCKED=1` and `MAIN_ENABLED=1` at every qualifying sample. Main VCO
was then frozen using the normal `ptrack vco-freeze` command, and the test
used one DAC step only. The script ended with `ptrack unfreeze`.

## A/B measurement

```text
DAC_CODE_A = 5
DAC_CODE_B = 1029
DELTA_DAC = 1024

MAIN_FREQ_ERROR_A_MEAN = -770.166666667
MAIN_FREQ_ERROR_B_MEAN = -765.166666667
DELTA_FREQ_ERROR = +5.0

PLANT_SIGN = POSITIVE
APPROX_MAIN_DAC_GAIN = +5.0 / 1024 = 0.0048828125
```

Both phases had six unique coherent trace publications and zero invalid
frames. The raw endpoint values also moved in the expected direction:

```text
Phase A final FREQ_ERROR = -777
Phase B final FREQ_ERROR = -766
```

Therefore, for this operating point, increasing the Main DAC code moves the
frequency error toward zero. This is evidence that the current Main PI
polarity may be opposite to the measured plant direction; it is not by itself
a Step5 lock pass.

## Health and lock evidence

The settled preflight and post-health captures retained:

```text
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
WDIAGS_RXERR delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SPLL_DELOCK_COUNT before/after = 0/0
```

After the A/B run, Helper remained locked and Main remained enabled, while the
closed-loop lock fields were still inactive:

```text
HELPER locked = 1, count 9352/10000
MAIN enabled = 1
MAIN frequency locked = 0
MAIN phase locked = 0
PSTAT locked = 0
```

Thus the current Step5 first inactive boundary remains Main frequency lock.

## Formal handoff

```text
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
DAC_DIRECTION_EXPERIMENT = PASS
PLANT_SIGN = POSITIVE
STEP5_FIRST_INACTIVE_BOUNDARY = MAIN_FREQUENCY_LOCK
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The next decision is delegated to branch5. This result supports evaluating
Main PI polarity, but no polarity or gain change is applied in this commit.

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MAIN-DAC-EVENT-TRIGGERED-DIRECTION-AUTHORITY-IDENTIFICATION-1200S-GATE-20260902/
```

Included files:

```text
preflight.log
dac-event-triggered-direction-identification.log
post-health.log
```
