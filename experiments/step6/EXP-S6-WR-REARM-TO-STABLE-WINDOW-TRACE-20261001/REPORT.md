# EXP-S6-WR-REARM-TO-STABLE-WINDOW-TRACE-20261001

## Verdict

~~~text
IMPLEMENTATION = OFFLINE_VALIDATED
PRODUCTION_CONTROL_CHANGES = NONE
TCL_POLICY_TESTS = PASS (341 assertions; Tcl 8.6.12)
TCL_OBSERVER_SYNTAX = PASS (info complete; Tcl 8.6.12)
PYTHON_ANALYZER_TESTS = PASS (6 tests)
WRAPPER_BASH_SYNTAX = PASS
LOCAL_GIT_DIFF_CHECK = PASS
PAIN_SOURCE_SYNC = PENDING
PINNED_SOF_HASH_PREFLIGHT = PENDING
PROGRAMMING = PENDING
HARDWARE_CAPTURE = PENDING
RECOVERY_ADMISSION_SUPPORTED = NOT_ESTABLISHED
PASS_300S_SAMPLED_STABLE_OFFSET = NOT_ESTABLISHED
STEP6_STABLE_OFFSET = NOT_ESTABLISHED
~~~

## Baseline

- Repository: <https://github.com/t5512355123/WR>
- Branch: `feat/file_cleanup`
- Source audit baseline: `00d1a6a5154238700bbcd674e2638a0e6f15932e`
- Candidate build source: `9c9afa345c1de03760ec9ee07eb742888c3fa8fe`
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`
- Expected Slave SOF SHA-256:
  `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19`
- Expected Master SOF SHA-256:
  `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a`

## Implementation and scope

This iteration adds a single Slave passive observer, a source-independent
policy module, mock tests, a conservative analyzer, and a bounded Pain wrapper.
The observer brackets each WDIAGS publication and Global-Time snapshot
separately, records individual A6C/A8C and event-word read times, and counts
only unique UCNT publications in a qualifying 300-second window.

No production control, firmware, RTL, build source, or SOF content is changed.
No compile is part of this experiment. The exact pinned SOFs must be verified
before the single authorized Slave-then-Master programming sequence.

## Validation and hardware evidence

Laptop offline checks passed: 341 Tcl policy assertions cover failure-word
decode, initial S_LOCK → timeout → PRESENT → S_LOCK → success admission,
valid sticky-disable stopping, invalid-frame streaks, same-UCNT payload
conflict, cached-publication rejection, unique-UCNT progression, strict ±60 ps,
and the 300-second window. The complete observer is Tcl-syntactically complete
under Tcl 8.6.12; six Python analyzer tests and the Bash wrapper syntax check
also pass. No production or build-source file was changed.

Pain synchronization, pinned-image provenance/hash preflight, programming,
and the one bounded hardware capture remain pending. If the pinned images do
not match exactly, do not program. Raw logs, programmer logs, source/image
hashes, and analyzer output will be retained under this experiment's `raw/`
and `analysis/` directories with checksums.

## Interpretation

Until the one capture completes, no recovery-admission or stable-offset result
is established. Even if sampled 300-second criteria pass, that result is not
continuous-between-samples proof and does not measure SMA physical edge skew.
