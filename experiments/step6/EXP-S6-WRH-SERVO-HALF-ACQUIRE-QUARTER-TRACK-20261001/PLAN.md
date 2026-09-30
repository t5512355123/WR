# EXP-S6-WRH-SERVO-HALF-ACQUIRE-QUARTER-TRACK-20261001

## Objective

Test whether halving only the `WRH_SYNC_PHASE` acquisition correction lets the
Slave repeatedly enter and remain inside the strict `-60 ps < CKO < 60 ps`
band, while retaining the already-tested `/4` TRACK correction. The target is
a fully qualified 300-second sampled window; a build, lock indication, or
single in-band sample is not a pass.

## Baseline and single change

- Branch: `feat/file_cleanup`.
- Baseline: `31abe502bfc6e1eb324e9cd3eff065e7315c1c89`.
- Production source: `vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c`.
- Baseline `WRH_SYNC_PHASE`: `cur_setpoint_ps += offset_ps`.
- Candidate `WRH_SYNC_PHASE`: `cur_setpoint_ps += (offset_ps / 2)`.
- `WRH_TRACK_PHASE` remains `offset_ps / 4`.
- The strict 60 ps entry threshold, 120 ps TRACK exit guard, ten-miss retry,
  Step 5 lock controls, PTP/DMS behavior, RTL, SDB, and timing constraints
  remain unchanged.

The measured plant response motivates this candidate: the prior half-step
trial recorded a `-184 ps` residual with a `-92 ps` SETP change, followed by
residuals `-74 ps` and `-1 ps`. That is promising acquisition evidence, not a
300-second result. The quarter-acquire/quarter-track run is the strongest
repeated in-band baseline so far (351/957 samples, longest fully-qualified run
3.099 s), but it did not meet the requested dwell.

## Laptop validation and publish

1. Run the candidate-specific source-contract test and `git diff --check`.
2. Confirm the production diff changes only the acquisition expression and
   that the frozen Step 6 milestone source/artifacts are unchanged.
3. Commit and push the source, test, and this plan to `origin/feat/file_cleanup`.

## Pain build, program, and observation

1. Fast-forward `/home/b10504072/04_WR` to the exact pushed commit. Preserve
   all unrelated work and stashes. Never access
   `/home/b10504072/04_WR_archive_step6_pass/`.
2. Confirm the checkout is clean, required Master/Slave cables are visible,
   no other Quartus/JTAG session is active, and the build paths resolve inside
   `/home/b10504072/04_WR`.
3. Build Master and Slave firmware, then their complete Quartus projects from
   this commit. Record logs and both SOF SHA-256 values.
4. Program Slave first, then Master, once each. Record programmer results.
5. Use one read-only JTAG session at a time. First run two 15-second Slave
   smokes with `phase_context=2`:

   ```sh
   quartus_stp -t scripts/jtag/read_step6_servo_interleaved_offset.tcl \
       15000 500 1-11.2 2
   ```

   Smoke quality requires at least 20 rows, at least 75% valid UCNT-matched
   phase-context rows, valid Step 1/Global-Time/all-five-Step-5 gates on the
   rows counted toward acceptance, no reset or transport error, and at least
   one strict in-band CKO sample before starting the 300-second acceptance
   capture.
6. If both smokes pass, run one 300-second capture with the same reader and
   arguments, changing the duration to `300000` ms. Sampled stability passes
   only if every accepted unique CKO row is strictly in `(-60 ps, +60 ps)`,
   all required gates are valid, UCNT-matched context is valid, no accepted
   sample gap exceeds 1000 ms, and no reset occurs.
7. Preserve raw data, hashes, build/program logs, and exact stop reason. Stop
   on link/Step 1 loss, reset/generation change, Global-Time loss, any Step 5
   lock dropping, transport error, or five consecutive invalid frames.
   An out-of-band CKO disproves this candidate's 300-second dwell; retain the
   bounded capture evidence and do not claim PASS.

### Provisional acquisition trace if the post-program wait expires

This is a read-only fallback proposal, not an authorization to start another
capture. Review the requested adviser response before launching it.

If the 600-second Global-Time readiness wait expires while Step 1 and all five
lock registers remain healthy but Global Time is still invalid, do not start
the acceptance reader (it treats invalid Global Time as an untrusted row). On
the same programmed boot, run the already-published read-only
`scripts/jtag/read_step6_servo_acquisition_context.tcl` once. It records
separately guarded CKO/SSTAT/UCNT and SETP/DMS context without requiring valid
Global Time, with up to 300 seconds ARMING and 600 seconds of health-ready
acquisition. Do not reset, reprogram, or launch a second JTAG reader. This is
diagnostic data only; it does not replace either smoke or the 300-second
acceptance capture. If the trace reaches a trusted `TRACK_PHASE` endpoint
while Step 1 and all locks remain ready, run the same 15-second
`phase_context=2` smoke on that boot; proceed to the acceptance capture only
if the smoke passes.

## Report and iteration

Transfer Pain evidence to Laptop, verify hashes, analyze accepted rows, and
complete `REPORT.md`. Push the report commit. If the strict dwell is not
established, use the new evidence to select the next single control change;
do not alter multiple gains or thresholds together. Timing closure is not a
functional acceptance gate.
