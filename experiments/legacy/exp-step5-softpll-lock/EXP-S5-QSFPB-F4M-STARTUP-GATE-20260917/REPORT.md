# EXP-S5-QSFPB-F4M-STARTUP-GATE-20260917

## Verdict

```text
QSFP-B_PHY_WR_PREREQUISITE = PASS
FIRMWARE_REBUILD           = PASS
QUARTUS_COMPILE            = PASS
PROGRAMMING                = PASS
STARTUP_GATE_REACHED       = NO
F4M_DIAGNOSTIC             = INCONCLUSIVE_STARTUP_GATE_NOT_REACHED
STEP5_PASS                 = NO
MERGE_APPROVED             = NO
```

This experiment completed the intended observer-only startup-gate validation.
It did not reach the Helper/Main boundary required for a valid Main F4L frame,
so it is not evidence for or against Main phase convergence.  The QSFP-B
data/WR path remained usable, but the Slave Helper never reached its locked
state during the bounded capture.

## Scope and single variable

The only functional change in this experiment was to the read-only Tcl
observer.  Before reading the 34-word Main F4L frame it waited for both:

```text
HELPER_LOCKED = 1
MAIN_ENABLED  = 1
```

Invalid F4L data before that boundary was reported as startup waiting rather
than `DATA_UNRESOLVED`.  The gate timeout was 30000 ms.  No production C/RTL,
PI/gain, threshold, timeout, bootstrap, detector, anti-windup, DAC, arbiter,
mailbox, PHY, reset, or SDB behavior was changed.  The observer remained a
single passive JTAG reader without a Helper PI snapshot or debug-FIFO drain.

## Reproducibility identity

```text
branch       = exp/step5-softpll-lock
source       = bfb1205a3505b44d69c1b3e5ccce541b9fe4a248
F4L marker   = DE5A_F4L_MAIN_PHASE_DIAG=1 (both images)
preload      = DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD=1 (both images)
main Kp      = DE5A_MAIN_PI_KP_OVERRIDE=300 (both images)
```

Fresh MIF hashes from Pain:

```text
Slave  = 5b7e752f89404c1c6da2ce4f869713656014ffcedfbf575e48aa82d442b05833
Master = b48492f7769e5d627e7d1ed1f36145d80fb419ea428162779f9a58fe9de8d700
```

Fresh SOF hashes from Pain:

```text
Slave  = 21e8caf4ea53654a6e403202646ac822573b0483c7d211bdc12427a1bb26ba59
Master = 317d00e036b7d21b89257294d41da114dd3be33b55d41c6cb485681aa91e6109
```

## Build and programming

Both port-B full Quartus builds completed successfully with zero errors:

```text
Slave  full compilation = 0 errors, 340 warnings
Master full compilation = 0 errors, 339 warnings
```

The images were programmed in the required order:

```text
Slave  DE5 [1-11.2] = status 0, checksum 0x30B8FA68
Master DE5 [1-11.1] = status 0, checksum 0x30B06CFD
```

Preflight immediately after programming returned valid probes:

```text
Master probe_hex = C110C0C126DC82FF
Slave  probe_hex = D11E76E1393C82EF
```

## F4M capture

The observer was run with:

```text
target_duration_ms = 60000
hard_duration_ms   = 70000
startup_gate_ms    = 30000
single_reader      = PASS
```

It stopped at 30009 ms, exactly at the bounded startup-gate condition:

```text
slave_cycles       = 22
master_samples     = 9
smoke_ok           = 0
diag_valid/unique  = 0/0
page0/page1/page2  = 0/0/0
run_end_reason     = STOP_STARTUP_GATE_NOT_REACHED
stop_reason        = STARTUP_GATE_NOT_REACHED
step5_pass         = NO
```

The final Slave gate sample was:

```text
HELPER_LOCKED      = 0
HELPER_LOCK_COUNT  = 2       (required 1000)
MAIN_STATE_RAW     = 00000000
MAIN_ENABLED       = 0
MAIN_F4L_VALID     = 0
PSTAT_LOCKED       = 0
```

The Helper was not completely inactive: bootstrap was done, update/service
counters advanced, and later samples reported residual demand with normal
request/completion activity.  However, it never satisfied the Helper lock
criterion.  Therefore the observer correctly did not read or interpret Main
phase/F4L data.

## Transport and reset health

The missing startup boundary was not caused by a loss of the QSFP-B WR data
link during this capture.  Repeated Slave and Master samples reported:

```text
PHY_LINK_USABLE       = 1
PSTAT_LINK             = 1
CORE_TM_LINK_UP        = 1
CORE_LINK_OK           = 1
WR_RX_READY/TX_READY   = 1/1
CPU_RESET_N            = 1
BOOT_GENERATION        = 1
WR_CORE_RESET_COUNT    = 0
SI_CONFIG_DROP_COUNT   = 0
```

The raw PHY status also showed that the reference-lock indication was not
uniformly stable on the B path (the data path remained usable while
`PHY_RX_LOCKED_TO_REF` varied).  This is an upstream observation to carry into
the next diagnostic; it is not sufficient by itself to claim a root cause.

## Interpretation

The startup gate change worked as intended: it separated a real pre-lock
condition from an invalid F4L transport frame.  The evidence now establishes
the following boundary:

```text
QSFP-B PHY/WR data path          PASS
Slave Helper service activity    PRESENT
Slave Helper locked              NOT REACHED
Main enabled                     NOT REACHED
Main F4L/phase diagnosis         NOT STARTED
Step5                            NOT PASS
```

This run must therefore be classified as
`INCONCLUSIVE_STARTUP_GATE_NOT_REACHED`, not as a Main phase-lock failure.
No PI or control-parameter conclusion is valid from this run, and no merge is
approved.

## Traceability note

The observer's emitted `STEP5_F4M_CONFIG` line still contains the historical
internal experiment label `EXP-S5-F4M-F4L-FIRST-LOSS-FULL-ROTATION-20260916`.
The external experiment directory, command, source commit, fresh MIF/SOF
hashes, and raw timestamps identify this capture unambiguously.  The stale
label should be corrected in the next observer-only revision before using the
line as an automated report identifier.

## Next experiment boundary

Do not tune PI/gain, thresholds, timeout, or other production control from
this result.  Before another Step5 phase run, perform one read-only startup
diagnostic on the same QSFP-B images that correlates, in one session:

```text
PHY_RX_LOCKED_TO_REF
Helper error/target/applied state
Helper lock counter and lock bit
Helper normal request/completion
Main enabled shadow
WR reset/generation counters
```

The purpose is to determine whether the unstable reference-lock indication
coincides with Helper lock loss or whether the Helper lock criterion is being
blocked elsewhere.  Keep the B topology and all control parameters frozen;
do not advance to QSFP-C merely because this run did not reach Step5.

## Raw evidence

```text
raw/build/firmware-image-manifest.txt
raw/build/sof-manifest.txt
raw/build/quartus_slave_portb_compile.log
raw/build/quartus_master_portb_compile.log
raw/program/program-slave-portb.log
raw/program/program-master-portb.log
raw/observe/read-probe-preflight.log
raw/observe/observer-f4m-startup-gate.log
```

```text
observer-f4m-startup-gate.log SHA256 = 1806582DBF4DD523B1851905A4CF8CFE48C8A06E58DB87E9ED6ECC5DE9C777E7
read-probe-preflight.log       SHA256 = 9674B5B84AB6DED2CF0987277A5FA966A1A39E9213A456FA3BB5472A394E53AE
program-slave-portb.log        SHA256 = 55EB689ACE7E800DA29F06542ABA80B6A311B46DF50E3801EF7C36117CE60189
program-master-portb.log       SHA256 = 0EC7E7BDE61423D7F79FB9AB0B1CD523755852C8E71B1EFBF1A5FE332A80F9B9
```
