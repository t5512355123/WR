# EXP-WR-PHY-QSFPB-PORTB-DIAGNOSTIC-20260917

## Purpose

The current Step5 image is blocked upstream of SoftPLL: the latest A-port
recheck reports `PHY_READY=0`, `WR_TX_READY=0`, `CORE_TM_LINK_UP=0`, and
`CORE_LINK_OK=0`.  Because the four QSFP cables are already connected and
remote physical reseating is unavailable, this experiment uses QSFP-B as a
separate physical path.

This is a prerequisite isolation experiment.  It is not a Step5 lock claim.

## Source of the port map

The QSFP-B pin map was cross-checked against the retained Pain-side
`02_QSFP/week03/QSFP_4PORT/QSFP_4PORT.qsf` reference project and the historical
QSFP-B experiment record.  No B-port pin was guessed.

| Signal | Pin |
|---|---|
| `QSFPB_INTERRUPT_n` | `PIN_AK9` |
| `QSFPB_LP_MODE` | `PIN_AM10` |
| `QSFPB_MOD_PRS_n` | `PIN_AL10` |
| `QSFPB_MOD_SEL_n` | `PIN_AP6` |
| `QSFPB_REFCLK_p` | `PIN_AD5` |
| `QSFPB_RST_n` | `PIN_AR6` |
| `QSFPB_RX_p[0..3]` | `PIN_AN3`, `PIN_AL3`, `PIN_AJ3`, `PIN_AG3` |
| `QSFPB_SCL/SDA` | `PIN_AM7`, `PIN_AM8` |
| `QSFPB_TX_p[0..3]` | `PIN_AP1`, `PIN_AM1`, `PIN_AK1`, `PIN_AH1` |

## Deliberate changes

The independent `quartus/jtag_runtime_diag_portb` projects change only the
physical path and the corresponding clock routing:

1. WR data uses `QSFPB_TX_p(0)` / `QSFPB_RX_p(0)`.
2. WR PHY/reference clock uses `QSFPB_REFCLK_p`.
3. DDMTD uses `QSFPA_REFCLK_p`.
4. SI5340 outputs are swapped: OUT0/A=`124.992 MHz`, OUT1/B=`125 MHz`.
5. SFP detect, I2C, reset, module-select, and low-power control use QSFP-B.
6. Only `QSFPB_TX_p[0]` receives First Post-Tap=18.

The existing A-port Step5 source remains unchanged.  SoftPLL PI/gain,
thresholds, timeout, bootstrap, arbiter, mailbox, detector, reset behavior,
and observer logic are not changed.

## Pain procedure

1. Pull the commit containing this plan and the two independent B-port
   projects.
2. Compile `DE5a_wr_slave_portb.qpf` and
   `DE5a_wr_master_portb.qpf` with the established Quartus 17 flow.
3. Record compile summaries and SOF SHA-256 values.
4. Program Slave first, then Master.  Do not power-cycle unless the existing
   programming procedure requires it.
5. Run the existing read-only probes:

   - `scripts/jtag/read_probe.tcl`
   - `scripts/jtag/read_clock_activity.tcl 2000`

6. Save raw output, checksums, programming logs, and exact image hashes for
   transfer back to the laptop.

## Interpretation

The selected path is considered recovered only if both endpoints sustain the
expected PHY/WR readiness and link indicators during repeated reads.  A
single changing or partial probe is not Step5 success.  If B fails, the next
remote path candidate is QSFP-C lane 0; do not change Step5 control settings
on the basis of this experiment.

## Baseline

- Branch: `exp/step5-softpll-lock`
- Pre-change HEAD: `36546072`
- Current A-port image: `6fa075bd` source family, latest observed A-port
  status remained `PHY_READY=0` / `CORE_LINK_OK=0`.
