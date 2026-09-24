# EXP-S5-MAIN-FREQ-THRESH20-F4L-HELPER-CORRELATION-20260920

## Objective

Determine whether the Slave Helper in the already-programmed threshold20 + F4L
diagnostic image completes acquisition after the previous direct gate stopped at
`SEQ_WAIT_HELPER`.

## Current image and session

```text
FPGA/source commit       = 00d7572fa4943dbba1e28b2245f884fc04386a94
previous gate report     = EXP-S5-MAIN-FREQ-THRESH20-F4L-DIAGNOSTIC-GATE-20260920
Slave main limits        = 00320014
Master main limits       = 00320032
F4L diagnostic owner     = 1 on Master and Slave
```

The FPGA image is already programmed and the current live session must be
preserved. This is a read-only continuation; there is no production source
change, recompile, or reprogram in this round.

## Allowed action

Run exactly one bounded Helper correlation on the same live session:

```text
quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 20 500
```

Capture complete stdout and checksum the raw file. Stop at sample 20 under all
outcomes. Do not run `read_wb_runtime` afterward and do not run formal F4L.

## Required evidence

For the Slave, preserve and evaluate:

```text
HELPER_STATE
HELPER_LOCKED
HELPER_LOCK_COUNT
HELPER_ERROR_SIGNED
HELPER_UPDATE_COUNT
STEP_DELTA / STEP_EVENT
DCO_ERROR / BUSY
SPLL_STATE / sequence state
```

## Classification

If the later samples show `HELPER_LOCKED=1`, lock count 1000, helper error
within the lock band, nonzero step/update activity, DCO error 0, and preferably
`SPLL_STATE=00030006`, classify Helper acquisition as PASS and stop. Formal F4L
remains not run.

If Helper remains unlocked but update/step activity continues with DCO error 0,
classify `HELPER_ACQUISITION_NOT_CONVERGED=YES` and stop. Do not extend the
window or repeat the correlation.

If lock is intermittent, step activity is absent, DCO error appears, or the
runtime infrastructure regresses, record the corresponding invalid/intermittent
classification and stop.
