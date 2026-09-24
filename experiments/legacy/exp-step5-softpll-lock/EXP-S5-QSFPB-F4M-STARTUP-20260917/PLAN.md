# EXP-S5-QSFPB-F4M-STARTUP-20260917

## Purpose

Run the existing Step5 F4M/F4L read-only startup observer on the QSFP-B
lane-0 physical path that passed `EXP-WR-PHY-QSFPB-PORTB-DIAGNOSTIC-20260917`.
This separates the previous A-port PHY regression from the remaining SoftPLL
startup and phase-lock problem.

## Source and scope

- Branch: `exp/step5-softpll-lock`
- Baseline: the pushed QSFP-B diagnostic source and report commit
- Projects: `quartus/jtag_runtime_diag_portb`
- Images: `DE5a_wr_slave_portb` and `DE5a_wr_master_portb`
- Physical path: QSFP-B lane 0 for WR data and 125 MHz PHY reference;
  QSFP-A remains the 124.992 MHz DMTD reference.

This round does not change production control behavior. Keep PI/gain,
thresholds, timeout, bootstrap, arbiter, mailbox, detector, DAC ordering,
PHY, reset, RTL, SDB, and observer logic unchanged. The rebuild is repeated
to preserve the laptop-push -> Pain-pull -> compile/program experiment
boundary and to record exact image identity for this Step5 session.

## Pain procedure

1. Pull this plan and the already-reviewed B-port source.
2. Compile both port-B projects with Quartus 17.0.
3. Program Slave first (`DE5 [1-11.2]`), then Master (`DE5 [1-11.1]`).
4. Run the existing read-only F4M observer as a 60-second smoke:

   ```text
   timeout 120s quartus_stp -t \
     scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
     100 1000 "" 60000 70000 f4m
   ```

5. Preserve raw observer output, image hashes, and programming logs for the
   laptop report.

## Interpretation

The smoke is valid only if the observer obtains coherent F4L frames,
`PHY_LINK_USABLE=1`, stable generation/reset state, and no transport or bank
collision error. It is not a Step5 PASS by itself. A Step5 PASS requires the
repository's sustained Main/Helper/phase/PSTAT lock criteria; if the smoke is
valid but still unlocked, use its first-loss and Main/Helper correlation to
choose the next single-variable experiment. If the B path fails upstream
again, stop and record the first failing boundary before changing any PI
parameter.
