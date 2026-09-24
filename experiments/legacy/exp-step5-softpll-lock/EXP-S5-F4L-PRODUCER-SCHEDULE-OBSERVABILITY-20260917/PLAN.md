# EXP-S5-F4L-PRODUCER-SCHEDULE-OBSERVABILITY-20260917

## Purpose

Locate the first missing boundary in the existing passive F4L producer path:

```text
Main enabled
  -> F4L page selector
  -> page due
  -> page publication
  -> observer page
```

The previous F4L smoke produced valid page 0/1 frames but no page 2.  The
current result is not enough to distinguish a Main-enable discontinuity from a
producer scheduler problem, a publication problem, or observer aliasing.

## Fixed scope

This is a diagnostic-only firmware/observer experiment.  Main/Slave/Master
control parameters, PI gains, thresholds, detector behavior, anti-windup,
DAC behavior and order, timeouts, bootstrap, arbiter, mailbox, PHY, reset
tree, RTL, SDB, task cadence, and the Main enable condition remain unchanged.

The only firmware addition is a read-only F4S shadow in the existing private
`0x1e0..0x1fc` diagnostic tail.  It publishes a seqlocked magic, Main enable
state, enable-rise/fall evidence, page selector, page advance/reset counters,
and page2 due/publish counters.  It does not feed back into any control path.

The only observer addition is a read-only reader for that shadow and offline
classification.  It does not request a PI snapshot, drain a debug FIFO, or
start a second reader.

## Smoke contract

- Laptop offline tests must pass before push.
- Pain pulls the exact Laptop commit, builds and programs once.
- One single-reader F4S session is run with a 10 s smoke window and a
  12 s target / 13 s hard bound.
- If the schedule shadow is not valid after the smoke window, stop and retain
  the raw capture.
- The F4S result is diagnostic only.  `STEP5_PASS=NO` unless an independent
  Step5 lock criterion is satisfied; this experiment cannot establish it.

## Offline and hardware evidence required

Record the exact source/build/program/observer commits and hashes, the raw
schedule words, publication sequence checks, Main enable fall/rise counters,
page selector, page advance/reset, page2 due/publish counters, observed F4L
pages, link/PHY state, generation/reset counters, and stop reason.

## Classification

1. `F4S_MAIN_ENABLE_DISCONTINUITY`: enable fall/reset evidence rises while
   page2 due remains zero.
2. `F4S_PAGE2_NOT_SCHEDULED`: Main remains enabled, selector stays in 0/1,
   and page2 due remains zero.
3. `F4S_PAGE2_DUE_BUT_NOT_PUBLISHED`: page2 due rises but page2 publish does
   not.
4. `F4S_PAGE2_PUBLISHED_BUT_NOT_OBSERVED`: producer page2 publish rises but
   the F4L observer sees no page2.
5. `F4S_FULL_PAGE_ROTATION`: observer sees pages 0, 1, and 2 and producer
   page2 publish rises.

Anything else is `F4S_INCONCLUSIVE`; do not extend the capture or change
control parameters automatically.
