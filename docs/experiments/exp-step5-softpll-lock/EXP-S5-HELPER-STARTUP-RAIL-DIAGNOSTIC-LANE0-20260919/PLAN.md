# EXP-S5-HELPER-STARTUP-RAIL-DIAGNOSTIC-LANE0-20260919

## Objective

Diagnose the current Step4B/Helper startup boundary after QSFP-A lane-0 link
recovery.  The previous lane-0 run had a usable WR link but reported
`HELPER_ERROR=150000`, `HELPER_OUTPUT=5`, `HELPER_LOCKED=0`, and no Main F4L
frame.  This experiment must distinguish a real Helper low-rail condition
from a stale/signed/packing or target/applied-service observation error.

This is a read-only diagnostic experiment, not a Step5 pass claim and not a
control-parameter experiment.

## Frozen hardware/control contract

- QSFP-A lane 0 route stays fixed for Master and Slave.
- Helper Kp/Ki: `-2250 / -2`.
- Helper bias/range: `5 / [5, 65531]`.
- Helper threshold/lock samples: `2000 / 1000`.
- Slave guard/bootstrap: `8 s / 3388`.
- Main Kp/Ki/boost remains `300 / 1 / 20`.
- No changes to gain, threshold, timeout, bootstrap, detector, anti-windup,
  DAC behavior/order, arbiter, mailbox, PHY, reset, RTL, or SDB.

## Allowed change

Only `scripts/jtag/read_step5_helper_pi_state_rail_audit.tcl` and offline
tests/experiment documents are changed.  The observer uses the existing
serialized diagnostic snapshot request contract.  Its WB writes are limited
to the diagnostic request/trigger registers; it performs no SoftPLL, DAC,
DCO, control, arbiter, mailbox, PHY, or reset write.

The observer is corrected to validate the current Helper contract rather than
the obsolete `Kp=-150, Ki=-1` contract.  It records:

- raw/preclamp Helper error and PI before/i_new/after;
- output, clamp side, lock count and rail fractions;
- target/applied position and normal request/completion/DCO-step deltas;
- bootstrap state, generation/reset stability, WR/link gate and transport;
- atomic snapshot ACK/epoch and double-read consistency.

## Execution order

1. Run the offline observer/static regression checks.
2. Push this source to GitHub.
3. On Pain, pull the exact pushed commit, build the unchanged Master/Slave
   lane-0 diagnostic images, and program the normal cables (`DE5 [1-11.1]`
   Master and `DE5 [1-11.2]` Slave).
4. Run a 10-second Slave smoke with one reader and no control write:

   ```text
   quartus_stp -t scripts/jtag/read_step5_helper_pi_state_rail_audit.tcl 100 100 "DE5 [1-11.2]" 1
   ```

5. Continue to a 120-second Slave formal capture only if the smoke has valid
   frames, stable generation/reset/link, and no stop condition.  Keep the
   hard limit at 130 seconds for that capture.
6. Copy raw logs/checksums back to Laptop, analyze offline, write the report,
   and push only this experiment's report files.

## Stop conditions

Stop immediately and classify the run as diagnostic/session failure if the
smoke has no valid frame, schema/identity mismatch, snapshot ACK/epoch
failure, a new reset/generation/config drop, WR terminal, link loss, transport
failure, or three consecutive PHY/Helper regressions.  Do not extend the
deadline, retry until a favorable result, or tune a control parameter.

## Decision boundary

- Low rail with coherent positive residual error and no applied progress:
  supports a Helper operating-point/actuator-authority hypothesis; it does
  not authorize a control change in this run.
- Coherent target/applied service with Helper still unlocked:
  move the diagnosis to Helper measurement/phase dynamics, not Main F4L.
- Invalid/incoherent snapshot:
  report the observer/session failure only.

`STEP5_PASS` remains `NO` unless an independent Step5 acceptance capture is
later completed.  No merge is approved by this plan.
