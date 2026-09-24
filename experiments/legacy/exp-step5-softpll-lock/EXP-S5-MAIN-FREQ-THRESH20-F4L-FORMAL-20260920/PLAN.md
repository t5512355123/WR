# EXP-S5-MAIN-FREQ-THRESH20-F4L-FORMAL-20260920

## Objective

Run the formal 120-second threshold20 F4L observability capture now that the
same live session has passed the Helper and Main runtime admission gates.

## Frozen implementation and session

```text
FPGA/source commit        = 00d7572fa4943dbba1e28b2245f884fc04386a94
previous Main gate        = b4b3ae4a
Slave main limits         = 00320014
Master main limits        = 00320032
F4L diagnostic owner      = 1 on Master and Slave
```

The FPGA image and live session are already valid. This round is read-only:
do not recompile, reprogram, reset/power-cycle, or change any production
control parameter.

## Formal command

Capture complete stdout from the first line with `tee`:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  2400 100 "" 120000 130000 f4l
```

Normal completion is `run_end_reason=TARGET_REACHED` and `stop_reason=NONE`.
The hard limit is 130 seconds. If the observer emits any non-`NONE` stop
reason before the target, accept that early stop, preserve the raw output, and
do not rerun to compensate.

## Formal validity requirements

```text
quartus_exit = 0
F4L smoke = PASS
MAIN F4L valid > 0
MAIN F4L unique > 0
page0/page1/page2 observed
Helper healthy throughout
PHY usable throughout
generation/reset/SI-drop stable
no fresh terminal
Main producer progressed
```

Historical sticky failure/terminal candidates do not invalidate the capture if
the observer reports `TERMINAL_FRESH_EDGE=0` and `TERMINAL=0`.

## Metrics to report

Compare with the frozen threshold50/Ki0 baseline:

```text
mean residual frequency
mean modulo phase drift
boundary crossing rate
phase in-band ratio
frequency-branch updates
phase-branch updates
FREQ_TO_PHASE / PHASE_TO_FREQ
phase integrator and Ki contribution
clamp / anti-windup / mismatch
```

Regardless of the formal result, do not declare complete Step5 PASS without
the separately required functional and timing-closure evidence.
