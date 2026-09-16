# EXP-WR-PHY-LINK-NONDESTRUCTIVE-HARDWARE-ISOLATION-20260916

## Status

```text
PRE_RESEAT_CAPTURE = VALID
POST_RESEAT_CAPTURE = NOT_RUN
AB_RESULT = PENDING_PHYSICAL_RESEAT
STEP5_PASS = NO
```

This is a separate startup-debug experiment following the
`UPSTREAM_WR_LINK_STARTUP_BLOCKER` result. The first physical A/B variable is
the same optical fiber being unplugged and reinserted at both ends. SFPs,
ports, SOF, firmware, and control parameters are to remain unchanged.

The post-reseat capture has not been run yet. No conclusion about the fiber,
SFP, board, or lane can be made from this pre-reseat baseline alone.

## Scope

No SOF reprogramming, compilation, firmware/RTL change, control write, VUART
command, PI/gain change, timeout change, or preload change was made. The
capture used the existing read-only scripts:

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_probe.tcl
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_clock_activity.tcl 2000
```

Capture time on Pain: `2026-09-16T23:51:18+08:00`.

## Pre-reseat instance 0

```text
Master DE5 [1-11.1] probe=0x4002EE020F008231
Slave  DE5 [1-11.2] probe=0x000220020F008221
```

Both boards decoded as:

```text
si_config_done=1
CPU_RESET_n=1
core_phy_rst=0
core_phy_tx_disable=0
wr_ready=0
core_tm_link_up=0
core_link_ok=0
wr_rx_ready=0
wr_tx_ready=0
QSFPA_MOD_PRS_n_raw=0
QSFPA_INTERRUPT_n_raw=1
wr_rx_locked_to_ref=1
wr_rx_locked_to_data=0
wr_rx_syncstatus=0
wr_rx_patterndetect=0
wr_rx_pattern_ready=0
wr_rx_disperr=0
wr_rx_errdetect=0
```

`MOD_PRS_n` and `INTERRUPT_n` are active-low raw pins and are not converted
into a module-presence or interrupt claim in this report.

## Pre-reseat instance 7

```text
Master BEGIN raw=001070802A2A6956 REF=26966 DMTD=10794 RX=28800 PHY_READY=0 RX_LOCK_REF=1 RX_LOCK_DATA=0
Master END   raw=0024D6D516C05628 REF=22056 DMTD=5824  RX=54997 PHY_READY=0 RX_LOCK_REF=0 RX_LOCK_DATA=1
Master modulo delta: REF=50626 DMTD=60566 RX=26197

Slave  BEGIN raw=0026720DA08FE2B6 REF=58038 DMTD=41103 RX=29197 PHY_READY=0 RX_LOCK_REF=0 RX_LOCK_DATA=1
Slave  END   raw=0023C5868CEDCF53 REF=53075 DMTD=36077 RX=50566 PHY_READY=0 RX_LOCK_REF=0 RX_LOCK_DATA=1
Slave  modulo delta: REF=60573 DMTD=60510 RX=21369
```

The counters show reference, DMTD, and recovered-RX clock activity, but
`PHY_READY` stayed 0. The changing RX lock indications are treated as
time-varying direct-probe values, not as a stable WR data-link qualification.

## Baseline interpretation

The pre-reseat state is consistent with the previously established boundary:

```text
SI configured -> CPU running -> PHY reset released -> local clocks active
    -> PHY data/pattern/ready and TX/link bring-up  [not established]
```

The correct result at this point is only:

```text
UPSTREAM_WR_LINK_STARTUP_BLOCKER = STILL_PRESENT_BEFORE_RESEAT
LINK_COMPONENT_AB = UNKNOWN
PRELOAD_EVALUATION = NOT_REACHED
```

After the same fiber is reinserted at both ends, run the same two existing
read-only scripts and compare `PHY_READY`, RX pattern/sync, `WR_TX_READY`,
`WR_READY`, `CORE_LINK_OK`, and PTP RX activity. Change only one physical
thing at a time. If the link remains down, the next A/B must be a known-good
fiber, SFP, or supported port/lane, one item per run.

## Remote raw artifacts

The exact pre-reseat logs remain on Pain under:

```text
/home/b10504072/04_WR/pain-preserve/EXP-WR-PHY-LINK-NONDESTRUCTIVE-HARDWARE-ISOLATION-20260916/pre-reseat/read_probe.log
/home/b10504072/04_WR/pain-preserve/EXP-WR-PHY-LINK-NONDESTRUCTIVE-HARDWARE-ISOLATION-20260916/pre-reseat/read_clock_activity.log
```

Their hashes and sizes are in `manifest.json`.

