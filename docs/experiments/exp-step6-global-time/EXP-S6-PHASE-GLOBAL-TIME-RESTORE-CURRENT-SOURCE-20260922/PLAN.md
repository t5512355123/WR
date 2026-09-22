# EXP-S6-PHASE-GLOBAL-TIME-RESTORE-CURRENT-SOURCE-20260922

## Objective

Restore the known-good fitted Step6 source on Pain and determine whether the
current link session can reproduce the previously observed Helper/Main phase
lock and valid Global-Time tuple (`TIME_VALID`, `PPS_VALID`, `TAI`, `CYCLES`).

## Why this experiment exists

The Laptop `exp/step6-Global-Time-Testing` source contains the fitted
Global-Time snapshot and Step6 scheduler wiring that was present in the
successful `c24568e3` Step6 run. Pain was previously using detached commit
`26e138fd`; that source is missing the fitted snapshot/SDC block. This run
therefore first verifies source identity and then builds from the pushed
Step6 branch.

## Allowed scope

- Laptop: source-identity guard and this experiment record only.
- Pain: pull the pushed branch, compile the existing Master/Slave JTAG
  diagnostic designs, program both DE5a boards, and perform read-only
  observation.
- No PI, gain, threshold, timeout, bootstrap, arbiter, mailbox, PHY, reset,
  or production SoftPLL control changes.
- No physical power-cycle in this experiment.

## Entry and stop conditions

Entry requires:

1. `SOURCE_CHECK=PASS` on the exact pushed commit.
2. Both boards program successfully.
3. The same dashboard and Global-Time/phase observers are used without
   Wishbone writes.

Stop immediately after the first valid observation window, or when the
dashboard/observer reports an upstream gate failure. Do not reprogram or
power-cycle repeatedly in the same session.

## Evidence to collect

- Source commit, branch, SOF SHA-256 and compile/program logs.
- Step 1--5 dashboard values, including Helper/Main frequency/phase/PSTAT.
- `TIME_VALID`, `PPS_VALID`, snapshot validity/stability, TAI and cycle.
- Paired Master/Slave Global-Time consistency and phase-lock status.
