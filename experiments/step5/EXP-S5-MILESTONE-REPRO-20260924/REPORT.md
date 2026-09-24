# EXP-S5-MILESTONE-REPRO-20260924

## Verdict

```text
STEP5_MILESTONE_REPRODUCTION = IN_PROGRESS
FROZEN_SOURCE_PACKAGE        = PASS (3190 historical Git blobs)
OFFLINE_TESTS                = PASS (11/11)
MASTER_INITIAL_COMPILE       = PASS_BUT_REJECTED_WRONG_EMBEDDED_VERSION
MASTER_CLEAN_BUILD           = REBUILD_REQUIRED
SLAVE_CLEAN_BUILD            = NOT_RUN
MASTER_PROGRAM               = NOT_RUN
SLAVE_PROGRAM                = NOT_RUN
300S_FOUR_LOCK_VALIDATION     = NOT_RUN
```

No Step 5 reproduction PASS is claimed in this initial report.

## Candidate and historical evidence

Candidate historical experiment:
`experiments/legacy/exp-step5-softpll-lock/EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920/`.

The historical report records Helper/HPLL lock, Main frequency lock, Main
phase lock, and PSTAT lock for 300.321 seconds. Its historical SOF hashes are
not used as the reproduction verdict; the rebuilt source and hardware result
are authoritative for this experiment. The historical strict-analysis caveat
of four repeated page-accounting rows will remain visible in the final report.

## Frozen source provenance

- Historical firmware/Quartus source commit:
  `26e138fdc0bfc8426704b397141d563cf4d580a2`.
- Observer-only 300-second contract commit:
  `47d9a394e53eda31476c82de2a85ad82573494ed`.
- Frozen candidate source location: `source/`.
- Source verifier and package generator: `analysis/`.

The package contains only path-relocated build inputs, the observer-only
overlay, and explicitly identified reproduction tooling. Build products are
not source inputs.

## Source identity issue found before programming

The first Master full compilation completed successfully, but its generated
firmware MIF did not match the historical MIF hash. The source and firmware
configuration blobs were independently verified as exact; the cause was the
upstream WRPC Makefile's `git describe` version fields resolving through the
candidate package's parent checkout. The compiled firmware contained
`master-diagnostic-baseline-20260817-1359-g59317b4d`, while the frozen Step 5
source commit resolves to
`master-diagnostic-baseline-20260817-1175-g26e138fd`.

The initial Master SOF was **not programmed**. Its full build log, firmware
log, build identity, generated MIF, and BIN are preserved under
`raw/build/attempt-unpinned/`. A separate Step 5 build wrapper now pins only
the upstream build-version variables to the frozen source description; it
does not modify firmware source, RTL, or control behavior. The package and
both boards must be rebuilt before programming. Historical MIF hashes remain
the pre-program gate for this correction; any residual difference must be
explained before proceeding.

## Build, program, runtime

Results will be entered here only after the respective operation is performed
and its raw evidence is saved under `raw/build/`, `raw/program/`, or
`raw/observe/`.

## Next action

Verify the candidate snapshot against its historical Git blobs, run its
offline tests, then push the frozen package to `feat/file_cleanup` so Pain can
pull the exact same source before clean compilation.
