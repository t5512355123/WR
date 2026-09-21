# EXP-S6-MASTER-TX-K28P5-COMMA-EMISSION-ATTRIBUTION-20260921

## Purpose

This experiment separates two possible causes of the Step6A blocker:

1. the Master TX PCS is not presenting the expected 8-bit K28.5 alignment
   comma at the Arria-10 transceiver parallel interface; or
2. the Master presents the comma, but it is lost or not acquired downstream by
   the serial link or the Slave receiver word aligner.

The experiment is based on the V3 result: the Slave had recovered RX activity
and `RX_LOCKED_TO_DATA=1`, but `RX_SYNCSTATUS=0` and `RX_PATTERN_READY=0` for
the formal window. It is not a Step6A or Step6B pass experiment.

## Source and allowed change

- Base functional source: exact `ec1f25e8` diagnostic source.
- Functional source change: none.
- Allowed production change: passive observer logic in
  `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd` only.
- Allowed observer: TX-clock-domain `TX_CYCLE_COUNT` and `TX_K28P5_COUNT`,
  plus a read-only status probe for `core_tx_data`, `core_tx_k`,
  `wr_tx_ready`, `wr_tx_enc_err`, `core_phy_rst`, and
  `core_phy_tx_disable`.
- Allowed scripts/tests/record: the Tcl observer, offline analyzer, tests,
  and this experiment directory.

`TX_K28P5_COUNT` increments only when `core_tx_k(0)='1'` and
`core_tx_data=x"BC"`. The counters do not feed back into the TX path,
reset tree, WR state machine, PHY, or any board output.

## Forbidden changes

No changes to Slave RTL, the vendor WR core, wrpc firmware/MIF, generated
Arria-10 transceiver IP, QSF/SDC, `g_use_simple_wa`, polarity, bitslip,
autonegotiation policy, SI5340, SFP/QSFP, PHY reset behavior, PTP/WR state
machine, or SoftPLL.

## Hardware contract

| Action | Contract |
| --- | --- |
| Master full compile | YES |
| Master program | YES, exactly once |
| Slave compile/program | NO |
| Firmware build | NO |
| Power cycle / PHY reset / PTP restart | NO |
| Mode command / fiber change / SI5340 / MDIO write | NO |

The Slave keeps the exact V3 image and is sampled only for the predeclared
post-Master-program recovery exception.

## Observation procedure

1. Program the Master diagnostic SOF once after a successful full compile.
2. Obtain at least three consecutive Master local-ready samples:

   ```text
   SI_CONFIG_DONE=1
   WR_READY=1
   TX_READY=1
   CPU_RESET_N=1
   PHY_RST=0
   PHY_TX_DISABLE=0
   ```

3. Use the last local-ready sample as the counter baseline.
4. Collect five Master formal samples in a window no longer than 2 seconds.
5. Read the Slave status alongside those samples. If `PATTERN_READY=1`,
   `SYNCSTATUS=1`, or `CORE_LINK_OK=1` appears after Master programming,
   stop immediately as the startup-order exception.
6. Do not issue any write or reset during the capture.

## Predeclared decision and stop conditions

| Evidence after baseline | Classification |
| --- | --- |
| `ΔTX_CYCLE_COUNT > 0` and `ΔTX_K28P5_COUNT > 0` | `MASTER_TX_K28P5_EMISSION_PASS` |
| `ΔTX_CYCLE_COUNT > 0` and `ΔTX_K28P5_COUNT = 0` | `FAIL_MASTER_TX_PCS_COMMA_GENERATION` |
| `ΔTX_CYCLE_COUNT = 0` | `INCONCLUSIVE_TX_CLOCK_NO_ACTIVITY` |
| local-ready does not reach three consecutive samples | `INCONCLUSIVE_DIAG_IMAGE_STARTUP` |
| reset/generation changes, invalid transport, or fewer than five formal samples | corresponding `INCONCLUSIVE_*` result |
| Slave recovery exception | `POST_MASTER_REPROGRAM_RECOVERY_OBSERVED` |

If the Master emits K28.5 while the Slave remains data-locked but has no
sync/pattern indication, record the boundary as:

```text
MASTER_TX_COMMA_SOURCE=PRESENT
SLAVE_WORD_ALIGN=FAIL
FAILURE_CLASS=FAIL_MASTER_TO_SLAVE_COMMA_DELIVERY_OR_RX_ALIGNMENT
S_LOCK=NOT_REACHED
STEP6A_GLOBAL_TIME=NOT_PASS
STEP6B=NOT_RUN
```

## Required record

After the Pain capture, copy the unmodified raw stdout and its checksum here,
run `scripts/analysis/step6_master_tx_comma_attribution.py`, write `REPORT.md`
with the exact source/SOF hashes and hardware contract, then push only the
experiment artifacts and the allowed observer changes.
