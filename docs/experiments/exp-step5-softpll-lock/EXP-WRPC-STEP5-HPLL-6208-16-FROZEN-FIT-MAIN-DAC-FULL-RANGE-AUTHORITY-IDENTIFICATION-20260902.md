# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MAIN-DAC-FULL-RANGE-AUTHORITY-IDENTIFICATION-20260902

## Result

```text
FULL_RANGE_DAC_EXPERIMENT = NOT_EXECUTED
FULL_RANGE_DAC_BLOCKER = HELPER_LOCK_GATE_NOT_REACHED
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The requested low-rail-to-high-rail Main-DAC authority measurement could not
start because the event-triggered gate was never reached during the complete
1200-second window. The target board remained `MAIN_ENABLED=1` but
`HELPER_LOCKED=0`, with `gate_streak=0/10` at the end of the run.

Consequently, the test issued no `ptrack vco-freeze`, no `pll sdac`, and no
DAC code change. No full-range A/B values or authority gain can be inferred
from this run.

## Controlled scope

The same already-programmed image was reused. No rebuild, recompile,
reprogram, Main PI change, Helper gain change, threshold change, or lock
detector change was made.

```text
image = 88604a5 + 7585a06 2s Main trace publication
board = DE5 [1-11.2]
gate timeout = 1200 s
gate qualification = 10 consecutive valid samples at 250 ms
intended Phase A DAC = 5
intended Phase B DAC = 65531
only intended runtime control variable = forced Main DAC code
```

## Gate observation

The target board stayed in the following state through the gate window:

```text
HELPER_LOCKED = 0
MAIN_ENABLED = 1
MAIN_FREQ_ERROR = -1226
MAIN_PI_OUTPUT = 5
gate_streak = 0/10
```

The script ended with `DAC_ID_GATE_TIMEOUT` and `DAC_ID_DONE`. Since the
failure occurred before freeze, there was no need for recovery unfreeze.

## Health evidence

The settled preflight and post-health captures continued to show:

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

Post-health still reported the target board as `MAIN_ENABLED=1`,
`HELPER_LOCKED=0`, `MAIN frequency locked=0`, `MAIN phase locked=0`, and
`PSTAT locked=0`.

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

The next decision is delegated to branch5. This run does not provide evidence
for or against full-range DAC authority because neither endpoint was applied.

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MAIN-DAC-FULL-RANGE-AUTHORITY-IDENTIFICATION-20260902/
```

Included files:

```text
preflight.log
full-range-authority-identification.log
post-health.log
```
