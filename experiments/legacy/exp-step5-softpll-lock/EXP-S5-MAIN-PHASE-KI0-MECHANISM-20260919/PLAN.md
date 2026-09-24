# EXP-S5-MAIN-PHASE-KI0-MECHANISM-20260919

## Objective

Run the first single-variable causal candidate authorized by the latest phase-lock review:

- Main frequency branch Ki = 1 (baseline)
- Main phase branch Ki = 0 (only functional change)
- Main Kp = 300
- frequency prelock boost = 20
- frequency threshold = 50
- phase threshold = 1200
- Helper Kp/Ki = -2250/-2
- Slave bootstrap = 3388
- bumpless preload = enabled

## Required sequence

1. Laptop offline tests, commit, and push.
2. Pain clean detached worktree at the exact pushed commit; build Slave/Master JTAG images.
3. Program Slave then Master.
4. Run direct runtime gate in the same fresh-program session.
5. Run the 10-second F4L mechanism smoke only if link, Helper lock, and Main enabled all pass.

## Stop conditions

- Any link loss, reset/generation change, SI configuration drop, fresh terminal edge,
  Helper unlock, or Main disabled: stop with `CONTROL_RESULT=INVALID`.
- If the direct runtime gate is not ready: do not run F4L.
- If F4L runs and phase integrator actual/proposed deltas are non-zero: stop with
  `PHASE_KI0_IMPLEMENTATION=FAIL`.

## Actual execution

The direct runtime gate was not ready after programming: Slave PTP was uncalibrated,
Helper was unlocked, and Main was disabled. Therefore the F4L smoke was not run.
