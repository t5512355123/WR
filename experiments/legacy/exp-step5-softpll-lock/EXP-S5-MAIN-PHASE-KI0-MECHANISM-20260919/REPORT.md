# EXP-S5-MAIN-PHASE-KI0-MECHANISM-20260919

## Verdict

```text
PHASE_KI0_MECHANISM = NOT_EVALUATED
CONTROL_RESULT = INVALID
STEP5_RESULT = NO
F4L_SMOKE = NOT_RUN
STOP_REASON = DIRECT_RUNTIME_GATE_NOT_READY_HELPER_MAIN
```

This is not a causal failure of the phase-Ki=0 candidate. The required runtime
prerequisites were not present after programming, so no phase-Ki conclusion is
allowed.

## Provenance

```text
branch = exp/step5-softpll-lock
source_commit = db7e0be12fcf1268059b916be6a21437da286fdd
experiment = EXP-S5-MAIN-PHASE-KI0-MECHANISM-20260919
pain_worktree = /home/b10504072/pain-worktrees/EXP-S5-MAIN-PHASE-KI0-MECHANISM-20260919
offline_tests = 18/18
```

The source candidate changes only the Main phase-branch effective Ki. Main
frequency Ki remains 1. Kp, boost, thresholds, lock samples, timeout, Helper
PI, bootstrap, bumpless preload, PHY, RTL, and reset behavior were not changed.

## Build and program

Pain pulled the exact commit into a clean detached worktree. Firmware and both
Quartus JTAG revisions compiled successfully with zero errors. The existing
timing caveat remains:

```text
Slave WNS = -0.361 ns
Master WNS = -0.289 ns
TIMING_CLOSED = NO
```

```text
Slave SOF SHA256  = fa5de2430152190f61eb54c63506103a7ce7f676b0e0945f02a1957baa65ae60
Master SOF SHA256 = 7e5ef99bc74d9f8e65d147a68d28a2c47985800d7422e84eb224632034b32dee
```

Programming succeeded on both cables:

```text
Slave  = DE5 [1-11.2]
Master = DE5 [1-11.1]
```

## Direct runtime gate

The gate was collected after a short startup wait in the same freshly-programmed
session with one `read_wb_runtime.tcl --raw` invocation. Transport returned RC=0.

### Master

Master remained a non-target endpoint for this Step5 gate. Its Step1/Step2/Step3
and Step4A diagnostics were reported PASS; Step5 is not applicable to the Master
reader path.

### Slave DE5 [1-11.2]

Upstream link was healthy:

```text
SI_CONFIG_DONE       = 1
CORE_TM_LINK_UP      = 1
CORE_LINK_OK         = 1
WR_RX_READY          = 1
WR_TX_READY          = 1
WR_RX_LOCKED_TO_DATA = 1
```

However, the Step2/Step4B prerequisite was not ready:

```text
WDIAGS_PTP       = 8 UNCALIBRATED (raw=0x00004108)
STEP4B_ALLOWED   = NO
STEP4B_RESULT    = BLOCKED_BY_STEP2
STEP5_RESULT     = UPSTREAM_NOT_READY
```

The corresponding raw SoftPLL state was:

```text
spll_state        = 0x00030004
spll_helper_state = 0x00640000
spll_main_state   = 0x00000000
```

The Helper was not locked and Main was not enabled. Consequently the advisor's
direct gate (`link PASS + Helper locked + Main enabled`) failed, and the F4L
mechanism smoke was correctly not started.

Reset and generation stability were not the blocker:

```text
BOOT_GENERATION       before=1 after=1 delta=0
CPU_RESET_COUNT       before=1 after=1 delta=0
WR_CORE_RESET_COUNT   before=1 after=1 delta=0
SI_CONFIG_DROP_COUNT  before=1 after=1 delta=0
```

## Interpretation

This round does not measure whether phase Ki=0 removes the shared-integrator
cancellation term. It only establishes that the freshly-programmed session did
not reach the required Helper/Main startup boundary. It must therefore not be
classified as candidate negative, candidate positive, or Step5 progress.

The correct boundary is:

```text
PHY/WR link = PASS
Step2 PTP calibration = NOT READY
Helper lock = NOT READY
Main enabled = NOT READY
F4L = NOT REACHED
Step5 = NOT REACHED
```

## Evidence

- [PLAN.md](PLAN.md)
- [direct_runtime.log](raw/observe/direct_runtime.log)
- [Pain build evidence](raw/pain/build/sof-manifest.txt)
- [Pain program evidence](raw/pain/program/program-manifest.txt)

Local direct-runtime SHA256:

```text
DF6A5D94279BDD7C52708F2DDB819C7A2AA7F0E617BD032C00BFF12579FBC3B
```

## Next action

Do not reprogram repeatedly, do not run F4L, and do not alter PI/gain/threshold/
timeout. Send this stopped result to the phase-lock advisor, wait the required
freshness interval, and read the newest reply before selecting another
experiment.
