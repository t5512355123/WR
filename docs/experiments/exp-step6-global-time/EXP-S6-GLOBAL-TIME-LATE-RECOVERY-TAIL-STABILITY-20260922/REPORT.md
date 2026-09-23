# EXP-S6-GLOBAL-TIME-LATE-RECOVERY-TAIL-STABILITY-20260922

## Verdict

```text
RESULT=PASS_LATE_RECOVERY_STABLE
GLOBAL_TIME_LATE_RECOVERY=CONFIRMED_STABLE
SLAVE_GLOBAL_TIME_COUNTER=PASS
SLAVE_PPS_SNAPSHOT=PASS
STEP6A_1=PASS
STEP6A_GLOBAL_TIME=PARTIAL_PASS_STEP6A1
MASTER_SLAVE_SAME_PPS=NOT_EVALUATED
STEP6B=NOT_RUN
```

This confirms that the previous 29.772-second sample was a late recovery,
not a transient one. The existing runtime session continued into a stable
Global-Time window without another PTP command, reset, programming step, or
power cycle.

## Provenance and protocol

```text
BRANCH=exp/step6-Global-Time-Testing
SOURCE_COMMIT=6edae336377268be4c82eb860f214a27ce8a92e1
MASTER_COMPILE=NO
SLAVE_COMPILE=NO
MASTER_PROGRAM=NO
SLAVE_PROGRAM=NO
MASTER_PTP_RESTART=NO
SLAVE_PTP_RESTART=NO
MODE_COMMAND=NO
CPU_RESET=NO
WR_CORE_RESET=NO
PHY_RESET=NO
POWER_CYCLE=NO
FIBER_QSFP_CHANGE=NO
AUTONEG_SI5340_MDIO_CHANGE=NO
```

## Phase A: current-session gate

All 3 paired health samples passed. Both boards remained link-healthy; Slave
kept `RX_LOCKED_TO_DATA=1`, `RX_PATTERN_READY=1`, and changing RX activity.
The reset/configuration signature stayed constant:

```text
BOOT_GENERATION=1
CPU_RESET_COUNT=1
WR_CORE_RESET_COUNT=1
SI_CONFIG_DROP_COUNT=1
```

Slave `TIME_VALID` was intentionally not used as a gate, because its recovery
was the subject of this experiment.

## Phase B: stable Global-Time tail

The observer captured 5 paired samples and stopped as soon as the formal gate
passed, after 6043 ms. All 10 rows were read-valid and capture-healthy, with
no reset change. Slave accepted all 5 samples consecutively:

```text
STATUS_TIME_VALID=1
SNAPSHOT_VALID=1
SNAPSHOT_TIME_VALID=1
SNAPSHOT_PPS_VALID=1
CORE_LINK_OK=1
CORE_TM_LINK_UP=1
RX_LOCKED_TO_DATA=1
RX_PATTERN_READY=1
SPLL_SEQ_STATE=8 (SEQ_READY)
PSTAT_LOCKED=1
MAIN_LOCKED=1
```

The Slave snapshot values were:

```text
TAI:             7839, 7840, 7842, 7843, 7844
SNAPSHOT_COUNT:  1519, 1520, 1522, 1523, 1524
SNAPSHOT_CYCLES: 123289344 on every accepted sample
```

`SNAPSHOT_COUNT` advanced 4 times, exceeding the required 2 advances. The
snapshot cycle value is within the 125 MHz one-second range
`0 <= cycles <= 124999999`.

The live Global-Time ticks were strictly increasing:

```text
980082660446
980242800913
980404087945
980566270103
980726812549
```

There were no time-valid rising or falling edges within the tail because the
session was already valid at the first tail sample; this is consistent with a
stable late-recovered state.

## Stored evidence

```text
raw/observe/late_recovery_tail.log
  SHA256=916252491EBA722963A8CDBA03C54D55E8155CAFAE26911C870F5A57BAE78507

analysis/summary.json
  SHA256=76F95CE99C03310E83F4508D5E91D3EBD4B752D1D5B3CEDCA9B33B4C351A2451
```

The Pain home-directory archive audit also recovered a distinct supplemental
capture at `raw/observe/late_recovery_tail_pre_pull.log`:

```text
SHA256=7372cf01fce4da4685366dc519941165f5e17d395bca0fb7428ae7e06bef7b47
```

This file is retained separately and is not substituted for the canonical
`late_recovery_tail.log`; the formal PASS criteria and verdict are unchanged.

## Boundary and next action

Step6A-1 Global-Time recovery is now a functional PASS. This experiment did
not compare Master and Slave PPS snapshots, and it did not implement or test
scheduled dual-board triggering. Therefore Step6B remains not run. The next
step requires a new adviser contract for Step6A-2 same-PPS consistency before
any trigger module is added.
