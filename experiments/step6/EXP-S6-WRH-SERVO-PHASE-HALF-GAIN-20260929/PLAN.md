# EXP-S6-WRH-SERVO-PHASE-HALF-GAIN-20260929

## Objective

Restore Slave Global Time validity by correcting the measured acquisition-loop
overshoot. Preserve the existing 60 ps validity threshold and all Step 5 / PLL
control behavior.

## Baseline evidence

With the frozen Step 6 image, Step 1–5 and the Slave lock bits were valid, but
Slave `TIME_VALID=0` and the WR servo repeatedly remained in
`WAIT_OFFSET_STABLE`. A 60 s read-only coherent capture on 2026-09-29 produced
two adjacent update pairs after a phase-setpoint action:

| Offset before (ps) | Setpoint delta (ps) | Offset after (ps) | Measured response delta (ps) | Estimated gain |
|---:|---:|---:|---:|---:|
| -2757 | -2757 | +2654 | +5411 | -1.964 |
| +2617 | +2617 | -2639 | -5256 | -2.008 |

The source currently adds the entire phase offset to `cur_setpoint_ps`. The
observed approximately -2:1 actuator response explains the near-equal sign
reversal and repeated failure of the unchanged 60 ps stable gate.

## Single functional change

In `wrh-servo.c`, change only the `WRH_SYNC_PHASE` acquisition correction from
the full measured offset to half of it:

```c
s->cur_setpoint_ps += (offset_ps / 2);
```

Do not change the 60 ps threshold, `TRACK_PHASE` quarter-step tracking, lock
logic, timeout/retry count, PPS/TAI handling, SoftPLL PI/gains, RTL, SDB, or
timing constraints.

## Verification and stop conditions

1. Run the offline model test and source diff review.
2. Push the laptop source commit; Pain pulls that exact commit.
3. Build both milestone images and program Slave first, then Master, using the
   recorded build/program wrappers.
4. Run the read-only Step 1–6 dashboard and a coherent WR-servo trace. Stop and
   preserve evidence if reset/generation changes, JTAG becomes untrusted, or
   Step 1–5 drops.
5. The acquisition fix is only a candidate until Slave reaches and maintains
   `TIME_VALID=1`, `PPS_VALID=1`, and `TRACK_PHASE`/the established locked servo
   state. Then run the established Step 6 common-time/trigger regression.

No timing-closure claim is part of this experiment.
