# EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-20260920

## Verdict

```text
F4L_HARDWARE_RUN                 = COMPLETED_TO_TARGET
F4L_CAPTURE_FILE                 = PRESENT
F4L_CAPTURE_SHA256               = e14fdac3cf0ceb27ae938f9d0f90adab3e51a04c0c87273241ce251121aaffb4
F4L_RUNTIME_CAPTURE              = PASS
F4L_STRICT_SCHEMA_ANALYSIS       = CAVEAT
PHASE_KI1_FLAG_RETENTION         = PASS_WITH_ACCOUNTING_CAVEAT
PSTAT_LOCK_RETENTION              = PASS
PHASE_KI1_INTEGRATOR_ACTIVITY    = PASS
FUNCTIONAL_STEP5_LOCK            = PASS_WITH_ACCOUNTING_CAVEAT
STEP5                            = NO
```

The single advisor-approved corrected recapture completed normally on the
same live `threshold20 + phase-Ki1` image.  The required producer-level lock
evidence was retained for the full observed window: every unique Main frame
was in the phase branch and reported frequency lock after the update plus
phase lock before and after the update.  Helper, PHY, PSTAT, terminal, and
reset guards remained healthy on every valid Slave cycle.

This is strong evidence that the Ki1 image held functional Main phase lock
for the 120-second F4L window.  It is not yet the repository-level `STEP5 =
PASS`: timing closure remains open, and the strict offline frame analyzer
reported four rows with internal page-counter consistency warnings.  Those
four rows are two repeated frame identities; they do not change the required
lock flags, but they are retained as an explicit evidence caveat.

## Frozen provenance and procedure

```text
source/control commit       = 26e138fdc0bfc8426704b397141d563cf4d580a2
Pain worktree source        = 5d7d1a46784581dd1396daeb5a24624b62b1c440
live image                  = same direct-gate-admitted threshold20 + phase-Ki1 image
program/reset/power-cycle   = none in this corrected recapture
control parameters          = unchanged
direct-gate admission       = EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-CAUSAL-20260920
capture preflight           = PASS
reader processes            = 1
control writes              = none
```

The preceding invalid attempt is retained in the earlier version of this
report's history: the observer reached its target, but the Pain output
directory did not exist after a plan-only pull.  That attempt had no usable
raw artifact and was not used as evidence.  The corrected run first created
and tested `raw/observe`, then executed the one permitted formal capture.

## Command and capture artifact

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  2400 100 "" 120000 130000 f4l

quartus_exit              = 0
run_end_reason            = TARGET_REACHED
stop_reason               = NONE
session_elapsed_ms        = 120276
target_duration_ms        = 120000
hard_duration_ms          = 130000
smoke_ok                  = 1
Slave diag_valid          = 127
Slave diag_unique         = 64
Slave duplicates          = 63
Slave page0/page1/page2   = 42/43/42
Main progress intervals   = 63
```

Raw log:

```text
raw/observe/f4l_threshold20_phase_ki1_stability_recapture_120s.log
SHA256 = e14fdac3cf0ceb27ae938f9d0f90adab3e51a04c0c87273241ce251121aaffb4
```

The local checksum matches the checksum emitted by Pain.  The complete
observer output and its checksum are committed beside this report.

## Main producer lock retention

The 64 unique frame identities were decoded using the checked-in
`spll_main_diag.h` flag definitions:

```text
BRANCH_ID=2 (PHASE)                         = 64/64
FLAGS=383 (0x17F)                           = 64/64
FREQ_LOCK_BEFORE                           = 64/64
FREQ_LOCK_AFTER                            = 64/64
PHASE_LOCK_BEFORE                          = 64/64
PHASE_LOCK_AFTER                           = 64/64
PHASE_CALLED                               = 64/64
PHASE_IN_BAND                              = 64/64
PHASE_OUT_OF_BAND                          = 0/64
DAC_WRITE                                  = 64/64
PI_CLAMP_CODE=0                            = 64/64
```

The observed unique-frame `FREQ_ERROR` range was `-31 .. +33` counts.  The
frame-level result therefore satisfies the advisor's lock-retention rule:

```text
BRANCH_ID=PHASE
FREQ_LOCK_AFTER=1
PHASE_LOCK_BEFORE=1
PHASE_LOCK_AFTER=1
```

## Runtime health and causal guards

Across all 127 valid Slave F4L cycles:

```text
HELPER_LOCKED              = 127/127
PHY_LINK_USABLE            = 127/127
PSTAT_LOCKED               = 127/127
TERMINAL=0                 = 127/127
TERMINAL_FRESH_EDGE=0      = 127/127
RESET_CHANGED=0            = 127/127
INIT_GENERATION            = 1 (stable in all unique frames)
SPLL_DELOCK_COUNT          = 0
```

The Main F4L update ID advanced from `14683464` to `15140058`; 63 of the
126 adjacent Slave cycle intervals showed progress.  No reprogramming,
reset, power-cycle, control write, second formal, direct gate, or F4J audit
was performed after the corrected capture.

## Ki1 integrator accounting

The independently sampled page-1 window shows actual Ki1 activity:

```text
phase_i_count_delta             = 456594
phase_actual_i_sum_delta        = 189886
phase_ki_x_sum_delta            = 189886
frequency_i_count_delta         = 0
frequency_actual_i_sum_delta    = 0
frequency_ki_x_sum_delta        = 0
clamp_event_count_delta         = 0
anti_windup_event_count_delta   = 0
actual_delta_mismatch_delta     = 0
```

The nonzero phase actual-I and Ki-X sums directly support:

```text
phase Ki=1 -> integrator moves -> residual bias is corrected
```

Page windows are intentionally treated as independently sampled and are not
claimed to be one-cycle atomic causal records.

## Normalized comparison

The same page-counter normalization used by the frozen threshold20/Ki0 F4L
formal is recorded in `analysis/normalized-comparison.md`.

```text
mean phase-conditioned frequency error = 0.002580
mean modulo phase drift magnitude     = 0.000214
boundary crossing rate                = 0.000000%
phase in-band ratio                   = 100.000000%
```

Relative to the frozen threshold20/Ki0 formal (`10.358250`, `10.358036`,
`0.128861%`, `10.465809%` respectively), all four observed directions are
strongly positive.  The page counter window used for these ratios is not
atomic with the individual F4L frame stream; the report therefore uses these
metrics as normalized window evidence, not as a single-cycle claim.

## Offline validation and caveat

The checked-in offline analyzer was run and its JSON output is:

```text
analysis/f4l_stability.json
```

It found 123 strictly schema-consistent rows and four rows with:

```text
SUMMARY_PHASE_COUNT_MISMATCH       = 2 repeated observations
HISTOGRAM_PHASE_COUNT_MISMATCH     = 2 repeated observations
```

The observer itself marked all 127 rows `MAIN_F4L_VALID=1` and transport
coherent, and the two affected frame identities still carried the same
`FLAGS=383` lock evidence.  The strict analyzer result is therefore retained
as a caveat rather than silently discarded:

```text
strict analyzer classification = FRAME_SCHEMA_INVALID
lock-flag retention            = PASS
runtime guard retention        = PASS
```

The five existing F4L offline regression tests were also executed manually
with the bundled Python runtime; all passed.  The optional pytest runner is
not installed in this environment.

## Step5 boundary and next decision

This corrected capture closes the functional evidence boundary for the
current Ki1 candidate, subject to the explicit accounting caveat above:

```text
FUNCTIONAL_MAIN_PHASE_LOCK_120S = SUPPORTED
```

The complete repository Step5 verdict remains `NO` because:

```text
Slave WNS  = -0.361 ns
Master WNS = -0.289 ns
TIMING_CLOSED = NO
```

No automatic tuning, reprogramming, or merge action is authorized from this
report.  The corrected raw, report, and analysis are now ready for advisor
review before any further experiment.
