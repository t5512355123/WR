# EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-CAUSAL-20260920

## Verdict

```text
PHASE_KI1_IMPLEMENTATION = PASS
MAIN_RUNTIME_GATE        = NOT_EVALUATED_UPSTREAM
PHASE_KI1_F4L_FORMAL     = NOT_ALLOWED
STEP5                    = NO
```

The source candidate was implemented, tested, built, and programmed
successfully.  The single direct runtime gate then stopped at Slave Helper
acquisition before Main was enabled, so this round provides no causal result
for effective phase Ki=1.

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

## Stop decision

The advisor's stop condition was met:

```text
PHASE_KI1_IMPLEMENTATION = PASS
PHASE_KI1_CONTROL_RESULT  = NOT_EVALUATED_UPSTREAM
PHASE_KI1_F4L_FORMAL      = NOT_ALLOWED
```

No Helper correlation, F4L capture, second programming attempt, threshold
change, PI/gain change, timeout change, or reset was performed after the
direct gate.  This round cannot declare Step5 PASS because Main never reached
the phase branch.

The next action is deferred to the phase-lock advisor after review of this
report.

