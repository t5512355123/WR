# EXP-S6-SLOCK-MASTER-FIRST-REACQUISITION-20260921

## Verdict

```text
MASTER_PRECONDITION              = INCONCLUSIVE_MASTER_PRECONDITION
SLAVE_PROGRAMMED                 = NO
SLOCK_MASTER_FIRST_REACQUISITION = NOT_RUN
STEP6A_GLOBAL_TIME               = NOT_PASS
STEP6B_SCHEDULED_TRIGGER         = NOT_RUN
POWER_CYCLE                      = NOT_PERFORMED
FULL_COMPILE                     = NOT_PERFORMED_BY_DESIGN
```

This run stopped before the Slave was programmed.  It therefore provides no
evidence for or against the Slave S_LOCK reacquisition hypothesis.

## Provenance

- Branch: `exp/step6-Global-Time-Testing`
- Exact image source: `ec1f25e81e0eb8c2caee796d13a225eaae81e5f2`
  (`ec1f25e8`)
- Observer commit used on Pain: `4d5ab6e8`
- Offline preflight analyzer fix: `969dc67c`
- Master cable: `DE5 [1-11.1]`
- Slave cable: `DE5 [1-11.2]`
- Programming order attempted: Master only; Slave was deliberately not
  programmed after the precondition failed.
- Power-cycle, PTP restart, mode command, and fiber operation: not performed.

The exact existing SOF artifacts were verified before programming:

```text
Master 568f08c974064bdd3e82f68e3f1ecb0ff6c8a2a8e5705bdcc15b5941d33173a3
Slave  7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e
```

## Master programming

Quartus Programmer reported:

```text
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
0 errors, 0 warnings
```

No compilation was performed.  This is intentional: the adviser required
reusing the exact `ec1f25e8` artifacts so that startup order remained the only
planned variable.

## Master precondition capture

The read-only observer collected 10 valid samples.  Wishbone transport had no
reported sample error, and the boot/reset counters stayed unchanged.  The
Master reached `PTP_STATE=6` after the initial startup samples, but the full
precondition never became true:

```text
SI_CONFIG_DONE        = 1 throughout
WR_RX_READY           = 1 throughout
WR_TX_READY           = 1 throughout
WR_RX_LOCKED_TO_DATA  = 1 throughout
PTP_STATE             = 4 initially, then 6
CORE_TM_LINK_UP       = 0 throughout
CORE_LINK_OK          = 0 throughout
BOOT_GENERATION       = 0x00000001 throughout
CPU_RESET_COUNT       = 0x00000001 throughout
WR_CORE_RESET_COUNT   = 0x00000001 throughout
SI_CONFIG_DROP_COUNT  = 0x00000001 throughout
WR_DISABLE_VALID      = 0 throughout
```

The observer ran for approximately 6.5 seconds; the measured sample gaps were
about 0.7 seconds because of the read-only JTAG transaction time.  Since the
required Master gate included both `CORE_TM_LINK_UP=1` and
`CORE_LINK_OK=1`, the gate was not satisfied.  In accordance with the plan,
the Slave was not programmed and no S_LOCK conclusion was made.

## Interpretation

This is an upstream Master precondition stop, not a `WR_S_LOCK_TIMEOUT` result
and not a Step6A result.  The experiment cannot yet test whether restoring
Master-first order allows the Slave SoftPLL to acquire before the 240 s S_LOCK
deadline.  No timeout, retry, PI, threshold, SoftPLL, PPS/PTP, RTL, or PHY
change was made.

The raw evidence and exact image hashes are preserved below.  A future run
must first establish the same Master precondition for 10 stable samples before
programming the Slave.

## Raw evidence

```text
047AF1A1D18EA1E72ADD56AA190CBD8C7F365300AABBA327F8868C41F58BDDD7  raw/program/program-master-first.log
6CF25A541836B5C131D5164F28280BE70F49D5CF9D560780D048C4268B30A0B5  raw/program/sof-sha256-before.txt
823BA22A9B8B12C27018DF5E08703E4934BF44B6DF0A0C72C28A232B75C99BC8  raw/preflight/master-preflight.log
```

