# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-HARDWARE-RUN-V2-20260922

## Verdict

```text
VERDICT = INCONCLUSIVE
CLASSIFICATION = INCONCLUSIVE_STEP6A_PRECONDITION_NOT_RECOVERED
STEP6A = NOT_PASS
STEP6B_POSTFIT_TIMING = PASS_STEP6B_POSTFIT_TIMING_PROVEN
STEP6B_1_DIGITAL_SCHEDULED_TRIGGER = NOT_RUN
STEP6B_PHYSICAL_EDGE = NOT_EVALUATED
TARGET/ARM WRITES = 0
```

Both direct programming operations succeeded, but the newly programmed images
did not re-establish the Step6A pre-arm time-valid gate within 60 seconds. The
observer therefore stopped before target or ARM writes. This is not a Step6B
trigger failure and does not claim Step6A or Step6B functional PASS.

## Source and fitted-artifact provenance

```text
Laptop/Pain source commit = bbbac332bf455101a6c1dca2bca6896e2dfae417
Fitted design source      = c24568e383be3355ac8684b7d13f293115931586

Master SOF SHA256 = 1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5
Slave SOF SHA256  = 66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151
Master MIF SHA256 = 8b569afe29d93cfedca84eed484c9c683f1fc58cf10e89943574b7de8d31df7e
Slave MIF SHA256  = eab60d5ceb4af234284f6f241a4595ee850cf3a0184a939d70a30c3d8a5ad26b

POSTFIT_TIMING = PASS_STEP6B_POSTFIT_TIMING_PROVEN
PROVENANCE_CHECK = 1
COMPILE = NO
FIRMWARE_BUILD = NO
```

## Direct programming result

The approved direct non-sudo, Master-last sequence completed exactly once per
board:

```text
Slave cable = DE5 [1-11.2]
Slave SOF checksum = 0x30B1E229
Slave start = 2026-09-22T05:24:13+08:00
Slave done  = 2026-09-22T05:24:33+08:00
Slave result = Configuration succeeded -- 1 device(s) configured;
               Successfully performed operation(s); 0 errors

Master cable = DE5 [1-11.1]
Master SOF checksum = 0x30B18F28
Master start = 2026-09-22T05:24:33+08:00
Master done  = 2026-09-22T05:24:52+08:00
Master result = Configuration succeeded -- 1 device(s) configured;
                Successfully performed operation(s); 0 errors

PROGRAM_METHOD = DIRECT_NON_SUDO
SLAVE_PROGRAM_COUNT = 1
MASTER_PROGRAM_COUNT = 1
PROGRAM_ORDER = SLAVE_THEN_MASTER
```

No programming retry, power cycle, CPU/WR/PHY reset, Master PTP restart, or
mode command occurred.

## Step6A pre-arm observation

```text
S6B_GATE_RESULT = INCONCLUSIVE_STEP6A_PRECONDITION_NOT_RECOVERED
PAIRED_HEALTHY = 0
COMMON_TAI_COUNT = 0
COHERENCE_VIOLATION = 0
```

Master recovered its link and time-valid snapshot path during the window. The
Slave link also remained healthy and eventually reached:

```text
RX_LOCKED_TO_DATA = 1
RX_PATTERN_READY = 1
SPLL_SEQ_STATE = 8
PSTAT_LOCKED = 1
MAIN_FREQ_LOCKED = 1
MAIN_PHASE_LOCKED = 1
MAIN_LOCKED = 1
```

However, Slave `STATUS_TIME_VALID=0` and `STATUS_PPS_VALID=0` remained at the
end of the gate, with no accepted snapshot. Its observed protocol state was
not the exact approved fallback signature: the late samples showed
`PTP_STATE=9`, but `PD_STATE=3` and `EXT_STATE=1` rather than `4` and `2`.
Therefore the observer correctly did not issue the conditional Slave-only
`ptp stop`/`ptp start` recovery.

Reset evidence stayed stable (`BOOT_GENERATION=1`, CPU/WR reset counts and
SI-config drop count unchanged at 1). Since the paired time-valid gate never
passed, the observer performed no target write, ARM write, trigger capture, or
physical-edge measurement.

## Boundary for next decision

This run isolates the remaining boundary after the programmer issue was fixed:

```text
direct programmer access       = PASS
Slave/Master programming       = PASS
link and Slave PLL lock        = eventually present
Slave Global Time/PPS validity = NOT_RECOVERED
Step6B digital trigger         = NOT_REACHED
```

The raw observer log and program logs are preserved in this experiment
directory. No further hardware action is taken until the adviser reviews this
new Step6A pre-arm result and gives the next single experiment.
