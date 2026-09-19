# EXP-S5-MAIN-FREQ-THRESH20-CAUSAL-20260920

## Verdict

```text
THRESH20_IMPLEMENTATION = PASS
HELPER_ACQUISITION = PASS
HELPER_LOCK_ACQUIRED_AND_HELD = YES
THRESH20_CONTROL_RESULT = MAIN_NOT_YET_EVALUATED
THRESH20_CAUSAL_RESULT = NOT_YET_EVALUATED
STEP5 = NO
STEP5_RESULT = MAIN_START_NOT_YET_EVALUATED
```

The Slave Main frequency-lock threshold override was implemented and observed in
the programmed runtime image.  The first direct snapshot showed the Helper
before lock, so the dashboard reported an upstream Step2/Step4B boundary.  The
bounded follow-up correlation on the same live session then showed the Helper
acquiring and holding lock.  Main startup and the threshold causal effect were
not evaluated in this experiment.  This is not evidence that threshold 20
failed, and it is not evidence that the acceptance-margin hypothesis is
confirmed.

## Scope and source provenance

This was the single causal candidate requested by the phase-lock analysis:

```text
Slave Main freq_ld.threshold: 50 -> 20
Master Main threshold:       50 (unchanged)
Slave AUX threshold:          50 (unchanged)
```

All other control and diagnostic settings were frozen.  In particular, no
PI/gain, phase Ki, delock floor, timeout, bootstrap, arbiter, mailbox, PHY, RTL,
or SDB changes were made, and F4J was not run in this round.

Source commit:

```text
165d25ae29eba4a8265c75b66d33a0c55ce2e2c4
```

The source implementation is identity-scoped: the Slave identity defines
`DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE=20`, while `spll_main.c` retains the
default 50 and applies the override only for a WR-node Main output
(`dac_index == 0`).  The Master identity does not define the override.

Offline checks completed before the hardware run:

```text
test_step5_threshold20.py  = PASS (3 tests)
test_step5_f4l.py          = PASS (5 tests)
offline total              = 8 PASS
```

## Build and programming

Clean JTAG build completed successfully with zero Quartus errors.  Timing
remains the known implementation caveat, not a threshold20 functional result:

```text
Slave worst-case setup slack  = -0.361 ns
Master worst-case setup slack = -0.289 ns
```

SOF artifacts:

```text
Slave  964891814cead5b8d2ef67ad301826d1c5fdc586341cfd30a6f4500f39693328
Master 7c7fa79ae41018c0ec65b871d58faad7c903401e43b40a2b968b4d50598477c1
```

Programming completed successfully:

```text
Slave  = DE5 [1-11.2]
Master = DE5 [1-11.1]
```

## Runtime observation

Exactly one read-only `read_wb_runtime.tcl --raw` capture was performed after
programming.  No F4J capture followed it.

Raw file:

```text
raw/observe/direct_runtime.log
SHA256 = 6d0b7fb6bbaee8159e1c02f8c32d74b0142d6316c18fcbe52eddb25da1c83c6e
quartus_exit = 0
```

JTAG/WB transport was trusted during the capture:

```text
WB_REQUEST_COUNT = 355
TIMEOUT_COUNT    = 0
INVALID_COUNT    = 0
PROBE_3WAY_MATCH_COUNT = 355
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
```

### Master, DE5 [1-11.1]

The Master remained healthy and preserved its default threshold:

```text
Step 1 PHY/link       = PASS
Step 2 Endpoint/PTP   = PASS
Step 4A event chain   = PASS
Step 5                = NOT_APPLICABLE_MASTER

spll_main_limits      = 00320032
```

The Master link, event counters, boot generation, CPU/WR reset counters, and
SI-config drop counter were stable during the before/after snapshot.

### Slave, DE5 [1-11.2]

The Slave link and transport prerequisites were alive, but the PTP state was not
calibrated:

```text
Step 1 PHY/link       = PASS
WDIAGS_PTP            = 8 UNCALIBRATED (raw=00004108)
Step 2                 = NA
Step 3 WR handshake    = PASS
Step 4B                = BLOCKED_BY_STEP2
Step 5                 = UPSTREAM_NOT_READY
```

The threshold implementation proof is direct and present in both before and
after raw snapshots:

```text
spll_main_limits = 00320014
```

This decodes as:

```text
lock_samples = 0x0032 = 50
threshold    = 0x0014 = 20
```

The other relevant Slave runtime state was:

```text
spll_helper_state = 00000000
spll_main_state   = 00000000
spll_init_count   = 1
```

Thus the Helper/Main closed-loop operating state required for a threshold
causal comparison was not reached.  The Slave boot generation, CPU reset count,
WR-core reset count, and SI-config drop count all remained unchanged at 1; RX
error delta was 0.  These stable infrastructure counters make this an upstream
readiness result, not a reset or link regression.

## Interpretation

The direct implementation gate passed:

```text
Slave Main threshold 20 = observed
Master Main threshold 50 = preserved
```

However, the runtime did not satisfy the advisor's control-evaluation entry
condition (`Helper locked` and active Main).  Because Slave PTP was still
uncalibrated, the existing runtime classifier correctly stopped at Step2 and
did not enter Step4B.  Therefore this capture cannot answer whether narrowing
the acceptance margin changes frequency-branch occupancy, handoff behavior, or
phase convergence.

No Step5 lock was observed or claimed.  No F4J follow-up was run, and no further
programming was performed after the candidate image was installed.

## Bounded Helper correlation

Following the advisor's diagnosis, the same freshly-programmed threshold20
image and live session were observed once with:

```text
read_hpll_helper_correlation.tcl 20 500
samples = 20
gap     = 500 ms
quartus_exit = 0
```

Raw file:

```text
raw/observe/helper_correlation.log
SHA256 = d615ab2003a326226e8df9541f3f3fb3dcd15ac8b87aa3be55a85a08654eef6b
```

The Slave samples provided the required Helper result:

```text
HELPER_STATE = 03E80001 throughout the 20-sample window
HELPER_LOCK_COUNT = 1000
HELPER_ERROR absolute maximum observed = 336
STEP_DELTA        = non-zero after the initial sample
HELPER_UPDATE_COUNT = advancing
DCO ERROR          = 0 in every sample
```

The Helper therefore acquired and held lock, and its service path remained
active.  The correlation ended normally at sample 20.  Per the experiment
stop rule, it was not extended and was not followed by F4J or another runtime
capture.

## Next action boundary

Stop this experiment here.  The next round may evaluate whether Main starts and
how the threshold20 Main detector behaves, but must not reinterpret the Helper
result as a Step5 lock or as a completed threshold causal test.  Do not run F4J
in this round and do not change another control parameter.
