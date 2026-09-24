# EXP-WRPC-STEP5-UPSTREAM-QSFPA-LANE1-PHY-VALIDATION-600S-20260901

## Scope and control invariants

This experiment changed only the WR transceiver data mapping from QSFP-A lane
0 to QSFP-A lane 1 on both the Master and Slave. QSFP-A and QSFP-B reference
clocks, the PHY functional configuration, firmware, and all SoftPLL/PI control
parameters were kept unchanged.

```text
BRANCH = exp/step5-softpll-lock
SOURCE_COMMIT = 7803da99aabe78482146aee035649bb455b5b419
FUNCTIONAL_SOURCE_CHANGE = QSFPA lane 0 -> lane 1 on Master and Slave
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

No PI equation, DMTD, tracker, FINC/FDEC, reset tree, or RXERR gate was
changed. The lane-0 unused-channel pre-emphasis assignment was removed after
Quartus correctly rejected that stale assignment when lane 0 became unused;
lane 1 retains the existing pre-emphasis value of 18.

## Build

Both projects completed a clean full compile after the lane-1 mapping change:

```text
LANE1_COMPILE_VALID = YES
Master COMPILE_RESULT = Full Compilation was successful
Slave  COMPILE_RESULT = Full Compilation was successful
Master FITTER_STATUS = Successful
Slave  FITTER_STATUS = Successful
```

Build identity:

```text
Quartus = Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition
Master SOF_SHA256 = b3dfe6a3fc5efe9cc9673bf50db5c3e12f666b500f8d8f27e1e2b0ade63f50de
Slave  SOF_SHA256 = 33908ab0679b90b66722898e1f61844d980e58bf82b34f947b1b9581c719dcee
Master WNS = -0.234 ns
Slave  WNS = -0.094 ns
Master TIMING_CLOSED = NO
Slave  TIMING_CLOSED = NO
```

The timing caveat is unchanged from the preceding image and is not used as a
lane-availability decision.

## Programming

Fresh programming was completed successfully:

```text
Master cable = DE5 [1-11.1]
Slave cable = DE5 [1-11.2]
Master programming = SUCCESS, 0 errors, 0 warnings
Slave programming = SUCCESS, 0 errors, 0 warnings
```

## Lane-1 link gate

The read-only runtime gate was run after programming using
`read_wb_runtime.tcl --raw`. Raw output was saved on pain at:

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-STEP5-UPSTREAM-QSFPA-LANE1-PHY-VALIDATION-600S-20260901/link-gate-runtime.log
```

### Master: DE5 [1-11.1]

```text
core_tm_link_up = 0
core_link_ok = 0
wr_rx_ready = 1
wr_tx_ready = 1
wr_rx_locked_to_data = 1
WDIAGS_MODE = 2 MASTER
WDIAGS_PTP = 6 MASTER
WDIAGS_RXERR delta = 0
STEP4A_MASTER_EVENT_CHAIN = PASS
```

The Master is running, but the WR timing/core link is not established.

### Slave: DE5 [1-11.2]

```text
core_tm_link_up = 0
core_link_ok = 0
wr_rx_ready = 1
wr_tx_ready = 1
wr_rx_locked_to_data = 1
wr_rx_enc_err = 1
WDIAGS_MODE = 3 SLAVE
WDIAGS_PTP = 4 LISTENING
WDIAGS_RXERR delta = 0
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_RESULT = UPSTREAM_NOT_READY
```

The Slave did not reach `PTP=SLAVE`; it remained in `LISTENING` because the
lane-1 WR link gate was not established.

## Formal result

Per branch5's lane-isolation rules, the 600-second PHY attribution phases were
not started because the basic lane-1 link precondition failed:

```text
LANE1_COMPILE_VALID = YES
LANE1_LINK_AVAILABLE = NO
QSFPA_LANE1_PHY_VALIDATION = NOT_RUN
RXERR_UPSTREAM_PRECONDITION = NOT_PASS
STEP4B_COMPLETE = YES (previous valid milestone)
STEP4B_REVALIDATED_BY_THIS_RUN = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This result does not by itself identify whether the cause is absent lane-1
fiber connectivity, the board lane mapping, or another common transceiver
path issue. It only proves that the lane-1 image compiled and programmed but
did not establish the required WR link on the current setup.

## Required next action

Stop this lane-1 experiment here and preserve the evidence. Do not scan lanes
2/3 automatically, modify reference clocks or regenerate the PHY, and do not
change SoftPLL/PI parameters. The next lane choice must be made by branch5
after reviewing this compile/program/link-gate result.
