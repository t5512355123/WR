# EXP-S6-FIXED-SETP-PRETRACK-LOCK-ATTRIBUTION-20261001

## Objective

Explain the pre-TRACK boundary observed on the currently programmed fixed-SETP
candidate. Its bounded dashboard run showed the Slave in `SYNC_TAI` for all 88
paired observations, with Step 1/link and WR handshake present, but no Helper,
Main, PSTAT, or Global-Time validity. The fixed-SETP latch was not reached.

Use one source-backed, read-only Slave WR lock/admission event trace to learn
whether the current session reaches `WRS_LOCKED`/sends `LOCKED`, records a new
S_LOCK failure, or remains in the pre-lock states. This is an upstream
readiness diagnosis only; it is not a CKO or Step 6 stability measurement.

## Frozen current hardware identity

- Pain repo: `/home/b10504072/04_WR`, branch `feat/file_cleanup`.
- Documentation/report sync commit: `cf5b57fcc96af11882bf158abea05a002bf3d35c`.
- Firmware/FPGA source used to build the images: `a62c264dbbfc15b31c316188dd7f851d28ec2a6d`.
- Slave SOF SHA-256: `5af7150671dfb293acd82c68f47df9688fc1f23d40cf912ed3c6764467754018`.
- Master SOF SHA-256: `9a0f1087c0dd75330c94cd7f24780359d4c3d89dacd7c207d734e29568d721c5`.
- These exact SOFs were successfully programmed Slave then Master immediately
  before the readiness run. No reset, reprogram, or power cycle occurred
  afterward; stopping the host dashboard did not reset either board.

This is an observer-only continuation on that still-running image. No
recompile/reprogram is performed: rebuilding or reprogramming would destroy
the continuous-session condition this trace is intended to inspect. The
wrapper must verify both saved build identities and SOF hashes before opening
the single JTAG observer.

## Observer and event contract

Reuse the already offline-tested
`scripts/jtag/read_step6_wr_lock_event_continuity_trace.tcl`. It performs
Wishbone reads only; it does not write a control register, request a diagnostic
snapshot, or use non-atomic counter arithmetic as an event.

Source-backed event words distinguish:

- `WRS_S_LOCK → WRS_LOCKED` handoff;
- current `WRS_LOCKED` state;
- a successful local TX `LOCKED (0x1002)` send (not proof of Master receipt).

The trace also retains Step 1/reset signatures, WR failure record/reason,
Helper/Main/PSTAT states, servo state, and the S_LOCK tail as explicitly
non-atomic context. A source event gets its configured 5-second post-event
window. Without an event, the Tcl observer ends after 300 seconds. The
external watchdog is 330 seconds. Its embedded legacy `trial_id` is unchanged;
this run is identified by this experiment directory, wrapper run tag, and raw
log path.

## Procedure

1. Laptop commits and pushes this plan/wrapper/report stub; Pain fast-forwards
   to that exact documentation commit.
2. Verify the build-info records point to source `a62c264d`, both SOF hashes
   match above, both expected cables are present, and no Quartus/JTAG reader is
   running. Do not access the protected archive.
3. Run `scripts/run_pretrack_lock_trace.sh` once. Do not overlap a dashboard,
   second reader, programming, build, reset, or power cycle.
4. Preserve the complete log and checksum, transfer them to this experiment's
   `raw/observe/`, analyze with the existing source-backed analyzer at
   `experiments/step6/EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001/scripts/`,
   update the report and Step 6 index, push the report, then stop before
   another hardware action.

## Stop conditions and verdict limits

Stop immediately for SOF identity mismatch, missing cable, another active
JTAG reader, fatal Tcl/JTAG error, reset/generation change, Step 1 loss after
establishment, five consecutive invalid required rows, or the observer's
source-backed failure-plus-three-terminal-state rule. Otherwise stop at the
observer's source event plus 5-second tail or at 300 seconds with no event.

Report `NO_SUCCESS_EVIDENCE_OBSERVED_300S` if no source event occurs; report a
source-backed failure/exit only when the script's explicit evidence supports
it. Counter deltas and S_LOCK tail fields remain context, not causal proof.
This experiment cannot establish CKO stability or Step 6 PASS. The fixed-SETP
latch remains untested until a later run actually records the strict
WAIT→TRACK transition.
