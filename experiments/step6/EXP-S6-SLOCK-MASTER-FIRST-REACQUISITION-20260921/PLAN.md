# EXP-S6-SLOCK-MASTER-FIRST-REACQUISITION-20260921

## Question

With the exact Step6A `ec1f25e8` Master/Slave images and all WR/SoftPLL
parameters frozen, does restoring the validated Step5 startup order make the
Slave obtain its first successful `spll_check_lock(0)=1` before the existing
240 s `WRS_S_LOCK` deadline?

## Controlled variable

Only the programming order changes:

```text
Master program → Master precondition (10 stable samples) → Slave program
```

The earlier Step6A run used Slave first and programmed Master roughly 30 s
later.  This experiment does not change the SOF, RTL, WRPC firmware, PI,
threshold, timeout, retry count, PHY, reset tree, SI configuration, or fiber.

## Image and hardware contract

- Reuse the exact images produced at source commit `ec1f25e8`.
- Expected Master SOF SHA256:
  `568f08c974064bdd3e82f68e3f1ecb0ff6c8a2a8e5705bdcc15b5941d33173a3`.
- Expected Slave SOF SHA256:
  `7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e`.
- Full compile: not performed; the existing exact artifacts are reused.
- FPGA reprogramming: required, Master first, then Slave.
- Power-cycle: not required and not performed.
- Master cable: `DE5 [1-11.1]`; Slave cable: `DE5 [1-11.2]`.

If Master does not satisfy the precondition, do not program Slave and classify
the run as `INCONCLUSIVE_MASTER_PRECONDITION`.

## Observer

The observer is read-only and samples at 500 ms.  It records the WR state,
failure reason, S_LOCK trace support fields, cumulative locking counters,
Step5 lock context, and reset/generation counters.  The offline analyzer
derives the source-backed value:

```text
LOCK_SUCCESS_COUNT = LOCK_POLLS - LOCK_UNLOCKED - LOCK_CALIB_FAIL
```

The Slave capture runs for at most 600 samples (300 s), with a 10 s
post-event stability window after either a successful S_LOCK exit or a WR
failure.

## Verdict rules

`PASS_SLOCK_SUCCESS` requires a positive `LOCK_SUCCESS_COUNT`, a subsequent
departure from `WRS_S_LOCK` toward `WRS_LOCKED` (or a source-backed TX LOCKED
signal), and 10 s without WR failure, reset, or transport invalidity.

If the Slave reaches `WR_S_LOCK_TIMEOUT` while the maximum success count and
calibration-failure count are both zero, classify:

```text
FAIL_SPLL_NOT_LOCKED_BEFORE_SLOCK_DEADLINE
```

If calibration failures occur after a successful lock check, classify:

```text
FAIL_T24P_CALIBRATION_BEFORE_SLOCK_DEADLINE
```

Other downstream WR reasons remain distinct and do not get relabeled as an
S_LOCK failure.  Any transport error, generation/reset change, missing S_LOCK
entry, or insufficient post-event evidence is `INCONCLUSIVE`.

This experiment can support startup-order sensitivity, but it cannot by itself
claim Step6A Global Time validity or run Step6B.
