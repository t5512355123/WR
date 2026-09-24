# EXP-S5-WR-LINK-STARTUP-TARGETED-RAW-20260916

## Verdict

```text
TARGETED_SNAPSHOT_VALID = YES
UPSTREAM_WR_LINK_STARTUP_BLOCKER = YES
STEP5_PASS = NO
F4M_RESULT = NOT_EVALUATED
PRELOAD_CAUSALITY = NOT_EVALUATED
```

This is the read-only follow-up requested after the exact-image cold replay of
commit `6fa075bd`. It closes the cold-replay/F4M attempt at the upstream WR
link-startup boundary. It does not evaluate the bumpless frequency-to-phase
preload, because the Slave never reached `LOCK_ENABLE` or SoftPLL startup.

## Scope and method

The target analysis instructed that no reprogramming or production-control
change should be made. This capture therefore used only existing JTAG direct
probe readers:

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_probe.tcl

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_clock_activity.tcl 2000
```

No Wishbone write, VUART command, reprogram, compile, firmware change, RTL
change, PI/gain change, timeout change, or preload change was made in this
experiment. `read_probe.tcl` reads direct instance 0 and
`read_clock_activity.tcl` reads direct instance 7.

Capture times on Pain were:

```text
instance 0: 2026-09-16T23:41:21+08:00
instance 7: 2026-09-16T23:42:16+08:00
Quartus:   17.0.0 Build 595
```

The exact remote logs were retained under Pain's preservation directory. Their
hashes are recorded in `manifest.json`.

## Instance 0: direct PHY/link probe

The direct probe words were:

```text
Master DE5 [1-11.1] = 0x2002EE020F008231
Slave  DE5 [1-11.2] = 0x000220020F008221
```

Decoded fields at the capture instant:

| Field | Master | Slave | Interpretation |
|---|---:|---:|---|
| `si_config_done` | 1 | 1 | SI configuration completed |
| `CPU_RESET_n` | 1 | 1 | CPU reset released |
| `core_phy_rst` | 0 | 0 | PHY is out of reset |
| `core_phy_tx_disable` | 0 | 0 | No explicit TX-disable assertion |
| `wr_ready` | 0 | 0 | WR core not ready |
| `core_tm_link_up` | 0 | 0 | Timing link not up |
| `core_link_ok` | 0 | 0 | WR link check not OK |
| `wr_rx_ready` | 0 | 0 | RX ready not asserted at this direct-probe instant |
| `wr_tx_ready` | 0 | 0 | TX ready not asserted |
| `QSFPA_MOD_PRS_n` raw | 0 | 0 | Active-low pin is low; raw electrical value only |
| `QSFPA_INTERRUPT_n` raw | 1 | 1 | Active-low pin is high; raw electrical value only |
| `wr_rx_locked_to_ref` | 1 | 1 | Reference-side lock indication |
| `wr_rx_locked_to_data` | 0 | 0 | Data-side lock not asserted |
| `wr_rx_syncstatus` | 0 | 0 | RX synchronizer not ready |
| `wr_rx_patterndetect` | 0 | 0 | Pattern detect not asserted |
| `wr_rx_pattern_ready` | 0 | 0 | Pattern alignment not ready |
| `wr_rx_disperr` | 0 | 0 | No disparity error at this instant |
| `wr_rx_errdetect` | 0 | 0 | No error-detect indication at this instant |
| `wr_rx_enc_err` | 0 | 0 | No encoding error at this direct-probe instant |
| `wr_tx_enc_err` | 0 | 0 | No TX encoding error |

The raw `MOD_PRS_n` and `INTERRUPT_n` values are not converted into a module
or interrupt claim; both are active-low electrical signals and are recorded
as raw values.

The earlier `read_wb_runtime.tcl --raw` snapshot at 23:35 also showed
`si_config_done=1`, `CPU_RESET_n=1`, `core_phy_rst=0`, `WR_READY=0`,
`CORE_TM_LINK_UP=0`, `CORE_LINK_OK=0`, `WR_TX_READY=0`, `PSTAT_LINK=0`, and
zero PTP RX activity. Some RX-ready/lock/error bits changed between the two
read-only capture times; those bits are treated as time-varying observations,
not contradictory permanent facts.

## Instance 7: clock activity

The two-second direct-probe window produced:

```text
Master BEGIN raw=00139E7C60EB5FE9 REF=24553 DMTD=24811 RX=40572
       PHY_READY=0 RX_LOCK_REF=1 RX_LOCK_DATA=0 TOGGLE=1/1/0
Master END   raw=001304304D2D4C69 REF=19561 DMTD=19757 RX=1072
       PHY_READY=0 RX_LOCK_REF=1 RX_LOCK_DATA=0 TOGGLE=1/1/0

Slave  BEGIN raw=0021CBA6D2EAD2CB REF=53963 DMTD=53994 RX=52134
       PHY_READY=0 RX_LOCK_REF=0 RX_LOCK_DATA=1 TOGGLE=1/0/0
Slave  END   raw=00261D6BBD6DBD8C REF=48524 DMTD=48493 RX=7531
       PHY_READY=0 RX_LOCK_REF=0 RX_LOCK_DATA=1 TOGGLE=0/1/1
```

The 16-bit counters are modulo counters. Their positive modulo deltas over
the window were:

```text
Master: REF=50544, DMTD=50482, RX=26036
Slave:  REF=60097, DMTD=60035, RX=20933
```

Thus reference, DMTD, and recovered-RX clock domains show activity. However,
`PHY_READY` remained 0 for both boards, and the lock indications were not a
stable WR data-link qualification. Clock activity alone is not a WR link or
SoftPLL-lock claim.

## Cross-check with the runtime snapshot

The preceding read-only runtime snapshot at approximately 23:35 had a trusted
Wishbone path:

```text
WB_REQUEST_COUNT = 352
PRELOAD_COUNT = 352
COMMIT_COUNT = 352
PROBE_3WAY_MATCH_COUNT = 352
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

It also showed Master local activity:

```text
DMTD_REF_ACCEPT delta = 13204
DMTD_FB_ACCEPT delta  = 23492
DMTD_ACCEPT delta     = 36696
TAG/TRR/IRQ/helper deltas ≈ 23500
BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta = 0
```

The Slave remained upstream of SoftPLL startup:

```text
LOCK_ENABLE = 0
SPLL_INIT_COUNT = 0
TAG/TRR/IRQ/helper deltas = 0
PSTAT_LINK = 0
```

This separates healthy local FPGA/SI/CPU/clock activity from the missing WR
link establishment. It does not identify a failed SFP component.

## Boundary classification

The evidence supports the following boundary:

```text
FPGA configured
  -> SI configured
  -> CPU running
  -> PHY reset released
  -> local reference/DMTD/RX clock activity
  -> PHY data/pattern/ready and TX/link bring-up   <-- BLOCKED
  -> WR endpoint/PTP link
  -> Slave LOCK_ENABLE
  -> Helper/Main SoftPLL
  -> frequency-to-phase preload
  -> Step5 closed-loop lock
```

Therefore the correct result is:

```text
UPSTREAM_WR_LINK_STARTUP_BLOCKER
STEP5_F4M = NOT RUN
PRELOAD_EVALUATION = NOT REACHED
```

This must not be reported as `BUMPLESS_PRELOAD_FAIL`, `F4M_FAIL`, or definite
`SFP_HARDWARE_FAILURE`.

## Next action boundary

This cold-replay/F4M line is now closed. Any continuation should be a separate
startup-debug experiment focused on why TX/PHY data-link bring-up does not
become ready. Until the WR entry gate is restored, do not alter PI/gain,
preload, timeout, detector, DAC, arbiter, mailbox, PHY, reset, or RTL
behavior, and do not start another formal F4M capture.

The minimum gate for returning to the Step5 experiment is:

```text
WR_CORE_VALID   = 1
PHY_LINK_USABLE = 1
PSTAT_LINK      = 1
TERMINAL        = 0
```

For the Slave, `LOCK_ENABLE` and subsequent Helper/Main activity must then be
observed before the preload can be evaluated.
