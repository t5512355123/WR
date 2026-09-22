# EXP-S6-DASHBOARD-WR-HANDSHAKE-CLASSIFICATION-FIX-20260922

## Objective

Correct the read-only dashboard classification that treated a healthy Slave's
last-observed WR messages (`CALIBRATED`, `WR_MODE_ON`, etc.) and a single
`WRS_IDLE` mailbox sample as a Step 3 failure.

## Allowed scope

Only `scripts/jtag/read_wb_runtime.tcl` is changed. The change is diagnostic
classification only:

- exact `LOCK`/`SLAVE_PRESENT` messages remain PASS;
- any known WR signaling message `0x1000..0x1005` with a positive count is
  informational evidence, not a failure;
- unknown messages and zero counts remain warnings;
- a single `WRS_IDLE` sample is informational and is not by itself a failure;
- parent metadata, lock-enable, link/PTP, reset, SoftPLL, PI, DAC, PPS, RTL,
  SDC, QSF, and all control behavior remain unchanged.

The existing focused repeated handshake reader remains responsible for deciding
whether a multi-sample handshake history is complete. This compact dashboard
must not claim a 300-second Step5 stability result from one read.

## Procedure

1. Laptop modifies the read-only Tcl classifier and pushes the branch.
2. Pain pulls the exact commit, builds/programs the existing Slave and Master
   images, Slave first then Master.
3. Run one raw read and one human-readable dashboard capture.
4. Copy raw evidence to Laptop, write the report and checksums, and push the
   experiment record.

## PASS criteria

For the restored-link session, a known later WR message must no longer produce
`WR_RX_SIGNAL_DEBUG`/`WR_TX_SIGNAL_DEBUG` errors or `STEP3_REGRESSION=INVALID`.
The dashboard should show Step 3 as PASS when all other Step 3 gates are valid,
and Step 4B should be admitted for independent startup/event-chain evaluation.
Step 5 remains INFO until its separate stability-window/300-second criterion
is proven.
