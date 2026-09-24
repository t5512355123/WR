# EXP-S6-GLOBAL-TIME-OBSERVABILITY-20260920

## Verdict

```text
STEP6A_MASTER_GLOBAL_TIME_COUNTER = PASS
STEP6A_SLAVE_GLOBAL_TIME_COUNTER  = NOT_VALID
STEP6A_MASTER_SLAVE_SAME_PPS      = INCONCLUSIVE
STEP6A_RESULT                     = NOT_PASS_BLOCKED_BY_SLAVE_TIME_VALID
STEP6B_SCHEDULED_TRIGGER          = NOT_RUN
POWER_CYCLE                       = NOT_REQUIRED / NOT_PERFORMED
```

Timing closure was not used as a gate for this experiment. Both images were
compiled successfully and programmed successfully; the result above is based
only on the Global Time observability evidence.

## Provenance

| Item | Value |
| --- | --- |
| Laptop/Pain source commit | `ec1f25e81e0eb8c2caee796d13a225eaae81e5f2` |
| Branch | `exp/step6-Global-Time-Testing` |
| Quartus | Prime 17.0 Build 595 |
| Master cable | `DE5 [1-11.1]` |
| Slave cable | `DE5 [1-11.2]` |
| Master SOF SHA256 | `568f08c974064bdd3e82f68e3f1ecb0ff6c8a2a8e5705bdcc15b5941d33173a3` |
| Slave SOF SHA256 | `7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e` |
| Observation | 15 s per board, 250 ms sample interval |

The build provenance files record `COMPILE_RESULT=Full Compilation was
successful` for both images. Programming logs record one device configured
and zero errors for each board.

## Master result

The Master satisfied the local Step6A counter criteria:

```text
status SI_CONFIG / PHY_READY / TM_LINK_UP / LINK_OK = 1 / 1 / 1 / 1
STATUS_TIME_VALID                              = 1
STATUS_PPS_VALID                               = 1
stable PPS snapshot rows                       = 59
valid PPS snapshot rows                        = 59
unique PPS snapshot events                     = 15
SNAPSHOT_COUNT                                 = 16 -> 30
TAI                                             = 15 -> 29
snapshot CYCLES                                = 124999999
TAI delta per snapshot-count delta             = 1
packed live cycle samples                     = 59
live cycle wrap observations                   = 14
live cycle bad steps                          = 0
```

The snapshot sequence and TAI advanced together once per reference-clock
period. The live packed sample advanced through the 125 MHz cycle domain and
crossed the cycle boundary repeatedly. This is sufficient for the
Master-local `GLOBAL_TIME_COUNTER_VALID` diagnostic classification.

## Slave result

The Slave had a healthy upstream/status gate but did not expose a valid global
time during the entire capture:

```text
SI_CONFIG        = 1
PHY_READY        = 1
TM_LINK_UP       = 1
LINK_OK          = 1
STATUS_PPS_VALID = 1
STATUS_TIME_VALID= 0 for all 59 samples
SNAPSHOT_VALID   = 0 for all 59 samples
SNAPSHOT_COUNT   = 0 for all 59 samples
```

The packed live cycle word changed, but without `time_valid` and without a PPS
boundary snapshot it is not valid evidence for the synchronized Global Time
counter. The analyzer therefore classifies the Slave as
`GLOBAL_TIME_NOT_VALID`, not as a counter pass.

## Cross-board conclusion

No shared valid TAI PPS boundary existed in the two captures. Sequential JTAG
reads were deliberately not treated as simultaneous PPS evidence. Therefore
Master/Slave Global Time agreement is `INCONCLUSIVE`, and the Step6A gate is
not passed.

This experiment also provides a useful boundary: the WR link and PPS-valid
status on Slave are already high, so the next investigation should explain
why Slave `tm_time_valid_o` remains low. It is not evidence to implement the
Step6B trigger yet.

## Files

```text
PLAN.md
REPORT.md
raw/observe/global-time-15s.log
raw/program/program-master.log
raw/program/program-slave.log
raw/build/build_info_jtag_master.txt
raw/build/build_info_jtag_slave.txt
raw/build/quartus_jtag_master_compile.log
raw/build/quartus_jtag_slave_compile.log
```

No trigger RTL, trigger firmware command, PI/gain, PHY, reset, or timing
constraint was changed in this experiment.
