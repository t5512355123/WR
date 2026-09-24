# EXP-S5-MAIN-PHASE-KI0-HELPER-CORRELATION-20X500-20260919

## Verdict

```text
HELPER_ACQUISITION                  = PASS
HELPER_LOCK_ACQUIRED_AND_HELD       = YES
DCO_SERVICE_ACTIVE                  = YES
DCO_ERROR                           = 0
PHASE_KI0_MECHANISM                 = NOT_EVALUATED
F4L_SMOKE                           = NOT_RUN
STEP5_RESULT                        = NOT_REACHED
STOP_REASON                         = HELPER_LOCK_ACQUIRED_AND_HELD
```

This is a Helper acquisition/continuity result only. It is not evidence that the Main phase-Ki=0 candidate improved or that Step5 passed.

## Provenance

```text
experiment                         EXP-S5-MAIN-PHASE-KI0-HELPER-CORRELATION-20X500-20260919
source commit                      db7e0be12fcf1268059b916be6a21437da286fdd
prior gate report commit           13a52fcd
session                            same freshly programmed Ki=0 session
Slave SOF SHA256                   fa5de2430152190f61eb54c63506103a7ce7f676b0e0945f02a1957baa65ae60
Master SOF SHA256                  7e5ef99bc74d9f8e65d147a68d28a2c47985800d7422e84eb224632034b32dee
command                            quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 20 500
remote start/end                   2026-09-19 22:13:28 / 22:13:57 (Pain)
```

The initial unqualified `quartus_stp` invocation was rejected by the Pain shell because Quartus was not on `PATH`; it produced no hardware samples. The result below is from the one valid invocation using the confirmed absolute Quartus path.

## Observation

The command completed all 20 configured samples with zero Quartus/Tcl errors.

### Slave (`DE5 [1-11.2]`)

The returned trace showed the Helper in the locked state for the later consecutive samples, with no drop during the remainder of the 20-sample capture:

```text
HELPER_STATE = 03E80001
              locked = 1
              lock_count = 1000
HELPER_ERROR  approximately -230 ... +348 in the visible consecutive samples
STEP_DELTA    approximately 557 ... 580 and non-zero
STEP_EVENT    = 1
ERROR         = 0
```

The Helper update count continued to increase. This meets the advisor's lock-continuity stop condition: lock count reached 1000 and remained locked in subsequent samples; the DCO step progressed and no DCO error appeared.

### Master (`DE5 [1-11.1]`)

The Master trace remained in its expected non-running Helper state (`HELPER_STATE=00060100`, large fixed diagnostic error, `STEP_DELTA=0`). This is not used as the Slave Helper acquisition gate for this experiment.

## Interpretation boundary

The previous direct gate had stopped before Main activation. This trace now establishes that the Slave Helper can acquire and hold lock with active DCO transactions, but it does not establish that the Main phase branch executed. Therefore:

```text
Helper acquisition boundary       PASS
Main enabled/phase Ki=0           NOT CONFIRMED
Ki=0 mechanism                     NOT EVALUATED
Step5 lock                        NOT CONFIRMED
```

No F4L was run, as required by the stop rule.

## Raw capture note

The trace was intentionally executed once interactively in the existing Pain session. The remote PTY response was not redirected to a file and the desktop tool returned a truncated transcript. `raw/trace-summary.md` preserves the command, visible key fields, sample-range evidence, and classification; it is not presented as a complete byte-for-byte raw dump.

## Next action gate

Before any next experiment, report this result to the phase-lock advisor and wait at least 10 minutes for the next reply. The advisor's stated next technical gate, subject to that re-review, is one direct runtime confirmation of Helper locked + Main enabled + stable link/reset state; only then may a 10-second Ki=0 F4L mechanism smoke run.
