# EXP-S5-MAIN-FREQ-THRESH20-F4J-AUDIT-20260920

## Objective

Use one bounded, read-only F4J producer audit on the same freshly-programmed
threshold20 image and live session.  The only question is whether the Slave
Main producer remains in frequency acquisition and whether its coherent
`FREQ_ERROR`/counter/branch frames move toward the new `+-20` acceptance
boundary.

This is not a new production-control change and is not a Step5 pass test by
itself.

## Frozen provenance

```text
FPGA/control source commit = 165d25ae29eba4a8265c75b66d33a0c55ce2e2c4
current laptop report tip  = 2bef57ed
observer implementation    = b4ca04ac (SESSION_EDGE freshness)
Slave SOF SHA256           = 964891814cead5b8d2ef67ad301826d1c5fdc586341cfd30a6f4500f39693328
Master SOF SHA256           = 7c7fa79ae41018c0ec65b871d58faad7c903401e43b40a2b968b4d50598477c1
```

No reprogramming, rebuild, threshold/gain/PI/timeout change, or PHY/RTL/SDB
change is allowed in this audit.

## Single command

```bash
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  2400 100 "" 30000 40000 f4j
```

Save complete stdout with a checksum under this experiment's `raw/observe/`
directory.  Stop at 30,000 ms or any observer early-stop condition; do not run
a second capture in this round.

## Valid capture gates

```text
quartus exit = 0
TARGET_REACHED with STOP_REASON=NONE
TERMINAL_FRESH_EDGE = 0 and TERMINAL = 0
HELPER_LOCKED = 1 and HELPER_LOCK_COUNT = 1000
PHY_LINK_USABLE = 1
generation/reset/SI-drop stable
producer_valid > 0 and producer_unique > 0
```

Historical sticky failure fields are acceptable only when the observer's
SESSION_EDGE freshness remains clear.

## Analysis and stop rule

Analyze only Slave coherent unique producer frames and retain:

```text
UPDATE_ID, FREQ_ERROR, FREQ_COUNT_BEFORE, FREQ_COUNT_AFTER,
BRANCH_ID, FLAGS, FREQ_TO_PHASE, PHASE_TO_FREQ
```

Classify the result as acceptance-dominant, hysteresis-dominant, mixed, or
invalid runtime.  Do not change a control parameter and do not claim Step5
PASS from this audit.  Write the report and push it after the single capture.
