# EXP-S5-QSFPB-F4M-FIRMWARE-REBUILD-RETRY-20260917

## Verdict

```text
QSFP-B_PHY_WR_PREREQUISITE = PASS
FIRMWARE_REBUILD           = PASS
QUARTUS_COMPILE            = PASS
PROGRAMMING                = PASS
F4M_DIAGNOSTIC             = INCONCLUSIVE_STARTUP_NOT_REACHED
STEP5_PASS                = NO
MERGE_APPROVED             = NO
```

This retry proves that the previous run did not stop because of the Pain
`rg` portability issue or because an old firmware MIF was reused.  Fresh
Slave and Master MIFs were built from the pushed source and both port-B SOFs
were compiled and programmed successfully.  The F4M observer nevertheless
stopped before the Slave Helper/Main startup boundary became valid.

## Frozen scope

The QSFP-B lane-0 topology was retained.  No production C/RTL, PI/gain,
threshold, timeout, bootstrap, detector, anti-windup, DAC, arbiter, mailbox,
PHY, reset, or SDB behavior was changed.  The observer was read-only and ran
as one JTAG reader without a Helper PI snapshot or debug-FIFO drain.

## Reproducibility identity

```text
branch       = exp/step5-softpll-lock
source       = f92e8f1de5065b603b70284171f72b4afb26862d
identity     = slave aa283a28dd201ec2a547f5804b91ab8b1771d8e0d7b6c83a90bcc726f039a546
               master 90c32a0b4084150db9303166b95ebed568105e691b10dcdbaf398c5c7f152ee
F4L marker   = DE5A_F4L_MAIN_PHASE_DIAG=1 (both images)
preload      = DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD=1 (both images)
main Kp      = DE5A_MAIN_PI_KP_OVERRIDE=300 (both images)
```

Fresh MIF hashes from Pain:

```text
Slave = d81c6d76dcab5b15de0a52dc7d08a7c17c049c214797c38db7e89d3b00a10601
Master = e30af80f64dbe9dbc4a1fb98f56b8ee60e488ae8a218974bc2ce15bd21d444f3
```

SOF hashes:

```text
Slave = 3d77b1bc7e80f4bebd3161baf752f3f28b1778495313d4626ab4d89aa3985873
Master = 624fe96b7f9f81a1fe771bba86fa9d24b19a6ab54c130e7e38098de2bae1a80e
```

Quartus full compilation completed with zero errors for both images.  Slave
was programmed on `DE5 [1-11.2]` first and Master on `DE5 [1-11.1]` second;
both Programmer operations returned status 0 and configuration succeeded.

## Preflight and F4M result

The immediate preflight returned valid B-path probes:

```text
Master probe_hex = 800268E1333882FF
Slave  probe_hex = 001E76E120D482EF
```

The F4M observer was run with the unchanged contract:

```text
target_duration_ms = 60000
hard_duration_ms   = 70000
single_reader      = PASS
```

It stopped after `15448 ms` with:

```text
run_end_reason = STOP_DATA_UNRESOLVED
stop_reason    = DATA_UNRESOLVED
slave_cycles   = 4
master_samples = 3
MAIN_F4L_VALID = 0 for every Slave cycle
diag_valid/unique = 0/0
page0/page1/page2 = 0/0/0
PSTAT_LOCKED   = 0
```

This is not a PHY/link failure.  At the retained end of the capture:

```text
PHY_LINK_USABLE     = 1
PSTAT_LINK          = 1
CORE_TM_LINK_UP     = 1
CORE_LINK_OK        = 1
WR_RX_READY/TX_READY= 1/1
BOOT_GENERATION     = 1
WR_CORE_RESET_COUNT = 0
SI_CONFIG_DROP_COUNT= 0
```

The observed startup state was still before the Main closed-loop boundary:

```text
Slave HELPER_LOCKED      = 0
Slave MAIN_ENABLED       = 0 (SPLL_STATE_RAW=00030004 at final Slave sample)
Slave PSTAT_LOCKED       = 0
S_LOCK trace             = valid, stage 2, remaining_ms=237252
Helper update count      = 215 at the final cycle
```

The Master also remained `MAIN_ENABLED=0` in its observed state, which is
consistent with this being a startup capture rather than a completed Main
phase-acquisition window.  The observer's unresolved-data guard then stopped
after repeated invalid Main F4L reads.  Because Helper lock and Main enable
were not yet present, these rows cannot be used to diagnose phase drift or
to claim that the F4L firmware producer is broken.

## Interpretation

The B physical path is usable and the fresh firmware boundary is verified.
The actual missing boundary is:

```text
Slave WR session / Helper startup
    -> Helper locked
    -> Main enabled
    -> valid F4L frame
```

The present F4M run ended before this sequence.  Therefore the correct result
is `INCONCLUSIVE_STARTUP_NOT_REACHED`, not Step5 failure and not firmware/MIF
incompatibility.  In particular, no PI or clock-control conclusion is valid
from this capture.

## Next experiment

Keep the QSFP-B lane-0 images and all production control parameters frozen.
Make only a passive observer change: add an explicit startup gate that waits
for the existing Helper-lock and Main-enabled status before attempting the
34-word F4L frame.  Before that gate, invalid F4L data must not be promoted to
`DATA_UNRESOLVED`; if the gate is not reached within the observer's bounded
window, stop as `STARTUP_GATE_NOT_REACHED` and preserve the raw state.

This is needed to obtain the same-generation F4L pages before deciding on any
phase-control experiment.  Do not sweep QSFP-C and do not tune PI/gain or
timeout based on this retry.

## Raw evidence

```text
raw/build/firmware-image-manifest.txt
raw/build/sof-manifest.txt
raw/build/quartus_slave_portb_compile.log
raw/build/quartus_master_portb_compile.log
raw/program/program-slave-portb.log
raw/program/program-master-portb.log
raw/observe/read-probe-preflight.log
raw/observe/observer-f4m-smoke.log
```

```text
observer-f4m-smoke.log SHA256 = 75E3A7B5310A6419F2012E6844052CC0E21257668B78612522E9192A365C54B3
read-probe-preflight.log SHA256 = C27091270AE5C3BFEBF3D9AAE02388360C503E3A6E2A48273A2B63A67341FE36
```
