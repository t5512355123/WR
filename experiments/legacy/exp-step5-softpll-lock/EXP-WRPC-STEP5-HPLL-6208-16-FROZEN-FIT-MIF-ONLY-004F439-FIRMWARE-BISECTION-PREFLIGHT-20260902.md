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
PREFLIGHT_RESULT          = PASS (3 consecutive settled captures)
STEP4B_COMPLETE           = YES (historical milestone)
STEP4B_REVALIDATED        = YES FOR 004F439 IMAGE
STEP5_COMPLETE            = NO
MERGE_APPROVED            = NO
```

## Build and frozen-fit result

The laptop experiment plan was pushed first in commit `733930d`. On pain, the
firmware source was checked out at the exact `004f439` commit in a detached
worktree and both MIFs built successfully. The current fitted database was
copied before modification; only MIF update plus assembler was run.

```text
Master MIF SHA256 = 24edb693235017ae64d09cc43a2dc4f7e1682d65ce52e3de448651f131404ee2
Slave  MIF SHA256 = 2c2a803d23bf8e8818124275753a5d79167f38a19ec22908cbbb8330276ecc27
Master SOF SHA256 = fb9e31d30e93e00bab3dcf1bc5555974918ba18228fd0b1db83920aa17f492f9
Slave  SOF SHA256 = d82877b3ebac05b910605cd0ee04ce0c2899f11b4345e82fa1092ccc26e8a64f
```

Both MIF updates and assemblies succeeded with zero errors and five warnings
each. The four fit/STA hashes were identical before and after assembly:

```text
Master fit.rpt = e02fbf1a458861f46acb5a10f4463fb8f089715e0fffa48891feeae73b6925e1
Master sta.rpt = fd36464ebc2e51551be1b95eac8fdeff1137983a6bde57547db5a94e9345d737
Slave  fit.rpt = 3dfba19a8001ef0077c6e2dc745a126f648a08fdf39faa96fe929fb8c6a3044b
Slave  sta.rpt = d801919fefc866dc51121f3e385b4d6b25b2a2377f97fa7d1ed77556081f2523
```

This confirms that the controlled comparison changed the WRPC firmware MIF
only; fitter, placement/routing, and timing reports were preserved.

## Programming

The generated images were programmed in the required order:

```text
Slave  DE5 [1-11.2] = successful, 0 errors, 0 warnings
Master DE5 [1-11.1] = successful, 0 errors, 0 warnings
```

## Three consecutive settled preflights

All three read-only `read_wb_runtime.tcl --raw` captures passed the complete
upstream gate. The captures were taken after the initial post-program settling
interval and then in two subsequent settled windows:

```text
                         preflight-1  preflight-2  preflight-3
Master Step1/2/4A             PASS         PASS         PASS
Slave Step1/2/3/4B            PASS         PASS         PASS
STEP4B_ALLOWED                YES          YES          YES
STEP4B_RESULT                 PASS         PASS         PASS
STEP4B_FIRST_INACTIVE         ACTIVE       ACTIVE       ACTIVE
JTAG_WB_DIAGNOSTIC_PATH       TRUSTED      TRUSTED      TRUSTED
PRELOAD_PROTOCOL_REVALIDATION PASS         PASS         PASS
DMTD_REF_DECREASE_COUNT       0            0            0
DMTD_FB_DECREASE_COUNT        0            0            0
```

The preflight snapshots showed `HELPER_LOCKED=0` and a Helper lock counter of
`2/10000`. This is not a Step5 lock result, because this experiment was
explicitly limited to locating the Step1/Step4B recovery boundary.

## Interpretation and handoff

The frozen-fit bisection result is:

```text
56a43b3 firmware  -> Slave Step1 FAIL, Step4B blocked
004f439 firmware  -> Slave Step1/2/3/4B PASS, three times
```

Therefore `004f439` is the first tested revision in this bracket that restores
the upstream Step4B gate on the same fitted hardware. It does not complete
Step5 and does not authorize a merge. The next experiment is to run the
existing 6000-sample x 100-ms Helper observer on this same frozen-fit
`004f439` image, only if the branch5 review explicitly accepts that handoff.

```text
STEP4B_COMPLETE           = YES
STEP4B_REVALIDATED        = YES
STEP5_COMPLETE            = NO
MERGE_APPROVED            = NO
NEXT_REQUIRED_EXPERIMENT  = 004f439 frozen-fit Helper 6000 x 100-ms run
```

## Raw evidence

The committed raw evidence is under:

`docs/experiments/exp-step5-softpll-lock/raw/step5-004f439-preflight-20260902/`

It contains the two firmware build logs, fit/STA before/after hashes, MIF/SOF
hashes, MIF-update/assembly logs, programming logs, and all three preflight
captures.
