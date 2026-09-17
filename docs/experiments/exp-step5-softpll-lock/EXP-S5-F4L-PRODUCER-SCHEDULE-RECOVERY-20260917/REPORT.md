# EXP-S5-F4L-PRODUCER-SCHEDULE-RECOVERY-20260917

## Verdict

```text
UPSTREAM_WR_LINK_RECOVERY = FAILED
F4S_PRODUCER_SCHEDULE     = NOT_RUN
F4L_PAGE_SCHEDULE_CAUSE   = NOT_EVALUATED
STEP5_PASS                = NO
MERGE_APPROVED            = NO
```

This recovery did not reach the F4S entry gate. It is not evidence that the
F4L page scheduler, Main enable, Helper, or phase controller is incorrect.

## Provenance

```text
Pain source/image commit = f847f4e74c5b16389c9848d4fe2592a9873a6b5c
Slave SOF SHA-256        = a39f315806251fe39b0d8ba62ac7a2b9aa908d9bae5593e771086f8978f02a49
Master SOF SHA-256       = b163ca1b084550e34335403fb168d68a3799799b14cfe527c25e9775be56cea1
```

These are the same validated original-path F4S images. No source file or
functional control parameter was changed in this recovery.

## Reprogramming

Slave was programmed first and Master second. Both Quartus Programmer
operations succeeded:

```text
Slave cable  = DE5 [1-11.2]
Slave checksum  = 0x30B84088
Master cable = DE5 [1-11.1]
Master checksum = 0x30B89B19
```

## Read-only preflight

The post-reprogram runtime preflight was collected at approximately
2026-09-17 11:13–11:14. The JTAG/WB transport completed without timeout or
protocol contamination, but the required WR link gate remained false on both
endpoints:

| signal | Master | Slave |
|---|---:|---:|
| `SI_CONFIG_DONE` | 1 | 1 |
| `CPU_RESET_N` | 1 | 1 |
| `WR_RX_READY` | 1 | 1 |
| `WR_TX_READY` | 1 | 1 |
| `WR_RX_LOCKED_TO_DATA` | 1 | 1 |
| `CORE_TM_LINK_UP` | 0 | 0 |
| `CORE_LINK_OK` | 0 | 0 |
| `PSTAT_LINK` / `PHY_LINK_USABLE` | 0 | 0 |

The Slave also showed `LOCK_ENABLE=1`, but its Step 4B result was still
`BLOCKED_BY_STEP1`; this does not override the failed link gate.

## Why F4S was not started

The authoritative F4S counters are already present in the f847 image, and
the laptop offline tests passed (`F4S_F4L_OFFLINE_TESTS=PASS`, 12 tests).
However, with `CORE_LINK_OK=0` on both boards, Main SoftPLL enable and the F4L
producer page path are not valid causal subjects. Starting F4S here would
only reproduce an upstream startup failure and could not distinguish:

```text
Main enable discontinuity
page scheduler failure
page2 due without publication
observer aliasing
```

Accordingly no F4S page, due, or publication value is interpreted in this
report, and no formal F4L capture was started.

## Interpretation and next boundary

The current session is blocked before the producer-schedule boundary:

```text
SI/config/reset/local RX/TX clocks  = PASS
WR endpoint link gate                = FAIL
Main F4L producer schedule           = NOT_REACHED
Step5 closed-loop lock               = NOT_REACHED
```

The four connected QSFP cables do not make the original image automatically
select another port. This run intentionally did not switch to QSFP-B, so the
QSFP-B topology remains a separate experiment and is not mixed into the
latest passive F4S diagnosis.

Do not change PI/gain/threshold/timeout or claim a page-scheduler root cause
from this run. Resume the latest F4S recommendation only after the original
path again satisfies the WR link gate.

## Raw evidence

The raw logs were generated on Pain at:

```text
docs/experiments/exp-step5-softpll-lock/EXP-S5-F4L-PRODUCER-SCHEDULE-RECOVERY-20260917/raw/program/slave-program.log
docs/experiments/exp-step5-softpll-lock/EXP-S5-F4L-PRODUCER-SCHEDULE-RECOVERY-20260917/raw/program/master-program.log
docs/experiments/exp-step5-softpll-lock/EXP-S5-F4L-PRODUCER-SCHEDULE-RECOVERY-20260917/raw/preflight-after-reprogram.log
```

Pain SHA-256:

```text
slave-program.log        6bec5598d22818e272f2739d9469e0d8144f8492c948a9d436f7a9c5d8d669eb
master-program.log       3c9167bc7744d6b0fe382848c4e7e2732d4fe3103bcf880e70f676004f179dec
preflight-after-reprogram.log
                          1282240e3ce39f7093c7b12b86b4d3081e11e458a464a4e0ef5bf36f8507fdc4
```
