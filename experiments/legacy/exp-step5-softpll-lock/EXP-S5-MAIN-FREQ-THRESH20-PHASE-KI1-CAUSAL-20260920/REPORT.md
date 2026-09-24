# EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-CAUSAL-20260920

## Verdict

```text
PHASE_KI1_IMPLEMENTATION = PASS
HELPER_RUNTIME_GATE      = PASS
HELPER_LOCK_HELD         = YES
MAIN_RUNTIME_GATE        = PASS
MAIN_PHASE_LOCK_OBSERVED = YES
PSTAT_LOCK_OBSERVED      = YES
PHASE_KI1_CAUSAL_DIRECTION = STRONGLY_POSITIVE
PHASE_KI1_F4L_FORMAL     = ALLOWED_NEXT
STEP5                    = NO
```

The source candidate was implemented, tested, built, and programmed
successfully.  The direct runtime gate initially stopped before Helper lock;
the one bounded follow-up correlation then showed that the Slave Helper
acquired and held lock with active DCO service.  A subsequent single Main
direct gate on the same live session observed Main phase lock and PSTAT lock.
This is strong positive causal evidence for phase Ki=1, but it is not yet a
stable-window Step5 proof.

## Exact candidate and provenance

```text
Laptop/Pain source commit        = 26e138fdc0bfc8426704b397141d563cf4d580a2
experiment plan                  = this experiment PLAN.md
changed production identity      = Slave DE5A_MAIN_PHASE_PI_KI_ZERO: 1 -> 0
Master identity                  = unchanged (still DE5A_MAIN_PHASE_PI_KI_ZERO=1)
Slave frequency threshold       = 20
Slave Main Kp                    = 300
bumpless preload                 = 1
F4L diagnostic owner             = 1
other control/observer/RTL/SDB   = unchanged
```

The source-only offline runner executed 13 tests and all passed.  The
production diff contained only the Slave identity Ki switch; the other
changed files were the corresponding offline assertions and this plan.

## Pain build and programming

```text
Slave firmware build             = PASS
Slave firmware MIF SHA256        = 1fe50c67ac75354034fbe11c7db0924ade8a8f1ef2fa3d782c4f78c1eca75ab0
Slave Quartus compile            = PASS (0 errors)
Slave SOF SHA256                 = e149a70147c969765beb6705b4daaaacc47965354177af47be6728ef6d97c449
Slave timing WNS                 = -0.361 ns
Slave programming                = PASS, DE5 [1-11.2]
Master rebuild/program           = not performed (no Master diff)
```

The programmer configured one device successfully.  No power cycle or
additional reset action was requested.

## Single direct runtime gate

Command:

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
```

```text
quartus_exit                     = 0
JTAG/WB transport                = TRUSTED
WB timeout/invalid               = 0 / 0
direct raw SHA256                = 4640f82e48fbf1ae0ea04f0161065446f8ef7be2d25332c5b816f76b8e7db845
```

### Slave upstream/runtime state

The Slave remained healthy at the link and reset boundaries:

```text
Step 1 PHY/link                  = PASS
Step 3 WR handshake               = PASS
CORE_TM_LINK_UP / CORE_LINK_OK   = 1 / 1
PHY_LINK_USABLE / PSTAT_LINK     = 1 / 1
RXERR delta                       = 0
BOOT_GENERATION delta             = 0
CPU_RESET_COUNT delta             = 0
WR_CORE_RESET_COUNT delta         = 0
SI_CONFIG_DROP_COUNT delta        = 0
```

The first inactive boundary was the Helper-to-Main SoftPLL sequence:

```text
SPLL_STATE                       = 00030004 (SEQ_WAIT_HELPER)
SPLL_HELPER_STATE                = 00640000 (lock count about 100, not 1000)
HELPER_LOCKED                    = 0
SPLL_MAIN_STATE                  = 00000000 (Main disabled)
MAIN_ENABLED                     = 0
SPLL_MAIN_LIMITS                 = 00320014 (threshold20, samples50)
SPLL_MAIN_PHASE_LIMITS           = 03E804B0 (phase threshold1200, samples1000)
```

The runtime therefore classified the Slave as:

```text
STEP4B_ALLOWED                   = NO
STEP4B_RESULT                    = BLOCKED_BY_STEP2
STEP5_RESULT                     = UPSTREAM_NOT_READY
```

The dashboard reported `WDIAGS_PTP=8 UNCALIBRATED` during this fresh
post-program snapshot, while the source-backed parent/link/reset state stayed
healthy.  Consistent with the established runtime rule, this is recorded as
the upstream measurement/acquisition boundary and not as evidence that the
Ki1 source candidate is wrong.

The Master side was not the candidate under test; its direct snapshot showed
Step 1, Step 2, and Step 4A healthy.  It does not change the Slave gate
classification.

## Bounded Helper correlation

The advisor-approved follow-up was executed once on the same live
`threshold20 + phase-Ki1` session:

```text
quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 20 500
```

No reprogramming, reset, F4L capture, `read_wb_runtime`, or control-parameter
change was performed in this follow-up.

```text
quartus_exit                     = 0
samples / gap                    = 20 / 500 ms
final raw SHA256 (laptop)        = 33aa295ce61997c690d876d52d57f926869a3eee561dc0935460b9d3193219c3
Pain pre-append digest           = 74d8361253756e9863a01eea22d87a87e8615019d5fff9246cfb2c0333a637ee
Slave board                      = DE5 [1-11.2]
SPLL_STATE                      = 00030008 on samples 1..20 (SEQ_READY)
HELPER_STATE                    = 03E80001 on samples 1..20
HELPER_LOCK_COUNT               = 1000 (encoded in HELPER_STATE)
HELPER_ERROR_SIGNED             = +192 .. -211
HELPER_UPDATE_COUNT             = 00381233 -> 0038DFD3
STEP_DELTA                      = 0 on sample 1; nonzero on samples 2..20
STEP_EVENT                      = 0 on sample 1; 1 on samples 2..20
DCO ERROR                       = 0 on samples 1..20
```

The Slave therefore satisfies the bounded Helper conditions: Helper lock was
acquired and held, its error stayed within the requested band, the update
counter advanced, and DCO service events continued.  The observed state is
`SEQ_READY`, not the advisor's preferred `SEQ_WAIT_MAIN (00030006)`; this is
recorded exactly and is not promoted to a Main-enabled or phase-lock claim.

The Master samples in the same two-board reader are not used for the Slave
candidate verdict.  The formal Step5/F4L path was not started after this
capture, as required by the stop rule.

## Main direct gate after Helper correlation

The advisor-approved follow-up was executed once on the same live session:

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
```

No reprogramming, reset, F4L capture, or control-parameter change was
performed before this read.

```text
quartus_exit                     = 0
final raw SHA256                 = dd6101aaedc06ece45f59d37062b0cc84c3d3f4603864e3b267f8eca0dca4699
JTAG/WB transport                = TRUSTED
WB requests / timeout / invalid  = 353 / 0 / 0
Slave WDIAGS_PTP                 = 9 SLAVE
Slave parentCalibrated           = 1
Slave LOCK_ENABLE                = 4
SPLL_STATE                       = 00030008 before and after (SEQ_READY)
SPLL_HELPER_STATE                = 03E80001 before and after
SPLL_MAIN_STATE                  = 3E80320F before and after
SPLL_MAIN_LIMITS                 = 00320014
SPLL_MAIN_PHASE_LIMITS           = 03E804B0
PSTAT                            = 00000003 before and after
PHY/link                         = PASS
RXERR delta                      = 0
BOOT/CPU/WR/SI-drop deltas       = 0 / 0 / 0 / 0
```

Using the source-backed register packing, `SPLL_MAIN_STATE=3E80320F`
decodes to:

```text
MAIN_ENABLED       = 1
MAIN_LOCKED        = 1
MAIN_FREQ_LOCKED   = 1
MAIN_PHASE_LOCKED  = 1
MAIN_FREQ_COUNT    = 50/50
MAIN_PHASE_COUNT   = 1000/1000
PSTAT_LOCKED       = 1   (PSTAT bit 1)
```

This satisfies the advisor's positive direct-gate case.  The runtime summary
also reported a Step 3 `WR_RX_SIGNAL_DEBUG`/`WR_TX_SIGNAL_DEBUG`
read-inconsistent diagnostic and classified the dashboard Step4B gate as
`BLOCKED_BY_STEP3`; the source-backed raw link, parent-calibration,
SoftPLL/Main/PSTAT shadows, reset counters, and trusted JTAG transport were
stable.  That diagnostic sideband is recorded as a measurement caveat and is
not silently converted into a Step5 pass.

## Stop decision

The advisor's stop condition was met:

```text
PHASE_KI1_IMPLEMENTATION = PASS
HELPER_ACQUISITION        = PASS
HELPER_LOCK_ACQUIRED_HELD = YES
MAIN_RUNTIME_GATE         = PASS
MAIN_PHASE_LOCK_OBSERVED  = YES
PSTAT_LOCK_OBSERVED       = YES
PHASE_KI1_CONTROL_RESULT  = STRONGLY_POSITIVE_DIRECT_SNAPSHOT
PHASE_KI1_F4L_FORMAL      = ALLOWED_NEXT
STEP5                     = NO
```

The single bounded Helper correlation and the single Main direct gate were the
only post-program observations.  No F4L capture, second programming attempt,
threshold change, PI/gain change, timeout change, or reset was performed.
This round cannot declare Step5 PASS because the positive result is still a
snapshot rather than a formal stable-window capture, and timing closure is
still open.

The next action is deferred to the phase-lock advisor; if the direct-gate
result is accepted, the next allowed experiment is one formal F4L stability
capture on this Ki1/threshold20 image.
