# EXP-S6-SLOCK-MASTER-FIRST-REACQUISITION-V2-20260921

## Verdict

```text
MASTER_LOCAL_READY          = PASS
SLAVE_PROGRAM               = PASS
POST_SLAVE_LINK_GATE_MASTER = FAIL
POST_SLAVE_LINK_GATE_SLAVE  = FAIL
SLOCK_MASTER_FIRST          = NOT_REACHED
STEP6A_GLOBAL_TIME          = NOT_PASS
STEP6B_SCHEDULED_TRIGGER    = NOT_RUN
POWER_CYCLE                 = NOT_PERFORMED
FULL_COMPILE                = NOT_PERFORMED_BY_DESIGN
```

The run stopped at the correct post-Slave link boundary.  It did not produce
an S_LOCK acquisition verdict.

## Provenance and fixed variables

- Branch: `exp/step6-Global-Time-Testing`
- Observer/gate commit: `8ec2162e`
- Exact image source: `ec1f25e81e0eb8c2caee796d13a225eaae81e5f2`
  (`ec1f25e8`)
- Master SOF SHA256:
  `568f08c974064bdd3e82f68e3f1ecb0ff6c8a2a8e5705bdcc15b5941d33173a3`
- Slave SOF SHA256:
  `7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e`
- Master cable: `DE5 [1-11.1]`
- Slave cable: `DE5 [1-11.2]`
- Full compile: not performed.
- Power-cycle, PTP restart, mode command, and fiber operation: not performed.
- Master was not reprogrammed for V2; its existing boot was retained.

## Sequence

The Master local-ready recheck passed immediately before Slave programming:

```text
MASTER_LOCAL_READY_RECHECK = 5 valid samples
MASTER_LOCAL_READY         = PASS
```

The exact Slave SOF then programmed successfully:

```text
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
0 errors, 0 warnings
```

Recorded sequence:

```text
Master program completed       = 11:11:46 +08:00
Master local-ready recheck     = 11:32:09–11:32:13 +08:00
Slave program start            = 11:32:51 +08:00
Slave program completed        = 11:33:10 +08:00
Post-Slave observers started   = 11:33:10 +08:00
Master settle before Slave     = approximately 1265 s
```

The two post-Slave observers sampled at the requested 500 ms cadence; JTAG
transaction time produced approximately 0.69 s sample spacing.  Both logs
contain 45 valid samples and stopped at approximately 30.9 s.

## Master local-ready evidence

All five local-ready samples were valid and stable:

```text
SI_CONFIG_DONE       = 1
WR_READY             = 1
WR_RX_READY          = 1
WR_TX_READY          = 1
WR_RX_LOCKED_TO_DATA = 1
CPU_RESET_N          = 1
PTP_STATE            = 6 (MASTER)
WR_DISABLE_VALID     = 0
BOOT_GENERATION      = 0x00000001
CPU_RESET_COUNT      = 0x00000001
WR_CORE_RESET_COUNT  = 0x00000001
SI_CONFIG_DROP_COUNT = 0x00000001
```

`CORE_TM_LINK_UP` and `CORE_LINK_OK` were recorded as 0, as expected for the
peer-dependent pre-Slave state and intentionally were not used to reject the
local-ready gate.

## Post-Slave link gate evidence

The required full link gate was evaluated separately on both boards:

```text
SI_CONFIG_DONE        = 1
WR_READY              = 1
WR_RX_READY           = 1
WR_TX_READY           = 1
WR_RX_LOCKED_TO_DATA  = 1 (after initial Slave startup samples)
CORE_TM_LINK_UP       = 0
CORE_LINK_OK          = 0
LINK_GATE_STREAK_MAX  = 0
```

Neither board reached five consecutive samples with the complete gate.  The
Master stayed in `PTP_STATE=6` but never asserted the two core link bits.  The
Slave progressed from its immediate post-program initialization to
`PTP_STATE=4` by the final sample, but also never asserted the two core link
bits.  Both boards remained transport-valid with unchanged reset/generation
counters.

Because the post-Slave link gate did not pass within 30 seconds:

```text
POST_SLAVE_LINK_GATE = FAIL
SLOCK_FIRST_ENTRY    = NOT_OBSERVED
LOCK_POLLS           = 0
LOCK_SUCCESS_COUNT   = NOT_APPLICABLE
```

This is not a valid `FAIL_SPLL_NOT_LOCKED_BEFORE_SLOCK_DEADLINE` result: the
experiment never reached the WR S_LOCK state machine.

## Interpretation

V2 successfully corrected the pre-Slave gate semantics and confirmed that the
Master was locally ready before the Slave was programmed.  The new causal
boundary is now after Slave programming and before WR S_LOCK: the two-board
WR endpoint/link session did not establish within 30 seconds.  No conclusion
about startup-order sensitivity or SoftPLL acquisition latency is allowed yet.

The next investigation must therefore target the post-Slave endpoint/link
establishment boundary, without changing S_LOCK timeout, PI, SoftPLL,
firmware, RTL, PHY, or reset behavior.

## Raw evidence

```text
79D9DF7C6C5B8FC8948F41CCB0C18C3A85622FD3681431AF2043BB62A1244C4E  raw/master-link/master-post-slave-link.log
6B9D1780599B567BA42E45BB55C955B150EB160FF119F436CF67E0905FBF29C7  raw/slave-reacq/slave-slock-reacquisition.log
1EA1750A82F9FB6B8297ADA029F59430A002958F402851A7131E36924B1AA112  raw/preflight/master-local-ready.log
EF6F3074D588C144891B50F7C8864BDC2A6B5AB54AFCCB3CA5A9775EFCC892C2  raw/program/program-slave-master-first.log
FA9EB3E6B2FD1AD099346F15E06225F259C3482CAFFDA7272E6453BCE408A31D  raw/program/sequence-times.log
A5C1902BFF12D0F06B892D0C6171EBE2A2E167F3014120F89E4935507E367905  raw/program/sof-sha256-before.txt
```

