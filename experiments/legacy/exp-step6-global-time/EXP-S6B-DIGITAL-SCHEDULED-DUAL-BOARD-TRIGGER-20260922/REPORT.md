# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-20260922

## Verdict

```text
RESULT=NOT_RUN_STEP6B_TIMING_NOT_PROVEN
STEP6A=PASS_PREVIOUS_EXPERIMENT
STEP6B_1_DIGITAL_SCHEDULED_TRIGGER=NOT_RUN
PROGRAM_COUNT=0
```

The run stopped before programming, exactly at the adviser-required
Step6B-specific timing gate.  This is not a digital-trigger failure and is
not a Step6B PASS: no hardware trigger observation was performed.

## Source and build

```text
LAPTOP_SOURCE_COMMIT=c24568e383be3355ac8684b7d13f293115931586
PAIN_SOURCE_COMMIT=c24568e383be3355ac8684b7d13f293115931586
SLAVE_BUILD_RC=0
MASTER_BUILD_RC=0
FIRMWARE_BUILD=NO
```

Both full Quartus compilations completed and produced SOFs:

```text
SLAVE_SOF_SHA256=66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151
MASTER_SOF_SHA256=1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5
SLAVE_MIF_SHA256=eab60d5ceb4af234284f6f241a4595ee850cf3a0184a939d70a30c3d8a5ad26b
MASTER_MIF_SHA256=8b569afe29d93cfedca84eed484c9c683f1fc58cf10e89943574b7de8d31df7e
MIF_UNCHANGED=YES
```

The build reported `TIMING_CLOSED=NO` for the full design.  That global
status was recorded only as context; it was not used as the Step6B gate.

## Step6B timing gate

The query used the existing `qsfp_ref_125m` clock and searched the synthesized
Step6B scheduler registers.  The register names were found, but TimeQuest did
not return setup/hold timing paths for the required groups:

```text
GROUP                         SLAVE                         MASTER
target_latch                  0/0 paths, 40 -> 40          0/0 paths, 40 -> 40
arm_sync                      invalid, 1 -> 2              invalid, 1 -> 2
comparator_fired              invalid, 1 -> 1              invalid, 1 -> 1
comparator_actual_tai         invalid, 1 -> 115            invalid, 1 -> 114
comparator_actual_cycles      invalid, 1 -> 102            invalid, 1 -> 103
```

Both timing reports therefore ended with:

```text
STEP6B_TIMING_RESULT=NOT_RUN_STEP6B_TIMING_NOT_PROVEN
REASON=target_latch_setup_or_hold_not_proven
```

This satisfies the stop rule.  The query must be corrected or otherwise
reviewed before any Step6B image is programmed; this report does not infer
that the RTL paths are functionally bad from the empty timing query.

## Programming and hardware observation

```text
SLAVE_PROGRAM_COUNT=0
MASTER_PROGRAM_COUNT=0
POWER_CYCLE=0
PTP_RESTART=0
SMA_CLKOUT_CHANGED=0
```

No board was reprogrammed, no reset or PTP command was sent, and no observer
arming or trigger capture was attempted.

## Raw evidence

* `raw/protocol.txt`
* `raw/build/source_identity.txt`
* `raw/build/slave_compile.log`
* `raw/build/master_compile.log`
* `raw/build/build_result.txt`
* `raw/timing/slave_step6b_timing.txt`
* `raw/timing/master_step6b_timing.txt`
* `raw/timing/slave_quartus_sta.log`
* `raw/timing/master_quartus_sta.log`
* `raw/program/stop.txt`

The next action is adviser review of the timing-query boundary.  No further
experiment is started from this report.
