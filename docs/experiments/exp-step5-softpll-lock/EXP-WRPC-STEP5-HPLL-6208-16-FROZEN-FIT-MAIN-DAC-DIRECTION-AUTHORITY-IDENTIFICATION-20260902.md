# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MAIN-DAC-DIRECTION-AUTHORITY-IDENTIFICATION-20260902

## Result

```text
DAC_DIRECTION_EXPERIMENT = NOT_EXECUTED
DAC_DIRECTION_BLOCKER = HELPER_LOCK_GATE_NOT_REACHED
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP5_RESULT = NOT_PASS
```

The experiment did not reach the controlled Main-DAC A/B measurement. The
target board `DE5 [1-11.2]` remained `MAIN_ENABLED=1` but
`HELPER_LOCKED=0` for the complete 120-second gate window. Therefore the
script did not issue `ptrack vco-freeze` or either `pll sdac` command.

## Scope and image

This was a runtime-only experiment using the already programmed image. No
rebuild, reprogram, gain change, lock-threshold change, or functional-source
change was made.

```text
existing image = 88604a5 + 7585a06
board = DE5 [1-11.2]
gate timeout = 120 s
phase samples = 20
phase gap = 500 ms
intended DAC step = +1024 codes
```

The observer was added at:

```text
scripts/jtag/read_step5_main_dac_direction_identification.tcl
```

The first invocation exposed and was corrected for a Tcl quoting error in the
default board filter. That invocation failed before opening the source probe,
so it could not affect the board. The corrected invocation completed with
`DAC_ID_GATE_TIMEOUT` and no DAC phase data.

## Gate and health evidence

The dedicated 40-sample, 250-ms monitor observed both boards as
`STEP5_SERIES_RESULT=NEVER_LOCKED`:

```text
DE5 [1-11.1]: HELPER locked=0, MAIN enabled=0, valid_samples=40
DE5 [1-11.2]: HELPER locked=0, MAIN enabled=1, valid_samples=40
```

For the target board, the preflight and post-health captures continued to
show:

```text
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
spll_helper_state = 00000000
spll_main_state   = 00000001
WDIAGS_RXERR delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

No `DAC_ID_PHASE_SUMMARY` or `DAC_ID_RESULT` exists because the gate was not
reached. The next decision is delegated to branch5: determine why the
currently programmed image does not reproduce the required Helper-lock gate,
before attempting DAC direction identification.

## Raw evidence

The raw logs for this run are in:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MAIN-DAC-DIRECTION-AUTHORITY-IDENTIFICATION-20260902/
```

Included files:

```text
preflight.log
dac-direction-identification.log
helper-lock-monitor.log
post-health.log
```
