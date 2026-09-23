# EXP-S6-ENDPOINT-LINK-AUTO-RECOVERY-20260923

## Question

Can the DE5a endpoint recover a persistent WR-link startup failure without a
manual reprogram, while the dashboard continues to report Step 1 and Step 6
against their actual gates?

## Baseline evidence

At 2026-09-23 21:48 local time, a fresh read-only dashboard showed both boards
with `WR_RX_READY=1` and `WR_TX_READY=1`, but `CORE_TM_LINK_UP=0` and
`CORE_LINK_OK=0`. A six-sample endpoint attribution capture then showed:

- Both boards had `SI_CONFIG_DONE=1`, `WR_READY=1`, `CPU_RESET_N=1`, and
  endpoint TX/RX enabled in the valid samples.
- Both receivers had changing recovered-clock activity; the Slave also had
  comma/pattern detection, but neither endpoint reached PCS sync or link-up.
- Reset and boot-generation counters did not change.
- Master PPS snapshots remained valid while its link gate was down. The shell
  dashboard rendered this retained time snapshot as Step 6 `VALID`, although
  the Tcl reader's Step 6 result includes the link gate.

The source audit found that firmware calls `ep_enable()` only during startup;
the link monitor observes link-down transitions but does not retry endpoint
PHY initialization while link remains down.

## Single functional change

Add a bounded-backoff endpoint recovery in `wrc_main.c`:

- Wait 30 seconds of continuous link-down before the first retry.
- Stagger Slave retries by 15 seconds so the Master endpoint gets the first
  recovery opportunity.
- Restart the existing endpoint/PHY initialization through `ep_enable()`.
- Increase retry spacing up to a five-minute cap; reset the backoff after link
  returns.
- Keep the existing PHY settings, link criteria, PTP state machine, SoftPLL,
  reset tree, and board pin mapping unchanged.

## Dashboard correction

Require both the Tcl reader's Step 1 and Step 6 gate results in the display
and wait condition; the Tcl Step 6 result itself also requires Step 1 PASS.
Retained, coherent TAI/cycle snapshot data may still be shown, but it must be
labelled as unqualified snapshot data when either gate has not passed. In
particular, link-down Master holdover must not render as a Step 6 PASS.

## Verification contract

1. Run the dashboard formatting/wait regression tests with synthetic records.
2. Push this source revision before Pain builds or programs it.
3. Build Master and Slave on Pain and record compiler results and SOF hashes.
4. Program Slave, then Master, once.
5. Observe read-only Step 1..6 status for at least 300 seconds after link
   recovery. Require both boards' role-applicable Step 1/2/3/4/6 gates to
   pass; Master Step 3 may remain informational. Require Slave Step 5 Helper,
   Main-frequency, Main-phase, Main-lock, and PSTAT signals to remain asserted
   for the Step 5 300-second criterion.
6. Re-run the Step 6 same-PPS consistency check and scheduled dual-board
   trigger/re-arm test on the recovered live session before closing the
   Step 6 milestone.
7. If any gate fails or data becomes invalid, preserve the capture and report
   the first failing boundary. Do not declare the milestone passed from stale
   PPS data or from SOFTPLL lock bits while Step 1 is down.

This experiment does not claim a PASS before the Pain runtime evidence is
collected.
