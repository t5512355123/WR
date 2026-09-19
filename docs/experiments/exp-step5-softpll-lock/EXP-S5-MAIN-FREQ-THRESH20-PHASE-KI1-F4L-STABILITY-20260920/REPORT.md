# EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-20260920

## Verdict

```text
F4L_HARDWARE_RUN                 = COMPLETED_TO_TARGET
F4L_CAPTURE_FILE                 = INVALID_MISSING_OUTPUT_DIRECTORY
PHASE_KI1_F4L_CAPTURE            = NOT_PROVEN
PHASE_KI1_LOCK_RETENTION         = NOT_PROVEN
FUNCTIONAL_STEP5_LOCK            = NOT_PROVEN
STEP5                            = NO
```

This was intended to be the single 120-second stability formal on the same
direct-confirmed `threshold20 + phase-Ki1` live image.  The observer itself
ran to its target, but the Pain `raw/observe` directory did not exist after
the plan-only pull.  Both `tee` and the final `sha256sum` therefore reported
`No such file or directory`; the complete stdout was not preserved as a raw
artifact.  Under the evidence contract this is an invalid capture, not a
functional pass or failure.

## Frozen provenance and admission

```text
source/control commit       = 26e138fdc0bfc8426704b397141d563cf4d580a2
Pain worktree after pull    = 5d7d1a46784581dd1396daeb5a24624b62b1c440
program/reset/power-cycle   = none in this round
control parameters          = unchanged
direct-gate admission       = report commit 28c603b0
```

The preceding direct gate had already established Main phase lock, PSTAT
lock, Helper lock, healthy link, and stable reset/generation state.  This
round did not change that image or state intentionally.

## Attempted command

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  2400 100 "" 120000 130000 f4l
```

The attempted output path was:

```text
docs/experiments/exp-step5-softpll-lock/EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-20260920/raw/observe/f4l_threshold20_phase_ki1_stability_120s.log
```

That directory was absent on Pain because Git does not track empty
directories.  The command nevertheless completed its observer run and the
terminal summary showed:

```text
quartus_exit       = 0
run_end_reason     = TARGET_REACHED
stop_reason        = NONE
session_elapsed_ms = 121052
diag_valid         = 127
diag_unique        = 64
duplicates         = 63
page0/page1/page2  = 42/42/43
smoke_ok           = 1
```

These terminal-only summary values are retained as diagnostic context, not as
the formal evidence artifact.  No raw SHA256 exists for this attempt, and no
offline unique-frame or Ki1-integrator analysis can be audited from the
missing file.

## Stop decision

The observer was allowed to finish naturally at its target.  No second formal
run, direct gate, F4J run, reprogramming, reset, or control change was made
after this invalid capture.  Because the raw artifact is missing, the report
does not claim `PHASE_LOCK_BEFORE/AFTER` retention, page-1 integral motion,
normalized metrics, or Step5 PASS.

The next action is deferred to the phase-lock advisor: specifically, whether
one corrected capture is permitted after creating the missing directory before
starting the formal observer.  Until that response, hardware remains stopped.
