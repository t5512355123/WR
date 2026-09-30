# EXP-S6-WRH-SERVO-QUARTER-ACQUIRE-REACQUISITION-TRACE-20260930 — Report

## Status

~~~text
IMPLEMENTATION = LOCAL_VALIDATION_PASS
PYTHON_OFFLINE_TESTS = 9/9 PASS
BASH_SYNTAX = PASS
TCL_PROC_COMPILE = PASS (Tcl 8.6.12 with hardware API stubbed)
GIT_DIFF_CHECK = PASS_FOR_NON_RAW_FILES
GITHUB_IMPLEMENTATION_PUSH = 0a656c98bfba12be04140537c00a09f6ba71ee28
PAIN_PULL = 0a656c98bfba12be04140537c00a09f6ba71ee28
PAIN_IMAGE_HASH_PREFLIGHT = PASS
SLAVE_PROGRAM = PASS
MASTER_PROGRAM = PASS
ACQUISITION_TRACE = STOPPED_EARLY_STEP5_LOCK_GATE_LOST_OR_INVALID
STEP6_STABLE_OFFSET = NOT ESTABLISHED
~~~

The observer implementation passed local offline checks. Tcl procedure
compilation used system Tcl 8.6.12 with the Quartus hardware API stubbed; the
actual observer also parsed and exited successfully under Pain's Quartus 17.0
runtime. Both exact existing SOFs were hash-verified and programmed successfully
without rebuilding. The trace stopped on its first row because Step 5 lock
gates were low immediately after programming; this does not adjudicate
acquisition or the fixed-SETP hypothesis.

## Scope

The only planned change is a dedicated, read-only acquisition observer and
durable raw-log/analyzer support. The Step 6 fixed-SETP candidate source and
both SOF images remain unchanged. See PLAN.md for baseline, hashes, validity
definitions, and stop criteria.

## Hardware result

Pain was fast-forwarded to `0a656c98bfba12be04140537c00a09f6ba71ee28` with a
clean worktree before programming. The existing image hashes matched the plan:

~~~text
Slave SHA-256 = 13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19
Master SHA-256 = 697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a
~~~

Quartus Programmer reported successful configuration on both cables, Slave
`DE5 [1-11.2]` first and Master `DE5 [1-11.1]` second. No compile or production
control-code change occurred.

The durable acquisition observer started after programming and stopped after
one sample:

~~~text
REQUESTED_DURATION_MS = 600000
ELAPSED_MS = 273
LAST_ROW_START_MS = 1
LAST_ROW_END_MS = 272
STOP_REASON = STEP5_LOCK_GATE_LOST_OR_INVALID
SAMPLE_COUNT = 1
STRUCTURALLY_TRUSTED_COUNT = 0
SERVO_STATE = 1
STEP1_GATE = 1
HELPER_LOCK = 1
MAIN_LOCK = 0
MAIN_FREQ_LOCK = 0
MAIN_PHASE_LOCK = 0
PSTAT_LOCK = 0
RESET_CHANGED = 0
~~~

That row showed Step 1 gate = 1 and HelperLock = 1, but MainLock,
MainFreqLock, MainPhaseLock, and PSTATLock = 0; reset signature did not change.
Primary and context WDIAGS frames were individually valid but did not join:
primary UCNT `0x2B`, context UCNT `0x2C`. Therefore the row is not used for CKO,
DMS, or SETP correlation; no latch trigger or TRACK sample was established.
This is an immediate post-program startup observation, not a six-hundred-second
acquisition result. The advisor has been sent the result; no further reset,
programming, or capture is being done while awaiting a revised next action.

The complete raw log is preserved at
`raw/observe/20260930T152531Z-acquisition.log`; its local SHA-256 matches the
Pain source and is recorded in `raw/SHA256SUMS`.
The capture is stored byte-for-byte; trailing spaces in the vendor's Quartus
license banner are intentionally preserved, so whitespace checks exclude this
raw evidence file rather than altering its checksum.
