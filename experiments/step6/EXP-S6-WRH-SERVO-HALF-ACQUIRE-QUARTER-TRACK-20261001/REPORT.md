# EXP-S6-WRH-SERVO-HALF-ACQUIRE-QUARTER-TRACK-20261001 — Report

## Current status

```text
CANDIDATE = WRH_SYNC_PHASE /2; WRH_TRACK_PHASE /4
LAPTOP_SOURCE_TEST = PENDING
GITHUB_PUSH = PENDING
PAIN_BUILD_PROGRAM = PENDING
HARDWARE_CAPTURE = PENDING
STABLE_OFFSET_300S = NOT_ESTABLISHED
```

This is an in-progress experiment record. No hardware result is claimed yet.

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

To be completed after laptop validation, Pain build/program, and bounded
read-only hardware observation. Until then, verdict remains
`STABLE_OFFSET_300S=NOT_ESTABLISHED`.
