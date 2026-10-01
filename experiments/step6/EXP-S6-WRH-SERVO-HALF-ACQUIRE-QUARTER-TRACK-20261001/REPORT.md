# EXP-S6-WRH-SERVO-HALF-ACQUIRE-QUARTER-TRACK-20261001 — Report

## Current status

```text
CANDIDATE = WRH_SYNC_PHASE /2; WRH_TRACK_PHASE /4
LAPTOP_SOURCE_TEST = PASS (3/3)
GITHUB_PUSH = PASS (ba9514c555edc672dff4eea9cfa5690d614a20a4)
PAIN_PULL = PASS (exact candidate commit)
PAIN_FIRMWARE_BUILD = PASS (Master + Slave)
PAIN_QUARTUS_FULL_COMPILE = PASS (Master 0 errors; Slave 0 errors)
JTAG_PROGRAM = PASS (Slave then Master; programmed SOF hashes match build inputs)
POST_PROGRAM_READY_WAIT = EXPIRED (600 s; Slave Global Time invalid)
ACQUISITION_TRACE = PENDING_SAME_BOOT_READ_ONLY_CAPTURE
STABLE_OFFSET_300S = NOT_ESTABLISHED
```

This is an in-progress experiment record. The candidate built and programmed
successfully, but this run did not establish stable offset or Step 6 PASS.

The first post-program one-shot showed Slave Step 1/link and all five Step 5
lock registers high, but the servo was still in `SYNC_TAI` at
`+1,312,121,377 ps`. After a bounded 600-second dashboard readiness wait, the
final sample was `WAIT_OFFSET_STABLE`, `+925 ps`, `TIME_VALID=0`,
`PPS_VALID=0`; the host-side wait expired. No smoke or 300-second acceptance
capture was run. A dedicated read-only acquisition trace is planned on the
same boot because the acceptance reader requires valid Global Time and would
otherwise stop on untrusted rows.

## Initial scope

Baseline commit: `31abe502bfc6e1eb324e9cd3eff065e7315c1c89` on
`feat/file_cleanup`. The only production change is the acquisition correction
in `vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c` from the full measured
offset to half the measured offset. TRACK remains `/4`; threshold, fallback,
retry count, Step 5 controls, PTP/DMS, RTL, SDB, and timing constraints are
unchanged. The frozen Step 6 milestone package is not modified.

Prior evidence: the `/4` acquire + `/4` track experiment sampled 351/957
strictly in-band rows, with a longest fully-qualified run of 3.099 seconds.
The earlier half-acquisition trial observed a correction sequence of `-184 ps`
CKO, `-92 ps` SETP delta, then residuals `-74 ps` and `-1 ps`, but did not
establish a 300-second dwell. This experiment tests that acquisition change
with the `/4` tracking baseline and the full acceptance reader.

## Results

- Laptop candidate tests: 3/3 passed (half-step acquisition, unchanged
  quarter-step tracking, and unchanged threshold/retry/exit guard).
- Pain pulled exact source commit `ba9514c555edc672dff4eea9cfa5690d614a20a4`.
- Master and Slave firmware builds and full Quartus compilations succeeded.
  Quartus reported existing warnings (Master 297, Slave 299); timing closure
  was not a criterion for this functional experiment.
- Slave was programmed before Master. Build-input and programmed SOF hashes
  match:

  ```text
  Slave  7abf7fe8decea08f884e48b61f0161b8410f8907e70a0622cad129b02131ea49
  Master 01260f6f0f511782025bbbc19a20d35eec684744ecbdd61e8f14b76ed446ae83
  ```

- The initial post-program sample showed Slave Step 1/link and all five Step 5
  lock registers high, while the servo was in `SYNC_TAI` at `+1,312,121,377 ps`.
- The bounded 600-second Global-Time readiness wait expired. Its final sample
  had Step 1/link and all five lock registers high, state
  `WAIT_OFFSET_STABLE`, CKO `+925 ps`, `TIME_VALID=0`, and `PPS_VALID=0`.
  The dashboard reported `LOCK_ACQUIRED_NOT_STABLE`.
- The readiness log contains 51 host polls from 7 through 607 seconds; every
  poll kept Step 1/link and the five lock flags high while Global Time remained
  invalid and the result remained `LOCK_ACQUIRED_NOT_STABLE`. These poll lines
  do not carry per-sample CKO/SETP/DMS/state measurements, so they establish
  persistent readiness status, not an offset trajectory. The initial CKO is
  from the separate post-program snapshot; the final `+925 ps` is the only CKO
  reported by the bounded-wait dashboard.
- No 15-second interleaved smoke or 300-second acceptance capture was run.
  Therefore these endpoint observations do not prove a stable trend or a
  causal mechanism; `STABLE_OFFSET_300S=NOT_ESTABLISHED` and Step 6 remains
  unproven.
- The Pain build, programming, and dashboard evidence was copied without
  modification to `raw/pain-run-20261001/`. The next action is a same-boot
  read-only acquisition trace, implemented by this experiment's durable
  wrapper. It is not gated on outside review. No reset or reprogram was
  performed after the bounded wait.
