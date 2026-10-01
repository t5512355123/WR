# EXP-S6-PRETRACK-COHERENT-CKO-SETP-20261001 — Report

## Initial status

```text
SOURCE/SCRIPT PREFLIGHT          = PASS (3 analyzer tests; Bash syntax check pass)
PAIN IMAGE PREFLIGHT             = PASS (build metadata and both SOF hashes)
READ_ONLY_CAPTURE                = STOPPED AT TRUST GUARD (1.422 s)
READ_VALID_ROWS                  = 5
COHERENT / PAIRED_CONTEXT_ROWS   = 0 / 0
SAME_FRAME_CKO_ROWS              = 0 TRUSTED
TRACK_PHASE                      = NOT_OBSERVED
STEP6_STABLE_OFFSET              = NOT_ESTABLISHED
```

This is a 30-second diagnostic on the existing image/session, not a smoke or
Step 6 acceptance capture. No controller change, build, programming, reset,
or power cycle is planned. See [`PLAN.md`](PLAN.md).

## Image/session and observer result

The wrapper verified that both current build-info records and SOFs matched the
frozen `a62c264d` candidate. Both expected cables were present and no
competing `quartus_stp` process existed. The observer was strictly read-only.

The 30-second request ended after five consecutive untrusted rows:

```text
actual duration                 = 1.422 s
READS_VALID                     = 5 / 5
COHERENT                        = 0 / 5
DIAG_EPOCH_STABLE               = 0 / 5
DIAG_FRAME_VALID                = 0 / 5
PHASE_CONTEXT_VALID             = 5 / 5
PHASE_CONTEXT_FRAME_VALID       = 0 / 5
PHASE_CONTEXT_MATCH             = 5 / 5
SERVO_STATE                     = WAIT_OFFSET_STABLE (5), 5 / 5
stop                            = five_consecutive_untrusted_samples
WB timeout/read errors          = 0 / 0
```

Read-valid but untrusted payload values were CKO `+1752 ps` (2 rows) and
`+1755 ps` (3 rows), DMS `178256 ps` (3 rows) and `178260 ps` (2 rows), and
SETP `3862 ps` (5 rows). Because the publication epoch changed during each
critical group, none of those CKO/DMS/SETP values is accepted as a coherent
pair; they are retained only as raw read context, not as a threshold verdict.
The Servo remained in state 5 in all five read-valid rows. No TRACK entry or
Step 6 result was observed.

The observer completed normally after its explicit trust guard; the wrapper
and Quartus returned success, which does not turn the five rows into valid
measurements. This run establishes that `phase_context=1` cannot obtain a
stable same-publication frame in this high-update session. The next diagnostic
will use the observer's separate-frame `phase_context=2` mode and require an
exact UCNT match; it will keep all control behavior and the programmed image
unchanged.

## Raw evidence and integrity

Pain-to-Laptop SHA-256 matched:

```text
raw/observe/20261001T035957Z-pretrack-phase-context.log
  745dbf82c9b8f7561823ad14930910b17e81d21538038e6ae4bc847430bbce3a
```

The existing fixed-SETP analyzer was run independently on Pain and Laptop.
Both reported 5 read-valid rows, 0 coherent/paired/trusted rows,
`SERVO_STATE=5` in all rows, and `STEP6_STRICT_OFFSET_300S_STABILITY=NOT_ESTABLISHED`.
