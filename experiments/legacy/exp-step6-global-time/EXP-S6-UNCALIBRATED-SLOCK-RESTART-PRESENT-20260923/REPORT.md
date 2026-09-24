# EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923

## Verdict

```text
STEP1_PHY_LINK                         = PASS
STEP2_ENDPOINT_PTP                     = PASS
STEP3_WR_HANDSHAKE                     = PASS (Slave role; Master INFO is expected)
STEP4_SOFTPLL_STARTUP                  = PASS
STEP5_FIVE_DIRECT_LOCKS_300S           = PASS (340 seconds)
STEP6A_GLOBAL_TIME_VALIDITY            = PASS
STEP6A_SAME_PPS_TIME_CONSISTENCY       = PASS
STEP6B_DIGITAL_DUAL_BOARD_TRIGGER      = PASS
STEP6_PHYSICAL_EDGE_SKEW               = NOT_EVALUATED
QUARTUS_TIMING_CLOSED                  = NO (separate implementation status)
```

The Step6B result proves that the two on-FPGA schedulers accepted one common
future Global-Time target and recorded the same firing label. It does not
measure physical output-pin skew; `0` here means equal labels at the 125 MHz
counter's 8 ns resolution.

## Why the earlier run failed

The prior re-arm path set the WR state to `WRS_IDLE` after an S_LOCK timeout.
When the PTP state was already `PPS_UNCALIBRATED`, no PTP state transition
occurred, so the normal transition hook that advances `WRS_IDLE` to
`WRS_PRESENT` never ran. The parent-detection event had already been consumed
and the Slave did not restart the WR handshake.

Commit `74dc28862653d306e0450cf437ba6d3a230d979d` keeps the existing S_LOCK,
WR Slave, and WR-parent guards, then chooses the restart state by PTP state:

- `PPS_UNCALIBRATED` starts directly at `WRS_PRESENT`.
- `PPS_SLAVE` retains `WRS_IDLE` and the existing PTP transition-hook path.

No Step5 PI/gain/threshold, timeout, SoftPLL, PPS generator, PHY, reset,
RTL, or SDC behavior was changed in this fix.

## Validation and runtime sequence

The Laptop-side source/recovery checks passed: 3 re-arm gate tests, 5 WR
fallback liveness contracts, 7 PTP restart/recovery contracts, and 3 Step6B
analyzer contracts (18 total). Pain built both boards from the exact commit
and programmed Slave then Master once. No physical power cycle or separate
PTP restart was used in this run.

The continuous dashboard capture started at `2026-09-24T00:08:59+08:00`.
It contains 58 complete samples. From `00:12:49` through `00:18:29`, 35
consecutive samples show all five direct Slave lock signals asserted:

```text
Helper/HPLL lock = 1
Main frequency lock = 1
Main phase lock = 1
Main lock = 1
PSTAT lock = 1
```

The interval between the first and last qualifying sample is 340 seconds;
every sample in that window passed. This meets the agreed Step5 functional
criterion. The dashboard's per-invocation `Step5Result` label is not used as
the stability verdict; the direct lock bits and timestamps are.

Step6A then passed on the same programmed session. Eight paired captures
produced five common PPS/TAI labels; all five had exact cycle agreement,
maximum absolute delta 0 ticks, and no mismatch. Both boards reported valid,
stable snapshots and unchanged reset counters.

For Step6B, the observer obtained three paired healthy pre-write samples,
three common time labels, and zero coherence violations. It wrote each board's
target once, then armed each board once. After arming, the observer only read
state. The result was:

```text
T0 = 1113
TARGET_TAI = 1133
TARGET_CYCLES = 62500000
MASTER actual = (1133, 62500000), fire count = 1
SLAVE  actual = (1133, 62500000), fire count = 1
POST_FIRE_HEALTHY_PAIRED_SAMPLES = 3
DIGITAL_TRIGGER_DELTA = 0 ticks
COHERENCE_VIOLATION = 0
RESET_OR_LINK_CHANGE = 0
```

The live observer itself reports `MASTER_PROGRAM=0`, `SLAVE_PROGRAM=0`,
`PTP_RESTART=0`, and `POWER_CYCLE=0`.

The first attempt to launch the live-session observer failed before producing a
capture: the shell's command-not-found handler raised `ModuleNotFoundError`.
That diagnostic is retained as
`raw/observe/step6b-live-session-74dc2886-20260924-command-not-found.log` and
is not used as runtime evidence. The subsequent `*-pathfixed.log` is the valid
capture used for the Step6B verdict. The failed launch did not run the reader or
issue JTAG writes.

## Build and programming provenance

```text
BRANCH = feat/file_cleanup
SOURCE_COMMIT = 74dc28862653d306e0450cf437ba6d3a230d979d
QUARTUS = 17.0.0 Build 595

SLAVE_QSF_SHA256 = 99851099c786f14ebbdc91949c9f2caaa8b0679273df7703c1a0e6a4a3aaf5f2
SLAVE_SDC_SHA256 = 083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d
SLAVE_MIF_SHA256 = 066761f51af3cc279923bd1e349b33d2d311faa7d2fa23e43745d9a1da3ca33c
SLAVE_SOF_SHA256 = 4775de6007af90e2049bcff573fa4173d843c4d84d25b88490c89a8635adc5ca
SLAVE_PROGRAMMER_CHECKSUM = 0x30B1E229

MASTER_QSF_SHA256 = f434c9b7e0ecfcc2378e0c1c5966762328e04ce6fc63f3cede4a77ccfb8c7607
MASTER_SDC_SHA256 = 083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d
MASTER_MIF_SHA256 = 00cf52190ae60392fce14fcb23ffac6adcb82b3a9ca4de5d1e968d21e3c68681
MASTER_SOF_SHA256 = 6521eb861051ce2fbe283269169992ecb88e093d734012a97500682d74329845
MASTER_PROGRAMMER_CHECKSUM = 0x30B18F28

PROGRAM_ORDER = SLAVE_THEN_MASTER
PROGRAM_RESULT = 1 device configured per board; 0 errors
TIMING_CLOSED = NO
```

The exact programming SOFs and their firmware MIFs are retained on Pain under
`/home/b10504072/04_WR/artifacts/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/`.
Quartus timing closure is recorded honestly but is not a Step5 functional
gate. The live trigger capture does not independently establish timing
closure.

## Evidence files

- `raw/build/build_info_jtag_slave.txt`, `raw/build/build_info_jtag_master.txt`
- `raw/build/build_jtag_slave.log`, `raw/build/build_jtag_master.log`
- `raw/observe/step5-step6-stability-690s.log`
- `raw/observe/same-pps-consistency.log`
- `raw/observe/step6b-preflight-74dc2886.log`
- `raw/observe/step6b-live-session-74dc2886-20260924-pathfixed.log`
- `raw/observe/step6b-live-session-74dc2886-20260924-command-not-found.log` (observer launch failure; no capture)
- `raw/program/programming-summary.md`
- `analysis/step6b-live-session-summary.json`

SHA-256 of the raw Step6B live-session log:
`b0b97461ffb3628bf07c4b562247794d419af7326c6f37181ce982da39241e85`.
