# EXP-S6-FIXED-SETP-PRETRACK-LOCK-ATTRIBUTION-20261001 — Report

## Initial status

```text
SOURCE/WRAPPER_VALIDATION       = PASS (10 tests; Bash syntax check pass)
PAIN_IDENTITY_PREFLIGHT         = PASS (source metadata and both SOF hashes)
READ_ONLY_TRACE                 = COMPLETE (300 s)
SOURCE_BACKED_LOCK_EVENT        = NONE OBSERVED
TRUSTED_ROWS                    = 888 / 888
SERVO_STATE                     = WAIT_OFFSET_STABLE 819; SYNC_PHASE 69; TRACK 0
STEP5_LOCK_GATES                = ALL FIVE 1 in 888 / 888 rows
STEP6_STABLE_OFFSET             = NOT_ESTABLISHED
```

This observer-only run is intended to localize the current candidate's
pre-TRACK startup boundary. It does not test CKO stability and cannot change
the Step 6 verdict.

See [`PLAN.md`](PLAN.md) for the frozen image identity and stop rules.

## Frozen source and image identity

Pain was fast-forwarded to documentation commit
`b7df6fa4` on `feat/file_cleanup`. The programmed images remain the two SOFs
built from firmware/FPGA source commit `a62c264d`; no compile, programming,
reset, or power cycle was performed between the prior readiness dashboard and
this trace. The wrapper rechecked these SOF hashes before opening JTAG:

```text
Slave DE5 [1-11.2]  5af7150671dfb293acd82c68f47df9688fc1f23d40cf912ed3c6764467754018
Master DE5 [1-11.1]  9a0f1087c0dd75330c94cd7f24780359d4c3d89dacd7c207d734e29568d721c5
```

The expected two cables were present, the wrapper found no competing
`quartus_stp`, and the observer used the Slave only.

## Read-only trace result

The source-backed observer completed its 300-second no-event window:

```text
SAMPLES                         = 888
READ_VALID / REQUIRED_VALID    = 888 / 888
EVENT_EVIDENCE / CONTEXT_VALID = 888 / 888
WB timeout / invalid           = 0 / 0
RESET_CHANGED                  = 0
WR_STATE                       = WRS_IDLE in 888 / 888 rows
SOURCE_BACKED_EVENT_ROWS       = 0
LIVE_EVENT_TRIGGER_EDGES       = 0
STOP_REASON                    = NO_SUCCESS_EVIDENCE_OBSERVED_300S
```

Across the same 888 rows, every Step 5 lock gate was high, while the servo
never entered TRACK:

| Read-only field | Observations |
|---|---:|
| `HELPER_LOCK=1` | 888 / 888 |
| `MAIN_FREQ_LOCK=1` | 888 / 888 |
| `MAIN_PHASE_LOCK=1` | 888 / 888 |
| `MAIN_LOCK=1` | 888 / 888 |
| `PSTAT_LOCK=1` | 888 / 888 |
| `SERVO_STATE=5` (`WAIT_OFFSET_STABLE`) | 819 |
| `SERVO_STATE=3` (`SYNC_PHASE`) | 69 |
| `SERVO_STATE=4` (`TRACK_PHASE`) | 0 |

The source-mapped WR admission state remained `WRS_IDLE`; no S_LOCK handoff,
WRS_LOCKED state, or local TX LOCKED send was captured. The pre-existing WR
failure counter stayed at its initial value and did not trigger the observer's
new-failure stop rule. The analyzer independently returned
`NO_SUCCESS_EVIDENCE_OBSERVED_300S`, with all 888 required rows valid and no
reset change.

This distinguishes the current boundary more sharply than the previous
dashboard: **Step 5 lock flags can all be 1 while the phase servo alternates
between WAIT_OFFSET_STABLE and SYNC_PHASE without reaching TRACK_PHASE.** It
does not establish why the strict WAIT→TRACK condition is missed. This event
trace did not sample CKO, DMS, or SETP, and the non-atomic S_LOCK tail/counter
fields are not treated as causal evidence. A separate same-frame CKO/DMS/SETP
diagnostic is needed before choosing any control change.

## Raw evidence and integrity

The wrapper log and checksum sidecar were transferred byte-for-byte from Pain.
SHA-256:

```text
raw/observe/20261001T034223Z-pretrack-lock-attribution.log
  42d98479135e24c52d660819dfe57f8b047d1cc56893844e46574d45b3732881
```

Laptop reran the existing source-backed analyzer; the verdict and all row
counts matched Pain. The raw log retains the source observer's inherited
legacy `trial_id`; the unique wrapper run tag and this experiment's path
identify this capture.
