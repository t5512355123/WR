# EXP-S6-MASTER-LAST-EXACT-IMAGE-RECOVERY-ATTRIBUTION-20260921

## Question

Does programming the exact `ec1f25e8` Master last recover the Slave, when the
exact `ec1f25e8` Slave is left running?  This separates startup/programming
order from the different diagnostic Master bitstream used in the preceding
capture.

The comparison is:

```text
exact Master first -> exact Slave last  = V3 failure
exact Slave remains running -> exact Master last = this experiment
```

## Fixed artifacts

```text
SOURCE_COMMIT       = ec1f25e81e0eb8c2caee796d13a225eaae81e5f2
MASTER_SOF_SHA256   = 568f08c974064bdd3e82f68e3f1ecb0ff6c8a2a8e5705bdcc15b5941d33173a3
SLAVE_SOF_SHA256    = 7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e
MASTER_CABLE        = DE5 [1-11.1]
SLAVE_CABLE         = DE5 [1-11.2]
```

The exact Master artifact is hash-checked on Pain before programming.  The
Slave is not programmed in this experiment and its current image is not
changed.

## Hardware contract

```text
MASTER FULL COMPILE = NO
SLAVE FULL COMPILE  = NO
FIRMWARE BUILD      = NO
MASTER PROGRAM      = YES, exactly once
SLAVE PROGRAM       = NO
POWER CYCLE         = NO
PHY RESET           = NO
PTP RESTART         = NO
MODE COMMAND        = NO
FIBER/QSFP CHANGE   = NO
POLARITY CHANGE     = NO
BITSLIP CHANGE      = NO
AUTONEG CHANGE      = NO
SI5340 CHANGE       = NO
MDIO WRITE          = NO
```

Only the read-only observer/orchestration, offline analyzer, tests, and this
experiment documentation are changed.  No VHDL, QSF, SDC, MIF, vendor core,
firmware, or production control is changed.

## Procedure

1. Before touching Master, collect five paired read-only preflight samples.
2. Require both boards to have `SI_CONFIG_DONE=1`, `WR_READY=1`,
   `RX_READY=1`, `TX_READY=1`, `CPU_RESET_N=1`, `PHY_RST=0`, and
   `PHY_TX_DISABLE=0`.  Require Slave `RX_LOCKED_TO_DATA=1` and changing
   recovered-RX activity.  If this gate fails, do not program Master.
3. Verify the exact Master SOF SHA-256.
4. Program Master once and launch the paired observer immediately; record
   programmer and observer timestamps.
5. Require Master local-ready for three consecutive samples within 10 seconds.
6. Observe for at most 120 seconds after Master programming at approximately
   250 ms cadence.  Stop at the first five-sample Slave streak satisfying:

   ```text
   RX_LOCKED_TO_DATA = 1
   RX activity changed
   RX_PATTERN_READY  = 1
   CORE_LINK_OK      = 1
   CORE_TM_LINK_UP   = 1
   ```

   Reset/generation/configuration counters must remain stable.

## Stop and verdict rules

- `PASS_EXACT_MASTER_LAST_RECOVERY`: five consecutive good Slave samples.
- `FAIL_TRANSIENT_RECOVERY`: pattern/link recovery is observed but the
  five-sample streak is lost before completion.
- `FAIL_EXACT_MASTER_LAST_RECOVERY_NOT_REPRODUCED`: Master local-ready passes,
  Slave remains healthy, but no five-sample recovery streak occurs within
  120 seconds.
- `INCONCLUSIVE_PREPROGRAM_STATE`: preflight gate fails; Master is not
  programmed.
- `INCONCLUSIVE_TRANSPORT`, `INCONCLUSIVE_RESET`, or
  `INCONCLUSIVE_MASTER_LOCAL_READY`: invalid transport, unexpected reset, or
  Master local-ready does not form within its deadline.  Do not retry in the
  same session.

This experiment does not claim Step6A Global Time or Step6B scheduled trigger;
both remain `NOT_PASS`/`NOT_RUN` regardless of the recovery result.
