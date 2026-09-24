# EXP-WR-PHY-QSFPB-PORTB-DIAGNOSTIC-20260917

## Verdict

**QSFP-B physical/WR prerequisite: PASS.**

Both DE5 endpoints sustained the expected PHY and WR link indicators in six
read-only probe samples. This is **not** a Step5 phase-lock PASS. It removes
the current QSFP-A upstream blocker and permits the next Step5 experiment to
use the QSFP-B lane-0 path.

The experiment kept the Step5 control implementation unchanged: no PI/gain,
threshold, timeout, bootstrap, arbiter, mailbox, detector, reset, or observer
logic was modified. The original A-port Step5 source was not overwritten.

## Baseline and image

- Branch: `exp/step5-softpll-lock`
- Laptop source HEAD: `743ee79a`
- Experiment source: `quartus/jtag_runtime_diag_portb`
- Compile/program order: Slave, then Master
- Physical path: QSFP-B lane 0 for WR data and 125 MHz PHY reference clock;
  QSFP-A remains the 124.992 MHz DMTD reference as specified in `PLAN.md`.

SOF artifacts:

| Endpoint | SHA-256 | Quartus programmer checksum | Result |
|---|---|---:|---|
| Slave-B | `12ee92dd41294424bf0cf9a419034cbcce5d0dae007e020795e7014e43211bf5` | `0x30B8FA68` | programmed successfully |
| Master-B | `56d12c68f093d0d05bef6b4a779d20be09ff2efec22186348b3f8f484ce97c01` | `0x30B06CFD` | programmed successfully |

## Build and programming

Both full Quartus 17.0 compilations completed with exit code 0 and generated
SOF files:

- Slave-B: `0 errors`, `340 warnings`, elapsed `00:05:17`.
- Master-B: `0 errors`, `339 warnings`, elapsed `00:08:19`.
- Programming: both cables reported `Configuration succeeded`, `0 errors`,
  `0 warnings`.

The warnings include unused non-selected QSFP lanes and incomplete timing
constraints already visible in this diagnostic topology. They did not prevent
image generation or JTAG programming and are retained in the raw logs.

## Repeated WR probe result

The existing `scripts/jtag/read_probe.tcl` was run six times at approximately
five-second intervals. The low 16-bit status was stable for each endpoint:

| Endpoint | Samples 1--6 | Decoded result |
|---|---|---|
| Master-B | `0x82FF` every sample | `si_config_done=1`, `phy_ready=1`, `tm_link_up=1`, `link_ok=1`, `time_valid=1`, `pps_valid=1`, `rx_ready=1`, `tx_ready=1`, `rx_enc_err=0` |
| Slave-B | `0x82EF` every sample | `si_config_done=1`, `phy_ready=1`, `tm_link_up=1`, `link_ok=1`, `time_valid=0`, `pps_valid=1`, `rx_ready=1`, `tx_ready=1`, `rx_enc_err=0` |

The changing upper 32 bits are runtime counters/status fields; the decisive
low-16-bit link fields remained stable. In particular, both endpoints have
`tm_link_up=1`, `link_ok=1`, `rx_ready=1`, `tx_ready=1`, and no receive
encoding error. The Slave `time_valid=0` means global WR time is not claimed
by this diagnostic smoke; it does not negate the recovered Ethernet/WR link.

## Clock-activity result

`scripts/jtag/read_clock_activity.tcl 2000` completed three times. All 12
begin/end observations reported `PHY_READY=1` and `RX_LOCK_DATA=1` on both
boards, with changing reference, DMTD, and recovered-RX counters. The probe's
`RX_LOCK_REF` remained 0 in the repeated windows; this field is not the WR
link-up bit and is recorded as a follow-up reference-clock/SoftPLL observation,
not silently treated as a link failure.

## Raw evidence

- `raw/build/quartus_slave_portb_compile.log`
- `raw/build/quartus_master_portb_compile.log`
- `raw/build/sof-manifest.txt`
- `raw/program/program-slave-portb.log`
- `raw/program/program-master-portb.log`
- `raw/observe/read-probe-repeat.log`
- `raw/observe/read-clock-activity-repeat.log`

## Next experiment

Do not sweep QSFP-C. Use this verified QSFP-B lane-0 mapping for the next
Step5-capable image while keeping the Step5 control code frozen. After the
normal compile/program sequence, run the Step5 startup/observer capture and
check whether Slave `time_valid`, SoftPLL startup, Main frequency acquisition,
and phase convergence proceed on the recovered B path. If the next capture
fails, classify the first failing boundary before changing any control
parameter.
