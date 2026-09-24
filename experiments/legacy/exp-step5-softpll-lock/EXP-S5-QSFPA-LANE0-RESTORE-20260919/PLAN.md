# EXP-S5-QSFPA-LANE0-RESTORE-20260919

## Purpose

Restore the known-good QSFP-A data-lane route so the Step5 diagnostic image can
re-establish the upstream White Rabbit link before any Step5 control experiment.

## Evidence and hypothesis

- The original Step1 milestone image used QSFP-A lane 0 and repeatedly produced
  the healthy probe status `0x82CF`.
- Commit `4eeb128d` changed the active WR data route in both Master and Slave
  from lane 1 to lane 2. The current Step5 image therefore uses lane 2.
- The current Step5 QSF retained lane 2 TX pre-emphasis and removed the lane 0
  pre-emphasis assignment.
- The current Step5 image failed with `PHY_READY=0` and `core_link_ok=0` even
  after the QSFP-A fiber was replaced.

The test hypothesis is that the regression is in the active lane selection and
its corresponding transceiver tuning, not in the optical cable.

## Single scoped source change

For both `DE5a_wr_master_jtag` and `DE5a_wr_slave_jtag`:

- route WR TX/RX back to `QSFPA_[TX/RX]_p(0)`;
- hold inactive TX lanes 1 through 3 low;
- restore TX first-post-tap 18 on `QSFPA_TX_p[0]`.

No PI, gain, threshold, timeout, bootstrap, arbiter, mailbox, PHY reset,
SoftPLL, detector, or Step5 control behavior is changed.

## Validation sequence

1. Run offline source checks and compile both JTAG diagnostic images.
2. Program Slave, then Master on Pain.
3. Run the existing read-only probe twelve times on each board.
4. Treat Step1 link recovery as the only pass/fail decision in this experiment.
5. Do not claim Step2, Step4B, or Step5 from this run.
