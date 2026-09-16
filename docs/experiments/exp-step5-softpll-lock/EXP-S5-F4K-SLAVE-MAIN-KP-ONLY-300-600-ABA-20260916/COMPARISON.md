# F4K A1/B/A2 Comparison — Slave Main Kp 300/600/300

## Final classification

The F4K diagnostic comparison is **not valid for a causal ABA conclusion**.
A2 and B are valid 120-second arms, but A1 ended after about 41 seconds with
a terminal `WR_S_LOCK_TIMEOUT`. Because the baseline arm is not a complete,
safe formal window, the comparator correctly rejects the ABA result.

~~~text
CLASSIFICATION        = ARM_DATA_INVALID
DIAGNOSTIC_PASS       = NO
BASELINE_REPRODUCIBLE = NO
DIRECTION_SUPPORTED   = NO
COMMON_WINDOW_MS      = NONE
STEP5_PASS            = NO
MERGE_APPROVED        = NO
~~~

The machine-readable result is in `analysis/comparison/comparison.json` and
`analysis/comparison/comparison.csv`.

## Arm validity

| Arm | Slave Main Kp | Formal window | Safety/WR stop | Comparison gate |
|---|---:|---:|---|---|
| A1 | 300 | 40,907 ms / 120,000 ms | terminal `WR_S_LOCK_TIMEOUT` | invalid |
| B | 600 | 120,023 ms / 120,000 ms | none; terminal 0 | ready |
| A2 | 300 | 120,553 ms / 120,000 ms | none; terminal 0 | ready |

All three arms have `PSTAT_LOCKED=0`; therefore none is a Step5 lock pass.
The two complete arms also kept the reset/safety fields stable and retained
valid producer data throughout their formal windows.

## What the complete arms show

The complete B and A2 captures both show sustained producer activity without
lock:

~~~text
                         B (Kp=600)       A2 (Kp=300)
phase detector delta        436968            437830
phase in-band ratio         0.136511          0.136142
phase active ratio          0.959793          0.961668
handoff delta                    84                52
PSTAT_LOCKED                    0/159             0/159
~~

These are descriptive differences only. They cannot establish that changing
Kp caused or prevented a lock because A1 is not a valid baseline arm, and the
common-window ABA gate is consequently unavailable. In particular, the
experiment does not justify another production-control change by itself.

## Interpretation and disposition

F4K answered the narrow diagnostic question only partially: changing Slave
Main Kp to 600 produced a safe, fully observed run, while the repeated Kp=300
arm also produced a safe, fully observed run, but neither reached
`PSTAT_LOCKED`. The earlier Kp=300 arm was not reproducible at the formal WR
session gate, so the overall result is `ARM_DATA_INVALID`, not evidence of a
successful Kp direction.

No Step5 completion or merge request is authorized by this evidence. Preserve
all three arms, retain the excluded pre-pull B capture separately, and choose
the next experiment from the next diagnostic recommendation without silently
changing PI, timeout, arbiter, PHY, reset, or RTL boundaries.

