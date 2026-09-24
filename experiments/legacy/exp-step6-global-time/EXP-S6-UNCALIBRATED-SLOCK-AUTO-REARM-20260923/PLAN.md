# EXP-S6-UNCALIBRATED-SLOCK-AUTO-REARM-20260923

## Objective

Recover Slave WR extension and Global Time when the WR `S_LOCK` timeout occurs
while the PTP state machine is still `PPS_UNCALIBRATED`.

## Evidence leading to this experiment

The previous endpoint-recovery image restored both boards' Step 1 link gate.
The read-only Slave attribution then showed:

```text
PTP_STATE=9 after fallback
WR_DISABLE_PTP_STATE=8
WR_FAILURE_REASON=3 (WR_S_LOCK_TIMEOUT)
WRC_MODE=3 (Slave)
PD_STATE=4
EXT_STATE=2 (PTP fallback)
WR_STATE_VALUE=0 (WRS_IDLE)
TIME_VALID=0
```

At the same time, Helper, Main frequency, Main phase, Main lock, and PSTAT
were asserted. This places the failure after link recovery and SoftPLL lock:
the timeout was recorded in `PPS_UNCALIBRATED` (state 8), but the existing
auto-rearm guard only accepted `PPS_SLAVE` (state 9). That left the existing
terminal fallback path active and discarded the WR parent context.

## Single source change

In `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/common-fun.c`, permit the
existing narrowly-scoped S_LOCK auto-rearm path when the PTP state is either
`PPS_UNCALIBRATED` or `PPS_SLAVE`.

Keep all other guards unchanged: failure must still be `WR_S_LOCK_TIMEOUT`,
the configured role must still be WR Slave, and the stored parent must still
be a WR Master or WR Master/Slave node. All other handshake failures retain
the existing fallback behavior.

No changes to PHY configuration, endpoint retry timing, PI/gain/threshold,
SoftPLL, PPS logic, timing constraints, reset behavior, or hardware wiring.

## Laptop-side validation and handoff

1. Run the new offline source-contract test.
2. Push this exact source and plan to `feat/file_cleanup`.
3. On Pain, pull the exact pushed commit, build both boards, and program Slave
   then Master once.
4. Save build/program checksums and raw runtime observations.

## Runtime gates and stop conditions

Run a read-only dashboard observation for at least 420 seconds after the
programming sequence. Do not declare a pass from a single snapshot.

Required:

- Both boards recover Step 1/2; Slave Step 3 and Step 4 pass.
- Slave Helper lock, Main frequency lock, Main phase lock, Main lock, and
  PSTAT remain asserted for at least 300 continuous seconds.
- Slave Global-Time `TIME_VALID`, `PPS_VALID`, and snapshot validity become
  true and remain valid; its snapshot counter advances.
- A same-PPS Master/Slave comparison passes before calling Step 6A complete.

Stop and preserve raw evidence if either board resets, link drops, JTAG data
becomes invalid, the Slave re-enters terminal fallback, or the Slave does not
recover Global Time within 120 seconds after its Step 1 and lock gates are
ready. Classify Step 5/Step 6 separately; a lock-only result is not Step 6
PASS. Step 6B scheduled dual-board trigger remains out of scope for this
experiment.
