# EXP-S5-F4L-PRODUCER-SCHEDULE-OBSERVABILITY-20260917

## Verdict

**INCONCLUSIVE — blocked before Main SoftPLL enable; Step 5 is not passed.**

The passive F4S schedule frame was read successfully, but Main never reached
the enabled state required to diagnose page2 publication or phase convergence.

```text
F4S schema         = PASS (3 valid, 0 invalid schedule frames)
classification     = F4S_INCONCLUSIVE
diagnostic_pass    = NO
Step5              = NOT PASS
merge              = NOT APPROVED
```

## Provenance

Hardware commit:

```text
f847f4e74c5b16389c9848d4fe2592a9873a6b5c
fix: accept F4S observer role
```

The first invocation at `a11e9bfb` was invalid before SignalTap started
because the observer whitelist omitted `f4s`. It is preserved as
`raw/observe/observer-f4s-invalid-role.log` and is not hardware evidence.
The corrected observer was pulled, rebuilt, and reprogrammed at `f847f4e7`.

```text
JTAG_F4L_STEP5_BUILD=PASS
Quartus errors = 0
Slave SOF = a39f315806251fe39b0d8ba62ac7a2b9aa908d9bae5593e771086f8978f02a49
Master SOF = b163ca1b084550e34335403fb168d68a3799799b14cfe527c25e9775be56cea1
JTAG_F4L_SCHEDULE_OBSERVABILITY_PROGRAM=PASS
Slave cable = DE5 [1-11.2]
Master cable = DE5 [1-11.1]
```

Timing remained the existing implementation caveat:

```text
Slave worst-case setup slack  = -0.268 ns
Master worst-case setup slack = -0.047 ns
```

## Frozen scope

Only passive observability was added. PI, gain, threshold, timeout, bootstrap,
arbiter, mailbox, detector, anti-windup, DAC behavior/order, PHY, reset, RTL,
SDB, and control branches were unchanged. No QSFP port switch was performed.
The observer made no control write, Helper PI snapshot, debug FIFO drain, or
second-reader access.

The F4S frame uses the existing private diagnostic tail
`0x00100BE0..0x00100BFC`, magic `0x46345331`, and eight words. It is
non-atomic with the separate F4L frame.

## Capture

Command:

```text
timeout 60s quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 100 2000 "" 12000 13000 f4s
```

The valid capture ran for `13,538 ms`, with three Slave cycles and two Master
samples. It stopped with `F4L_NO_VALID_TIMEOUT`, not with a reader/schema
failure.

```text
schedule_valid       = 3
schedule_invalid     = 0
sequence             = 100, 110, 116
MAIN_ENABLED_CURRENT = 0 in all three frames
enabled rise/fall    = 0 / 0
page selector        = 0 in all three frames
page advance/reset   = 0 / 0
page2 due/publish    = 0 / 0
```

Upstream state in the same capture:

```text
Slave CORE_TM_LINK_UP    = 0
Slave CORE_LINK_OK       = 0
Slave PHY_LINK_USABLE    = 0
Slave PSTAT_LINK         = 0
Slave PSTAT_LOCKED       = 0
Slave HELPER_LOCKED      = 0
Slave HELPER_UPDATE_COUNT= 0
Main F4L frame            = invalid in all sampled cycles
```

The boards still reported `WR_READY=1`, `WR_RX_READY=1`, and
`WR_TX_READY=1`; those do not establish the required WR link gate. No reset
generation change occurred during the capture.

## Interpretation

The corrected offline analyzer reports:

```text
classification  = F4S_INCONCLUSIVE
diagnostic_pass = false
step5_pass      = false
```

This is not category A because no Main enable fall or reset rise was observed.
It is not category B because Main was never enabled. Categories C and D cannot
be evaluated because page2 was never due or published. The capture therefore
cannot identify page scheduling, Helper admission, or phase PI behavior.

The strongest conclusion is:

> The session is blocked upstream of Main SoftPLL enable by the current PHY/WR
> link state. Restore the prerequisite before using F4S to diagnose Step5.

This does not invalidate historical Step4B or Step5 results; this session
simply did not reach the prerequisite state.

## Offline checks

```text
py_compile                       = PASS
F4S_OFFLINE_TESTS_PASS           = PASS
F4S analyzer raw-word correction = PASS
```

The analyzer output is in `analysis/f4s-analysis.json`; all build, program,
valid-observer, and invalid-observer evidence is under `raw/`.

## Next action

Do not change PI or page/arbiter logic based on this capture. Restore and
verify the existing PHY/WR link prerequisite on the current path, then rerun
the same passive F4S capture unchanged. Only a capture with
`MAIN_ENABLED=1` can distinguish page2-not-scheduled from a later publication
boundary; only after that boundary is observed should formal F4L phase capture
be attempted.
