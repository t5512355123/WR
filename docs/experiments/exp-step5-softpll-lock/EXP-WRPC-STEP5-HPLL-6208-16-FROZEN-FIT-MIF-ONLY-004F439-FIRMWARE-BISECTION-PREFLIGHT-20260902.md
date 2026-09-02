# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MIF-ONLY-004F439-FIRMWARE-BISECTION-PREFLIGHT-20260902

## Purpose

Locate the first firmware revision after `56a43b3` that restores the Slave
upstream Step1/Step4B gate. This experiment is a preflight-only bisect; it is
not a Step5 lock run.

The previous frozen-fit MIF-only replay of `56a43b3` was blocked before Step4B:
the Slave reported `core_tm_link_up=0` and `core_link_ok=0` in two settled
captures. The current trusted `7585a06` baseline passes Step4B. The next
controlled revision is `004f439`, the first firmware revision in this history
that adds Main-frequency observability.

## Controlled change

```text
ONLY_CONTROL_VARIABLE = WRPC_FIRMWARE_REVISION
previous              = 56a43b3e8b1f73369576c6542f63fb027652636c
test                  = 004f4396f48622ded3575fcf11aa9a906f571c65
```

All implementation and runtime settings remain fixed:

```text
fitted database         = current 7585a06 fitted database
placement/routing       = unchanged
bootstrap               = 6208
code_per_physical_step  = 16
helper kp               = -300
helper ki               = -1
shift                   = 12
bias                    = 5
threshold               = 200
lock_samples            = 10000
QSFPA lane              = 2
normal tracker          = ON
```

The laptop-side source selection is the immutable `004f439` firmware commit;
the generated MIFs will be built from that commit in a detached worktree,
then applied to the frozen current fitted database with MIF update plus
assembler only. No synthesis, fitter, place-and-route, HDL, controller, or
timing change is permitted.

## Required procedure

1. Build Master/Slave WRPC MIFs from `004f439`.
2. Apply the MIFs to the frozen `7585a06` fitted database and preserve the
   fit/STA hashes.
3. Program Slave first, then Master.
4. Take three consecutive settled read-only preflights.
5. Do not run the 600-second Helper observer in this experiment.

Each preflight must show:

```text
Master Step1/Step2/Step4A = PASS
Slave  Step1/Step2/Step3/Step4B = PASS
STEP4B_ALLOWED            = YES
STEP4B_RESULT             = PASS
RXERR_DELTA               = 0
all reset deltas          = 0
JTAG_WB_DIAGNOSTIC_PATH   = TRUSTED
```

## Status

```text
PREFLIGHT_RESULT          = PENDING
STEP4B_COMPLETE           = YES (historical milestone)
STEP4B_REVALIDATED        = PENDING FOR 004F439 IMAGE
STEP5_COMPLETE            = NO
MERGE_APPROVED            = NO
```

The final result, hashes, programming logs, three preflight captures, and any
next-step recommendation will be appended after the hardware run.
