# EXP-S5-QSFPA-LANE0-RESTORE-20260919

## Verdict

```text
QSFP_A_STEP1_LINK = PASS
STEP2              = NOT_RUN
STEP4B             = NOT_RUN
STEP5              = NOT_ASSESSED
```

The QSFP-A White Rabbit upstream link was restored by reverting the active
WR data route in both diagnostic images from lane 2 to the known-good lane 0.
This is strong code-path evidence against the optical cable as the primary
cause: the same physical path failed with the lane-2 image and passed again
with the lane-0 image.

## Source change

Source commit:

```text
ef3223adb0fa226f9e412e179c1d963ce11f4574
```

Changed in both Master and Slave:

- `pad_txp_o` / `pad_rxp_i` restored to `QSFPA_TX_p(0)` /
  `QSFPA_RX_p(0)`;
- inactive TX lanes 1 through 3 driven low;
- TX first-post-tap 18 restored to `QSFPA_TX_p[0]` in the QSF.

No Step5 PI, gain, threshold, timeout, bootstrap, arbiter, mailbox, reset,
detector, SoftPLL, or control-branch behavior was changed.

The lane-2 route was introduced by `4eeb128d` on 2026-09-01. The original
Step1 milestone source used lane 0 and the old milestone image had repeatedly
reported low 16-bit status `0x82CF` on this hardware path.

## Build and programming

Both Quartus builds completed with return code 0. Quartus reported the
pre-existing implementation caveat `timing_closed=NO` for both images.

```text
Slave SOF SHA256
7b0dfae8408b9fc45e22c2bfc841d384a7e16a6adb68f72f7f0b4079a6daa63c

Master SOF SHA256
9fec958572546984e26571511034d5661c41720772b25f0188d559b9aecba5a0
```

Programming succeeded with 0 errors and 0 warnings:

```text
Slave cable  DE5 [1-11.2]  checksum 0x30B5B27A
Master cable DE5 [1-11.1]  checksum 0x30AFA169
```

## Step1 probe result

The valid probe run used the full Quartus SignalTap executable path. The
earlier PATH-only attempt produced only `command-not-found` messages and is
not counted as an observation.

There were 12 valid samples, each reading both boards:

```text
Master low16: 0x82FF on 12/12 samples
Slave  low16: 0x82EF on 12/12 samples
```

For the status probe, bits `[3:0]` are `link_ok`, `tm_link_up`, `phy_ready`,
and `si_config_done`. Bits 7 and 6 are `tx_ready` and `rx_ready`. Therefore
all 12 samples on both boards had:

```text
link_ok       = 1
tm_link_up    = 1
phy_ready     = 1
si_config_done= 1
tx_ready      = 1
rx_ready      = 1
```

The exact raw probe output is preserved in `read_probe_12x.log`.

## 2-second clock activity check

The read-only clock activity probe also succeeded. Both boards reported
`PHY_READY=1` and `RX_LOCK_DATA=1` at the end of the 2-second interval, with
changed activity/toggle observations. The Slave additionally reported
`RX_LOCK_REF=1` at the end of the interval.

The raw output is preserved in `read_clock_activity_2000ms.log`.

## Interpretation and next boundary

This experiment restores the upstream prerequisite only. It does not prove
frequency lock, phase lock, or Step5 completion. The next valid experiment may
resume the Step5 startup/lock diagnostics using this lane-0 source baseline;
it must keep the lane mapping fixed and must not mix a new QSFP route change
with PI or SoftPLL tuning.

## Raw artifacts

- `build_slave.log`
- `build_master.log`
- `program_slave.log`
- `program_master.log`
- `read_probe_12x.log`
- `read_clock_activity_2000ms.log`
- `manifest.txt`
