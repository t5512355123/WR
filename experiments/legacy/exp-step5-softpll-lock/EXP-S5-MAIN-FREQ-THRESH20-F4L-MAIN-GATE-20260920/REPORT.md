# EXP-S5-MAIN-FREQ-THRESH20-F4L-MAIN-GATE-20260920

## Verdict

```text
THRESH20_CONTROL_PRESERVATION = PASS
F4L_DIAGNOSTIC_OWNER           = PASS
HELPER_RUNTIME_GATE             = PASS
MAIN_RUNTIME_GATE               = PASS
F4L_THRESH20_FORMAL             = ALLOWED_NEXT
STEP5                           = NO
STOP_REASON                     = DIRECT_MAIN_GATE_COMPLETE
```

This was one read-only Main gate on the same already-programmed threshold20 +
F4L live session. There was no reprogramming, recompilation, reset/power-cycle,
control-parameter change, or formal F4L capture in this round.

## Provenance

```text
FPGA/source commit             = 00d7572fa4943dbba1e28b2245f884fc04386a94
experiment-plan commit         = 8340e8e9
previous Helper report         = 121d882f
observer command               = read_wb_runtime.tcl --raw
quartus_exit                   = 0
raw SHA256                     = e4527abc4b924c14bef325ba39d6fb81b51e859274ef8b7db2ac428086bd905c
```

The implementation identity and threshold20 preservation were already verified
by the previous build/program and Helper reports:

```text
Slave spll_main_limits         = 00320014
Master spll_main_limits        = 00320032
DE5A_F4L_MAIN_PHASE_DIAG       = 1 on Master and Slave
```

## Master reference

The Master remained healthy and is not the Step5 closed-loop subject:

```text
Step1 PHY/link                  = PASS
Step2 Endpoint/PTP              = PASS
Step4A event chain               = PASS
spll_main_limits                = 00320032
BOOT_GENERATION delta            = 0
CPU_RESET_COUNT delta            = 0
WR_CORE_RESET_COUNT delta        = 0
SI_CONFIG_DROP_COUNT delta       = 0
RXERR delta                      = 0
```

## Slave Main gate

The Slave satisfied the required operating state:

```text
PHY/link                         = PASS
PSTAT_LINK                       = 1
WDIAGS_PTP                       = 9 (SLAVE)
parentCalibrated                 = 1
LOCK_ENABLE                      = 4
SPLL_SEQ_STATE                   = 6 (SEQ_WAIT_MAIN)
SPLL_STATE                       = 00030006
SPLL_HELPER_STATE                = 03E80001
HELPER_LOCKED                    = 1
HELPER_LOCK_COUNT                = 1000
MAIN_ENABLED                     = 1
MAIN_FREQ_LOCKED                 = 1
MAIN_PHASE_LOCKED                = 0
MAIN_FREQ_COUNT                  = 50/50
MAIN_PHASE_COUNT                 = 100/1000
spll_main_limits                 = 00320014
```

The runtime remained stable during the gate:

```text
RXERR delta                      = 0
BOOT_GENERATION delta            = 0
CPU_RESET_COUNT delta            = 0
WR_CORE_RESET_COUNT delta        = 0
SI_CONFIG_DROP_COUNT delta       = 0
JTAG/WB transport                = TRUSTED
WB requests                      = 352
timeouts/invalid                 = 0/0
probe 3-way matches              = 352
DMTD counters                    = nondecreasing
Step4B                           = PASS
```

The raw dashboard also reports a historical `WRS_S_LOCK` timeout/failure
debug value, but the current link, parent signaling, Helper/Main state, Step4B
gate, and reset/runtime deltas are healthy. It is recorded as provenance and
was not used by itself to invalidate this direct gate.

## Step5 interpretation

The single snapshot reports:

```text
MAIN enabled                     = 1
MAIN frequency locked            = 1
MAIN phase locked                = 0
PSTAT_locked                     = 0
STEP5_RESULT                    = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY   = MAIN_PHASE_LOCK
```

This is not a Step5 pass: a single direct snapshot cannot prove closed-loop
phase-lock stability. It does prove the required admission boundary for the
next formal observation: Helper is locked, Main is enabled, threshold20 is
present, and the runtime infrastructure is clean. `MAIN_FREQ_LOCKED=1` is
recorded as positive gate evidence; phase lock remains unobserved.

## Stop and next permitted round

Per the advisor's rule, stop after this direct gate. The next round may run the
formal threshold20 F4L comparison, still without changing the production
controls:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  2400 100 "" 120000 130000 f4l
```

That formal capture must be a separate round and must be reported against the
frozen threshold50/Ki0 baseline; it was not run here.

```text
F4L_THRESH20_FORMAL = NOT_RUN_IN_THIS_ROUND
STEP5               = NO
```

## Evidence

- `PLAN.md`
- `raw/observe/direct_main_gate.log`
- `raw/observe/direct_main_gate.log.sha256`
