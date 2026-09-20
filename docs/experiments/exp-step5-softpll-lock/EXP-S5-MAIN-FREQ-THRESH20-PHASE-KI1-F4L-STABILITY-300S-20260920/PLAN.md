# EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920

## Objective

Validate whether the already selected `threshold20 + phase-Ki1` image can hold
the Step5 functional gate for a continuous 300-second coherent WR session.
Timing closure is recorded separately and is not a functional gate.

## Frozen control

```text
firmware/source commit = 26e138fdc0bfc8426704b397141d563cf4d580a2
Slave Main frequency threshold = 20
Slave Main phase Ki = 1
Main Kp = 300
Helper/SoftPLL control = unchanged
PI, detector, threshold, timeout, bootstrap, arbiter, mailbox, PHY, reset, RTL, SDB = frozen
```

Only the read-only F4L observer contract was corrected after the first
attempt: its wall-clock target/hard limit changed from 120/130 seconds to
300/310 seconds. No firmware was rebuilt for that observer-only correction;
the already programmed SOF images stayed unchanged.

## Procedure

1. Build and program the exact Master/Slave candidate images.
2. Wait at least 120 seconds and run the read-only runtime preflight.
3. Run exactly one F4L observer with target `300000 ms` and hard limit
   `310000 ms`.
4. Preserve the complete raw output, checksum, build metadata, programmer
   logs, preflight logs, and offline analysis.

## Acceptance

The functional Step5 gate is satisfied only when the same session reaches at
least 300 seconds with all of the following continuously present:

```text
Helper/HPLL lock
Main frequency lock
Main phase lock
PSTAT.locked
```

The observer must also show a valid WR link, no terminal edge, no reset or
generation change, no SoftPLL delock, and no early stop.
