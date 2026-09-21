# EXP-S6A-ACTIVE-EXTENSION-LATE-GLOBAL-TIME-TAIL-20260922

## Verdict

```text
RESULT                         = PASS_ACTIVE_EXTENSION_LATE_GLOBAL_TIME_RECOVERY
STEP6A_REQUALIFICATION         = PASS
STEP6B_1_DIGITAL_TRIGGER      = NOT_RUN
STEP6B_PHYSICAL_EDGE           = NOT_EVALUATED
```

The existing programmed Step6B V2 session remained healthy through the complete
45-second read-only tail. Slave Global Time/PPS validity was valid for every
tail sample and the Master/Slave snapshot labels were coherent at zero tick
delta.

## Provenance

```text
Laptop/Pain observer commit   = 39c401494e156238f1096a46ec0621b6f13a2f9d
Fitted design source commit   = c24568e383be3355ac8684b7d13f293115931586
Post-fit timing proof         = PASS_STEP6B_POSTFIT_TIMING_PROVEN
```

The Pain-side provenance gate passed for both SOFs and both MIFs:

```text
Master SOF = 1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5
Slave  SOF = 66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151
Master MIF = 8b569afe29d93cfedca84eed484c9c683f1fc58cf10e89943574b7de8d31df7e
Slave  MIF = eab60d5ceb4af234284f6f241a4595ee850cf3a0184a939d70a30c3d8a5ad26b
PROVENANCE_CHECK = 1
```

## Hardware contract

No compile, firmware build, FPGA programming, reset, PTP restart, power cycle,
target write, ARM write, PHY/SI/MDIO write, or fiber/QSFP change was performed.
The V2 programmed session was preserved exactly as found.

```text
MASTER_PROGRAM_COUNT = 0
SLAVE_PROGRAM_COUNT  = 0
PTP_RESTART_COUNT    = 0
TARGET_WRITE_COUNT   = 0
ARM_WRITE_COUNT      = 0
POWER_CYCLE          = 0
```

## Phase A: current-session gate

Three paired read-only gate samples all passed:

```text
GATE_PAIRS             = 3 / 3
MASTER_LINK/TIME       = PASS on all gate pairs
SLAVE_ACTIVE_EXTENSION = PASS on all gate pairs
RESET_STABLE           = PASS on all gate pairs
```

The Slave gate held the required link, RX pattern, SoftPLL and lock state:

```text
CORE_LINK_OK       = 1
CORE_TM_LINK_UP    = 1
RX_LOCKED_TO_DATA  = 1
RX_PATTERN_READY   = 1
SPLL_SEQ_STATE     = 8
PSTAT_LOCKED       = 1
MAIN_FREQ_LOCKED   = 1
MAIN_PHASE_LOCKED  = 1
MAIN_LOCKED        = 1
PTP_STATE          = 9
PD_STATE           = 3
EXT_STATE          = 1
WRC_MODE           = 3
```

## Phase B: 45-second read-only tail

```text
TAIL_SAMPLES          = 61
VALID_SAMPLES         = 61
MAX_VALID_STREAK      = 61
FIRST_VALID_MS        = 0
LAST_VALID_MS         = 44529
SNAPSHOT_DELTA        = 45
COMMON_TAI_COUNT      = 45
MAX_ABS_DELTA_TICKS   = 0
MAX_ABS_DELTA_NS      = 0
TIME_VALID_RISING     = 0
TIME_VALID_FALLING    = 0
ACTIVE_SAMPLES        = 61
COHERENCE_VIOLATION   = 0
```

The first tail sample was already valid, so this run does not identify the
exact 0-to-1 recovery instant. It does establish that the recovered
active-extension session stayed valid for the full tail, with snapshot count
advancing and 45 distinct common TAI labels having identical sub-second cycle
values.

Reset signatures stayed unchanged in the raw samples:

```text
BOOT_GENERATION     = 1
CPU_RESET_COUNT     = 1
WR_CORE_RESET_COUNT = 1
SI_CONFIG_DROP_COUNT= 1
```

## Conclusion and next boundary

This experiment closes the Step6A late-tail requalification boundary:

```text
Slave Global Time/PPS validity       = PASS
Master/Slave common TAI coherence    = PASS
Active-extension stability           = PASS
Step6B-1 scheduled trigger           = NOT RUN
```

The next experiment must be separately approved before any target/ARM write.
This report intentionally does not claim the digital scheduled trigger or the
physical SMA edge result.

Raw observer log, protocol record, provenance record, stop record and analyzer
summary are stored beside this report.
