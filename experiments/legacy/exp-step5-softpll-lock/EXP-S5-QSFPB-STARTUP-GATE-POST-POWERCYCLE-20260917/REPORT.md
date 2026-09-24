# EXP-S5-QSFPB-STARTUP-GATE-POST-POWERCYCLE-20260917

## Verdict

```text
QSFPB_STARTUP_GATE                  = PASS
ORIGINAL_QSFPA_PATH_SPECIFIC_BLOCKER= SUPPORTED
COMMON_WR_LINK_BLOCKER              = NOT SUPPORTED BY THIS A/B
F4S/F4L                              = NOT RUN
STEP5_PASS                          = NO
MERGE_APPROVED                      = NO
```

The independent QSFP-B lane-0 path established a stable WR/PHY link after
the physical power cycle and after fresh programming.  This supports the
conclusion that the current QSFP-A failure is path-specific.  It does not
constitute a Step5 closed-loop or phase-lock result.

## Experiment boundary

The latest diagnostic recommendation was followed exactly: use QSFP-B only
as an upstream startup gate, then stop.  No F4S/F4L capture, Main observer,
PI tuning, or Step5 control experiment was started.

The existing QSFP-B diagnostic source was reused without functional changes.
The port-B topology uses QSFP-B lane 0 for WR data and the QSFP-B PHY
reference clock; the existing project keeps the QSFP-A reference for the
DMTD path.  Main/Slave roles and the validated Slave-first programming order
were preserved.

Frozen items included PI/gain, thresholds, timeout, bootstrap/preload,
detector, anti-windup, DAC ordering, arbiter, mailbox, PHY RTL, reset tree,
SDB, and all Step5 observer/control behavior.

## Reproducibility identity

```text
branch       = exp/step5-softpll-lock
source       = 5ef4dc156ba6d1b11017285bf4c4fd366255afaa
project      = quartus/jtag_runtime_diag_portb
program      = Slave DE5 [1-11.2], then Master DE5 [1-11.1]
Main Kp      = 300
F4L marker   = enabled in the frozen image identity
preload      = enabled in the frozen image identity
```

Fresh firmware MIF hashes:

```text
Slave  = 36cee911824c24bf9b3837954c7a8090fef8b55df893fabc7aa0b4cc541ee3e9
Master = 3732978078b2d934e1f53dbee7dc57084084064c8f45acea0ae3ce25fd39861f
```

Fresh SOF hashes:

```text
Slave  = d87775cd6ce0de2250a3b0ef9a7e22c7c338cb162dd3b607640a0dffe978e269
Master = eb82c7ee30bb8e9d8f8c3dca84667f47525760a02a9fccf30bb2e38a059dd7a8
```

Quartus 17.0 full compilation and programming:

```text
Slave  = 0 errors, 340 warnings, full compilation successful
Master = 0 errors, 339 warnings, full compilation successful
Slave  programmer checksum = 0x30B8FA68, configuration succeeded
Master programmer checksum = 0x30B06CFD, configuration succeeded
```

The first Slave programming shell invocation was incorrectly quoted and was
rejected before Quartus programming began (`programming option string "p" is
illegal`).  It caused no hardware change.  The corrected invocation was
then run successfully; the raw log preserves both the rejected invocation
and the successful retry.

## Startup-gate evidence

### Repeated direct status probe

Six read-only `read_probe.tcl` samples completed with return code 0.
The decisive low-16-bit status fields remained valid throughout:

| Endpoint | Low-16 status samples | Gate interpretation |
|---|---|---|
| Master-B | `82FF, 82FF, 82FF, 82FF, 82FF, 82FF` | CPU released; SI/PHY/link/TM/RX/TX ready |
| Slave-B | `82EF, 82CF, 82EF, 82EF, 82EF, 82EF` | CPU released; SI/PHY/link/TM/RX/TX ready |

The Slave variation is in `pps_valid/time_valid`, not in the required PHY or
WR-link bits.  Both endpoints repeatedly had:

```text
CPU_RESET_n     = 1
si_config_done  = 1
phy_ready       = 1
tm_link_up      = 1
link_ok         = 1
rx_ready        = 1
tx_ready        = 1
rx_enc_err      = 0
tx_enc_err      = 0
```

### WB runtime preflight

The existing raw WB reader independently confirmed the same boundary:

```text
Master: core_tm_link_up=1, core_link_ok=1, wr_rx_ready=1,
        wr_tx_ready=1, pstat=00000001, Step 1 pass
Slave : core_tm_link_up=1, core_link_ok=1, wr_rx_ready=1,
        wr_tx_ready=1, pstat=00000001, Step 1 pass
```

The WB transport was trusted:

```text
WB_REQUEST_COUNT             = 352
PRELOAD_COUNT                = 352
COMMIT_COUNT                 = 352
PROBE_3WAY_MATCH_COUNT       = 352
TIMEOUT_COUNT                = 0
INVALID_COUNT                = 0
JTAG_WB_DIAGNOSTIC_PATH      = TRUSTED
```

The raw reader also saw active endpoint traffic and `rxerr=0`.  It classified
Master Step4A as PASS.  On the Slave it reported `WDIAGS_PTP=UNCALIBRATED`
and therefore `STEP4B_ALLOWED=NO`; this is outside the current B startup-gate
question and is why this run must not be promoted to a Step5 run.

### Clock activity

The 2000 ms read-only clock-activity probe completed on both boards.  All
four begin/end observations reported:

```text
PHY_READY     = 1
RX_LOCK_DATA  = 1
```

Reference, DMTD, and recovered-RX counters changed between the begin and end
samples on both boards.  `RX_LOCK_REF` varied between samples; it was not
used as a failure criterion for this startup gate because the direct WR link
bits and recovered-data indication were valid.

## Interpretation

The causal boundary is now:

```text
FPGA/SI/CPU startup       PASS
QSFP-B PHY data path      PASS
WR endpoint link          PASS
PSTAT link indication     PASS
Slave Helper/Main Step5   NOT EVALUATED in this experiment
```

Because the original QSFP-A image/path failed the same upstream link gate
after reprogramming and power cycling, while the independent QSFP-B path
passes it, the evidence supports:

```text
ORIGINAL_QSFPA_PATH_SPECIFIC_BLOCKER = SUPPORTED
```

It does not prove which A-side component is responsible (fiber, module,
cage, lane, or A-side startup interaction), and it does not prove that the
B path can reach Step5 lock.  In particular, `STEP5_PASS` remains `NO`.

## Stop decision

Per the prescribed decision boundary, stop this experiment now:

- do not sweep QSFP-C or QSFP-D;
- do not start F4S/F4L on this B startup-gate run;
- do not change PI, gain, threshold, timeout, bootstrap, preload, or PHY
  settings;
- do not merge any Step5 result to `main`.

The next Step5-capable experiment requires an explicit decision about whether
to restore and validate the original QSFP-A path or to define a separate,
controlled QSFP-B Step4B/Step5 run.  This report intentionally stops before
that decision.

## Raw evidence

```text
raw/build/firmware-image-manifest.txt
raw/build/firmware-slave-build.log
raw/build/firmware-master-build.log
raw/build/quartus_slave_portb_compile.log
raw/build/quartus_master_portb_compile.log
raw/build/sof-manifest.txt
raw/program/program-slave-portb.log
raw/program/program-master-portb.log
raw/observe/read-probe-repeat.log
raw/observe/read-clock-activity-2000ms.log
raw/observe/read-wb-runtime-raw.log
```

Local raw-file SHA-256 values:

```text
firmware-image-manifest.txt       89B8CB8A31B3CCD5C634993F1C699B146A5D5CDE9695A7304C8EDFCF25D3BE51
quartus_slave_portb_compile.log   1BB5F0FF93B2313F80B8F7C02C109D98711CDBB4B62286E3BA49388CA514B0DC
quartus_master_portb_compile.log  7BD8041528718ED75428ABFF85BA92700F3432DC490364C4747E420E077E633C
sof-manifest.txt                  FCAF43846CCF47502176262506F1FDE02FB6831C0ACBA392ECBB17D85B29A12C
program-slave-portb.log           6CF05A7257B899DCDB64B637D0FD5D31524CB3ADC7A2BF81C31088163D5EB4A0
program-master-portb.log          A922DAE62C9D26505D501FEE4188202117C244177245DF3B58BFD00F434A33C8
read-probe-repeat.log             DE143D0B2AB23784818BACB84428FB1780A381190F4466E3ECA7C4BD29EA1685
read-clock-activity-2000ms.log    7030ADB785EC5D8307EEB678A13DC453CC5F37EFF0D63CB2C819A21815A25464
read-wb-runtime-raw.log           8041DCB8EBD83B00FD22DFECE36BFCA2DD41D2DC1A38E7B1D3674753E15B1F15
```

