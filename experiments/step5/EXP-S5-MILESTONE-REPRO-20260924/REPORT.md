# EXP-S5-MILESTONE-REPRO-20260924

## Verdict

```text
STEP5_MILESTONE_REPRODUCTION = IN_PROGRESS
FROZEN_SOURCE_PACKAGE        = NOT_YET_VERIFIED
MASTER_CLEAN_BUILD           = NOT_RUN
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

## Build, program, runtime

Results will be entered here only after the respective operation is performed
and its raw evidence is saved under `raw/build/`, `raw/program/`, or
`raw/observe/`.

## Next action

Verify the candidate snapshot against its historical Git blobs, run its
offline tests, then push the frozen package to `feat/file_cleanup` so Pain can
pull the exact same source before clean compilation.
