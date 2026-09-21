# EXP-S6-SAME-PPS-GLOBAL-TIME-CONSISTENCY-20260922

## Result

```text
RESULT=PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY
VERDICT=PASS
STEP6A_1=PASS
STEP6A_2=PASS
STEP6A_GLOBAL_TIME=PASS
STEP6B=NOT_RUN
```

This experiment passed the Step6A-2 digital same-PPS consistency criterion.
Master and Slave produced the same frozen Global-Time `SNAPSHOT_TAI` labels and
exactly the same `SNAPSHOT_CYCLES` value for five distinct common labels.

This is a timestamp-label consistency result. It does **not** claim that two
future physical trigger edges have zero propagation or measurement delay; that
is the separate Step6B scheduled-trigger experiment.

## Source and execution

```text
Laptop source commit = 47d0914b7775ccf2e8ff7a6310e2f2ae65affab9
Pain source commit    = 47d0914b7775ccf2e8ff7a6310e2f2ae65affab9
Observer              = scripts/jtag/read_step6_same_pps_global_time_consistency.tcl
Analysis              = scripts/analysis/step6_same_pps_global_time_consistency.py
Gate pairs            = 3
Capture samples       = 7 paired samples
Capture elapsed       = 4108 ms
```

The observer was executed through Quartus STP and completed without Tcl or STP
errors. The formal pass stopped the capture early, before the 20-second upper
bound.

## Protocol boundary

This was strictly read-only:

```text
MASTER_COMPILE=NO
SLAVE_COMPILE=NO
MASTER_PROGRAM=NO
SLAVE_PROGRAM=NO
MASTER_PTP_RESTART=NO
SLAVE_PTP_RESTART=NO
CPU_RESET=NO
WR_CORE_RESET=NO
PHY_RESET=NO
POWER_CYCLE=NO
MODE_COMMAND=NO
FIBER_QSFP_CHANGE=NO
AUTONEG_CHANGE=NO
SI5340_CHANGE=NO
MDIO_WRITE=NO
```

The coherent snapshot read sequence was `probe63-before -> probe62 ->
probe63-after`. A row was accepted only when the two probe63 reads matched,
all snapshot validity flags were set, and `SNAPSHOT_CYCLES` was in the legal
range `0..124999999`.

## Phase-A gate evidence

All three paired gate samples passed. Both boards retained:

```text
SI_CONFIG=1
WR_READY=1
CORE_TM_LINK_UP=1
CORE_LINK_OK=1
TIME_VALID=1
PPS_VALID=1
CPU_RESET_N=1
PHY_RST=0
PHY_TX_DISABLE=0
```

The reset signature stayed constant on both boards:

```text
BOOT_GENERATION=1
CPU_RESET_COUNT=1
WR_CORE_RESET_COUNT=1
SI_CONFIG_DROP_COUNT=1
```

Slave-specific readiness also remained true throughout the accepted rows:

```text
RX_LOCKED_TO_DATA=1
RX_PATTERN_READY=1
SPLL_SEQ_STATE=8
PSTAT_LOCKED=1
MAIN_LOCKED=1
```

## Same-PPS result

| Common `SNAPSHOT_TAI` | Master cycles | Slave cycles | Delta ticks | Delta ns |
|---:|---:|---:|---:|---:|
| 9222 | 123289344 | 123289344 | 0 | 0 |
| 9223 | 123289344 | 123289344 | 0 | 0 |
| 9224 | 123289344 | 123289344 | 0 | 0 |
| 9225 | 123289344 | 123289344 | 0 | 0 |
| 9226 | 123289344 | 123289344 | 0 | 0 |

Summary:

```text
COMMON_TAI_LABELS=5
MASTER_LABEL_COUNT=5
SLAVE_LABEL_COUNT=5
EXACT_MATCH_COUNT=5
UNIQUE_DELTA_TICKS=0
MAX_ABS_DELTA_TICKS=0
MAX_ABS_DELTA_NS=0
RUNTIME_INVALID=false
STABILITY_LOSS=false
COHERENCE_VIOLATION=false
```

The cycle value `123289344` is legal for the 125 MHz WR timebase because it is
below `125000000` cycles per second.

## Interpretation

Step6A-1 (Global-Time validity and late-recovery stability) was already passed
by the preceding tail-stability experiment. This run now passes Step6A-2:
the two boards agree on the same PPS-labelled Global-Time snapshot at five
distinct seconds with zero digital cycle-label difference.

Therefore the current Step6 status is:

```text
Step6A Global Time observability/consistency = PASS
Step6B scheduled dual-board trigger          = NOT_RUN
```

The next experiment, after adviser review, may be Step6B: arm a minimal
future-time trigger on both boards and measure the two physical output edges.
No Step6B implementation or functional hardware write was performed here.

## Evidence hashes

SHA-256 values are for the files copied from Pain after the observer completed:

The raw log was normalized only by removing trailing whitespace from fixed
width Quartus informational text; measured observer fields and records were
not edited before hashing.

```text
raw/observe/same_pps_consistency.log
148190E9D2325EDDDFB9229D09754D577B55377D6C550824741EE8FB39AAAA1E

analysis/summary.json
623D012CBF1DC2DB5CD50C6F80DAD3AE29EE692C5E6FFC0C0C3F96C468361F91

analysis/analyzer.txt
623D012CBF1DC2DB5CD50C6F80DAD3AE29EE692C5E6FFC0C0C3F96C468361F91

raw/protocol.txt
CB671277C166A7639D1BAA68E430847A33E739B46D7CAF50FDC517241D3778B3

raw/program/stop.txt
0B34047ACE11335A1B61DF0A7DC895E0A5891AF4F154F90F684DC3C5C41E4798
```
