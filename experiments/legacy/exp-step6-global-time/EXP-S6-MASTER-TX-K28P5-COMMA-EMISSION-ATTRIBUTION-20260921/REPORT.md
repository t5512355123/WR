# EXP-S6-MASTER-TX-K28P5-COMMA-EMISSION-ATTRIBUTION-20260921

## Verdict

```text
EXP_RESULT                         = POST_MASTER_REPROGRAM_RECOVERY_OBSERVED
POST_MASTER_REPROGRAM_RECOVERY     = OBSERVED
FAILURE_CLASS                      = STARTUP_ORDER_SENSITIVE_LINK_ACQUISITION
MASTER_DIAG_LOCAL_READY            = PASS
MASTER_TX_COUNTER_ACTIVITY         = OBSERVED
MASTER_TX_K28P5_EMISSION_FORMAL_PASS = NOT_CLAIMED
STEP6A_GLOBAL_TIME                 = NOT_PASS
STEP6B                             = NOT_RUN
S_LOCK                             = NOT_REACHED_BY_THIS_OBSERVER
```

This is a valid diagnostic stop, not a Step6A pass.  The run stopped at the
first formal sample because the predeclared exception was observed on the
Slave: `CORE_LINK_OK=1` and `RX_PATTERN_READY=1` after the Master diagnostic
image was programmed.  Therefore the required five-sample comma decision was
not attempted and no standalone `MASTER_TX_K28P5_EMISSION=PASS` claim is made.

## Question and source boundary

The experiment asked whether the Master TX PCS presents K28.5 at the
parallel interface immediately before the Arria-10 transceiver.  The Master
observer counted:

```text
TX_CYCLE_COUNT += 1 on each rising_edge(wr_tx_clk)
TX_K28P5_COUNT += 1 when core_tx_k(0)='1 and core_tx_data=x"BC"
```

The observer is passive.  It has no feedback into the TX path, reset tree,
PHY, WR/PTP state machine, or SoftPLL.

The Master functional base reference was exact `ec1f25e8`; the diagnostic
image was built from source commit `7acbc58b9363a4cc036f45d1a79c0bfd7b3e3368`.
Commit `d40ed7f3d51dce6203a441956af63f0d69d7cd4e` only fixed a Tcl variable
name collision after the first observer invocation aborted before any sample;
it did not alter the compiled VHDL or the programmed SOF.

## Build and programming evidence

Pain performed a Master-only full Quartus compile:

```text
COMPILE_RESULT       = PASS
COMPILE_ERRORS       = 0
COMPILE_WARNINGS     = 297
FITTER_RESULT        = PASS
ASSEMBLER_RESULT     = PASS
TIMING_CLOSED        = NO   (not a decision criterion for this experiment)
```

Programmed artifact:

```text
target               = DE5 [1-11.1]
program count        = 1
program result       = PASS (RC=0)
Quartus SOF checksum = 0x30B50A9D
SOF SHA-256          = f371c0ed3df88f629d1c57d2333246395a92993420435039619867fe88449487
```

The Slave was not compiled or programmed.  There was no firmware build,
power cycle, PHY reset, PTP restart, mode command, fiber/QSFP change,
SI5340 change, or MDIO write.

## Runtime evidence

The corrected read-only observer returned `OBSERVER_RC=0` and Quartus STP
reported zero errors and zero warnings.

### Master local-ready gate

Three consecutive valid samples passed:

```text
SI_CONFIG_DONE = 1
WR_READY       = 1
TX_READY       = 1
CPU_RESET_N    = 1
PHY_RST        = 0
PHY_TX_DISABLE = 0
```

The baseline was:

```text
TX_CYCLE_COUNT = 2574947215
TX_K28P5_COUNT = 1283611603
BOOT_GENERATION = 00000001
CPU_RESET_COUNT = 00000001
WR_CORE_RESET_COUNT = 00000001
SI_CONFIG_DROP_COUNT = 00000001
```

The first formal sample showed positive TX activity and positive K28.5 count:

```text
TX_CYCLE_COUNT       = 2592304172
TX_K28P5_COUNT       = 1292289904
TX_CYCLE_DELTA       = 17356957
TX_K28P5_DELTA       = 8678301
```

This is strong local evidence that the Master parallel TX boundary was
active and presented K28.5 during the sample.  It is intentionally recorded
as evidence, not as the formal five-sample emission PASS, because the
predeclared Slave recovery exception stopped the capture after one formal
sample.

### Slave recovery exception

The first paired Slave sample was:

```text
CORE_TM_LINK_UP       = 1
CORE_LINK_OK          = 1
RX_LOCKED_TO_DATA     = 1
RX_SYNCSTATUS         = 0
RX_PATTERN_READY      = 1
RX_ACTIVITY_COUNT     = 21391
POST_MASTER_REPROGRAM_RECOVERY = 1
```

V3 had recorded `RX_PATTERN_READY=0` throughout its Slave-first capture.
The transition to `RX_PATTERN_READY=1` after Master-only programming is the
predeclared startup-order exception, so the experiment stopped immediately.

## First observer invocation

The first observer invocation was not a hardware result.  It aborted before
opening a board because the Tcl variable `snap` collided with the global
array created by the read-only transport library:

```text
can't set "snap": variable is array
```

That log is preserved under `raw/observation/`.  The variable-only fix was
pushed as `d40ed7f3`, pulled to Pain, and the corrected observer then ran
successfully.  No FPGA programming was repeated for this script-only fix.

## Raw evidence and reproducibility

The unmodified Pain stdout, build reports, programmer output, SOF, and
checksums are under `raw/`.  The corrected observer raw log is:

```text
raw/observation-v2/master-tx-comma-attribution.log
SHA-256 = 03DBA4CC82C29BAE873A53F5222FF680DF7B7863BE2FB8B65595142B0A5DA8DE
```

Offline analyzer result:

```text
CLASSIFICATION=POST_MASTER_REPROGRAM_RECOVERY_OBSERVED
LOCAL_READY_PASS=True
FORMAL_SAMPLES=1
TRANSPORT_ERRORS=0
RESET_CHANGES=0
TX_CYCLE_DELTA=17356957
TX_K28P5_DELTA=8678301
STEP6A=NOT_PASS
STEP6B=NOT_RUN
```

The build/source/program/observer checksums are also preserved in the
corresponding raw subdirectories.
