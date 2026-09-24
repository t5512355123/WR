# EXP-S5-F4J-MAIN-FREQ-ACCEPTANCE-AUDIT-20260919

## Purpose

Perform the advisor-requested source-side correlation audit for Main frequency-lock acceptance. This is an observability-owner switch only: the diagnostic owner changes from F4L to F4J so that one producer frame can expose `FREQ_ERROR`, frequency-lock counter before/after, branch identity, flags, and update identity together.

## Controlled source change

The only source change is in both DE5A identity headers:

```c
#define DE5A_F4L_MAIN_PHASE_DIAG 0
```

All control and hardware parameters remain frozen: phase Ki=0, bumpless preload, Main Kp=300, frequency Ki=1, thresholds, lock counts, delock floor, Helper PI, bootstrap, timeout, PHY/route, RTL, SDB, mailbox, and detector behavior.

## Required sequence

1. Push the source-only identity change from the laptop.
2. Pull the exact source commit on Pain.
3. Build both fresh JTAG images and record the compiler manifests.
4. Program Slave and Master and record the SOF hashes.
5. Run one read-only direct runtime gate.
6. Run the fixed 30-second F4J producer audit only if the gate proves the required operating state.

Required gate:

```text
PHY_LINK_USABLE = 1
PSTAT_LINK      = 1
HELPER_LOCKED   = 1, count=1000
MAIN_ENABLED    = 1
MAIN_FREQ_LOCKED= 1
reset/generation/SI-drop stable
```

The conditional audit command would have been:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 30000 40000 f4j
```

## Stop rule

If the fresh image does not enter the required state, classify `F4J_ACCEPTANCE_AUDIT=NOT_RUN`, preserve the gate evidence, and stop. Do not wait, reprogram, run F4L, change threshold/delock floor/PI/gain/timeout, or infer a frequency-acceptance policy from an invalid runtime.

## Actual outcome

The build and programming stages succeeded. Master was healthy, but the Slave gate was invalid: link was up while `WDIAGS_PTP=8 UNCALIBRATED`, Helper was not locked, and Main was disabled. The conditional F4J command was therefore correctly not executed.
