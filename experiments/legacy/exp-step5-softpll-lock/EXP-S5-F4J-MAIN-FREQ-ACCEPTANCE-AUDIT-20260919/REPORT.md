# EXP-S5-F4J-MAIN-FREQ-ACCEPTANCE-AUDIT-20260919

## Verdict

```text
SOURCE_IDENTITY_SWITCH             = PASS
BUILD                             = PASS
PROGRAM                           = PASS
MASTER_DIRECT_GATE                 = PASS
SLAVE_PHY_LINK                     = PASS
SLAVE_PTP_CALIBRATION              = INVALID (WDIAGS_PTP=8 UNCALIBRATED)
SLAVE_HELPER_LOCKED                = NO
SLAVE_MAIN_ENABLED                 = NO
DIRECT_RUNTIME_GATE                = FAIL_INVALID_RUNTIME
F4J_ACCEPTANCE_AUDIT               = NOT_RUN
F4J_30S_PRODUCER_AUDIT             = NOT_RUN
STEP5_RESULT                       = NO
STOP_REASON                        = FRESH_IMAGE_NOT_IN_REQUIRED_OPERATING_STATE
```

This run does not evaluate the F4J producer frames and does not prove or disprove the frequency-lock acceptance-policy hypothesis. The fresh programmed image did not satisfy the advisor's precondition: the Slave PTP state was uncalibrated, Helper was not locked, and Main was disabled. The run was stopped without waiting or changing any control parameter.

## Provenance

```text
experiment                         EXP-S5-F4J-MAIN-FREQ-ACCEPTANCE-AUDIT-20260919
branch                             exp/step5-softpll-lock
source/build commit                63bf952a3ea46dd0231f12d6d3e9b86d816ed953
source change                      DE5A_F4L_MAIN_PHASE_DIAG: 1 -> 0 in both identities
Slave SOF SHA256                   f70d688bd1e703177e4e59b713f8165d871fe4b3c735888b169ddea9526346a6
Master SOF SHA256                  7cbe368bab2f94a8e7276cb7d8f066ee386e02f8e072b686a6e2a9ca59b96f1c
build start                        2026-09-19 23:38:02+08:00
program end                        2026-09-19 23:52:02+08:00
direct gate                        2026-09-19 23:52:37-23:52:52+08:00
direct gate command                quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
F4J command                        NOT RUN (gate failed)
direct gate raw SHA256             6AE86B37B01C2B338D4BC4F298EB628122517816BBDB64696773C55BF3243F44
```

The complete build, program, and direct-gate logs are in `raw/`. The reported negative Quartus WNS values remain an existing implementation caveat; they are not used to claim a functional result in this invalid runtime.

## Source-control audit

The source diff was limited to the two identity definitions:

```text
firmware/configs/de5a_slave_identity.h: DE5A_F4L_MAIN_PHASE_DIAG 1 -> 0
firmware/configs/de5a_master_identity.h: DE5A_F4L_MAIN_PHASE_DIAG 1 -> 0
```

The build manifest also confirms that the PI and preload markers remained enabled, including `DE5A_MAIN_PI_KP_OVERRIDE=300` and `DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD=1`. No production control, RTL, SDB, timeout, detector, or route change was made for this experiment.

## Build and programming

Pain completed the fresh Slave and Master JTAG builds with zero compile errors and programmed both cables successfully:

```text
Slave cable     = DE5 [1-11.2]
Master cable    = DE5 [1-11.1]
build result    = success, warnings only
program result  = JTAG_F4L_SCHEDULE_OBSERVABILITY_PROGRAM=PASS
```

## Direct runtime gate

### Master (`DE5 [1-11.1]`)

```text
Step 1 PHY/link                  = PASS
Step 2 Endpoint/PTP              = PASS, WDIAGS_PTP=6 MASTER
Step 4A event chain              = PASS
BOOT_GENERATION delta             = 0
CPU_RESET_COUNT delta             = 0
WR_CORE_RESET_COUNT delta         = 0
SI_CONFIG_DROP_COUNT delta        = 0
```

The Master result is not the Step5 gate because closed-loop Step5 is evaluated on the Slave.

### Slave (`DE5 [1-11.2]`)

The upstream physical and transport state was healthy:

```text
SI_CONFIG_DONE                    = 1
CORE_TM_LINK_UP                   = 1
CORE_LINK_OK                      = 1
WR_RX_READY / WR_TX_READY         = 1 / 1
WR_RX_LOCKED_TO_DATA              = 1
RXERR delta                       = 0
```

However, the required PTP/SoftPLL operating state was absent:

```text
WDIAGS_PTP                        = 8 UNCALIBRATED (raw=00004108)
Step 2                            = NA
Step 3                            = PASS
STEP4B_ALLOWED                    = NO
STEP4B_RESULT                     = BLOCKED_BY_STEP2
STEP5_RESULT                      = UPSTREAM_NOT_READY
```

The direct raw snapshot is consistent with that gate result:

```text
spll_state                        = 00030004
spll_helper_state                 = 00640000
HELPER_LOCKED                     = 0
HELPER_LOCK_COUNT                 = 100 (floor shown in raw state)
spll_helper_limits                = 03E807D0 (threshold=2000, lock_samples=1000)
spll_main_state                   = 00000000
MAIN_ENABLED                      = 0
spll_helper_error (after)         = 0000430D
```

The raw helper error is outside the configured 2000-count acquisition threshold in this snapshot. This is an upstream acquisition observation only; it is not an F4J producer correlation result.

Runtime stability and the JTAG path were not the problem in this capture:

```text
BOOT_GENERATION delta              = 0
CPU_RESET_COUNT delta              = 0
WR_CORE_RESET_COUNT delta          = 0
SI_CONFIG_DROP_COUNT delta         = 0
WB transport                       = trusted
WB requests / 3-way matches        = 352 / 352
timeouts / invalid                 = 0 / 0
```

The diagnostic script printed `FAILURE_CLASSIFICATION=JTAG/DASHBOARD_MEASUREMENT_FAILURE` for the Step2 invalid state. This report preserves that script output but does not reinterpret it as a Step5 control failure: F4J never reached its producer-audit precondition.

## Non-results and boundary

The following were intentionally not measured in this run:

```text
FREQ_ERROR ↔ FREQ_COUNT_BEFORE/AFTER correlation = NOT MEASURED
BRANCH_ID / FLAGS / UPDATE_ID producer frames    = NOT MEASURED
acceptance-margin vs hysteresis classification   = NOT EVALUATED
F4J 30-second observer                            = NOT RUN
Step5 closed-loop lock                            = NO
```

The only defensible boundary from this experiment is:

```text
fresh F4J image programmed
        ↓
Slave link/transport healthy
        ↓
Slave PTP uncalibrated
        ↓
Step4B blocked by Step2
        ↓
Helper not locked; Main disabled
        ↓
F4J acceptance audit not run
```

No threshold, delock floor, PI/gain, timeout, bootstrap, detector, firmware control branch, RTL, or hardware route was changed after the gate failure. The next action requires advisor review of this invalid runtime; no new experiment is authorized by this report.
